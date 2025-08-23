# Jenkins CI/CD – Step‑by‑Step (GitHub Codespace/Workspace Agent + GHCR)

This guide walks you from a fresh Jenkins Helm install to a working Declarative Pipeline that builds, optionally tests/lints, builds a Docker image, and pushes to **GitHub Container Registry (ghcr.io)**. It also shows how to add a **custom SSH agent (Node)** that runs inside a GitHub Codespace/Workspace‑like VM.

---

## 0) Prerequisites

* Jenkins installed from the official Helm chart (controller is reachable via browser).
* Docker available on the build agent (your Codespace/Workspace VM).
* Your GitHub PAT with scopes: `write:packages`, `read:packages` (for GHCR).
* Repository: `https://github.com/Makushchenko/kbot.git`
* Install k3d
```bash
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | sudo bash
```
* Create a k3d Cluster
```bash
k3d cluster create jenkins \
  --servers 1 \
  --agents 3
```

---

## 1) Install Required Plugins

In Jenkins UI → **Manage Jenkins → Plugins**:

* **SSH Build Agents** (to connect to your Codespace/Workspace as a Node)
* **Docker Pipeline** (provides `docker.withRegistry` used in the `push` stage)

After installation, restart Jenkins if prompted.

---

## 2) Prepare the GitHub Codespace/Workspace VM as an SSH Agent

> The goal: Jenkins should “Launch agents via SSH” to this VM.

On the VM:

```bash
# Find the primary IP (example shows 10.0.0.168 on eth0)
ip a
# -> 10.0.0.168

# Check sshd port (default is 22; example uses 2222)
sudo vi /etc/ssh/sshd_config
#   Ensure/adjust:
#   Port 2222
#   PasswordAuthentication no
#   PubkeyAuthentication yes
sudo systemctl restart sshd

# Create a keypair (on the VM) for the 'jenkins' user or current user
ssh-keygen -t ed25519 -C "jenkins-agent"

# Authorize public key for SSH logins on this VM
cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Test SSH locally (optional, from a different host)
ssh -p 2222 <user>@10.0.0.168
```

> ⚠️ **Security note:** never commit or publish your **private** key. You’ll paste it into Jenkins Credentials (encrypted at rest).
> To view it locally (for pasting only):
>
> ```bash
> cat ~/.ssh/id_ed25519   # PRIVATE key – keep secret
> ```

---

## 3) Add the VM as a Jenkins Node (SSH Agent)

Jenkins UI:

1. **Manage Jenkins → Nodes → New Node**
2. **Name**: `kbot-github-codespace` (any name)
3. **Type**: **Permanent Agent**
4. **Remote root directory**: e.g. `/tmp`
5. **Labels**: `github-codespace` (so jobs can target it)
6. **Launch method**: **Launch agents via SSH**

   * **Host**: `10.0.0.168`
   * **Port**: `2222`
   * **Credentials**: Add → **SSH Username with private key**

     * Username: the Linux user on the VM
     * Private key: paste contents of `~/.ssh/id_ed25519`
   * **Host Key Verification Strategy**: as per your policy (e.g., “Known hosts file” or “Non verifying” in labs)
7. Save, then click into the node and **Launch agent**. It should show **online**.

> If your pipeline must run specifically on this node, either:
>
> * Set pipeline‑wide `agent { label 'github-codespace' }`, **or**
> * Add `agent { label 'github-codespace' }` on stages that need Docker.

---

## 4) Create GHCR Credentials in Jenkins

Jenkins UI → **Manage Jenkins → Credentials → (Global)** → **Add Credentials**:

* **Kind**: Username with password
* **Username**: your GitHub username
* **Password**: your GitHub **PAT** (`write:packages`, `read:packages`)
* **ID**: `ghcr-creds`  ← must match Jenkinsfile

---

## 5) Create a Pipeline Job Using the Jenkinsfile

Use the following **Jenkinsfile** (from your repo `./pipeline/jenkins.groovy`). It includes parameters to skip tests/lint and uses GHCR for `push`.

