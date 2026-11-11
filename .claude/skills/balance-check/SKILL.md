---
name: balance-check
description: "Kiểm cân bằng Candy Away từ số thật: kinh tế, tiến trình mở khoá, độ khó level, quảng cáo. Dùng sau khi đổi số trong config.gd hoặc sinh lại level, hoặc khi người dùng hỏi về cân bằng."
argument-hint: "[economy|progression|levels|ads]"
---

Chỉ báo cáo. Đổi số khi người dùng yêu cầu, và đi qua `/design-note` để `design.md` cùng mục 9 đổi theo.

## Bước 1: đầu vào

Liệt kê từng đầu vào dưới đây và ghi `FOUND` hoặc `ABSENT`. Phần thiếu đầu vào ghi `NOT ASSESSED`. `NOT ASSESSED` là kết quả hợp lệ; một báo cáo sạch không dựa trên dữ liệu mới là sai.

- **Số:** các bảng trong `src/config.gd` (`_ECON`, `_LIVES`, `_ADS`, `_UNLOCK`, `_FEATURES`, `_DAILY`, `_COSMETICS`, `_SKUS`, `_PACKS`, `_OFFERS`, `_WEEKLY`, `_CHAIN`, `_WIN_STREAK`, `_ROAD_TRIP`, `_SPECIAL`, `_CONTENT`). Đây là giá trị gốc; lúc chạy Remote Config ghi đè qua `Config.apply_remote` (khoá ở `docs/HORUS_HANDOFF.md` mục 4).
- **Mục tiêu:** `design.md` mục 3 (Mạng, Tiêu chí thư giãn), 4 (Đường cong độ khó L1–500, Mở khoá theo level), 5 (Kinh tế, Bảng mô phỏng, Rủi ro người dùng đã chấp nhận), 6 (Quảng cáo), 7 (Mua hàng và offer). Giá trị không có khoảng mục tiêu thì ghi `chưa có khoảng mục tiêu, không đánh giá`, không gọi là outlier.
- **Level:** `data/levels/level_NNNN.json` (500 file, có `min_taps`, `moves`, `hard`, khối và cơ chế), `data/road_trip/`, `data/special/`. Tính đúng của level kiểm bằng `tools/godot.sh --headless --path . -s res://tools/validate_levels.gd` (thoát 1 khi có lỗi).
- **Mô phỏng:** `node tools/sim.mjs` (28 ngày, nhóm người chơi, 500 seed). Số đọc thẳng từ `src/config.gd` (mặc định, chưa Remote Config) và `data/levels/`; hành vi người chơi, tỉ lệ thắng, MOVES thừa là giả định. Luồng trong sim là bản chép của luật game: luật đổi mà sim chưa theo (đối chiếu `design.md` mục 3–7 với các hàm `rescue`, `attempt`, `daily`, `maybeInter` của sim) là một phát hiện, và phần kết quả dựa trên luồng đó chỉ ghi là tham khảo. Phần sim chưa mô phỏng ghi ở `design.md` mục 5 "Bảng mô phỏng".

## Bước 2: kiểm theo mảng

Không có tham số thì kiểm cả bốn mảng.

- **economy:** faucet (thắng level, quà 28 ngày, video gold, Road Trip, Win Streak, offer), sink (+3 MOVES, nạp mạng, booster, cosmetic); dự phóng gold theo ngày và theo level; vòng lặp kiếm gold vô hạn (video và quà chồng nhau); sink có thể cạn; gold trên mỗi đô của các SKU so với nhau (gói nào áp đảo gói khác). Câu hỏi kinh tế lớn thì giao agent `economy-designer`.
- **progression:** mốc mở khoá (`_UNLOCK`, `_FEATURES`, `design.md` mục 4 "Mở khoá theo level") so với số level mỗi ngày dự phóng; vùng chết (quá nhiều level không có gì mới); nhiều tính năng mở dồn cùng một level.
- **levels:** đường cong `min_taps`, `moves`, `hard` theo level so với `design.md` mục 4; level nhảy vọt độ khó so với hàng xóm; tỉ lệ từng cơ chế kể từ mốc mở; level dạy chỉ có một cơ chế (trừ ngoại lệ ghi trong `design.md`).
- **ads:** tần suất interstitial và luật giãn cách (`_ADS`, `src/meta/ad_pacing.gd`), số video có thưởng mỗi ngày và trần; quảng cáo chen vào tutorial hoặc ngay sau mua hàng.

Mọi con số tính bằng script đọc thẳng file level JSON và `src/config.gd`: Node (`node`) hoặc Python qua `uv run --with <gói> python`. Script đặt trong scratchpad, không vào repo.

## Kết quả

1. Bảng đầu vào `FOUND` / `ABSENT`.
2. Bảng bất thường: `file:line`, giá trị, mục tiêu, đề xuất.
3. Luật game mà `tools/sim.mjs` chưa theo, kèm phần kết quả bị ảnh hưởng.
4. Các phần `NOT ASSESSED` và cần gì để đánh giá.
