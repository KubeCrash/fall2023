#!/bin/env bash

# Create certificates to secure communication between CockroachDB nodes.
# Note that while Linkerd will provide a secure channel between pods, unless
# CockroachDB nodes are created in secure mode (i.e. without the --insecure flag)
# password authentication won't be available for uses.

set -x

kubectl create namespace cockroachdb --context eu-central
kubectl create namespace cockroachdb --context us-east
kubectl create namespace cockroachdb --context us-west

mkdir certs my-safe-directory

cockroach cert create-ca \
  --certs-dir=certs \
  --ca-key=my-safe-directory/ca.key

cockroach cert create-client \
  root \
  --certs-dir=certs \
  --ca-key=my-safe-directory/ca.key

# These are writing secrets into the K8s cluster, rather than
# into the local filesystem.

kubectl create secret \
  generic cockroachdb.client.root \
  --from-file=certs \
  --context eu-central \
  --namespace cockroachdb

kubectl create secret \
  generic cockroachdb.client.root \
  --from-file=certs \
  --context us-east \
  --namespace cockroachdb

kubectl create secret \
  generic cockroachdb.client.root \
  --from-file=certs \
  --context us-west \
  --namespace cockroachdb


cockroach cert create-node \
  localhost 127.0.0.1 \
  cockroachdb-0-eu-central \
  cockroachdb-1-eu-central \
  cockroachdb-2-eu-central \
  cockroachdb-public \
  cockroachdb-public.eu-central \
  cockroachdb-public.eu-central.svc.eu-central \
  "*.cockroachdb" \
  "*.cockroachdb.eu-central" \
  "*.cockroachdb.eu-central.svc.eu-central" \
  --certs-dir=certs \
  --ca-key=my-safe-directory/ca.key

kubectl create secret \
  generic cockroachdb.node \
  --from-file=certs \
  --context eu-central \
  --namespace cockroachdb

rm certs/node.crt
rm certs/node.key


cockroach cert create-node \
  localhost 127.0.0.1 \
  cockroachdb-0-us-east \
  cockroachdb-1-us-east \
  cockroachdb-2-us-east \
  cockroachdb-public \
  cockroachdb-public.us-east \
  cockroachdb-public.us-east.svc.us-east \
  "*.cockroachdb" \
  "*.cockroachdb.us-east" \
  "*.cockroachdb.us-east.svc.us-east" \
  --certs-dir=certs \
  --ca-key=my-safe-directory/ca.key

kubectl create secret \
  generic cockroachdb.node \
  --from-file=certs \
  --context us-east \
  --namespace cockroachdb

rm certs/node.crt
rm certs/node.key


cockroach cert create-node \
  localhost 127.0.0.1 \
  cockroachdb-0-us-west \
  cockroachdb-1-us-west \
  cockroachdb-2-us-west \
  cockroachdb-public \
  cockroachdb-public.us-west \
  cockroachdb-public.us-west.svc.us-west \
  "*.cockroachdb" \
  "*.cockroachdb.us-west" \
  "*.cockroachdb.us-west.svc.us-west" \
  --certs-dir=certs \
  --ca-key=my-safe-directory/ca.key

kubectl create secret \
  generic cockroachdb.node \
  --from-file=certs \
  --context us-west \
  --namespace cockroachdb

rm certs/node.crt
rm certs/node.key
