//////// Utilities
//
// Sucking in all of jQuery is massive overkill, but the $() shorthand
// is really nice, so...
export function $(id) {
    return document.getElementById(id)
}

// getCookie (from MDN) clearly demonstrates why we can't have nice things.

export function getCookie(name) {
    // Split cookie string and get all individual name=value pairs in an array
    var cookieArr = document.cookie.split(";");

    // Loop through the array elements
    for(var i = 0; i < cookieArr.length; i++) {
        var cookiePair = cookieArr[i].split("=");

        /* Removing whitespace at the beginning of the cookie name
        and compare it with the given string */
        if(name == cookiePair[0].trim()) {
            // Decode the cookie value and return
            return decodeURIComponent(cookiePair[1]);
        }
    }

    // Return null if not found
    return null;
}

//////// Logger
//
// Logger is a simple logging class. It logs datestamped text to
// the console and to its div (where it's colored for semantics).

export class Logger {
    constructor(logdiv) {
        // this.logdiv = logdiv	// not an ID, the div itself
        this.info("Startup")
    }

    // logmsg does most of the heavy lifting.
    logmsg(color, msg) {
        let now = new Date().toISOString()
        console.log(`${now} ${msg}`)
        // this.logdiv.innerHTML = `<span class="${color}">${now}: ${msg}</span><br/>` + this.logdiv.innerHTML
    }

    // success, fail, and info are wrappers around logmsg to avoid
    // having to always pass the color by hand.

    success(msg) {
        this.logmsg("green", msg)
    }

    fail(msg) {
        this.logmsg("red", msg)
    }

    info(msg) {
        this.logmsg("grey", msg)
    }
}
