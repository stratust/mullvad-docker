# Mullvad VPN Docker (with udp-over-tcp)

Docker image with the official Mullvad VPN daemon, built specifically to enable **WireGuard over TCP** (udp2tcp obfuscation) on networks that do DPI/throttle UDP traffic.

Built from the official `.deb` published by Mullvad — no custom WireGuard implementation.

## Why

Gluetun uses WireGuard (UDP only). When an ISP does DPI and blocks/throttles encrypted UDP, you need TCP. The Mullvad daemon has built-in `udp2tcp` obfuscation that wraps WireGuard UDP inside TCP on ports 80, 443, or 5001 — this image makes that available as a Docker container.

## Usage

```bash
docker run -d \
  --name mullvad \
  --cap-add NET_ADMIN \
  --device /dev/net/tun:/dev/net/tun \
  -e MULLVAD_ACCOUNT=1234567890123456 \
  -e MULLVAD_LOCATION="br sao" \
  -e MULLVAD_ANTICENSORSHIP_MODE=udp2tcp \
  -e MULLVAD_WIREGUARD_PORT=443 \
  -p 8888:8888/tcp \
  ghcr.io/stratust/mullvad-vpn:latest
```

Other containers can route through the VPN using `network_mode: service:mullvad`.

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `MULLVAD_ACCOUNT` | _(empty)_ | Your Mullvad account number |
| `MULLVAD_LOCATION` | _(empty)_ | Location, e.g. `br sao`, `us nyc`, `se sto` |
| `MULLVAD_ANTICENSORSHIP_MODE` | `udp2tcp` | `udp2tcp`, `shadowsocks`, `quic`, `lwo`, or `auto` |
| `MULLVAD_WIREGUARD_PORT` | `443` | Port for obfuscation (80, 443, or 5001) |
| `MULLVAD_ALWAYS_REQUIRE_VPN` | `true` | Enable lockdown mode (kill switch) |
| `MULLVAD_ALLOW_LAN` | `true` | Allow LAN connections |

## Use as VPN gateway for other containers

```yaml
services:
  mullvad:
    image: ghcr.io/stratust/mullvad-vpn:latest
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    environment:
      - MULLVAD_ACCOUNT=1234567890123456
      - MULLVAD_LOCATION=br sao
      - MULLVAD_ANTICENSORSHIP_MODE=udp2tcp
      - MULLVAD_WIREGUARD_PORT=443
    ports:
      - 8888:8888/tcp   # HTTP proxy (if enabled)

  qbittorrent:
    image: ghcr.io/hotio/qbittorrent
    network_mode: service:mullvad
    depends_on:
      - mullvad
```
