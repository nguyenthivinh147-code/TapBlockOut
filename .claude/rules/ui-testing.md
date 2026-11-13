---
paths:
  - "src/ui/**"
  - "scenes/**"
  - "assets/**"
  - "data/ui_unity/**"
  - "i18n/**"
  - "**/*.gdshader"
  - "tests/test_ui_*.gd"
  - "tests/shot*.gd"
  - "tests/_shot_*.gd"
---

# Test UI

Thay đổi người chơi nhìn thấy (layout, màu, chữ, icon, animation, VFX) qua hai cổng: test headless đạt, **và** ảnh PNG đã đọc. Test xanh chỉ nói logic đúng; màn hiện đúng hay chưa thì chỉ ảnh trả lời được. Quy trình đầy đủ: `docs/TESTING.md` bước 4, "Tầng 2", "Test case".

Hành vi phải kiểm của màn và popup đang sửa (trạng thái nút, bấm đúp, dim, chạm nền, Back Android, thứ tự popup tự mở, chuỗi popup, chuyển màn nhanh, vòng lặp màn, để yên lâu): checklist `[UI]` và `[EDGE]` trong `.claude/skills/game-testcase-generator/SKILL.md`.

## Chụp

- Luồng chuẩn: `tools/smoke.sh window <kịch bản>` (`tools/affected.sh` in sẵn dòng này). Ảnh ở `output/smoke/window/<kịch bản>/`, chụp lúc màn đã yên, chạm thật có hit-test.
- Ảnh chỉ có khi có cửa sổ (`window`, hoặc `capture=1` trên máy thật); headless không vẽ gì. Case `r.tc_look` chạy headless ra `blocked`, chưa phải pass.
- Tỉ lệ: mặc định 443×960 (cùng tỉ lệ 886×1920). Layout co giãn theo màn thì chụp thêm một tỉ lệ khác bằng `SMOKE_RES`, ví dụ `432x1056` (tỉ lệ máy dài Z Flip5).
- Chữ hoặc bản dịch đổi: chạy thêm kịch bản L (mọi ngôn ngữ trong `Game.LANGS`).
- Màn không có kịch bản: script trong scratchpad `extends "res://tests/smoke/smoke.gd"` (`open_game`, `tap`, `shot`) hoặc `extends "res://tests/_shot_shop.gd"`, chạy có cửa sổ, `-s` nhận đường dẫn tuyệt đối. Save nằm ở `user://` riêng. Chạy sau khi bộ test nền xong, vì hai bên dùng chung file của store giả.
- So trước/sau: `tests/shot.gd --only=<màn>` ghi đè `tests/shots/` (có trong git, nên bản HEAD là ảnh trước). Theme pastel: thêm `--theme=` để chụp ảnh gốc.
- Ảnh tự chụp ghi vào `output/<việc>/`.

## Đọc ảnh

Mở từng PNG liên quan bằng Read; có ảnh ref (Figma, `art/concepts/`) thì đặt cạnh để so. Mỗi ảnh xem:

- Chữ: tràn khung, đè nhau, bị cắt, còn key chưa dịch, ô trắng quanh ký tự. Ký hiệu ngoài atlas Baloo (như `∞`) vẫn qua `test_i18n`, chỉ ảnh mới lộ ra.
- Layout: lệch tâm, ra ngoài màn, đè thanh trên hoặc dưới, thứ tự lớp (popup, dim, toast).
- Ảnh: đúng icon và đúng theme. Theme pastel: twin chưa import thì ảnh gốc hiện thay mà không báo lỗi.
- Trạng thái: nút khoá, mờ, chấm đỏ, số trên màn khớp với save của kịch bản.

`census_<ảnh>.json` chỉ cảnh báo, không làm fail: đọc cảnh báo của nó cùng lúc với ảnh.

## Chạm

- Lỗi "phải bấm mấy lần mới ăn" chỉ smoke hoặc probe bắt được (E2E gọi thẳng signal). Probe: `push_input` một `InputEventMouseMotion` ở toạ độ local trên lưới điểm phủ `get_global_rect()` của nút, rồi `gui_get_hovered_control()`. Mẫu: `tests/test_ui_events.gd` `test_chain_buttons_take_taps`.
- Thủ phạm hay gặp: `clip_children` (Unity Mask) chỉ cắt phần vẽ, vùng nhận chạm vẫn tràn ra. Nút `Bg` / `Continue` phủ cả popup luôn trượt dưới panel: đó là đúng.
- Luật chạm và Back chung có test sẵn bấm thật qua hit-test: `tests/test_ui_tap_rules.gd`, `tests/test_ui_back_rules.gd` (helper `tests/ui_probe.gd`). Màn hoặc nút mới cùng loại thì thêm vào hai file đó; lỗi game chưa sửa ghi vào `KNOWN` đầu file (`docs/TESTING.md` "Tầng 1").
- Mỗi dòng `SMOKE WARN ... trượt` hoặc `(NOT the target ...)` được xếp loại: lỗi smoke (đợi thiếu, chạm sai chỗ) sửa trong smoke; lỗi game (nút bị che) báo người dùng.

## Lỗi chỉ thấy bằng mắt

Cặp ảnh trước và sau thay cho test hồi quy đỏ: cùng màn, cùng cỡ cửa sổ, cùng ngôn ngữ, lưu trong `output/<việc>/`. Phần đo được bằng số (rect, căn giữa, cỡ chữ) thì viết thêm test, như `tests/test_ui_result.gd` `test_win_card_centered`.

## Môi trường

- Editor đang mở chỉ import asset mới và `.translation` khi cửa sổ editor có focus. Ảnh còn hình cũ hoặc hiện key thô: kiểm `.godot/imported/` trước khi nghi code.
- Ký tự mới (CJK, Hangul): chạy `node tools/node/subset_fonts.mjs` rồi `tools/gen_baloo_font.gd`. Cách rẻ hơn: chọn từ đã có glyph (`Font.has_char` trên font và các fallback).
- Smoke giữ `~/.candy_godot.lock`, mỗi lúc một cửa sổ Godot. Lúc cửa sổ smoke đang chạy, để chuột và phím yên (`SMOKE REAL INPUT` làm lần chạy vô hiệu).
- Màn dựng bằng bake: sau bake chạy `tests/test_unity_slim.gd` và kiểm không có node dựng hai lần (tên `@Label@…`); chi tiết `.claude/rules/godot-scene-files.md`.

## Xong khi

- `tools/test.sh <lọc>` đạt.
- `tools/smoke.sh window <kịch bản>` có `SMOKE OK` và `SMOKE ERRORS script=0 engine=0`.
- Mọi ảnh liên quan đã đọc; mọi case `look` có kết quả.
- Báo người dùng: đường dẫn các ảnh đã đọc, điều thấy được, kể cả chỗ chưa đạt.
