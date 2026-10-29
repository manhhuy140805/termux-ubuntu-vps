#!/bin/bash
# ==============================================================================
# Script: start-services.sh
# Location: ~/scripts/start-services.sh inside Ubuntu PRoot
# Usage: ./start-services.sh [start|stop|restart|status]
# ==============================================================================

LOG_DIR="$HOME/logs"
mkdir -p "$LOG_DIR"

start_services() {
    echo "=== Starting Services [$(date '+%Y-%m-%d %H:%M:%S')] ==="

    # 1. Start OpenSSH Server on Port 2222
    sudo mkdir -p /run/sshd
    sudo chmod 0755 /run/sshd
    if ! ss -lnt | grep -q ":2222 "; then
        sudo service ssh start
        echo "[SSH] OpenSSH server started on port 2222."
    else
        echo "[SSH] SSH server is already running."
    fi

    # 2. Start Redis Server on Port 6379 (for BullMQ)
    if ! ss -lnt | grep -q ":6379 "; then
        sudo service redis-server start
        echo "[Redis] redis-server started on port 6379."
    else
        echo "[Redis] Redis server is already running."
    fi

    # 3. Restore PM2 Applications (Node.js / Python Backend)
    if command -v pm2 > /dev/null 2>&1; then
        echo "[PM2] Resurrecting saved applications..."
        pm2 resurrect > /dev/null 2>&1 || true
        pm2 restart all > /dev/null 2>&1 || true
        echo "[PM2] Applications restored and online."
    fi

    # 4. Start Cloudflare Tunnel
    if ! pidof cloudflared > /dev/null 2>&1; then
        TOKEN_FILE="$HOME/.cloudflared/token"
        
        if [ -f "$TOKEN_FILE" ]; then
            TOKEN=$(cat "$TOKEN_FILE" | tr -d '\n\r')
            echo "[Cloudflare] Starting tunnel with token from $TOKEN_FILE..."
            nohup cloudflared tunnel run --token "$TOKEN" > "$LOG_DIR/cloudflared.log" 2>&1 < /dev/null &
            echo "[Cloudflare] Started with PID $!"
        elif [ -f "$HOME/start-tunnel.sh" ]; then
            bash "$HOME/start-tunnel.sh" > /dev/null 2>&1 &
            echo "[Cloudflare] Executed start-tunnel.sh."
        else
            echo "[Cloudflare] WARN: Token file or start-tunnel.sh not found."
        fi
    else
        echo "[Cloudflare] cloudflared is already running."
    fi
}

stop_services() {
    echo "=== Stopping Services ==="
    sudo service ssh stop > /dev/null 2>&1 && echo "[SSH] Stopped."
    sudo service redis-server stop > /dev/null 2>&1 && echo "[Redis] Stopped."
    killall cloudflared 2>/dev/null || pkill -9 cloudflared 2>/dev/null && echo "[Cloudflare] Stopped."
    pm2 stop all > /dev/null 2>&1 && echo "[PM2] Stopped all apps."
}

case "$1" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        stop_services
        sleep 2
        start_services
        ;;
    status)
        echo "=== VPS Service Health Check ==="
        echo "SSH (:2222):  $(ss -lnt | grep -q ':2222 ' && echo 'ONLINE' || echo 'OFFLINE')"
        echo "Redis (:6379): $(ss -lnt | grep -q ':6379 ' && echo 'ONLINE' || echo 'OFFLINE')"
        echo "Tunnel:        $(pidof cloudflared > /dev/null && echo 'ONLINE' || echo 'OFFLINE')"
        pm2 list
        ;;
    *)
        start_services
        ;;
esac
