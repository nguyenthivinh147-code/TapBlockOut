---
paths:
  - "**/*.tscn"
  - "**/*.tres"
  - "**/*.uid"
---

# File scene và resource của Godot

Màn có script dựng UI: sửa script rồi bake lại bằng `tools/bake_screen.gd` theo `docs/UI_NODES.md`. Sửa tay text của scene đã bake chỉ dùng cho chỉnh nhỏ.

Bake:

- Chép `scenes/<tên>.tscn` sang scratchpad trước. `bake_screen.gd` vẫn ghi scene (in "xong") khi script màn lỗi parse; output có `SCRIPT ERROR` thì chép bản cũ về.
- Sau bake chạy `tools/godot.sh --headless --path . -s res://tools/slim_scenes.gd -- res://scenes/<tên>.tscn` (khi editor đóng), rồi `tests/test_unity_slim.gd`.

Sửa text của `.tscn` / `.tres`:

- Giữ nguyên `format=` trong header `[gd_scene]` hoặc `[gd_resource]`.
- Mỗi `[ext_resource]` và `[sub_resource]` có id riêng trong file.
- Copy một node block thì bỏ `unique_id=` của nó.
- Tham chiếu mới để trống `uid=`, cho `--import` (hoặc `filesystem_manage(op="scan")` khi editor mở) gán. Giá trị `uid://` chỉ lấy từ file có sẵn.
- `.uid` đi cùng script: giữ, commit cùng; đổi tên script ngoài editor thì đổi tên `.uid` theo.
- Sửa xong chạy `tools/test.sh` và xem scene đó một lần bằng ảnh (`tools/smoke.sh window <kịch bản>` hoặc `tests/shot.gd`).
