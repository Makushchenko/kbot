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