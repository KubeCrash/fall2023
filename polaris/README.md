# Polaris

[Polaris](https://github.com/fairwindsops/polaris) is an open source policy engine and admission controller for Kubernetes.

## Requirements

In addition to the requirements in the main README for building the demo environment, you will need to have [Helm](https://helm.sh/) installed.

## Usage

Simply run the install script:

```
bash ./setup-polaris.sh
```

This will install cert-manager, and Polaris. Cert-manager is used to manage the certificates for the admission webhook.

After it's installed in each cluster, you can follow the Helm output instructions to see the dashboard.

## Configuration

The [values file](./polaris-values.yaml) has all of the Polaris configuration. If you would like to test the blocking admission controller, just change any of the checks to `danger` instead of `warning`.

Full configuration reference can be found [in the Polaris documentation](https://polaris.docs.fairwinds.com/customization/configuration/)
