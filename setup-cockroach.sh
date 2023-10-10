#!/bin/env bash

# Create certificates to secure communication between CockroachDB nodes.
# Note that while Linkerd will provide a secure channel between pods, unless
# CockroachDB nodes are created in secure mode (i.e. without the --insecure flag)
# password authentication won't be available for uses.

set -x

rm -rf cockroach
mkdir cockroach cockroach/certs cockroach/keys

cockroach cert create-ca \
   --certs-dir=cockroach/certs \
   --ca-key=cockroach/keys/ca.key

cockroach cert create-client \
   root \
   --certs-dir=cockroach/certs \
   --ca-key=cockroach/keys/ca.key

for ctx in us-east us-west eu-central; do
   kubectl create ns cockroachdb --context $ctx

   kubectl create secret \
      generic cockroachdb.client.root \
      --from-file=cockroach/certs \
      --context $ctx \
      --namespace cockroachdb

   cockroach cert create-node \
      localhost 127.0.0.1 \
      cockroachdb-public \
      cockroachdb-public.cockroachdb \
      cockroachdb-public.cockroachdb.svc \
      cockroachdb-public.cockroachdb.svc.$ctx \
      cockroachdb-0 \
      cockroachdb-0-us-east \
      cockroachdb-0-us-west \
      cockroachdb-0-eu-central \
      cockroachdb-1 \
      cockroachdb-1-us-east \
      cockroachdb-1-us-west \
      cockroachdb-1-eu-central \
      cockroachdb-2 \
      cockroachdb-2-us-east \
      cockroachdb-2-us-west \
      cockroachdb-2-eu-central \
      --certs-dir=cockroach/certs \
      --ca-key=cockroach/keys/ca.key

   kubectl create secret \
      generic cockroachdb.node \
      --from-file=cockroach/certs \
      --context $ctx \
      --namespace cockroachdb

   mkdir cockroach/$ctx-node
   mv cockroach/certs/node.crt cockroach/$ctx-node/
   mv cockroach/certs/node.key cockroach/$ctx-node/
done
