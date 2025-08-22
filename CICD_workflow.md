# CI/CD kbot — Workflow Scheme

```mermaid
flowchart TD
  %% Trigger → Workflow (vertical)
  dev[Push to branch: develop] --> gha[GitHub Actions: CI/CD kbot]

  %% CI job
  subgraph CI [Job CI]
    direction TB
    checkout1[Checkout]
    test1[Run tests: make test]
    login[Login to GHCR]
    buildpush[Build & push image:
    make image push]
    checkout1 --> test1 --> login --> buildpush
  end

  gha --> CI
  ghcr[(GHCR registry)]
  buildpush --> ghcr

  %% CD job
  subgraph CD [Job CD]
    direction TB
    checkout2[Checkout]
    calcver[Compute VERSION]
    bump[Update helm/values.yaml image.tag]
    commitpush[Commit & push]
    checkout2 --> calcver --> bump --> commitpush
  end

  CI --> CD

  repo[(GitHub repo: Makushchenko/kbot)]
  commitpush --> repo

  %% Argo CD auto-sync
  subgraph Argo [Argo CD]
    direction TB
    app[Application: kbot auto-sync]
    render[Helm render at path helm]
    apply[Apply to cluster prune & self-heal]
    app --> render --> apply
  end

  repo --> Argo
  k8s[(Kubernetes namespace: kbot)]
  apply --> k8s
  k8s --> ghcr
```

---

### Reading the diagram

* **CI** builds and pushes a multi‑arch image to **GHCR**.
* **CD** bumps `helm/values.yaml:image.tag` and pushes back to the repo.
* **Argo CD** auto‑sync sees the new commit, renders the Helm chart in `helm`, and applies it to the **k8s** cluster. Pods then pull the freshly built image from **GHCR**.

> Tip: If your Argo CD Application had `helm.parameters`, those would override chart `values.yaml`. Removing them lets `values.yaml` control the tag bump shown here.