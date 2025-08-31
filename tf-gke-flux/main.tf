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

  kube_config_host    = module.gke_cluster.config_host
  kube_config_token   = module.gke_cluster.config_token
  kube_ca_certificate = module.gke_cluster.ca_certificate
  github_repository   = "${var.GITHUB_OWNER}/${var.FLUX_GITHUB_REPO}"
  github_token        = var.GITHUB_TOKEN
  private_key         = module.tls_private_key.private_key_pem
}