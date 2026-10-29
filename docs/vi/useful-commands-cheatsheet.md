# Sổ Tay Lệnh DevOps Thường Dùng Trên Android VPS (Cheatsheet)

[**[🇬🇧 Read English Version](../en/useful-commands-cheatsheet.md)** • **[🏠 Trang chủ](../../README.vi.md)**]

Tài liệu này tổng hợp toàn bộ các câu lệnh thực chiến thường xuyên sử dụng nhất khi vận hành máy chủ Android VPS (Termux + Ubuntu PRoot), bao gồm quản lý tiến trình ứng dụng **PM2**, kiểm tra cổng mạng **Port**, đọc **Log**, quản trị **PostgreSQL / Redis**, kiểm tra **Cloudflare Tunnel** và theo dõi phần cứng thiết bị.

---

## 📑 Mục lục

1. [Quản lý ứng dụng Backend với PM2](#1-quản-lý-ứng-dụng-backend-với-pm2)
2. [Kiểm tra Cổng mạng (Port) & Phản hồi HTTP (Ping Port)](#2-kiểm-tra-cổng-mạng-port--phản-hồi-http-ping-port)
3. [Quản trị Cơ sở dữ liệu (PostgreSQL Native & Redis BullMQ)](#3-quản-trị-cơ-sở-dữ-liệu-postgresql-native--redis-bullmq)
4. [Kiểm tra và Khắc phục sự cố Cloudflare Tunnel](#4-kiểm-tra-và-khắc-phục-sự-cố-cloudflare-tunnel)
5. [Kiểm tra Mạng riêng ảo Tailscale](#5-kiểm-tra-mạng-riêng-ảo-tailscale)
6. [Giám sát Tài nguyên Phần cứng & Nhiệt độ Máy (RAM, CPU, Pin)](#6-giám-sát-tài-nguyên-phần-cứng--nhiệt-độ-máy-ram-cpu-pin)
7. [Các lệnh Cứu hộ Khẩn cấp & Dọn dẹp Hệ thống](#7-các-lệnh-cứu-hộ-khẩn-cấp--dọn-dẹp-hệ-thống)

---

## 1. Quản lý ứng dụng Backend với PM2

Toàn bộ các lệnh này được thực thi bên trong môi trường **Ubuntu PRoot** (`deploy@localhost`):

### 1.1. Khởi chạy ứng dụng mới
```bash
# Khởi chạy file build Node.js (chế độ Fork, giới hạn 300MB RAM)
pm2 start dist/main.js --name "intern-be" --max-memory-restart 300M

# Khởi chạy thông qua script npm (ví dụ npm run start:prod)
pm2 start npm --name "intern-be" --max-memory-restart 300M -- run start:prod

# Khởi chạy ứng dụng Python FastAPI / Uvicorn
pm2 start "uvicorn main:app --host 0.0.0.0 --port 8000" --name "python-api"
```

> [!TIP]
> **Tại sao luôn dùng chế độ `fork` trên Android VPS?**
> Môi trường PRoot chạy giả lập trên chip ARM không hỗ trợ tốt IPC Cluster. Khởi chạy với chế độ mặc định `fork` giúp ứng dụng hoạt động ổn định nhất, không bị lỗi restart lặp và tiết kiệm RAM tối đa.

### 1.2. Xem trạng thái và Giám sát
```bash
# Xem danh sách tất cả ứng dụng đang chạy
pm2 list

# Mở bảng điều khiển đồ họa theo dõi CPU và RAM thời gian thực
pm2 monit

# Xem chi tiết thông số cấu hình và đường dẫn của 1 app
pm2 show intern-be
```

### 1.3. Đọc và Quản lý Log
```bash
# Xem log trực tiếp thời gian thực (bấm Ctrl + C để thoát)
pm2 logs intern-be

# Đọc 100 dòng log gần nhất rồi tự động thoát ra terminal
pm2 logs intern-be --lines 100 --nostream

# Đọc riêng biệt log lỗi (Error log)
pm2 logs intern-be --err --lines 50 --nostream

# XÓA SẠCH file log cũ khi bị đầy bộ nhớ
pm2 flush
```

### 1.4. Nạp lại mã nguồn, Dừng và Lưu cấu hình
```bash
# Nạp lại mã nguồn mới không downtime (Zero-downtime Reload)
pm2 reload intern-be --update-env

# Khởi động lại hẳn tiến trình
pm2 restart intern-be

# Tạm dừng 1 app
pm2 stop intern-be

# Xóa bỏ 1 app ra khỏi danh sách quản lý
pm2 delete intern-be

# BẮT BUỘC: Lưu lại danh sách app hiện tại vào ổ cứng để tự hồi sinh khi reboot
pm2 save

# Hồi sinh lại danh sách app đã lưu từ trước
pm2 resurrect
```

---

## 2. Kiểm tra Cổng mạng (Port) & Phản hồi HTTP (Ping Port)

Các câu lệnh hữu ích để kiểm tra xem Backend hoặc Database đã thực sự lắng nghe trên cổng mong muốn chưa.

### 2.1. Kiểm tra danh sách cổng đang mở (Listening Ports)
```bash
# Xem tất cả các cổng TCP đang lắng nghe trên máy
ss -lnt

# Kiểm tra riêng một cổng cụ thể (ví dụ cổng 3001)
ss -lnt | grep :3001

# Xem kèm tên tiến trình và PID đang mở cổng (cần quyền sudo)
sudo ss -tulpn | grep :3001
```

### 2.2. Kiểm tra tiến trình nào đang chiếm dụng cổng
```bash
# Xem chương trình nào đang giữ cổng 3001
lsof -i :3001

# Đóng ngay tiến trình đang chiếm cổng 3001
sudo fuser -k 3001/tcp
```

### 2.3. "Ping" kiểm tra kết nối cổng và phản hồi HTTP
```bash
# Kiểm tra nhanh kết nối TCP (Ping Port) bằng Netcat
nc -zv 127.0.0.1 3001

# Gửi HTTP HEAD test phản hồi web nội bộ (Mong đợi: HTTP/1.1 200 OK)
curl -I http://localhost:3001

# Gửi request kiểm tra nội dung JSON trả về từ endpoint
curl http://localhost:3001/api/health
```

---

## 3. Quản trị Cơ sở dữ liệu (PostgreSQL Native & Redis BullMQ)

### 3.1. PostgreSQL Server (Tầng Termux Host - Cổng 5432)
Thao tác tại màn hình Termux (hoặc SSH cổng `8022`):

```bash
# Kiểm tra xem PostgreSQL có đang sẵn sàng nhận kết nối không
pg_isready

# Khởi động máy chủ PostgreSQL
pg_ctl -D $PREFIX/var/lib/postgresql -l $PREFIX/var/lib/postgresql/logfile start

# Khởi động lại PostgreSQL
pg_ctl -D $PREFIX/var/lib/postgresql restart

# Dừng PostgreSQL
pg_ctl -D $PREFIX/var/lib/postgresql stop

# Đăng nhập trực tiếp vào giao diện dòng lệnh psql
psql -d postgres
# Hoặc đăng nhập vào database dự án:
psql -U postgres -h localhost -d myapp_db
```

### 3.2. Redis Server (Tầng Ubuntu PRoot - Cổng 6379)
Thao tác bên trong Ubuntu PRoot (`deploy@localhost`):

```bash
# Kiểm tra phản hồi Redis (Mong đợi: PONG)
redis-cli ping

# Xem số lượng Key / Job trong Redis Database số 1 (BullMQ)
redis-cli -n 1 dbsize

# Xem trực tiếp danh sách tất cả key trong DB 1
redis-cli -n 1 keys "*"

# Xóa sạch toàn bộ dữ liệu trong Redis DB 1 (khi cần reset queue)
redis-cli -n 1 flushdb

# Khởi động lại dịch vụ Redis
sudo service redis-server restart
```

---

## 4. Kiểm tra và Khắc phục sự cố Cloudflare Tunnel

```bash
# Kiểm tra tiến trình tunnel có đang chạy nền không
pidof cloudflared

# Xem tiến trình chi tiết và tham số chạy
ps aux | grep cloudflared

# Xem log kết nối tunnel trực tiếp (theo dõi traffic vào website)
tail -f ~/logs/cloudflared.log

# Đọc 50 dòng log gần nhất của tunnel
tail -n 50 ~/logs/cloudflared.log

# Tắt toàn bộ các tiến trình tunnel bị kẹt hoặc chạy trùng
pkill -9 cloudflared
```

---

## 5. Kiểm tra Mạng riêng ảo Tailscale

Thực hiện từ Terminal trên máy tính hoặc điện thoại:

```bash
# Kiểm tra kết nối ping trực tiếp tới điện thoại qua Tailscale IP
tailscale ping 100.94.18.108

# Xem trạng thái kết nối của tất cả các máy trong Tailnet
tailscale status

# Xem địa chỉ IP Tailscale hiện tại của máy
tailscale ip -4
```

---

## 6. Giám sát Tài nguyên Phần cứng & Nhiệt độ Máy (RAM, CPU, Pin)

### 6.1. Kiểm tra Bộ nhớ RAM & CPU (Trong Ubuntu PRoot)
```bash
# Xem dung lượng RAM tổng, đã dùng (used) và còn trống (free)
free -h

# Xem 10 tiến trình đang ngốn nhiều RAM nhất hệ thống
ps aux --sort=-%mem | head -n 10

# Xem 10 tiến trình đang ngốn nhiều CPU nhất
ps aux --sort=-%cpu | head -n 10

# Bật trình theo dõi hệ thống trực quan dạng htop
top
# (Mẹo: Bấm 'Shift + H' trong top để ẩn bớt các luồng thread con của cloudflared)
```

### 6.2. Kiểm tra Pin, Nhiệt độ & Khóa CPU (Trong Termux Host)
```bash
# Xem phần trăm pin, trạng thái sạc và nhiệt độ máy
termux-battery-status

# Khóa CPU không cho ngủ sâu khi tắt màn hình (Wake-lock)
termux-wake-lock

# Giải phóng khóa CPU (khi muốn tắt máy nghỉ ngơi)
termux-wake-unlock
```

---

## 7. Các lệnh Cứu hộ Khẩn cấp & Dọn dẹp Hệ thống

### 7.1. Cứu hộ khi Ubuntu PRoot bị đơ cứng
Từ máy tính, SSH vào **Cổng 8022** (Termux Host):
```bash
ssh -p 8022 100.94.18.108

# 1. Tiêu diệt toàn bộ các tiến trình PRoot bị treo
pkill -9 proot

# 2. Đăng nhập lại vào Ubuntu sạch sẽ
proot-distro login ubuntu --user deploy
```

### 7.2. Lệnh dọn dẹp hệ thống khi đầy đĩa (Disk Cleanup)
```bash
# Dọn dẹp cache của apt
sudo apt clean && sudo apt autoremove -y

# Dọn dẹp cache npm
npm cache clean --force

# Xóa các file log rác
rm -f ~/nohup.out ~/logs/*.log
pm2 flush
```
