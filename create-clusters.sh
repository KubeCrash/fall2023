#!/bin/env bash
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

# clear

# Create three K3d clusters that are all on the same flat network. As written,
# these are single-Node clusters named "us-east", "us-west", and "eu-central".

#@SHOW

# Each cluster maps port 80 and 443 to the host system, so that ingress can
# work. In us-east, we expose 80 on 8080 and 443 on 8443.
#
# Also, we don't install traefik on any cluster, since we'll be using
# Emissary. Likewise, we disable local-storage and metrics-server.
k3d cluster create us-east \
    -p "8080:80@loadbalancer" -p "8443:443@loadbalancer" \
    --agents=0 \
    --servers=1 \
    --network=world-network \
    --k3s-arg '--disable=traefik,metrics-server@server:*;agents:*' \
    --k3s-arg '--cluster-domain=us-east@server:*' \
    --k3s-arg '--cluster-cidr=10.23.0.0/24@server:*'

# In us-west, we map 80 & 443 to 8081 and 8444.
k3d cluster create us-west \
    -p "8081:80@loadbalancer" -p "8444:443@loadbalancer" \
    --agents=0 \
    --servers=1 \
    --network=world-network \
    --k3s-arg '--disable=traefik,metrics-server@server:*;agents:*' \
    --k3s-arg '--cluster-domain=us-west@server:*' \
    --k3s-arg '--cluster-cidr=10.23.1.0/24@server:*'

# In eu-central, we map 80 & 443 to 8082 and 8445.
k3d cluster create eu-central \
    -p "8082:80@loadbalancer" -p "8445:443@loadbalancer" \
    --agents=0 \
    --servers=1 \
    --network=world-network \
    --k3s-arg '--disable=traefik,metrics-server@server:*;agents:*' \
    --k3s-arg '--cluster-domain=eu-central@server:*' \
    --k3s-arg '--cluster-cidr=10.23.2.0/24@server:*'

kubectl config delete-context us-east >/dev/null 2>&1
kubectl config rename-context k3d-us-east us-east
kubectl config delete-context us-west >/dev/null 2>&1
kubectl config rename-context k3d-us-west us-west
kubectl config delete-context eu-central >/dev/null 2>&1
kubectl config rename-context k3d-eu-central eu-central

# Grab CIDR ranges, and use them to tweak the routing tables on each cluster
# to allow flat networking.
useast_cidr=
useast_router=
uswest_cidr=
uswest_router=
eucentral_cidr=
eucentral_router=

REMAINING=60 ;\
echo "Getting us-east cluster network info..." ;\
while true; do \
    useast_cidr=$(kubectl --context us-east get node k3d-us-east-server-0 -o jsonpath='{.spec.podCIDR}') ;\
    useast_router=$(kubectl --context us-east get node k3d-us-east-server-0 -o jsonpath='{.status.addresses[?(.type=="InternalIP")].address}') ;\
    if [ -n "$useast_cidr" -a -n "$useast_router" ]; then break; fi ;\
    REMAINING=$(( $REMAINING - 1 )) ;\
    printf "." ;\
    sleep 1 ;\
done ;\
if [ $REMAINING -eq 0 ]; then \
    echo "Timed out waiting for us-east network info" ;\
    exit 1 ;\
else \
    printf "\nus-east: $useast_cidr, router $useast_router" ;\
fi

REMAINING=60 ;\
echo "Getting us-west cluster network info..." ;\
while true; do \
    uswest_cidr=$(kubectl --context us-west get node k3d-us-west-server-0 -o jsonpath='{.spec.podCIDR}') ;\
    uswest_router=$(kubectl --context us-west get node k3d-us-west-server-0 -o jsonpath='{.status.addresses[?(.type=="InternalIP")].address}') ;\
    if [ -n "$uswest_cidr" -a -n "$uswest_router" ]; then break; fi ;\
    REMAINING=$(( $REMAINING - 1 )) ;\
    printf "." ;\
    sleep 1 ;\
done ;\
if [ $REMAINING -eq 0 ]; then \
    echo "Timed out waiting for us-west network info" ;\
    exit 1 ;\
else \
    printf "\nus-west: $uswest_cidr, router $uswest_router" ;\
fi

REMAINING=60 ;\
echo "Getting eu-central cluster network info..." ;\
while true; do \
    eucentral_cidr=$(kubectl --context eu-central get node k3d-eu-central-server-0 -o jsonpath='{.spec.podCIDR}') ;\
    eucentral_router=$(kubectl --context eu-central get node k3d-eu-central-server-0 -o jsonpath='{.status.addresses[?(.type=="InternalIP")].address}') ;\
    if [ -n "$eucentral_cidr" -a -n "$eucentral_router" ]; then break; fi ;\
    REMAINING=$(( $REMAINING - 1 )) ;\
    printf "." ;\
    sleep 1 ;\
done ;\
if [ $REMAINING -eq 0 ]; then \
    echo "Timed out waiting for eu-central network info" ;\
    exit 1 ;\
else \
    printf "\neu-central: $eucentral_cidr, router $eucentral_router" ;\
fi

echo "us-east cluster: route ${uswest_cidr} via ${uswest_router}, ${eucentral_cidr} via ${eucentral_router}"
docker exec -it k3d-us-east-server-0 ip route add ${uswest_cidr} via ${uswest_router}
docker exec -it k3d-us-east-server-0 ip route add ${eucentral_cidr} via ${eucentral_router}

echo "us-west cluster: route ${useast_cidr} via ${useast_router}, ${eucentral_cidr} via ${eucentral_router}"
docker exec -it k3d-us-west-server-0 ip route add ${useast_cidr} via ${useast_router}
docker exec -it k3d-us-west-server-0 ip route add ${eucentral_cidr} via ${eucentral_router}

echo "eu-central cluster: route ${useast_cidr} via ${useast_router}, ${uswest_cidr} via ${uswest_router}"
docker exec -it k3d-eu-central-server-0 ip route add ${useast_cidr} via ${useast_router}
docker exec -it k3d-eu-central-server-0 ip route add ${uswest_cidr} via ${uswest_router}

#@SKIP
#@wait

# if [ -f images.tar ]; then k3d image import -c ${CLUSTER} images.tar; fi
# #@wait
