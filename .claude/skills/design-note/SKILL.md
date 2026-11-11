---
name: design-note
description: "Ghi luật và số của một hệ thống Candy Away vào design.md: thiết kế mới trước khi code tính năng có luật hoặc số mới (new), hoặc suy ngược từ code đang chạy (reverse)."
argument-hint: "<hệ thống> [new|reverse]"
---

Đích là **một mục của `design.md`**: luật chơi, con số, nội dung đều ở đó và `design.md` thắng. Tên file, interface, cấu trúc thư mục, thứ tự việc thuộc `plans/PLAN_tap-block-out-godot-android.md`; note nào kéo theo đổi interface thì ghi "cần sửa kế hoạch mục 1.x" để sửa trong cùng thay đổi.

`design.md` có nhiều phiên cùng sửa: đọc lại đoạn cần sửa ngay trước mỗi Edit, sửa từng đoạn nhỏ.

## Bước

1. **Tìm chỗ.** `grep -n "^## \|^### " design.md`. Hệ thống đã có mục thì sửa mục đó; chưa có thì thêm `###` dưới mục `##` hợp (3 Luật chơi, 4 Level, 5 Kinh tế, 6 Quảng cáo, 7 Mua hàng và offer, 8 Kỹ thuật).
2. **Thu thập.**
   - `new`: hỏi người dùng tối đa 3 câu về điều code không trả lời được (cảm giác muốn tạo, giới hạn phạm vi). Phần còn lại tự đề xuất và gắn nhãn "đề xuất, chờ duyệt".
   - `reverse`: đọc `src/core/`, `src/meta/`, `src/game/`, `src/ui/` và bảng số trong `src/config.gd`. Ghi đúng những gì code đang làm, dẫn `file:line`. Chỗ không rõ là cố ý hay lỗi thì ghi `CHƯA RÕ Ý ĐỊNH` để người dùng quyết.
3. **Viết mục**, giữ giọng và cách trình bày của các mục xung quanh. Nội dung cần có:
   - **Mục tiêu người chơi:** một đoạn, người chơi cảm thấy gì, vì sao hệ thống tồn tại.
   - **Luật:** không nhập nhằng, gồm cả trường hợp biên.
   - **Công thức và số:** định nghĩa biến, giá trị ở hai đầu khoảng.
   - **Núm chỉnh:** khoá trong `src/config.gd` (ví dụ `Config._ECON`), khoá Remote Config nếu có (`docs/HORUS_HANDOFF.md` mục 4), khoảng an toàn.
   - **Chữ hiển thị:** key `tr("KEY")` mới, thêm vào `i18n/strings.csv` khi code.
   - **Xong khi:** test nào (`tests/test_<x>.gd`), kịch bản smoke nào, màn nào phải đúng; đủ số case tối thiểu theo `docs/TESTING.md` mục "Ma trận bao phủ".

   Khi note dẫn tới code: số mới vào `src/config.gd`, logic thuần vào `src/core/` hoặc `src/meta/` (`extends RefCounted`, không `Node`, không `Platform`, không đọc giờ hệ thống).
4. **Ghi nhật ký.** Thêm một bullet cuối `design.md` mục 9 "Nhật ký quyết định", theo kiểu các dòng gần nhất: `- <Việc> (<ai quyết>, YYYY-MM-DD; mục <n> "<tên mục>"; kế hoạch Task <x> nếu có): <quyết định>, <lý do>.`

## Xong khi

Mục trong `design.md` có luật, số kèm khoá config, và điều kiện "Xong khi" kiểm được bằng test hoặc smoke; mục 9 có dòng mới. Báo người dùng mục nào đã đổi, cùng mọi chỗ `CHƯA RÕ Ý ĐỊNH` (`reverse`) hoặc "đề xuất, chờ duyệt" (`new`).
