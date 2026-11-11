# Godot: tài liệu tham chiếu theo phiên bản

Bản dùng: **Godot 4.7.2** (Windows, chạy qua `tools/godot.sh`, biến `GODOT` trỏ tới file exe), renderer `gl_compatibility`, đích Android.

Các file trong thư mục này lấy từ [Claude Code Game Studios](https://github.com/donchitos/claude-code-game-studios) 1.2.0 (MIT, `LICENSE-CCGS`). Tác giả xác minh lần cuối 2026-10-17 cho phần 4.7, 2026-02-12 cho phần còn lại.

Dùng khi không chắc về một API, đặc biệt các thay đổi từ 4.5 trở đi:

- `deprecated-apis.md`: API cũ và API thay thế.
- `breaking-changes.md`: thay đổi phá vỡ theo từng phiên bản.
- `current-best-practices.md`: tính năng và cách làm mới.
- `modules/`: ui, rendering, animation, audio, input.

Chuẩn cuối cùng là chính engine đã cài. Tra bằng `tools/godot.sh --doctool <thư mục scratchpad>`, rồi đọc `doc/classes/<Class>.xml`. Tài liệu này mâu thuẫn với doctool thì tin doctool.

Phần gdUnit4 trong `current-best-practices.md` chỉ để tham khảo: dự án này không dùng gdUnit4, test chạy bằng `tests/run_all.gd` (`docs/TESTING.md`).
