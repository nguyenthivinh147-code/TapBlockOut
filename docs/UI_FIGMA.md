# UI theo Figma "Tapblock"

> Từ nay chỉ Home, bàn chơi và HUD trong level, thanh trên (`hub_top.gd`) và thanh dưới (`hub_nav.gd`) còn theo tài liệu này. Mọi màn và popup khác dựng theo prefab Unity của color-cube-match-puzzle: xem `docs/UI_UNITY.md`. Phần "Màn chưa nối logic" bên dưới (stub, `Config.ui_preview`, dữ liệu mẫu) vẫn áp dụng cho mọi màn.

Nguồn: file Figma `Tapblock`. Layout lấy từ page **Overview** (wireframe 11 nhóm, khung 390x844). Màu, chữ, component, icon lấy từ page **02 · Foundations**.

## Quy tắc

- Mọi chữ hiển thị qua `tr()`. Không dùng ảnh có chữ "nướng" sẵn (nút PLAY, tab HOME, tiêu đề popup, giá OK/100...). Chỉ dùng sprite không chữ.
- Màu, cỡ chữ, nút, ô nền nằm ở `src/ui/theme_kit.gd`, khớp bảng Colors trong Foundations.
- Sprite cắt từ atlas nằm ở `src/ui/ui_atlas.gd` (bảng `REGIONS`, toạ độ lấy từ bounds node trong Figma). Atlas và icon nằm ở `assets/ui/figma/`.
- Nút viên thuốc cỡ thường dùng `assets/ui/figma/pill/*_96.png`, sinh bằng `tools/gen_ui_sprites.gd` (cắt từ atlas, thu về cao 96px để đầu tròn đúng tỉ lệ khi 9-slice). Sửa atlas thì chạy lại tool rồi `--import`.
- Icon `ic_*` tìm thấy trực tiếp theo tên. Tên cũ ánh xạ sang icon Figma qua `ThemeKit.FIGMA_ICON`, bảng này ưu tiên hơn file trong `assets/ui/`.
- Popup dựng bằng `src/ui/popup_kit.gd`: nền mờ, khung kem, ribbon tiêu đề, nút X. Chữ trên thân kem dùng `ThemeKit.ink_label` hoặc `PopupKit.text`, số vàng dùng `ThemeKit.gold_label`.
- Màn có khung hi-fi (frame 886×1920, như node `47:3486`: Setting, Ingame Setting, Language, Profile) dựng bằng `PopupKit.make_fig`: số trong code là px đọc thẳng từ Figma, gốc là góc trên trái popup, cả khối thu theo `PopupKit.FIG_SCALE` (720/886). Đặt phần tử bằng `fig_box`, `fig_text`, `fig_icon`, `fig_button`, `fig_toggle`, `fig_link`. `fig_button` co sprite atlas về đúng cao nút (`UiAtlas.fit_box`) nên đầu tròn không méo, và nới vùng chạm lên 96 px màn hình mà hình nút vẫn đúng cỡ Figma. Chữ dài (tiếng Việt) tự thu cỡ cho vừa.
- Home, Shop, Leaderboard dùng chung `src/ui/hub_top.gd` (avatar, mạng, vàng, settings) và `src/ui/hub_nav.gd` (Shop, Home, Ranking). Shop và Leaderboard ẩn avatar và settings (`hide_side_buttons()`), chỉ còn mạng và vàng.
- Thanh dưới chia ba ô bằng nhau (886/3, khác Figma 338/274, theo video ref chuyển tab). Mỗi ô có nền tím đứng yên (`ShopPanel`, `HomePanel`, `RankingPanel`, nằm ngoài nút), sát mép ô, không khe giữa các ô (`SLOT_INSET` 0), cao 151 (`PANEL_H`). Tab đang mở có một ô sáng vàng cao 189 (`HIGHLIGHT_H`, `Highlight`). Ảnh nền tím và vàng có 11 và 7 hàng trong suốt ở đáy nên hai nền chạy quá đáy thanh (248) đúng chừng đó, không lộ nền màn bên dưới, vẽ trên nền tím, dưới icon; icon 168 nhô lên, chữ dưới icon. Hai tab còn lại icon 96.
- Chuyển tab (nhịp đo từ video ref): mỗi màn dựng thanh dưới mới, thanh nhớ tab mở trước (`HubNav.last_tab`).
  - Khác tab thì ô sáng trượt ngang 0.33 s (quart ease-out) từ ô cũ sang ô mới, đi qua ô ở giữa nếu cách hai ô.
  - Từ 0.12 s, trong 0.2 s, icon cũ co về 96 và hạ xuống; icon mới to lên 168, nhô lên, hơi vượt (`TRANS_BACK`); chữ hiện dần.
  - Cùng lúc `main.gd` trượt màn: màn mới vào từ phía tab của nó, màn cũ ra phía kia, cùng 0.33 s quart ease-out. Thanh trên và thanh dưới của màn mới đứng yên (ghim ngược lại độ dời của màn), thanh của màn cũ ẩn. Chạm và Back chờ tới khi trượt xong; một lần `go()` mới kết thúc ngay lần trượt đang chạy. Chỉ trượt giữa Shop, Home, Leaderboard.
  - Bấm tab thì nút lún 0.92 trong 0.1 s, thả ra bật lại.
