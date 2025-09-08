module "github_repository" {
  source = "github.com/Makushchenko/tf-github-repository"

  github_owner             = var.GITHUB_OWNER
  github_token             = var.GITHUB_TOKEN
  repository_name          = var.FLUX_GITHUB_REPO
  public_key_openssh       = module.tls_private_key.public_key_openssh
  public_key_openssh_title = "flux0"
}

module "gke_cluster" {
  source = "github.com/Makushchenko/tf-google-gke-cluster"

  GOOGLE_REGION           = var.GOOGLE_REGION
  GOOGLE_PROJECT          = var.GOOGLE_PROJECT
  GKE_CLUSTER_NAME        = var.GKE_CLUSTER_NAME
  GKE_DELETION_PROTECTION = var.GKE_DELETION_PROTECTION
  GKE_POOL_NAME           = var.GKE_POOL_NAME
  GKE_MACHINE_TYPE        = var.GKE_MACHINE_TYPE
  GKE_DISK_SIZE_GB        = var.GKE_DISK_SIZE_GB
  GKE_NUM_NODES           = var.GKE_NUM_NODES
}

module "tls_private_key" {
  source = "github.com/den-vasyliev/tf-hashicorp-tls-keys"

  algorithm = "RSA"
}

module "flux_bootstrap" {
  source = "github.com/Makushchenko/tf-fluxcd-flux-bootstrap"

  kube_config_host       = module.gke_cluster.config_host
  kube_config_token      = module.gke_cluster.config_token
  kube_ca_certificate    = module.gke_cluster.ca_certificate
  github_repository      = "${var.GITHUB_OWNER}/${var.FLUX_GITHUB_REPO}"
  github_token           = var.GITHUB_TOKEN
  kustomization_override = file("${path.module}/flux-kbot-bootstrap/kustomization.yaml")
  private_key            = module.tls_private_key.private_key_pem
}

# --- TO DO: migrate to module ---
resource "github_repository_file" "seed_kbot_bootstrap" {
  for_each            = local.seed_kbot_bootstrap
  repository          = var.FLUX_GITHUB_REPO
  branch              = data.github_repository.flux_gitops.default_branch
  file                = each.key
  content             = each.value
  commit_message      = "Seed ${each.key} via Terraform"
  commit_author       = var.GITHUB_OWNER
  commit_email        = var.GITHUB_EMAIL
  overwrite_on_create = true

  depends_on = [module.github_repository, module.flux_bootstrap]
}

module "gke-workload-identity" {
  source = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"

  use_existing_k8s_sa = true
  name                = "kustomize-controller"
  namespace           = "flux-system"
  project_id          = var.GOOGLE_PROJECT
  cluster_name        = var.GKE_CLUSTER_NAME
  location            = var.GOOGLE_REGION
  annotate_k8s_sa     = true
  roles               = ["roles/cloudkms.cryptoKeyEncrypterDecrypter"]
}

module "kms" {
  source  = "terraform-google-modules/kms/google"
  version = "~> 4.0"

  project_id      = var.GOOGLE_PROJECT
  location        = "global"
  keyring         = "sops-flux-${local.application}"
  keys            = ["sops-key-flux-${local.application}"]
  prevent_destroy = false
}

# --- TO DO: migrate to module ---
resource "github_repository_file" "seed_flux_bootstrap" {
  for_each            = local.seed_flux_bootstrap
  repository          = var.FLUX_GITHUB_REPO
  branch              = data.github_repository.flux_gitops.default_branch
  file                = each.key
  content             = each.value
  commit_message      = "Seed ${each.key} via Terraform"
  commit_author       = var.GITHUB_OWNER
  commit_email        = var.GITHUB_EMAIL
  overwrite_on_create = true

  depends_on = [module.gke-workload-identity]
}