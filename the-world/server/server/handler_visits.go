package server

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/gofiber/fiber/v2"
)

func (s *Server) visitHandler(c *fiber.Ctx) error {
	name := c.Params("name")
	smiley := c.Query("smiley")
	region := c.Query("region")

	if err := visitCell(c.Context(), s.db, name, smiley, region); err != nil {
		log.Printf("database error: %v", err)
		return fiber.NewError(http.StatusInternalServerError, fmt.Sprintf("database error: %v", err))
	}

	cell, err := getCell(s.db, name)
	if err != nil {
		return err
	}

	return c.JSON(cell)
}

func visitCell(ctx context.Context, db *sql.DB, name, smiley, region string) error {
	now := time.Now()

	fmt.Printf("%s: cell %s, smiley %s, region %s\n", now, name, smiley, region)

	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		log.Printf("could not begin txn: %v", err)
		return fmt.Errorf("could not begin txn: %w", err)
	}

	defer tx.Rollback()

	if _, err = tx.ExecContext(ctx, `INSERT INTO cells (name, smiley, crdb_region)
																	 VALUES ($1, $2, user_to_db_region($3))
																	 ON CONFLICT(name) DO UPDATE SET smiley = $2`, name, smiley, region); err != nil {
		log.Printf("could not upsert smiley: %v", err)
		return fmt.Errorf("could not upsert smiley: %w", err)
	}

	if _, err = tx.Exec(`INSERT INTO visits (cell_name, crdb_region, timestamp) VALUES ($1, user_to_db_region($2), $3)`, name, region, now); err != nil {
		log.Printf("could not upsert visitor: %v", err)
		return fmt.Errorf("could not upsert visitor: %w", err)
	}

	if err = tx.Commit(); err != nil {
		log.Printf("could not commit txn: %v", err)
		return fmt.Errorf("could not commit txn: %w", err)
	}

	return nil
}

func getVisitorCounts(db *sql.DB, name string, stmt string) (map[string]int, error) {
	rows, err := db.Query(stmt, name)
	if err != nil {
		log.Printf("could not run query: %v", err)
		log.Println(stmt)
		return nil, fmt.Errorf("could not run query: %w", err)
	}
	defer rows.Close()

	counts := make(map[string]int)

	for rows.Next() {
		var region string
		var count int

		if err = rows.Scan(&region, &count); err != nil {
			log.Printf("could not scan row: %v", err)
			return nil, fmt.Errorf("could not scan row: %w", err)
		}

		counts[region] = count
	}

	return counts, nil
}
