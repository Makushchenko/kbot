######################
# .0
######################
# --- get credentials for cluster
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



Request `Create IAM Members roles/cloudkms.cryptoKeyEncrypterDecrypter serviceAccount:kustomize-controller@engaged-card-466414-h6.iam.gserviceaccount.com
for project "engaged-card-466414-h6"` returned error: Error retrieving IAM policy for project "engaged-card-466414-h6": googleapi:
Error 403: Cloud Resource Manager API has not been used in project engaged-card-466414-h6 before or it is disabled.
Enable it by visiting https://console.developers.google.com/apis/api/cloudresourcemanager.googleapis.com/overview?project=engaged-card-466414-h6 then retry.
If you enabled this API recently, wait a few minutes for the action to propagate to our systems and retry.

k get sa -n flux-system kustomize-controller -o yaml
gcloud kms keyrings list --location global

flux create kustomization flux-system \
    --namespace=flux-system \
    --path=./clusters \
    --source=GitRepository/flux-system \
    --interval=10m \
    --prune=true \
    --decryption-provider=sops \
    --export > flux-kbot-bootstrap/sops-patch.yaml



t state mv 'github_repository_file.seed_flux_kbot_bootstrap["clusters/kbot/kbot-ns.yaml"]' 'github_repository_file.seed_kbot_bootstrap["clusters/kbot/kbot-ns.yaml"]'
t state mv 'github_repository_file.seed_flux_kbot_bootstrap["clusters/kbot/kbot-hr.yaml"]' 'github_repository_file.seed_kbot_bootstrap["clusters/kbot/kbot-hr.yaml"]'
t state mv 'github_repository_file.seed_flux_kbot_bootstrap["clusters/kbot/kbot-gr.yaml"]' 'github_repository_file.seed_kbot_bootstrap["clusters/kbot/kbot-gr.yaml"]'

k get po -n flux-system
k logs -n flux-system kustomize-controller-57c7ff5596-88mf7 -f --tail 10


ta -target='github_repository_file.seed_flux_bootstrap["clusters/flux-system/sops-patch.yaml"]'
ta -target='github_repository_file.seed_flux_bootstrap["clusters/flux-system/sa-patch.yaml"]'

k get sa -n flux-system kustomize-controller -o yaml | grep -A5 anno
gcloud kms keys list --location global --keyring sops-flux


wget https://github.com/getsops/sops/releases/download/v3.10.2/sops-v3.10.2.linux.amd64
chmod +x sops-v3.10.2.linux.amd64
mv sops-v3.10.2.linux.amd64 ./sops/sops
# ---
(
  read -s TELE_TOKEN; echo
  printf %s "$TELE_TOKEN" \
  | kubectl -n kbot create secret generic kbot \
      --type=Opaque \
      --from-file=token=/dev/stdin \
      --dry-run=client -o yaml
  echo '---'
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
      --dry-run=client -o yaml
) > ./flux-kbot-bootstrap/secrets.yaml
# ---
./sops/sops -e --gcp-kms "$(
  gcloud kms keys list \
    --location=global \
    --keyring=sops-flux \
    --format='value(name)' | paste -sd, -
)" --encrypted-regex '^(token|\.dockerconfigjson)$' ./flux-kbot-bootstrap/secrets.yaml > ./flux-kbot-bootstrap/secrets-enc.yaml
# ---
k delete secret ghcr-creds -n kbot && k delete secret kbot -n kbot

cat ./flux-kbot-bootstrap/secrets-enc.yaml


k get secrets -n kbot
k get secrets -n kbot kbot -o yaml
k get secrets -n kbot ghcr-creds -o yaml

k get po -n kbot
k describe po kbot-5d6df85998-w69jj -n kbot 
k get deploy -n kbot
k rollout restart deploy kbot -n kbot
kubectl logs kbot-6cc89d4b95-96zq7 -n kbot -f

gcloud iam service-accounts keys create key.json \
  --iam-account kustomize-controller@engaged-card-466414-h6.iam.gserviceaccount.com \
  --project engaged-card-466414-h6

# --- Create the secrets in GCP Secret Manager
PROJECT_ID=engaged-card-466414-h6
SA_EMAIL=kustomize-controller@engaged-card-466414-h6.iam.gserviceaccount.com

# Enable service
gcloud services enable secretmanager.googleapis.com --project "$PROJECT_ID"

# Create secrets (Google-managed encryption)
gcloud secrets create TELE_TOKEN --replication-policy=automatic --project "$PROJECT_ID"
gcloud secrets create GH_PAT     --replication-policy=automatic --project "$PROJECT_ID"

# Add initial versions (paste values)
read -s GH_PAT && export GH_PAT
read -s TELE_TOKEN && export TELE_TOKEN
printf '%s' "$TELE_TOKEN" | gcloud secrets versions add TELE_TOKEN --data-file=- --project "$PROJECT_ID"
printf '%s' "$GH_PAT"     | gcloud secrets versions add GH_PAT     --data-file=- --project "$PROJECT_ID"

# Grant the GitHub Actions service account read access
gcloud secrets add-iam-policy-binding TELE_TOKEN \
  --project "$PROJECT_ID" --member "serviceAccount:$SA_EMAIL" \
  --role roles/secretmanager.secretAccessor

gcloud secrets add-iam-policy-binding GH_PAT \
  --project "$PROJECT_ID" --member "serviceAccount:$SA_EMAIL" \
  --role roles/secretmanager.secretAccessor