#!/bin/bash
# ==============================================================================
# Script: start-services.sh
# Location: ~/scripts/start-services.sh inside Ubuntu PRoot
# Usage: ./start-services.sh [start|stop|restart|status]
# ==============================================================================

# Ensure full PATH including /usr/local/bin for node & pm2
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"
export HOME="/home/deploy"
export PM2_HOME="$HOME/.pm2"

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

    # 3. Clean stale PM2 socket & restore applications
    rm -f "$PM2_HOME/pm2.sock" "$PM2_HOME/pm2.pid"
    if command -v pm2 > /dev/null 2>&1; then
        echo "[PM2] Resurrecting saved applications..."
        pm2 resurrect > /dev/null 2>&1 || true
        pm2 restart all > /dev/null 2>&1 || true

        # Fallback check for intern-be
        if [ -d "$HOME/projects/project-intern-be" ]; then
            cd "$HOME/projects/project-intern-be"
            if ! pm2 list | grep -q "intern-be.*online"; then
                echo "[PM2] intern-be is not online. Forcing start..."
                pm2 restart intern-be > /dev/null 2>&1 || pm2 start dist/main.js --name "intern-be" --max-memory-restart 300M
            fi
        fi
        echo "[PM2] Applications status confirmed."
    else
        echo "[PM2] ERROR: pm2 binary not found in PATH: $PATH"
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
