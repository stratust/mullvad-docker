FROM debian:bookworm-slim

ARG MULLVAD_VERSION=2026.3
ARG DEB_URL=https://github.com/mullvad/mullvadvpn-app/releases/download/${MULLVAD_VERSION}/MullvadVPN-${MULLVAD_VERSION}_amd64.deb

# Install the Mullvad .deb (brings mullvad-daemon + CLI + wireguard-go)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates curl iproute2 iptables iputils-ping dnsutils \
        libnl-3-200 libnl-genl-3-200 procps && \
    curl -fsSL -o /tmp/mullvad.deb "${DEB_URL}" && \
    apt-get install -y --no-install-recommends /tmp/mullvad.deb && \
    rm /tmp/mullvad.deb && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Mullvad daemon needs /dev/net/tun and NET_ADMIN
# The daemon creates its own wg interface in userspace (wireguard-go)
# but still needs cap NET_ADMIN for routing/firewall rules
ENV MULLVAD_ACCOUNT="" \
    MULLVAD_LOCATION="" \
    MULLVAD_ANTICENSORSHIP_MODE="udp2tcp" \
    MULLVAD_WIREGUARD_PORT="443" \
    MULLVAD_ALWAYS_REQUIRE_VPN="true" \
    MULLVAD_ALLOW_LAN="true"

HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD mullvad status 2>&1 | grep -q "Connected" || exit 1

ENTRYPOINT ["/entrypoint.sh"]
