#!/bin/sh
set -e

# ============================================================
# mihomo Docker Entrypoint (All-in-One)
# - Sub-Store  (background)  → :3001 (API) + :3002 (UI)
# - mihomo     (foreground)  → :7890 :9090
# ============================================================

CONFIG_DIR="/root/.config/mihomo"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
UI_DIR="${CONFIG_DIR}/ui"
PROVIDERS_DIR="${CONFIG_DIR}/proxy_providers"
BUILTIN_UI_DIR="/opt/mihomo/ui"
BUILTIN_GEO_DIR="/opt/mihomo/geodata"

SUB_STORE_BACKEND="/opt/sub-store/backend/sub-store.bundle.js"
SUB_STORE_DATA="${SUB_STORE_DATA_BASE_PATH:-/opt/sub-store/data}"

# ========================
# Initialize directories
# ========================
mkdir -p "${CONFIG_DIR}" "${UI_DIR}" "${PROVIDERS_DIR}" "${SUB_STORE_DATA}"

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
# Start Sub-Store (background)
# ========================
if [ -f "${SUB_STORE_BACKEND}" ]; then
  echo "[sub-store] Starting backend on :${SUB_STORE_BACKEND_API_PORT:-3001}, frontend on :${SUB_STORE_FRONTEND_PORT:-3002}..."
  node "${SUB_STORE_BACKEND}" &
  SUB_STORE_PID=$!
  echo "[sub-store] Sub-Store started (PID: ${SUB_STORE_PID})"
  # Wait for Sub-Store to be ready before mihomo starts pulling providers
  echo "[sub-store] Waiting for backend to be ready..."
  for i in $(seq 1 15); do
    if wget -q --spider "http://127.0.0.1:${SUB_STORE_BACKEND_API_PORT:-3001}" 2>/dev/null; then
      echo "[sub-store] Backend is ready"
      break
    fi
    sleep 1
  done
else
  echo "[sub-store] WARNING: Sub-Store backend not found, skipping"
fi

# ========================
# Graceful shutdown
# ========================
cleanup() {
  echo "[shutdown] Stopping services..."
  [ -n "${SUB_STORE_PID}" ] && kill "${SUB_STORE_PID}" 2>/dev/null
  [ -n "${MIHOMO_PID}" ] && kill "${MIHOMO_PID}" 2>/dev/null
  wait 2>/dev/null
  echo "[shutdown] All services stopped"
  exit 0
}
trap cleanup SIGTERM SIGINT

# ========================
# Startup banner
# ========================
echo "============================================"
echo "  mihomo Docker (All-in-One)"
echo "============================================"
echo "  Proxy      : :7890"
echo "  Dashboard  : :9090/ui"
echo "  Sub-Store  : :${SUB_STORE_FRONTEND_PORT:-3002}"
echo "  Config     : ${CONFIG_FILE}"
echo "  GEO        : $(ls ${CONFIG_DIR}/*.dat ${CONFIG_DIR}/*.mmdb ${CONFIG_DIR}/*.metadb 2>/dev/null | wc -l) file(s)"
echo "============================================"
echo ""

# ========================
# Start mihomo (foreground with wait)
# ========================
/mihomo -d "${CONFIG_DIR}" "$@" &
MIHOMO_PID=$!
wait "${MIHOMO_PID}"
