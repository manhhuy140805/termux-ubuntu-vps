# Installing & Connecting SSH to Termux Host (Port 8022)

[**[🇻🇳 Đọc bản Tiếng Việt](../vi/termux-ssh-guide.md)** • **[🏠 Home](../../README.md)**]

This guide explains how to install, configure, and connect to **OpenSSH directly on the Termux Host Layer** listening on port **`8022`** over the private Tailscale network.

---

## 📑 Table of Contents

1. [Difference Between Termux Host SSH (:8022) vs Ubuntu PRoot SSH (:2222)](#1-difference-between-termux-host-ssh-8022-vs-ubuntu-proot-ssh-2222)
2. [Why Having Termux SSH Port 8022 is Essential](#2-why-having-termux-ssh-port-8022-is-essential)
3. [Step 1: Install & Configure OpenSSH on Termux](#step-1-install--configure-openssh-on-termux)
4. [Step 2: Autostart Configuration & Avoiding Auto-login Conflicts](#step-2-autostart-configuration--avoiding-auto-login-conflicts)
5. [Step 3: Connect via SSH from PC to Termux](#step-3-connect-via-ssh-from-pc-to-termux)
6. [Step 4: Configure Passwordless SSH Key Authentication](#step-4-configure-passwordless-ssh-key-authentication)
7. [Real-world Rescue Scenarios via Port 8022](#real-world-rescue-scenarios-via-port-8022)

---

## 1. Difference Between Termux Host SSH (:8022) vs Ubuntu PRoot SSH (:2222)

Our Android VPS operates on a dual-layer architectural model:

| Comparison Attribute | 🟢 Termux Host SSH (Layer 1) | 🔵 Ubuntu PRoot SSH (Layer 2) |
| :--- | :--- | :--- |
| **Port** | **`8022`** | **`2222`** |
| **Environment** | Android Native (Bionic libc) | Ubuntu 24.04 ARM64 (glibc) |
| **Start Command** | `sshd` | `service ssh start` |
| **User Account** | Termux user ID (check with `whoami`, e.g. `u0_a245`) | `deploy` |
| **Authentication** | Password set via `passwd` or SSH public key | Standard Ubuntu Linux user password |
| **Primary Purpose** | **Emergency rescue terminal**, native PostgreSQL management, Android hardware controls | **Primary development workspace**, PM2 apps, Redis, GitHub Actions CI/CD |

---

## 2. Why Having Termux SSH Port 8022 is Essential

If you only configure SSH inside Ubuntu (port 2222):
* If Ubuntu suffers an `/etc/ssh/sshd_config` syntax error, tmpfs permission issue on `/run/sshd`, or memory exhaustion deadlock, you are **completely locked out remotely**.
* You would be forced to physically unlock the phone and type commands on the small touchscreen to fix it.

👉 **Termux Port 8022 is your ultimate rescue hatch**: It runs completely independently at the host level. Even if Ubuntu is completely crashed or frozen, you can always SSH into port 8022 from your PC to edit files, kill hung processes, or restart the container.

---

## 3. Step 1: Install & Configure OpenSSH on Termux

Execute this in Termux's main shell (`~$`, **outside Ubuntu PRoot**):

```bash
# 1. Update packages & install OpenSSH
pkg update -y
pkg install openssh -y

# 2. Check your Termux username
whoami
# (Example output: u0_a245)

# 3. Set a password for Termux SSH login
passwd
# Enter and confirm your desired password (e.g. 123123)
# (Linux does not display characters while typing passwords)

# 4. Start the Termux OpenSSH daemon
sshd
```

Verify that the daemon is running:
```bash
pgrep sshd
```
*(A PID number confirms that the OpenSSH server is actively listening on port `8022`).*

---

## 4. Step 2: Autostart Configuration & Avoiding Auto-login Conflicts

If your Termux `~/.bashrc` automatically launches Ubuntu PRoot upon shell startup, connecting via SSH to port 8022 will inadvertently trap you inside Ubuntu instead of giving you a Termux rescue prompt.

We prevent this by guarding the Ubuntu login with the `$SSH_CLIENT` environment variable:

Edit Termux's startup file:
```bash
nano ~/.bashrc
```

Add this block:
```bash
# 1. Automatically start Termux SSH (port 8022) if not running
pgrep -x sshd > /dev/null 2>&1 || sshd

# 2. Automatically start native PostgreSQL if not running
if ! pg_isready -q > /dev/null 2>&1; then
    pg_ctl -D $PREFIX/var/lib/postgresql -l logfile start > /dev/null 2>&1
fi

# 3. ONLY enter Ubuntu when opened locally on the phone screen
# Keep remote SSH sessions on port 8022 inside Termux Host for rescue operations
if [ -z "$SSH_CLIENT" ] && [ -z "$SSH_CONNECTION" ]; then
    if ! pgrep -x proot > /dev/null 2>&1; then
        proot-distro login ubuntu --user deploy
    fi
fi
```
Press `Ctrl + O` → `Enter` to save, `Ctrl + X` to exit `nano`.

---

## 5. Step 3: Connect via SSH from PC to Termux

From your PC terminal (with Tailscale active on both devices):

```bash
# Connect using port 8022:
ssh -p 8022 100.94.18.108

# Or explicitly provide the Termux username:
ssh -p 8022 u0_a245@100.94.18.108
```

* Enter the password you configured via `passwd`.
* Once connected, you will be greeted by the Termux prompt:
  ```text
  ~ $
  ```
* You are now executing commands directly on the host Android environment.

---

## 6. Step 4: Configure Passwordless SSH Key Authentication

To login without entering a password:

From your **PC terminal**:
```bash
ssh-copy-id -p 8022 100.94.18.108
```
Enter your Termux password one last time. You can now access Termux via `ssh -p 8022 100.94.18.108` in ~0.2 seconds without credentials.

---

## 7. Real-world Rescue Scenarios via Port 8022

### Scenario 1: Ubuntu PRoot Freezes / Deadlocks
Recover without touching the physical phone:
```bash
# Terminate hung PRoot instances
pkill -9 proot

# Re-enter Ubuntu cleanly
proot-distro login ubuntu --user deploy
```

### Scenario 2: Manage Native PostgreSQL Daemon
```bash
# Verify database cluster health
pg_isready

# Restart PostgreSQL engine
pg_ctl -D $PREFIX/var/lib/postgresql restart
```

### Scenario 3: Android Power & Thermal Management
```bash
# Prevent Android kernel from sleeping CPU
termux-wake-lock

# Inspect battery level and temperature
termux-battery-status
```
