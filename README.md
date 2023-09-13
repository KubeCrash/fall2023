## WORLD DEMO

This is the World demo.

**It is very much WIP.** In particular, there's no K8s code at all in here
yet.

What is in here is a single-page web app and a backing Go server that stores
data in SQLite. To play with it:

1. In one shell window:

``` sh
cockroach demo --global --no-example-database --nodes 9
```

And once in the CockroachDB shell, execute the script in create.sql.

2. In a second window:

``` sh
cd the-world/server
go run .
```

Sample requests

``` sh
curl -s "http://localhost:8888/cells"
curl -s "http://localhost:8888/cells/na10"
```

3. In a third window:

``` sh
cd the-world/data
python -m http.server 8081
```

4. Finally, open a web browser to `http://localhost:8081/`. Watch the little
   flags move around and leave trails of smileys.

The US and Canadian flags will turn cells more red. The German and Spanish
flags will turn them more green. All flags will prefer to move to the
neighboring cell they've visited least. There are a few cells where they get
to cross the Atlantic.

To reset everything:

- kill the server
- stop cockroach (the `demo` command doesn't persist anything)
- start cockroach
- restart the server

Finally, the scripts in `the-world/hack` are the basis for some of the more
irritatingly verbose bits.
