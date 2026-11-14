# Theme pastel (concept A "Sữa dâu oải hương")

Nhánh `Theme_pastel`, làm 2026-11-13. Áp concept A đã duyệt (`output/pastel_concept/sheet_A_final.png`: home_A, level_A, shop_A3) lên asset thật của cả game. Theme gốc (candy xanh tím) giữ nguyên trên nhánh `Theme_candy`; trên nhánh này vẫn xem lại được ảnh gốc bằng `--theme=`.

## Bảng màu và quy tắc

| Vai trò | Màu |
|---|---|
| Nền (trên → dưới) | tím nhạt `#EFD4FC` → đào `#FFDBCE` (`ThemeKit.BG_TOP`, `BG_BOTTOM`; Home có 6 điểm dừng, mục "Home theo ref") |
| Nền màn level | `#F1E3FF` (`ThemeKit.LEVEL_BG`) dưới ảnh `bg_level` 35% |
| Mặt kem | `#FFF6EC` (`ThemeKit.POPUP_CREAM`) |
| Khung popup kem, thẻ shop, mái hiên | tím hồng `#DCBFF2` (đích `lilac`, mục "Khung popup") |
| Khung jelly còn lại | lavender, giữa `#C9B3F5` (đích `lavender` của tool): tab, pill tím, nút vuông, khung minh hoạ, ruy băng thẻ Thua, Leaderboard |
| HUD, tab thanh dưới, nút cài đặt | lavender sáng (đích `lavender_light`), glyph trắng viền tối giữ nguyên |
| Ruy băng tiêu đề, khung ấm | dâu `#FF7FA8` (đích `strawberry`) |
| Chữ tối, panel tối | mận `#4A2A6B` (`ThemeKit.INK`, `PANEL`, chữ thân Unity) |
| Viền chữ | mận `#3A1C6E` (`ThemeKit.TEXT_OUTLINE`, có từ trước) |
| Khay bàn chơi | mận đậm `#3B2A5C` (`ThemeKit.BOARD_BG`), tương phản khối 3,4–6,1:1 |
| Lớp phủ popup | giữ đen 80% (`ThemeKit.SCRIM`; người dùng đã bác phương án mận) |

- Icon vật phẩm (xu, ADS, booster, tim, quà, gói) giữ màu thật; chỉ hạ độ bão hoà phần trên 0,76 (map `icon`), cho tươi mà không chói.
- Chỉ khung, nền, nút trang trí và ruy băng chuyển pastel. Màu mang nghĩa giữ nguyên: nút mua xanh lá, nút xem video xanh dương (`shop.gd` `VIDEO_PILL_COLOR`), pill vàng, dải cảnh báo Hard/VeryHard. Nút đỏ (`pill_red`) thành hồng dâu theo ref Home (mục dưới), vẫn là màu "nguy hiểm/khó".
- Không đổi: khối, mảnh vỡ, cơ chế trên bàn, avatar, khung avatar, minh hoạ Win Streak (giữ ảnh gốc).
- Kẹo của màn chuyển cảnh kẹo rơi (`candy_curtain.gd`, `assets/ui/candy_drop/`, người dùng yêu cầu 2026-11-13) phủ kín màn nên theo tông concept, mỗi loại một màu pastel: bạc hà đỏ → dâu, bạc hà xanh → oải hương, kẹo mút cam → đào, sao vàng → bơ, gumdrop xanh lá → bạc hà, kẹo vuông tím → lilac, kẹo vuông cyan → xanh dương nhạt; tim hồng vốn đã pastel nên giữ ảnh gốc. Trắng và vệt bóng giữ nguyên. Nền lót dưới đống kẹo (`CandyCurtain.BACKING`) là màu cũ đi qua cùng map của loại kẹo đó. `candy_drop_00` còn là icon chạy trên thanh tải của màn loading nên cũng thành bạc hà dâu. Ảnh trước/sau: `output/candy_curtain_theme/` (gitignored).

## Cơ chế

