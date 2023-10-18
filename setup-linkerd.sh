#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: 2023 Buoyant Inc.
# SPDX-License-Identifier: Apache-2.0
#
# Copyright 2023 Buoyant Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License.  You may obtain
# a copy of the License at
#
#     http:#www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This sets up Linkerd for the World demo. It assumes that you have Kubernetes
# contexts named 'us-east', 'us-west', and 'eu-central', and that they can
# talk to each other in some way. You can tune this script using environment
# variables, but for the World, _probably_ all you want to do is to set
# CLUSTER_TYPE to something other than "k3d" if you're not using k3d clusters
# on a flat network.
#
# - Set CUSTOM_DOMAINS to  a non-empty value to use custom cluster domains for
#   each cluster. This will happen automatically if you set CLUSTER_TYPE to
#   "k3d", which is its default.
#
# - Set FLAT_NETWORKS to a non-empty value to disable gateways between
#   clusters. For the World demo, you should not do this (since CockroachDB
#   needs the gateways at the moment).
#
# - Set DISABLE_HEADLESS to a non-empty value to disable headless services.
#   This is another thing you should not do right now for the World.

# gen_anchor and gen_issuer use the "step" CLI to make certificates for
# Linkerd. THIS IS NOT PRODUCTION READY: you should be using cert-manager
# or the like. For this demo, it's fine.

gen_anchor () {
    rm -rf trust-anchor.crt trust-anchor.key

    step certificate create \
         --profile root-ca --no-password --insecure \
         --not-after='87600h' \
         root.linkerd.cluster.local \
         trust-anchor.crt trust-anchor.key
}

gen_issuer () {
    domain=$1

    rm -rf "issuer-${domain}.crt" "issuer-${domain}.key"

    step certificate create \
         --profile intermediate-ca --no-password --insecure \
         --ca trust-anchor.crt --ca-key trust-anchor.key \
         --not-after='2160h' \
         identity.linkerd.${domain} \
         "issuer-${domain}.crt" "issuer-${domain}.key"
}

# Handle tuning variables. Start by assuming that we're on k3d, but allow
# overriding.

if [ -z "$CLUSTER_TYPE" ]; then
    CLUSTER_TYPE=k3d
    CUSTOM_DOMAINS=true
fi

GATEWAY=

if [ -n "$FLAT_NETWORKS" ]; then
    GATEWAY="--gateway=false"
fi

LINK_ARGS="--set enableHeadlessServices=true"

if [ -n "$DISABLE_HEADLESS" ]; then
    LINK_ARGS=
fi

#### LINKERD INSTALLATION

# First, set up certificates.

gen_anchor
gen_issuer us-east
gen_issuer us-west
gen_issuer eu-central

# Next, just walk over the different contexts and install Linkerd. Most of
# this is straight out of the Linkerd quickstart; the custom-domains part is
# the main difference here.

for ctx in us-east us-west eu-central; do \
    domain="${ctx}" ;\
    CLUSTER_DOMAIN= ;\
    if [ -n "$CUSTOM_DOMAINS" ]; then \
        CLUSTER_DOMAIN="--cluster-domain ${domain}" ;\
    fi ;\
    linkerd --context=$ctx install --crds | kubectl --context $ctx apply -f - ;\
    linkerd --context=$ctx install \
        $CLUSTER_DOMAIN \
        --identity-trust-anchors-file trust-anchor.crt \
        --identity-issuer-certificate-file "issuer-${domain}.crt" \
        --identity-issuer-key-file "issuer-${domain}.key" \
        | kubectl --context $ctx apply -f - ;\
done

# Next, walk contexts and install the Linkerd multicluster extension. We do
# this after the main Linkerd install to minimize waiting time: if we
# installed multicluster in the loop above, we'd be waiting for each control
# plane to get ready in series, rather than in parallel.

for ctx in us-east us-west eu-central; do \
    linkerd --context=$ctx multicluster install $GATEWAY \
        | kubectl --context $ctx apply -f - ;\
done

# Finally, run linkerd check to make sure everything is working.

for ctx in us-east us-west eu-central; do \
    linkerd --context=$ctx check ;\
done

# Link the clusters together. This looks more complex than it is because, for
# k3d, we need to override the APIserver address that Linkerd multicluster
# will try to use -- this is because of the way k3d's networking works.
# Basically, we grab the IP address of the server node in each cluster _on the
# shared Docker network_; that's where we need to talk to the APIserver.

USEAST_APISERVER=
USWEST_APISERVER=
EUCENTRAL_APISERVER=

apiserver_addr () {
    ctx="$1"

    addr=$(kubectl --context $ctx get node k3d-$ctx-server-0 -o jsonpath='{.status.addresses[?(.type=="InternalIP")].address}')
    echo "--api-server-address=https://${addr}:6443"
}

if [ "$CLUSTER_TYPE" = "k3d" ]; then
    USEAST_APISERVER=$(apiserver_addr us-east)
    USWEST_APISERVER=$(apiserver_addr us-west)
    EUCENTRAL_APISERVER=$(apiserver_addr eu-central)
fi

# This looks completely bizarre, I know, but we're going to link each cluster
# to _all three clusters_. Why? It's the way to make get ClusterIP services
# for each pod in each cluster, which is important for CockroachDB because it
# needs to have a single name for each CockroachDB node that's resolvable in
# every cluster.

for ctx in us-east us-west eu-central; do \
    linkerd --context=us-east multicluster link \
            --cluster-name us-east \
            $GATEWAY $LINK_ARGS $USEAST_APISERVER \
            | kubectl --context $ctx apply -f - ;\

    linkerd --context=us-west multicluster link \
            --cluster-name us-west \
            $GATEWAY $LINK_ARGS $USWEST_APISERVER \
            | kubectl --context $ctx apply -f - ;\

    linkerd --context=eu-central multicluster link \
            --cluster-name eu-central \
            $GATEWAY $LINK_ARGS $EUCENTRAL_APISERVER \
            | kubectl --context $ctx apply -f - ;\
done
