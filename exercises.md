# Phiếu Phản Ánh — K3 Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng `> *Câu trả lời của bạn*` bằng câu trả lời.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Nguyễn Thành An 
> Mã học viên: 2A202601017

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> Khi deploy lên Railway, nếu quên set `AGENT_API_KEY` trong dashboard, app sẽ crash ngay lúc khởi động và Railway báo deployment failed — ta phát hiện lỗi ngay. Nếu để mặc định `"changeme"`, app khởi động bình thường, health check xanh, nhưng endpoint `/ask` lại chấp nhận mọi request có header `X-API-Key: changeme`. Bất kỳ ai biết giá trị mặc định này đều có thể gọi API tự do, tốn tiền LLM của mình mà không hề hay biết vì service trông hoàn toàn ổn định.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> ```
> [INFO]  event="ask_completed" tokens_in=3 tokens_out=42 cost_usd=2.565e-05 timestamp="2026-08-10T05:44:57+00:00" user_id="sv-test"
> ```
>
> 1. **Lọc và đo lường tự động**: vì mỗi trường là key-value riêng, có thể dùng `jq` hoặc log aggregator (Datadog, CloudWatch) để query `event="ask_completed"` và tính tổng `cost_usd` theo `user_id` — phát hiện user nào đang đốt ngân sách nhiều nhất. `print()` chỉ cho một chuỗi văn bản, không tách được trường.
> 2. **Cảnh báo theo ngưỡng**: có thể đặt alert "nếu `tokens_out > 1000` trong một request thì gửi Slack notification". Với `print()` thuần, pipeline giám sát không biết trường nào là tokens, trường nào là cost để so sánh.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (Dockerfile.single) | 458 MB |
| Multi-stage (Dockerfile) | 141 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> Phần chênh lệch (~317 MB) là các công cụ build chỉ cần lúc compile, không cần khi chạy: `gcc`, `musl-dev` (để build các extension C của uvicorn như `uvloop`, `httptools`), toàn bộ header file và static library của Alpine. Ngoài ra bản single-stage giữ lại cả test dependencies (`pytest`, `httpx`, `fakeredis`, `PyYAML`) vì không có bước strip. Multi-stage build giữ lại `/install` (các package Python đã compile, đã lọc bỏ test deps) nhưng bỏ lại compiler và toolchain trong stage builder, nên image runtime chỉ chứa Python interpreter và code đã build sẵn.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> Dockerfile hiện tại copy `requirements.txt` trước, rồi mới `RUN pip install`, rồi mới `COPY app` và `COPY utils`. Khi sửa `app/main.py`: layer `COPY requirements.txt` và `RUN pip install` **dùng lại từ cache** vì `requirements.txt` không đổi — đây là layer nặng nhất (~60s). Chỉ layer `COPY app ./app` trở đi phải chạy lại.
>
> Nếu đặt `COPY . .` trước `RUN pip install`: mỗi lần sửa bất kỳ file nào trong project (kể cả comment trong code), Docker thấy layer `COPY` thay đổi → invalidate cache → `pip install` chạy lại từ đầu mỗi lần build, tốn thêm hàng phút không cần thiết.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> Chuỗi sự kiện: (1) Kẻ tấn công gửi payload khai thác lỗ hổng trong code xử lý input → (2) đạt được remote code execution bên trong container → (3) vì process chạy bằng root (uid 0), có thể ghi vào `/proc/sysrq-trigger`, mount filesystem của host, hoặc nếu Docker socket được mount vào container thì tạo container mới với `--privileged` để thoát ra host hoàn toàn → (4) kiểm soát máy host.
>
> `USER appuser` (uid 10001) cắt đứt ở bước (3): kẻ tấn công có shell trong container nhưng chỉ là một user không có quyền gì trên host. Không ghi được vào `/proc`, không mount được filesystem, không tương tác được với Docker daemon — thiệt hại bị giới hạn trong phạm vi container.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

