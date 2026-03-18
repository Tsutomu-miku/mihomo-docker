#!/bin/bash
# ============================================================
# Entrypoint script for mihomo-docker
# Handles config initialization, timezone, and process startup
# ============================================================

set -e

CONFIG_DIR="/root/.config/mihomo"
DEFAULT_CONFIG="/etc/mihomo/default-config.yaml"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
UI_DIR="${CONFIG_DIR}/ui"
BUILTIN_UI_DIR="/opt/mihomo/ui"

# ----------------------------------------------------------
# Ensure config directory exists
# ----------------------------------------------------------
mkdir -p "${CONFIG_DIR}"

# ----------------------------------------------------------
# Ensure UI files exist in config directory
# If the ui directory is empty or missing (e.g. wiped by volume mount),
# copy the built-in UI files into it.
# ----------------------------------------------------------
if [ ! -d "${UI_DIR}" ] || [ -z "$(ls -A ${UI_DIR} 2>/dev/null)" ]; then
    echo "[entrypoint] UI files not found in ${UI_DIR}."
    if [ -d "${BUILTIN_UI_DIR}" ]; then
        echo "[entrypoint] Copying built-in metacubexd UI files..."
        mkdir -p "${UI_DIR}"
        cp -r "${BUILTIN_UI_DIR}/"* "${UI_DIR}/"
        echo "[entrypoint] UI files copied to ${UI_DIR}."
    else
        echo "[entrypoint] WARNING: Built-in UI not found at ${BUILTIN_UI_DIR}."
    fi
fi

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
echo "  UI dir       : ${UI_DIR}"
echo "  API address  : http://0.0.0.0:9090"
echo "  Web UI       : http://0.0.0.0:9090/ui"
echo "============================================================"

# ----------------------------------------------------------
# Start mihomo with config directory, passing additional args
# ----------------------------------------------------------
exec mihomo -d "${CONFIG_DIR}" "$@"
