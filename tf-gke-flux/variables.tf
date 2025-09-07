variable "GOOGLE_PROJECT" {
  type        = string
  description = "GCP project name"
}

variable "GOOGLE_REGION" {
  type        = string
  default     = "us-central1-c"
  description = "GCP region to use"
}

variable "GKE_MACHINE_TYPE" {
  type        = string
  default     = "g1-small"
  description = "Machine type"
}

variable "GKE_DISK_SIZE_GB" {
  type        = number
  default     = 30
  description = "Size of the disk attached to each node, specified in GB"
}

variable "GKE_NUM_NODES" {
  type        = number
  default     = 2
  description = "GKE nodes number"
}

variable "GKE_CLUSTER_NAME" {
  type        = string
  default     = "main"
  description = "GKE cluster name"
}

variable "GKE_POOL_NAME" {
  type        = string
  default     = "main"
  description = "GKE pool name"
}

variable "GKE_DELETION_PROTECTION" {
  type        = bool
  default     = true
  description = "GKE deletion protection"
}

variable "GITHUB_OWNER" {
  type        = string
  default     = ""
  description = "GitHub user name set with: export TF_VAR_GITHUB_OWNER="
}

variable "GITHUB_TOKEN" {
  type        = string
  default     = ""
  description = "GitHub token (PAT) set with: export TF_VAR_GITHUB_TOKEN="
  sensitive   = true
}

variable "GITHUB_EMAIL" {
  type        = string
  default     = ""
  description = "GitHub email set with: export TF_VAR_GITHUB_EMAIL="
  sensitive   = true
}

variable "FLUX_GITHUB_REPO" {
  type    = string
  default = "flux-gitops"
}