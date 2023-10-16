package model

// Cell describes a cell in the database.
type Cell struct {
	Name         string         `json:"name"`
	Smiley       string         `json:"smiley"`
	Recents      map[string]int `json:"recents"`
	Totals       map[string]int `json:"totals"`
	Destinations []string       `json:"destinations"`
}

// World describes the world as a whole.
type World struct {
	Locations map[string]string `json:"locations"`
	Cells     map[string]*Cell  `json:"cells"`
}
