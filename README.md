# Turn Your Android Phone into a Linux Web Server (VPS)

[![Platform: Android](https://img.shields.io/badge/Platform-Android%208.0%2B-green.svg)](https://www.android.com/)
[![Environment: Termux + PRoot](https://img.shields.io/badge/Environment-Termux%20%7C%20PRoot%20Ubuntu-orange.svg)](https://termux.dev/)
[![Mesh VPN: Tailscale](https://img.shields.io/badge/VPN-Tailscale-blue.svg?logo=tailscale)](https://tailscale.com/)
[![Tunnel: Cloudflare](https://img.shields.io/badge/Tunnel-Cloudflare%20Zero%20Trust-F38020.svg?logo=cloudflare)](https://www.cloudflare.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Bilingual: EN / VI](https://img.shields.io/badge/Language-English%20%7C%20Ti%E1%BA%BFng%20Vi%E1%BB%87t-brightgreen.svg)](#)

[**[🇻🇳 Bản Tiếng Việt](README.vi.md)** • **[📁 English Guides (`docs/en/`)](docs/en/)** • **[📁 Thư Mục Hướng Dẫn Tiếng Việt (`docs/vi/`)](docs/vi/)**]

---

Transform an old or spare Android smartphone into a lightweight, 24/7 personal web server and development sandbox. By combining **Termux**, **Ubuntu (PRoot)**, **Tailscale**, and **Cloudflare Tunnel (Zero Trust)**, you can:
- Host public websites with your own custom domain, backed by free automatic SSL/HTTPS from Cloudflare.
- Securely manage the server from your PC/laptop via SSH from anywhere in the world.
- **Zero Port Forwarding**: Operates seamlessly behind CGNAT, 4G/5G mobile carriers, and public Wi-Fi.
- **Zero Root Required**: Runs safely in user space virtualization.
- Automatically restore services after phone reboots.

> [!TIP]
> **Optimized Workflow**: We install the SSH service and Tailscale right at the start. Once connected from your PC, you can put the phone away and do all configurations, file editing, and deployments directly from your computer terminal!

---

## 📑 Table of Contents

- [1. Architecture Overview](#1-architecture-overview)
- [2. Prerequisites & Hardware Planning](#2-prerequisites--hardware-planning)
- [3. Sample Configuration Reference (Mock Values)](#3-sample-configuration-reference-mock-values)
- [📱 Phase 1: Bootstrap on Phone](#-phase-1-bootstrap-on-phone)
  - [Step 1: Install Termux & Ubuntu PRoot](#step-1-install-termux--ubuntu-proot)
  - [Step 2: Create Non-Root User & Enable SSH](#step-2-create-non-root-user--enable-ssh)
- [🌐 Phase 2: Setup Tailscale for Secure Remote Access](#-phase-2-setup-tailscale-for-secure-remote-access)
  - [Step 3.1: Install & Connect Tailscale on Android](#step-31-install--connect-tailscale-on-android)
  - [Step 3.2: Install & Connect Tailscale on PC/Laptop](#step-32-install--connect-tailscale-on-pclaptop)
- [💻 Phase 3: Connect & Deploy from PC via SSH](#-phase-3-connect--deploy-from-pc-via-ssh)
  - [Step 4: Connect to Android Server via SSH](#step-4-connect-to-android-server-via-ssh)
  - [Step 5: Deploy Web Services (Python / Node.js)](#step-5-deploy-web-services-python--nodejs)
  - [Step 5.1: Install PostgreSQL Database (Native Android)](#step-51-install-postgresql-database-native-android)
  - [Step 5.2: Manage Database with DBeaver via SSH Tunnel](#step-52-manage-database-with-dbeaver-via-ssh-tunnel)
  - [Step 6: Expose Website to the Internet via Cloudflare Tunnel](#step-6-expose-website-to-the-internet-via-cloudflare-tunnel)
  - [Step 7: Autostart on Reboot (Termux:Boot & Wake-Lock)](#step-7-autostart-on-reboot-termuxboot--wake-lock)
  - [Step 8: Process Monitoring & Useful Commands](#step-8-process-monitoring--useful-commands)
- [🚀 Phase 4: Automated CI/CD with GitHub Actions](#-phase-4-automated-cicd-with-github-actions)
- [4. Known Limitations & Technical Constraints](#4-known-limitations--technical-constraints)
- [5. Operations & Maintenance Checklist](#5-operations--maintenance-checklist)
- [6. License](#6-license)

---

## 1. Architecture Overview

```
                      [ Public Internet Clients ]
                                  │
                                  ▼
                   https://app.myserverdemo.net
                                  │
                                  ▼
                 [ Cloudflare Edge (DNS + SSL/TLS) ]
                                  │
                       Cloudflare Tunnel (Outbound)
                                  │
                                  ▼
     ┌─────────────────────────────────────────────────────────┐
     │                     Android Device                      │
     │                                                         │
     │  ┌──────────────────┐        ┌───────────────────────┐  │
     │  │  Termux (Host)   │        │     Ubuntu PRoot      │  │
     │  │                  │        │                       │  │
     │  │  • Wake-lock     │───────▶│  • OpenSSH (:2222)    │◀─── [ Laptop Admin ]
     │  │  • Termux:Boot   │        │  • Web Server (:8080) │     • SSH Terminal
     │  │  • Tailscale VPN │        │  • cloudflared agent  │     • DBeaver GUI
     │  │  • PostgreSQL    │        │                       │       (SSH Tunnel :5432)
     │  │    (:5432)       │        │                       │     via Tailscale IP
     │  └──────────────────┘        └───────────────────────┘     (100.85.120.45)
     └─────────────────────────────────────────────────────────┘
```

---

## 2. Prerequisites & Hardware Planning

### Hardware
- **Smartphone**: Android 8.0+ (Android 10+ recommended), 64-bit ARM (`aarch64`), 2 GB+ RAM (3–4 GB recommended).
- **Storage**: Minimum 8–16 GB free internal storage.
- **Power & Thermal**: Standard 5V charger, disable battery optimization, keep device well-ventilated.

### Software & Accounts
- **Termux** & **Termux:Boot** (Installed from F-Droid or GitHub Releases, **not** Google Play Store).
- A free **Tailscale** account (https://tailscale.com/).
- A registered domain name delegated to **Cloudflare DNS** (e.g., `myserverdemo.net`).
- A free **Cloudflare Zero Trust** account.

---

## 3. Sample Configuration Reference (Mock Values)

All commands in this guide use the following **mock sample data**. You can copy-paste these commands directly while testing, or substitute them with your own values:

| Parameter | Mock Sample Value | Explanation |
|---|---|---|
| **Linux Username** | `deploy` | Non-root administrator user in Ubuntu |
| **User Password** | `MySecretPass123` | Password for SSH and `sudo` |
| **SSH Port** | `2222` | Listening port for OpenSSH inside PRoot |
| **Tailscale Phone IP** | `100.85.120.45` | Random mock Tailscale CGNAT IP of the phone |
| **Local Wi-Fi IP** | `192.168.1.120` | Local network IP alternative |
| **Custom Domain** | `myserverdemo.net` | Domain registered and managed on Cloudflare |
| **Website Subdomain** | `app.myserverdemo.net` | Hostname mapped to your web application |
| **Web Service Port** | `8080` | Internal port of the web server |
| **Cloudflare Tunnel Name** | `pocket-vps` | Name of the tunnel connector |
| **Cloudflare Token** | `eyJhIjoiMTIzNDVhYmNkZSIsInQiOiJkZW1vLXV1aWQiLCJzIjoiZXhhbXBsZSJ9` | Mock connector authentication token |

---

## 📱 Phase 1: Bootstrap on Phone

*Run these initial setup commands directly in the Termux app on your phone.*

### Step 1: Install Termux & Ubuntu PRoot

1. Download and install **Termux** from **[F-Droid](https://f-droid.org/packages/com.termux/)** or **[GitHub Releases](https://github.com/termux/termux-app/releases)**.
2. Launch Termux and update package repositories:
   ```bash
   pkg update && pkg upgrade -y
   pkg install -y openssh proot-distro curl wget nano git
   ```
   > [!TIP]
   > **Termux Host Rescue SSH (Port 8022)**: The `openssh` package above allows you to start an independent SSH server directly on the Termux host for emergency out-of-band recovery. See the dedicated guide: [Installing & Connecting SSH to Termux Host](docs/en/termux-ssh-guide.md).
3. Install Ubuntu ARM64:
   ```bash
   proot-distro install ubuntu
   ```
4. Log in to your new Ubuntu system:
   ```bash
   proot-distro login ubuntu
   ```

---

### Step 2: Create Non-Root User & Enable SSH

Inside PRoot Ubuntu (`root@localhost:~#`):

1. **Install OpenSSH Server and essential utilities**:
   ```bash
   apt update && apt upgrade -y
   apt install -y openssh-server sudo iproute2 procps curl wget nano ca-certificates
   ```

2. **Create a non-root user** (`deploy`) and configure passwordless sudo:
   ```bash
   adduser deploy
   # Enter password (e.g. MySecretPass123) and press Enter through prompts
   
   usermod -aG sudo deploy

   # Enable passwordless sudo (Required so CI/CD and unattended background boot scripts do not stall)
   echo "deploy ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/deploy
   chmod 0440 /etc/sudoers.d/deploy
   ```

3. **Configure SSH on Port 2222**:
   ```bash
   nano /etc/ssh/sshd_config
   ```
   Add or ensure these lines exist:
   ```text
   Port 2222
   PermitRootLogin no
   PasswordAuthentication yes
   ```

4. **Start the SSH service**:
   > [!NOTE]
   > In PRoot environments, `/run` is mounted on an ephemeral tmpfs RAM disk. Every time the PRoot container restarts, `/run/sshd` is erased. Always ensure `/run/sshd` exists before starting OpenSSH.

   ```bash
   mkdir -p /run/sshd && chmod 0755 /run/sshd
   service ssh start
   ```
   Check that port 2222 is active:
   ```bash
   ss -lnt | grep 2222
   ```

---

## 🌐 Phase 2: Setup Tailscale for Secure Remote Access

Tailscale creates an encrypted, zero-configuration WireGuard mesh network connecting your phone and PC, allowing you to SSH from any network (home, office, or coffee shop) without opening router ports.

### Step 3.1: Install & Connect Tailscale on Android
1. Install **Tailscale** on your phone from [Google Play](https://play.google.com/store/apps/details?id=com.tailscale.ipn) or [F-Droid](https://f-droid.org/packages/com.tailscale.ipn/).
2. Open the app and log in (Google, GitHub, Microsoft, or Apple account).
3. Toggle the switch to **Active**.
4. The app will display an IP address starting with `100.x.y.z` (for our example: `100.85.120.45`). Note down this IP!
5. **Battery Setting**: In Android **Settings** → **Apps** → **Tailscale** → **Battery**, set to **Unrestricted** so Android does not kill the VPN connection in the background.

### Step 3.2: Install & Connect Tailscale on PC/Laptop
1. Install Tailscale on your computer:
   - **Ubuntu/Debian Linux**:
     ```bash
     curl -fsSL https://tailscale.com/install.sh | sh
     sudo tailscale up
     ```
   - **macOS / Windows**: Download installer from [tailscale.com/download](https://tailscale.com/download) and launch it.
2. Sign in with the **same account** used on the phone.
3. Test connectivity by pinging your phone's Tailscale IP:
   ```bash
   ping 100.85.120.45
   ```
   *If you receive replies, your secure private tunnel is ready!*

> [!SUCCESS]
> **Phone setup complete!** Plug your phone into its charger and switch to your PC. All subsequent steps are performed from your computer terminal.

---

## 💻 Phase 3: Connect & Deploy from PC via SSH

### Step 4: Connect to Android Server via SSH

From your PC/Laptop terminal, connect using the sample user and Tailscale IP:

```bash
ssh -p 2222 deploy@100.85.120.45
```

When prompted, enter your password (`MySecretPass123`). You now have full terminal access to Ubuntu running on your phone!

*(Alternative: If both devices are on the same local Wi-Fi, you can also connect via LAN IP, e.g. `ssh -p 2222 deploy@192.168.1.120`).*

#### Optional: Enable Passwordless SSH Key Login
From your PC terminal:
```bash
ssh-copy-id -p 2222 deploy@100.85.120.45
```
After testing key login, disable password auth in `/etc/ssh/sshd_config` (`PasswordAuthentication no`) for maximum security.

---

### Step 5: Deploy Web Services (Python / Node.js)

#### Option A: Lightweight Python Web Server (Instant Test)
1. Create project directories:
   ```bash
   mkdir -p ~/projects/website ~/logs
   cd ~/projects/website
   ```

2. Create a clean sample landing page:
   ```bash
   cat << 'EOF' > index.html
   <!DOCTYPE html>
   <html lang="en">
   <head>
     <meta charset="UTF-8">
     <meta name="viewport" content="width=device-width, initial-scale=1">
     <title>Pocket Linux Server</title>
     <style>
       body { font-family: system-ui, sans-serif; display: flex; align-items: center; justify-content: center; height: 90vh; margin: 0; background: #0f172a; color: #f8fafc; text-align: center; }
       .card { background: #1e293b; padding: 2.5rem 3.5rem; border-radius: 1rem; box-shadow: 0 10px 25px rgba(0,0,0,0.5); border: 1px solid #334155; }
       h1 { color: #38bdf8; margin-bottom: 0.5rem; }
       p { color: #94a3b8; }
       .badge { display: inline-block; background: #0284c7; color: white; padding: 0.25rem 0.75rem; border-radius: 9999px; font-size: 0.875rem; }
     </style>
   </head>
   <body>
     <div class="card">
       <div class="badge">Online</div>
       <h1>📱 Pocket Android Server</h1>
       <p>Running on Ubuntu PRoot • Managed via SSH • Tunneled through Cloudflare.</p>
     </div>
   </body>
   </html>
   EOF
   ```

3. Start web server in background on port `8080`:
   ```bash
   nohup python3 -m http.server 8080 --bind 0.0.0.0 > ~/logs/website.log 2>&1 < /dev/null &
   ```

4. Verify local HTTP response:
   ```bash
   curl -I http://127.0.0.1:8080
   ```
   *Expected response: `HTTP/1.0 200 OK`*

---

#### Option B: Modern Node.js / Vite Application
```bash
sudo apt update && sudo apt install -y nodejs npm
node -v && npm -v

cd ~/projects
npm create vite@latest my-app -- --template vue
cd my-app
npm install
npm run build
```

---

### Step 5.1: Install PostgreSQL Database (Native Android)

> [!TIP]
> 📖 For a detailed guide on managing databases and troubleshooting, refer to [PostgreSQL & DBeaver Guide](docs/en/dbeaver-database-guide.md).

To prevent deadlocks caused by Android kernel blocking SysV IPC/shared memory system calls inside PRoot glibc, install **PostgreSQL natively in Termux Host**:

1. In Termux main shell (`~$`, outside PRoot):
   ```bash
   pkg install postgresql -y
   mkdir -p $PREFIX/var/lib/postgresql
   initdb $PREFIX/var/lib/postgresql
   pg_ctl -D $PREFIX/var/lib/postgresql -l logfile start
   ```

2. Configure superuser password and create a project database:
   ```bash
   psql -d postgres
   ```
   In `postgres=#`:
   ```sql
   ALTER USER postgres WITH PASSWORD '123123';
   CREATE DATABASE myapp_db;
   \q
   ```

---

### Step 5.2: Manage Database with DBeaver via SSH Tunnel

Manage your PostgreSQL database securely from your PC using [DBeaver Community](https://dbeaver.io/) without exposing port `5432` to the public internet:

1. Open DBeaver → **New Database Connection** → Choose **PostgreSQL** → Click **Next**.
2. **Main Tab (Database Configuration)**:
   * **Host**: `localhost` *(Mandatory: evaluated from the SSH tunnel endpoint on the phone)*.
   * **Port**: `5432`
   * **Database**: `myapp_db` *(or `postgres`)*
   * **Username**: `postgres`
   * **Password**: `123123` *(configured in Step 5.1)*
3. **SSH Tab (Secure Tunnel via Tailscale)**:
   * Check **`[x] Use SSH Tunnel`**
   * **Host/IP**: `100.94.18.108` *(Phone Tailscale IP)*
   * **Port**: `2222` *(Ubuntu PRoot SSH port)*
   * **User Name**: `deploy`
   * **Authentication Method**: **Password** or **Public Key**.
4. Click **Test Connection**. When the green **Connected** checkmark appears, click **Finish**.

---

### Step 6: Expose Website to the Internet via Cloudflare Tunnel

Cloudflare Tunnel safely bridges your local phone server to the internet without exposing your IP or opening router ports.

#### 6.1. Create Tunnel on Cloudflare Zero Trust Dashboard
1. On your PC browser, visit [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/).
2. Navigate to **Networks** → **Tunnels** → **Add a tunnel**.
3. Select **Cloudflared** connector.
4. Name your tunnel: `pocket-vps`.
5. Cloudflare will generate a command showing your tunnel token. Copy the token string.

#### 6.2. Download & Install `cloudflared` on Phone (via SSH)
In your PC terminal SSH session:

```bash
mkdir -p ~/bin
cd ~/bin

# Download ARM64 Linux binary
wget -O cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64
chmod +x cloudflared
sudo mv cloudflared /usr/local/bin/

cloudflared --version
```

#### 6.3. Save Token & Create Standalone Runner Script
Save your token into a secured configuration file:
```bash
mkdir -p ~/.cloudflared ~/logs

# Save your token (Use nano or echo to avoid mobile terminal line-wrapping issues)
nano ~/.cloudflared/token
# Paste your token string -> Ctrl+O -> Enter -> Ctrl+X
chmod 600 ~/.cloudflared/token
```

Create an idempotent runner script `~/start-tunnel.sh` that prevents duplicate background processes:
```bash
nano ~/start-tunnel.sh
```

Paste the following script:
```bash
#!/bin/bash
# Exit immediately if cloudflared is already active
if pidof cloudflared > /dev/null 2>&1; then
    exit 0
fi

TOKEN=$(cat ~/.cloudflared/token 2>/dev/null | tr -d '\r\n')
if [ -n "$TOKEN" ]; then
    nohup cloudflared tunnel run --token "$TOKEN" > ~/logs/cloudflared.log 2>&1 &
fi
```

Make it executable and launch it:
```bash
chmod +x ~/start-tunnel.sh
~/start-tunnel.sh
```

Verify that the process is running cleanly:
```bash
ps -C cloudflared -o pid,user,cmd
```
*In the Cloudflare Dashboard, the tunnel status will turn green (**Healthy**).*

#### 6.4. Configure Public Route in Dashboard
1. Go to the **Public Hostnames** tab inside your tunnel in Cloudflare Dashboard.
2. Click **Add a public hostname**.
3. Enter your routing rules:
   - **Subdomain**: `app`
   - **Domain**: `myserverdemo.net`
   - **Type**: `HTTP`
   - **URL**: `127.0.0.1:8080`
4. Click **Save hostname**.
5. Open `https://app.myserverdemo.net` in your browser from an external network (e.g. 4G/cellular) to test.

---

### Step 7: Service Autostart Configuration (Termux Login & Phone Reboot)

> [!TIP]
> 📖 For an end-to-end autonomous cold boot recovery guide covering Android OS, native PostgreSQL, Redis, PM2, and Cloudflare, refer to: [Complete Autostart & Disaster Recovery Guide](docs/en/autostart-services-guide.md).

To make your phone operate reliably as an autonomous 24/7 server, service autostart is split into two operational levels:

#### 1. Autostart on Ubuntu PRoot Login (`~/.bashrc`)

Whenever you open Termux on your phone and launch Ubuntu (`proot-distro login ubuntu --user deploy`), OpenSSH and Cloudflare Tunnel should launch automatically.

> [!IMPORTANT]
> **SSH Session vs Local Console Guard**:
> When you SSH into your phone from your laptop, the system **must NOT re-run startup routines** (which would launch duplicate processes and slow down terminal response). We guard against this by checking the `$SSH_CLIENT` environment variable.
> In addition, **NEVER put service startup commands in `~/.profile`** because OpenSSH executes `~/.profile` for every remote login shell.

Edit `~/.bashrc`:
```bash
nano ~/.bashrc
```

Append the following block to the **very end** of `~/.bashrc`:
```bash
# Only start services when opened directly from local Termux console
# Skip completely during remote SSH sessions to prevent process duplication
if [ -z "$SSH_CLIENT" ] && [ -z "$SSH_CONNECTION" ]; then
    sudo mkdir -p /run/sshd
    sudo chmod 0755 /run/sshd
    sudo service ssh status > /dev/null 2>&1 || sudo service ssh start
    ~/start-tunnel.sh
fi
```
Save: `Ctrl + O` -> `Enter` -> `Ctrl + X`.

#### 2. Autostart on Phone Cold Reboot (Termux:Boot)
1. Install **Termux:Boot** from F-Droid. Open the app once to register permissions.
2. Inside Termux (host environment, outside Ubuntu):
   ```bash
   mkdir -p ~/.termux/boot
   nano ~/.termux/boot/start-server.sh
   ```
3. Use the helper script [`scripts/boot-termux.sh`](scripts/boot-termux.sh):
   ```bash
   #!/data/data/com.termux/files/usr/bin/bash
   termux-wake-lock
   sleep 15
   proot-distro login ubuntu -- su - deploy -c "/home/deploy/scripts/start-services.sh"
   ```
4. Make it executable:
   ```bash
   chmod +x ~/.termux/boot/start-server.sh
   ```

#### 3. Consolidated Multi-Service Management Script
In your SSH session:
```bash
mkdir -p ~/scripts
nano ~/scripts/start-services.sh
# Paste content from scripts/start-services.sh
chmod +x ~/scripts/start-services.sh
```

---

### Step 8: Process Monitoring & Useful Commands

> [!TIP]
> 📖 For an extensive cheatsheet of commands covering PM2, port inspection, logs, PostgreSQL, Redis, and Cloudflare, refer to: [Essential DevOps Commands Cheatsheet](docs/en/useful-commands-cheatsheet.md).

Use the [`scripts/start-services.sh`](scripts/start-services.sh) management script:

```bash
# Check status of SSH, Web Server, and Cloudflare Tunnel
~/scripts/start-services.sh status

# Restart all services
~/scripts/start-services.sh restart

# Check live web traffic
tail -f ~/logs/website.log

# Check Cloudflare tunnel logs
tail -n 50 ~/logs/cloudflared.log
```

---

## 🚀 Phase 4: Automated CI/CD with GitHub Actions

Once your Android VPS server and database are running, you can configure an automated, zero-cost (0 VND) continuous deployment pipeline:
Every time you run `git push origin main`, GitHub Actions will:
1. Connect securely to your private **Tailscale** network using an ephemeral auth key.
2. SSH into your Android VPS and pull the latest commits (`git pull`).
3. Install dependencies and **run automated database migrations** (Prisma / Alembic / Django) on local PostgreSQL (`localhost:5432`).
4. Reload the backend application via **PM2** with zero downtime.

📖 **Deep-Dive Developer Guides:**
* 👉 [**Essential DevOps Commands Cheatsheet**](docs/en/useful-commands-cheatsheet.md) *(Vietnamese: [Bản tiếng Việt](docs/vi/useful-commands-cheatsheet.md))*
* 👉 [**Complete Autostart & Disaster Recovery Guide (Cold Reboot)**](docs/en/autostart-services-guide.md) *(Vietnamese: [Bản tiếng Việt](docs/vi/autostart-services-guide.md))*
* 👉 [**Installing & Connecting SSH to Termux Host (Port 8022)**](docs/en/termux-ssh-guide.md) *(Vietnamese: [Bản tiếng Việt](docs/vi/termux-ssh-guide.md))*
* 👉 [**Automated CI/CD Pipeline with GitHub Actions & Tailscale**](docs/en/cicd-github-actions.md) *(Vietnamese: [Bản tiếng Việt](docs/vi/cicd-github-actions.md))*
* 👉 [**Multi-Backend Service Management & Isolated CI/CD**](docs/en/multi-backend-management.md) *(Vietnamese: [Bản tiếng Việt](docs/vi/multi-backend-management.md))*
* 👉 [**PostgreSQL Installation & Database Management via DBeaver**](docs/en/dbeaver-database-guide.md) *(Vietnamese: [Bản tiếng Việt](docs/vi/dbeaver-database-guide.md))*

*(Workflow template available at: [`.github/workflows/deploy.yml.example`](.github/workflows/deploy.yml.example))*.

---

## 4. Technical Constraints & Troubleshooting Field Guide

### 4.1. Known Limitations & Constraints

- **No Native Docker Support**: PRoot operates in user-space via `ptrace`. Linux kernel namespaces, cgroups, and bridge networking required by Docker are not available without a custom rooted kernel.
- **Systemd Absence**: Standard `systemctl` does not run inside PRoot. Use `service <name> start` or custom shell scripts / `supervisord`.
- **Battery Care**: To prevent battery swelling when plugged in 24/7, use battery protection features (e.g. Sony's Battery Care, Samsung's Protect Battery at 80%, or rooted battery charge limiters).
- **Ephemeral `/run` Directory**: PRoot mounts `/run` on tmpfs (RAM). Exiting PRoot clears `/run/sshd`. Always recreate `/run/sshd` prior to launching OpenSSH.

### 4.2. Troubleshooting Field Guide (FAQ)

#### 1. Why are there multiple `cloudflared` or `sshd-session` entries in `top`?
* **`sshd-session` (2 rows)**: Normal behavior. OpenSSH uses **Privilege Separation** where one unprivileged child process isolates network decryption and one child process runs as the authenticated user.
* **`cloudflared` (multiple rows)**: `cloudflared` is a multi-threaded Go application. `top` defaults to displaying individual threads (LWP). Press **`Shift + H`** in `top` to toggle thread display on/off.
* **Inspecting true processes**: Use `ps -C cloudflared -o pid,user,cmd` to view distinct process instances.

#### 2. Mobile Keyboard Syntax Errors (`Exit 127 󰛉token` or `syntax error near unexpected token 'newline'`)
* **Root Cause**: Virtual keyboards on Android (Gboard, Samsung, Laban Key) automatically convert double hyphens `--` into en-dashes `–` or Unicode private-use ligatures (`[EF][F9]`). Multi-line heredocs pasted into Termux also wrap across lines.
* **Solution**: Always use `nano` or execute configuration commands from your laptop via SSH.

#### 3. OpenSSH reports `[ OK ]` but `service ssh status` shows `sshd is not running`
* **Root Cause**: Missing privilege separation directory `/run/sshd`.
* **Solution**: Run:
  ```bash
  sudo mkdir -p /run/sshd && sudo chmod 0755 /run/sshd && sudo service ssh restart
  ```

#### 4. Clean Reset Command (Clearing Duplicate Background Hooks)
If duplicate processes were spawned or startup scripts were accidentally placed in both `.profile` and `.bashrc`:
```bash
# 1. Terminate all running cloudflared instances
pkill -9 cloudflared

# 2. Strip previous autostart lines from .profile and .bashrc
sed -i '/cloudflared/d; /start-tunnel/d; /token/d; /sshd/d' ~/.profile
sed -i '/cloudflared/d; /start-tunnel/d; /token/d; /sshd/d; /SSH_CLIENT/d; /SSH_CONNECTION/d' ~/.bashrc

# 3. Clean up log files
rm -f ~/nohup.out ~/logs/cloudflared.log ~/cloudflared.log
```

---

## 5. Operations & Maintenance Checklist

- [ ] Phone plugged into power with battery optimization set to **Unrestricted**.
- [ ] Tailscale active on phone and PC; ping responds to `100.85.120.45`.
- [ ] SSH accessible from PC: `ssh -p 2222 deploy@100.85.120.45`.
- [ ] Web application responds locally to `curl -I http://127.0.0.1:8080`.
- [ ] `cloudflared` tunnel connector is running and shows **Healthy** in Cloudflare Zero Trust.
- [ ] Website reachable publicly at `https://app.myserverdemo.net`.
- [ ] Autostart script verified by performing a test phone reboot.

---

## 6. License

This project is open-source under the [MIT License](LICENSE).
