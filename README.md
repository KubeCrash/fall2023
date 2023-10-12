## WORLD DEMO

This is the World demo.

**It is very much WIP.** In particular, there's no K8s code at all in here
yet.

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
bash ./setup-emissary.sh
```

#### Create namespaces and certs for the CockroachDB nodes

``` sh
bash setup-cockroach.sh
```

Install CockroachDB into the clusters

``` sh
linkerd inject the-world/k8s/cockroachdb-eu-central.yaml | kubectl apply --context eu-central -f -
linkerd inject the-world/k8s/cockroachdb-us-east.yaml | kubectl apply --context us-east -f -
linkerd inject the-world/k8s/cockroachdb-us-west.yaml | kubectl apply --context us-west -f -
```

Initialise CockroachDB

``` sh
kubectl exec \
   --context eu-central \
   -it cockroachdb-0 -c cockroachdb \
   --namespace cockroachdb \
   -- /cockroach/cockroach init \
      --certs-dir=/cockroach/cockroach-certs
```

#### TBD: Create the initial DB tables, etc.

#### Set up the World

``` sh
bash ./setup-world.sh
kubectl apply -f emissary-yaml
```

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
   -- cockroach sql
```

#### Cleanup

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

then rerun `setup-cockroachdb.sh` and rerun the `linkerd inject | kubectl
apply` commands for CockroachDB.

``` sh
rm *.crt
rm *.key
```