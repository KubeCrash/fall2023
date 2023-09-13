package middleware

import "github.com/gofiber/fiber/v2"

// CORS allows Fiber to run with a CORS middlewhare via Use(CORS)
func CORS(c *fiber.Ctx) error {
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
