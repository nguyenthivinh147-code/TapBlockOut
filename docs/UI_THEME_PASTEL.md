# Theme pastel (concept A "Sữa dâu oải hương")

Nhánh `Theme_pastel`, làm 2026-11-13. Áp concept A đã duyệt (`output/pastel_concept/sheet_A_final.png`: home_A, level_A, shop_A3) lên asset thật của cả game. Theme gốc (candy xanh tím) giữ nguyên trên nhánh `Theme_candy`; trên nhánh này vẫn xem lại được ảnh gốc bằng `--theme=`.

## Bảng màu và quy tắc

| Vai trò | Màu |
|---|---|
| Nền (trên → dưới) | lavender `#E9D9FF` → hồng đào `#FFE3EC` (`ThemeKit.BG_TOP`, `BG_BOTTOM`) |
| Nền màn level | `#F1E3FF` (`ThemeKit.LEVEL_BG`) dưới ảnh `bg_level` 35% |
| Mặt kem | `#FFF6EC` (`ThemeKit.POPUP_CREAM`) |
| Khung jelly | lavender, giữa `#C9B3F5` (đích `lavender` của tool): khung popup, thẻ shop, mái hiên |
| HUD, tab thanh dưới, nút cài đặt | lavender sáng (đích `lavender_light`), glyph trắng viền tối giữ nguyên |
| Ruy băng tiêu đề, khung ấm | dâu `#FF7FA8` (đích `strawberry`) |
| Chữ tối, panel tối | mận `#4A2A6B` (`ThemeKit.INK`, `PANEL`, chữ thân Unity) |
| Viền chữ | mận `#3A1C6E` (`ThemeKit.TEXT_OUTLINE`, có từ trước) |
| Khay bàn chơi | mận đậm `#3B2A5C` (`ThemeKit.BOARD_BG`), tương phản khối 3,4–6,1:1 |
| Lớp phủ popup | giữ đen 80% (`ThemeKit.SCRIM`; người dùng đã bác phương án mận) |

- Icon vật phẩm (xu, ADS, booster, tim, quà, gói) giữ màu thật; chỉ hạ độ bão hoà phần trên 0,76 (map `icon`), cho tươi mà không chói.
- Chỉ khung, nền, nút trang trí và ruy băng chuyển pastel. Màu mang nghĩa giữ nguyên: nút mua xanh lá, nút đỏ, nút xem video xanh dương (`shop.gd` `VIDEO_PILL_COLOR`), pill vàng, dải cảnh báo Hard/VeryHard, viền số level đã qua `076F87`.
- Không đổi: khối, mảnh vỡ, cơ chế trên bàn, avatar, khung avatar, kẹo rơi, minh hoạ Win Streak (giữ ảnh gốc).

## Cơ chế

- Ảnh theme là **twin**: `res://assets/<đường dẫn>` có bản `res://assets/themes/pastel/<cùng đường dẫn>`. Cùng kích thước, cùng vùng atlas, cùng margin 9-slice, cùng tham số import (size limit, nén).
- Autoload `ThemeAssets` (`src/ui/theme_assets.gd`) đứng ngay sau `_mcp_game_helper`, trước `Platform`. Lúc `_init` nó quét thư mục theme và đăng ký `src/ui/theme_loader.gd` (một `ResourceFormatLoader`) lên đầu danh sách loader. Từ đó mọi đường nạp ảnh gốc trả về twin: `ext_resource` trong scene đã bake, `load()`, `preload()` của script nạp sau, `UiAtlas`. Không sửa scene nào để trỏ sang ảnh mới.
- Tên theme: `Config.UI_THEME` (`"pastel"` trên nhánh này, `""` là ảnh gốc). Bản debug nhận tham số `--theme=<tên>`; `--theme=` (rỗng) cho ảnh gốc để chụp so sánh.
- Twin chưa import (clone mới, editor chưa chạy) bị bỏ qua, ảnh gốc hiện thay vì lỗi nạp. `tests/test_theme_assets.gd` bắt trường hợp này: mọi file trong thư mục theme phải nạp được.
- Màn boot splash do engine vẽ trước khi script chạy nên không qua loader (`application/boot_splash/image` vẫn là ảnh gốc).
- Màu vẽ bằng code (hằng `ThemeKit`, gradient trong scene, màu chữ của scene Unity đã bake) đổi thẳng trên nhánh, không theo `--theme=`. Tint khoá cũng nhạt đi cho hợp nền sáng: tab thanh dưới `HubNav.LOCKED_TINT` `(0.9, 0.88, 0.95)` (gốc `(0.7, 0.7, 0.78)`), ô booster `level.gd` `LOCKED_TINT` `(0.72, 0.7, 0.8)` (gốc `(0.55, 0.55, 0.62)`).

