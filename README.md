# 🚀 mihomo-docker

**Docker-based all-in-one proxy solution** packaging the [mihomo](https://github.com/MetaCubeX/mihomo) (Clash.Meta) proxy kernel with the beautiful [metacubexd](https://github.com/MetaCubeX/metacubexd) Web UI into a single, ready-to-run Docker image.

---

## ✨ Features

- **mihomo Kernel** — High-performance proxy core built from the latest Alpha branch with full gVisor support
- **metacubexd Web UI** — Modern, responsive dashboard for managing proxies, rules, and connections
- **Multi-Platform** — Supports `linux/amd64`, `linux/arm64`, and `linux/arm/v7` (Raspberry Pi)
- **All-in-One** — Single container, no sidecar needed
- **Sensible Defaults** — Ships with a working default configuration
- **Docker Compose Ready** — One command to start everything
- **Auto Timezone** — Configurable via `TZ` environment variable

---

## 📦 Quick Start

### Option 1: Docker Run

```bash
# Create a config directory and start the container
mkdir -p ./config

docker run -d \
  --name mihomo \
  --restart unless-stopped \
  --cap-add NET_ADMIN \
  -p 7890:7890 \
  -p 7891:7891 \
  -p 9090:9090 \
  -v $(pwd)/config:/root/.config/mihomo \
  -e TZ=Asia/Shanghai \
  ghcr.io/tsutomu-miku/mihomo-docker:latest
```

### Option 2: Docker Compose (Recommended)

```bash
# Clone the repository
git clone https://github.com/Tsutomu-miku/mihomo-docker.git
cd mihomo-docker

# Start the service
docker compose up -d

# View logs
docker compose logs -f mihomo
```

### Access the Web UI

Once the container is running, open your browser and navigate to:

```
http://<your-host-ip>:9090/ui
```

> If you set a `secret` in `config.yaml`, you will need to enter it on the Web UI login page.

---

## ⚙️ Configuration

### Config File

The main configuration file is located at:

```
./config/config.yaml
```

On first run, if no `config.yaml` exists, the container copies a default configuration automatically. Edit this file to add your proxy servers, subscription URLs, and routing rules.

<!-- 首次运行时，如果没有 config.yaml，容器会自动复制一份默认配置。
     编辑该文件可添加代理服务器、订阅链接和分流规则。 -->

### Applying Changes

After editing `config.yaml`, you can reload the configuration without restarting the container:

```bash
# Restart the container (simple approach)
docker restart mihomo

# Or use the API to hot-reload (if supported by your config)
curl -X PUT http://127.0.0.1:9090/configs -H "Content-Type: application/json" \
  -d '{"path": "/root/.config/mihomo/config.yaml"}'
```

### Using Subscription Providers

Uncomment the `proxy-providers` section in `config.yaml` and add your subscription URL:

```yaml
proxy-providers:
  my-provider:
    type: http
    url: "https://your-subscription-url"
    interval: 3600
    path: ./providers/my-provider.yaml
    health-check:
      enable: true
      interval: 600
      url: https://www.gstatic.com/generate_204
```

---

## 📋 Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | `UTC` | Timezone (e.g., `Asia/Shanghai`, `America/New_York`) |

---

## 🔌 Ports

| Port | Protocol | Description |
|------|----------|-------------|
| `7890` | TCP | HTTP / Mixed proxy (HTTP + SOCKS5) |
| `7891` | TCP | Dedicated SOCKS5 proxy |
| `9090` | TCP | RESTful API & metacubexd Web UI |
| `53` | TCP/UDP | DNS server (disabled in port mapping by default) |

---

## 📂 Volumes

| Container Path | Description |
|----------------|-------------|
| `/root/.config/mihomo` | Configuration directory — mount your local `./config` here |
| `/ui` | Web UI files (built into the image, no need to mount) |

The configuration directory stores:
- `config.yaml` — Main configuration file
- `cache.db` — Persistent cache (fake-ip mappings, selected proxies)
- `providers/` — Downloaded proxy provider files

---

## 🌐 Using as a Network Proxy for Other Containers

### Method 1: Bridge Mode with Explicit Proxy

Configure other containers to use mihomo as their HTTP/SOCKS5 proxy:

```yaml
# docker-compose.yml
services:
  mihomo:
    # ... (mihomo service config)

  my-app:
    image: my-app:latest
    environment:
      - HTTP_PROXY=http://mihomo:7890
      - HTTPS_PROXY=http://mihomo:7890
      - ALL_PROXY=socks5://mihomo:7891
    depends_on:
      - mihomo
```

### Method 2: Host Network Mode

For transparent proxy setups, switch to host network mode:

```yaml
services:
  mihomo:
    # ... other settings ...
    network_mode: host
    # Remove the 'ports' section when using host mode
```

<!-- 使用 host 网络模式时，不需要映射端口，容器直接使用宿主机网络。
     适合透明代理和 TUN 模式。 -->

### Method 3: Shared Network Stack

Route another container's traffic through mihomo:

```yaml
services:
  mihomo:
    # ... (mihomo service config)

  my-app:
    image: my-app:latest
    network_mode: "service:mihomo"
    depends_on:
      - mihomo
```

---

## 🔄 Updating

### Update the Image

```bash
# Pull the latest image
docker compose pull

# Recreate the container with the new image
docker compose up -d

# Clean up old images
docker image prune -f
```

### Build Locally with Specific Versions

```bash
docker build \
  --build-arg MIHOMO_VERSION=Alpha \
  --build-arg METACUBEXD_VERSION=v1.243.0 \
  -t mihomo-docker:custom .
```

---

## 🏗️ Building from Source

```bash
# Clone the repository
git clone https://github.com/Tsutomu-miku/mihomo-docker.git
cd mihomo-docker

# Build for current platform
docker build -t mihomo-docker:local .

# Build for multiple platforms
docker buildx build \
  --platform linux/amd64,linux/arm64,linux/arm/v7 \
  -t mihomo-docker:local .
```

---

## 🛡️ TUN Mode

To enable TUN mode for transparent proxying, you need to:

1. Enable TUN in `config.yaml`:

```yaml
tun:
  enable: true
  stack: system
  dns-hijack:
    - any:53
  auto-route: true
  auto-detect-interface: true
```

2. Run the container with additional privileges:

```yaml
services:
  mihomo:
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv6.conf.all.forwarding=1
```

---

## 🙏 Credits

This project packages the following open-source projects:

- **[mihomo](https://github.com/MetaCubeX/mihomo)** — The most feature-rich Clash kernel (formerly Clash.Meta)
- **[metacubexd](https://github.com/MetaCubeX/metacubexd)** — A modern Web UI dashboard for Clash-based kernels
- **[Docker](https://www.docker.com/)** — Container platform

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).

Copyright (c) 2025 Tsutomu-miku

> **Note:** The mihomo kernel and metacubexd UI have their own respective licenses.
> Please refer to their repositories for license details.
