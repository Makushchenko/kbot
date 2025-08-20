# kbot Helm Chart

Helm chart for deploying **kbot** Telegram bot on Kubernetes with GitHub Container Registry (GHCR) images.

---

## Prerequisites

- [Helm](https://helm.sh/docs/intro/install/)
- [k3d](https://k3d.io/) (or any Kubernetes cluster)
- [GitHub CLI](https://cli.github.com/)

---

## Setup

```bash
# Create Helm chart scaffold
helm create ./helm/kbot

# Read sensitive values
read -s TELE_TOKEN
read -s GH_USER
read -s GH_PAT

export TELE_TOKEN GH_USER GH_PAT
```

---

## Local Render

```bash
helm template kbot ./helm/kbot \
  --namespace kbot \
  --set-string secret.value="$TELE_TOKEN" \
  --set-string registry.username="$GH_USER" \
  --set-string registry.password="$GH_PAT"
```

---

## Package & Cluster

```bash
helm package ./helm/kbot

# Create k3d cluster
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
k3d cluster create dev --servers 1 --agents 3
```

---

## Lint & Install

```bash
helm lint ./helm/kbot-0.1.0.tgz \
  --set-string secret.value="$TELE_TOKEN" \
  --set-string registry.username="$GH_USER" \
  --set-string registry.password="$GH_PAT"

helm install kbot ./helm/kbot-0.1.0.tgz \
  -n kbot --create-namespace \
  --set-string secret.value="$TELE_TOKEN" \
  --set-string registry.username="$GH_USER" \
  --set-string registry.password="$GH_PAT"
```

---

## GitHub Release

```bash
gh release create
gh release list
gh release upload v1.0.4 ./helm/kbot-0.1.0.tgz
```

Install directly from GitHub release:

```bash
helm install kbot https://github.com/Makushchenko/kbot/releases/download/v1.0.4/kbot-0.1.0.tgz \
  -n kbot --create-namespace \
  --set-string secret.value="$TELE_TOKEN" \
  --set-string registry.username="$GH_USER" \
  --set-string registry.password="$GH_PAT"
```

---

## Upgrade

```bash
helm upgrade kbot \
  -n kbot \
  --set image.tag=v1.0.4-f488dae \
  --set-string secret.value="$TELE_TOKEN" \
  --set-string registry.username="$GH_USER" \
  --set-string registry.password="$GH_PAT"
```

---

## Useful Commands

```bash
helm get manifest kbot -n kbot | grep -A2 'image: ghcr'
kubectl -n kbot get pod -l app=kbot -o jsonpath='{.items[0].spec.containers[0].image}{"\n"}'

helm ls -n kbot
helm uninstall kbot -n kbot
```

---

After installation, open your Telegram bot and send:

```
/start Hello
```