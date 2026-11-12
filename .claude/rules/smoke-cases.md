---
paths:
  - "tests/smoke/**"
  - "tests/cases/**"
---

# Kịch bản smoke theo test case

Kịch bản smoke của một tính năng là bản chạy được của `tests/cases/<MODULE>.csv`. Định dạng CSV, cột `AUTO`, `r.tc` / `r.tc_look` / `r.tc_blocked`, cách phân loại case FAIL: `docs/TESTING.md` mục "Test case". Đọc mục đó trước khi viết.

- Viết từ CSV: mỗi case `todo:smoke:<kịch bản>` thành một chỗ chấm có đúng ID, rồi đổi `AUTO` thành `smoke:<kịch bản>`. Bước kịch bản muốn thêm mà không ứng với case nào: thêm case vào CSV trước (form của skill `/game-testcase-generator`, ID nối tiếp), rồi mới viết bước.
- Chấm từng ý của EXPECTED RESULT tại lúc nó thấy được. Số kỳ vọng ghi thẳng từ CSV cạnh ID; `Config` và hàm của game chỉ dùng để dựng save và điều khiển, không để tính kỳ vọng.
- Case `[NEG]` chấm cả hai phần: dữ liệu giữ nguyên và phản hồi UI.
- Case smoke không quan sát được (SDK thật, âm thanh, rung) đổi sang `manual:<lý do>`; case là công thức hay ngưỡng thuần thì đổi sang `todo:unit:test_<file>` hoặc viết unit test cho nó.
- Lỗi game tìm ra: chấm FAIL kèm câu luật trong `design.md` và số thấy được, báo người dùng; sửa game là task riêng (luật test đỏ trước).

Xong khi: `tools/test.sh test_cases` đạt, dòng `CASES <MODULE>` có `todo 0`, `tools/smoke.sh headless <kịch bản>` in `SMOKE CASES ... missing=0`, mỗi case FAIL đã có loại (OQ, lỗi smoke đã sửa, lỗi game), và ảnh của mọi case `look` đã đọc ở lần chạy `window`.
