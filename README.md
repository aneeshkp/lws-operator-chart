# LWS Operator Helm Chart

Deploy Red Hat Leader Worker Set (LWS) Operator on any Kubernetes cluster without OLM.

## Overview

This chart uses **olm-extractor** to extract manifests directly from Red Hat's OLM bundle, enabling deployment on non-OLM Kubernetes clusters (AKS, EKS, GKE) while:

- **Minimizing OCP team burden** - Uses exact manifests from Red Hat's OLM bundles
- **Easy upgrades** - Single command: `./scripts/update-bundle.sh <version>`
- **No breaking changes** - Only minimal patches for non-OLM environments

## What is Leader Worker Set?

LWS provides an API for deploying a group of pods as a unit of replication, designed for:
- **AI/ML inference workloads** - Especially multi-host inference where LLMs are sharded across multiple nodes
- **Distributed training** - Coordinated pod groups with leader/worker topology
- **Gang scheduling** - All-or-nothing pod group scheduling

## Prerequisites

- `kubectl` configured for your cluster
- `helmfile` installed
- `podman login registry.redhat.io` (for Red Hat registry auth)

## Quick Start

```bash
cd lws-operator-chart

# 1. Login to Red Hat registry
podman login registry.redhat.io

# 2. Deploy
helmfile apply
```

## Configuration

Edit `environments/default.yaml`. Choose ONE auth method:

### Option A: System Podman Auth (Recommended)

```yaml
# environments/default.yaml
useSystemPodmanAuth: true
```

### Option B: Pull Secret File

```yaml
# environments/default.yaml
pullSecretFile: ~/pull-secret.txt
```

## What Gets Deployed

**Presync hooks (before Helm install):**
1. LeaderWorkerSetOperator CRD - applied with `--server-side`
2. Operator namespace (`openshift-lws-operator`)

**Helm install:**
3. Pull secret (`redhat-pull-secret`)
4. LWS Operator ServiceAccount with `imagePullSecrets`
5. LWS Operator deployment + RBAC

**Post-install:**
6. LeaderWorkerSetOperator CR (`cluster`)
7. Operator deploys LeaderWorkerSet CRD and webhooks

## Version Compatibility

| Component | Version |
|-----------|---------|
| LWS Operator | 1.0 |
| LeaderWorkerSet API | v1 |

**OLM Bundle:** `registry.redhat.io/leader-worker-set/lws-operator-bundle` ([Red Hat Catalog](https://catalog.redhat.com/software/containers/leader-worker-set/lws-operator-bundle))

## Verify Installation

```bash
# Check operator
kubectl get pods -n openshift-lws-operator

# Check LeaderWorkerSetOperator CR
kubectl get leaderworkersetoperator cluster

# Check LeaderWorkerSet CRD is available
kubectl get crd leaderworkersets.leaderworkerset.x-k8s.io
```

## Create a LeaderWorkerSet

```bash
kubectl apply -f - <<EOF
apiVersion: leaderworkerset.x-k8s.io/v1
kind: LeaderWorkerSet
metadata:
  name: my-lws
spec:
  replicas: 2
  leaderWorkerTemplate:
    size: 3
    leaderTemplate:
      metadata:
        labels:
          role: leader
      spec:
        containers:
        - name: main
          image: nginx
    workerTemplate:
      spec:
        containers:
        - name: main
          image: nginx
EOF
```

## Uninstall

```bash
./scripts/cleanup.sh
```

## Update to New Bundle Version

```bash
./scripts/update-bundle.sh 1.1
helmfile apply
```

## Update Pull Secret

Red Hat pull secrets expire (typically yearly). To update:

```bash
# Option A: Using system podman auth (after re-login)
podman login registry.redhat.io
./scripts/update-pull-secret.sh

# Option B: Using pull secret file
./scripts/update-pull-secret.sh ~/new-pull-secret.txt

# Restart operator to use new secret
kubectl rollout restart deployment/openshift-lws-operator -n openshift-lws-operator
```

## File Structure

```
lws-operator-chart/
├── Chart.yaml
├── values.yaml                  # Default values
├── helmfile.yaml.gotmpl         # Deploy with: helmfile apply
├── .helmignore
├── environments/
│   └── default.yaml             # User config
├── manifests-crds/              # LeaderWorkerSetOperator CRD
├── templates/
│   ├── deployment-*.yaml        # Operator deployment
│   ├── pull-secret.yaml         # Registry pull secret
│   └── *.yaml                   # RBAC, ServiceAccount, etc.
└── scripts/
    ├── update-bundle.sh         # Update to new bundle version
    ├── update-pull-secret.sh    # Update expired pull secret
    ├── cleanup.sh               # Uninstall
    └── post-install-message.sh  # Post-install instructions
```
