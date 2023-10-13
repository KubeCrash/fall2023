#!/bin/env bash

# Create certificates to secure communication between CockroachDB nodes.
# Note that while Linkerd will provide a secure channel between pods, unless
# CockroachDB nodes are created in secure mode (i.e. without the --insecure flag)
# password authentication won't be available for uses.

set -x

kubectl create namespace eu-central --context eu-central
kubectl create namespace us-east --context us-east
kubectl create namespace us-west --context us-west

mkdir certs my-safe-directory

cockroach cert create-ca \
  --certs-dir=certs \
  --ca-key=my-safe-directory/ca.key

cockroach cert create-client \
  root \
  --certs-dir=certs \
  --ca-key=my-safe-directory/ca.key

kubectl create secret \
  generic cockroachdb.client.root \
  --from-file=certs \
  --context eu-central \
  --namespace eu-central

kubectl create secret \
  generic cockroachdb.client.root \
  --from-file=certs \
  --context us-east \
  --namespace us-east

kubectl create secret \
  generic cockroachdb.client.root \
  --from-file=certs \
  --context us-west \
  --namespace us-west


cockroach cert create-node \
  localhost 127.0.0.1 \
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
  --namespace eu-central

rm certs/node.crt
rm certs/node.key


cockroach cert create-node \
  localhost 127.0.0.1 \
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
  --namespace us-east

rm certs/node.crt
rm certs/node.key


cockroach cert create-node \
  localhost 127.0.0.1 \
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
  --namespace us-west

rm certs/node.crt
rm certs/node.key