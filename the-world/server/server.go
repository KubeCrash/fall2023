package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	_ "embed"

	_ "github.com/mattn/go-sqlite3"
)

//go:embed connections.json
var connectionsJSON string

type Cell struct {
	Name         string         `json:"name"`
	Smiley       string         `json:"smiley"`
	Recents      map[string]int `json:"recents"`
	Totals       map[string]int `json:"totals"`
	Destinations []string       `json:"destinations"`
}

var (
	Smilies = map[string]string{
		"confused":  "&#x1F615;",
		"cursing":   "&#x1F92C;",
		"kaboom":    "&#x1F92F;",
		"neutral":   "&#x1F610;",
		"screaming": "&#x1F631;",
		"sleeping":  "&#x1F634;",
		"smiling":   "&#x1F603;",
		"thinking":  "&#x1F914;",
		"tongue":    "&#x1F61B;",
		"upset":     "&#x1F62C;",
		"yay":       "&#x1F389;",
	}
)

var db *sql.DB

func initDatabase() {
	var err error
	db, err = sql.Open("sqlite3", "./cells.db")
	if err != nil {
		log.Fatalf("Failed to open the SQLite database: %v", err)
	}

	var connections map[string]map[string][]string
	err = json.Unmarshal([]byte(connectionsJSON), &connections)

	if err != nil {
		log.Fatalf("Failed to parse connections.json: %v", err)
	}

	// Create tables if they don't exist
	statements := []string{
		`DROP TABLE IF EXISTS connections`,
		`CREATE TABLE connections (rownum INTEGER PRIMARY KEY, src TEXT, dest TEXT)`,
		`CREATE TABLE IF NOT EXISTS cells (name TEXT PRIMARY KEY, smiley TEXT)`,
		`CREATE TABLE IF NOT EXISTS visits (cell_name TEXT, region TEXT, timestamp INTEGER)`,
	}

	for _, stmt := range statements {
		_, err := db.Exec(stmt)
		if err != nil {
			log.Fatalf("Failed to create table: %v", err)
		}
	}

	tx, err := db.BeginTx(context.Background(), nil)
	if err != nil {
		log.Fatalf("Failed to begin transaction: %v", err)
	}

	defer tx.Rollback()

	rownum := 0

	for cell, destinations := range connections["connections"] {
		for _, dest := range destinations {
			_, err = tx.Exec(`INSERT INTO connections (rownum, src, dest) VALUES (?, ?, ?)`, rownum, cell, dest)

			if err != nil {
				log.Fatalf("Failed to insert connection %s -> %s: %v", cell, dest, err)
			}

			rownum++
		}
	}

	err = tx.Commit()

	if err != nil {
		log.Fatalf("Failed to commit transaction: %v", err)
	}
}

func visitCell(ctx context.Context, cellName string, smiley string, region string) error {
	now := time.Now()

	fmt.Printf("%s: cell %s, smiley %s, region %s\n", now, cellName, smiley, region)

	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("could not begin txn: %w", err)
	}

	defer tx.Rollback()

	_, err = tx.ExecContext(ctx, `INSERT INTO cells (name, smiley) VALUES (?, ?) ON CONFLICT(name) DO UPDATE SET smiley=?`, cellName, smiley, smiley)

	if err != nil {
		return fmt.Errorf("could not upsert smiley: %w", err)
	}

	_, err = tx.Exec(`INSERT INTO visits (cell_name, region, timestamp) VALUES (?, ?, ?)`, cellName, region, now.UnixMilli())

	if err != nil {
		return fmt.Errorf("could not upsert visitor: %w", err)
	}

	err = tx.Commit()

	if err != nil {
		return fmt.Errorf("could not commit txn: %w", err)
	}

	return nil
}

func handleCORS(w http.ResponseWriter, r *http.Request) bool {
	// Set CORS headers
	origin := r.Header.Get("Origin")

	if origin == "" {
		origin = "*"
	}

	w.Header().Set("Access-Control-Allow-Origin", origin)
	w.Header().Set("Access-Control-Allow-Credentials", "true")
	w.Header().Set("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Cache-Control, X-Custom-Header")

	// Handle pre-flight OPTIONS request
	if r.Method == "OPTIONS" {
		w.WriteHeader(http.StatusOK)
		return true
	}

	return false
}

func cellHandler(w http.ResponseWriter, r *http.Request) {
	path := strings.TrimSuffix(strings.TrimPrefix(r.URL.Path, "/"), "/")

	segments := strings.Split(path, "/")

	if handleCORS(w, r) {
		return
	}

	if (len(segments) < 2) ||
		(len(segments) > 3) ||
		(segments[0] != "cell") {
		http.Error(w, "Bad request", http.StatusBadRequest)
		return
	}

	cellName := segments[1]

	if (len(segments) == 2) || (segments[2] == "") {
		if r.Method != "GET" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		handleGetCell(w, r, cellName)
	} else if segments[2] == "visit" {
		if r.Method != "POST" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		handleVisit(w, r, cellName)
	} else {
		http.Error(w, "Not found", http.StatusNotFound)
	}
}

