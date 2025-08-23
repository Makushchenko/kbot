## 1) Install k3d

```bash
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | sudo bash
```

## 2) Create a k3d Cluster

```bash
k3d cluster create jenkins \
  --servers 1 \
  --agents 3
```