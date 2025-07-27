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