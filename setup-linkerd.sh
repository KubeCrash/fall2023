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

# Next up: install Emissary-ingress 3.1.0 as the ingress. This is mostly following
# the quickstart, but we force every Deployment to one replica to reduce the load
# on k3d.

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

#### LINKERD_INSTALL_START

gen_anchor
gen_issuer us-east
gen_issuer us-west
gen_issuer eu

for ctx in us-east us-west eu; do \
    domain="${ctx}" ;\
    linkerd --context=$ctx install --crds | kubectl --context $ctx apply -f - ;\
    linkerd --context=$ctx install \
        --cluster-domain "$domain" \
        --identity-trust-anchors-file trust-anchor.crt \
        --identity-issuer-certificate-file "issuer-${domain}.crt" \
        --identity-issuer-key-file "issuer-${domain}.key" \
        | kubectl --context $ctx apply -f - ;\
done

for ctx in us-east us-west eu; do \
    linkerd --context=$ctx multicluster install --gateway=false \
        | kubectl --context $ctx apply -f - ;\
done

for ctx in us-east us-west eu; do \
    linkerd --context=$ctx check ;\
done

# Link clusters.
# Note that this bit with overriding the API server address is just a thing
# for k3d: you shouldn't need this with cloud clusters.
USEAST_APISERVER=$(kubectl --context us-east get node k3d-us-east-server-0 -o jsonpath='{.status.addresses[?(.type=="InternalIP")].address}')
USWEST_APISERVER=$(kubectl --context us-west get node k3d-us-west-server-0 -o jsonpath='{.status.addresses[?(.type=="InternalIP")].address}')
EU_APISERVER=$(kubectl --context eu get node k3d-eu-server-0 -o jsonpath='{.status.addresses[?(.type=="InternalIP")].address}')

# us-east -> us-west and eu
linkerd --context=us-west multicluster link \
        --cluster-name us-west \
        --gateway=false \
        --api-server-address="https://${USWEST_APISERVER}:6443" \
    | kubectl --context=us-east apply -f -

linkerd --context=eu multicluster link \
        --cluster-name eu \
        --gateway=false \
        --api-server-address="https://${EU_APISERVER}:6443" \
    | kubectl --context=us-east apply -f -

# us-west -> us-east and eu
linkerd --context=us-east multicluster link \
        --cluster-name us-east \
        --gateway=false \
        --api-server-address="https://${USEAST_APISERVER}:6443" \
    | kubectl --context=us-west apply -f -

linkerd --context=eu multicluster link \
        --cluster-name eu \
        --gateway=false \
        --api-server-address="https://${EU_APISERVER}:6443" \
    | kubectl --context=us-west apply -f -

# eu -> us-east and us-west
linkerd --context=us-east multicluster link \
        --cluster-name us-east \
        --gateway=false \
        --api-server-address="https://${USEAST_APISERVER}:6443" \
    | kubectl --context=eu apply -f -

linkerd --context=us-west multicluster link \
        --cluster-name us-west \
        --gateway=false \
        --api-server-address="https://${USWEST_APISERVER}:6443" \
    | kubectl --context=eu apply -f -
