import { $, Logger } from "./modules/utils.js"
import { Request } from "./modules/request.js"
import { Smilies, Flags } from "./modules/constants.js"

class ToggleSwitch {
    constructor(button, startLabel, stopLabel, onstart, onstop) {
        this.button = button	// not an ID, the button itself
        this.button.onclick = () => { this.toggle() }
        this.startLabel = startLabel
        this.stopLabel = stopLabel
        this.onstart = () => { onstart(this) }
        this.onstop = () => { onstop(this) }
        this.start()
    }

    toggle() {
        if (this.active) {
            this.stop()
        }
        else {
            this.start()
        }
    }

    start() {
        this.active = true
        this.button.value = this.stopLabel
        this.onstart()
    }

    stop() {
        this.active = false
        this.button.value = this.startLabel
        this.onstop()
    }
}


class Player {
    constructor(logger, cellSet, country, region, smilies) {
        this.logger = logger
        this.cellSet = cellSet
        this.country = country
        this.region = region
        this.smilies = smilies
        this.active = false
        this.flag = Flags[country]

        this.cell = null
        this.visited = {}	// map of cell names to how often we've visited that cell
        this.stepScheduled = false
        this.stepDelay = 500 + (Math.random() * 1000)

        this.nextSmiley = null
        this.nextCell = null

        this.init()
    }

    init() {
        if (!this.cellSet.isInitialized()) {
            this.logger.info(`Player ${this.country} WAIT...`)

            setTimeout(() => { this.init() }, Math.random() * 1000)
            return
        }

        this.logger.info(`Player ${this.country} INIT...`)

        this.cell = this.cellSet.randomCellMatchingPrefix(this.region.toLowerCase())

        // Visit the first cell to kick things off.
        this.visit(this.pickSmiley())
    }

    start() {
        this.logger.info(`Player ${this.country} START (cell ${this.cell})`)
        this.active = true
        this.scheduleNextStep()
    }

    stop() {
        this.logger.info(`Player ${this.country} STOP (cell ${this.cell})`)
        this.active = false
    }

    getVisited(cell) {
        if (cell in this.visited) {
            return this.visited[cell]
        } else {
            return 0
        }
    }

    pickSmiley() {
        let idx = Math.floor(Math.random() * this.smilies.length)
        let smiley = this.smilies[idx]  // Use the name of the smiley, not the entity.

        return smiley
    }

    visit(smiley) {
        // First things first: remember that we're in the middle of handling a
        // visit.
        this.visitInProgress = true

        // OK. Note that we're present in a cell: bump the visited count...
        this.visited[this.cell] = this.getVisited(this.cell) + 1

        // ...and show our flag, but make it faded until we hear back from the
        // server.
        this.show(true)

        // Next, post our smiley to the database.
        let baseURL = `http://localhost:8888/cell/${this.cell}/visit`
        let param = `smiley=${smiley}&region=${this.region}`

        new Request("POST", baseURL, param, `player ${this.country}`, (r) => {
            // this.logger.info(`Request completed: ${r.status} latency ${r.latency}ms`)
            // this.logger.info(`Response: ${JSON.stringify(r.response)}`)

            // We're finished one way or the other, so make the flag fully opaque.
            this.show(false)

            if (r.ok) {
                // All's well! Update the cell's display...
                this.cellSet.visit(r.response)

                // ...and choose our next cell, preferring cells we haven't
                // visited often.
                let candidates = []

                for (let cell of r.response.destinations) {
                    let count = this.getVisited(cell)
                    candidates.push({
                        "cell": cell,
                        "count": count
                    })
                }

                // candidates = candidates.filter(c => c.cell != "na00")
                let bestCount = Math.min(...candidates.map(c => c.count))
                let bestCandidates = candidates.filter(c => ((c.count == bestCount)))

                this.nextCell = bestCandidates[Math.floor(Math.random() * bestCandidates.length)].cell
                this.nextSmiley = this.pickSmiley()

                // this.logger.info(`Player ${this.country}: ${this.cell} -> ${this.nextCell}`)
            }
            else {
                // Not OK. We'll just have to try again later.
                this.logger.info(`Player ${this.country} visit failed: ${r.response.error}`)

                this.nextCell = this.cell
                this.nextSmiley = smiley


                this.cellSet.showError(this.cell)
            }

            // In any case, schedule our next step.
            this.scheduleNextStep()
        })
    }

