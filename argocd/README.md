# Deploy Argo CD and Auto-Sync `kbot` (Helm) — Step-by-Step

This README installs **k3d**, **Argo CD CLI**, **Argo CD (via Helm)**, creates required **Secrets** for `kbot`, and sets up an **Argo CD Application** that auto-syncs your Helm chart from Git.

> Notes
> • When you run `kubectl port-forward`, do it in a **separate terminal** because it blocks the session.
> • In the `argocd login … --password $PASS` line, use the password printed by the prior command (copy/paste it into `$PASS` or replace `"$PASS"` inline).

---

## 1) Install k3d

```bash
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | sudo bash
```

## 2) Install Argo CD CLI

```bash
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```

## 3) Create a k3d Cluster

```bash
k3d cluster create demo \
  --servers 1 \
  --agents 3
```

## 4) Install Argo CD via Helm

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd -n argocd --create-namespace --version 8.3.0
```

## 5) Access Argo CD UI & Get Admin Password

> Run the port-forward in a **separate terminal** so you can keep going with the rest.

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:80
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
argocd login localhost:8080 --username admin --password "$PASS" --insecure
```

* Copy the printed password and either export it to `PASS` or paste it in place of `"$PASS"`.

## 6) Create the Target Namespace

```bash
kubectl create namespace kbot
```

## 7) Create Required Secrets for `kbot`

**Telegram token (Opaque Secret):**

```bash
# --- TELE_TOKEN secret (no secret in args; piped via stdin)
read -s TELE_TOKEN; echo
printf %s "$TELE_TOKEN" \
| kubectl -n kbot create secret generic kbot \
    --type=Opaque \
    --from-file=token=/dev/stdin \
    --dry-run=client -o yaml \
| kubectl apply -f -
kubectl get secret kbot -n kbot
kubectl describe secret kbot -n kbot
```

**GHCR pull secret (dockerconfigjson):**

```bash
# --- GHCR dockerconfigjson secret (no creds in args; piped via stdin)
read -p "GHCR server [ghcr.io]: " SERVER; SERVER=${SERVER:-ghcr.io}
read -p "Email [ci@example.com]: " EMAIL; EMAIL=${EMAIL:-ci@example.com}
read -s -p "GHCR username: " GH_USER; echo
read -s -p "GHCR PAT: " GH_PAT; echo
AUTH_B64=$(printf "%s:%s" "$GH_USER" "$GH_PAT" | base64 | tr -d '\n')
printf '{"auths":{"%s":{"username":"%s","password":"%s","email":"%s","auth":"%s"}}}\n' \
  "$SERVER" "$GH_USER" "$GH_PAT" "$EMAIL" "$AUTH_B64" \
| kubectl -n kbot create secret generic ghcr-creds \
    --type=kubernetes.io/dockerconfigjson \
    --from-file=.dockerconfigjson=/dev/stdin \
    --dry-run=client -o yaml \
| kubectl apply -f -
kubectl get secret ghcr-creds -n kbot
kubectl describe secret ghcr-creds -n kbot
```

## 8) Register Argo CD Project & Application

> These manifests should already exist at `./argocd/app_project.yaml` and `./argocd/application.yaml`. The Application points at your Helm chart path in Git and uses **auto-sync**.

```bash
# --- Create an ArgoCD Project (scopes where apps can deploy)
kubectl apply -f ./argocd/app_project.yaml

# --- ArgoCD Application (Helm chart from Git, auto-sync)
kubectl apply -f ./argocd/application.yaml
```

## 9) Observe Sync & App State

```bash
# Watch the app reconcile
argocd app get kbot
# Print effective Helm inputs ArgoCD uses
argocd app get kbot --show-params   # shows helm.parameters

kubectl get pods -n kbot
kubectl describe pod kbot-78777496b6-z4z9r -n kbot

kubectl logs kbot-78777496b6-z4z9r -n kbot -f
```

---

### Troubleshooting tips

* If ArgoCD doesn’t pick up changes fast enough, click **Refresh** in the UI or run `argocd app refresh kbot --hard`.
* If the Application shows type **Directory** instead of **Helm**, ensure your `path` contains a `Chart.yaml`.
* Secrets won’t update running Pods automatically; trigger a rollout if you rotate tokens.