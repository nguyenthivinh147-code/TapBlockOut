---
name: device-test
description: "Test Candy Away trên điện thoại cắm USB: mọi kịch bản smoke và đủ 500 level, báo cáo đạt / lỗi game / hạ tầng, rồi cài lại bản demo."
argument-hint: "[all|features|levels] [từ-tới]"
disable-model-invocation: true
---

Chạy trên máy thật bằng `tools/device_smoke.sh`. Lệnh, biến môi trường (`GODOT`, `JAVA_HOME`, `SNAP`), cách đọc `summary.txt` và `levels.tsv`: `docs/TESTING.md` mục "Thiết bị thật". Đọc mục đó trước bước 1.

Phạm vi: `all` (mặc định) làm mọi bước; `features` bỏ bước 5; `levels` bỏ bước 4. `từ-tới` (ví dụ `levels 101-200`) giới hạn level ở bước 2 và 5.

Suốt lúc chạy, máy cắm, mở khoá, không ai chạm. Khi `adb devices` báo `unauthorized` hoặc máy khoá: nhờ người dùng mở khoá và bấm Cho phép (tích "Luôn cho phép"), rồi làm lại bước đang dở. Riêng bước 5 script tự chờ và nối lại.

## 1. Máy sẵn sàng

`adb devices` có đúng một dòng `device`. Ghi hãng, model, Android, RAM, cỡ màn cho báo cáo.

Xong khi: một máy ở trạng thái `device`.

## 2. Desktop xanh trước

- `tools/test.sh`.
- `tools/smoke.sh headless` với các kịch bản sẽ chạy ở bước 4.
- `SMOKE_ARGS="from=<từ> to=<từ+39>" tools/smoke.sh headless V` khi phạm vi có level.

Kịch bản đỏ trên desktop được xử lý ở desktop: lỗi của smoke thì sửa smoke, lỗi game thì báo người dùng và bỏ kịch bản đó khỏi bước 4.

Xong khi: mỗi lệnh in mã 0, hoặc kịch bản đỏ đã có tên trong danh sách bỏ kèm lý do.

## 3. Build và cài

`tools/device_smoke.sh build`, rồi `adb install -r build/CandyAway-smoke.apk`.

Xong khi: `build/CandyAway-demo.apk` và `build/CandyAway-smoke.apk` mới hơn lúc bắt đầu, `adb devices` vẫn `device` (export hay làm máy hỏi lại quyền), install in `Success`. Ghi lại các dòng `snapshot dùng bản HEAD` của build: code game đang sửa dở không có trong bản test.

## 4. Mọi kịch bản tính năng

Mọi mã trong bảng "Kịch bản" của `docs/TESTING.md` tầng 2, trừ V và G2 (G tự chạy G2):

- A, T, L có ảnh: `tools/device_smoke.sh run A T L capture=1`.
- Các mã còn lại trong một lệnh: `tools/device_smoke.sh run <mã>...`.

Xong khi: mỗi mã có `summary.txt` với dòng `== <mã>`.

## 5. Đủ level

`tools/device_smoke.sh run V from=<từ> to=<tới>` (mặc định 1–500, khoảng 9 giây mỗi level), chạy nền.

Xong khi: dòng `== V tổng` có đủ số level của phạm vi và `levels.tsv` có đúng từng ấy dòng level.

## 6. Đọc kết quả

Xếp mỗi kịch bản và mỗi level vào một loại:

- **đạt**: mã 0, `SMOKE ERRORS script=0 engine=0`.
- **lỗi game**: mã 1 hoặc `SMOKE LEVEL FAIL`. Tìm dòng `SMOKE FAILED`, `LEVEL FAIL`, `SMOKE ERROR` trong `logcat.txt`, đối chiếu luật trong `design.md`, chạy lại đúng kịch bản (hoặc `run V from=<n> to=<n>`) một lần để loại trường hợp ngẫu nhiên.
- **hạ tầng**: mã 2 (app chết, quá giờ, mất kết nối, chạm thật). Xem `DEBUG`, `AndroidRuntime` trong `logcat.txt`, chạy lại một lần.

Ảnh: đọc mọi ảnh của A và L; với T đọc ảnh đầu, giữa và cuối của mỗi đoạn quay. Tìm chữ tràn, vỡ khung, thiếu chữ, màn trống.

Khung hình: `p95_ms` của `levels.tsv` đo lúc chạm liên tục, trường hợp nặng nhất. Lấy vài level có `p95_ms` cao nhất, đo lại theo nhịp người chơi (`run V from=<n> to=<n> pace=0.5`), rồi so p95 với 33 ms (ngân sách 30 FPS, `design.md` mục 8).

Xong khi: mọi kịch bản và mọi level đã có loại, mọi ảnh trong danh sách trên đã đọc.

## 7. Trả máy

`adb install -r build/CandyAway-demo.apk`.

Xong khi: install in `Success`.

## 8. Báo cáo

Gửi người dùng:

- máy, commit, các file dùng bản HEAD;
- bảng kịch bản: mã, loại, lý do;
- level: số đạt, từng level lỗi game kèm lý do, p95 lúc chạm liên tục và lúc theo nhịp người chơi;
- khởi động, PSS cao nhất;
- mỗi lỗi game: luật trong `design.md`, điều thấy trên máy, lệnh tái hiện;
- phần máy không kiểm được: quảng cáo và mua hàng thật, âm thanh, rung, cảm giác chơi (kế hoạch mục 4).

Lỗi game được sửa trong task riêng, theo luật test đỏ trước, khi người dùng đồng ý.
