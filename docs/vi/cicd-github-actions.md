# Hướng Dẫn Tự Động Hóa CI/CD với GitHub Actions & Tailscale Cho Android VPS

[**[🇬🇧 Read English Version](../en/cicd-github-actions.md)** • **[🏠 Trang chủ](../../README.vi.md)**]

Tài liệu này hướng dẫn chi tiết cách thiết lập một đường ống (pipeline) **CI/CD tự động hóa 100% với chi phí 0đ** bằng cách kết hợp **GitHub Actions**, **Tailscale**, và **máy chủ Android Ubuntu (PRoot)**.

Mỗi khi bạn gõ `git push origin main` trên máy tính:
1. **GitHub Actions** tự động khởi chạy máy ảo trên mây.
2. Máy ảo kết nối an toàn vào mạng riêng ảo **Tailscale (Tailnet)** của bạn.
3. SSH trực tiếp vào điện thoại Android qua IP Tailscale riêng tư (`100.x.y.z:2222`).
4. Kéo code mới nhất (`git pull`), cài đặt thư viện (`npm install` / `pip install`).
5. **🎯 Tự động chạy Database Migration** cập nhật schema trên PostgreSQL cục bộ (`localhost:5432`).
6. Khởi động lại dịch vụ qua **PM2** mà không làm gián đoạn người dùng (Zero-downtime).
7. Website được cập nhật ngay lập tức ra Internet qua **Cloudflare Tunnel**.

---

## 📑 Mục lục

