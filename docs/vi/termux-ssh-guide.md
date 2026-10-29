# Hướng Dẫn Cài Đặt & Kết Nối SSH Trực Tiếp Đến Termux Host (Cổng 8022)

[**[🇬🇧 Read English Version](../en/termux-ssh-guide.md)** • **[🏠 Trang chủ](../../README.vi.md)**]

Tài liệu này hướng dẫn cách cấu hình máy chủ **OpenSSH trực tiếp trên tầng nền Termux (Host Layer)** lắng nghe trên cổng **`8022`** và kết nối từ xa từ máy tính qua mạng Tailscale.

---

## 📑 Mục lục

1. [Phân biệt SSH Termux Host (:8022) và SSH Ubuntu PRoot (:2222)](#1-phân-biệt-ssh-termux-host-8022-và-ssh-ubuntu-proot-2222)
2. [Tại sao bắt buộc phải có cổng SSH Termux 8022?](#2-tại-sao-bắt-buộc-phải-có-cổng-ssh-termux-8022)
3. [Bước 1: Cài đặt và cấu hình OpenSSH trên Termux](#bước-1-cài-đặt-và-cấu-hình-openssh-trên-termux)
4. [Bước 2: Cấu hình tự khởi động và tránh xung đột Auto-login](#bước-2-cấu-hình-tự-khởi-động-và-tránh-xung-đột-auto-login)
5. [Bước 3: Kết nối SSH từ máy tính vào Termux](#bước-3-kết-nối-ssh-từ-máy-tính-vào-termux)
6. [Bước 4: Cấu hình đăng nhập bằng SSH Key (Không cần mật khẩu)](#bước-4-cấu-hình-đăng-nhập-bằng-ssh-key-không-cần-mật-khẩu)
7. [Các kịch bản cứu hộ thực tế qua cổng 8022](#các-kịch-bản-cứu-hộ-thực-tế-qua-cổng-8022)

---

## 1. Phân biệt SSH Termux Host (:8022) và SSH Ubuntu PRoot (:2222)

Hệ thống VPS Android của chúng ta hoạt động theo kiến trúc 2 tầng mạng độc lập:

| Đặc điểm so sánh | 🟢 SSH Termux Host (Tầng 1) | 🔵 SSH Ubuntu PRoot (Tầng 2) |
| :--- | :--- | :--- |
| **Cổng kết nối (Port)** | **`8022`** | **`2222`** |
| **Môi trường** | Android Native (Bionic libc) | Ubuntu 24.04 ARM64 (glibc) |
| **Lệnh bật SSH** | `sshd` | `service ssh start` |
| **Tài khoản đăng nhập** | Tên user của Termux (xem bằng `whoami`, ví dụ: `u0_a245`) | `deploy` |
| **Cơ chế xác thực** | Mật khẩu đặt qua lệnh `passwd` hoặc SSH key | Mật khẩu Linux tiêu chuẩn trong Ubuntu |
| **Mục đích chính** | **Cổng cứu hộ khẩn cấp**, quản trị PostgreSQL Native, quản trị phần cứng Android | **Môi trường làm việc chính**, triển khai web, PM2, Redis, CI/CD GitHub Actions |

---

## 2. Tại sao bắt buộc phải có cổng SSH Termux 8022?

Nếu bạn chỉ cấu hình SSH trên Ubuntu (cổng 2222):
* Khi Ubuntu bị lỗi cấu hình `/etc/ssh/sshd_config`, lỗi permission tmpfs `/run/sshd`, hoặc bị deadlock do ứng dụng ngốn hết RAM, bạn sẽ **hoàn toàn mất kết nối từ xa**.
* Bạn bắt buộc phải mở màn hình điện thoại, gõ phím trên màn hình cảm ứng nhỏ hẹp để sửa lỗi.

👉 **Cổng SSH 8022 của Termux là "chiếc chìa khóa vạn năng" cứu hộ**: Luôn luôn mở độc lập ở tầng ngoài. Dù Ubuntu bên trong có bị sập hoàn toàn, bạn vẫn có thể SSH vào cổng 8022 từ máy tính để sửa file, khởi động lại container, hoặc restart PostgreSQL.

---

## 3. Bước 1: Cài đặt và cấu hình OpenSSH trên Termux

Thực hiện ngay tại màn hình chính của Termux (dấu nhắc `~$`, **ngoài môi trường Ubuntu**):

```bash
# 1. Cập nhật và cài đặt OpenSSH
pkg update -y
pkg install openssh -y

# 2. Xem tên tài khoản người dùng Termux của bạn
whoami
# (Ví dụ kết quả hiển thị: u0_a245)

# 3. Đặt mật khẩu đăng nhập SSH cho Termux
passwd
# Nhập mật khẩu bạn muốn (ví dụ: 123123) và nhập lại để xác nhận
# (Lưu ý: khi gõ mật khẩu trên Linux, màn hình sẽ không hiện ký tự)

# 4. Khởi chạy máy chủ SSH Termux
sshd
```

Kiểm tra dịch vụ SSH Termux đã chạy:
```bash
pgrep sshd
```
*(Nếu hiển thị một mã số tiến trình PID là SSH Termux đã sẵn sàng lắng nghe ở cổng `8022`).*

---

## 4. Bước 2: Cấu hình tự khởi động và tránh xung đột Auto-login

Một vấn đề phổ biến là: nếu cấu hình tự động vào Ubuntu trong `~/.bashrc`, mỗi khi bạn SSH vào cổng 8022, Termux sẽ tự động chuyển bạn vào Ubuntu thay vì giữ bạn ở màn hình Termux Host.

Để khắc phục, chúng ta sử dụng biến môi trường `$SSH_CLIENT`:

Mở file cấu hình khởi động của Termux:
```bash
nano ~/.bashrc
```

Thêm khối lệnh chuẩn hóa sau vào file:
```bash
# 1. Tự động bật SSH Termux (cổng 8022) nếu chưa chạy
pgrep -x sshd > /dev/null 2>&1 || sshd

# 2. Tự động bật PostgreSQL Native nếu chưa chạy
if ! pg_isready -q > /dev/null 2>&1; then
    pg_ctl -D $PREFIX/var/lib/postgresql -l logfile start > /dev/null 2>&1
fi

# 3. CHỈ tự động nhảy vào Ubuntu khi mở trực tiếp trên màn hình điện thoại
# Khi kết nối qua SSH (cổng 8022), GIỮ NGUYÊN ở Termux Host để cứu hộ
if [ -z "$SSH_CLIENT" ] && [ -z "$SSH_CONNECTION" ]; then
    if ! pgrep -x proot > /dev/null 2>&1; then
        proot-distro login ubuntu --user deploy
    fi
fi
```
Nhấn `Ctrl + O` → `Enter` để lưu, `Ctrl + X` để thoát `nano`.

---

## 5. Bước 3: Kết nối SSH từ máy tính vào Termux

Từ terminal trên máy tính của bạn (đảm bảo cả hai máy đều đang kết nối Tailscale):

```bash
# Cú pháp kết nối (sử dụng cổng 8022):
ssh -p 8022 <IP_Tailscale_của_điện_thoại>

# Hoặc điền kèm tên user Termux:
ssh -p 8022 u0_a245@100.94.18.108
```

* Nhập mật khẩu bạn đã đặt ở lệnh `passwd` tại Bước 1.
* Khi kết nối thành công, bạn sẽ thấy dấu nhắc lệnh Termux quen thuộc:
  ```text
  ~ $
  ```
* Bạn đang đứng trực tiếp tại hệ điều hành Android Native!

---

## 6. Bước 4: Cấu hình đăng nhập bằng SSH Key (Không cần mật khẩu)

Để từ máy tính SSH vào Termux không cần gõ mật khẩu:

Trên **máy tính của bạn**, chạy lệnh:
```bash
ssh-copy-id -p 8022 100.94.18.108
```
Nhập mật khẩu Termux lần cuối cùng. Từ nay về sau, bạn chỉ cần gõ `ssh -p 8022 100.94.18.108` là vào thẳng Termux trong 0.2 giây.

---

## 7. Các kịch bản cứu hộ thực tế qua cổng 8022

Khi xảy ra sự cố, từ máy tính bạn SSH vào cổng 8022 để xử lý:

### Kịch bản 1: Ubuntu PRoot bị treo cứng (Deadlock)
Không cần chạm vào điện thoại, từ SSH cổng 8022:
```bash
# Tắt toàn bộ tiến trình PRoot bị kẹt
pkill -9 proot

# Đăng nhập lại vào Ubuntu để kiểm tra
proot-distro login ubuntu --user deploy
```

### Kịch bản 2: Quản trị hoặc khởi động lại PostgreSQL Native
```bash
# Xem trạng thái database
pg_isready

# Khởi động lại PostgreSQL
pg_ctl -D $PREFIX/var/lib/postgresql restart
```

### Kịch bản 3: Giữ điện thoại luôn thức và kiểm tra pin
```bash
# Bật wake-lock chống Android ngắt CPU
termux-wake-lock

# Xem thông tin pin và nhiệt độ máy
termux-battery-status
```
