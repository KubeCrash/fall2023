# After that, we'll install Emissary as an ingress controller. The choice
# of ingress controller doesn't actually matter for this demo, we just need
# one to make it easy to get access to the Faces demo.
#
# This is almost straight out of the Emissary quickstart, but we force it
# to one replica to reduce the load on k3d, and we make sure to inject Emissary
# into the mesh.

EMISSARY_VERSION=3.8.0

EMISSARY_CRDS=https://app.getambassador.io/yaml/emissary/$EMISSARY_VERSION/emissary-crds.yaml
EMISSARY_INGRESS=https://app.getambassador.io/yaml/emissary/$EMISSARY_VERSION/emissary-emissaryns.yaml

install_emissary () {
    ctx="$1"

    kubectl --context "$ctx" create namespace emissary && \
    curl --proto '=https' --tlsv1.2 -sSfL $EMISSARY_CRDS | \
        sed -e 's/replicas: 3/replicas: 1/' | \
        kubectl --context "$ctx" apply -f -
    kubectl --context "$ctx" wait --timeout=90s --for=condition=available deployment emissary-apiext -n emissary-system

    curl --proto '=https' --tlsv1.2 -sSfL $EMISSARY_INGRESS | \
        sed -e 's/replicas: 3/replicas: 1/' | \
        linkerd inject - | kubectl --context "$ctx" apply -f -

    kubectl --context "$ctx" -n emissary wait --for condition=available --timeout=90s deploy -lproduct=aes
}

install_emissary us-east
install_emissary us-west
install_emissary eu-central