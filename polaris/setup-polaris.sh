for ctx in us-east us-west eu-central; do
  kubectl --context "$ctx" apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.1/cert-manager.crds.yaml

  helm upgrade --kube-context "$ctx" --install cert-manager jetstack/cert-manager -n cert-manager --create-namespace \
    --set global.priorityClassName=system-cluster-critical \
    --set image.pullPolicy=Always \
    --set webhook.image.pullPolicy=Always \
    --set cainjector.image.pullPolicy=Always \
    --set acmesolver.image.pullPolicy=Always
  helm upgrade --kube-context "$ctx" --install polaris fairwinds-stable/polaris -n polaris --create-namespace -f polaris-values.yaml
done
