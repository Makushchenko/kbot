APP          := $(shell basename $(shell git remote get-url origin) .git)
REGISTRY     := ghcr.io/makushchenko
VERSION    	 := $(shell git describe --tags --abbrev=0)-$(shell git rev-parse --short HEAD)
BUILDER_NAME := multiarch-builder
TARGETOS     ?= linux
TARGETARCH   ?= amd64

.PHONY: format lint test get build linux arm macos windows image linux-image arm-image macos-image init-builder windows-image \
		push linux-push arm-push macos-push windows-push clean

format:
	gofmt -s -w ./

lint:
	golint

test:
	go test -v

get:
	go get

#############
# Build GO artifact depends on host OS/Arch
#############
build: format get
	CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
	go build -v -o ${APP} \
	-ldflags "-X=github.com/Makushchenko/kbot/cmd.appVersion=${VERSION}"

#############
# Build GO artifact for dedicated OS/Arch
#############
linux:
	@ARCH=$$(go env GOHOSTARCH); \
	echo "→ building ${APP} for linux/$$ARCH"; \
	$(MAKE) TARGETOS=linux TARGETARCH=$$ARCH build

arm:
	@echo "→ building ${APP} for linux/arm64"; \
	$(MAKE) TARGETOS=linux TARGETARCH=arm64 build

macos:
	@ARCH=$$(go env GOHOSTARCH); \
	echo "→ building ${APP} for darwin/$$ARCH"; \
	$(MAKE) TARGETOS=darwin TARGETARCH=$$ARCH build

windows:
	@ARCH=$$(go env GOHOSTARCH); \
	echo "→ building ${APP}.exe for windows/$$ARCH"; \
	$(MAKE) TARGETOS=windows TARGETARCH=$$ARCH \
			APP=${APP}.exe \
			build

#############
# Image build depends on host OS/Arch
#############
image:
	docker build \
		--build-arg TARGETOS=$$(go env GOHOSTOS) \
		--build-arg TARGETARCH=$$(go env GOHOSTARCH) \
		--target final-${TARGETOS} \
		-t ${REGISTRY}/${APP}:${VERSION}-${TARGETOS}-${TARGETARCH} .

#############
# Image build for dedicated OS/Arch
#############
linux-image:
	docker build \
		--build-arg TARGETOS=linux \
		--build-arg TARGETARCH=${TARGETARCH} \
		--target final-linux \
		-t ${REGISTRY}/${APP}:${VERSION}-${TARGETOS}-${TARGETARCH} .

arm-image:
	docker build \
		--build-arg TARGETOS=linux \
		--build-arg TARGETARCH=arm64 \
		--target final-linux \
		-t ${REGISTRY}/${APP}:${VERSION}-${TARGETOS}-${TARGETARCH} .

macos-image:
	@echo "In development..."

init-builder:
	@docker buildx inspect ${BUILDER_NAME} >/dev/null 2>&1 \
		|| docker buildx create --use --name ${BUILDER_NAME}

windows-image: init-builder
	@echo "---EARLY ACCESS---"
	@ARCH=$$(go env GOHOSTARCH); \
	docker buildx build \
		--builder ${BUILDER_NAME}  \
		--platform windows/$$ARCH \
		--build-arg TARGETOS=windows \
		--build-arg TARGETARCH=$$ARCH \
		--build-arg APP=${APP}.exe \
		--target final-windows \
		-t ${REGISTRY}/${APP}:${VERSION}-${TARGETOS}-${TARGETARCH} \
		--load .

#############
# Push to registry depends on host OS/Arch
#############
push:
	docker push ${REGISTRY}/${APP}:${VERSION}-${TARGETOS}-${TARGETARCH}

#############
# Push to registry for dedicated OS/Arch
#############
linux-push:
	docker push ${REGISTRY}/${APP}:${VERSION}-linux-${TARGETARCH}

arm-push:
	docker push ${REGISTRY}/${APP}:${VERSION}-linux-arm64

macos-push:
	@echo "In development..."

windows-push:
	docker push ${REGISTRY}/${APP}:${VERSION}-windows-${TARGETARCH}

#############
# Clean all local artifacts and images
#############
clean:
	@rm -f ${APP} ${APP}.exe
	-@docker rmi ${REGISTRY}/${APP}:${VERSION}-${TARGETOS}-${TARGETARCH} \
				${REGISTRY}/${APP}:${VERSION}-linux-arm64 \
				${REGISTRY}/${APP}:${VERSION}-windows-${TARGETARCH}
