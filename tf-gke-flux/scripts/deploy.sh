######################
# .0
######################
# --- Get credentials for GKE cluster
gcloud container clusters get-credentials kbot-cluster --zone europe-central2-a --project <project_id>


######################
# .1
######################
# --- Namespace
kubectl create namespace kbot
---
apiVersion: v1
kind: Namespace
metadata:
  name: kbot

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

# --- Install Flux CLI
curl -s https://fluxcd.io/install.sh | sudo FLUX_VERSION=2.0.0 bash


######################
# .2 Create file into repo kbot-flux: clusters/kbot/kbot-gr.yaml
######################
flux create source git kbot \
    --url=https://github.com/Makushchenko/kbot \
    --branch=main \
    --namespace=kbot \
    --export
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: kbot
  namespace: kbot
spec:
  interval: 1m0s
  ref:
    branch: main
  url: https://github.com/Makushchenko/kbot


######################
# .3 Create file into repo kbot-flux: clusters/kbot/kbot-hr.yaml
# reconcileStrategy: Revision <— react to Git commits (repo revision), not only chart version
######################
flux create helmrelease kbot \
    --namespace=kbot \
    --source=GitRepository/kbot \
    --chart="./helm" \
    --release-name=kbot \
    --interval=1m \
    --create-target-namespace=true \
    --export
---
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: kbot
  namespace: kbot
spec:
  chart:
    spec:
      chart: ./helm
      reconcileStrategy: ChartVersion
      sourceRef:
        kind: GitRepository
        name: kbot
  install:
    createNamespace: true
  interval: 1m0s
  releaseName: kbot


######################
# .4 Flux diagnostics
######################
# --- flux cli
flux get all
flux logs
flux logs -n kbot
flux events
flux get helmreleases -n kbot

# --- kubectl
kubectl get pods -n flux-system -owide
kubectl get pods source-controller-7f4885bfbf-j89ck -n flux-system -owide
kubectl describe pod source-controller-7f4885bfbf-j89ck -n flux-system
kubectl get pods -n flux-system -o wide
kubectl get pods -n flux-system -l app=source-controller
kubectl logs source-controller-78b674c466-zkch7 -n flux-system
kubectl describe pod source-controller-78b674c466-zkch7 -n flux-system
kubectl -n flux-system get kustomization -o wide


######################
# .5 Validate deployment
######################
kubectl get pods -n kbot
kubectl describe pods kbot-7cb46ff7d-zrg6p -n kbot
kubectl logs kbot-7cb46ff7d-zrg6p -n kbot -f