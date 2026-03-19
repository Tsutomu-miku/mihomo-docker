# ============================================================
# Stage 1: Build mihomo from source (Alpha branch)
# ============================================================
FROM golang:1.24-alpine AS builder

RUN apk add --no-cache git make

WORKDIR /src
RUN git clone --branch Alpha --depth 1 https://github.com/MetaCubeX/mihomo.git .

# Build with all tags for full feature support
RUN go build -trimpath -ldflags "-s -w \
    -X 'github.com/metacubex/mihomo/constant.Version=$(git describe --tags --always)' \
    -X 'github.com/metacubex/mihomo/constant.BuildTime=$(date -u +%Y-%m-%dT%H:%M:%SZ)'" \
    -tags "with_gvisor" \
    -o /mihomo

# ============================================================
# Stage 2: Download frontend (metacubexd)
# NOTE: upstream changed from .zip to .tgz as of v1.243.0
# ============================================================
FROM alpine:latest AS frontend

RUN apk add --no-cache wget && \
    wget -q -O /tmp/ui.tgz \
      "https://github.com/MetaCubeX/metacubexd/releases/latest/download/compressed-dist.tgz" && \
    mkdir -p /ui && \
    tar -xzf /tmp/ui.tgz -C /ui && \
    rm /tmp/ui.tgz

# ============================================================
# Stage 3: Download GEO database files
# ============================================================
FROM alpine:latest AS geodata

RUN apk add --no-cache wget && mkdir -p /geodata && \
    echo "Downloading geo databases..." && \
    wget -q -O /geodata/geoip.dat \
      "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.dat" && \
    wget -q -O /geodata/geosite.dat \
      "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat" && \
    wget -q -O /geodata/geoip.metadb \
      "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.metadb" && \
    wget -q -O /geodata/country.mmdb \
      "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/country.mmdb" && \
    wget -q -O /geodata/GeoLite2-ASN.mmdb \
      "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/GeoLite2-ASN.mmdb" && \
    echo "All geo databases downloaded successfully"

# ============================================================
# Stage 4: Final runtime image
# ============================================================
FROM alpine:latest

LABEL org.opencontainers.image.source="https://github.com/Tsutomu-miku/mihomo-docker"
LABEL org.opencontainers.image.description="mihomo (Clash.Meta) Docker - All-in-One Proxy with Web UI"

# Install runtime dependencies
RUN apk add --no-cache ca-certificates tzdata iptables

# Create directories
RUN mkdir -p /root/.config/mihomo/ui \
             /opt/mihomo/ui \
             /opt/mihomo/geodata

# Copy mihomo binary
COPY --from=builder /mihomo /mihomo

# Copy frontend UI to BOTH active and backup locations
COPY --from=frontend /ui /root/.config/mihomo/ui
COPY --from=frontend /ui /opt/mihomo/ui

# Copy geo database files to BOTH active and backup locations
COPY --from=geodata /geodata/ /root/.config/mihomo/
COPY --from=geodata /geodata/ /opt/mihomo/geodata/

# Copy default config (used when no config is mounted)
COPY config/config.yaml /opt/mihomo/config.yaml

# Copy entrypoint script
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Environment defaults
ENV TZ=Asia/Shanghai

# Expose ports
# 7890: HTTP/SOCKS mixed proxy
# 7891: Reserved for additional proxy port
# 9090: External controller (API + Web UI)
EXPOSE 7890 7891 9090

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -q --spider http://127.0.0.1:9090 || exit 1

ENTRYPOINT ["/entrypoint.sh"]
