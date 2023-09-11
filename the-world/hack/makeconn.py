#!/usr/bin/env python

# This is the basis of the connection matrix for the world. NA and EU are both
# 6x6 fully-connected grids. The output here is easy to massage into
# server/connections.json.
#
# Note that this script does _not_ generate any connections across the
# Atlantic: it was just simpler to add those by hand.

def make_connections(cells):
    num_rows = len(cells)
    num_cols = len(cells[0])

    for row in range(num_rows):
        assert len(cells[row]) == num_cols, "All rows must have the same number of cells"

        for col in range(num_cols):
            connected = []

            for drow, dcol in [ (-1, 0), (1, 0), (0, -1), (0, 1) ]:
                nrow = row + drow
                ncol = col + dcol

                if nrow >= 0 and nrow < num_rows and ncol >= 0 and ncol < num_cols:
                    connected.append(cells[nrow][ncol])

            print("%s: [ %s ]," % (cells[row][col], ", ".join([ '"%s"' % x for x in connected ])))

def main():
    make_connections(
        [
            [ "na00", "na01", "na02", "na03", "na04", "na05", ],
            [ "na06", "na07", "na08", "na09", "na10", "na11", ],
            [ "na12", "na13", "na14", "na15", "na16", "na17", ],
            [ "na18", "na19", "na20", "na21", "na22", "na23", ],
            [ "na24", "na25", "na26", "na27", "na28", "na29", ],
            [ "na30", "na31", "na32", "na33", "na34", "na35", ],
        ]
    )

    make_connections(
        [
            [ "eu00", "eu01", "eu02", "eu03", "eu04", "eu05", ],
            [ "eu06", "eu07", "eu08", "eu09", "eu10", "eu11", ],
            [ "eu12", "eu13", "eu14", "eu15", "eu16", "eu17", ],
            [ "eu18", "eu19", "eu20", "eu21", "eu22", "eu23", ],
            [ "eu24", "eu25", "eu26", "eu27", "eu28", "eu29", ],
            [ "eu30", "eu31", "eu32", "eu33", "eu34", "eu35", ],
        ]
    )

if __name__ == '__main__':
    main()
