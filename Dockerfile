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

COPY --from=alpine:latest /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

ENTRYPOINT ["/kbot"]
CMD ["version"]