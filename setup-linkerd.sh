#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: 2022 Buoyant Inc.
# SPDX-License-Identifier: Apache-2.0
#
# Copyright 2022 Buoyant Inc.
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

#@SHOW

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

# Assume that we're on k3d, but allow overriding.
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

#### LINKERD_INSTALL_START

gen_anchor
gen_issuer us-east
gen_issuer us-west
gen_issuer eu-central

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

set -x

for ctx in us-east us-west eu-central; do \
    linkerd --context=$ctx multicluster install $GATEWAY \
        | kubectl --context $ctx apply -f - ;\
done

for ctx in us-east us-west eu-central; do \
    linkerd --context=$ctx check ;\
done

# Link clusters.
# Note that this bit with overriding the API server address is just a thing
# for k3d.

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

set -x

# This looks completely bizarre, I know, but we're going to link
# each cluster to _all three clusters_. Why? It's the way to make
# get ClusterIP services for each pod in each cluster. Horrible,
# but yeah.

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
