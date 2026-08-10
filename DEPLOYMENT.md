# Thông Tin Deploy — Checkpoint 5

> Điền file này sau khi deploy xong. `pytest tests/test_cp5.py` đọc file này
> để tìm địa chỉ service của bạn và gọi thử.
>
> **Chỉ ghi TÊN biến môi trường, tuyệt đối không dán giá trị API key vào đây.**
> Repo này công khai — dán khóa vào là mất khóa.

## Thông Tin Học Viên

| Mục | Nội dung |
|-----|----------|
| Họ và tên | Nguyễn Thành An |
| Mã học viên | 2A202601017 |
| Repo | https://github.com/Muscar1a/K3-Day12-01017-NguyenThanhAn |

## Service

| Mục | Nội dung |
|-----|----------|
| Public URL | https://agent-production-a887.up.railway.app |
| Platform | Railway |
| Ngày deploy | 2026-08-10 |

## Biến Môi Trường Đã Set Trên Cloud

Ghi tên biến và **nguồn giá trị**, không ghi giá trị:

| Biến | Đã set | Ghi chú |
|------|--------|---------|
| `PORT` | ✅ | platform tự gán |
| `AGENT_API_KEY` | ✅ | đặt trong dashboard, không nằm trong repo |
| `REDIS_URL` | ✅ | Railway Redis service (tự inject qua reference variable) |
| `RATE_LIMIT_PER_MINUTE` | ✅ | 10 |
| `MONTHLY_BUDGET_USD` | ✅ | 10.0 |
| `LOG_LEVEL` | ✅ | INFO |

## Lệnh Kiểm Tra

Thay `<URL>` bằng Public URL ở trên:

```bash
# 1. Liveness — mong đợi 200 {"status":"ok"}
curl -i https://agent-production-a887.up.railway.app/health

# 2. Readiness — mong đợi 200 {"status":"ready"} (đã nối được Redis)
curl -i https://agent-production-a887.up.railway.app/ready

# 3. Không có API key — mong đợi 401
curl -i -X POST https://agent-production-a887.up.railway.app/ask \
  -H "Content-Type: application/json" \
  -d '{"question":"Hello"}'

# 4. Có API key — mong đợi 200 kèm câu trả lời
curl -i -X POST https://agent-production-a887.up.railway.app/ask \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $AGENT_API_KEY" \
  -H "X-User-Id: sv-test" \
  -d '{"question":"Deploy la gi?"}'

# 5. Rate limit — gọi 15 lần, những lần cuối phải trả 429
for i in $(seq 1 15); do
  curl -s -o /dev/null -w "%{http_code} " -X POST https://agent-production-a887.up.railway.app/ask \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $AGENT_API_KEY" \
    -H "X-User-Id: sv-test" \
    -d '{"question":"test"}'
done; echo
```

## Kết Quả Chạy Thật

```
1. GET /health → 200 OK
   {"status":"ok","service":"day12-agent","version":"1.0.0"}

2. GET /ready → 200 OK
   {"status":"ready","redis":true}

3. POST /ask (no key) → 401 Unauthorized
   {"detail":"Not authenticated"}

4. POST /ask (valid key) → 200 OK
   {"answer":"Theo mình hiểu, What is Docker liên quan tới cách hệ thống được đóng gói và vận hành. Điểm mấu chốt là tách cấu hình ra khỏi code và giữ service ở trạng thái stateless.","user_id":"sv-test","history_length":0,"cost_usd":2.565e-05,"tokens":{"in":3,"out":42}}
```

## Ảnh Chụp Màn Hình

Đặt ảnh trong thư mục `screenshots/`:

- `screenshots/dashboard.png` — trang quản lý service trên platform
- `screenshots/health.png` — kết quả gọi `/health` từ trình duyệt hoặc curl
