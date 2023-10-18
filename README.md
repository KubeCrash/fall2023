## WORLD DEMO

This is the World demo.

**It is very much WIP.**

You'll need `kubectl`, `linkerd`, and `step` to run this.

linkerd — https://linkerd.io/2/getting-started/
step — https://smallstep.com/docs/step-cli/installation

The World demo uses three clusters, named us-east, us-west, and eu-central.
By default, all three are created using k3d.

## K3d

### Setting Up the Infrastructure

``` sh
bash ./create-clusters.sh  # Create the clusters
bash ./setup-linkerd.sh    # Set up Linkerd to connect them all
bash ./setup-cockroach.sh  # Fire up CockroachDB
bash ./setup-emissary.sh   # Set up Emissary for ingress
```

### Start up the Application

For this next bit, you can set `DOCKER_REGISTRY` to something you can push to
(like `DOCKER_REGISTRY=docker/dwflynn`) to use images in that registry, or you
can leave `DOCKER_REGISTRY` unset to use `k3d image load` for your images
instead.

``` sh
bash ./setup-world.sh
```

After that you can e.g. `open http://localhost:8080/world/` to get the us-east
GUI. The us-west GUI is on port 8081; eu-central is on 8082.

You will have to authenticate. There are five users:

`ca`, password `ca`: a North American user shown by an Canadian flag
`de`, password `de`: a European user shown by a German flag
`es`, password `es`: a European user shown by a Spanish flag
`us`, password `us`: a North American user shown by an American flag
`world`, password `world`: a special user who gets to see everything

**Who you log in as matters**. The GUI will show you users wandering North
America and Europe (sort of). Each user marks a smiley into the cell they're
visiting, and also changes the background color: North American users make the
background more red, European users make the background more green. **However,
North American users only get to see background colors for North America, and
European users only get to see background colors for Europe.** The `world`
user gets to see everything.

Also, if you connect to a North American Emissary (the Emissaries running in
`us-east` or `us-west`) and then log in as a European user, you'll get
redirected to the Emissary in `eu-central`. Same goes if you log into a North
American user when talking to the `eu-central` Emissary.

**Note:** the GUI is inefficient right now; every couple of seconds, it just
reloads the world, which isn't necessarily all that nice to the database. This
is an area for future improvement.

### Run a player

We start four players (CA, DE, ES, and US) running inside the cluster. You can
start more:

``` sh
cd the-world/server
go run . --player US
```

though at the moment the only valid players are US, CA, DE, and ES.

US and CA are in the North American region, DE and ES are in the European
region. They are represented by country flags. If you want to support
additional players, see the-world/server/player/player.go.

## Civo

You can also set up to run with Civo clusters. (Everything after step 1 should
also work with other cloud clusters.)

### 1. Create Civo clusters named `us-east`, `us-west`, and `eu-central`.

(If you're using another cloud provider, just make sure you have the correct
context names for your clusters.)

``` sh
bash ./create-civo.sh
```

### 2. Install Linkerd

`CLUSTER_TYPE` tells the setup script that we're using a Civo cluster
(honestly, this could be anything other than 'k3d'):

``` sh
CLUSTER_TYPE=civo bash ./setup-linkerd.sh
```

### 3. Install CockroachDB

We don't need to do anything weird for CockroachDB.

``` sh
bash ./setup-cockroach.sh
```

### 4. Start Emissary

Here we explicitly use gateway mirroring for Emissary's cross-cluster
stuff. (If you used your own cloud and configured flat-network multicluster, you
can skip setting `MIRROR_TYPE`.)

``` sh
MIRROR_TYPE=gateway bash ./setup-emissary.sh
```

### 5. Set up the Application

You'll need to provide your own DOCKER_REGISTRY and WORLD_VERSION here, and
you'll need a working multiplatform `docker buildx build`, because you need to
actually push the built images somewhere for cloud provider clusters.

**Don't forget to bump the version when you do new builds.**

``` sh
DOCKER_REGISTRY=... WORLD_VERSION=... bash ./setup-world.sh
```

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
bash do-sql.sh
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

#### Reset database state

To reset the world to a blank grey grid:

``` sh
bash reset-world.sh
```

#### Redeploy the world

To rebuild & redeploy the world (maybe you changed the GUI or the Go code):

``` sh
kubectl delete --context eu-central ns world
kubectl delete --context us-east ns world
kubectl delete --context us-west ns world
bash setup-world.sh
```

#### Drop CockroachDB tables and reinitialize

To just shred CockroachDB's tables and reinitialize, run

``` sh
bash deinit-cockroachdb.sh
bash init-cockroachdb.sh
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
