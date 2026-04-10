#!/bin/sh
set -e

# ============================================================
# mihomo Docker Entrypoint
# ============================================================

CONFIG_DIR="/root/.config/mihomo"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
UI_DIR="${CONFIG_DIR}/ui"
PROVIDERS_DIR="${CONFIG_DIR}/proxy_providers"
BUILTIN_UI_DIR="/opt/mihomo/ui"
BUILTIN_GEO_DIR="/opt/mihomo/geodata"

# ========================
# Initialize directories
# ========================
mkdir -p "${CONFIG_DIR}" "${UI_DIR}" "${PROVIDERS_DIR}"

# ========================
# Default config
# ========================
if [ ! -f "${CONFIG_FILE}" ]; then
  echo "[init] config.yaml not found, copying default..."
  cp /opt/mihomo/config.yaml "${CONFIG_FILE}"
  echo "[init] Default config created at ${CONFIG_FILE}"
fi

# ========================
# Restore UI files
# ========================
if [ ! -d "${UI_DIR}" ] || [ -z "$(ls -A "${UI_DIR}" 2>/dev/null)" ]; then
  echo "[init] Restoring dashboard UI..."
  cp -r "${BUILTIN_UI_DIR}/"* "${UI_DIR}/" 2>/dev/null || true
  echo "[init] Dashboard UI restored"
fi

# ========================
# Restore GEO databases
# ========================
GEO_FILES="geoip.dat geosite.dat geoip.metadb country.mmdb GeoLite2-ASN.mmdb"
for f in ${GEO_FILES}; do
  if [ ! -f "${CONFIG_DIR}/${f}" ]; then
    if [ -f "${BUILTIN_GEO_DIR}/${f}" ]; then
      echo "[init] Restoring ${f}..."
      cp "${BUILTIN_GEO_DIR}/${f}" "${CONFIG_DIR}/${f}"
    fi
  fi
done

# ========================
# Timezone
# ========================
if [ -n "${TZ}" ] && [ -f "/usr/share/zoneinfo/${TZ}" ]; then
  ln -sf "/usr/share/zoneinfo/${TZ}" /etc/localtime
  echo "${TZ}" > /etc/timezone
fi

# ========================
# Startup banner
# ========================
echo "============================================"
echo "  mihomo Docker"
echo "============================================"
echo "  Config : ${CONFIG_FILE}"
echo "  UI     : ${UI_DIR}"
echo "  GEO    : $(ls ${CONFIG_DIR}/*.dat ${CONFIG_DIR}/*.mmdb ${CONFIG_DIR}/*.metadb 2>/dev/null | wc -l) file(s)"
echo "============================================"
echo ""

# ========================
# Start mihomo
# ========================
exec /mihomo -d "${CONFIG_DIR}" "$@"