> Tối đa **20 request** trong 2 giây. Cách đạt được: gửi 10 request vào giây cuối của phút (ví dụ 10:00:59) → bộ đếm phút đó ghi nhận 10, đúng hạn mức. Sang giây 10:01:00 bộ đếm reset về 0 → gửi thêm 10 request nữa, vẫn đúng hạn mức. Kết quả: 20 request trong khoảng 1-2 giây mà không bị chặn lần nào.
>
> Sliding window tránh được điều này: tại bất kỳ thời điểm nào, hệ thống nhìn vào đúng 60 giây gần nhất. 10 request ở giây :59 vẫn còn trong cửa sổ khi tính đến giây :01, nên request thứ 11 bị chặn.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

> Rate limit đo **tần suất** (số request / đơn vị thời gian, reset theo cửa sổ). Cost guard đo **tổng chi phí tích lũy** trong tháng, không reset theo tần suất mà reset theo chu kỳ billing.
>
> - **Rate limit cho qua, cost guard chặn**: user gửi đúng 1 request/phút suốt cả tháng (luôn dưới 10/phút), nhưng mỗi câu hỏi có context dài → mỗi request tốn $0.80 → sau 13 request tích lũy đủ $10.00 → cost guard chặn, dù tần suất hoàn toàn hợp lệ.
> - **Cost guard cho qua, rate limit chặn**: user mới, chưa tiêu xu nào trong tháng, nhưng gửi 15 request trong 60 giây → rate limit chặn ở request thứ 11 vì vượt 10/phút, dù tổng chi phí chỉ mới vài cent.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> 1. Redis mất kết nối → `store.ping()` trả `False` → endpoint gộp trả 503.
> 2. Load balancer poll health check của cả 3 container → nhận 503 → đánh dấu cả 3 là unhealthy → ngừng chuyển traffic vào.
> 3. Orchestrator (Railway / K8s) thấy health check fail liên tục → bắt đầu restart cả 3 container theo `restartPolicyMaxRetries`.
> 4. Container mới khởi động, ngay lập tức ping Redis → vẫn down → lại trả 503 → lại bị restart.
> 5. Trong toàn bộ 30 giây đó, **không container nào phục vụ được request** → outage toàn bộ.
> 6. Redis phục hồi → container restart lần cuối → health check xanh → traffic trở lại, nhưng mọi request đang xử lý dở trước đó đã bị cắt đứt.
>
> Với `/health` tách riêng (không check Redis): bước 2-4 không xảy ra. Container vẫn chạy, load balancer chỉ dừng gửi traffic mới qua `/ready`, nhưng không restart container. Khi Redis phục hồi, `/ready` tự xanh lại mà không cần restart.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

> Với Redis: `history_length` tăng đều 0 → 1 → 2 → 3... bất kể request rơi vào container nào, vì tất cả đọc/ghi vào cùng một Redis key `history:{user_id}`.
>
> Với dict Python: mỗi container có dict riêng trong RAM. Nginx phân phối request round-robin qua 3 container, nên `history_length` sẽ dao động không nhất quán — ví dụ: 0, 0, 0, 1, 1, 1, 2, 2, 2 (nếu round-robin đều) hoặc nhảy loạn hơn nếu phân phối không đều. Agent "mất trí nhớ" mỗi khi request rơi vào container khác, và khi container restart thì toàn bộ lịch sử trong dict đó biến mất.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> **Lỗi**: `/ready` trả 503 liên tục dù `/health` trả 200 bình thường. Test báo `AssertionError: /ready trả 503 — nhiều khả năng biến REDIS_URL trên cloud chưa đúng hoặc chưa tạo Redis instance`.
>
> **Tìm nguyên nhân**: kiểm tra biến môi trường bằng `railway variable` → thấy `REDIS_URL=fake://` trên cloud. Dockerfile strip `fakeredis` khỏi production image (`grep -vE "fakeredis" requirements.txt`), nên khi app gọi `import fakeredis` sẽ fail. Nhưng lỗi bị nuốt bởi `ping()` dùng `try/except Exception`, nên chỉ thấy 503 chứ không thấy traceback. Ngoài ra phát hiện thêm: service tên "Redis" trên Railway thực ra đang chạy web app (uvicorn), không phải Redis database — nên `redis.railway.internal:6379` không có gì để kết nối.
>
> **Sửa**: tạo Redis database thật bằng `railway add --database redis`, Railway tự tạo service với image `redis` và inject đúng connection string. Cập nhật `REDIS_URL` của agent service sang URL nội bộ của Redis database mới, redeploy → `/ready` trả 200.
