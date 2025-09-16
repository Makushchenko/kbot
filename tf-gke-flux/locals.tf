locals {
  environment = "demo"
  application = "kbot"
  owner       = "makushchenko"

  # --- kbot
  seed_kbot_bootstrap = {
    "clusters/kbot/kbot-ns.yaml" = file("${path.module}/flux-kbot-bootstrap/kbot-ns.yaml")
    "clusters/kbot/kbot-gr.yaml" = file("${path.module}/flux-kbot-bootstrap/kbot-gr.yaml")
    "clusters/kbot/kbot-hr.yaml" = file("${path.module}/flux-kbot-bootstrap/kbot-hr.yaml")
  }

  # --- flux
  seed_flux_bootstrap = {
    "clusters/flux-system/sops-patch.yaml"        = file("${path.module}/flux-kbot-bootstrap/sops-patch.yaml")
    "clusters/flux-system/sa-patch.yaml"          = file("${path.module}/flux-kbot-bootstrap/sa-patch.yaml")
    "clusters/flux-system/obs-kustomization.yaml" = file("${path.module}/flux-kbot-bootstrap/obs-kustomization.yaml")
  }

  # # --- observability
  # seed_observability_bootstrap = {
  #   for f in fileset("${path.module}/flux-kbot-bootstrap/observability", "**") :
  #   "clusters/observability/${f}" => file("${path.module}/flux-kbot-bootstrap/observability/${f}")
  # }

}