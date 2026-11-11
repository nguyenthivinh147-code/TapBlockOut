---
paths:
  - "**/*.gd"
  - "**/*.gdshader"
---

# Code Godot

- Kế hoạch (`plans/PLAN_tap-block-out-godot-android.md` mục 1.3) và `CLAUDE.md` thắng lời khuyên Godot chung: logic trong `src/core`, `src/meta` là `RefCounted` thuần, số trong `src/config.gd`, script nạp nhau bằng `preload`.
- API từ 4.5 trở lên mà không chắc: đọc `docs/godot/VERSION.md` rồi file nó chỉ tới, trước khi viết.
- Renderer là `gl_compatibility` cho cả desktop lẫn mobile. Tính năng chỉ có trên Forward+/Mobile (compute shader, GPU particles nâng cao, một số hàm shader) phải xác nhận chạy trên renderer này.
- Ripgrep không có type `gdscript`: lọc bằng `--glob "*.gd"`.
- Smoke luôn chạy qua `tools/smoke.sh`: script giữ khoá `~/.candy_godot.lock` để các phiên song song không tranh cửa sổ và `user://smoke_*`.
