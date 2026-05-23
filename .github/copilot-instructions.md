# Andromeda Cluster — Copilot Instructions

## Repository Overview

This is an **Infrastructure-as-Code GitOps repository** for the Andromeda Kubernetes cluster. Changes here are applied automatically by ArgoCD — there is no CI build or test pipeline. Pushing to `HEAD` causes ArgoCD to sync.

## Architecture

The deployment is structured as an **App-of-Apps** GitOps pattern:

```
core-service/          ← Root Helm chart (manually installed once)
  templates/           ← ArgoCD Application manifests (one per service)

core-charts/           ← Supplemental Helm charts per service
  {service}-extras/    ← Cluster-specific resources for a service
    templates/         ← Kubernetes manifests (secrets, ingress, CRDs, etc.)
    values.yaml

system/                ← Ansible workspace for Proxmox node management
utils/                 ← Helper scripts (e.g., creating sealed secrets)
```

ArgoCD is bootstrapped once via `helm install`, then it deploys `core-service`, which in turn deploys all other services.

## Key Conventions

### Dual-Source ArgoCD Applications

Every service in `core-service/templates/` typically uses **two Helm sources**:
1. The upstream public Helm chart (versioned)
2. `repoURL: {{ .Values.repository.url }}` → `path: core-charts/{service}-extras` for cluster-specific overlays

The `repository.url` value in `core-service/values.yaml` must point to the active GitHub remote so ArgoCD can pull configs.

### Secrets (Sealed Secrets)

All secrets are encrypted with **kubeseal** (Bitnami Sealed Secrets) and committed to the repo. Never commit plaintext secrets.

Use the helper script to create a new sealed secret:
```bash
# Single key-value pair
./utils/create-secret-template.sh <service-type> <service-name> <secret-name> <key> <value>

# Interactive mode (multiple key-value pairs)
./utils/create-secret-template.sh <service-type> <service-name> <secret-name>

# Example: create a secret for the prometheus service under core
./utils/create-secret-template.sh core prometheus github-client
```

The script auto-detects the target namespace from the ArgoCD Application manifest and outputs the sealed secret YAML into `{type}-charts/{service}-extras/templates/`.

Sealed secrets must have the label `app.kubernetes.io/part-of: {service-name}` (added automatically by the script).

### Adding a New Core Service

1. Add an ArgoCD `Application` manifest to `core-service/templates/{service}.yaml`
2. Set `spec.destination.namespace` — this is the namespace used by the secrets script
3. Create `core-charts/{service}-extras/` with `Chart.yaml`, `values.yaml`, and `templates/` for any cluster-specific resources

### Ingress / DNS / TLS

- Ingress class: `nginx`
- TLS: cert-manager with cluster-issuer `letsencrypt-dns` (DNS01 via Hetzner)
- External-DNS target: `cluster.ldtteam.com`
- ParchmentMC services use a separate issuer via Cloudflare

### ArgoCD Sync Policy

All applications use `automated` sync with `prune: true` and `CreateNamespace=true`. Avoid manually applied cluster resources that aren't tracked here, as they'll be pruned.

## Infrastructure Reference

Four Proxmox hardware nodes, each running one Rancher control VM and four RKE2 Kubernetes VMs (system + worker nodes):

| Node     | IP          | Proxmox VM ID ranges       |
|----------|-------------|----------------------------|
| Titawin  | 10.1.0.2/16 | K8s: 2000–2999, Templates: 8000–8999, Rancher: 1000 |
| Adhil    | 10.2.0.2/16 | K8s: 3000–3999, Templates: 9000–9999, Rancher: 1001 |
| Nembus   | 10.3.0.2/16 | K8s: 4000–4999, Templates: 10000–10999, Rancher: 1002 |
| Veritate | 10.4.0.2/16 | K8s: 5000–5999, Templates: 11000–11999, Rancher: 1003 |
