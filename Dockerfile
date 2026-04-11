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
# Stage 4: Download Sub-Store backend + frontend
# ============================================================
FROM alpine:latest AS substore

RUN apk add --no-cache wget unzip && \
    mkdir -p /sub-store/backend /sub-store/frontend && \
    echo "Downloading Sub-Store backend..." && \
    wget -q -O /sub-store/backend/sub-store.bundle.js \
      "https://github.com/sub-store-org/Sub-Store/releases/latest/download/sub-store.bundle.js" && \
    echo "Downloading Sub-Store frontend..." && \
    wget -q -O /tmp/frontend.zip \
      "https://github.com/sub-store-org/Sub-Store-Front-End/releases/latest/download/dist.zip" && \
    unzip -q /tmp/frontend.zip -d /tmp/fe && \
    # dist.zip extracts to dist/ subdirectory - flatten it
    cp -r /tmp/fe/dist/* /sub-store/frontend/ 2>/dev/null || \
    cp -r /tmp/fe/* /sub-store/frontend/ && \
    rm -rf /tmp/frontend.zip /tmp/fe && \
    # Verify index.html exists
    ls -la /sub-store/frontend/index.html && \
    echo "Sub-Store downloaded successfully"

# ============================================================
# Stage 5: Final runtime image
# ============================================================
FROM alpine:latest

LABEL org.opencontainers.image.source="https://github.com/Tsutomu-miku/mihomo-docker"
LABEL org.opencontainers.image.description="mihomo Docker - All-in-One Proxy with Web UI & Sub-Store"

# Install runtime dependencies (add nodejs for Sub-Store)
RUN apk add --no-cache ca-certificates tzdata iptables nodejs

# Create directories
RUN mkdir -p /root/.config/mihomo/ui \
             /opt/mihomo/ui \
             /opt/mihomo/geodata \
             /opt/sub-store/backend \
             /opt/sub-store/frontend \
             /opt/sub-store/data

# Copy mihomo binary
COPY --from=builder /mihomo /mihomo

# Copy frontend UI to BOTH active and backup locations
COPY --from=frontend /ui /root/.config/mihomo/ui
COPY --from=frontend /ui /opt/mihomo/ui

# Copy geo database files to BOTH active and backup locations
COPY --from=geodata /geodata/ /root/.config/mihomo/
COPY --from=geodata /geodata/ /opt/mihomo/geodata/

# Copy Sub-Store backend + frontend
COPY --from=substore /sub-store/backend/ /opt/sub-store/backend/
COPY --from=substore /sub-store/frontend/ /opt/sub-store/frontend/

# Copy default config (used when no config is mounted)
COPY config/config.yaml /opt/mihomo/config.yaml

# Copy entrypoint script
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Environment defaults
ENV TZ=Asia/Shanghai
# Sub-Store backend serves API
ENV SUB_STORE_BACKEND_API_HOST=0.0.0.0
ENV SUB_STORE_BACKEND_API_PORT=3001
# Sub-Store frontend (static files) on separate port to avoid conflict
ENV SUB_STORE_FRONTEND_HOST=0.0.0.0
ENV SUB_STORE_FRONTEND_PORT=3002
ENV SUB_STORE_FRONTEND_PATH=/opt/sub-store/frontend
ENV SUB_STORE_DATA_BASE_PATH=/opt/sub-store/data

# Expose ports
# 7890: HTTP/SOCKS mixed proxy
# 9090: External controller (API + Web UI)
# 3001: Sub-Store Backend API
# 3002: Sub-Store Frontend UI
EXPOSE 7890 9090 3001 3002

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -q --spider http://127.0.0.1:9090 || exit 1

ENTRYPOINT ["/entrypoint.sh"]