- Glow sau mốc level hiện tại ở Home phập phồng như tia sáng trong popup (`src/ui/ui_motion.gd`, xem `docs/UI_UNITY.md`).

## Home (Figma section "Meta", node 18:37)

- Ba khung "main menu" 886x1920 theo độ khó của level hiện tại: thường (22:17528), Hard (22:17393), Super Hard (22:17460). Dải ADS 120 ở đáy không thuộc UI game, nên khung tính là 886x1800.
- `src/ui/figma_box.gd` đặt node theo toạ độ Figma và co theo `s = rộng màn / 886` (720 px: s ≈ 0,813). Hàng trên và hai cột icon neo đỉnh; nút PLAY, chữ "Sắp có level mới" và thanh dưới neo đáy. Màn thấp hơn khung (720x1280 tương đương cao 1575 thiết kế) thì cụm ba mốc level (cùng ray) co lại (cỡ và khoảng cách), giữ khoảng 70 trên nút PLAY như ảnh ref (Figma để 101); màn cao hơn thì cụm dời xuống giữa phần trống.
- Toạ độ chính (px thiết kế): hàng trên y 35 (avatar 124 ở x 11, chip mạng 272x105 ở x 189, chip vàng ở x 477, settings 88 ở x 795); cột icon 194x176 ở x 12 (trái) và x 682 (phải) từ y 221, bước 213 (tự rút bước khi nhiều mục); nút PLAY pill 387x165 ở (256, 1274); thanh dưới 886x248 từ y 1552.
- Đường level: level 1 dùng bố cục khung thường (hai mốc khoá 220 ở y 211 và 525, mốc hiện tại 290 ở y 868). Từ level 2 dùng bố cục khung Hard, hai mốc dưới hạ xuống như ảnh ref (khoá 220 ở y 149, hiện tại 290 ở y 548, vừa qua 220 ở y 971; Figma để 513 và 941). Mốc hiện tại: kim cương xanh (thường), lục giác đỏ có đầu lâu (`hard`), lục giác tím có đầu lâu sừng (`very_hard`); mốc vừa qua là lục giác xanh có dấu tích; mốc khoá là lục giác xám có ổ khoá ở mọi độ khó (theo ảnh ref, không theo khung thường của Figma).
- Ray kẹo thẳng đứng, tâm ở x 443 (`PATH_X`): `home_rail_straight.png` 64×2008, đặt ở `RAIL_RECT` (411, 98) khi cụm mốc không co. Ảnh sinh bằng `tools/gen_home_rail.py` từ ray cong `home_rail.png` (component "Progress line", node `71:367`, 306×2008): duỗi theo đường giữa ray, lấy một chu kỳ sọc ở đoạn thẳng nhất của ray cong rồi lặp lại, nhân RGB với 0,85 cho bớt chói. Ba mốc giữ y như trên, tâm nằm trên đường giữa ray (thẳng hàng); ray chạy tiếp sau nút PLAY xuống thanh dưới. Ray co và dời cùng cụm mốc (quanh x 443 và đỉnh cụm) nên mốc luôn nằm trên ray. Ray đục, mờ dần ở hai đầu. Glow fx 1 cỡ 518 quanh mốc 290 ở mọi độ khó, tâm theo mốc hiện tại.
- Nút PLAY: pill xanh/đỏ/tím theo độ khó; khó thì có chữ độ khó cỡ 36 phía trên chữ PLAY cỡ 102. Chữ độ khó dùng khoá `level_hard`, `level_very_hard` ("VERY HARD", Figma ghi "SUPER HARD").
- Nền (theme kẹo, khác Figma): mọi độ khó dùng chung nền của khung Hard, dải `#3454AC` → `#DEE1F2`, phủ thêm lớp `#3454AC` mờ dần trên 566 px đầu. Độ khó chỉ đổi mốc hiện tại, vị trí glow và nút Chơi. Hoạ tiết kẹo chìm mờ (`home_candy_pattern.png`, tile 512 px có 5 hình, sinh bằng `tools/gen_home_candy_pattern.py`, vẽ hai lớp: lòng hình hồng, lớp trắng lệch xuống 2 px làm viền sáng ở mép dưới để hình chìm xuống; độ mờ 2,7%, tức alpha 7/255) và sao 4 cánh lấp lánh (`src/ui/home_sparkles.gd`). Ảnh rời export từ Figma: `home_glow.png` (fx 1), `home_rail.png` (ray kẹo cong, "Progress line" 1x, chỉ làm nguồn cho `home_rail_straight.png`), `home_banner.png` (ribbon vàng); `home_pattern.png` (nền hình mèo) không còn dùng.
- Ngoài khung Figma, giữ theo logic game: icon Daily Challenge ở cột trái (khoá ghi "Level 50"), icon ưu đãi có hạn ở đầu cột phải (ribbon ghi thời gian còn), Special Pack, Weekend Sale, Weekly Pass, Chain Offer ở cột phải; mạng ẩn trước khi mở; avatar và frame là đồ người chơi đang đeo. Chip mạng: số mạng trên icon tim, thanh ghi "FULL" hoặc thời gian tới mạng kế; chạm mở popup tim (`no_lives` với `source: "hub"`) đè lên màn đang mở, dim 85%: tiêu đề "Thêm mạng"; chưa đầy thì có nút video, nút gold và đếm ngược, đầy mạng (hoặc vô hạn) thì ẩn cả ba và báo đầy. Nạp xong hoặc đóng đều quay lại màn cũ, không vào level.
- Chụp để so: `tests/shot.gd` với `--only=home,home_l1,home_hard,home_very_hard`.
- Mọi nút tối thiểu 96×96. Dấu + trên chip tiền tệ chỉ là hình; vùng chạm là cả chip.
- Nhãn FigmaBox là con của nút (chữ Chơi, chữ độ khó, chữ tab thanh dưới) thu cỡ cho vừa `ThemeKit.button_text_area` của nút, như chữ trên nút Unity (`docs/UI_UNITY.md`). Bề rộng đo theo chữ hoa khi nhãn bật `uppercase` và trừ viền chữ.
- Font: Baloo, style theo material TextMeshPro "Baloo Outline - Black" của color-cube-match-puzzle (chữ trắng, viền đen, bóng đen lệch xuống). `assets/fonts/baloo.res` là `FontFile` MSDF dựng từ atlas SDF trong `Baloo Bhaijaan Regular 400 SDF.asset` bằng `tools/gen_baloo_font.gd` (project đó không còn file TTF gốc). Font là mặc định cho mọi chữ qua `gui/theme/custom_font` trong `project.godot` và `ThemeKit.make_theme()`; atlas có đủ chữ Latin (cả tiếng Việt) và Cyrillic. Hindi, Hàn, Nhật lấy từ ba font fallback gắn trong `baloo.res`: `assets/fonts/baloo2.res` (Baloo 2: Devanagari, cùng thiết kế Baloo, kèm dấu câu Baloo thiếu như "·"), `jua.res` (Jua: Hangul), `mplus_rounded.res` (M PLUS Rounded 1c Bold: kana, kanji). TTF gốc và license OFL nằm ở `art/fonts/` (không import); `tools/gen_baloo_font.gd` nhúng TTF vào các `.res` đó. Lý do không import TTF thẳng: fallback phải có ascent/descent đúng bằng Baloo (32 và 11.9 ở cỡ 32), vì `Font.get_height()` lấy font cao nhất trong chuỗi fallback mà `UnityUI` dàn chữ theo chiều cao của Baloo (`GODOT_LINE_HEIGHT`); để metric gốc (Baloo 2 cao 52) thì bàn cờ và chữ TMP lệch đi. Script cũng bỏ các glyph Devanagari, Hangul, kana, kanji lẻ tẻ trong atlas Unity để cả cụm chữ sang fallback (Hindi cần shaping thật). Fallback là MSDF với `msdf_pixel_range=14`, `msdf_size=32` như atlas, nên `src/ui/tmp_text.gdshader` (lấy median RGB, giới hạn bởi A) vẽ viền và bóng giống nhau; mỗi font gắn `language_support` (hi, ko, ja) để TextServer ưu tiên đúng font theo ngôn ngữ. `tests/test_i18n.gd` kiểm mọi ký tự của 14 cột đều có trong Baloo hoặc một fallback. Jua chỉ có khoảng 2.350 âm tiết Hangul thông dụng; thêm chữ Hàn mới thì chạy test này.
- Viền mặc định `ThemeKit.TEXT_OUTLINE` màu đen; label có viền thêm bóng `ThemeKit.underlay()` (offset dọc bằng nửa viền + 1). `ink_label` không viền, không bóng. Viền màu riêng theo ngữ cảnh (nút theo `BUTTON_STROKE`, ribbon, chữ vàng) giữ nguyên. `Button` của Godot không vẽ bóng chữ nên nút chỉ có viền.

