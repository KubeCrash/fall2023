package player

import (
	"encoding/json"
	"fmt"
	"io"
	"math/rand"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/buoyantio/flag-demo/server/model"
)

type Player struct {
	BaseURL string
	Name    string
	Region  string
	Smilies []string

	sleepTime  time.Duration
	cellVisits map[string]int
}

func New(baseURL string, name string, region string, smilies []string) *Player {
	p := &Player{
		BaseURL: baseURL,
		Name:    name,
		Region:  region,
		Smilies: smilies,

		sleepTime: 4 * time.Second,
	}

	p.cellVisits = make(map[string]int)

	return p
}

func (player *Player) Run() {
	fmt.Printf("Starting player %s (%#v)...\n", player.Name, player)

	// Start by grabbing our starting location.
	currentLocation, err := player.getLocation()

	if err != nil {
		fmt.Printf("%s: location failed: %v\n", player.Name, err)
		return
	}

	fmt.Printf("%s: start at %s\n", player.Name, currentLocation)

	for {
		smiley := player.randomSmiley()
		cell, err := player.visit(currentLocation, smiley)

		if err != nil {
			fmt.Printf("%s: visit failed: %v\n", player.Name, err)
			break
		}

		if len(cell.Destinations) == 0 {
			fmt.Printf("%s: dead end visiting %s??\n", player.Name, currentLocation)
			break
		}

		// Update our cell visit count. Go will start the value at 0 for us if
		// this cell isn't in the map yet, so this is pretty simple.
		player.cellVisits[cell.Name]++

		// Find the minimum number of visits for any destination...
		foundMinimum := false
		minVisits := 0

		for _, dest := range cell.Destinations {
			visitCount := player.cellVisits[dest]

			if !foundMinimum || (visitCount < minVisits) {
				minVisits = visitCount
				foundMinimum = true
			}
		}

		// ...then make an ordered array of candidates that are at the
		// minimum visit count.
		candidates := make([]string, 0, len(cell.Destinations))

		for _, dest := range cell.Destinations {
			visitCount := player.cellVisits[dest]

			if visitCount == minVisits {
				candidates = append(candidates, dest)
			}
		}

		// Finally, pick a random destination from that array.
		currentLocation = candidates[rand.Intn(len(candidates))]

		fmt.Printf("%s: ", player.Name)

		for _, dest := range cell.Destinations {
			fmt.Printf("%s (%d) ", dest, player.cellVisits[dest])
		}

		fmt.Printf("-> ")

		for _, dest := range candidates {
			fmt.Printf("%s ", dest)
		}

		fmt.Printf("=> %s\n", currentLocation)
		time.Sleep(player.sleepTime)
	}
}

func (player *Player) randomSmiley() string {
	return player.Smilies[rand.Intn(len(player.Smilies))]
}

func (player *Player) getLocation() (string, error) {
	// url := fmt.Sprintf("%s/location?player=%s", player.BaseURL, url.QueryEscape(player.Name))
	url := fmt.Sprintf("%s/cells/", player.BaseURL)

	fmt.Printf("Getting location for %s: %s\n", player.Name, url)
	req, err := http.NewRequest("GET", url, nil)

	if err != nil {
		return "", fmt.Errorf("Error creating location request: %w", err)
	}

	req.SetBasicAuth(strings.ToLower(player.Name), strings.ToLower(player.Name))

	resp, err := http.DefaultClient.Do(req)

	if err != nil {
		return "", fmt.Errorf("Error getting location: %w", err)
	}

	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("Error getting location: %s", resp.Status)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("Error reading location response: %w", err)
	}

	var world *model.World
	err = json.Unmarshal(body, &world)
	if err != nil {
		return "", fmt.Errorf("Error parsing location response: %w", err)
	}

	// Do we have a location?
	location, exists := world.Locations[player.Name]

	if !exists {
		// No extant location, so return a random key from the cells map
		cellNames := make([]string, 0, len(world.Cells))

		for k := range world.Cells {
			cellNames = append(cellNames, k)
		}

		fmt.Printf("Cells: %d - %#v\n", len(cellNames), cellNames)

		location = cellNames[rand.Intn(len(cellNames))]
	}

	return string(location), nil
}

func (player *Player) visit(location string, smiley string) (*model.Cell, error) {
	fmt.Printf("%s: visiting %s with %s\n", player.Name, location, smiley)

	url := fmt.Sprintf("%s/cells/%s/visit?player=%s&smiley=%s&region=%s",
		player.BaseURL, location,
		url.QueryEscape(player.Name),
		url.QueryEscape(smiley),
		url.QueryEscape(player.Region))

	req, err := http.NewRequest("POST", url, nil)

	if err != nil {
		return nil, fmt.Errorf("Error creating location request: %w", err)
	}

	req.SetBasicAuth(strings.ToLower(player.Name), strings.ToLower(player.Name))
	req.Header.Add("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)

	if err != nil {
		return nil, fmt.Errorf("Error visiting cell: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("HTTP error visiting cell: %s", resp.Status)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("Error reading visit response: %w", err)
	}

	var cell model.Cell
	err = json.Unmarshal(body, &cell)
	if err != nil {
		return nil, fmt.Errorf("Error parsing visit response: %w", err)
	}

	return &cell, nil
}
