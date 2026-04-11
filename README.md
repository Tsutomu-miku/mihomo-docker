# mihomo Docker

> All-in-One proxy solution in a **single Docker image**: **mihomo** + **metacubexd** + **Sub-Store**.

Deploy a full-featured proxy with graphical subscription management — no more manually editing YAML configs.

## Features

- **mihomo Alpha** — Latest Clash Meta kernel with VLESS, Hysteria2, TUIC, etc.
- **metacubexd Dashboard** — Web UI to switch proxy modes, select nodes, monitor traffic
- **Sub-Store Built-in** — Subscription management UI (import, filter, merge, auto-refresh) bundled in the same image
- **Pre-bundled GEO Databases** — geoip.dat, geosite.dat, mmdb, ASN auto-updated
- **Self-healing** — Dashboard UI & GEO files auto-restore if missing
- **Multi-architecture** — amd64 / arm64 / armv7
- **Single Container** — Everything runs in one container, deploy with one command

## Architecture

```
┌─────────────────────────────────────────────┐
│             Single Docker Container          │
│                                              │
│  Browser ──► metacubexd    (:9090/ui)       │
│  Browser ──► Sub-Store UI  (:3001)          │
│                                              │
│         mihomo proxy engine (:7890)         │
│              ▲                               │
│              │ proxy-providers               │
│              ▼                               │
│         Sub-Store backend  (:3001)          │
│                                              │
└─────────────────────────────────────────────┘
```

## Quick Start

### 1. Clone the repo

```bash
git clone https://github.com/Tsutomu-miku/mihomo-docker.git
cd mihomo-docker
```

### 2. Start

```bash
docker compose up -d
```

That's it — one container, all services.

### 3. Configure subscriptions (Sub-Store UI)

Open **http://\<YOUR-IP\>:3001** in your browser:

1. **Add Subscriptions** — Click "+" to add your airport/provider subscription URLs
2. **Create a Collection** — Name it `all` (or any name), add your subscriptions to it
3. **Done!** — mihomo will automatically pull nodes from Sub-Store

### 4. Manage proxy (mihomo Dashboard)

Open **http://\<YOUR-IP\>:9090/ui** in your browser:

- **Switch mode** — Global / Rule / Direct
- **Select nodes** — Click to choose, with latency testing
- **Monitor traffic** — Real-time connections and bandwidth

## Ports

| Port | Service | Description |
|------|---------|-------------|
| 7890 | mihomo | HTTP/SOCKS5 mixed proxy |
| 9090 | mihomo | Dashboard & External Controller API |
| 3001 | Sub-Store | Subscription management UI |

## Configuration

### Sub-Store Backend Path

The `SUB_STORE_FRONTEND_BACKEND_PATH` env var acts as a simple auth token for the Sub-Store API. **Change it to your own random string** for security:

```yaml
environment:
  - SUB_STORE_FRONTEND_BACKEND_PATH=/your-random-string-here
```

### Custom Collection Name

If you named your Sub-Store collection something other than `all`, update `config/config.yaml`:

```yaml
proxy-providers:
  sub-store:
    url: "http://127.0.0.1:3001/download/collection/YOUR_NAME?target=ClashMeta"
```

### mihomo Secret

For production, uncomment and set a secret in `config/config.yaml`:

```yaml
secret: "your-secret-here"
```

Then enter this secret when connecting from the dashboard.

### Region-based Proxy Groups

The default config includes commented region groups (Hong Kong, Japan, USA, Streaming). Uncomment them in `config/config.yaml` if you need region-based routing:

```yaml
proxy-groups:
  - name: "HongKong"
    type: url-test
    use:
      - sub-store
    filter: "(?i)港|HK|Hong"
    ...
```

### Data Persistence

| Path | Description |
|------|-------------|
| `./config/` | mihomo config, UI, GEO databases |
| `./sub-store-data/` | Sub-Store subscriptions and collections |

Both directories are auto-created on first run.

## GEO Databases

Auto-updated every 24 hours. Sources:

| File | Description |
|------|-------------|
| geoip.dat | IP geolocation rules |
| geosite.dat | Domain-based rules |
| geoip.metadb | Compact IP database |
| country.mmdb | MaxMind country DB |
| GeoLite2-ASN.mmdb | ASN lookup DB |

## Docker Image

```bash
# Pull from GitHub Container Registry
docker pull ghcr.io/tsutomu-miku/mihomo-docker:latest
```

Supported platforms: `linux/amd64`, `linux/arm64`, `linux/arm/v7`

## Build from Source

```bash
docker build -t mihomo-docker .
```

## File Structure

```
mihomo-docker/
├── config/
│   └── config.yaml          # mihomo config (auto-created on first run)
├── sub-store-data/           # Sub-Store persistent data (auto-created)
├── docker/
│   └── entrypoint.sh         # Container startup script
├── docker-compose.yml         # One-container deployment
├── Dockerfile                 # Multi-stage all-in-one build
└── README.md
```

## Troubleshooting

### Sub-Store UI not accessible

- Check logs: `docker compose logs mihomo | grep sub-store`
- Ensure port 3001 is not blocked by firewall
- Restart: `docker compose restart mihomo`

### Nodes not showing in mihomo

1. Verify Sub-Store has subscriptions configured and collection created
2. Check the collection name matches `config.yaml`'s proxy-providers URL
3. Force refresh: `curl -X PUT http://127.0.0.1:9090/providers/proxies/sub-store`
4. Check logs: `docker compose logs mihomo`

### GEO database errors

The container auto-restores missing GEO files from built-in copies on startup. If issues persist:

```bash
rm -f config/geoip.dat config/geosite.dat config/geoip.metadb config/country.mmdb config/GeoLite2-ASN.mmdb
docker compose restart mihomo
```

### Dashboard UI not loading

```bash
rm -rf config/ui
docker compose restart mihomo
```

## Credits

- [mihomo (Clash Meta)](https://github.com/MetaCubeX/mihomo) — Proxy kernel
- [metacubexd](https://github.com/MetaCubeX/metacubexd) — Dashboard UI
- [Sub-Store](https://github.com/sub-store-org/Sub-Store) — Subscription management
- [meta-rules-dat](https://github.com/MetaCubeX/meta-rules-dat) — GEO databases

## License

[MIT](LICENSE)
