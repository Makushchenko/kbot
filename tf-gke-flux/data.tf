data "google_client_config" "default" {}

data "google_compute_instance_group" "node_instance_groups" {
  self_link  = module.gke_cluster.managed_instance_group_urls[0]
  depends_on = [module.gke_cluster]
}

# data "google_compute_instance" "nodes" {
#   for_each  = toset(data.google_compute_instance_group.node_instance_groups.instances[*])
#   self_link = each.key
# }