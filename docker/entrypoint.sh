#!/bin/bash
# ============================================================
# Entrypoint script for mihomo-docker
# Handles config initialization, timezone, and process startup
# ============================================================

set -e

CONFIG_DIR="/root/.config/mihomo"
DEFAULT_CONFIG="/etc/mihomo/default-config.yaml"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"

# ----------------------------------------------------------
# Ensure config directory exists
# ----------------------------------------------------------
mkdir -p "${CONFIG_DIR}"

# ----------------------------------------------------------
# Copy default config if none exists
# ----------------------------------------------------------
if [ ! -f "${CONFIG_FILE}" ]; then
    echo "[entrypoint] No config.yaml found in ${CONFIG_DIR}."
    echo "[entrypoint] Copying default configuration..."
    cp "${DEFAULT_CONFIG}" "${CONFIG_FILE}"
    echo "[entrypoint] Default config written to ${CONFIG_FILE}."
    echo "[entrypoint] Please edit it to add your proxy providers."
fi

# ----------------------------------------------------------
# Set timezone if TZ environment variable is provided
# ----------------------------------------------------------
if [ -n "${TZ}" ]; then
    TZ_FILE="/usr/share/zoneinfo/${TZ}"
    if [ -f "${TZ_FILE}" ]; then
        ln -sf "${TZ_FILE}" /etc/localtime
        echo "${TZ}" > /etc/timezone
        echo "[entrypoint] Timezone set to ${TZ}."
    else
        echo "[entrypoint] WARNING: Timezone '${TZ}' not found, using UTC."
    fi
fi

# ----------------------------------------------------------
# Display startup information
# ----------------------------------------------------------
echo "============================================================"
echo "  mihomo-docker"
echo "  Proxy kernel : mihomo (Clash.Meta)"
echo "  Web UI       : metacubexd"
echo "  Config dir   : ${CONFIG_DIR}"
echo "  API address  : http://0.0.0.0:9090"
echo "  Web UI       : http://0.0.0.0:9090/ui"
echo "============================================================"

# ----------------------------------------------------------
# Start mihomo with config directory, passing additional args
# ----------------------------------------------------------
exec mihomo -d "${CONFIG_DIR}" "$@"
