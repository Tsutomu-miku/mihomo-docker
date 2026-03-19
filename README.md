# mihomo-docker

A Docker all-in-one proxy solution powered by [mihomo](https://github.com/MetaCubeX/mihomo) (Clash.Meta) kernel with [metacubexd](https://github.com/MetaCubeX/metacubexd) web dashboard.

## Features

- **mihomo Alpha** kernel - latest proxy engine with full protocol support
- **metacubexd** web dashboard - modern, responsive management UI
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

## License

MIT License - see [LICENSE](LICENSE) for details.

## Credits

- [MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo) - Proxy kernel
- [MetaCubeX/metacubexd](https://github.com/MetaCubeX/metacubexd) - Web dashboard
- [MetaCubeX/meta-rules-dat](https://github.com/MetaCubeX/meta-rules-dat) - GEO databases