1. [Mô hình kiến trúc hoạt động](#1-mô-hình-kiến-trúc-hoạt-động)
2. [Hồ sơ kỹ thuật và Đặc tả môi trường VPS](#2-hồ-sơ-kỹ-thuật-và-đặc-tả-môi-trường-vps-vps-specifications--profile)
3. [Các yêu cầu cần chuẩn bị](#3-các-yêu-cầu-cần-chuẩn-bị)
4. [Bước 1: Cấu hình VPS trên điện thoại sẵn sàng đón nhận CI/CD](#bước-1-cấu-hình-vps-trên-điện-thoại-sẵn-sàng-đón-nhận-cicd)
5. [Bước 2: Tạo Ephemeral Auth Key trên Tailscale](#bước-2-tạo-ephemeral-auth-key-trên-tailscale)
6. [Bước 3: Tạo SSH Key riêng cho GitHub Actions](#bước-3-tạo-ssh-key-riêng-cho-github-actions)
7. [Bước 4: Cấu hình Secrets trên GitHub Repository](#bước-4-cấu-hình-secrets-trên-github-repository)
8. [Bước 5: Tạo file GitHub Actions Workflow](#bước-5-tạo-file-github-actions-workflow)
9. [Bước 6: Thử nghiệm thực tế và theo dõi Pipeline](#bước-6-thử-nghiệm-thực-tế-và-theo-dõi-pipeline)
10. [Cẩm nang tối ưu hóa và Xử lý sự cố (Troubleshooting)](#cẩm-nang-tối-ưu-hóa-và-xử-lý-sự-cố-troubleshooting)

---

## 1. Mô hình kiến trúc hoạt động

```mermaid
flowchart TD
    Dev["💻 Developer (Máy tính)"] -->|"git push origin main"| GH["🐙 GitHub Repository"]
    
    subgraph GHA ["☁️ GitHub Actions Runner (Ubuntu VM)"]
        A1["1. Checkout Code"] --> A2["2. tailscale/github-action\n(Gia nhập Tailnet bằng Auth Key)"]
        A2 --> A3["3. appleboy/ssh-action\n(Kết nối SSH qua Tailscale IP)"]
    end
    
    GH -->|"Kích hoạt Workflow"| GHA
    
    subgraph Phone ["📱 Máy chủ Android (VPS)"]
        subgraph TailscaleNet ["Mạng riêng ảo Tailscale (:2222)"]
            S1["Git Pull Code Mới"] --> S2["Cài Dependency (npm/pip)"]
            S2 --> S3["🎯 Database Migration\n(Prisma / Alembic / Django)"]
            S3 --> S4["Khởi động lại App qua PM2"]
        end
        
        DB[("🐘 PostgreSQL\n(localhost:5432)")]
        S3 <-->|"Cập nhật Schema"| DB
        
        CF["☁️ Cloudflare Tunnel\n(cloudflared)"]
        S4 <-->|"localhost:8080 / 5173"| CF
    end

    A3 -->|"SSH qua 100.x.y.z:2222"| TailscaleNet
    CF -->|"Public HTTPS"| Internet["🌐 Người dùng Internet\n(https://app.yourdomain.com)"]
```

---

## 2. Hồ sơ kỹ thuật và Đặc tả môi trường VPS (VPS Specifications & Profile)

Để đường ống CI/CD hoạt động ổn định và chính xác, hệ thống máy chủ cá nhân được chuẩn hóa theo hồ sơ thiết bị và kiến trúc 2 tầng dưới đây:

### 2.1. Cấu hình phần cứng (Hardware Specifications)

| Thông số | Giá trị thực tế | Ý nghĩa đối với CI/CD |
| :--- | :--- | :--- |
| **Thiết bị** | Sony Xperia Ace II (`SO-41B`) | Điện thoại Android nhỏ gọn, tiết kiệm điện năng 24/7 |
| **Vi xử lý (SoC)** | MediaTek Helio P35 (MT6765) | 8 nhân ARM Cortex-A53 (4x 2.3 GHz + 4x 1.8 GHz) |
| **Kiến trúc CPU** | `arm64` (`aarch64`) | Các package/binary tải về trong CI/CD phải tương thích kiến trúc ARM64 |
| **Bộ nhớ RAM** | 4 GB LPDDR4X (Khả dụng ~3.8 GB) | Đủ sức chạy đồng thời OS, Postgres, Cloudflare và 3-5 ứng dụng backend |
| **Bộ nhớ trong** | 64 GB eMMC 5.1 | Dung lượng lưu trữ thoải mái cho hệ điều hành, database và source code |
| **Nguồn điện & Pin** | Cắm sạc 24/7 (Bật Battery Care) | Tính năng chăm sóc pin của Sony giúp giới hạn sạc ở 80-90%, chống chai phồng pin |

### 2.2. Kiến trúc 2 tầng độc đáo (Dual-layer Architecture)

Hệ thống được thiết kế phân tầng rõ ràng giữa **Termux Host** và **Ubuntu Guest (PRoot)** nhằm đạt hiệu năng cao nhất và khả năng phục hồi tự động:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   HỆ ĐIỀU HÀNH ANDROID (THIẾT BỊ VẬT LÝ)               │
│                                                                        │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ 🟢 TẦNG 1: TERMUX HOST (NATIVE BIONIC ARM64)                     │  │
│  │                                                                  │  │
│  │  • PostgreSQL Server (:5432) - Chạy Native, siêu nhẹ (~30MB RAM) │  │
│  │  • OpenSSH Server (:8022) - Cổng cứu hộ Android khẩn cấp         │  │
│  │  • Termux:Boot - Tự kích hoạt dịch vụ khi Android lên nguồn      │  │
│  │  • Tailscale Android (Always-on VPN) - Kết nối mạng riêng ảo     │  │
│  └──────────────────────────────────┬───────────────────────────────┘  │
│                                     │ (Mount rootfs & Loopback)        │
│  ┌──────────────────────────────────▼───────────────────────────────┐  │
│  │ 🔵 TẦNG 2: UBUNTU PROOT (GUEST LINUX CONTAINER)                  │  │
│  │                                                                  │  │
│  │  • User: deploy (quyền NOPASSWD:ALL trong sudoers)               │  │
│  │  • OpenSSH Server (:2222) - Cổng tiếp nhận CI/CD & Quản trị      │  │
│  │  • PM2 Process Manager - Quản lý tiến trình ứng dụng Web/API     │  │
│  │  • Cloudflare Tunnel (cloudflared) - Định tuyến tên miền Public  │  │
│  │  • Kết nối Database: Truy cập thẳng localhost:5432 ở Tầng 1      │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

### 2.3. Bảng phân bổ cổng mạng và dịch vụ (Port & Service Mapping)

| Cổng | Giao thức | Vị trí chạy | Dịch vụ | Mục đích sử dụng trong CI/CD |
| :---: | :---: | :--- | :--- | :--- |
| **`2222`** | TCP / SSH | Ubuntu PRoot | OpenSSH Server (User: `deploy`) | **Cổng chính**: GitHub Actions SSH vào để thực thi deploy & migration |
| **`8022`** | TCP / SSH | Termux Native | OpenSSH Server (User: Termux) | **Cổng cứu hộ**: SSH quản trị cấp thấp Termux nếu Ubuntu bị lỗi |
| **`5432`** | TCP | Termux Native | PostgreSQL Server | **Cơ sở dữ liệu**: Chạy migration và lưu trữ dữ liệu ứng dụng (xem [Hướng dẫn DBeaver](dbeaver-database-guide.md)) |
| **`6379`** | TCP | Ubuntu PRoot | Redis Server (`redis-server`) | **Hàng đợi & Cache**: Phục vụ BullMQ xử lý Mail Queue, Audit Log, Job Queue |
| **`3000` / `8080`** | TCP / HTTP | Ubuntu PRoot | Backend App (PM2) | Cổng lắng nghe API Node.js (NestJS / Express) |
| **Internet** | HTTPS | Cloudflare Edge | Cloudflare Tunnel | Public domain `https://app.yourdomain.com` trỏ ingress về cổng backend |

### 2.4. Các đặc thù quan trọng cần lưu ý khi xây dựng CI/CD

1. **Không sử dụng Docker bên trong VPS Android:**
   * Môi trường PRoot chạy trên tầng người dùng (`ptrace`), không có quyền can thiệp vào kernel cgroups/namespaces của Android để chạy Docker daemon.
   * **Chiến lược CI/CD**: Các bước test/lint nặng hoặc build image Docker (nếu cần) sẽ thực hiện trực tiếp trên GitHub Runner mây (vốn có 4 vCPU và 16GB RAM miễn phí), sau đó chỉ đẩy mã nguồn hoặc artifact nhẹ về VPS để chạy trực tiếp qua **PM2**.
2. **Cơ chế cách ly phiên làm việc (`$SSH_CLIENT` Guard):**
   * Trong file `~/.bashrc` của cả Termux và Ubuntu đã được thiết lập điều kiện chặn biến `$SSH_CLIENT`. Mỗi khi GitHub Actions mở kết nối SSH vào VPS, terminal sẽ mở ngay lập tức trong 0.1 giây mà **không chạy lại các script khởi động**, giúp pipeline chạy mượt mà và không sinh ra tiến trình trùng lặp.
3. **Cơ chế phục hồi tự động khi mất điện / sập nguồn:**
   * Khi điện thoại có pin lại và khởi động lên nguồn: Tính năng **Always-on VPN** của Tailscale tự kết nối lại IP, **Termux:Boot** tự động kích hoạt PostgreSQL, SSH và Cloudflare Tunnel trong 30 giây. Đường ống CI/CD có thể tiếp tục deploy bình thường mà không cần bất kỳ thao tác thủ công nào.

---

## 3. Các yêu cầu cần chuẩn bị

* Điện thoại Android đã hoàn thành cài đặt theo hướng dẫn gốc:
  * Đang chạy **Ubuntu PRoot** với tài khoản `deploy` (đã có quyền `NOPASSWD:ALL`).
  * **OpenSSH Server** đang chạy trên cổng `2222`.
  * **Tailscale** đang hoạt động và có IP (ví dụ: `100.94.18.108`).
  * **Cloudflare Tunnel** đang trỏ tới cổng ứng dụng của bạn.
* Một tài khoản **GitHub** và một repository chứa mã nguồn backend/fullstack của bạn.
* Trình quản lý tiến trình **PM2** trên VPS điện thoại.

---

## Bước 1: Cấu hình VPS trên điện thoại sẵn sàng đón nhận CI/CD

SSH vào VPS trên điện thoại từ máy tính:
```bash
ssh -p 2222 deploy@100.94.18.108
```

### 1. Cài đặt PM2 để quản lý tiến trình ứng dụng
PM2 giúp ứng dụng Node.js/Python tự động chạy nền, tự khởi động lại khi có sự cố và reload code mới mà không downtime:

```bash
# Cài đặt PM2 toàn cục (yêu cầu đã có Node.js & npm)
sudo npm install -g pm2
```

### 2. Cài đặt Redis Server (Cổng 6379) cho BullMQ (Mail & Audit Log)
Nhiều backend Node.js (như NestJS / Express) sử dụng **BullMQ** để quản lý hàng đợi gửi Mail nền và ghi Audit Log bất đồng bộ. BullMQ bắt buộc phải có `redis-server` chạy ở cổng `6379`:

```bash
# Cài đặt redis-server trên Ubuntu PRoot
sudo apt update && sudo apt install -y redis-server

# Khởi động dịch vụ Redis
sudo service redis-server start

# Kiểm tra Redis đang hoạt động
redis-cli ping
# Kết quả trả về: PONG là thành công 100%!
```

Để Redis tự khởi động cùng VPS, mở `nano ~/.bashrc` và thêm vào khối khởi động:
```bash
sudo service redis-server status > /dev/null 2>&1 || sudo service redis-server start
```

### 3. Chuẩn bị thư mục dự án và clone code lần đầu
Tạo thư mục chứa dự án và clone repository về bằng link SSH (`git@github.com:...`):

```bash
mkdir -p ~/projects
cd ~/projects

# Clone mã nguồn dự án của bạn
git clone git@github.com:your-username/my-app.git
cd my-app
```

### 4. Cấu hình file môi trường `.env` trên VPS
Tạo file `.env` chứa chuỗi kết nối Database, Redis và các biến bí mật (file này không commit lên GitHub):

```bash
nano .env
```
Nội dung mẫu:
```env
PORT=3000
DATABASE_URL="postgresql://postgres:123123@localhost:5432/myapp_db"
REDIS_HOST="localhost"
REDIS_PORT=6379
JWT_SECRET="your_very_secure_secret_key"
NODE_ENV="production"
```
Lưu file: `Ctrl + O` -> `Enter` -> `Ctrl + X`.

### 5. Cấu hình Ingress trên Cloudflare Tunnel trỏ về Backend
Trên trang quản trị **Cloudflare Zero Trust** ([one.dash.cloudflare.com](https://one.dash.cloudflare.com/)):
1. Vào **Networks** → **Tunnels** → Chọn Tunnel của bạn.
2. Mở tab **Public Hostnames** → Bấm **Edit** (hoặc **Add a public hostname**):
   * **Subdomain**: `api` (hoặc `app`)
   * **Domain**: tên miền của bạn (ví dụ: `manhhuy.io.vn`)
   * **Type**: `HTTP`
   * **URL**: `localhost:3000` *(hoặc cổng backend dự án của bạn quy định)*
3. Bấm **Save hostname**. Toàn bộ request từ Internet gửi tới tên miền sẽ được Cloudflare Tunnel chuyển tiếp thẳng vào backend trên VPS!

### 6. Khởi chạy ứng dụng lần đầu bằng PM2
Chạy thử và lưu danh sách tiến trình của PM2:

```bash
# Cài đặt thư viện ban đầu
npm install

# Khởi chạy ứng dụng bằng PM2 (ví dụ cổng 3000)
pm2 start dist/main.js --name "my-app"
# Hoặc với script npm: pm2 start npm --name "my-app" -- start

# Lưu danh sách tiến trình để tự phục hồi
pm2 save
```

---

## Bước 2: Tạo Ephemeral Auth Key trên Tailscale

Để GitHub Actions có thể "nhìn thấy" con điện thoại của bạn, máy ảo của GitHub cần được cấp quyền tạm thời tham gia vào mạng Tailnet của bạn.

1. Đăng nhập trang quản trị Tailscale: [login.tailscale.com/admin/settings/keys](https://login.tailscale.com/admin/settings/keys).
2. Nhấn nút **Generate auth key**.
3. Cấu hình chính xác như sau:
   * **Reusable**: Bật **ON** (để key dùng được nhiều lần cho mỗi commit).
   * **Ephemeral**: Bật **ON** *(Cực kỳ quan trọng: máy ảo GitHub sẽ tự động biến mất khỏi danh sách thiết bị Tailscale ngay khi workflow kết thúc, không làm rác mạng)*.
   * **Pre-authorized**: Bật **ON**.
4. Nhấn **Generate key**.
5. Copy chuỗi key vừa tạo (dạng `tskey-auth-kXXXXX...`). **Lưu lại chuỗi này** để nhập vào GitHub Secrets ở Bước 4.

---

## Bước 3: Tạo SSH Key riêng cho GitHub Actions

Để GitHub Actions có thể đăng nhập vào user `deploy` trên VPS mà không cần gõ mật khẩu, chúng ta tạo một cặp SSH key riêng:

Trên **Terminal máy tính của bạn**, chạy lệnh:

```bash
# 1. Tạo cặp key riêng cho CI/CD (nhấn Enter qua tất cả câu hỏi)
ssh-keygen -t ed25519 -C "github-actions-ci" -f ~/.ssh/github_actions -N ""

# 2. Đẩy public key lên VPS điện thoại để cấp quyền đăng nhập
ssh-copy-id -i ~/.ssh/github_actions.pub -p 2222 deploy@100.94.18.108
```

Kiểm tra thử đăng nhập bằng key vừa tạo:
```bash
ssh -i ~/.ssh/github_actions -p 2222 deploy@100.94.18.108
```
*Nếu đăng nhập thành công vào thẳng Ubuntu mà không đòi mật khẩu là đã hoàn tất!*

---

## Bước 4: Cấu hình Secrets trên GitHub Repository

Vào trang GitHub của repository dự án của bạn:
1. Nhấp chọn tab **Settings** (ở trên cùng bên phải).
2. Ở thanh bên trái, tìm mục **Security** → chọn **Secrets and variables** → **Actions**.
3. Bấm nút **New repository secret** màu xanh và lần lượt tạo 5 secret sau:

| TÊN SECRET | GIÁ TRỊ | MÔ TẢ |
| :--- | :--- | :--- |
| `TAILSCALE_AUTHKEY` | `tskey-auth-...` | Auth Key lấy từ Tailscale ở Bước 2 |
| `SSH_HOST` | `100.94.18.108` | Địa chỉ IP Tailscale của con điện thoại Android |
| `SSH_PORT` | `2222` | Cổng SSH bạn đã cấu hình trên VPS Ubuntu |
| `SSH_USER` | `deploy` | Tài khoản SSH trên VPS |
| `SSH_PRIVATE_KEY` | *(Nội dung file `~/.ssh/github_actions`)* | Toàn bộ nội dung private key trên máy tính (bắt đầu bằng `-----BEGIN OPENSSH PRIVATE KEY-----`) |

> [!TIP]
> Để lấy nội dung `SSH_PRIVATE_KEY` dán vào GitHub:
> Trên máy tính, gõ: `cat ~/.ssh/github_actions` rồi copy toàn bộ nội dung hiển thị trong terminal.

---

## Bước 5: Tạo file GitHub Actions Workflow

Trong thư mục dự án trên máy tính của bạn, tạo file theo đúng đường dẫn:
`.github/workflows/deploy.yml`

### Trường hợp A: Dành cho dự án Node.js / TypeScript (Prisma ORM)

```yaml
name: CI/CD Pipeline to Android VPS

on:
  push:
    branches:
      - main  # Tự động chạy mỗi khi push code lên nhánh main
  workflow_dispatch: # Cho phép nhấn nút bấm chạy thủ công trên GitHub UI

jobs:
  deploy:
    name: Build, Migrate & Deploy
    runs-on: ubuntu-latest
    timeout-minutes: 15

    steps:
      # 1. Kéo mã nguồn về máy ảo GitHub
      - name: Checkout Code
        uses: actions/checkout@v4

      # 2. Kết nối máy ảo GitHub vào mạng Tailscale
      - name: Connect to Tailscale Network
        uses: tailscale/github-action@v3
        with:
          authkey: ${{ secrets.TAILSCALE_AUTHKEY }}

      # 3. Thực thi Deploy, Migrate và Restart dịch vụ qua SSH
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
            set -e # Dừng ngay nếu có bất kỳ lệnh nào bị lỗi
            echo "🚀 [CI/CD] Đã kết nối thành công tới Android VPS!"
            
            # Di chuyển vào thư mục dự án
            cd ~/projects/my-app

            # 1. Kéo code mới nhất từ nhánh main
            echo "📥 [1/4] Đang kéo mã nguồn mới nhất..."
            git pull origin main

            # 2. Cài đặt các gói phụ thuộc mới (nếu có)
            echo "📦 [2/4] Đang cập nhật dependencies..."
            npm install --production=false

            # 3. Thực thi Database Migration
            echo "🐘 [3/4] Đang áp dụng Database Migration vào PostgreSQL..."
            npx prisma migrate deploy

            # 4. Build code (nếu dự án dùng TypeScript / Next.js)
            echo "⚙️ [4/4] Đang build ứng dụng..."
            npm run build --if-present

            # 5. Khởi động lại ứng dụng qua PM2 (Zero-downtime)
            echo "🔄 Đang reload tiến trình PM2..."
            pm2 reload my-app || pm2 start dist/main.js --name "my-app"
            pm2 save

            echo "✅ [CI/CD] Triển khai thành công 100%! Ứng dụng đã sẵn sàng trên Cloudflare Tunnel."
```

### Trường hợp B: Dành cho dự án Python (FastAPI / Django + Alembic)

Thay thế phần `script` trong bước `Deploy to Android VPS via SSH` thành:

```bash
script: |
  set -e
  cd ~/projects/my-python-app
  git pull origin main

  # Kích hoạt virtualenv và cài package
  source venv/bin/activate
  pip install -r requirements.txt

  # Chạy migration cho Database
  # Với FastAPI/Alembic:
  alembic upgrade head
  # Hoặc với Django:
  # python manage.py migrate

  # Reload dịch vụ qua PM2
  pm2 reload python-api || pm2 start "uvicorn main:app --host 0.0.0.0 --port 8080" --name "python-api"
  pm2 save
```

---

## Bước 6: Thử nghiệm thực tế và theo dõi Pipeline

Bây giờ bạn hãy thử nghiệm toàn bộ dây chuyền tự động:

1. Trên máy tính của bạn, mở code dự án, sửa thử một dòng chữ hoặc thêm một cột vào schema Database.
2. Commit và push code lên nhánh `main`:
   ```bash
   git add .
   git commit -m "feat: test automated ci/cd pipeline with database migration"
   git push origin main
   ```
3. Mở trình duyệt vào repository trên GitHub, nhấp vào tab **Actions**.
4. Bạn sẽ thấy một workflow có tên `CI/CD Pipeline to Android VPS` đang chạy với vòng tròn màu vàng.
5. Nhấp vào xem chi tiết:
   * Bước `Connect to Tailscale Network`: hoàn tất sau ~5 giây.
   * Bước `Deploy to Android VPS via SSH`: bạn sẽ thấy trực tiếp toàn bộ log `git pull`, `npx prisma migrate deploy` và `pm2 reload` chạy ngay trên chiếc điện thoại của bạn.
6. Khi tất cả các bước chuyển sang màu xanh lá cây (**Passed**), mở trình duyệt truy cập:
   ```text
   https://app.yourdomain.com
   ```
   *Tính năng mới và dữ liệu mới đã được cập nhật thành công!*

---

## Cẩm nang tối ưu hóa và Xử lý sự cố (Troubleshooting)

### 1. Lỗi `Host key verification failed` khi chạy SSH Action
* **Hiện tượng**: Pipeline dừng ở bước SSH với thông báo `Host key verification failed`.
* **Khắc phục**: Thư viện `appleboy/ssh-action` mặc định không yêu cầu known_hosts. Nếu gặp lỗi, đảm bảo bạn không bật tùy chọn `sync: true` hoặc thêm dòng lệnh quét host key trước đó.

### 2. Kỹ thuật "Build trên mây, chỉ Deploy về điện thoại" (Tiết kiệm CPU/RAM điện thoại)
* **Vấn đề**: Con chip Helio P35 trên điện thoại có thể mất nhiều thời gian hoặc nóng máy khi chạy các lệnh build nặng như `npm run build` của Next.js / NuxtJS.
* **Giải pháp tối ưu**:
  1. Cho GitHub Actions Runner (vốn có 4 Core CPU và 16GB RAM miễn phí) thực hiện lệnh `npm run build` trực tiếp trên mây.
  2. Dùng lệnh `rsync` hoặc `scp` qua Tailscale để nạp thư mục `.next/` hoặc `dist/` đã build sẵn về điện thoại.
  3. Điện thoại chỉ việc chạy `npx prisma migrate deploy` và `pm2 reload`, toàn bộ quá trình deploy chỉ mất **dưới 10 giây** mà máy điện thoại hoàn toàn mát mẻ!

### 3. Nguyên tắc an toàn với Database Migration trong CI/CD
* Luôn sử dụng lệnh **`npx prisma migrate deploy`** (không dùng `prisma migrate dev` trong CI/CD vì `dev` sẽ hỏi tương tác dòng lệnh và có thể làm reset database).
* Các công cụ ORM hiện đại (Prisma, Alembic, Django) luôn bọc migration trong một **Transaction**. Nếu script migration bị lỗi (ví dụ trùng tên cột hoặc lỗi ràng buộc khóa ngoại), Database sẽ tự động **Rollback** nguyên vẹn, đảm bảo an toàn tuyệt đối cho dữ liệu production.

### 4. Đảm bảo điện thoại luôn duy trì kết nối mạng
* Luôn cắm sạc cho điện thoại ở nơi thoáng khí.
* Đảm bảo app **Tailscale** trên Android đã được cấp quyền pin **Không hạn chế (Unrestricted)**.
* Đảm bảo script giữ CPU thức (`termux-wake-lock`) đã được kích hoạt trong Termux.
