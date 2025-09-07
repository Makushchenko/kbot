# Configure the Google Cloud provider
provider "google" {
  # The GCP project to use
  project = var.GOOGLE_PROJECT
  # The GCP region to deploy resources in
  region = var.GOOGLE_REGION

  default_labels = {
    environment = local.environment
    owner       = local.owner
    project     = var.GOOGLE_PROJECT
  }
}

provider "flux" {
  kubernetes = {
    host                   = module.gke_cluster.config_host
    token                  = module.gke_cluster.config_token
    cluster_ca_certificate = module.gke_cluster.ca_certificate
  }
  git = {
    url = "https://github.com/${var.GITHUB_OWNER}/${var.FLUX_GITHUB_REPO}.git"
    http = {
      username = "git" # This can be any string when using a personal access token
      password = var.GITHUB_TOKEN
    }
  }
}

provider "github" {
  owner = var.GITHUB_OWNER
  token = var.GITHUB_TOKEN
}