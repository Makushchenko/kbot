data "google_client_config" "default" {}

data "google_compute_instance_group" "node_instance_groups" {
  self_link  = module.gke_cluster.managed_instance_group_urls[0]
  depends_on = [module.gke_cluster]
}

# Fetch the repo’s default branch so we don’t hardcode "main"
data "github_repository" "flux_gitops" {
  full_name  = "${var.GITHUB_OWNER}/${var.FLUX_GITHUB_REPO}"
  depends_on = [module.github_repository, module.flux_bootstrap]
}

# data "google_compute_instance" "nodes" {
#   for_each  = toset(data.google_compute_instance_group.node_instance_groups.instances[*])
#   self_link = each.key
# }