ARG TARGETOS=linux
ARG TARGETARCH=amd64
ARG APP=kbot

# ─── builder ───────────────────────────────────────────
FROM --platform=${BUILDPLATFORM} quay.io/projectquay/golang:1.24 AS builder
ARG TARGETOS TARGETARCH APP

WORKDIR /go/src/app
COPY . .

RUN CGO_ENABLED=0 \
    GOOS=${TARGETOS} \
    GOARCH=${TARGETARCH} \
    make build APP=${APP}

# ─── final stage: Linux/MacOS (any arch) ────────────────────
FROM scratch AS final
WORKDIR /

COPY --from=builder /go/src/app/kbot /kbot

#COPY --from=alpine:latest /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

ENTRYPOINT ["/kbot"]
CMD ["version"]

# # ─── final stage: Windows ─────────────────────────────
# FROM mcr.microsoft.com/windows/nanoserver:1809 AS final-windows
# WORKDIR C:/app

# COPY --from=builder /go/src/app/kbot.exe /kbot.exe

# ENTRYPOINT ["C:\\app\\kbot.exe"]
# CMD ["version"]