func handleGetCell(w http.ResponseWriter, r *http.Request, cellName string) {
	var smiley string

	err := db.QueryRow(`SELECT smiley FROM cells WHERE name = ?`, cellName).Scan(&smiley)
	if err == sql.ErrNoRows {
		smiley = "neutral"
	} else if err != nil {
		http.Error(w, "Database error", http.StatusInternalServerError)
		return
	}

	recents, err := getVisitorCounts(cellName, `
        SELECT region,count(region) FROM
            (SELECT region FROM visits WHERE cell_name=?
                ORDER BY timestamp DESC LIMIT 10)
            GROUP BY region;
    `)

	if err != nil {
		http.Error(w, fmt.Sprintf("Could not fetch recents: %v", err), http.StatusInternalServerError)
		return
	}

	totals, err := getVisitorCounts(cellName, `
        SELECT region,count(region) FROM visits WHERE cell_name=?
             GROUP BY region;
    `)

	if err != nil {
		http.Error(w, fmt.Sprintf("Could not fetch recents: %v", err), http.StatusInternalServerError)
		return
	}
	// fmt.Printf("GET %s: smiley %s recents %v totals %v\n", cellName, smiley, recents, totals)

	rows, err := db.Query("SELECT dest FROM connections WHERE src = ?", cellName)
	if err != nil {
		http.Error(w, fmt.Sprintf("Could not fetch connections: %v", err), http.StatusInternalServerError)
		return
	}

	defer rows.Close()

	dests := make([]string, 0, 2) // every cell has at least two connections

	for rows.Next() {
		var dest string

		err = rows.Scan(&dest)

		if err != nil {
			http.Error(w, fmt.Sprintf("Could not scan connection row: %v", err), http.StatusInternalServerError)
			return
		}

		dests = append(dests, dest)
	}

	cell := &Cell{
		Name:         cellName,
		Recents:      recents,
		Totals:       totals,
		Smiley:       smiley,
		Destinations: dests,
	}

	json.NewEncoder(w).Encode(cell)
}

func getVisitorCounts(cellName string, stmt string) (map[string]int, error) {
	rows, err := db.Query(stmt, cellName)
	if err != nil {
		return nil, fmt.Errorf("could not run query: %w", err)
	}

	defer rows.Close()

	counts := make(map[string]int)

	for rows.Next() {
		var region string
		var count int

		err = rows.Scan(&region, &count)

		if err != nil {
			return nil, fmt.Errorf("could not scan row: %w", err)
		}

		counts[region] = count
	}

	return counts, nil
}

func handleVisit(w http.ResponseWriter, r *http.Request, cellName string) {
	// fmt.Printf("POST visit: URL %s\n", r.URL)
	// fmt.Printf("POST visit: Query %v\n", r.URL.Query())

	smiley := r.URL.Query().Get("smiley")
	region := r.URL.Query().Get("region")

	err := visitCell(r.Context(), cellName, smiley, region)

	if err != nil {
		http.Error(w, fmt.Sprintf("Database error: %v", err), http.StatusInternalServerError)
		return
	}

	handleGetCell(w, r, cellName)
}

// allCellHandler returns the smiley and visitor counts for all cells, as a JSON dictionary.
func allCellsHandler(w http.ResponseWriter, r *http.Request) {
	if handleCORS(w, r) {
		return
	}

	if r.Method != "GET" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
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
		http.Error(w, "Database error", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	cells := make(map[string]*Cell)

	for rows.Next() {
		var name string
		var smiley string
		var recent_region string
		var recent_count int
		var total_region string
		var total_count int

		err = rows.Scan(&name, &smiley, &recent_region, &recent_count, &total_region, &total_count)
		if err != nil {
			fmt.Printf("error: %v\n", err)
			http.Error(w, "Database error", http.StatusInternalServerError)
			return
		}

		if _, ok := cells[name]; !ok {
			cells[name] = &Cell{
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
	rows, err = db.Query(`SELECT distinct(src) FROM connections WHERE src NOT IN (SELECT distinct(cell_name) FROM visits)`)

	if err != nil {
		fmt.Printf("error: %v\n", err)
		http.Error(w, "Database error", http.StatusInternalServerError)
		return
	}

	defer rows.Close()

	for rows.Next() {
		var name string
		err = rows.Scan(&name)

		if err != nil {
			fmt.Printf("error: %v\n", err)
			http.Error(w, "Database error", http.StatusInternalServerError)
			return
		}

		if _, ok := cells[name]; !ok {
			cells[name] = &Cell{
				Name:    name,
				Recents: make(map[string]int),
				Totals:  make(map[string]int),
				Smiley:  "",
			}
		}
	}

	fmt.Printf("GET all cells: %v\n", cells)

	json.NewEncoder(w).Encode(cells)
}

func main() {
	initDatabase()
	defer db.Close()

	http.HandleFunc("/cell/", cellHandler)
	http.HandleFunc("/allcells/", allCellsHandler)

	fmt.Printf("Listening on port 8888...\n")
	log.Fatal(http.ListenAndServe(":8888", nil))
}
