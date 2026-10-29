#!/data/data/com.termux/files/usr/bin/bash
# ==============================================================================
# Script: boot-termux.sh
# Location: ~/.termux/boot/start-server.sh on Android (Termux)
# Requirement: Termux:Boot app installed from F-Droid
# ==============================================================================

LOG_FILE="$HOME/boot.log"
echo "==================================================" >> "$LOG_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Termux Boot started." >> "$LOG_FILE"

# 1. Acquire Android Wake Lock to prevent CPU sleep
termux-wake-lock
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Wake lock acquired." >> "$LOG_FILE"

# 2. Wait 10s for network and Tailscale to stabilize
sleep 10

# 3. Start Termux Host OpenSSH (Port 8022 - Rescue Shell)
if ! pgrep -x sshd > /dev/null 2>&1; then
    sshd
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Termux SSH started on port 8022." >> "$LOG_FILE"
fi

# 4. Start Native PostgreSQL (Port 5432)
if ! pg_isready -q > /dev/null 2>&1; then
    pg_ctl -D $PREFIX/var/lib/postgresql -l $PREFIX/var/lib/postgresql/logfile start
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] PostgreSQL Native started on port 5432." >> "$LOG_FILE"
fi

# 5. Launch Ubuntu PRoot Services as user 'deploy' (or your custom user)
USERNAME="deploy"
UBUNTU_SCRIPT="/home/$USERNAME/scripts/start-services.sh"

if [ -f "$PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu$UBUNTU_SCRIPT" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Launching Ubuntu services..." >> "$LOG_FILE"
    proot-distro login ubuntu -- su - "$USERNAME" -c "$UBUNTU_SCRIPT start" >> "$LOG_FILE" 2>&1
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Ubuntu services executed." >> "$LOG_FILE"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARN: Startup script not found in $UBUNTU_SCRIPT" >> "$LOG_FILE"
fi
