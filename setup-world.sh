(cd the-world/server; docker build -t the-world:0.0.1 .)

for ctx in us-east us-west eu; do
    k3d image import the-world:0.0.1 -c $ctx

    kubectl --context $ctx create ns world
    linkerd inject the-world/k8s/world-gui.yaml | kubectl --context $ctx apply -f -
    linkerd inject the-world/k8s/world.yaml | kubectl --context $ctx apply -f -
done

for ctx in us-east us-west eu; do
    kubectl --context $ctx rollout status -n world deploy
done