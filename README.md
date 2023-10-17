## WORLD DEMO

This is the World demo.

**It is very much WIP.**

You'll need `kubectl`, `linkerd`, and `step` to run this.

linkerd — https://linkerd.io/2/getting-started/
step — https://smallstep.com/docs/step-cli/installation

The World demo uses three clusters, named us-east, us-west, and eu-central.
By default, all three are created using k3d.

## Setting Up the Infrastructure

``` sh
bash ./create-clusters.sh  # Create the clusters
bash ./setup-linkerd.sh    # Set up Linkerd to connect them all
bash ./setup-cockroach.sh  # Fire up CockroachDB
bash ./setup-emissary.sh   # Set up Emissary for ingress
```

## Start up the Application

For this next bit, you can set `DOCKER_REGISTRY` to something you can push to
(like `DOCKER_REGISTRY=docker/dwflynn`) to use images in that registry, or you
can leave `DOCKER_REGISTRY` unset to use `k3d image load` for your images
instead.

``` sh
bash ./setup-world.sh
```

After that you can e.g. `open http://localhost:8080/world/` to get the us-east
GUI. The us-west GUI is on port 8081; eu-central is on 8082.

**Note:** the GUI is inefficient right now; every couple of seconds, it just
reloads the world, which isn't necessarily all that nice to the database. This
is very low on my priority list. [ :) ]

### Run a player

The GUI won't show you much until one or more players is running.

``` sh
cd the-world/server
go run . --player US
```

Valid players are US, CA, DE, and ES. US and CA are in the North American
region, DE and ES are in the European region. They are represented by country
flags.

### Random debugging stuff

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

Enable CockroachDB enterprise features

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

### Cleanup

#### Drop CockroachDB tables and reinitialize

To just shred CockroachDB's tables and reinitialize, run

``` sh
bash deinit-cockroachdb.sh
bash init-cockroachdb.sh
```

#### Redeploy the world

To rebuild & redeploy the world (maybe you changed the GUI or the Go code):

``` sh
kubectl delete --context eu-central ns world
kubectl delete --context us-east ns world
kubectl delete --context us-west ns world
bash setup-world.sh
```

#### Completely reinstall CockroachDB

To _completely_ delete and reinstall CockroachDB:

``` sh
kubectl delete --context eu-central ns cockroachdb
kubectl delete --context us-east ns cockroachdb
kubectl delete --context us-west ns cockroachdb
bash setup-cockroachdb.sh
```

#### Completely start over

To shred all three clusters and completely start over:

``` sh
k3d cluster delete us-east us-west eu-central
```

Then start over with this README.
