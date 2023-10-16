/*
 * Copyright 2023 Datawire. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*
 * Example auth service for Emissary-Ingress[1] using ExtAuth[2].
 * [1]: https://www.getambassador.io/docs/emissary
 * [2]: https://www.getambassador.io/docs/emissary/latest/topics/running/services/ext-authz#extauth-protocol
*/

const express = require('express')
const app = express()
const addRequestId = require('express-request-id')()
const auth = require('basic-auth')

// Set up authentication middleware
const basicAuth = require('express-basic-auth')
const authenticate = basicAuth({
    'users': {
        'us': 'us',
        'ca': 'ca',
        'es': 'es',
        'de': 'de',
        'world': 'world',
    },
    'challenge': true,
    'realm': 'Ambassador Realm'
})

const region = process.env.REGION

// Always have a request ID.
app.use(addRequestId)

// Add verbose logging of requests (see below)
app.use(logRequests)

// Get authentication path from env, default to /extauth
let authPath = '/extauth'
if ('AUTH_PATH' in process.env) {
    authPath = process.env.AUTH_PATH
}
console.log(`setting authenticated path to: ${authPath}`)

// Do regional routing based on user
app.all(authPath.concat('*'), function (req, res, next) {
    const usServers = /us|ca/
    const euServers = /es|de/
    const authentication = auth(req)

    // pass request on if there's an existing region target that matches our region
    if (req.get('x-region-target') === region) {
        console.log('region matches, passing on request')
        next()
        return
    }

    if (!authentication || !authentication.name) {
        next()
        return
    }

    if (usServers.test(authentication.name) && region === 'eu') {
        console.log('setting target region to us')
        res.set('x-region-target', 'us')
    } else if (euServers.test(authentication.name) && region === 'us') {
        console.log('setting target region to eu')
        res.set('x-region-target', 'eu')
    }

    next()
})

// Require authentication for authPath requests
app.all(authPath.concat('*'), authenticate, function (req, res) {
    var session = req.headers['x-world-session']

    if (!session) {
        console.log(`creating x-world-session: ${req.id}`)
        session = req.id
        res.set('x-world-session', session)
    }

    console.log(`allowing World request, session ${session}`)
    res.send('OK (authenticated)')
})



// Everything else is okay without auth
app.all('*', function (req, res) {
    console.log(`Allowing request to ${req.path}`)
    res.send(`OK (not ${authPath})`)
})

app.listen(3000, function () {
    console.log('Subrequest auth server sample listening on port 3000')
})

// Middleware to log requests, including basic auth header info
function logRequests (req, res, next) {
    console.log('\nNew request')
    console.log(`  Path: ${req.path}`)
    console.log(`  Incoming headers >>>`)
    Object.entries(req.headers).forEach(
        ([key, value]) => console.log(`    ${key}: ${value}`)
    )

    // Check for expected authorization header
    const auth = req.headers['authorization']
    if (!auth) {
        console.log('  No authorization header')
        return next()
    }
    if (!auth.toLowerCase().startsWith('basic ')) {
        console.log('  Not Basic Auth')
        return next()
    }

    // Parse authorization header
    const userpass = Buffer.from(auth.slice(6), 'base64').toString()
    console.log(`  Auth decodes to "${userpass}"`)
    const splitIdx = userpass.search(':')
    if (splitIdx < 1) {  // No colon or empty username
        console.log('  Bad authorization format')
        return next()
    }

    // Extract username and password pair
    const username = userpass.slice(0, splitIdx)
    const password = userpass.slice(splitIdx + 1)
    console.log(`  Auth user="${username}" pass="${password}"`)
    return next()
}