- Ảnh theme là **twin**: `res://assets/<đường dẫn>` có bản `res://assets/themes/pastel/<cùng đường dẫn>`. Cùng kích thước, cùng vùng atlas, cùng margin 9-slice, cùng tham số import (size limit, nén).
- Autoload `ThemeAssets` (`src/ui/theme_assets.gd`) đứng ngay sau `_mcp_game_helper`, trước `Platform`. Lúc `_init` nó quét thư mục theme và đăng ký `src/ui/theme_loader.gd` (một `ResourceFormatLoader`) lên đầu danh sách loader. Từ đó mọi đường nạp ảnh gốc trả về twin: `ext_resource` trong scene đã bake, `load()`, `preload()` của script nạp sau, `UiAtlas`. Không sửa scene nào để trỏ sang ảnh mới.
- Tên theme: `Config.UI_THEME` (`"pastel"` trên nhánh này, `""` là ảnh gốc). Bản debug nhận tham số `--theme=<tên>`; `--theme=` (rỗng) cho ảnh gốc để chụp so sánh.
- Twin chưa import (clone mới, editor chưa chạy) bị bỏ qua, ảnh gốc hiện thay vì lỗi nạp. `tests/test_theme_assets.gd` bắt trường hợp này: mọi file trong thư mục theme phải nạp được.
- Màn boot splash do engine vẽ trước khi script chạy nên không qua loader (`application/boot_splash/image` vẫn là ảnh gốc).
- Màu vẽ bằng code (hằng `ThemeKit`, gradient trong scene, màu chữ của scene Unity đã bake) đổi thẳng trên nhánh, không theo `--theme=`. Tint khoá cũng nhạt đi cho hợp nền sáng: tab thanh dưới `HubNav.LOCKED_TINT` trắng (không tô, theo ref Home; gốc `(0.7, 0.7, 0.78)`), ô booster `level.gd` `LOCKED_TINT` `(0.72, 0.7, 0.8)` (gốc `(0.55, 0.55, 0.62)`).

## Home theo ref Figma "2.1 Home" (node `106:385`, 2026-11-13)

Ảnh ref (bản vẽ lại Home bằng AI, đúng bố cục game, 886×1920) lưu ở `art/concepts/ref_home_pastel_106_385.png`. Người dùng yêu cầu màu và icon giống hệt ref; chọn mốc hình hoa, **giữ hào quang vàng** sau mốc hiện tại (ref không có), đổi phần dùng chung ở mọi màn, icon khoá giữ đủ màu.

