set -e

TAG=the-world:0.0.2

if [ -z "$DOCKER_REGISTRY" ]; then
    ( cd the-world/server && docker build -t $TAG . )
fi

if [ -n "$DOCKER_REGISTRY" ]; then
    if [ -z "$WORLD_VERSION" ]; then
        echo "WORLD_VERSION must be set for a registry build" >&2
        exit 1
    fi

    TAG=$DOCKER_REGISTRY/the-world:$WORLD_VERSION

    # This assumes that you have a buildx builder set up for multiplatform!
    ( cd the-world/server &&
      docker buildx build \
             --platform=linux/amd64,linux/arm64 \
             --tag $TAG \
             --push . )
fi

for ctx in us-east us-west eu-central; do
    if [ -z "$DOCKER_REGISTRY" ]; then
        k3d image import $TAG -c $ctx
    fi

    kubectl --context $ctx create ns world

    sed -e "s,%TAG%,$TAG," < the-world/k8s/world-gui.yaml | \
        linkerd --context $ctx inject - | \
        kubectl --context $ctx apply -f -

    sed -e "s,%TAG%,$TAG," < the-world/k8s/world.yaml | \
        linkerd --context $ctx inject - | \
        kubectl --context $ctx apply -f -

    # DON'T inject the players -- they talk only to Emissary, like a
    # normal out-of-cluster client would.
    sed -e "s,%TAG%,$TAG," < the-world/k8s/player-$ctx.yaml | \
        kubectl --context $ctx apply -f -
done

for ctx in us-east us-west eu-central; do
    kubectl --context $ctx rollout status -n world deploy
done

for ctx in us-east us-west; do
    kubectl apply --context $ctx -f emissary/mappings-us.yaml
done

kubectl apply --context eu-central -f emissary/mappings-eu.yaml

