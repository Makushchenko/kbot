## Quick Usage GKE with Terraform

**Prerequisites**

* Terraform installed; Google Cloud SDK (`gcloud`) authenticated:

  ```bash
  gcloud auth login
  gcloud auth application-default login
  gcloud config set project engaged-card-466414-h6
  gcloud services enable container.googleapis.com compute.googleapis.com
  ```

**Files**

* Save the provided values as `terraform.tfvars`:

  ```hcl
  GOOGLE_PROJECT          = "engaged-card-466414-h6"
  GOOGLE_REGION           = "europe-central2-a" # zone used by this config
  GKE_MACHINE_TYPE        = "g1-small"
  GKE_DISK_SIZE_GB        = 25
  GKE_NUM_NODES           = 2
  GKE_CLUSTER_NAME        = "demo-cluster"
  GKE_POOL_NAME           = "demo-pool"
  GKE_DELETION_PROTECTION = false
  ```

* Set environment variables:
  ```bash
  export TF_VAR_GITHUB_OWNER=
  export TF_VAR_GITHUB_TOKEN=
  ```

**Deploy**

```bash
terraform init
terraform plan -out tfplan
terraform apply tfplan
```

**Get kubeconfig & test**

```bash
# zonal (matches europe-central2-a)
gcloud container clusters get-credentials demo-cluster --zone europe-central2-a --project engaged-card-466414-h6
kubectl get nodes -o wide
```

**Destroy**

```bash
terraform destroy
```

**Notes**

* `GKE_DELETION_PROTECTION = false` lets you delete the cluster without extra steps.
* `GKE_NUM_NODES = 2` is fine for dev; use ≥3 for HA.

## Infracost (basic auth & CLI)

**Install**

```bash
# macOS
brew install infracost
# Linux
curl -fsSL https://raw.githubusercontent.com/infracost/infracost/master/scripts/install.sh | sh
```

**Authenticate**

```bash
# Option A: browser-based login
infracost auth login

# Option B: headless/CI — set API key directly
export INFRACOST_API_KEY=<your_api_key>
# or store it in the CLI config
infracost configure set api_key <your_api_key>
```

**CLI usage (run from this Terraform project)**

```bash
# Fast estimate from Terraform dir
infracost breakdown --path .

# More precise using a plan file
terraform plan -out tfplan
terraform show -json tfplan > plan.json
infracost breakdown --path plan.json
```

Docs: [https://www.infracost.io/docs/](https://www.infracost.io/docs/)

## Terraform backend: Google Cloud Storage bucket

**Create bucket (recommended settings)**

```bash
# Set your project & region
PROJECT="engaged-card-466414-h6"
REGION="europe-central2"           # use region (not zone)
BUCKET="tfstate-${PROJECT}-demo"   # must be globally unique

# Create bucket with Uniform access (no object ACLs)
# -b on = uniform bucket-level access
gsutil mb -p "$PROJECT" -l "$REGION" -b on "gs://${BUCKET}"

# Enable object versioning (protects state rollbacks)
gsutil versioning set on "gs://${BUCKET}"

# Enforce Public Access Prevention (no public objects)
gsutil pap set enforced "gs://${BUCKET}"

# (Optional) default CMEK if you use Cloud KMS
# gsutil kms encryption -k projects/$PROJECT/locations/$REGION/keyRings/<ring>/cryptoKeys/<key> "gs://${BUCKET}"
```

**Terraform backend config**

```hcl
terraform {
  backend "gcs" {
    bucket = "tfstate-engaged-card-466414-h6-demo"  # your bucket name
    prefix = "terraform/state"                      # folder-like path for this workspace
  }
}
```

**IAM (who can access state)**
Grant your CI/user service account **Storage Object Admin** on the bucket (read/write objects):

```bash
gsutil iam ch serviceAccount:<SA_EMAIL>:roles/storage.objectAdmin "gs://${BUCKET}"
```

**Notes**

* Use a **region** for the bucket (e.g., `europe-central2`), not a zone.
* Bucket names are global; pick something unique and consistent per environment (e.g., `tfstate-<project>-<env>`).