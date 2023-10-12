package server

import (
	"database/sql"
	"fmt"

	"github.com/buoyantio/flag-demo/server/middleware"
	"github.com/gofiber/fiber/v2"
)

// Server holds the runtime variables required by the application.
type Server struct {
	db     *sql.DB
	router *fiber.App
}

// New returns a pointer to a new instance of Server.
func New(db *sql.DB) *Server {
	svr := Server{
		db: db,
	}

	router := fiber.New()
	router.Use(middleware.CORS)

	router.Static("/", "./ui")

	if db != nil {
		fmt.Printf("Adding cells handlers")
		router.Get("/cells", svr.getAllCellsHandler)
		router.Get("/cells/", svr.getAllCellsHandler)
		router.Get("/cells/:name", svr.getCellHandler)
		router.Post("/cells/:name/visit", svr.visitHandler)
	}

	svr.router = router

	return &svr
}

// Start kicks off the server's underlying router.
func (s *Server) Start(addr string) error {
	return s.router.Listen(addr)
}