## Tool `tools/theme_recolor.py`

```bash
uv run --no-project --with numpy --with pillow python -I tools/theme_recolor.py tools/theme_pastel.json          # sinh twin
uv run --no-project --with numpy --with pillow python -I tools/theme_recolor.py tools/theme_pastel.json --code   # màu trong code
tools/godot.sh --headless --path . --import                                                                      # import twin (editor đóng)
```

- Đổi màu tất định, không dùng AI: mỗi pixel thuộc một họ sắc (`families`: red, orange, yellow, green, cyan, blue, purple, magenta) được đưa về họ đích (`targets`: lavender, strawberry, cream, butter): hue về hue đích, saturation nhân và chặn trần, value nâng `1 - (1 - v) × lift` nên bóng đổ, viền tối, vệt sáng giữ thứ tự. Trọng số mờ dần ở mép họ sắc và ở saturation thấp, nên trắng, kem, viền xám không đổi và không có đường nối.
- `maps`: `frame` (xanh, cyan, tím, magenta → lavender), `frame_light` (cùng họ → lavender sáng), `frame_warm` (thêm cam → dâu), `ribbon` (mọi họ trừ đỏ, xanh lá → dâu), `label` (cam, vàng → kem), `icon` (chỉ hạ saturation trên `icon_sat_cap`).
- `files`: `"map"` cho cả file, `"regions": [[x, y, w, h, map], ...]` cho atlas (chỉ đổi trong các ô đó). Ô lấy từ inventory (dưới). Xoá một rule thì lần chạy sau xoá twin tương ứng. `--only <chuỗi>` chỉ sinh lại file có chuỗi đó trong đường dẫn.
- `.import` của twin chép tham số từ ảnh gốc nhưng giữ `uid`, `path` của twin đã có, nên chạy lại không đổi uid; ảnh đổi thì Godot tự import lại (cần `--import` hoặc mở editor).
- `code_colors`: `{màu cũ: màu mới}` viết lại trong `data/ui_unity/*.json` (hex), scene (`Color(...)`, `PackedColorArray`, khớp theo giá trị 8 bit) và `src/**/*.gd`. Chạy lại không đổi gì thêm. Danh sách hiện có: chữ thân xanh mực `1c4a83` → mận `4a2a6b`; chữ nhấn xanh `166dcc`, `126dcc` → `7a4fc0`; chữ mô tả `476b97`, `295487` → `6b4f8a`; dải tab `1f3e7e`, chữ hướng dẫn `27306a` → `4a2a6b`; nền Road Trip `5a70e0` → `b9a0f0`; nền xanh `3967bf`, `3454ac` → `e9d9ff`, `7b9edd`, `dee1f2` → `ffe3ec`.

## Inventory: màn nào vẽ ảnh nào

`tests/shot_inventory.gd` (con của `tests/shot.gd`) mở khoảng 80 màn và popup, đi cây node đang hiện, ghi mọi texture (đường dẫn, vùng atlas, margin 9-slice, rect trên màn, màu tint), stylebox, `ColorRect`, màu chữ và tham số shader, kèm ảnh chụp 886×1920. Chạy có cửa sổ trong Xephyr vì cửa sổ cao hơn màn 1440p:

```bash
DISPLAY=:0 Xephyr :53 -screen 900x1940 -ac -br -noreset &
DISPLAY=:53 tools/godot.sh --path . --resolution 886x1920 -s res://tests/shot_inventory.gd -- --lang=vi --dest=$PWD/output/asset_export/after
# thêm --theme= để chụp ảnh gốc
```

Kết quả lần làm theme (gitignored): `output/asset_export/before/` (ảnh gốc), `after/` (theme pastel), `before/textures.json` (129 texture đang vẽ, gộp theo vùng), `atlas_map/` (atlas có khung đỏ: vùng 9-slice đang dùng, xanh: vùng đang dùng không viền, xám: sprite chưa dùng), `compare_key.png` (Home, Level, Shop: trước, sau, concept).
