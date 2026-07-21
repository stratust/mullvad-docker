#!/bin/bash
set -e

# Clean up stale RPC socket/dir from previous runs
if [ -d /var/run/mullvad-vpn ]; then
    rm -rf /var/run/mullvad-vpn
fi
if [ -e /var/run/mullvad-vpn ]; then
    rm -f /var/run/mullvad-vpn
fi
mkdir -p /var/run

# Start mullvad-daemon in background
echo "[entrypoint] Starting mullvad-daemon..."
mullvad-daemon &
DAEMON_PID=$!

# Wait for daemon RPC socket to be available
echo "[entrypoint] Waiting for daemon to be ready..."
for i in $(seq 1 30); do
    if mullvad status >/dev/null 2>&1; then
        echo "[entrypoint] Daemon is ready."
        break
    fi
    sleep 1
done

# Login if account is set
if [ -n "$MULLVAD_ACCOUNT" ]; then
    echo "[entrypoint] Logging in with account..."
    mullvad account login "$MULLVAD_ACCOUNT" || true
fi

# Set location if specified
# Format: country-code or country-code city-name
# Try variations: "br sao" → "br saopaulo" → just "br"
if [ -n "$MULLVAD_LOCATION" ]; then
    echo "[entrypoint] Setting location: $MULLVAD_LOCATION"
    mullvad relay set location "$MULLVAD_LOCATION" 2>/dev/null \
        || mullvad relay set location "$(echo "$MULLVAD_LOCATION" | awk '{print $1}')" 2>/dev/null \
        || echo "[entrypoint] Warning: could not set location, using auto-selection"
fi

# Configure udp-over-tcp (anti-censorship / bridge mode)
if [ -n "$MULLVAD_ANTICENSORSHIP_MODE" ]; then
    echo "[entrypoint] Setting anti-censorship mode: $MULLVAD_ANTICENSORSHIP_MODE"
    mullvad bridge set state on 2>/dev/null || true
    if [ "$MULLVAD_ANTICENSORSHIP_MODE" = "udp2tcp" ]; then
        mullvad bridge set tunnel-protocol udp-over-tcp 2>/dev/null || true
        if [ -n "$MULLVAD_WIREGUARD_PORT" ]; then
            mullvad bridge set udp-over-tcp-port --port "$MULLVAD_WIREGUARD_PORT" 2>/dev/null || true
        fi
    fi
fi

# Set LAN access if configured
if [ "$MULLVAD_ALLOW_LAN" = "true" ]; then
    mullvad settings set lan-connections allow 2>/dev/null || true
fi

# Always require VPN to prevent leaks
if [ "$MULLVAD_ALWAYS_REQUIRE_VPN" = "true" ]; then
    mullvad settings set lockdown-mode on 2>/dev/null || true
fi

# Connect
echo "[entrypoint] Connecting..."
mullvad connect

# Show initial status
sleep 5
mullvad status

# Keep container alive — wait for daemon process
echo "[entrypoint] Mullvad VPN is running. Forwarding to daemon process."
wait $DAEMON_PID
