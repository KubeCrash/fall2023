package main

import (
	"database/sql"
	"fmt"
	"log"
	"os"

	"github.com/buoyantio/flag-demo/server/player"
	"github.com/buoyantio/flag-demo/server/server"
	"github.com/spf13/cobra"

	_ "github.com/jackc/pgx/v5/stdlib"
)

func runServer(cmd *cobra.Command, args []string) {
	var db *sql.DB = nil
	var err error

	playerName, _ := cmd.Flags().GetString("player")
	region, _ := cmd.Flags().GetString("region")
	smilies, _ := cmd.Flags().GetString("smilies")
	sleepsec, _ := cmd.Flags().GetFloat64("sleep")
	baseURL, _ := cmd.Flags().GetString("url")

	if playerName != "" {
		player := player.New(baseURL, playerName, region, smilies, sleepsec)
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

func main() {
	rootCmd := &cobra.Command{
		Use:   "server",
		Short: "The World server",
		Run:   runServer,
	}

	rootCmd.Flags().StringP("url", "u", "http://localhost:8080", "Base URL")

	rootCmd.Flags().StringP("player", "p", "", "Player name")
	rootCmd.Flags().StringP("region", "r", "", "Player region")
	rootCmd.Flags().StringP("smilies", "s", "", "Player smiley set")
	rootCmd.Flags().Float64P("sleep", "z", 0, "Player sleep time")

	if err := rootCmd.Execute(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}
