#!/bin/sh
set -e

# ============================================================
# mihomo Docker Entrypoint
# Handles: config init, UI recovery, geo file recovery, startup
# ============================================================

CONFIG_DIR="/root/.config/mihomo"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
UI_DIR="${CONFIG_DIR}/ui"
BUILTIN_UI_DIR="/opt/mihomo/ui"
BUILTIN_GEO_DIR="/opt/mihomo/geodata"

# --- Ensure config directory exists ---
mkdir -p "${CONFIG_DIR}"

# --- Initialize default config if not present ---
if [ ! -f "${CONFIG_FILE}" ]; then
    echo "[entrypoint] No config.yaml found, copying default..."
    cp /opt/mihomo/config.yaml "${CONFIG_FILE}"
fi

# --- Recover UI files (may be overwritten by volume mount) ---
if [ ! -d "${UI_DIR}" ] || [ -z "$(ls -A "${UI_DIR}" 2>/dev/null)" ]; then
    if [ -d "${BUILTIN_UI_DIR}" ] && [ -n "$(ls -A "${BUILTIN_UI_DIR}" 2>/dev/null)" ]; then
        echo "[entrypoint] UI directory empty/missing, restoring from built-in..."
        mkdir -p "${UI_DIR}"
        cp -r "${BUILTIN_UI_DIR}/"* "${UI_DIR}/"
        echo "[entrypoint] UI files restored to ${UI_DIR}"
    fi
fi

# --- Recover GEO database files (may be overwritten by volume mount) ---
recover_geo_file() {
    local filename="$1"
    if [ ! -f "${CONFIG_DIR}/${filename}" ]; then
        if [ -f "${BUILTIN_GEO_DIR}/${filename}" ]; then
            echo "[entrypoint] ${filename} missing, restoring from built-in..."
            cp "${BUILTIN_GEO_DIR}/${filename}" "${CONFIG_DIR}/${filename}"
        fi
    fi
}

# Recover all geo database files
recover_geo_file "geoip.dat"
recover_geo_file "geosite.dat"
recover_geo_file "geoip.metadb"
recover_geo_file "country.mmdb"
recover_geo_file "GeoLite2-ASN.mmdb"

# --- Set timezone ---
if [ -n "${TZ}" ] && [ -f "/usr/share/zoneinfo/${TZ}" ]; then
    ln -sf "/usr/share/zoneinfo/${TZ}" /etc/localtime
    echo "${TZ}" > /etc/timezone
fi

# --- Startup banner ---
echo "============================================"
echo "  mihomo Docker - All-in-One Proxy"
echo "============================================"
echo "  Config:    ${CONFIG_FILE}"
echo "  UI:        ${UI_DIR}"
echo "  API:       0.0.0.0:9090"
echo "  Mixed:     0.0.0.0:7890"
echo "============================================"

# List geo files status
echo "  GEO files:"
for f in geoip.dat geosite.dat geoip.metadb country.mmdb GeoLite2-ASN.mmdb; do
    if [ -f "${CONFIG_DIR}/${f}" ]; then
        size=$(du -h "${CONFIG_DIR}/${f}" 2>/dev/null | cut -f1)
        echo "    ✓ ${f} (${size})"
    else
        echo "    ✗ ${f} (missing)"
    fi
done
echo "============================================"

# --- Start mihomo ---
exec /mihomo -d "${CONFIG_DIR}" "$@"
