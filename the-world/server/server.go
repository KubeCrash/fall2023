package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"time"

	_ "embed"

	"github.com/gofiber/fiber/v2"
	_ "github.com/jackc/pgx/v5/stdlib"
)

func main() {
	db, err := sql.Open("pgx", "postgres://world_service:EcSljwBeVIG42KLO0LS3jtuh9x6RMcOBZEWFSk@localhost:26257/defaultdb?sslmode=allow")
	if err != nil {
		log.Fatalf("Failed to open the SQLite database: %v", err)
	}
	defer db.Close()

	router := fiber.New()
	router.Use(cors)

	router.Get("/cells", getAllCellsHandler(db))
	router.Get("/cells/:name", getCellHandler(db))
	router.Post("/cells/:name/visit", visitHandler(db))

	fmt.Printf("Listening on port 8888...\n")
	log.Fatal(router.Listen(":8888"))
}

type cell struct {
	Name         string         `json:"name"`
	Smiley       string         `json:"smiley"`
	Recents      map[string]int `json:"recents"`
	Totals       map[string]int `json:"totals"`
	Destinations []string       `json:"destinations"`
}

func visitCell(ctx context.Context, db *sql.DB, name, smiley, region string) error {
	now := time.Now()

	fmt.Printf("%s: cell %s, smiley %s, region %s\n", now, name, smiley, region)

	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("could not begin txn: %w", err)
	}

	defer tx.Rollback()

	if _, err = tx.ExecContext(ctx, `INSERT INTO cells (name, smiley) VALUES ($1, $2) ON CONFLICT(name) DO UPDATE SET smiley = $3`, name, smiley, smiley); err != nil {
		return fmt.Errorf("could not upsert smiley: %w", err)
	}

	if _, err = tx.Exec(`INSERT INTO visits (cell_name, region, timestamp) VALUES ($1, $2, $3)`, name, region, now); err != nil {
		return fmt.Errorf("could not upsert visitor: %w", err)
	}

	if err = tx.Commit(); err != nil {
		return fmt.Errorf("could not commit txn: %w", err)
	}

	return nil
}

func getCellHandler(db *sql.DB) fiber.Handler {
	return func(c *fiber.Ctx) error {
		name := c.Params("name")

		cell, err := getCell(db, name)
		if err != nil {
			return err
		}

		return c.JSON(cell)
	}
}

func getCell(db *sql.DB, name string) (*cell, error) {
	var smiley string
	if err := db.QueryRow(`SELECT smiley FROM cells WHERE name = $1`, name).Scan(&smiley); err == sql.ErrNoRows {
		smiley = "neutral"
	} else if err != nil {
		return nil, fiber.NewError(http.StatusInternalServerError, "Database error")
	}

	recents, err := getVisitorCounts(db, name, `
        SELECT region, count(region) FROM
            (SELECT region FROM visits WHERE cell_name = $1
                ORDER BY timestamp DESC LIMIT 10)
            GROUP BY region`)

	if err != nil {
		return nil, fiber.NewError(http.StatusInternalServerError, fmt.Sprintf("Could not fetch recents: %v", err))
	}

	totals, err := getVisitorCounts(db, name, `
        SELECT region, count(region) FROM visits WHERE cell_name = $1
             GROUP BY region`)

	if err != nil {
		return nil, fiber.NewError(http.StatusInternalServerError, fmt.Sprintf("Could not fetch recents: %v", err))
	}

	rows, err := db.Query("SELECT dest FROM connections WHERE src = $1", name)
	if err != nil {
		return nil, fiber.NewError(http.StatusInternalServerError, fmt.Sprintf("Could not fetch connections: %v", err))
	}
	defer rows.Close()

	dests := make([]string, 0, 2) // every cell has at least two connections

	for rows.Next() {
		var dest string
		if err = rows.Scan(&dest); err != nil {
			return nil, fiber.NewError(http.StatusInternalServerError, fmt.Sprintf("Could not scan connection row: %v", err))
		}

		dests = append(dests, dest)
	}

	return &cell{
		Name:         name,
		Recents:      recents,
		Totals:       totals,
		Smiley:       smiley,
		Destinations: dests,
	}, nil
}

func visitHandler(db *sql.DB) fiber.Handler {
	return func(c *fiber.Ctx) error {
		name := c.Params("name")
		smiley := c.Query("smiley")
		region := c.Query("region")

		if err := visitCell(c.Context(), db, name, smiley, region); err != nil {
			return fiber.NewError(http.StatusInternalServerError, fmt.Sprintf("Database error: %v", err))
		}

		cell, err := getCell(db, name)
		if err != nil {
			return err
		}

		return c.JSON(cell)
	}
}

