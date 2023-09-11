#!/usr/bin/env python

# This is the basis of CSS grids used for the world. It doesn't produce valid
# CSS; it produces a starting point. Ish.

import sys

def main():
    pfx = sys.argv[1]
    rows = int(sys.argv[2])
    cols = int(sys.argv[3])

    idx = 0

    allcells = []

    for _ in range(rows):
        cells = []

        for _ in range(cols):
            cellid = "%s%02d" % (pfx, idx)
            cells.append(cellid)
            allcells.append(cellid)

            idx += 1

        print('    "%s"' % ' '.join(cells))

    print()

    for cell in allcells:
        print(".%s { grid-area: %s }" % (cell, cell))

    print()

    print("    <div id=\"%s-container\" class=\"map %s-map\">" % (pfx, pfx))
    print("        <div id=\"%s-grid\" class=\"%s-grid\">" % (pfx, pfx))

    for cell in allcells:
        print("            <div id=\"%s\" class=\"cell %s %s\">" % (cell, pfx, cell))
        print("                <div id=\"%s-content\"></div>" % cell)
        print("                <div id=\"%s-player\" class=\"player-marker\"></div>" % cell)
        print("            </div>")

    print("        </div>")
    print("    </div>")

if __name__ == '__main__':
    main()