- Mốc level: hoa kẹo 6 cánh, viền kem. Khoá tím nhạt (`hex_gray`, `node_gray`), Khó hồng dâu (`hex_red`), đã qua bạc hà (`hex_blue`); Thường xanh lá (`hex_green`, `node_green`) và Rất khó tím (`hex_purple`) đổi màu từ mốc hồng vì ref không có. Dùng chung cho Road Trip. Nguồn: 3 mốc cắt từ ref (`art/images/pastel_node_ref_n23/n22/n24.png`), ComfyUI `edit_game_image` xoá số, đầu lâu, dấu tích, ổ khoá, dựng lại cánh bị che, nền xanh đậm phẳng (`art/images/pastel_node_src_*.png`, `art/manifest.json`); `tools/make_pastel_home.py` tách nền, đổi màu, co về đúng cỡ trên màn của ref theo vùng atlas, ghi `art/themes/pastel/node_*.png`.
- Số trên mốc (`home.gd`, `road_trip_map.gd`): khoá chữ `#FBEAFF` viền `#A57BBE`; đã qua viền `#366869`; Khó `#6C133F`; Thường `#2D5E12`; Rất khó giữ `#4B1073`.
- Ray kẹo `home_rail_straight.png`: sọc hồng trắng lấy thẳng từ ref (cột x 411..475 trùng `RAIL_RECT`, một chu kỳ 91 px lặp lại). `TopShade` dời xuống dưới ray và mốc để không làm nhạt mốc trên cùng.
- Nền Home: 6 điểm dừng đo trên ref (0 `#EFD4FC`, 0,18 `#F4DAFA`, 0,34 `#FBDFEF`, 0,5 `#FEE4E5`, 0,68 `#FFE3D8`, 0,84 `#FFDBCE`); `TopShade` cùng màu đỉnh.
- Ổ khoá `ic_lock` tím xám (map `lock`), nút đỏ `pill_red` và `pill_red_96` hồng dâu (map `pill_pink`), ô sáng thanh dưới vàng bơ (map `highlight`), tab tím thanh dưới sáng hơn (map `frame_nav`, `#DABAFB`), ribbon cột `home_banner` đào mơ `#FCA684` viền cam đất `#D87652` (map `label`: thân vàng → `peach`, viền cam → `peach_rim`; bản đào nhạt `#FEDFCE` đầu tiên chìm vào nền nên đậm lên 2026-11-13), lịch `ic_dailygift` viền xanh nhạt (map `calendar`).
- Màu code: viền chữ ribbon cột (`home.gd` `HOME_INK`), chữ nút Chơi khi Hard ở Road Trip (`road_trip.gd`; nút Chơi ở Home theo tông nút, xem "Level Thường" dưới) và chữ tab đang mở (`HubNav.CAPTION_STROKE`) mận `#3E0B3A`; chấm đỏ thông báo `ThemeKit.DANGER` `#FF636F`.
- Chip mạng và vàng ở thanh trên (mọi màn có `HubTop`): ảnh `assets/ui/figma/hub_chip.png` (không có twin; trước là `StyleBoxFlat` trong `hub_top.tscn`, nay chỉ còn làm dự phòng) do `tools/make_pastel_home.py` vẽ theo dải màu đo dọc chip của ref: viền trên tím nhạt mảnh, dải trắng, thân kem đào ấm dần xuống, mép dưới nâu hồng, viền đáy tím đậm, bóng tím mờ bên dưới. Vẽ ở 3× px thiết kế (thân 70, bóng 8); `HubTop.chip_box` co ảnh theo cao thanh (cache theo px), 9-slice ngang giữ hai đầu tròn, bóng vẽ ra dưới thanh bằng `expand_margin_bottom`. Chữ trong chip mận `#43173F`.
- Icon cột đang khoá (Bảng xếp hạng, Daily Challenge) giữ màu, chỉ có ổ khoá và chữ "Level N".
- Level Thường (2026-11-13, người dùng chọn "giảm nhẹ" trong `art/concepts/concept_home_normal_tier_v3.png` sau hai lượt phương án `_v1`, `_v2`): mốc xanh lá bớt chói (hue 100, saturation ×0,70, value ×0,95 so với mốc hồng; `hex_green`, `node_green`, cả Road Trip). Nút Chơi ở level thường dùng ảnh riêng `assets/ui/figma/home_play_normal.png` (bản sao `pill_green` của atlas, `home.gd` `PLAY_NORMAL_ART`), twin pastel đổi màu bằng map `play_green` (xanh táo `#9BDA69` ở giữa nút, giữ sọc xoắn, vệt bóng, viền của nút gốc). Các nút xanh khác dùng cùng sprite đó (2026-11-13, người dùng yêu cầu; trước đó chỉ đổi nút Chơi ở Home): map `play_green` đổi các vùng pill xanh `pill_green` (0,816,380,168) và `pill_green_white` (384,816,368,168) của `atlas_main.png` (nút `ThemeKit` kiểu `primary`: Shop, nút Level Road Trip), cùng hai vùng ấy của `cc/Resources_moved_UI_Maincenter.png` (`UI_Maincenter_48`, `_57`: nút xanh của popup Unity, `UnityKit` `green`), `pill/pill_green_96.png`, pill nhỏ viền kem `UI_Shop_Popup_Atlas_8` (816,767,204,100: nút Free, Claim của popup gói) và nút vuông `UI_Maincenter_30` của `cc/Resources_UI_Maincenter.png` (1792,809,256,270: nút mua của Shop, gói). Vùng `pill_green` của atlas là bản gốc của ảnh nút Chơi nên twin trùng từng pixel; nút vuông và pill nhỏ khác hình nên chỉ cùng tông xanh táo, giữ sọc, bóng, viền của chính chúng. Chữ PLAY và chữ độ khó trên nút Chơi ở Home viền và bóng cùng tông nút (2026-11-13, người dùng yêu cầu; trước đó mận `HOME_INK` ở Thường và Hard): dùng màu viền số của mốc hiện tại (`home.gd` `TIERS.num`): Thường xanh lá đậm `#2D5E12`, Khó mâm xôi đậm `#6C133F`, Rất khó tím đậm `#4B1073`.

## Icon booster Claymorphism (2026-11-13)

