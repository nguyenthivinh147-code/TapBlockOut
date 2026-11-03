# UI theo Figma "Tapblock"

Nguồn: file Figma `Tapblock`. Layout lấy từ page **Overview** (wireframe 11 nhóm, khung 390x844). Màu, chữ, component, icon lấy từ page **02 · Foundations**.

## Quy tắc

- Mọi chữ hiển thị qua `tr()`. Không dùng ảnh có chữ "nướng" sẵn (nút PLAY, tab HOME, tiêu đề popup, giá OK/100...). Chỉ dùng sprite không chữ.
- Màu, cỡ chữ, nút, ô nền nằm ở `src/ui/theme_kit.gd`, khớp bảng Colors trong Foundations.
- Sprite cắt từ atlas nằm ở `src/ui/ui_atlas.gd` (bảng `REGIONS`, toạ độ lấy từ bounds node trong Figma). Atlas và icon nằm ở `assets/ui/figma/`.
- Nút viên thuốc cỡ thường dùng `assets/ui/figma/pill/*_96.png`, sinh bằng `tools/gen_ui_sprites.gd` (cắt từ atlas, thu về cao 96px để đầu tròn đúng tỉ lệ khi 9-slice). Sửa atlas thì chạy lại tool rồi `--import`.
- Icon `ic_*` tìm thấy trực tiếp theo tên. Tên cũ ánh xạ sang icon Figma qua `ThemeKit.FIGMA_ICON`, bảng này ưu tiên hơn file trong `assets/ui/`.
- Popup dựng bằng `src/ui/popup_kit.gd`: nền mờ, khung kem, ribbon tiêu đề, nút X. Chữ trên thân kem dùng `ThemeKit.ink_label` hoặc `PopupKit.text`, số vàng dùng `ThemeKit.gold_label`.
- Home, Shop, Leaderboard dùng chung `src/ui/hub_top.gd` (avatar, mạng, vàng, settings) và `src/ui/hub_nav.gd` (Shop, Home, Ranking).
- Mọi nút tối thiểu 96×96. Dấu + trên chip tiền tệ chỉ là hình; vùng chạm là cả chip.
- Font Baloo chưa có trong repo (không tải được lúc làm); đang dùng font mặc định của Godot với viền chữ như Foundations. Thêm `assets/fonts/Baloo2.ttf` và đặt làm font mặc định trong `ThemeKit.make_theme()` khi có.

## Màn chưa nối logic

- Script `extends "res://src/ui/stub_ui.gd"`, scene cùng tên trong `scenes/`. Nhận `setup({"view": ...})`; không truyền thì lấy dữ liệu mẫu trong `src/ui/sample_data.gd`.
- Nút chỉ phát `closed({"action": ...})`, không gọi `Game`, không mua hàng, không chạy quảng cáo. Tiền, giá, tên người chơi trên các màn này là số mẫu từ wireframe.
- `Config.ui_preview()` chặn lối vào ở bản phát hành: chỉ bật khi `OS.is_debug_build()`, gồm cả APK xuất bằng `tools/export_apk.sh` (`--export-debug`). Bản `tools/export_release.sh` ẩn hết. `tests/test_ui_stubs.gd` kiểm điều này.
- Lối vào khi xem trước: icon ADS Daily, Remove Ads, Win Streak trên Home, các mục Hearts, Helper Packs, Bundles trong Shop, nút bút chì ở Profile, nút Help trong cài đặt ở level, và **Settings > Xem trước UI** liệt kê toàn bộ màn theo số wireframe.

Nối logic cho một màn: thêm logic và save vào `src/meta` và `Game`, truyền `view` thật, đổi nút từ `closed({"action"})` sang hành động thật, bỏ khoá mẫu và điều kiện `ui_preview` của lối vào, sửa `design.md`.

## Trạng thái

| Wireframe | Màn | Trạng thái |
|---|---|---|
| 2.1 | Home | Xong, có logic |
| 2.2 | `popup_daily` | Xong, có logic. Game có 7 ô mỗi tuần như wireframe; thêm dòng tuần và ô thứ 7 chiếm cả hàng |
| 3.2, 3.4 | Dải cảnh báo độ khó, HUD level | Xong, có logic. Bánh răng mở 3.5; Home nằm trong popup đó |
| 3.5 | `popup_ingame_settings` | Xong, có logic |
| 3.6, 3.10 | Hộp thoại trong `level.gd` | Xong, có logic. Dùng hộp thoại chung thay vì scene riêng |
| 4.1, 4.4, 4.5 | `win_card`, `popup_rescue`, `lose_card` | Xong, có logic. Rescue giữ nội dung +3 Lượt của game, không phải "Out of Space" |
| 5.1 | `no_lives` | Xong, có logic |
| 6.1, 6.2 | `shop`, `shop_mini` | Gold và gói đặc biệt có logic. Hearts, Helper Packs, Bundles chỉ là UI |
| 7.1, 7.2 | `popup_offer` | Xong, có logic |
| 7.3, 7.4 | `chain_offer` | Xong, có logic. Dạng danh sách bước thay vì lưới 2 cột |
| 7.6 | `weekly_pass`, `popup_weekly_tutorial` | Xong, có logic. Dạng card, chưa toàn màn hình |
| 10.1, 10.3 | `profile`, `settings` | Xong, có logic. Settings giữ các nút ngôn ngữ thật thay vì mở 10.4 |
| Ngoài wireframe | `challenge` | Xong, có logic |
| 1.1 đến 1.6 | `splash`, `popup_update`, `download_data`, `select_account`, `tutorial_intro`, `popup_no_internet` | Chỉ UI |
| 2.3, 2.4 | `popup_ads_daily`, `popup_remove_ads` | Chỉ UI |
| 3.1, 3.3, 3.7, 3.8, 3.9, 3.11 | `load_transition`, `popup_mechanic`, `booster_soon`, `booster_unlocked`, `popup_free_pick`, `speedup_tutorial` | Chỉ UI |
| 4.2, 4.3, 4.6, 4.7 | `popup_bonus`, `popup_rate`, `popup_keep_playing`, `popup_helper_pack` | Chỉ UI |
| 5.2, 5.3 | `popup_heart_bundle`, `popup_heart_support` | Chỉ UI |
| 7.5 | `popup_weekly_upsell` | Chỉ UI |
| 8.1 đến 8.4 | `leaderboard`, `popup_lb_howto`, `popup_leagues`, `popup_lb_result` | Xong, có logic (design.md mục 7, Leaderboard). Hai tab League và World thay cho giải tuần; thêm `popup_lb_player` cho World. Phần dùng chung ở `src/ui/lb_kit.gd` |
| 9.1 đến 9.5 | `popup_streak_intro`, `streak_main`, `popup_streak_rewards`, `popup_streak_end`, `popup_streak_keep` | Chỉ UI |
| 10.2, 10.4, 10.5 | `popup_change_name`, `popup_language`, `popup_help` | Chỉ UI |
| 11.1 đến 11.3, 6.3 | `ad_loading`, `popup_notice`, `popup_reward` | Chỉ UI |

Một số wireframe 3.8, 3.9, 3.11, 4.4 mô tả băng chuyền và ô chứa của game gốc; game này không có cơ chế đó nên các màn trên giữ chữ theo wireframe để duyệt bố cục, cần sửa nội dung khi nối logic.
