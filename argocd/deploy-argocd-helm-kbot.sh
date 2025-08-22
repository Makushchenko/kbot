curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | sudo bash

curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

k3d cluster create demo \
  --servers 1 \
  --agents 3

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd -n argocd --create-namespace --version 8.3.0

kubectl port-forward svc/argocd-server -n argocd 8080:80
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
argocd login localhost:8080 --username admin --password "$PASS" --insecure

kubectl create namespace kbot

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

# --- Create an ArgoCD Project (scopes where apps can deploy)
kubectl apply -f ./argocd/app_project.yaml

# --- ArgoCD Application (Helm chart from Git, auto-sync)
kubectl apply -f ./argocd/application.yaml

# Watch the app reconcile
argocd app get kbot
# Print effective Helm inputs ArgoCD uses
argocd app get kbot --show-params   # shows helm.parameters

kubectl get pods -n kbot
kubectl describe pod kbot-78777496b6-z4z9r -n kbot

kubectl logs kbot-78777496b6-z4z9r -n kbot -f