Ba icon vật phẩm `booster_hint` (bóng đèn), `booster_move` (+3), `booster_smash` (búa kẹo mút) vẽ lại theo concept Claymorphism (skill `ui-ux-pro-max`: khối 3D mềm, mập, bo tròn, bóng nhẹ). Bảng 3 phương án `art/concepts/concept_booster_clay_v1.png`; người dùng chọn **B** (đất sét satin, viền mảnh cùng tông) và yêu cầu màu tươi hơn một chút.

- Nguồn AI: `art/images/booster_<tên>_clay_ai.png` (ComfyUI `edit_game_image`, `<image1>` là icon gốc; prompt, seed trong `art/manifest.json`, mục `pastel_booster_*`).
- `tools/fit_icon.gd --size=256 --margin=0.06 --floor=12`, rồi `tools/pastel_booster_boost.py` tăng độ bão hoà `1 - (1 - s)^1,5` (kem, trắng giữ nguyên); búa thêm `--pink-only --pink-shift=-14` để hồng san hô thành hồng dâu thay vì ngả đỏ. Kết quả ở `art/themes/pastel/booster_*.png`.
- `tools/theme_pastel.json`: ba rule `ui/booster_*.png` có `"source"` trỏ tới ảnh trên và giữ `"map": "icon"` (trần độ bão hoà 0,76 như icon vật phẩm khác). Sinh lại: `tools/theme_recolor.py tools/theme_pastel.json --only ui/booster_`.
- Chỉ đổi twin; ảnh gốc `assets/ui/booster_*.png` giữ cho theme candy. Chưa đổi theo: nút booster HUD (`hud_booster_*`), icon booster trong ảnh gói (`art_level_pack*`, `art_starter_pack`, `art_no_ads_bundle`), `cc/ic_booster*`, `figma/ic_booster*` và búa hiệu ứng `fx_lollipop_hammer`.

## Khung popup (2026-11-13)

Theo ref người dùng gửi (popup Cài đặt vẽ lại): viền khung tím hồng thay lavender ngả xanh, ruy băng tiêu đề có mép dưới đậm và bóng đổ xuống mặt kem. Đo trên ref: thân viền `#DEC2F4` (hue 274), mép ngoài `#BE9BD8`, ruy băng mặt `#F69BAA`, mép dưới đậm dần tới `#E18293` trong khoảng 15% chiều cao, bóng hồng nâu trên kem (`#E8B6AA` sát ruy băng).

- Khung: map `frame_lilac` (xanh, cyan, tím, magenta → đích `lilac`: hue 274, saturation ×0,37 trần 0,30, lift 0,55) cho các khung kem dùng chung: `cc/Popup2.png` (popup Unity) và `figma/popup_frame1/2/3.png` (`popup_kit.gd`). Giữ sọc chéo, vệt sáng, viền của ảnh gốc. Khung có minh hoạ riêng (`PopupDailyRewardAd`, `Popup_SpecialPack`, `BG_Winstreak`, thẻ Thắng/Thua) vẫn `lavender`.
- Thẻ shop và mái hiên cũng `frame_lilac` (2026-11-13, người dùng yêu cầu: thẻ gold trong popup Cần thêm gold lệch tông với viền popup mới): vùng thẻ gold nhỏ (0,150 132×180), thẻ gold lớn (0,340 466×256), mái hiên (0,808 1024×216) của `cc/UI_Shop_Atlas.png`; thẻ gói (0,0 và 0,633 512×312) và nút mũi tên (0,948 108×76) của `cc/UI_Shop_Packs_Atlas.png`. Thẻ hồng (136,150, `frame_warm`) giữ nguyên. Ảnh trước, sau: `output/popup_frame/cmp_shop_lilac.png`, `cmp_shop_scroll.png`.
- Ruy băng tiêu đề (vùng 384,1332 368×108: `UI_Maincenter_60` của `cc/Resources_moved_UI_Maincenter.png` cho mọi popup Unity, `label_purple` của `figma/atlas_main.png` cho `popup_kit.gd`, 9-slice lề dưới 22): `tools/make_pastel_popup.py` lấy vùng gốc của từng atlas, đổi màu bằng map `ribbon`, co ruy băng còn 360×100 (chừa 8 hàng dưới cho bóng, 4 cột mỗi đầu cho bóng tròn theo hai đầu), làm đậm dải 16 hàng sát mép dưới (value −12%, saturation +0,12 ở mép), đặt bóng (bóng ruy băng dời xuống 5 px, mờ 2,5 px, hồng `#C45270` alpha 0,55) dưới ruy băng. Ghi `art/themes/pastel/popup_title_maincenter.png`, `popup_title_main.png`; `tools/theme_pastel.json` đặt chúng lên vùng bằng `"overlays"`.
- Sinh lại: chạy `make_pastel_popup.py` rồi `theme_recolor.py ... --only Resources_moved_UI_Maincenter` và `--only figma/atlas_main`. Ảnh trước, sau, ref: `output/popup_frame/`.

