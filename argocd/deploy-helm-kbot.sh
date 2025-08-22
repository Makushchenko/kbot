helm create ./helm/kbot

read -s TELE_TOKEN
read -s GH_USER
read -s GH_PAT

export TELE_TOKEN
export GH_USER
export GH_PAT

helm template kbot ./helm/kbot \
  --namespace kbot \
  --set-string secret.value="$TELE_TOKEN" \
  --set-string registry.username="$GH_USER" \
  --set-string registry.password="$GH_PAT"

helm package ./helm/kbot

curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
k3d cluster create dev \
  --servers 1 \
  --agents 3

helm lint ./helm/kbot-0.1.0.tgz \
  --set-string secret.value="$TELE_TOKEN" \
  --set-string registry.username="$GH_USER" \
  --set-string registry.password="$GH_PAT"

helm install kbot ./helm/kbot-0.1.0.tgz \
  -n kbot --create-namespace \
  --set-string secret.value="$TELE_TOKEN" \
  --set-string registry.username="$GH_USER" \
  --set-string registry.password="$GH_PAT"

# --- Create GitHub Release
gh release create
gh release list
gh release upload v1.0.4 ./helm/kbot-0.1.0.tgz

helm install kbot https://github.com/Makushchenko/kbot/releases/download/v1.0.4/kbot-0.1.0.tgz \
  -n kbot --create-namespace \
  --set-string secret.value="$TELE_TOKEN" \
  --set-string registry.username="$GH_USER" \
  --set-string registry.password="$GH_PAT"

helm upgrade kbot \
  -n kbot \
  --set image.tag=v1.0.4-f488dae \
  --set-string secret.value="$TELE_TOKEN" \
  --set-string registry.username="$GH_USER" \
  --set-string registry.password="$GH_PAT"

####################
Usefull commands
####################
helm get manifest kbot -n kbot | grep -A2 'image: ghcr'
kubectl -n kbot get pod -l app=kbot -o jsonpath='{.items[0].spec.containers[0].image}{"\n"}'

helm uninstall kbot -n kbot
helm ls -n kbot
####################