# Andromeda
Contains the service specifications for the Andromeda cluster.

## Directories
### core-services
This directory contains charts the primary core-service deployment chart which triggers the deployment of all core services, using ArgoCD

### charts
This directory contains additional core service of the cluster.
It is deployed via the `core-service` application.

## Bootstrapping
1. Create a Kubernetes cluster (for example via Rancher)
2. Install ArgoCD
   1. Run: `helm repo add argoproj https://argoproj.github.io/argo-helm` to add the ArgoCD Helm repository
   2. Run: `helm install argocd argoproj/argo-cd -n argocd --create-namespace` to bootstrap ArgoCD