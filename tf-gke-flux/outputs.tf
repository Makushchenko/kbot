# output "node_ip" {
#   value = [for node in data.google_compute_instance.nodes : node.network_interface[0].access_config[0].nat_ip]
# }

# output "FLUX_GITHUB_TARGET_PATH" {
#   value = var.FLUX_GITHUB_TARGET_PATH
# }