```groovy
pipeline {

    agent {
        label 'github-codespace'
    }

    environment {
        REPO = 'https://github.com/Makushchenko/kbot.git'
        BRANCH = 'main'
    }
    
    parameters {
        choice(
            name: 'TARGETOS',
            choices: ['linux', 'darwin', 'windows'],
            description: 'Target operating system'
        )
        choice(
            name: 'ARCH',
            choices: ['amd64', 'arm64'],
            description: 'Target architecture'
        )
        booleanParam(
            name: 'SKIP_TESTS',
            defaultValue: false,
            description: 'Skip running tests'
        )
        booleanParam(
            name: 'SKIP_LINT',
            defaultValue: true,
            description: 'Skip running linter'
        )
    }    

    stages {
        stage('clone') {
            steps {
                echo 'CLONE REPOSITORY'
                git branch: "${BRANCH}", url: "${REPO}"
            }
        }
        stage('test') {
            when {
                expression { return !params.SKIP_TESTS }
            }            
            steps {
                echo 'TEST EXECUTION STARTED'
                sh 'make test'
            }
        }
        stage('lint') {
            when {
                expression { return !params.SKIP_LINT }
            }            
            steps {
                echo 'LINT EXECUTION STARTED'
                sh 'make lint'
            }
        }        
        stage('build') {
            steps {
                echo 'ARTIFACT BUILD EXECUTION STARTED'
                sh 'make build'
            }
        }
        stage('image') {
            steps {
                echo 'IMAGE BUILD EXECUTION STARTED'
                sh 'make image'
            }
        }
        stage("push") {
            steps {
                script {
                    docker.withRegistry('https://ghcr.io', 'ghcr-creds') {
                        sh 'make push'
                    }
                }
            }
        }
    }
}
```

> **Tip:** If you want to **force** Docker‑heavy stages onto your Codespace node, add:
>
> ```groovy
> stage('image') {
>   agent { label 'github-codespace' }
>   steps { sh 'make image' }
> }
> stage('push') {
>   agent { label 'github-codespace' }
>   steps {
>     script {
>       docker.withRegistry('https://ghcr.io', 'ghcr-creds') {
>         sh 'make push'
>       }
>     }
>   }
> }
> ```
>
> Or set `pipeline { agent { label 'github-codespace' } }` globally if **all** stages should run there.

---

## 6) Expected Make Targets & Image Naming

Your `make push` should push to GHCR:

```
ghcr.io/<GH_USERNAME>/<image_name>:<tag>
```

Ensure your Makefile tags accordingly (example):

```make
APP         := $(shell basename $(shell git remote get-url origin) .git)
REGISTRY    := ghcr.io/makushchenko
VERSION     := $(shell git describe --tags --abbrev=0)-$(shell git rev-parse --short HEAD)
TARGETOS    ?= linux
ARCH        ?= amd64
TARGETARCH  ?= $(ARCH)

...

push:
	docker push ${REGISTRY}/${APP}:${VERSION}-${TARGETOS}-${TARGETARCH}
```

---

## 7) Run a Build

* Click **Build with Parameters**.
* Choose `TARGETOS`, `ARCH`, and whether to set `SKIP_TESTS` / `SKIP_LINT`.
* Watch stages execute; skipped stages will show as **skipped** in UI.
* On success, check your package at **[https://github.com/users/](https://github.com/users/)\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*/packages**.

---

## 8) Troubleshooting

* **`No such property: docker`**
  Install **Docker Pipeline** plugin and run on a node with Docker CLI/daemon access.
* **`denied: permission`**\*\* on push\*\*
  PAT missing `write:packages` or image name not under `ghcr.io/<your-user>/...`.
* **SSH agent offline**
  Verify IP/port (`ip a`, `sshd_config`), firewall rules, correct **SSH private key** in credentials, and that the remote user has permissions on the `Remote root directory`.
* **Stage never runs**
  Check `when` conditions and parameter values.

---

## 9) Quick Reference (Commands Recap)

```bash
# On the agent VM
ip a                            # find IP (e.g., 10.0.0.168)
sudo vi /etc/ssh/sshd_config    # confirm/set Port 2222; enable PubkeyAuthentication
sudo systemctl restart sshd

ssh-keygen -t ed25519 -C "jenkins-agent"
cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Test from another host (optional)
ssh -p 2222 <user>@10.0.0.168
```

> **Never share** the contents of `~/.ssh/id_ed25519` publicly. Paste it only into Jenkins **Crede****l****ntias**

---
