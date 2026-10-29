# Android VPS Essential DevOps Commands Cheatsheet

[**[🇻🇳 Đọc bản Tiếng Việt](../vi/useful-commands-cheatsheet.md)** • **[🏠 Home](../../README.md)**]

This document compiles the most essential and frequently used DevOps commands for operating an Android VPS (Termux + Ubuntu PRoot), covering **PM2** process management, **port inspection & HTTP pinging**, **PostgreSQL & Redis** operations, **Cloudflare Tunnel** troubleshooting, **Tailscale** network diagnostics, and hardware monitoring.

---

## 📑 Table of Contents

1. [PM2 Application Management](#1-pm2-application-management)
2. [Port Inspection & HTTP Health Checks (Ping Port)](#2-port-inspection--http-health-checks-ping-port)
3. [Database Management (Native PostgreSQL & Redis BullMQ)](#3-database-management-native-postgresql--redis-bullmq)
4. [Cloudflare Tunnel Inspection & Troubleshooting](#4-cloudflare-tunnel-inspection--troubleshooting)
5. [Tailscale Mesh VPN Inspection](#5-tailscale-mesh-vpn-inspection)
6. [Hardware & Thermal Monitoring (RAM, CPU, Battery)](#6-hardware--thermal-monitoring-ram-cpu-battery)
7. [Emergency Rescue & System Cleanup Commands](#7-emergency-rescue--system-cleanup-commands)

---

## 1. PM2 Application Management

Run these commands inside the **Ubuntu PRoot** environment (`deploy@localhost`):

### 1.1. Launching Applications
```bash
# Start a compiled Node.js application (Fork mode, 300MB memory ceiling)
pm2 start dist/main.js --name "intern-be" --max-memory-restart 300M

# Start via npm script (e.g. npm run start:prod)
pm2 start npm --name "intern-be" --max-memory-restart 300M -- run start:prod

# Start a Python FastAPI / Uvicorn service
pm2 start "uvicorn main:app --host 0.0.0.0 --port 8000" --name "python-api"
```

> [!TIP]
> **Why Fork Mode on Android VPS?**
> The PRoot user-space virtualization layer on ARM architecture does not fully support Node.js cluster IPC pipes. Running in standard `fork` mode ensures rock-solid stability, prevents crash-restart loops, and drastically reduces memory overhead.

### 1.2. Status & Monitoring
```bash
# List all running PM2 applications
pm2 list

# Launch interactive terminal CPU/RAM dashboard
pm2 monit

# Inspect detailed metrics and file paths of a specific application
pm2 show intern-be
```

### 1.3. Logs Management
```bash
# Stream live logs in real time (Press Ctrl + C to exit)
pm2 logs intern-be

# Display the last 100 log lines and exit immediately
pm2 logs intern-be --lines 100 --nostream

# Display only error logs
pm2 logs intern-be --err --lines 50 --nostream

# Truncate and clear all stored logs to free internal storage
pm2 flush
```

### 1.4. Reload, Stop, and Persist State
```bash
# Zero-downtime rolling reload with updated environment variables
pm2 reload intern-be --update-env

# Hard restart the process
pm2 restart intern-be

# Stop a process without removing it from management
pm2 stop intern-be

# Remove an application from PM2 management
pm2 delete intern-be

# MANDATORY: Dump current process state to disk for auto-recovery on reboot
pm2 save

# Resurrect previously saved process state
pm2 resurrect
```

---

## 2. Port Inspection & HTTP Health Checks (Ping Port)

Essential utilities to verify that backend services or databases are listening on expected network sockets.

### 2.1. Inspecting Listening Ports
```bash
# List all TCP ports currently listening on the server
ss -lnt

# Filter for a specific port (e.g. port 3001)
ss -lnt | grep :3001

# Inspect listening ports with process names and PIDs (requires sudo)
sudo ss -tulpn | grep :3001
```

### 2.2. Identifying Port Conflicts
```bash
# Find the exact process holding port 3001
lsof -i :3001

# Force kill any process occupying port 3001
sudo fuser -k 3001/tcp
```

### 2.3. Pinging Ports and Testing HTTP Responses
```bash
# Test TCP socket reachability using Netcat (Ping Port)
nc -zv 127.0.0.1 3001

# Inspect HTTP response headers (Expected: HTTP/1.1 200 OK)
curl -I http://localhost:3001

# Query JSON payload from an API healthcheck endpoint
curl http://localhost:3001/api/health
```

---

## 3. Database Management (Native PostgreSQL & Redis BullMQ)

### 3.1. PostgreSQL Server (Termux Host Layer - Port 5432)
Execute in Termux shell (`~$`, or via SSH port `8022`):

```bash
# Check if PostgreSQL cluster is accepting connections
pg_isready

# Start PostgreSQL daemon
pg_ctl -D $PREFIX/var/lib/postgresql -l $PREFIX/var/lib/postgresql/logfile start

# Restart PostgreSQL daemon
pg_ctl -D $PREFIX/var/lib/postgresql restart

# Stop PostgreSQL daemon
pg_ctl -D $PREFIX/var/lib/postgresql stop

# Launch interactive psql shell as superuser
psql -d postgres

# Connect directly to a specific project database
psql -U postgres -h localhost -d myapp_db
```

### 3.2. Redis Server (Ubuntu PRoot Layer - Port 6379)
Execute inside Ubuntu PRoot (`deploy@localhost`):

```bash
# Ping Redis server (Expected: PONG)
redis-cli ping

# Count keys/jobs inside Redis logical database index 1 (BullMQ)
redis-cli -n 1 dbsize

# List all keys stored in database 1
redis-cli -n 1 keys "*"

# Flush all keys in database 1 (Reset queue)
redis-cli -n 1 flushdb

# Restart Redis background service
sudo service redis-server restart
```

---

## 4. Cloudflare Tunnel Inspection & Troubleshooting

```bash
# Check if cloudflared tunnel daemon is running
pidof cloudflared

# Inspect active cloudflared process details
ps aux | grep cloudflared

# Stream live tunnel request logs
tail -f ~/logs/cloudflared.log

# Read last 50 lines of tunnel logs
tail -n 50 ~/logs/cloudflared.log

# Terminate duplicate or hung tunnel processes
pkill -9 cloudflared
```

---

## 5. Tailscale Mesh VPN Inspection

Execute from your PC or phone terminal:

```bash
# Ping phone server over Tailscale IP
tailscale ping 100.94.18.108

# Check connection status of all peers in Tailnet
tailscale status

# Display current local Tailscale IPv4 address
tailscale ip -4
```

---

## 6. Hardware & Thermal Monitoring (RAM, CPU, Battery)

### 6.1. RAM & CPU Inspection (Inside Ubuntu PRoot)
```bash
# Inspect total, used, and free RAM
free -h

# Top 10 memory-consuming processes
ps aux --sort=-%mem | head -n 10

# Top 10 CPU-consuming processes
ps aux --sort=-%cpu | head -n 10

# Interactive resource visualizer
top
# (Tip: Press 'Shift + H' inside top to toggle multi-threaded display)
```

### 6.2. Battery, Thermal & CPU Wake-lock (Inside Termux Host)
```bash
# Inspect battery percentage, charge status, and device temperature
termux-battery-status

# Acquire wake-lock to prevent CPU sleep when screen is off
termux-wake-lock

# Release CPU wake-lock
termux-wake-unlock
```

---

## 7. Emergency Rescue & System Cleanup Commands

### 7.1. Recovering from a Frozen PRoot Container
From your PC, connect to the **Termux Host Rescue Port (8022)**:
```bash
ssh -p 8022 100.94.18.108

# 1. Kill hung PRoot processes
pkill -9 proot

# 2. Re-enter Ubuntu cleanly
proot-distro login ubuntu --user deploy
```

### 7.2. Disk Space Cleanup
```bash
# Clean APT package cache
sudo apt clean && sudo apt autoremove -y

# Clean NPM package cache
npm cache clean --force

# Remove lingering log files
rm -f ~/nohup.out ~/logs/*.log
pm2 flush
```
