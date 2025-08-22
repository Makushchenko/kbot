# CI/CD kbot — Workflow Scheme

```mermaid
flowchart TD
  A[Push to branch: develop] --> B[GitHub Actions workflow: CI/CD kbot]

  subgraph CI [Job: CI]
    direction TB
    C1[Checkout]
    C2[Run tests (make test)]
    C3[Login to GHCR]
    C4[Build and push image (make image push)]
    C1 --> C2 --> C3 --> C4
  end

  B --> CI
  GHCR[(GitHub Container Registry)]
  C4 --> GHCR

  subgraph CD [Job: CD]
    direction TB
    D1[Checkout]
    D2[Compute VERSION]
    D3[Update Helm values (image tag)]
    D4[Commit and push]
    D1 --> D2 --> D3 --> D4
  end

  CI --> CD
  REPO[(GitHub repo)]
  D4 --> REPO

  subgraph ARGO [Argo CD]
    direction TB
    E1[Application: kbot (auto sync)]
    E2[Helm render at path helm/kbot]
    E3[Apply to cluster]
    E1 --> E2 --> E3
  end

  REPO --> ARGO
  K8S[(Kubernetes namespace: kbot)]
  E3 --> K8S
  K8S --> GHCR
```

---

### Reading the diagram

* **CI** builds and pushes a multi‑arch image to **GHCR**.
* **CD** bumps `helm/values.yaml:image.tag` and pushes back to the repo.
* **Argo CD** auto‑sync sees the new commit, renders the Helm chart in `helm`, and applies it to the **k8s** cluster. Pods then pull the freshly built image from **GHCR**.

> Tip: If your Argo CD Application had `helm.parameters`, those would override chart `values.yaml`. Removing them lets `values.yaml` control the tag bump shown here.