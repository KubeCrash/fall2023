package model

// Cell describes a cell in the database.
type Cell struct {
	Name         string         `json:"name"`
	Smiley       string         `json:"smiley"`
	Recents      map[string]int `json:"recents"`
	Totals       map[string]int `json:"totals"`
	Destinations []string       `json:"destinations"`
}
