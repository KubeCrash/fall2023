set -e

VERSION=0.0.1
TAG=$DOCKER_REGISTRY/the-world:$VERSION

if [ -z "$DOCKER_REGISTRY" ]; then
    TAG=the-world:$VERSION
fi

( cd the-world/server && docker build -t $TAG . )

if [ -n "$DOCKER_REGISTRY" ]; then
    docker push $TAG
fi

for ctx in us-east us-west eu-central; do
    if [ -z "$DOCKER_REGISTRY" ]; then
        k3d image import $TAG -c $ctx
    fi

    kubectl --context $ctx create ns world

    sed -e "s/%TAG%/$TAG/" < the-world/k8s/world-gui.yaml | \
        linkerd inject - | \
        kubectl --context $ctx apply -f -

    sed -e "s/%TAG%/$TAG/" < the-world/k8s/world.yaml | \
        linkerd inject - | \
        kubectl --context $ctx apply -f -

    sed -e "s/%TAG%/$TAG/" < the-world/k8s/player-$ctx.yaml | \
        linkerd inject - | \
        kubectl --context $ctx apply -f -
done

for ctx in us-east us-west eu-central; do
    kubectl --context $ctx rollout status -n world deploy
done

for ctx in us-east us-west; do
    kubectl apply --context $ctx -f emissary/mappings-us.yaml
done

kubectl apply --context eu-central -f emissary/mappings-eu.yaml

