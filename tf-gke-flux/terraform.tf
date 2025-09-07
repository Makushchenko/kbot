terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">6.35"
    }
    flux = {
      source  = "fluxcd/flux"
      version = "~> 1.5.0"
    }
    github = {
      source  = "integrations/github"
      version = ">= 5.9.1"
    }
  }
}
