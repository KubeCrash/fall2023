#!/bin/env bash

# Create certificates to secure communication between CockroachDB nodes.
# Note that while Linkerd will provide a secure channel between pods, unless
# CockroachDB nodes are created in secure mode (i.e. without the --insecure flag)
# password authentication won't be available for uses.

mkdir certs keys

cockroach cert create-ca \
   --certs-dir=certs \
   --ca-key=keys/ca.key

cockroach cert create-client \
   root \
   --certs-dir=certs \
   --ca-key=keys/ca.key

kubectl create secret \
   generic cockroachdb.client.root \
   --from-file=certs \
   --context us-east \
   --namespace crdb

kubectl create secret \
   generic cockroachdb.client.root \
   --from-file=certs \
   --context us-west \
   --namespace crdb

kubectl create secret \
   generic cockroachdb.client.root \
   --from-file=certs \
   --context eu-central \
   --namespace crdb


cockroach cert create-node \
   localhost 127.0.0.1 \
   cockroachdb-public \
   cockroachdb-public.us-east \
   cockroachdb-public.us-east.svc.cluster.local \
   "*.cockroachdb" \
   "*.cockroachdb.us-east" \
   "*.cockroachdb.us-east.svc.cluster.local" \
   --certs-dir=certs \
   --ca-key=keys/ca.key

kubectl create secret \
   generic cockroachdb.node \
   --from-file=certs \
   --context us-east \
   --namespace crdb

rm certs/node.crt
rm certs/node.key


cockroach cert create-node \
   localhost 127.0.0.1 \
   cockroachdb-public \
   cockroachdb-public.us-west \
   cockroachdb-public.us-west.svc.cluster.local \
   "*.cockroachdb" \
   "*.cockroachdb.us-west" \
   "*.cockroachdb.us-west.svc.cluster.local" \
   --certs-dir=certs \
   --ca-key=keys/ca.key

kubectl create secret \
   generic cockroachdb.node \
   --from-file=certs \
   --context us-west \
   --namespace crdb

rm certs/node.crt
rm certs/node.key


cockroach cert create-node \
   localhost 127.0.0.1 \
   cockroachdb-public \
   cockroachdb-public.eu-central \
   cockroachdb-public.eu-central.svc.cluster.local \
   "*.cockroachdb" \
   "*.cockroachdb.eu-central" \
   "*.cockroachdb.eu-central.svc.cluster.local" \
   --certs-dir=certs \
   --ca-key=keys/ca.key

kubectl create secret \
   generic cockroachdb.node \
   --from-file=certs \
   --context eu-central \
   --namespace crdb

rm certs/node.crt
rm certs/node.key