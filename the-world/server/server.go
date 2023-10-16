package main

import (
	"database/sql"
	"fmt"
	"log"
	"os"

	"github.com/buoyantio/flag-demo/server/player"
	"github.com/buoyantio/flag-demo/server/server"

	_ "github.com/jackc/pgx/v5/stdlib"
)

func main() {
	var db *sql.DB = nil
	var err error

	playerName, ok := os.LookupEnv("PLAYER_NAME")

	if ok {
		player := player.New(
			"http://localhost:8080",
			playerName,
			"NA",
			[]string{"winking", "smirking", "screaming", "flushed"},
		)

		player.Run()
		return
	}

	connectionString, ok := os.LookupEnv("CONNECTION_STRING")

	if ok {
		db, err = sql.Open("pgx", connectionString)

		if err != nil {
			log.Fatalf("Failed to open the SQLite database: %v", err)
		}

		defer db.Close()
	} else {
		log.Printf("No connection string found, only serving the GUI!")
	}

	log.Printf("Starting server, db is %v", db)
	svr := server.New(db)

	fmt.Printf("Listening on port 8888...\n")
	log.Fatal(svr.Start(":8888"))
}
