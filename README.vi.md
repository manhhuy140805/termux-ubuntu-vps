# Hướng Dẫn Biến Điện Thoại Android Thành Linux Web Server (VPS)

[![Platform: Android](https://img.shields.io/badge/Platform-Android%208.0%2B-green.svg)](https://www.android.com/)
[![Môi trường: Termux + PRoot](https://img.shields.io/badge/Environment-Termux%20%7C%20PRoot%20Ubuntu-orange.svg)](https://termux.dev/)
[![Mesh VPN: Tailscale](https://img.shields.io/badge/VPN-Tailscale-blue.svg?logo=tailscale)](https://tailscale.com/)
[![Tunnel: Cloudflare](https://img.shields.io/badge/Tunnel-Cloudflare%20Zero%20Trust-F38020.svg?logo=cloudflare)](https://www.cloudflare.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Bilingual: EN / VI](https://img.shields.io/badge/Language-English%20%7C%20Ti%E1%BA%BFng%20Vi%E1%BB%87t-brightgreen.svg)](#)

[**[🇬🇧 English Version](README.md)** • **[📁 English Guides (`docs/en/`)](docs/en/)** • **[📁 Thư Mục Hướng Dẫn Tiếng Việt (`docs/vi/`)](docs/vi/)**]

---

Tài liệu này hướng dẫn bạn cách tận dụng một chiếc điện thoại Android cũ hoặc dư dùng để làm máy chủ Linux (VPS mini) chạy 24/7. Giải pháp kết hợp **Termux**, **Ubuntu (PRoot)**, **Tailscale**, và **Cloudflare Tunnel (Zero Trust)** giúp bạn:

- Có website chạy với tên miền riêng (custom domain) với chứng chỉ SSL/HTTPS tự động từ Cloudflare.
- Quản trị từ xa bằng SSH an toàn từ bất kỳ đâu (kể cả ngoài quán cafe) thông qua mạng riêng ảo Tailscale.
- **Không cần mở port router (No Port Forwarding)**, hoạt động tốt kể cả sau CGNAT (mạng 4G/5G, Wi-Fi công cộng hay mạng gia đình không có IP tĩnh).
- **Không cần Root máy**, an toàn tuyệt đối cho thiết bị.
- Tự động duy trì và phục hồi dịch vụ sau khi khởi động lại điện thoại.

> [!TIP]
> **Quy trình tối ưu hóa trải nghiệm**: Chúng ta sẽ thiết lập SSH và Tailscale ngay từ đầu (Bước 2 & 3). Ngay sau khi máy tính kết nối SSH thành công vào điện thoại, bạn có thể cất điện thoại sang một bên và thực hiện toàn bộ việc cấu hình, triển khai website, cài đặt Cloudflare Tunnel trực tiếp từ bàn phím và màn hình lớn của máy tính!

---

## 📑 Mục lục

- [1. Mô hình kiến trúc hệ thống](#1-mô-hình-kiến-trúc-hệ-thống)
- [2. Yêu cầu phần cứng & Chuẩn bị](#2-yêu-cầu-phần-cứng--chuẩn-bị)
- [3. Bảng thông số mẫu giả lập (Mock Data)](#3-bảng-thông-số-mẫu-giả-lập-mock-data)
- [📱 Giai đoạn 1: Khởi tạo nhanh trên điện thoại](#-giai-đoạn-1-khởi-tạo-nhanh-trên-điện-thoại)
  - [Bước 1: Cài đặt Termux và Ubuntu PRoot](#bước-1-cài-đặt-termux-và-ubuntu-proot)
  - [Bước 2: Tạo User và Kích hoạt SSH Server](#bước-2-tạo-user-và-kích-hoạt-ssh-server)
- [🌐 Giai đoạn 2: Cài đặt Tailscale để kết nối từ xa an toàn](#-giai-đoạn-2-cài-đặt-tailscale-để-kết-nối-từ-xa-an-toàn)
  - [Bước 3.1: Cài đặt và kết nối Tailscale trên điện thoại](#bước-31-cài-đặt-và-kết-nối-tailscale-trên-điện-thoại)
  - [Bước 3.2: Cài đặt và kết nối Tailscale trên máy tính/laptop](#bước-32-cài-đặt-và-kết-nối-tailscale-trên-máy-tínhlaptop)
- [💻 Giai đoạn 3: Cấu hình và Triển khai từ máy tính qua SSH](#-giai-đoạn-3-cấu-hình-và-triển-khai-từ-máy-tính-qua-ssh)
  - [Bước 4: Kết nối SSH vào điện thoại từ máy tính](#bước-4-kết-nối-ssh-vào-điện-thoại-từ-máy-tính)
  - [Bước 5: Triển khai Web Server (Python / Node.js)](#bước-5-triển-khai-web-server-python--nodejs)
  - [Bước 5.1: Cài đặt Cơ sở Dữ liệu PostgreSQL (Native Android)](#bước-51-cài-đặt-cơ-sở-dữ-liệu-postgresql-native-android)
  - [Bước 5.2: Quản trị Database bằng DBeaver qua SSH Tunnel](#bước-52-quản-trị-database-bằng-dbeaver-qua-ssh-tunnel)
  - [Bước 6: Public Website ra Internet với Cloudflare Tunnel](#bước-6-public-website-ra-internet-với-cloudflare-tunnel)
    - [6.1. Tạo Tunnel và chọn môi trường (OS & Arch)](#61-tạo-tunnel-và-chọn-môi-trường-os--architecture-trên-cloudflare-dashboard)
    - [6.2. Chạy lệnh cài đặt và xử lý lỗi thiếu gói (sudo, curl...)](#62-chạy-lệnh-cài-đặt-từ-cloudflare-và-xử-lý-các-lỗi-thiếu-gói-command-not-found)
    - [6.3. Khởi chạy Connector và xử lý hạn chế Service PRoot](#63-khởi-chạy-connector-và-xử-lý-hạn-chế-service-trong-proot)
    - [6.4. Định tuyến Public Hostname (Tên miền riêng)](#64-định-tuyến-public-hostname-tên-miền-riêng-trên-dashboard)
  - [Bước 7: Tự khởi động sau khi điện thoại Reboot (Termux:Boot)](#bước-7-tự-khởi-động-sau-khi-điện-thoại-reboot-termuxboot)
  - [Bước 8: Quản lý tiến trình, xem Log và Script tự động](#bước-8-quản-lý-tiến-trình-xem-log-và-script-tự-động)
- [🚀 Giai đoạn 4: Tự động hóa CI/CD với GitHub Actions](#-giai-đoạn-4-tự-động-hóa-cicd-với-github-actions)
- [4. Các giới hạn kỹ thuật cần biết](#4-các-giới-hạn-kỹ-thuật-cần-biết)
- [5. Checklist vận hành & Bảo trì](#5-checklist-vận-hành--bảo-trì)
- [6. Giấy phép (License)](#6-giấy-phép-license)

---

## 1. Mô hình kiến trúc hệ thống

```text
                     [ Người dùng trên Internet ]
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
     │                   Điện thoại Android                    │
     │                                                         │
     │  ┌──────────────────┐        ┌───────────────────────┐  │
     │  │  Termux (Host)   │        │     Ubuntu PRoot      │  │
     │  │                  │        │                       │  │
     │  │  • Wake-lock     │───────▶│  • OpenSSH (:2222)    │◀─── [ Laptop Quản Trị ]
     │  │  • Termux:Boot   │        │  • Web Server (:8080) │     • SSH Terminal
     │  │  • Tailscale VPN │        │  • cloudflared agent  │     • DBeaver GUI
     │  │  • PostgreSQL    │        │                       │       (SSH Tunnel :5432)
     │  │    (:5432)       │        │                       │     qua Tailscale IP
     │  └──────────────────┘        └───────────────────────┘     (100.85.120.45)
     └─────────────────────────────────────────────────────────┘
```

---

## 2. Yêu cầu phần cứng & Chuẩn bị

### Phần cứng

- **Điện thoại**: Chạy Android 8.0 trở lên (khuyên dùng Android 10+), kiến trúc ARM64 (`aarch64`), RAM từ 2 GB (khuyên dùng 3–4 GB RAM trở lên).
- **Bộ nhớ trong**: Trống tối thiểu 8 – 16 GB.
- **Nguồn điện & Tản nhiệt**: Cắm sạc 5V ổn định, tắt tối ưu pin, để máy ở nơi thoáng mát.

### Phần mềm & Tài khoản

- **Termux** & **Termux:Boot** (Cài từ F-Droid hoặc GitHub Releases, **không** tải từ CH Play).
- Tài khoản miễn phí trên **Tailscale** (https://tailscale.com/).
- Một tên miền riêng đã trỏ Nameserver về **Cloudflare DNS** (ví dụ: `myserverdemo.net`).
- Tài khoản miễn phí trên **Cloudflare Zero Trust**.

---

## 3. Bảng thông số mẫu giả lập (Mock Data)

Tất cả câu lệnh trong tài liệu đều sử dụng bộ dữ liệu **mẫu ngẫu nhiên** dưới đây. Bạn có thể copy-paste trực tiếp để chạy thử hoặc thay bằng giá trị thực tế của bạn:

| Thông số                    | Giá trị mẫu giả lập                       | Ý nghĩa                                        |
| --------------------------- | ----------------------------------------- | ---------------------------------------------- |
| **Tên tài khoản Linux**     | `deploy`                                  | User quản trị thường trong Ubuntu (không root) |
| **Mật khẩu mẫu**            | `MySecretPass123`                         | Mật khẩu dùng đăng nhập SSH và lệnh `sudo`     |
| **Cổng SSH**                | `2222`                                    | Cổng dịch vụ OpenSSH bên trong Ubuntu PRoot    |
| **IP Tailscale điện thoại** | `100.85.120.XXX`                          | Địa chỉ IP ảo ngẫu nhiên do Tailscale cấp      |
| **IP Wi-Fi nội bộ**         | `192.168.1.XXX`                           | Địa chỉ IP mạng gia đình (dự phòng)            |
| **Tên miền riêng**          | `myserverdemo.net`                        | Tên miền quản lý trên Cloudflare               |
| **Subdomain website**       | `app.myserverdemo.net`                    | Tên miền con phục vụ trang web                 |
| **Cổng ứng dụng web**       | `8080`                                    | Cổng HTTP nội bộ của server                    |
| **Tên Tunnel Cloudflare**   | `pocket-vps`                              | Tên của tunnel kết nối                         |
| **Token Cloudflare**        | `eyJhIjoiMTIzNDVhYmNkZSI................` | Mã token kết nối mẫu                           |

---

## 📱 Giai đoạn 1: Khởi tạo nhanh trên điện thoại

_Các thao tác này bạn gõ trực tiếp trên màn hình điện thoại trong ứng dụng Termux._

### Bước 1: Cài đặt Termux và Ubuntu PRoot

1. Tải và cài **Termux** từ **[F-Droid](https://f-droid.org/packages/com.termux/)** hoặc **[GitHub Releases](https://github.com/termux/termux-app/releases)**.
2. Mở Termux và cập nhật các gói nền tảng:
   ```bash
   pkg update && pkg upgrade -y
   pkg install -y openssh proot-distro curl wget nano git
   ```
   > [!TIP]
   > **Cổng cứu hộ SSH Termux (Cổng 8022)**: Gói `openssh` ở trên cho phép bạn bật máy chủ SSH trực tiếp trên tầng nền Termux để làm cổng cứu hộ khẩn cấp từ máy tính. Xem hướng dẫn chi tiết tại: [Hướng Dẫn Cài Đặt & Kết Nối SSH Đến Termux Host](docs/vi/termux-ssh-guide.md).
3. Cài đặt Ubuntu ARM64:
   ```bash
   proot-distro install ubuntu
   ```
4. Đăng nhập vào Ubuntu:
   ```bash
   proot-distro login ubuntu
   ```

---

### Bước 2: Tạo User và Kích hoạt SSH Server

Khi đã ở trong dấu nhắc lệnh Ubuntu (`root@localhost:~#`):

1. **Cài đặt các gói công cụ và máy chủ SSH**:

   ```bash
   apt update && apt upgrade -y
   apt install -y openssh-server sudo iproute2 procps curl wget nano ca-certificates
   ```

2. **Tạo tài khoản quản trị thường (`deploy`) và cấp quyền `sudo` không hỏi mật khẩu**:

   ```bash
   adduser deploy
   # Nhập mật khẩu (ví dụ: MySecretPass123) và nhấn Enter qua các thông tin tùy chọn

   usermod -aG sudo deploy

   # Cấu hình sudo không hỏi mật khẩu (Bắt buộc để CI/CD và script tự động chạy ngầm không bị kẹt)
   echo "deploy ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/deploy
   chmod 0440 /etc/sudoers.d/deploy
   ```

3. **Cấu hình SSH lắng nghe trên cổng 2222**:

   ```bash
   nano /etc/ssh/sshd_config
   ```

   Thêm hoặc kiểm tra các dòng sau vào cuối file:

   ```text
   Port 2222
   PermitRootLogin no
   PasswordAuthentication yes
   ```

4. **Khởi động SSH service**:
   > [!NOTE]
   > Trong môi trường PRoot, thư mục `/run` nằm trên RAM ảo (tmpfs). Mỗi khi thoát PRoot, thư mục `/run/sshd` sẽ bị mất. Do đó, cần đảm bảo thư mục này luôn tồn tại trước khi khởi động SSH.

   ```bash
   mkdir -p /run/sshd && chmod 0755 /run/sshd
   service ssh start
   ```
   Kiểm tra cổng 2222 đang hoạt động:
   ```bash
   ss -lnt | grep 2222
   ```

---

## 🌐 Giai đoạn 2: Cài đặt Tailscale để kết nối từ xa an toàn

Tailscale tạo ra một mạng riêng ảo WireGuard (mesh VPN) mã hóa trực tiếp giữa máy tính và điện thoại của bạn, giúp SSH từ bất cứ đâu mà không cần cấu hình mở cổng modem.

### Bước 3.1: Cài đặt và kết nối Tailscale trên điện thoại

1. Cài đặt **Tailscale** trên Android từ [Google Play](https://play.google.com/store/apps/details?id=com.tailscale.ipn) hoặc [F-Droid](https://f-droid.org/packages/com.tailscale.ipn/).
2. Mở app và đăng nhập bằng tài khoản (Google, GitHub, Microsoft hoặc Apple).
3. Gạt công tắc sang **Active** (biểu tượng VPN xuất hiện trên thanh trạng thái).
4. Màn hình sẽ hiển thị địa chỉ IP bắt đầu bằng `100.x.y.z` (trong ví dụ này giả lập là `100.85.120.45`). Hãy ghi lại IP này.
5. **Cấu hình Pin**: Vào **Cài đặt Android** → **Ứng dụng** → **Tailscale** → **Pin** → chọn **Không hạn chế (Unrestricted)** để tránh Android tắt VPN khi chạy nền.

### Bước 3.2: Cài đặt và kết nối Tailscale trên máy tính/laptop

1. Cài đặt Tailscale trên máy tính của bạn:
   - **Ubuntu/Debian Linux**:
     ```bash
     curl -fsSL https://tailscale.com/install.sh | sh
     sudo tailscale up
     ```
   - **Windows / macOS**: Tải bộ cài từ [tailscale.com/download](https://tailscale.com/download) và đăng nhập.
2. Đăng nhập bằng **cùng tài khoản** đã dùng trên điện thoại.
3. Kiểm tra thông mạng bằng cách ping thử tới IP Tailscale của điện thoại:
   ```bash
   ping 100.85.120.45
   ```
   _Nếu nhận được phản hồi ping thành công, đường truyền đã thông suốt!_

> [!SUCCESS]
> **Đến đây bạn đã hoàn tất phần việc trên điện thoại!** Hãy cắm sạc cho máy, đặt máy lên bàn và chuyển sang sử dụng máy tính. Toàn bộ các bước tiếp theo đều thực hiện trên terminal máy tính.

---

## 💻 Giai đoạn 3: Cấu hình và Triển khai từ máy tính qua SSH

### Bước 4: Kết nối SSH vào điện thoại từ máy tính

Mở Terminal trên máy tính (Linux, macOS hoặc PowerShell trên Windows) và gõ lệnh với thông tin mẫu:

```bash
# Kết nối qua Tailscale (Dù ở nhà hay ra ngoài đều dùng được)
ssh -p 2222 deploy@100.85.120.45
```

Nhập mật khẩu (`MySecretPass123`). Bạn đã đăng nhập thành công vào Ubuntu trên điện thoại!

_(Cách dự phòng: Nếu cả hai máy cùng ở một mạng Wi-Fi gia đình, bạn cũng có thể SSH qua IP LAN, ví dụ: `ssh -p 2222 deploy@192.168.1.120`)._

#### Tùy chọn: Đăng nhập bằng SSH Key (Không cần gõ mật khẩu)

Từ terminal máy tính:

```bash
ssh-copy-id -p 2222 deploy@100.85.120.45
```

Sau đó bạn có thể sửa `/etc/ssh/sshd_config` thành `PasswordAuthentication no` để bảo mật tối đa.

---

### Bước 5: Triển khai Web Server (Python / Node.js)

#### Cách A: Chạy Python Web Server (Thử nghiệm nhanh)

1. Tạo thư mục chứa web và log:

   ```bash
   mkdir -p ~/projects/website ~/logs
   cd ~/projects/website
   ```

2. Tạo trang `index.html` mẫu:

   ```bash
   cat << 'EOF' > index.html
   <!DOCTYPE html>
   <html lang="vi">
   <head>
     <meta charset="UTF-8">
     <meta name="viewport" content="width=device-width, initial-scale=1">
     <title>Pocket Linux Server</title>
     <style>
       body { font-family: system-ui, sans-serif; display: flex; align-items: center; justify-content: center; height: 90vh; margin: 0; background: #0f172a; color: #f8fafc; text-align: center; }
       .card { background: #1e293b; padding: 2.5rem 3.5rem; border-radius: 1rem; border: 1px solid #334155; box-shadow: 0 10px 25px rgba(0,0,0,0.5); }
       h1 { color: #38bdf8; margin-bottom: 0.5rem; }
       p { color: #94a3b8; }
       .badge { display: inline-block; background: #0284c7; color: white; padding: 0.25rem 0.75rem; border-radius: 9999px; font-size: 0.875rem; }
     </style>
   </head>
   <body>
     <div class="card">
       <div class="badge">Online</div>
       <h1>📱 Máy Chủ Android Mini</h1>
       <p>Quản lý qua SSH từ PC • Termux + Ubuntu PRoot + Cloudflare Tunnel.</p>
     </div>
   </body>
   </html>
   EOF
   ```

3. Khởi chạy web server ngầm cổng `8080`:

   ```bash
   nohup python3 -m http.server 8080 --bind 0.0.0.0 > ~/logs/website.log 2>&1 < /dev/null &
   ```

4. Kiểm tra phản hồi HTTP ngay trên máy:
   ```bash
   curl -I http://127.0.0.1:8080
   ```
   _Kết quả mong đợi: `HTTP/1.0 200 OK`_

---

#### Cách B: Chạy ứng dụng Node.js / Vite

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

### Bước 5.1: Cài đặt Cơ sở Dữ liệu PostgreSQL (Native Android)

> [!TIP]
> 📖 Để xem cẩm nang quản trị toàn diện, mẹo tối ưu và xử lý lỗi sâu, vui lòng đọc tài liệu riêng: [Hướng Dẫn Cài Đặt PostgreSQL & Quản Trị Bằng DBeaver](docs/vi/dbeaver-database-guide.md).

Để tránh tình trạng treo đơ máy (deadlock) do nhân Android chặn các hàm thăm dò bộ nhớ sâu (`SysV IPC`) của PostgreSQL bên trong Ubuntu PRoot, giải pháp chuẩn hóa là cài đặt **PostgreSQL Native ngay trên Termux Host**:

1. Tại màn hình chính của Termux (dấu nhắc `~$`, chưa login Ubuntu):
   ```bash
   pkg install postgresql -y
   mkdir -p $PREFIX/var/lib/postgresql
   initdb $PREFIX/var/lib/postgresql
   pg_ctl -D $PREFIX/var/lib/postgresql -l logfile start
   ```

2. Đặt mật khẩu cho user quản trị `postgres` và khởi tạo database dự án:
   ```bash
   psql -d postgres
   ```
   Trong giao diện `postgres=#`:
   ```sql
   ALTER USER postgres WITH PASSWORD '123123';
   CREATE DATABASE myapp_db;
   \q
   ```
   *(PostgreSQL sẽ lắng nghe tại `localhost:5432`, dùng chung hoàn toàn với ứng dụng chạy trong Ubuntu PRoot).*

---

### Bước 5.2: Quản trị Database bằng DBeaver qua SSH Tunnel

Để quản trị trực quan cơ sở dữ liệu từ máy tính mà **không cần mở cổng 5432 ra Internet**:

1. Mở phần mềm [DBeaver Community](https://dbeaver.io/) trên máy tính → Nhấn **New Database Connection** → Chọn **PostgreSQL** → Nhấn **Next**.
2. **Cấu hình Tab `Main` (Thông tin Database)**:
   * **Host**: `localhost` *(Bắt buộc điền localhost vì kết nối được gọi từ điểm cuối SSH Tunnel trên điện thoại)*.
   * **Port**: `5432`
   * **Database**: `myapp_db` *(hoặc `postgres`)*
   * **Username**: `postgres`
   * **Password**: `123123` *(mật khẩu bạn đã đặt ở Bước 5.1)*
3. **Cấu hình Tab `SSH` (Đường hầm bảo mật qua Tailscale)**:
   * Tích chọn ô: **`[x] Use SSH Tunnel`**
   * **Host/IP**: `100.94.18.108` *(Địa chỉ IP Tailscale của điện thoại)*
   * **Port**: `2222` *(Cổng SSH của Ubuntu PRoot)*
   * **User Name**: `deploy` *(Tài khoản người dùng Ubuntu)*
   * **Authentication Method**: Chọn **Password** (nhập mật khẩu user `deploy`) hoặc **Public Key**.
4. **Kiểm tra kết nối**: Nhấn **Test Connection** (nếu thiếu Driver PostgreSQL, bấm *Download*). Khi xuất hiện tích xanh **Connected** → Nhấn **Finish**. Giờ đây bạn có thể xem bảng, sửa dữ liệu và chạy query trực quan bằng chuột.

---

### Bước 6: Public Website ra Internet với Cloudflare Tunnel

Cloudflare Tunnel giúp kết nối trang web nội bộ ra ngoài Internet an toàn mà không làm lộ địa chỉ IP thật của bạn.

#### 6.1. Tạo Tunnel và chọn môi trường (OS & Architecture) trên Cloudflare Dashboard

1. Trên trình duyệt máy tính, truy cập [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/).
2. Điều hướng vào menu bên trái: **Networks** (hoặc **Networking**) → **Tunnels**.
3. Nhấn **Add a tunnel** → chọn loại connector là **Cloudflared** → nhấn **Next**.
4. Đặt tên gợi nhớ cho tunnel: ví dụ `pocket-vps` → nhấn **Save tunnel**.
5. Màn hình tiếp theo là **"Setup Environment"**, bạn cần chọn chính xác hai thông số môi trường của điện thoại:
   - **Choose your operating system (Chọn hệ điều hành)**: Chọn thẻ **Debian** (hoặc **Linux**).
     > _Giải thích_: Môi trường Ubuntu PRoot trên điện thoại là bản phân phối phát triển từ Debian, nên việc chọn **Debian** sẽ cung cấp gói cài đặt `.deb` tương thích chuẩn xác nhất.
   - **Choose your architecture (Chọn kiến trúc vi xử lý)**: Chọn thẻ **arm64** (hoặc **arm64-bit**).
     > _Giải thích_: Hầu hết điện thoại Android hiện nay đều sử dụng vi xử lý 64-bit ARM (`aarch64` / `arm64`). **Tuyệt đối không chọn** `64-bit (x86_64)` hoặc `32-bit (x86)` vì đó là kiến trúc của máy tính Intel/AMD, không thể chạy trên chip điện thoại.
6. Khi chọn đúng **Debian** và **arm64**, Cloudflare sẽ tự động tạo sẵn một đoạn mã cài đặt mẫu bên dưới mục **"If you do not have cloudflared installed"**.

#### 6.2. Chạy lệnh cài đặt từ Cloudflare và xử lý các lỗi thiếu gói ("command not found")

Cloudflare sẽ cung cấp một khối lệnh hoàn chỉnh tương tự như sau:

```bash
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb && sudo dpkg -i cloudflared.deb && sudo cloudflared service install eyJhIjoiMTIzNDVhYmNkZSIsInQiOiJkZW1vLXV1aWQiLCJzIjoiZXhhbXBsZSJ9
```

> [!NOTE]
> Chuỗi token `eyJh...` ở trên chỉ là dữ liệu mẫu giả lập. Bạn hãy copy nguyên đoạn mã chứa chuỗi token thực tế hiển thị trên màn hình Cloudflare của bạn.

Copy toàn bộ khối lệnh trên và dán vào terminal SSH trên máy tính. Vì môi trường Ubuntu PRoot ban đầu là bản tối giản (minimal), bạn có thể gặp một số lỗi báo thiếu gói lệnh (`command not found`). Dưới đây là cách xử lý từng trường hợp:

- **Lỗi 1: `bash: sudo: command not found`**
  - _Nguyên nhân_: Môi trường PRoot chưa có gói phân quyền `sudo`, hoặc bạn đang thao tác trực tiếp bằng user `root` (vốn không cần dùng `sudo`).
  - _Cách xử lý_: Cài đặt gói `sudo` bằng lệnh:
    ```bash
    apt update && apt install -y sudo
    ```
    Sau đó chạy lại câu lệnh của Cloudflare. Nếu bạn đang ở quyền `root`, bạn chỉ cần xóa bỏ các chữ `sudo` trong câu lệnh.

- **Lỗi 2: `bash: curl: command not found`**
  - _Nguyên nhân_: Chưa cài công cụ tải dữ liệu qua mạng `curl`.
  - _Cách xử lý_:
    ```bash
    apt update && apt install -y curl
    ```

- **Lỗi 3: Báo lỗi chứng chỉ bảo mật SSL (`certificate verification failed`) hoặc thiếu `ca-certificates`/`wget`**
  - _Cách xử lý_:
    ```bash
    apt install -y ca-certificates wget
    ```

> [!TIP]
> **Mẹo chuẩn bị trước**: Để tránh gặp bất kỳ lỗi thiếu package nào, bạn nên cài đặt trước tất cả các gói phụ thuộc cần thiết bằng một lệnh duy nhất:
>
> ```bash
> sudo apt update && sudo apt install -y curl wget sudo ca-certificates iproute2 procps
> ```

#### 6.3. Khởi chạy Connector và xử lý hạn chế Service trong PRoot

Phần cuối câu lệnh do Cloudflare sinh ra là `sudo cloudflared service install <TOKEN>`. Lệnh này sẽ cố gắng đăng ký `cloudflared` làm một dịch vụ chạy ngầm của hệ điều hành.

Tuy nhiên, trong môi trường Ubuntu PRoot, hệ thống **không có tiến trình `systemd` thực thụ** (PID 1 không phải systemd). Do đó, bạn xử lý theo 2 trường hợp sau:

1. **Trường hợp lệnh `service install` đã tạo thành công SysV init script**:
   Kiểm tra tình trạng service:

   ```bash
   service cloudflared status
   ```

   Nếu service đang dừng, hãy kích hoạt bằng:

   ```bash
   sudo service cloudflared start
   ```

2. **Trường hợp báo lỗi systemd hoặc service không tự chạy (Giải pháp khuyên dùng - Cực kỳ ổn định trên PRoot)**:

   Lưu token vào file cấu hình an toàn:
   ```bash
   mkdir -p ~/.cloudflared ~/logs

   # Tạo file lưu token (Dùng nano hoặc echo chuỗi token vào file)
   nano ~/.cloudflared/token
   # Dán chuỗi token thật của bạn (ví dụ eyJh...) -> Ctrl+O -> Enter -> Ctrl+X
   chmod 600 ~/.cloudflared/token
   ```

   Tạo script khởi chạy độc lập `~/start-tunnel.sh` với cơ chế khóa PID chống chạy trùng:
   ```bash
   nano ~/start-tunnel.sh
   ```

   Dán nội dung script sau:
   ```bash
   #!/bin/bash
   # Nếu cloudflared đã đang chạy rồi thì THOÁT NGAY LẬP TỨC
   if pidof cloudflared > /dev/null 2>&1; then
       exit 0
   fi

   TOKEN=$(cat ~/.cloudflared/token 2>/dev/null | tr -d '\r\n')
   if [ -n "$TOKEN" ]; then
       nohup cloudflared tunnel run --token "$TOKEN" > ~/logs/cloudflared.log 2>&1 &
   fi
   ```

   Cấp quyền thực thi và khởi chạy:
   ```bash
   chmod +x ~/start-tunnel.sh
   ~/start-tunnel.sh
   ```

Kiểm tra xem tiến trình `cloudflared` đã hoạt động chưa:

```bash
pgrep -af cloudflared
# Hoặc kiểm tra chi tiết:
ps -C cloudflared -o pid,user,cmd
```

_Khi thấy tiến trình xuất hiện, nhìn lại màn hình Cloudflare Dashboard bạn sẽ thấy biểu tượng trạng thái tunnel chuyển sang màu xanh lá cây (**Healthy**)._

#### 6.4. Định tuyến Public Hostname trên Dashboard

1. Trên Cloudflare Dashboard, mở tab **Public Hostnames** của tunnel `pocket-vps`.
2. Nhấn **Add a public hostname**.
3. Điền thông tin:
   - **Subdomain**: `app`
   - **Domain**: `myserverdemo.net`
   - **Type**: `HTTP`
   - **URL**: `127.0.0.1:8080`
4. Bấm **Save hostname**.
5. Mở trình duyệt trên điện thoại hoặc máy tính (dùng mạng 4G) truy cập:
   ```text
   https://app.myserverdemo.net
   ```

---

### Bước 7: Tự khởi động dịch vụ (Termux Login & Phone Reboot)

> [!TIP]
> 📖 Để xem cẩm nang tự phục hồi toàn diện từ phần cứng Android đến Ubuntu PRoot, Redis, PostgreSQL và PM2, vui lòng xem: [Hướng Dẫn Tự Khởi Động Dịch Vụ Khi Điện Thoại Reboot](docs/vi/autostart-services-guide.md).

Để hệ thống thực sự trở thành một "mini VPS" hoạt động tự động 24/7, cấu hình khởi động dịch vụ theo 2 cấp độ:

#### 1. Cấu hình tự khởi động khi mở Ubuntu trên Termux (`~/.bashrc`)

Mỗi khi bạn mở Termux trên điện thoại và đăng nhập vào Ubuntu (`proot-distro login ubuntu --user deploy`), hệ thống sẽ tự động kích hoạt OpenSSH Server và Cloudflare Tunnel.

> [!IMPORTANT]
> **Quy tắc phân biệt SSH Session vs Local Session**:
> Khi bạn ngồi máy tính SSH vào điều khiển, hệ thống **tuyệt đối không được chạy lại các lệnh khởi động này** (tránh chạy đè tiến trình và làm chậm phiên gõ lệnh). Chúng ta sử dụng biến môi trường `$SSH_CLIENT` để kiểm tra.
> Ngoài ra, **tuyệt đối KHÔNG đặt lệnh chạy dịch vụ vào `~/.profile`** vì `~/.profile` là Login Shell, sẽ tự động thực thi mỗi khi máy tính SSH vào.

Mở file `~/.bashrc`:
```bash
nano ~/.bashrc
```

Thêm khối lệnh sau vào **cuối cùng của file**:
```bash
# Chỉ tự động bật SSH và Cloudflare khi mở trực tiếp từ Termux trên điện thoại
# Tuyệt đối KHÔNG chạy khi máy tính SSH vào điều khiển
if [ -z "$SSH_CLIENT" ] && [ -z "$SSH_CONNECTION" ]; then
    sudo mkdir -p /run/sshd
    sudo chmod 0755 /run/sshd
    sudo service ssh status > /dev/null 2>&1 || sudo service ssh start
    ~/start-tunnel.sh
fi
```
Lưu lại: `Ctrl + O` -> `Enter` -> `Ctrl + X`.

#### 2. Cấu hình Termux:Boot (Tự chạy khi điện thoại khởi động lại)

Để dịch vụ tự bật lại mà không cần bạn phải chạm vào điện thoại sau khi máy hết pin hoặc khởi động lại:

1. Cài app **Termux:Boot** từ F-Droid và mở app một lần.
2. Tạo script boot trong Termux (xem file mẫu [`scripts/boot-termux.sh`](scripts/boot-termux.sh)):
   ```bash
   mkdir -p ~/.termux/boot
   nano ~/.termux/boot/start-server.sh
   ```
   Dán nội dung:
   ```bash
   #!/data/data/com.termux/files/usr/bin/bash
   termux-wake-lock
   sleep 15
   proot-distro login ubuntu -- su - deploy -c "/home/deploy/scripts/start-services.sh"
   ```
3. Cấp quyền thực thi:
   ```bash
   chmod +x ~/.termux/boot/start-server.sh
   ```

#### 3. Cấu hình Script quản lý dịch vụ tổng hợp trong Ubuntu

Tại phiên SSH, tạo thư mục script:

```bash
mkdir -p ~/scripts
nano ~/scripts/start-services.sh
# Dán nội dung từ scripts/start-services.sh trong repo này
chmod +x ~/scripts/start-services.sh
```

---

### Bước 8: Quản lý tiến trình, xem Log và Script tự động

Sử dụng script đi kèm dự án [`scripts/start-services.sh`](scripts/start-services.sh) hoặc lệnh trực tiếp:

```bash
# Kiểm tra tình trạng tất cả dịch vụ (SSH, Web, Cloudflare)
~/scripts/start-services.sh status

# Khởi động lại toàn bộ dịch vụ
~/scripts/start-services.sh restart

# Xem 50 dòng log mới nhất của website
tail -n 50 ~/logs/website.log

# Xem trực tiếp log theo thời gian thực
tail -f ~/logs/website.log

# Xem log tunnel
tail -n 50 ~/logs/cloudflared.log
```

---

## 🚀 Giai đoạn 4: Tự động hóa CI/CD với GitHub Actions

Sau khi hoàn thành cài đặt máy chủ và cơ sở dữ liệu, bạn có thể thiết lập quy trình **CI/CD hoàn toàn tự động (chi phí 0đ)**:
Mỗi khi bạn gõ `git push origin main` trên máy tính, GitHub Actions sẽ tự động:
1. Kết nối vào mạng riêng ảo **Tailscale** của bạn.
2. SSH vào VPS Android, kéo code mới (`git pull`).
3. Cài đặt thư viện và **tự động chạy Database Migration** (Prisma / Alembic / Django) trên PostgreSQL cục bộ (`localhost:5432`).
4. Khởi động lại ứng dụng qua **PM2** mà không gây gián đoạn (Zero-downtime).

📖 **Các tài liệu chuyên sâu dành cho nhà phát triển:**
* 👉 [**Hướng Dẫn Tự Khởi Động Dịch Vụ Khi Điện Thoại Reboot (Cold Boot)**](docs/vi/autostart-services-guide.md) *(Bản tiếng Anh: [English Version](docs/en/autostart-services-guide.md))*
* 👉 [**Hướng Dẫn Cài Đặt & Kết Nối SSH Đến Termux Host (Cổng 8022)**](docs/vi/termux-ssh-guide.md) *(Bản tiếng Anh: [English Version](docs/en/termux-ssh-guide.md))*
* 👉 [**Hướng Dẫn Chi Tiết CI/CD GitHub Actions & Tailscale Cho Android VPS**](docs/vi/cicd-github-actions.md) *(Bản tiếng Anh: [English Version](docs/en/cicd-github-actions.md))*
* 👉 [**Hướng Dẫn Quản Lý Nhiều Dự Án Backend & CI/CD Độc Lập**](docs/vi/multi-backend-management.md) *(Bản tiếng Anh: [English Version](docs/en/multi-backend-management.md))*
* 👉 [**Hướng Dẫn Cài Đặt PostgreSQL & Quản Trị Bằng DBeaver**](docs/vi/dbeaver-database-guide.md) *(Bản tiếng Anh: [English Version](docs/en/dbeaver-database-guide.md))*

*(File workflow mẫu có sẵn tại: [`.github/workflows/deploy.yml.example`](.github/workflows/deploy.yml.example))*.

---

## 4. Các giới hạn kỹ thuật & Cẩm nang xử lý sự cố thực tế

### 4.1. Các giới hạn kỹ thuật cần biết

- **Không có Docker native**: PRoot chạy trên tầng người dùng bằng `ptrace`. Không hỗ trợ namespaces và cgroups của Linux kernel để chạy Docker container hoàn chỉnh.
- **Không có `systemd`**: Hãy sử dụng script shell `service ssh start` hoặc các process manager nhẹ như PM2 / supervisord.
- **Bảo vệ pin**: Hãy bật các tính năng bảo vệ pin của máy (như sạc tới 80% dừng) nếu cắm nguồn 24/7.
- **Thư mục `/run` là tmpfs**: Mỗi khi thoát PRoot, `/run/sshd` sẽ bị xóa. Luôn cần `mkdir -p /run/sshd` trước khi chạy `service ssh start`.

### 4.2. Cẩm nang xử lý sự cố thực tế (Troubleshooting FAQ)

#### 1. Hiện tượng "tiến trình trùng lặp" trong bảng `top`
* **Triệu chứng**: Gõ `top` thấy xuất hiện 2 dòng `sshd-session` và 3-5 dòng `cloudflared`.
* **Giải thích**:
  - `sshd-session` (2 dòng): Hoàn toàn bình thường! Đây là cơ chế **Privilege Separation** của OpenSSH (1 tiến trình giải mã mạng, 1 tiến trình quản lý shell người dùng).
  - `cloudflared` (nhiều dòng): Bản thân `cloudflared` viết bằng Golang đa luồng. Lệnh `top` mặc định hiển thị cả các luồng con (Threads).
* **Cách xử lý**:
  - Trong `top`, bấm **`Shift + H`** để tắt/bật chế độ xem thread (sẽ gom các luồng con lại thành 1 dòng).
  - Dùng lệnh `ps -C cloudflared -o pid,user,cmd` để xem tiến trình chính xác.
  - Nếu thực sự có 2 tiến trình khác PID chạy đè nhau, tắt hết bằng: `killall cloudflared || pkill -9 cloudflared`.

#### 2. Lỗi bàn phím di động: `Exit 127 󰛉token` hoặc `syntax error near unexpected token 'newline'`
* **Nguyên nhân**: Bàn phím ảo trên điện thoại (Gboard, Laban Key) tự động sửa dấu hai gạch ngang `--token` thành gạch ngang dài `–` hoặc ký tự đặc biệt Unicode. Đồng thời lệnh copy-paste dài bị vỡ dòng khi dán vào Termux.
* **Cách xử lý**:
  - Ưu tiên dùng `nano` để chỉnh sửa file thay vì dán các câu lệnh heredoc (`cat << 'EOF'`) quá dài.
  - Sử dụng Terminal máy tính SSH vào điện thoại để cấu hình, bàn phím máy tính không bao giờ bị dính lỗi tự sửa ký tự.

#### 3. Lỗi SSH báo `[ OK ]` nhưng kiểm tra `service ssh status` báo `sshd is not running`
* **Nguyên nhân**: Thiếu thư mục phân quyền `/run/sshd`.
* **Cách xử lý**: Chạy lệnh:
  ```bash
  sudo mkdir -p /run/sshd && sudo chmod 0755 /run/sshd && sudo service ssh restart
  ```

#### 4. Lệnh dọn sạch toàn bộ (Clean Reset) khi cấu hình bị rối
Nếu trong quá trình cài đặt bạn lỡ thêm lệnh vào nhiều file khiến tiến trình bị chạy đè hoặc báo lỗi `start-tunnel.sh: No such file or directory`, hãy chạy bộ lệnh dọn dẹp sau:
```bash
# 1. Dập tắt toàn bộ cloudflared
pkill -9 cloudflared

# 2. Xóa sạch các dòng tự chạy cũ trong .profile và .bashrc
sed -i '/cloudflared/d; /start-tunnel/d; /token/d; /sshd/d' ~/.profile
sed -i '/cloudflared/d; /start-tunnel/d; /token/d; /sshd/d; /SSH_CLIENT/d; /SSH_CONNECTION/d' ~/.bashrc

# 3. Xóa log rác
rm -f ~/nohup.out ~/logs/cloudflared.log ~/cloudflared.log
```

---

## 5. Checklist vận hành & Bảo trì

- [ ] Điện thoại đã cắm sạc và tắt tối ưu hóa pin cho Termux và Tailscale.
- [ ] Tailscale hoạt động trên cả 2 máy, lệnh ping tới `100.85.120.45` phản hồi tốt.
- [ ] SSH kết nối ổn định từ máy tính: `ssh -p 2222 deploy@100.85.120.45`.
- [ ] Web application phản hồi cục bộ: `curl -I http://127.0.0.1:8080`.
- [ ] Cloudflare Zero Trust Dashboard báo tunnel trạng thái `Healthy`.
- [ ] Tên miền `https://app.myserverdemo.net` truy cập được từ mạng ngoài.
- [ ] Đã reboot thử điện thoại và xác nhận các dịch vụ tự động hoạt động trở lại.

---

## 6. Giấy phép (License)

Dự án này được phân phối theo giấy phép mã nguồn mở [MIT License](LICENSE).
