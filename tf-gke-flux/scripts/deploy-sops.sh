######################
# Prerequisites 
######################
$PROJECT_ID=
# --- Get credentials for GKE cluster
gcloud container clusters get-credentials kbot-cluster --zone europe-central2-a --project $PROJECT_ID

# --- Install Flux CLI
curl -s https://fluxcd.io/install.sh | sudo FLUX_VERSION=2.0.0 bash

read -s TELE_TOKEN && export TELE_TOKEN
read -s GH_PAT && export GH_PAT
export TF_VAR_GITHUB_TOKEN=
export TF_VAR_GITHUB_EMAIL=
export TF_VAR_GITHUB_OWNER=

# --- After first apply of flux_bootstrap manually add sa-patch.yaml and sops-patch.yaml into clusters/flux-system 



######################
# (EXAMPLES)
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

# ---
flux create kustomization flux-system \
    --namespace=flux-system \
    --path=./clusters \
    --source=GitRepository/flux-system \
    --interval=10m \
    --prune=true \
    --decryption-provider=sops \
    --export > flux-kbot-bootstrap/sops-patch.yaml

# --- SOPS
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
    --keyring=sops-flux-kbot \
    --format='value(name)' | paste -sd, -
)" --encrypted-regex '^(token|\.dockerconfigjson)$' ./flux-kbot-bootstrap/secrets.yaml > ./flux-kbot-bootstrap/secrets-enc.yaml
# ---
k delete secret ghcr-creds -n kbot && k delete secret kbot -n kbot
cat ./flux-kbot-bootstrap/secrets-enc.yaml


######################
# Create the secrets in GCP Secret Manager
######################
PROJECT_ID=engaged-card-466414-h6
SA_EMAIL=kustomize-controller@engaged-card-466414-h6.iam.gserviceaccount.com

# --- Enable service
gcloud services enable secretmanager.googleapis.com --project "$PROJECT_ID"

# --- Create secrets (Google-managed encryption)
gcloud secrets create TELE_TOKEN --replication-policy=automatic --project "$PROJECT_ID"
gcloud secrets create GH_PAT     --replication-policy=automatic --project "$PROJECT_ID"

# --- Add initial versions (paste values)
read -s GH_PAT && export GH_PAT
read -s TELE_TOKEN && export TELE_TOKEN
printf '%s' "$TELE_TOKEN" | gcloud secrets versions add TELE_TOKEN --data-file=- --project "$PROJECT_ID"
printf '%s' "$GH_PAT"     | gcloud secrets versions add GH_PAT     --data-file=- --project "$PROJECT_ID"

# --- Grant the GitHub Actions service account read access
gcloud secrets add-iam-policy-binding TELE_TOKEN \
  --project "$PROJECT_ID" --member "serviceAccount:$SA_EMAIL" \
  --role roles/secretmanager.secretAccessor

gcloud secrets add-iam-policy-binding GH_PAT \
  --project "$PROJECT_ID" --member "serviceAccount:$SA_EMAIL" \
  --role roles/secretmanager.secretAccessor


######################
# Get secrets for GitHub Actions
######################
# --- Get GCP_KMS_KEYRING_NAME
gcloud kms keys list \
  --location=global \
  --keyring=sops-flux-kbot-keyring \
  --format='value(name)'

# --- Get GCP_SA_KEY
gcloud iam service-accounts keys create key.json \
  --iam-account kustomize-controller@$PROJECT_ID.iam.gserviceaccount.com \
  --project $PROJECT_ID


######################
# Flux deployment diagnostics
######################
# --- flux cli
flux get all
flux logs
flux logs -n kbot
flux events
flux get helmreleases -n kbot

# --- flux with kubectl
kubectl get pods -n flux-system -owide
kubectl get pods source-controller-7f4885bfbf-j89ck -n flux-system -owide
kubectl describe pod source-controller-7f4885bfbf-j89ck -n flux-system
kubectl get pods -n flux-system -o wide
kubectl get pods -n flux-system -l app=source-controller
kubectl logs source-controller-6ff87cb475-v2brb -n flux-system
kubectl describe pod source-controller-6ff87cb475-v2brb -n flux-system
kubectl -n flux-system get kustomization -o wide
k logs -n flux-system kustomize-controller-57c7ff5596-6xvq9 -f --tail 10
k get sa -n flux-system kustomize-controller -o yaml

clusters/flux-system/sops-patch.yaml -> path: ./clusters
flux reconcile kustomization flux-system --with-source
flux get kustomizations -A
flux get sources git -A


# --- kbot deployment
kubectl get pods -n kbot
k describe po kbot-7b7649984b-v8h4m -n kbot 
k get deploy -n kbot
k rollout restart deploy kbot -n kbot
k logs kbot-67b6ddb66f-7ktxv -n kbot -f

# --- Secrets
k get secrets -n kbot
k get secrets -n kbot kbot -o yaml
k get secrets -n kbot ghcr-creds -o yaml

# --- KMS
gcloud kms keyrings list --location global


######################
# Resources destroy
######################
t state rm 'github_repository_file.seed_flux_bootstrap["clusters/flux-system/sa-patch.yaml"]' \
'github_repository_file.seed_flux_bootstrap["clusters/flux-system/sops-patch.yaml"]' \
'github_repository_file.seed_kbot_bootstrap["clusters/kbot/kbot-gr.yaml"]' \
'github_repository_file.seed_kbot_bootstrap["clusters/kbot/kbot-hr.yaml"]' \
'github_repository_file.seed_kbot_bootstrap["clusters/kbot/kbot-ns.yaml"]' \
'module.github_repository.github_branch_default.this' \
'module.github_repository.github_repository.this' \
'module.github_repository.github_repository_deploy_key.this'

t destroy -target=module.gke-workload-identity

t state rm module.flux_bootstrap.flux_bootstrap_git.this

gcloud secrets delete TELE_TOKEN --project "$PROJECT_ID" --quiet
gcloud secrets delete GH_PAT --project "$PROJECT_ID" --quiet

# ---
KEY=sops-flux-kbot; KR=sops-key-flux-kbot; LOC=global
for v in $(gcloud kms keys versions list --location=$LOC --keyring=$KR --key=$KEY --format='value(name.basename())'); do
  gcloud kms keys versions disable  "$v" --location=$LOC --keyring=$KR --key=$KEY
  gcloud kms keys versions destroy  "$v" --location=$LOC --keyring=$KR --key=$KEY
done

KEY=sops-flux; KR=sops-key-flux; LOC=global
for v in $(gcloud kms keys versions list --location=$LOC --keyring=$KR --key=$KEY --format='value(name.basename())'); do
  gcloud kms keys versions disable  "$v" --location=$LOC --keyring=$KR --key=$KEY
  gcloud kms keys versions destroy  "$v" --location=$LOC --keyring=$KR --key=$KEY
done