## Màn chưa nối logic

- Script `extends "res://src/ui/stub_ui.gd"`, scene cùng tên trong `scenes/`. Nhận `setup({"view": ...})`; không truyền thì lấy dữ liệu mẫu trong `src/ui/sample_data.gd`.
- Nút chỉ phát `closed({"action": ...})`, không gọi `Game`, không mua hàng, không chạy quảng cáo. Tiền, giá, tên người chơi trên các màn này là số mẫu từ wireframe.
- `Config.ui_preview()` chặn lối vào ở bản phát hành: chỉ bật khi `OS.is_debug_build()`, gồm cả APK xuất bằng `tools/export_apk.sh` (`--export-debug`). Bản `tools/export_release.sh` ẩn hết. `tests/test_ui_stubs.gd` kiểm điều này.
- Lối vào khi xem trước: icon Remove Ads, Win Streak trên Home, các mục Hearts, Helper Packs, Bundles trong Shop, nút bút chì ở Profile, nút Help trong cài đặt ở level, và **Settings > Xem trước UI** liệt kê toàn bộ màn theo số wireframe.

Nối logic cho một màn: thêm logic và save vào `src/meta` và `Game`, truyền `view` thật, đổi nút từ `closed({"action"})` sang hành động thật, bỏ khoá mẫu và điều kiện `ui_preview` của lối vào, sửa `design.md`.

