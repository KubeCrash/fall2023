package server

import (
	"database/sql"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/buoyantio/flag-demo/server/model"
	"github.com/gofiber/fiber/v2"
)

func user_to_region(user string) string {
	// XXX This is a brutal hack.
	if user == "" {
		// Technically impossible, if Emissary is doing its job.
		return "error"
	}

	if strings.ToLower(user) == "world" {
		return "world"
	}

	if (strings.ToLower(user) == "es") || (strings.ToLower(user) == "de") {
		return "EU"
	}

	return "NA"
}

func cell_in_region(cell string, region string) bool {
	if region == "world" {
		return true
	}

	return strings.HasPrefix(strings.ToLower(cell), strings.ToLower(region))
}

func (s *Server) getAllCellsHandler(c *fiber.Ctx) error {
	// Who is the logged-in user? We trust what Emissary says here since
	// it's managing auth and Linkerd is securing that bit.
	user := strings.ToUpper(string(c.Request().Header.Peek("x-world-user")))
	region := user_to_region(user)

	now := time.Now()

	fmt.Printf("%s: WORLD %s (%s)\n", now, user, region)

	// Start by grabbing all the locations from the server. This works no
	// matter what.
	rows, err := s.db.Query(`SELECT * from locations`)
	if err != nil {
		fmt.Printf("error loading locations: %v\n", err)
		return fiber.NewError(http.StatusInternalServerError, "Database error")
	}
	defer rows.Close()

	locations := make(map[string]string)

	for rows.Next() {
		var player string
		var cell_name string

		err = rows.Scan(&player, &cell_name)

		if err != nil {
			fmt.Printf("error scanning locations: %v\n", err)
			return fiber.NewError(http.StatusInternalServerError, "Database error")
		}

		locations[player] = cell_name
	}

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
		WITH
			y AS (
				SELECT
					x.cell_name as cell_name,
					x.crdb_region as region,
					count(x.crdb_region) as count
				FROM (
					SELECT
						ROW_NUMBER() OVER (PARTITION BY cell_name ORDER BY timestamp DESC) AS r,
						cell_name,
						crdb_region
					FROM
						visits
				) x
				WHERE x.r <= 10
				GROUP BY cell_name, crdb_region
			),
			z AS (
				SELECT
					cell_name,
					crdb_region,
					count(crdb_region) as count
				FROM
					visits
				GROUP BY cell_name, crdb_region
			)
		SELECT
			name,
			smiley,
			y.region as recent_region,
			y.count as recent_count,
			z.crdb_region as total_region,
			z.count as total_count
		FROM cells c
		JOIN y ON c.name = y.cell_name
		JOIN z ON (c.name = z.cell_name) AND (y.region = z.crdb_region)`

	rows, err = s.db.Query(stmt)
	if err != nil {
		fmt.Printf("error: %v\n", err)
		return fiber.NewError(http.StatusInternalServerError, "Database error")
	}
	defer rows.Close()

	cells := make(map[string]*model.Cell)

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

		// If the user isn't in the cell's region, wipe the counts.
		// (Ideally, the database Just Does This. We want to be able to demo
		// this without needing enterprise features, though, so we have the app
		// handle it.)
		if !cell_in_region(name, region) {
			recent_count = 0
			total_count = 0
		}

		if _, ok := cells[name]; !ok {
			cells[name] = &model.Cell{
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
	if rows, err = s.db.Query(`SELECT distinct(src) FROM connections WHERE src NOT IN (SELECT distinct(cell_name) FROM visits)`); err != nil {
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
			cells[name] = &model.Cell{
				Name:    name,
				Recents: make(map[string]int),
				Totals:  make(map[string]int),
				Smiley:  "",
			}
		}
	}

	world := &model.World{
		User:      user,
		Locations: locations,
		Cells:     cells,
	}

	// fmt.Printf("GET the world: %v\n", world)

	return c.JSON(world)
}

func (s *Server) getCellHandler(c *fiber.Ctx) error {
	// Who is the logged-in user? We trust what Emissary says here since
	// it's managing auth and Linkerd is securing that bit.
	user := strings.ToUpper(string(c.Request().Header.Peek("x-world-user")))
	name := c.Params("name")

	cell, err := getCell(s.db, name, user)
	if err != nil {
		return err
	}

	return c.JSON(cell)
}

func getCell(db *sql.DB, name string, user string) (*model.Cell, error) {
	// Yeah, this is a crock at the moment.
	region := user_to_region(user)

	now := time.Now()

	fmt.Printf("%s: CELL %s: %s (%s)\n", now, name, user, region)

	var smiley string
	if err := db.QueryRow(`SELECT smiley FROM cells WHERE name = $1`, name).Scan(&smiley); err == sql.ErrNoRows {
		smiley = "neutral"
	} else if err != nil {
		return nil, fiber.NewError(http.StatusInternalServerError, "Database error")
	}

	recents := make(map[string]int)
	totals := make(map[string]int)
	var err error

	// If the user isn't in the cell's region, don't even fetch the visit
	// data. (Ideally, the database Just Does This. We want to be able to demo
	// this without needing enterprise features, though, so we have the app
	// handle it.)
	if cell_in_region(name, region) {
		recents, err = getVisitorCounts(db, name, `
			SELECT crdb_region, count(crdb_region) FROM
				(SELECT crdb_region FROM visits WHERE cell_name = $1
					ORDER BY timestamp DESC LIMIT 10)
				GROUP BY crdb_region`)

		if err != nil {
			return nil, fiber.NewError(http.StatusInternalServerError, fmt.Sprintf("Could not fetch recents: %v", err))
		}

		totals, err = getVisitorCounts(db, name, `
			SELECT crdb_region, count(crdb_region)
					FROM visits
					WHERE cell_name = $1
			GROUP BY crdb_region`)

		if err != nil {
			return nil, fiber.NewError(http.StatusInternalServerError, fmt.Sprintf("Could not fetch recents: %v", err))
		}
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

	return &model.Cell{
		Name:         name,
		Recents:      recents,
		Totals:       totals,
		Smiley:       smiley,
		Destinations: dests,
	}, nil
}
