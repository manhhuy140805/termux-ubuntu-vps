# Automated CI/CD with GitHub Actions & Tailscale for Android VPS

[**[🇻🇳 Đọc bản Tiếng Việt](../vi/cicd-github-actions.md)** • **[🏠 Home](../../README.md)**]

This guide provides a comprehensive setup for an **enterprise-grade, 100% automated CI/CD pipeline ($0 cost)** combining **GitHub Actions**, **Tailscale Mesh VPN**, and an **Android Ubuntu (PRoot) server**.

Every time you execute `git push origin main` on your PC:
1. **GitHub Actions** provisions an ephemeral cloud runner.
2. The runner connects securely to your private **Tailscale Tailnet**.
3. It opens an SSH session to your phone VPS over private Tailscale IP (`100.x.y.z:2222`).
4. Pulls the latest code (`git pull`) and updates dependencies (`npm install` / `pip install`).
5. **🎯 Automatically executes Database Migrations** against native PostgreSQL (`localhost:5432`).
6. Restarts applications with **PM2** (Zero-downtime rolling restart).
7. Exposes the updated service instantly to the internet via **Cloudflare Tunnel**.

---

## 📑 Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [VPS Hardware & Environment Specifications](#2-vps-hardware--environment-specifications)
3. [Prerequisites](#3-prerequisites)
4. [Step 1: Prepare the Android VPS Environment](#step-1-prepare-the-android-vps-environment)
5. [Step 2: Generate Ephemeral Auth Key on Tailscale](#step-2-generate-ephemeral-auth-key-on-tailscale)
6. [Step 3: Generate Dedicated SSH Key for GitHub Actions](#step-3-generate-dedicated-ssh-key-for-github-actions)
7. [Step 4: Configure Repository Secrets on GitHub](#step-4-configure-repository-secrets-on-github)
8. [Step 5: Create GitHub Actions Workflow File](#step-5-create-github-actions-workflow-file)
9. [Step 6: Live Deployment Verification](#step-6-live-deployment-verification)
10. [Optimization & Troubleshooting FAQ](#10-optimization--troubleshooting-faq)

---

## 1. Architecture Overview

```mermaid
flowchart TD
    Dev["💻 Developer (PC/Laptop)"] -->|"git push origin main"| GH["🐙 GitHub Repository"]
    
    subgraph GHA ["☁️ GitHub Actions Runner (Ubuntu Cloud VM)"]
        A1["1. Checkout Code"] --> A2["2. tailscale/github-action\n(Join Tailnet via Ephemeral Auth Key)"]
        A2 --> A3["3. appleboy/ssh-action\n(SSH via Private Tailscale IP)"]
    end
    
    GH -->|"Trigger Workflow"| GHA
    
    subgraph Phone ["📱 Android Server (Pocket VPS)"]
        subgraph TailscaleNet ["Private Tailscale Network (:2222)"]
            S1["Git Pull Latest Code"] --> S2["Install Dependencies (npm/pip)"]
            S2 --> S3["🎯 Database Migration\n(Prisma / Alembic / Django)"]
            S3 --> S4["PM2 Zero-Downtime Reload"]
        end
        
        DB[("🐘 PostgreSQL\n(localhost:5432)")]
        S3 <-->|"Schema Update"| DB
        
        CF["☁️ Cloudflare Tunnel\n(cloudflared)"]
        S4 <-->|"localhost:3000 / 8080"| CF
    end

    A3 -->|"SSH via 100.x.y.z:2222"| TailscaleNet
    CF -->|"Public HTTPS"| Internet["🌐 Internet Users\n(https://app.yourdomain.com)"]
```

---

## 2. VPS Hardware & Environment Specifications

### 2.1. Hardware Specifications

| Specification | Target Value | CI/CD Relevance |
| :--- | :--- | :--- |
| **Device Model** | Sony Xperia Ace II (`SO-41B`) | Compact, highly energy-efficient 24/7 server |
| **SoC / Processor** | MediaTek Helio P35 (MT6765) | 8-core ARM Cortex-A53 (4x 2.3 GHz + 4x 1.8 GHz) |
| **CPU Architecture** | `arm64` (`aarch64`) | Binaries & dependencies must be ARM64 compatible |
| **RAM** | 4 GB LPDDR4X (~3.8 GB available) | Sufficient to run OS, PostgreSQL, Redis, and 3-5 backend services |
| **Internal Storage**| 64 GB eMMC 5.1 | Ample space for OS, PostgreSQL database, and git repos |
| **Power & Battery** | Continuous 5V charging (Battery Care on) | Sony Battery Care restricts charge to 80-90% to avoid battery swelling |

### 2.2. Dual-Layer Architecture

The server separates responsibilities between **Termux Host** and **Ubuntu PRoot (Guest)** for maximum performance and fault tolerance:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   PHYSICAL ANDROID OPERATING SYSTEM                    │
│                                                                        │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ 🟢 LAYER 1: TERMUX HOST (NATIVE BIONIC ARM64)                    │  │
│  │                                                                  │  │
│  │  • PostgreSQL Server (:5432) - Native Bionic, lightweight (~30MB)│  │
│  │  • OpenSSH Server (:8022) - Emergency rescue shell               │  │
│  │  • Termux:Boot - System boot autostart hook                      │  │
│  │  • Tailscale Android (Always-on VPN) - Mesh VPN transport        │  │
│  └──────────────────────────────────┬───────────────────────────────┘  │
│                                     │ (Mount rootfs & Loopback)        │
│  ┌──────────────────────────────────▼───────────────────────────────┐  │
│  │ 🔵 LAYER 2: UBUNTU PROOT (GUEST LINUX CONTAINER)                  │  │
│  │                                                                  │  │
│  │  • User: deploy (NOPASSWD:ALL in sudoers)                        │  │
│  │  • OpenSSH Server (:2222) - Primary CI/CD & admin access port    │  │
│  │  • PM2 Process Manager - Process daemon & health manager         │  │
│  │  • Cloudflare Tunnel (cloudflared) - Edge ingress router         │  │
│  │  • Database Access: Direct loopback to Layer 1 localhost:5432     │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

### 2.3. Port & Service Mapping

| Port | Protocol | Layer | Service | Role in CI/CD |
| :---: | :---: | :--- | :--- | :--- |
| **`2222`** | TCP / SSH | Ubuntu PRoot | OpenSSH Server (User: `deploy`) | **Primary**: GitHub Actions SSH deployment endpoint |
| **`8022`** | TCP / SSH | Termux Native | OpenSSH Server (User: Termux) | **Rescue**: Host-level rescue terminal if Ubuntu fails |
| **`5432`** | TCP | Termux Native | PostgreSQL Server | **Database**: Migration target and persistent storage (see [DBeaver Guide](dbeaver-database-guide.md)) |
| **`6379`** | TCP | Ubuntu PRoot | Redis Server (`redis-server`) | **Queue & Cache**: BullMQ worker queue for mail and audit logs |
| **`3000` / `8080`** | TCP / HTTP | Ubuntu PRoot | Backend App (PM2) | Application HTTP listener |
| **Internet** | HTTPS | Cloudflare Edge | Cloudflare Tunnel | Public domain ingress routing |

### 2.4. Critical CI/CD Constraints

1. **No Docker Inside Android VPS:**
   * PRoot operates in user space via `ptrace`; it cannot manage kernel cgroups/namespaces required by Docker engine.
   * **CI/CD Strategy**: Heavy build and lint steps run on free GitHub Runners (4 vCPUs, 16 GB RAM); lightweight compiled code/artifacts are pushed to the VPS and supervised by **PM2**.
2. **Session Guard (`$SSH_CLIENT` Check):**
   * Startup scripts in `~/.bashrc` must bypass initialization when `$SSH_CLIENT` is present. This guarantees non-interactive CI/CD SSH commands execute immediately in ~0.1s without re-triggering interactive scripts.
3. **Automatic Cold Recovery:**
   * After a power outage, Android boots up; **Always-on VPN** reconnects Tailscale, and **Termux:Boot** restores PostgreSQL, SSH, and Cloudflare Tunnel within 30 seconds.

---

## 3. Prerequisites

* Android VPS configured per the main guide:
  * Running **Ubuntu PRoot** with user `deploy` (`NOPASSWD:ALL` configured).
  * **OpenSSH Server** listening on port `2222`.
  * **Tailscale** active with a stable Tailscale IP (`100.x.y.z`).
  * **Cloudflare Tunnel** operational and routing to local port.
* A **GitHub** account and repository with your backend codebase.
* **PM2** process manager installed on the VPS.

---

## Step 1: Prepare the Android VPS Environment

SSH into your phone VPS from your PC:
```bash
ssh -p 2222 deploy@100.94.18.108
```

### 1. Install PM2
```bash
sudo npm install -g pm2
```

### 2. Install Redis Server (Port 6379) for BullMQ
```bash
sudo apt update && sudo apt install -y redis-server
sudo service redis-server start
redis-cli ping
# Expected response: PONG
```

Add autostart to `~/.bashrc`:
```bash
sudo service redis-server status > /dev/null 2>&1 || sudo service redis-server start
```

### 3. Clone Repository
```bash
mkdir -p ~/projects
cd ~/projects
git clone git@github.com:your-username/my-app.git
cd my-app
```

### 4. Create `.env` on VPS
```bash
nano .env
```
Example `.env`:
```env
PORT=3000
DATABASE_URL="postgresql://postgres:123123@localhost:5432/myapp_db"
REDIS_HOST="localhost"
REDIS_PORT=6379
JWT_SECRET="your_secure_secret"
NODE_ENV="production"
```

### 5. Launch with PM2
```bash
npm install
pm2 start dist/main.js --name "my-app"
pm2 save
```

---

## Step 2: Generate Ephemeral Auth Key on Tailscale

1. Visit [login.tailscale.com/admin/settings/keys](https://login.tailscale.com/admin/settings/keys).
2. Click **Generate auth key**.
3. Configure settings:
   * **Reusable**: **ON**
   * **Ephemeral**: **ON** *(Essential: the runner removes itself from Tailscale upon completion)*.
   * **Pre-authorized**: **ON**
4. Click **Generate key** and copy the string (`tskey-auth-kXXXXX...`).

---

## Step 3: Generate Dedicated SSH Key for GitHub Actions

On your **PC terminal**:

```bash
# 1. Generate dedicated ED25519 key pair
ssh-keygen -t ed25519 -C "github-actions-ci" -f ~/.ssh/github_actions -N ""

# 2. Authorize public key on the phone VPS
ssh-copy-id -i ~/.ssh/github_actions.pub -p 2222 deploy@100.94.18.108
```

Verify passwordless login:
```bash
ssh -i ~/.ssh/github_actions -p 2222 deploy@100.94.18.108
```

---

## Step 4: Configure Repository Secrets on GitHub

On GitHub, navigate to your repo ➔ **Settings** ➔ **Secrets and variables** ➔ **Actions** ➔ **New repository secret**:

| Secret Name | Value | Description |
| :--- | :--- | :--- |
| `TAILSCALE_AUTHKEY` | `tskey-auth-...` | Ephemeral Auth Key generated in Step 2 |
| `SSH_HOST` | `100.94.18.108` | Phone's Tailscale IP address |
| `SSH_PORT` | `2222` | SSH port on Ubuntu PRoot |
| `SSH_USER` | `deploy` | Ubuntu user account |
| `SSH_PRIVATE_KEY` | Content of `~/.ssh/github_actions` | Private SSH key from PC (including header and footer lines) |

---

## Step 5: Create GitHub Actions Workflow File

In your project repository, create `.github/workflows/deploy.yml`:

```yaml
name: CI/CD Pipeline to Android VPS

on:
  push:
    branches:
      - main
  workflow_dispatch:

jobs:
  deploy:
    name: Build, Migrate & Deploy
    runs-on: ubuntu-latest
    timeout-minutes: 15

    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Connect to Tailscale Network
        uses: tailscale/github-action@v3
        with:
          authkey: ${{ secrets.TAILSCALE_AUTHKEY }}

      - name: Deploy to Android VPS via SSH
        uses: appleboy/ssh-action@v1.0.3
        with:
          host: ${{ secrets.SSH_HOST }}
          port: ${{ secrets.SSH_PORT }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          timeout: 120s
          command_timeout: 10m
          script: |
            set -e
            echo "🚀 [CI/CD] Connected to Android VPS!"
            
            cd ~/projects/my-app

            echo "📥 [1/4] Pulling latest code..."
            git pull origin main

            echo "📦 [2/4] Updating dependencies..."
            npm install --production=false

            echo "🐘 [3/4] Applying database migrations..."
            npx prisma migrate deploy

            echo "⚙️ [4/4] Compiling project..."
            npm run build --if-present

            echo "🔄 Reloading PM2 process..."
            pm2 reload my-app || pm2 start dist/main.js --name "my-app"
            pm2 save

            echo "✅ [CI/CD] Deployment complete! App is live on Cloudflare Tunnel."
```

---

## Step 6: Live Deployment Verification

1. On your PC, make a test commit to `main`:
   ```bash
   git add .
   git commit -m "feat: verify automated ci/cd pipeline"
   git push origin main
   ```
2. Open your GitHub repository ➔ Click the **Actions** tab.
3. Observe the job: Tailscale authenticates in ~5 seconds, then SSH executes `git pull`, `npx prisma migrate deploy`, and `pm2 reload`.
4. When the status turns green, visit `https://app.yourdomain.com` to see your updates live.

---

## 10. Optimization & Troubleshooting FAQ

### 1. `Host key verification failed`
* Ensure your `appleboy/ssh-action` configuration does not enforce `sync: true` unless custom known host fingerprints are provided.

### 2. Cloud-Build Pattern (Saving Phone CPU/RAM)
* For large frameworks (Next.js/Nuxt), build on GitHub Cloud Runner (`npm run build`) and copy `.next` or `dist` to the phone via `rsync` or `scp`. This keeps phone temperatures low and completes deployments in under 10 seconds.

### 3. Safe Database Migrations in CI/CD
* Always use `npx prisma migrate deploy` instead of `prisma migrate dev`. Modern ORMs (Prisma, Alembic) wrap schema migrations in database transactions, automatically rolling back on failure.