    scheduleNextStep(cell, smiley) {
        // If we're not active, or if there's already a step scheduled, then
        // bail.
        if (!this.active || this.stepScheduled) {
            return
        }

        // OK, remember that a step is scheduled now...
        this.stepScheduled = true

        // ...and actually do it.
        setTimeout(() => { this.step() }, this.stepDelay)
    }

    step() {
        // When we're called, there's no longer a step scheduled...
        this.stepScheduled = false

        // ...and this.nextSmiley and this.nextCell must be set.
        if ((this.nextSmiley == null) || (this.nextCell == null)) {
            this.logger.info(`Player ${this.country} step: no next cell or smiley`)

            // There's not much we can do at this point.
            return
        }

        // OK, all good. Hide our current flag...
        this.hide()

        // ...then update our cell...
        this.cell = this.nextCell
        this.nextCell = null

        // ...and visit it.
        this.visit(this.nextSmiley)
    }

    show(faded) {
        $(`${this.cell}-player`).innerHTML = this.flag
        $(`${this.cell}-player`).style.display = "flex"

        if (faded) {
            $(`${this.cell}-player`).style.opacity = 0.5
        }
        else {
            $(`${this.cell}-player`).style.opacity = 1.0
        }
    }

    hide() {
        $(`${this.cell}-player`).innerHTML = ""
        $(`${this.cell}-player`).style.display = "none"
    }
}

//////// CELLSET
// This represents information about a set of cells in the world.

class CellSet {
    constructor(logger) {
        this.logger = logger

        // When we start up, we don't know what cells exist.
        // We have to read that from the database.
        this.cells = {}
        this.allCells = null
        this.start()
    }

    isInitialized() {
        return this.allCells != null
    }

    start() {
        this.logger.info("CellSet START")
        this.update()
    }

    stop() {
        this.logger.info("CellSet STOP")

        if (this.allCells != null) {
            for (let cell of this.allCells) {
                this.cells[cell].stop()
            }
        }
    }

    // Pick a random cell from this.connmap.
    randomCell() {
        return this.allCells[Math.floor(Math.random() * this.allCells.length)]
    }

    randomCellMatchingPrefix(prefix) {
        let cell = ""
        while (!cell.startsWith(prefix)) {
            cell = this.randomCell()
        }
        return cell
    }

    visit(packet) {
        let cell = packet.name
        let smiley = packet.smiley
        let recents = packet.recents
        let totals = packet.totals

        this.cells[cell].visit(smiley, recents, totals)
    }

    showError(name) {
        this.cells[name].showError()
    }

    update() {
        new Request("GET", "http://localhost:8888/allcells/", "", "world", (r) => {
            if (r.ok) {
                let world = r.response

                if (this.allCells == null) {
                    // We're initializing. First up, save the full list of cells...
                    let allCells = Object.keys(world)

                    // ...then create a Cell object for each one.
                    for (let cell of allCells) {
                        this.cells[cell] = new Cell(this, cell)
                        this.cells[cell].start()
                    }

                    this.allCells = allCells
                    this.logger.info(`CellSet init: ${this.allCells.length} cells`)
                }

                // Now, update each cell.
                for (let cellName of this.allCells) {
                    let cell = world[cellName]

                    if (cell != null) {
                        this.cells[cellName].visit(cell.smiley, cell.recents, cell.totals)
                    }
                    else {
                        this.cells[cellName].clear()
                    }
                }

                this.logger.info(`CellSet update: ${this.allCells.length} cells`)
            }
        })
    }
}

//////// CELL
// This represents a single cell in the world. It's responsible for
// fetching the data for that cell and updating the display.

class Cell {
    constructor(cellSet, cell) {
        this.fadeTime = 60
        this.cellSet = cellSet
        this.logger = cellSet.logger
        this.cell = cell
        this.smiley = ""
        this.recents = {}	// Recent visits
        this.totals = {}	// Total visits
        this.fadeCount = 0
        this.red = 128
        this.green = 128

        this.active = false
        this.logger.info(`Cell ${this.cell} created`)

        this.update()
        // setInterval(() => { this.fade() }, 1000)
    }

    schedule() {
        setTimeout(() => { this.scheduledUpdate() }, 4000 + (Math.random() * 2000))
    }

    start() {
        // this.logger.info(`Cell ${this.cell} START`)
        this.active = true
    }