func getVisitorCounts(db *sql.DB, name string, stmt string) (map[string]int, error) {
	rows, err := db.Query(stmt, name)
	if err != nil {
		return nil, fmt.Errorf("could not run query: %w", err)
	}
	defer rows.Close()

	counts := make(map[string]int)

	for rows.Next() {
		var region string
		var count int

		if err = rows.Scan(&region, &count); err != nil {
			return nil, fmt.Errorf("could not scan row: %w", err)
		}

		counts[region] = count
	}

	return counts, nil
}

// allCellHandler returns the smiley and visitor counts for all cells, as a JSON dictionary.
func getAllCellsHandler(db *sql.DB) fiber.Handler {
	return func(c *fiber.Ctx) error {
		// Yes, this is some hairy SQL. It joins the cells table with two separate
		// subqueries: the first one partitions the visits table by cell name,
		// then counts the regions in the 10 most recent visits for each cell, and
		// the second one does the same without the partition, so it gets the
		// per-cell totals.
		//
		// The most useful source when I was figuring out how to do this was
		// https://stackoverflow.com/questions/28119176/select-top-n-record-from-each-group-sqlite.
		// I'm guessing that there's a better way to do this.

		stmt := `
        SELECT
            name,
            smiley,
            y.region as recent_region,
            y.count as recent_count,
            z.region as total_region,
            z.count as total_count
        FROM cells
        JOIN (
            SELECT
                x.cell_name as cell_name,
                x.region as region,
                count(x.region) as count
            FROM (
                SELECT
                    ROW_NUMBER() OVER (PARTITION BY cell_name ORDER BY timestamp DESC) AS r,
                    cell_name,
                    region
                FROM
                    visits
            ) x
            WHERE x.r <= 10
            GROUP BY cell_name, region
        ) y ON name = y.cell_name
        JOIN (
            SELECT
                cell_name,
                region,
                count(region) as count
            FROM
                visits
            GROUP BY cell_name, region
        ) z ON (name = z.cell_name) AND (y.region = z.region)
    `

		rows, err := db.Query(stmt)
		if err != nil {
			fmt.Printf("error: %v\n", err)
			return fiber.NewError(http.StatusInternalServerError, "Database error")
		}
		defer rows.Close()

		cells := make(map[string]*cell)

		for rows.Next() {
			var name string
			var smiley string
			var recent_region string
			var recent_count int
			var total_region string
			var total_count int

			if err = rows.Scan(&name, &smiley, &recent_region, &recent_count, &total_region, &total_count); err != nil {
				fmt.Printf("error: %v\n", err)
				return fiber.NewError(http.StatusInternalServerError, "Database error")
			}

			if _, ok := cells[name]; !ok {
				cells[name] = &cell{
					Name:    name,
					Recents: make(map[string]int),
					Totals:  make(map[string]int),
					Smiley:  smiley,
				}
			}

			cell := cells[name]
			cell.Recents[recent_region] = recent_count
			cell.Totals[total_region] = total_count
		}

		// After all that, we also need to find all the cells for which we have
		// destinations, but no visits, because the JavaScript code needs to know
		// about all the possible cells up front.
		if rows, err = db.Query(`SELECT distinct(src) FROM connections WHERE src NOT IN (SELECT distinct(cell_name) FROM visits)`); err != nil {
			fmt.Printf("error: %v\n", err)
			return fiber.NewError(http.StatusInternalServerError, "Database error")
		}

		for rows.Next() {
			var name string
			if err = rows.Scan(&name); err != nil {
				fmt.Printf("error: %v\n", err)
				return fiber.NewError(http.StatusInternalServerError, "Database error")
			}

			if _, ok := cells[name]; !ok {
				cells[name] = &cell{
					Name:    name,
					Recents: make(map[string]int),
					Totals:  make(map[string]int),
					Smiley:  "",
				}
			}
		}

		fmt.Printf("GET all cells: %v\n", cells)

		return c.JSON(cells)
	}
}

func cors(c *fiber.Ctx) error {
	origin := c.Get("Origin")

	if origin == "" {
		origin = "*"
	}

	c.Set("Access-Control-Allow-Origin", origin)
	c.Set("Access-Control-Allow-Credentials", "true")
	c.Set("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
	c.Set("Access-Control-Allow-Headers", "Content-Type, Cache-Control, X-Custom-Header")

	// Handle pre-flight OPTIONS request
	if c.Method() == "OPTIONS" {
		return nil
	}

	return c.Next()
}