## Trạng thái

| Wireframe | Màn | Trạng thái |
|---|---|---|
| 2.1 | Home | Xong, có logic |
| 2.2 | `popup_daily` | Xong, có logic. Game có 7 ô mỗi tuần như wireframe; thêm dòng tuần và ô thứ 7 chiếm cả hàng |
| 3.2, 3.4 | Dải cảnh báo độ khó, HUD level | Xong, có logic. Bánh răng mở 3.5; Home nằm trong popup đó. Nút và khung HUD nay dùng sprite `assets/ui/hud/` theo ảnh ref kẹo (xem `design.md`), không còn icon Figma trên tile |
| 3.5 | `popup_ingame_settings` | Xong, có logic. Theo hi-fi "Ingame/Setting"; nút xanh là Restart (Figma ghi giá 100 gold), "-1 tim" gắn cả Home và Restart khi bỏ ván mất mạng |
| 3.6, 3.10 | Hộp thoại trong `level.gd` | Xong, có logic. Dùng hộp thoại chung thay vì scene riêng |
| 4.1, 4.4, 4.5 | `win_card`, `popup_rescue`, `lose_card` | Xong, có logic. Rescue giữ nội dung +3 Lượt của game, không phải "Out of Space" |
| 5.1 | `no_lives` | Xong, có logic |
| 6.1, 6.2 | `shop`, `shop_mini` | Gold và gói đặc biệt có logic. Hearts, Helper Packs, Bundles chỉ là UI |
| 7.1, 7.2 | `popup_offer` | Xong, có logic |
| 7.3, 7.4 | `chain_offer` | Xong, có logic. Dạng danh sách bước thay vì lưới 2 cột |
| 7.6 | `weekly_pass`, `popup_weekly_tutorial` | Xong, có logic. Dạng card, chưa toàn màn hình |
| 10.1, 10.3 | `profile`, `settings` | Xong, có logic, theo hi-fi node `47:3486`. Settings thêm icon thông báo (Figma có 3 icon), Restore và Privacy là chữ gạch chân; nút Language mở popup Language riêng trong `settings.gd` (14 ngôn ngữ của `Game.LANGS`, đúng 14 ô của prefab, ô sáng là `Game.current_lang()`), không dùng stub 10.4. Profile: ô tên hiện "Người chơi", dòng UID hiện gold; món chưa có hiện khoá trên ô, nút giá kèm nút video |
| Ngoài wireframe | `challenge` | Xong, có logic |
| 1.1 | `splash` | Xong, có logic: màn loading khi mở game, `main.gd` chạy thanh tải trong lúc `Game.boot()` (design.md mục 2) |
| 1.2 đến 1.6 | `popup_update`, `download_data`, `select_account`, `tutorial_intro`, `popup_no_internet` | Chỉ UI |
| 2.3 | ADS Daily | Xong, có logic, nằm trong Shop (khối `AdsDaily`, dùng video gold `shop_coins`: 5 ô mỗi ngày, mỗi ô 200 gold). Không có lối vào trên Home; `popup_ads_daily` chỉ còn trong danh sách xem trước |
| 2.4 | `popup_remove_ads` | Chỉ UI |
| 3.1, 3.3, 3.7, 3.8, 3.9, 3.11 | `load_transition`, `popup_mechanic`, `booster_soon`, `booster_unlocked`, `popup_free_pick`, `speedup_tutorial` | Chỉ UI |
| 4.2, 4.3, 4.6, 4.7 | `popup_bonus`, `popup_rate`, `popup_keep_playing`, `popup_helper_pack` | Chỉ UI |
| 5.2, 5.3 | `popup_heart_bundle`, `popup_heart_support` | Chỉ UI |
| 7.5 | `popup_weekly_upsell` | Chỉ UI |
| 8.1 đến 8.4 | `leaderboard`, `popup_lb_howto`, `popup_leagues`, `popup_lb_result` | Xong, có logic (design.md mục 7, Leaderboard). Hai tab League và World thay cho giải tuần; thêm `popup_lb_player` cho World. Phần dùng chung ở `src/ui/lb_kit.gd` |
| 9.1 đến 9.5 | `popup_streak_intro`, `streak_main`, `popup_streak_rewards`, `popup_streak_end`, `popup_streak_keep` | Chỉ UI |
| 10.2, 10.4, 10.5 | `popup_change_name`, `popup_language`, `popup_help` | Chỉ UI |
| 11.1 đến 11.3, 6.3 | `ad_loading`, `popup_notice`, `popup_reward` | Chỉ UI |

Một số wireframe 3.8, 3.9, 3.11, 4.4 mô tả băng chuyền và ô chứa của game gốc; game này không có cơ chế đó nên các màn trên giữ chữ theo wireframe để duyệt bố cục, cần sửa nội dung khi nối logic.
