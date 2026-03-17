# ============================================================
# Dockerfile for mihomo-docker
# Multi-stage build: mihomo kernel + metacubexd Web UI
# ============================================================

# ----------------------------------------------------------
# Stage 1: Build mihomo from source (Alpha branch)
# ----------------------------------------------------------
FROM golang:1.24-alpine AS builder

ARG TARGETARCH
ARG MIHOMO_VERSION=Alpha

RUN apk add --no-cache git ca-certificates build-base

WORKDIR /src

RUN git clone --depth 1 --branch ${MIHOMO_VERSION} https://github.com/MetaCubeX/mihomo.git .

# Obtain version information for build-time injection
RUN VERSION=$(git describe --tags --always 2>/dev/null || echo "unknown") && \
    BUILDTIME=$(date -u '+%Y-%m-%dT%H:%M:%SZ') && \
    CGO_ENABLED=0 GOOS=linux GOARCH=${TARGETARCH} \
    go build -trimpath \
      -tags "with_gvisor" \
      -ldflags "-s -w -X 'github.com/metacubex/mihomo/constant.Version=${VERSION}' -X 'github.com/metacubex/mihomo/constant.BuildTime=${BUILDTIME}'" \
      -o /mihomo

# ----------------------------------------------------------
# Stage 2: Download metacubexd Web UI
# ----------------------------------------------------------
FROM alpine:latest AS frontend

ARG METACUBEXD_VERSION=v1.243.0

RUN apk add --no-cache curl tar

WORKDIR /ui

RUN curl -fsSL \
    "https://github.com/MetaCubeX/metacubexd/releases/download/${METACUBEXD_VERSION}/compressed-dist.tgz" \
    | tar -xz --strip-components=0

# ----------------------------------------------------------
# Stage 3: Final runtime image
# ----------------------------------------------------------
FROM alpine:latest

LABEL org.opencontainers.image.title="mihomo-docker" \
      org.opencontainers.image.description="All-in-one Docker image packaging mihomo proxy kernel with metacubexd Web UI" \
      org.opencontainers.image.authors="Tsutomu-miku" \
      org.opencontainers.image.url="https://github.com/Tsutomu-miku/mihomo-docker" \
      org.opencontainers.image.source="https://github.com/Tsutomu-miku/mihomo-docker" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.vendor="Tsutomu-miku"

RUN apk add --no-cache \
    ca-certificates \
    tzdata \
    bash \
    curl \
    && update-ca-certificates

# Create configuration directory
RUN mkdir -p /root/.config/mihomo

# Copy mihomo binary from builder stage
COPY --from=builder /mihomo /usr/local/bin/mihomo

# Copy metacubexd UI from frontend stage
COPY --from=frontend /ui /ui

# Copy default configuration
COPY config/config.yaml /etc/mihomo/default-config.yaml

# Copy entrypoint script
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Configuration volume
VOLUME ["/root/.config/mihomo"]

# Expose ports:
#   7890 - HTTP/Mixed proxy
#   7891 - SOCKS5 proxy
#   9090 - RESTful API & Web UI
#   53   - DNS (TCP & UDP)
EXPOSE 7890 7891 9090 53/tcp 53/udp

ENTRYPOINT ["/entrypoint.sh"]
