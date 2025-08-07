APP         := $(shell basename $(shell git remote get-url origin) .git)
REGISTRY    := ghcr.io/makushchenko
VERSION     := $(shell git describe --tags --abbrev=0)-$(shell git rev-parse --short HEAD)
TARGETOS    ?= linux
ARCH        ?= amd64
TARGETARCH  ?= $(ARCH)

.PHONY: init-qemu format lint test get build linux arm macos windows image linux-image arm-image macos-image init-builder windows-image \
        push linux-push arm-push macos-push windows-push clean

# Step: register QEMU handlers for cross-platform builds (needed when TARGETOS/TARGETARCH differs from host)
init-qemu:
	@docker run --privileged --rm tonistiigi/binfmt --install all

format:
	@gofmt -s -w ./

lint:
	@golangci-lint run

test:
	@go test -v

get:
	@go get

#############
# Build GO artifact (depends on host OS/Arch)
#############
build: format get
	CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
	go build -v -o ${APP} \
	-ldflags "-X=github.com/Makushchenko/kbot/cmd.appVersion=${VERSION}"

#############
# Build GO artifact for dedicated OS/Arch
#############
linux: format lint get
	@ARCH=$$(go env GOHOSTARCH); \
	echo "→ building ${APP} for linux/$$ARCH"; \
	$(MAKE) TARGETOS=linux TARGETARCH=$$ARCH build

arm: format lint get
	@echo "→ building ${APP} for linux/arm64"; \
	$(MAKE) TARGETOS=linux TARGETARCH=arm64 build

macos: format lint get
	@ARCH=$$(go env GOHOSTARCH); \
	echo "→ building ${APP} for darwin/$$ARCH"; \
	$(MAKE) TARGETOS=darwin TARGETARCH=$$ARCH build

windows: format lint get
	@ARCH=$$(go env GOHOSTARCH); \
	echo "→ building ${APP}.exe for windows/$$ARCH"; \
	$(MAKE) TARGETOS=windows TARGETARCH=$$ARCH \
		APP=${APP}.exe \
		build

#############
# Image build (with QEMU) depends on host OS/Arch
#############
image:
	docker build \
		--build-arg TARGETOS=$$(go env GOHOSTOS) \
		--build-arg TARGETARCH=$$(go env GOHOSTARCH) \
		-t ${REGISTRY}/${APP}:${VERSION}-${TARGETOS}-${TARGETARCH} .

#############
# Image build for dedicated OS/Arch
#############
linux-image: init-qemu
	docker build \
		--platform=linux/${TARGETARCH} \
		--build-arg TARGETOS=linux \
		--build-arg TARGETARCH=${TARGETARCH} \
		-t ${REGISTRY}/${APP}:${VERSION}-linux-${TARGETARCH} .

arm-image: init-qemu
	docker build \
		--platform=${TARGETOS}/arm64 \
		--build-arg TARGETOS=${TARGETOS} \
		--build-arg TARGETARCH=arm64 \
		-t ${REGISTRY}/${APP}:${VERSION}-${TARGETOS}-arm64 .

macos-image: init-qemu
	docker build \
		--platform=darwin/${TARGETARCH} \
		--build-arg TARGETOS=darwin \
		--build-arg TARGETARCH=${TARGETARCH} \
		-t ${REGISTRY}/${APP}:${VERSION}-macos-${TARGETARCH} .

windows-image: init-qemu
	docker build \
		--platform=windows/${TARGETARCH} \
		--build-arg TARGETOS=windows \
		--build-arg TARGETARCH=${TARGETARCH} \
		--build-arg APP=${APP} \
		-t ${REGISTRY}/${APP}:${VERSION}-windows-${TARGETARCH} .

#############
# Push to registry (depends on host OS/Arch)
#############
push:
	docker push ${REGISTRY}/${APP}:${VERSION}-${TARGETOS}-${TARGETARCH}

#############
# Push for dedicated OS/Arch
#############
linux-push:
	docker push ${REGISTRY}/${APP}:${VERSION}-linux-${TARGETARCH}

arm-push:
	docker push ${REGISTRY}/${APP}:${VERSION}-${TARGETOS}-arm64

macos-push:
	@echo "In development..."

windows-push:
	docker push ${REGISTRY}/${APP}:${VERSION}-windows-${TARGETARCH}

#############
# Clean all artifacts and images for all OS/Arch
#############
clean:
	@rm -f ${APP} ${APP}.exe
	@docker rmi ${REGISTRY}/${APP}:${VERSION}-${TARGETOS}-${TARGETARCH} \
			${REGISTRY}/${APP}:${VERSION}-linux-${TARGETARCH} \
			${REGISTRY}/${APP}:${VERSION}-linux-amd64 \
			${REGISTRY}/${APP}:${VERSION}-linux-arm64 \
			${REGISTRY}/${APP}:${VERSION}-macos-${TARGETARCH} \
			${REGISTRY}/${APP}:${VERSION}-macos-amd64 \
			${REGISTRY}/${APP}:${VERSION}-macos-arm64 \
			${REGISTRY}/${APP}:${VERSION}-windows-${TARGETARCH}  2>/dev/null || true