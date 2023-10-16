## WORLD DEMO

This is the World demo.

**It is very much WIP.**

You'll need `kubectl`, `linkerd`, and `step` to run this.

linkerd — https://linkerd.io/2/getting-started/
step — https://smallstep.com/docs/step-cli/installation

### Local

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

CONNECTION_STRING=postgres://world_service:EcSljwBeVIG42KLO0LS3jtuh9x6RMcOBZEWFSk@localhost:26257/the_world?sslmode=allow \
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

### Docker

Create a docker image

``` sh
(cd server && docker build -t the-world .)
```

Run the docker image

``` sh
docker run --rm -it \
   --name the-world \
   -p 8888:8888 \
   -e CONNECTION_STRING="postgres://world_service:EcSljwBeVIG42KLO0LS3jtuh9x6RMcOBZEWFSk@host.docker.internal:26257/the_world?sslmode=allow" \
      the-world
```

### Kubernetes

#### Create the cluster with Linkerd and Emissary

``` sh
bash ./create-clusters.sh
bash ./setup-linkerd.sh
bash ./setup-cockroach.sh
bash ./setup-emissary.sh
```

#### Set up the World

``` sh
bash ./setup-world.sh
```

After that you can e.g. `open http://localhost:8080/world/` to get the us-east
GUI. The us-west GUI is on port 8081; eu-central is on 8082.

**Note:** the GUI is inefficient right now; every couple of seconds, it just
reloads the world, which isn't necessarily all that nice to the database. This
is very low on my priority list. [ :) ]

#### Run a player

``` sh
cd the-world/server
PLAYER_NAME=US go run .
```

This needs proper command line handling by now. Also note that players are
always North American right now, which is part of why we need proper
command-line handling (or we need to just derive the region from the player
name).

#### Random debugging stuff

Enter bash shell

``` sh
kubectl exec \
   --context eu-central \
   -it cockroachdb-0 -c cockroachdb \
   --namespace cockroachdb \
   -- bash
```

Enter SQL shell

``` sh
kubectl exec \
   --context eu-central \
   -it cockroachdb-0 -c cockroachdb \
   --namespace cockroachdb \
   -- cockroach sql --url "postgres://root@localhost:26257/defaultdb?sslmode=verify-full&sslrootcert=/cockroach/cockroach-certs/ca.crt&sslcert=/cockroach/cockroach-certs/client.root.crt&sslkey=/cockroach/cockroach-certs/client.root.key"
```

Create user

``` sql
CREATE USER rob WITH LOGIN PASSWORD 'password';
GRANT ALL ON DATABASE defaultdb TO rob WITH GRANT OPTION;
GRANT SYSTEM ALL PRIVILEGES TO rob;
```

Enable enterprise features

``` sql
SELECT crdb_internal.cluster_id();
-- crl-lic -months 1 -org 'KubeCrash 2023' -type 'Evaluation' <CLUSTER_ID>
SET CLUSTER SETTING cluster.organization = '';
SET CLUSTER SETTING enterprise.license = '';
```

Port forward to HTTP port, open browser, and login

``` sh
kubectl port-forward svc/cockroachdb-public 8080:8080 -n cockroachdb
```

#### Cleanup

To just shred CockroachDB's tables and reinitialize, run

``` sh
bash deinit-cockroachdb.sh
bash init-cockroachdb.sh
```

``` sh
k3d cluster delete us-east
k3d cluster delete us-west
k3d cluster delete eu-central
```

Or if you just want to reinstall CockroachDB:

``` sh
kubectl delete --context eu-central ns cockroachdb
kubectl delete --context us-east ns cockroachdb
kubectl delete --context us-west ns cockroachdb
```

Then rerun `setup-cockroachdb.sh` and rerun the `linkerd inject | kubectl
apply` commands for CockroachDB.

``` sh
rm -rf certs
rm -rf my-safe-directory
```
