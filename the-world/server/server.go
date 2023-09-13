package main

import (
	"database/sql"
	"fmt"
	"log"
	"os"

	"github.com/buoyantio/flag-demo/server/server"
	_ "github.com/jackc/pgx/v5/stdlib"
)

func main() {
	connectionString, ok := os.LookupEnv("CONNECTION_STRING")
	if !ok {
		log.Fatalf("missing CONNECTION_STRING env var")
	}

	db, err := sql.Open("pgx", connectionString)
	if err != nil {
		log.Fatalf("Failed to open the SQLite database: %v", err)
	}
	defer db.Close()

	svr := server.New(db)

	fmt.Printf("Listening on port 8888...\n")
	log.Fatal(svr.Start(":8888"))
}
