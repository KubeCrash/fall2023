// Request is a class that represents a request to the server.

export class Request {
    constructor(method, url, param, name, callback) {
        this.method = method
        this.url = url
        this.name = name
        this.param = param
        this.latency = -1       // This will be filled in with latency after the request completes.
        this.response = null    // This will be filled in with the parsed JSON response.
        this.status = null      // This will be filled in with the HTTP status code.
        this.ok = false         // This will be set to true if the request succeeded (HTTP 200).
        this.complete = false   // Set to true when the request is complete.
        this.callback = callback    // Called on completion.

        this.xhr = new XMLHttpRequest();
        let sentAt = new Date().getTime()

        this.xhr.addEventListener("load", () => {
			// This is the success case: our XHR succeeded in that we got an HTTP
            // response. Of course, the response may itself be a failure.
			//
			// Start by figuring out how long it took to get the response...
			let now = new Date()
			this.latency = now - sentAt

            // ...and then figure out what the HTTP status was.
            this.status = this.xhr.status

            // If the status is 200, then we got a successful response and we need to
            // parse the response text as JSON.

            if (this.status == 200) {
                // Try to parse the JSON response.
                try {
                    // console.log("Response: " + this.xhr.responseText)
                    this.response = JSON.parse(this.xhr.responseText)
                    this.ok = true
                }
                catch (e) {
                    // Huh, that ain't good.
                    this.status = 500
                    this.ok = false
                    this.response = { error: `Failed to parse JSON response: ${e}` }
                }
            }
            else {
                // The response was not 200, so we need to construct an error response.
                this.response = { error: `HTTP status ${this.status}` }
                this.ok = false
            }

            // Let our caller know we're done.
            this.callback(this)
        })

        this.xhr.addEventListener("error", () => {
			// This is the failure case: something went wrong. A really
			// annoying thing about XHR is that we don't get anything useful
			// about _what_ went wrong, but, well, c'est la vie.
			//
			// Start, again, with the latency...
			let now = new Date()
			this.latency = now - this.sentAt

            // ...and then just show that something failed.
            this.status = 999
            this.ok = false
            this.response = { error: "XHR error" }

            // Let our caller know we're done.
            this.callback(this)
		})

        // OK, fire it up. This business with appending the date as a
		// query-string is because Safari (at least) just _refuses_ to pay
		// attention to the Cache-Control header we add below, and we _really_
		// don't want this to be cached.
		//
		// Safari is why we can't have nice things.
		let now = new Date().toISOString()
        let fullURL = `${this.url}?now=${now}`

        if ((param != null) && (param != "")) {
            fullURL = `${fullURL}&${param}`
        }

        // console.log(`Request: ${this.method} ${fullURL}`)
        this.xhr.open(this.method, fullURL)
	    this.xhr.setRequestHeader("Cache-Control", "no-cache, no-store, max-age=0");

		// We must send credentials...
		this.xhr.withCredentials = true

		// ...and we really want to be sure that the browser turns on CORS for
		// this, so we use a custom header to force preflighting.
		this.xhr.setRequestHeader("X-Custom-Header", "custom")

		// OK -- save the time we sent the request, and off we go.
		// this.info("Sending XHR...")
		this.sentAt = new Date()
		this.xhr.send();
    }
}

