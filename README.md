# kbot CLI Guide

A simple command-line tool generated with [Cobra](https://github.com/spf13/cobra-cli).

## Prerequisites

* Go 1.18 or newer
* `$GOPATH/bin` or `/usr/local/go/bin` in your `PATH`

## Installation & Setup

1. Initialize your module:

   ```bash
   go mod init github.com/Makushchenko/kbot
   ```
2. Install the Cobra CLI generator:

   ```bash
   go install github.com/spf13/cobra-cli@latest
   ```
3. Bootstrap your application:

   ```bash
   cobra-cli init
   ```

## Generating Commands

* View the default help:

  ```bash
  go run main.go help
  ```
* Add a `version` command:

  ```bash
  cobra-cli add version
  ```
* Add a custom `kbot` command:

  ```bash
  cobra-cli add kbot
  ```

## Building the Binary

Embed the application version and build:

```bash
go build -ldflags "-X=github.com/Makushchenko/kbot/cmd.appVersion=v1.0.0" -o kbot
```

## Usage

* Run the CLI:

  ```bash
  ./kbot
  ```
* Display help:

  ```bash
  ./kbot help
  ```
* Check version:

  ```bash
  ./kbot version
  ```

## Start Telegram Bot Integration (feature/telebot branch)

```bash
git status
git checkout -b feature/telebot
```

Edit `cmd/kbot.go`:

### Add import

```go
import (
	"fmt"
	"log"
	"os"
	"time"

	"github.com/spf13/cobra"
	telebot "gopkg.in/telebot.v4"
)
```

### Add global variable

```go
var (
	TeleToken = os.Getenv("TELE_TOKEN")
)
```

### Basic Setup (v1.0.1)

Update `Run:` function with basic bot setup:

```go
Run: func(cmd *cobra.Command, args []string) {
	fmt.Printf("kbot %s started", appVersion)

	kbot, err := telebot.NewBot(telebot.Settings{
		URL:   "",
		Token: TeleToken,
		Poller: &telebot.LongPoller{
			Timeout: 10 * time.Second,
		},
	})

	if err != nil {
		log.Fatalf("Please check TELE_TOKEN env variable. %s", err)
		return
	}

	kbot.Start()
},
```

### Add alias to `kbotCmd`

```go
Aliases: []string{"start"},
```

### Format and Build (v1.0.1)

```bash
gofmt -s -w ./
go get
go build -ldflags "-X=github.com/Makushchenko/kbot/cmd.appVersion=v1.0.1"
./kbot
./kbot start
```

---

## Enhance Telegram Bot (v1.0.2)

Update `Run:` function to handle payload:

```go
kbot.Handle(telebot.OnText, func(m telebot.Context) error {
	log.Print(m.Message().Payload, m.Text())
	payload := m.Message().Payload

	switch payload {
	case "hello":
		err = m.Send(fmt.Sprintf("Hello I'm Kbot %s!", appVersion))
	}

	return err
})
```

### Rebuild with updated logic (v1.0.2)

```bash
gofmt -s -w ./
go build -ldflags "-X=github.com/Makushchenko/kbot/cmd.appVersion=v1.0.2"
./kbot
./kbot start
```

## Create Telegram Bot and Export Token

* Create a bot via [@BotFather](https://t.me/BotFather)
* Copy the token

### Use `read` to hide API token from logs

```bash
read -s TELE_TOKEN
export TELE_TOKEN
./kbot start
```

> The `read -s` command is used to securely input the Telegram API token without displaying it on the terminal (to avoid leaking it in logs or history).

## What happens on /start hello

When a user sends the command `/start hello` to the bot, it extracts the payload `hello` and responds:

```
Hello I'm Kbot v1.0.2!
```

The version is dynamically injected via the build process.

## Tag and Commit (v1.0.2)

```bash
git add .
git commit -m "DEVOPS-224 #time 1h #comment kbot connected with Telegram Bot return hello message and version on /start hello command"
git tag v1.0.2
git push -u origin feature/telebot
```

## Merge into main via PullRequest

```bash
git checkout main
git pull
git status
```

---

The initial Telegram bot build used version `v1.0.1`. After enhancing it to handle messages like `/start hello`, the project was rebuilt with version `v1.0.2` and the commit was tagged accordingly.

---

# Makefile & Dockerfile

This guide explains how to build the project using the provided Makefile and Dockerfile, as well as essential Git and GitHub Container Registry commands for versioning and publishing.

---

## Step 1: Commands *depends on host OS/Arch*

Use these primary Makefile targets without specifying a platform; they automatically use your **host** OS and architecture.

```bash
# Build binary for host OS/Arch
make build

# Build Docker image for host OS/Arch
make image

# Push image tagged with host OS/Arch
make push

# Remove all binaries and Docker images for all OS/Arch
make clean
```

---

## Step 2: Commands *for dedicated OS/Arch*

When you need explicit control over platform builds, use dedicated Makefile targets:

```bash
# Build binary for specific platforms
make linux    # Linux (host architecture)
make arm      # Linux/ARM64
make windows  # Windows 
make macos    # macOS

# Build Docker images for specific platforms
make linux-image               # Linux (host architecture)
make linux-image ARCH=arm64    # Linux (specify architecture)
make linux-image ARCH=amd64    # Linux (specify architecture)
make arm-image                 # Linux/ARM64
make arm-image TARGETOS=linux  # Specify OS/ARM64
make arm-image TARGETOS=darwin # Specify OS/ARM64
make windows-image             # Windows (in development)
make windows-image ARCH=       # Windows (in development)(specify architecture)
make macos-image               # macOS (in development)
make macos-image ARCH=arm64    # macOS (in development) (specify architecture)
make macos-image ARCH=amd64    # macOS (in development) (specify architecture)

# Push these images for specific platforms to registry
make linux-push     # Push Linux image
make arm-push       # Push Linux/ARM64 image
make windows-push   # Push Windows image
make macos-push     # Push macOS image (in development)

# Remove all binaries and Docker images for all OS/Arch
make clean 
make clean ARCH=arm64
make clean TARGETOS=darwin ARCH=arm64
```

---

## Step 3: Additional setup commands

These commands help with version tagging, commit management, and authenticating to GitHub Container Registry.

```bash
# Retrieve version metadata
git describe --tags --abbrev=0
git rev-parse --short HEAD

# Amend the last commit message and push forcefully
git commit --amend --message "changed message"
git push --force-with-lease origin feature/makefile

# Authenticate to GitHub Container Registry
read -s CR_PAT
echo $CR_PAT | docker login ghcr.io -u Makushchenko --password-stdin

# Install golangci-lint
curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/HEAD/install.sh | sh -s -- -b $(go env GOPATH)/bin v2.3.1
golangci-lint --version
```