    stop() {
        // this.logger.info(`Cell ${this.cell} STOP`)
        this.active = false
    }

    scheduledUpdate() {
        this.schedule()

        if (!this.active) {
            return;
        }

        this.update()
    }

    getRecents(region) {
        if (region in this.recents) {
            return this.recents[region]
        } else {
            return 0
        }
    }

    getTotals(region) {
        if (region in this.totals) {
            return this.totals[region]
        } else {
            return 0
        }
    }

    showError() {
        this.smiley = "cursing"
        this.update()
    }

    visit(smiley, recents, totals) {
        this.smiley = smiley
        this.recents = recents
        this.totals = totals
        this.update()
    }

    clear() {
        this.smiley = null
        this.recents = {}
        this.visited = {}
        this.update()
    }

    update() {
        if (this.name == "na00") {
            this.logger.info(`Cell ${this.cell} update`)
        }

        // We are no longer faded, by definition.
        this.fadeCount = 0

        // Use recent info to set the background color.
        let countNA = this.getRecents("NA")
        let countEU = this.getRecents("EU")
        let red = 128
        let green = 128

        // Blend red and green together in proportion of countNA (red) and countEU (green).
        if ((countNA != 0) || (countEU != 0)) {
            red = 128 + Math.floor(127 * countNA / (countNA + countEU))
            green = 128 + Math.floor(127 * countEU / (countNA + countEU))
        }

        this.red = red
        this.green = green

        $(this.cell).style.backgroundColor = `rgb(${red}, ${green}, 128)`

        let smileyEntity = null

        if (this.smiley != null) {
            smileyEntity = Smilies[this.smiley]
        }

        if (smileyEntity != null) {
            $(`${this.cell}-content`).innerHTML = Smilies[this.smiley]
            $(`${this.cell}-content`).style.display = "flex"

        }
        else {
            $(`${this.cell}-content`).innerHTML = ""
            $(`${this.cell}-content`).style.display = "none"
        }
    }

    fade() {
        if (!this.active) {
            return;
        }

        this.fadeCount++

        if (this.fadeCount >= this.fadeTime) {
            this.red = 128
            this.green = 128
        }
        else {
            let deltaR = Math.floor((this.red - 128) * (this.fadeCount / (this.fadeTime * 1.0)))
            let deltaG = Math.floor((this.green - 128) * (this.fadeCount / (this.fadeTime * 1.0)))

            this.red -= deltaR
            this.green -= deltaG
        }

        $(this.cell).style.backgroundColor = `rgb(${this.red}, ${this.green}, 128)`
    }
}

//////// OVERLORD
// This is the main class that controls the whole show.

class Overlord {
    constructor(logger, toggleButton) {
        this.logger = logger
        this.toggleButton = toggleButton
        this.active = false
        this.managed = []
        this.sw = new ToggleSwitch(
            $("btnToggle"), "Start", "Stop",
            () => { this.start() },
            () => { this.stop() }
        )
    }

    addManaged(managed) {
        this.managed.push(managed)

        if (this.active) {
            managed.start()
        } else {
            managed.stop()
        }
    }

    start() {
        this.logger.info("Starting")
        this.active = true

        for (let managed of this.managed) {
            managed.start()
        }
    }

    stop() {
        this.logger.info("Stopping")
        this.active = false

        for (let managed of this.managed) {
            managed.stop()
        }
    }
}

//////// Mainline
//
// When the page loads, we set up the world and fire up a timer to get things
// moving.
window.onload = () => {
    let initialUser = "unknown";
    let logger = new Logger($("log"))

    logger.info(`Page loaded; user ${initialUser}`)

    let overlord = new Overlord(logger, $(btnToggle))

    let cs = new CellSet(logger)
    overlord.addManaged(cs)

    overlord.addManaged(new Player(logger, cs, "US", "NA",
                                    [ "grinning", "smiling-open",
                                      "smiling-closed", "smiling-tightly-closed" ]))
    overlord.addManaged(new Player(logger, cs, "CA", "NA",
                                    [ "innocent", "joy", "sweat-smile", "rofl" ]))
    overlord.addManaged(new Player(logger, cs, "ES", "EU",
                                    [ "smiling", "relieved", "heart-eyes", "shades" ]))
    overlord.addManaged(new Player(logger, cs, "DE", "EU",
                                    [ "rolling-eyes", "thinking", "hand-over-mouth", "shushing" ]))
}