## Tool `tools/theme_recolor.py`

```bash
uv run --no-project --with numpy --with pillow --with scipy python -I tools/make_pastel_home.py                    # art tay: mốc hoa, ray (art/themes/pastel/)
uv run --no-project --with numpy --with pillow --with scipy python -I tools/make_pastel_popup.py                   # art tay: ruy băng tiêu đề popup có bóng
uv run --no-project --with numpy --with pillow python -I tools/theme_recolor.py tools/theme_pastel.json          # sinh twin
uv run --no-project --with numpy --with pillow python -I tools/theme_recolor.py tools/theme_pastel.json --code   # màu trong code
tools/godot.sh --headless --path . --import                                                                      # import twin (editor đóng)
```

- Đổi màu tất định, không dùng AI: mỗi pixel thuộc một họ sắc (`families`: red, orange, yellow, green, cyan, blue, purple, magenta; `candy_*` cho kẹo rơi) được đưa về họ đích (`targets`: lavender, lilac, lavender_light, lavender_nav, strawberry, peach, peach_rim, butter, butter_bright, pink_pill, lilac_steel, periwinkle, `candy_*`): hue về hue đích, saturation nhân và chặn trần, value nâng `1 - (1 - v) × lift` nên bóng đổ, viền tối, vệt sáng giữ thứ tự. Trọng số mờ dần ở mép họ sắc và ở saturation thấp, nên trắng, kem, viền xám không đổi và không có đường nối.
- `maps`: `frame` (xanh, cyan, tím, magenta → lavender), `frame_lilac` (cùng họ → tím hồng `lilac`: khung popup kem, thẻ shop, mái hiên), `frame_light` (cùng họ → lavender sáng), `frame_nav` (cùng họ → tím tab thanh dưới), `frame_warm` (thêm cam → dâu), `ribbon` (mọi họ trừ đỏ, xanh lá → dâu), `label` (vàng → đào, cam → viền đào đậm), `pill_pink` (đỏ, magenta → hồng dâu), `lock` (xanh → tím xám), `highlight` (vàng, cam → vàng bơ), `calendar` (xanh → xanh nhạt), `play_green` (xanh lá, vàng → xanh táo `apple_play`, mọi nút xanh lá), `icon` (chỉ hạ saturation trên `icon_sat_cap`), `candy_*` (kẹo rơi, mỗi loại một map).
- Họ sắc có `half` 180 phủ cả vòng hue (`candy_red`, `candy_cyan`, ...): đặt `centre` ở hue chính của một ảnh một màu thì cả ảnh về một đích, `keep_hue` giữ một phần độ lệch hue quanh tâm đó. Đích của kẹo đặt `sat` = `sat_max` nên saturation chỉ bị nhân, không chạm trần: kẹo vẽ bóng bằng saturation (cyan, vàng gần như S 1 cả viên) vẫn giữ thứ tự sáng tối.
- `files`: `"map"` cho cả file, `"regions": [[x, y, w, h, map], ...]` cho atlas (chỉ đổi trong các ô đó; chạy sau `map`). Ô lấy từ inventory (dưới). Art làm tay vào qua `"source": "<đường dẫn từ gốc repo>"` (thay cả ảnh trước khi đổi màu, cùng cỡ) và `"overlays": [[x, y, w, h, "<đường dẫn>"], ...]` (thay cả màu lẫn alpha một ô sau khi đổi màu, ảnh đúng w×h). Xoá một rule thì lần chạy sau xoá twin tương ứng (so đường dẫn đã chuẩn hoá, chạy được trên Windows). `--only <chuỗi>` chỉ sinh lại file có chuỗi đó trong đường dẫn và không xoá gì. Twin có pixel không đổi thì không ghi lại (zlib, Pillow khác máy nén khác byte).
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
