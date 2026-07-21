#!/bin/bash
set -e

# Start mullvad-daemon in background
echo "[entrypoint] Starting mullvad-daemon..."
mullvad-daemon --launch-subprocesses &
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
if [ -n "$MULLVAD_LOCATION" ]; then
    echo "[entrypoint] Setting location: $MULLVAD_LOCATION"
    mullvad relay set location "$MULLVAD_LOCATION"
fi

# Configure anti-censorship (udp-over-tcp by default)
if [ -n "$MULLVAD_ANTICENSORSHIP_MODE" ]; then
    echo "[entrypoint] Setting anti-censorship mode: $MULLVAD_ANTICENSORSHIP_MODE"
    
    if [ "$MULLVAD_ANTICENSORSHIP_MODE" = "auto" ]; then
        mullvad anti-censorship set mode auto 2>/dev/null || true
    else
        # Set the wireguard port for the obfuscation
        if [ -n "$MULLVAD_WIREGUARD_PORT" ]; then
            mullvad anti-censorship set wireguard-port --port "$MULLVAD_WIREGUARD_PORT" 2>/dev/null || true
        fi
        mullvad anti-censorship set mode "$MULLVAD_ANTICENSORSHIP_MODE" 2>/dev/null || true
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
sleep 3
mullvad status

# Keep container alive — wait for daemon process
echo "[entrypoint] Mullvad VPN is running. Forwarding to daemon process."
wait $DAEMON_PID
