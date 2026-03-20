# mihomo-docker

A Docker all-in-one proxy solution powered by [mihomo](https://github.com/MetaCubeX/mihomo) (Clash.Meta) kernel with [metacubexd](https://github.com/MetaCubeX/metacubexd) web dashboard.

## Features

- **mihomo Alpha** kernel - latest proxy engine with full protocol support
- **metacubexd** web dashboard - modern, responsive management UI
- **Subscription support** - native proxy-providers for airport subscriptions, optional Sub-Store integration
- **Pre-bundled GEO databases** - geoip.dat, geosite.dat, geoip.metadb, country.mmdb, ASN.mmdb
- **Auto-recovery** - UI and GEO files automatically restored when config volume overwrites them
- **Multi-architecture** - supports linux/amd64, linux/arm64, linux/arm/v7
- **Docker-optimized** - proper health checks, log rotation, timezone support

## Quick Start

### 1. Create project directory

```bash
mkdir mihomo && cd mihomo
mkdir -p config
```

### 2. Create docker-compose.yml

```yaml
services:
  mihomo:
    container_name: mihomo
    image: ghcr.io/tsutomu-miku/mihomo-docker:latest
    restart: unless-stopped
    network_mode: host
    cap_add:
      - NET_ADMIN
      - NET_RAW
    environment:
      - TZ=Asia/Shanghai
    volumes:
      - ./config:/root/.config/mihomo
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
```

### 3. Start the container

```bash
docker compose up -d
```

On first start, the container will:
1. Copy default `config.yaml` to `./config/` (if not present)
2. Restore web UI files to `./config/ui/`
3. Restore GEO database files (geoip.dat, geosite.dat, etc.)
4. Start mihomo proxy engine

### 4. Access the dashboard

Open your browser and visit:

```
http://YOUR_HOST_IP:9090/ui
```

## Subscription Usage

metacubexd frontend does not have built-in subscription management. This project provides subscription support through mihomo's native **proxy-providers** feature and optional **Sub-Store** integration.

### Method 1: Edit config.yaml (Simplest)

The default `config.yaml` includes a commented-out `proxy-providers` section. Simply uncomment and fill in your subscription URL:

```yaml
proxy-providers:
  airport1:
    type: http
    url: "https://your-provider.com/api/v1/client/subscribe?token=YOUR_TOKEN"
    path: ./proxy_providers/airport1.yaml
    interval: 3600
    health-check:
      enable: true
      url: https://www.gstatic.com/generate_204
      interval: 300
      timeout: 5000
      lazy: true

proxy-groups:
  - name: "Proxy"
    type: select
    use:
      - airport1
    proxies:
      - DIRECT
```

Then restart the container:

```bash
docker compose restart
```

### Method 2: Multiple Subscriptions with Region Groups

For users with multiple airport subscriptions who want region-based auto-select:

```yaml
proxy-providers:
  airport1:
    type: http
    url: "https://airport1.example.com/subscribe?token=TOKEN1"
    path: ./proxy_providers/airport1.yaml
    interval: 3600
    health-check:
      enable: true
      url: https://www.gstatic.com/generate_204
      interval: 300
  airport2:
    type: http
    url: "https://airport2.example.com/subscribe?token=TOKEN2"
    path: ./proxy_providers/airport2.yaml
    interval: 3600
    health-check:
      enable: true
      url: https://www.gstatic.com/generate_204
      interval: 300

proxy-groups:
  - name: "Proxy"
    type: select
    proxies:
      - HongKong
      - Japan
      - USA
      - DIRECT

  - name: "HongKong"
    type: url-test
    use:
      - airport1
      - airport2
    filter: "(?i)HK|Hong|港"
    url: https://www.gstatic.com/generate_204
    interval: 300

  - name: "Japan"
    type: url-test
    use:
      - airport1
      - airport2
    filter: "(?i)JP|Japan|日"
    url: https://www.gstatic.com/generate_204
    interval: 300

  - name: "USA"
    type: url-test
    use:
      - airport1
      - airport2
    filter: "(?i)US|United|美"
    url: https://www.gstatic.com/generate_204
    interval: 300
```

### Method 3: Sub-Store (Advanced Web UI)

For users who prefer a graphical subscription manager with merge/filter capabilities, use the included `docker-compose.substore.yml`:

```bash
docker compose -f docker-compose.substore.yml up -d
```

This starts both mihomo and [Sub-Store](https://github.com/sub-store-org/Sub-Store):

| Service | Port | URL |
|---------|------|-----|
| mihomo Dashboard | 9090 | `http://HOST:9090/ui` |
| Sub-Store Frontend | 3001 | `http://HOST:3001` |

Use Sub-Store to:
- Add and manage multiple subscription sources
- Merge subscriptions into a single provider
- Filter/rename/sort nodes
- Export as Clash YAML for use in proxy-providers

### Supported Subscription Formats

| Format | Example | Notes |
|--------|---------|-------|
| Clash YAML | Most airports provide this | Directly compatible |
| Base64 encoded | V2Ray subscription links | mihomo auto-decodes |
| URI list | `ss://...`, `vmess://...` per line | mihomo auto-parses |
| SIP008 | Shadowsocks standard | Supported natively |

### Manual Refresh

Trigger an immediate subscription update via the API:

```bash
# Update all proxy-providers
curl -X PUT http://127.0.0.1:9090/providers/proxies/airport1

# Or restart container
docker compose restart
```

You can also refresh subscriptions from the metacubexd dashboard under the **Providers** tab.

### proxy-providers Reference

| Parameter | Type | Description |
|-----------|------|-------------|
| `type` | `http` / `file` | `http` fetches from URL; `file` loads local YAML |
| `url` | string | Subscription URL (for `type: http`) |
| `path` | string | Local cache path (relative to config dir) |
| `interval` | int | Auto-update interval in seconds (default: 3600) |
| `health-check.enable` | bool | Enable periodic node health checks |
| `health-check.url` | string | URL for latency testing |
| `health-check.interval` | int | Health check interval in seconds |
| `filter` | string | Regex to filter nodes by name |

## Configuration

### Config File

The main configuration file is `./config/config.yaml`. Edit it to add your proxy servers:

```yaml
proxies:
  - name: "My Proxy"
    type: ss
    server: your-server.com
    port: 8388
    cipher: aes-256-gcm
    password: "your-password"

proxy-groups:
  - name: "Proxy"
    type: select
    proxies:
      - "My Proxy"
      - DIRECT

rules:
  - GEOSITE,private,DIRECT
  - GEOSITE,cn,DIRECT
  - GEOIP,CN,DIRECT,no-resolve
  - MATCH,Proxy
```

After editing, restart the container:

```bash
docker compose restart
```

### Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 7890 | HTTP/SOCKS5 | Mixed proxy port |
| 9090 | HTTP | External controller API + Web UI |

### GEO Database Files

The image pre-bundles all necessary GEO databases from [MetaCubeX/meta-rules-dat](https://github.com/MetaCubeX/meta-rules-dat):

| File | Format | Purpose |
|------|--------|---------|
| `geoip.dat` | v2ray DAT | GeoIP rules (used with `geodata-mode: true`) |
| `geosite.dat` | v2ray DAT | GeoSite domain rules |
| `geoip.metadb` | MetaDB | mihomo-specific GeoIP metadata |
| `country.mmdb` | MaxMind MMDB | GeoIP database (used with `geodata-mode: false`) |
| `GeoLite2-ASN.mmdb` | MaxMind MMDB | ASN (Autonomous System Number) database |

**Auto-recovery**: When you mount `./config:/root/.config/mihomo`, the volume mount may overwrite the built-in GEO files. The entrypoint script automatically detects missing GEO files and restores them from the built-in backup at `/opt/mihomo/geodata/`.

### GEO Auto-Update

The default config enables automatic GEO database updates every 24 hours with CDN mirrors:

```yaml
geo-auto-update: true
geo-update-interval: 24
geox-url:
  geoip: "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip.dat"
  geosite: "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geosite.dat"
  mmdb: "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/country.mmdb"
  asn: "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/GeoLite2-ASN.mmdb"
```

### DNS Configuration

The default DNS config uses a layered architecture to avoid the "chicken-and-egg" problem (proxy needs DNS, DNS needs proxy):

1. **default-nameserver** (plain IPs) - bootstraps all other DNS
2. **proxy-server-nameserver** - resolves proxy node hostnames via DIRECT
3. **nameserver** - primary DNS for all other domains
4. **fallback** - anti-pollution DNS (overseas servers)

### SAFE_PATHS Compliance

mihomo Alpha enforces a security policy where config paths must be within the working directory. This image:

- Uses relative path `external-ui: ui` (resolves to `/root/.config/mihomo/ui`)
- Stores all GEO files in `/root/.config/mihomo/` (the working directory)
- No `SAFE_PATHS` environment variable needed in normal operation

## Docker Image

Pull from GitHub Container Registry:

```bash
# Latest
docker pull ghcr.io/tsutomu-miku/mihomo-docker:latest

# Specific version
docker pull ghcr.io/tsutomu-miku/mihomo-docker:v1.0.0
```

### Supported Architectures

| Architecture | Docker Platform | Typical Devices |
|-------------|-----------------|------------------|
| x86_64 | linux/amd64 | PCs, servers, most VPS |
| ARM64 | linux/arm64 | Raspberry Pi 4/5, Apple M-series |
| ARMv7 | linux/arm/v7 | Raspberry Pi 2/3, older ARM boards |

## Build from Source

```bash
git clone https://github.com/Tsutomu-miku/mihomo-docker.git
cd mihomo-docker
docker build -t mihomo-docker .
```

## Troubleshooting

### GEO database errors on startup

If you see errors like `can't load GEO data`, check:

1. GEO files should exist in `./config/` directory
2. If missing, restart the container - entrypoint auto-recovers them
3. Check network access for auto-update: `geox-url` uses CDN mirrors

### UI not accessible

1. Verify the container is running: `docker compose ps`
2. Check logs: `docker compose logs -f`
3. Ensure port 9090 is accessible
4. Access URL: `http://HOST_IP:9090/ui`
5. UI files should be in `./config/ui/` - restart container to restore

### SAFE_PATHS error

If you see `path is not subpath of home directory or SAFE_PATHS`, ensure:
- `external-ui` in config uses a relative path (e.g., `ui`) not absolute (e.g., `/ui`)
- All referenced paths are within `/root/.config/mihomo/`

### Subscription not updating

1. Verify subscription URL is accessible from the container
2. Check logs: `docker compose logs -f | grep provider`
3. Manual refresh: `curl -X PUT http://127.0.0.1:9090/providers/proxies/PROVIDER_NAME`
4. Ensure `proxy_providers/` directory exists in `./config/`

## License

MIT License - see [LICENSE](LICENSE) for details.

## Credits

- [MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo) - Proxy kernel
- [MetaCubeX/metacubexd](https://github.com/MetaCubeX/metacubexd) - Web dashboard
- [MetaCubeX/meta-rules-dat](https://github.com/MetaCubeX/meta-rules-dat) - GEO databases
- [sub-store-org/Sub-Store](https://github.com/sub-store-org/Sub-Store) - Subscription manager (optional)
