# UI theo Figma "Tapblock"

Nguồn: file Figma `Tapblock`. Layout lấy từ page **Overview** (wireframe 11 nhóm, khung 390x844). Màu, chữ, component, icon lấy từ page **02 · Foundations**.

## Quy tắc

- Mọi chữ hiển thị qua `tr()`. Không dùng ảnh có chữ "nướng" sẵn (nút PLAY, tab HOME, tiêu đề popup, giá OK/100...). Chỉ dùng sprite không chữ.
- Màu, cỡ chữ, nút, panel nằm ở `src/ui/theme_kit.gd`. Màu khớp bảng Colors trong Foundations (menu `#3967BF` → `#7B9EDD`, popup lavender, cream `#F8F3DE`, ink `#3A3F6E`, Button ramp).
- Sprite 9-slice cắt từ atlas nằm ở `src/ui/ui_atlas.gd` (bảng `REGIONS`, toạ độ lấy từ bounds node trong Figma). Atlas và icon nằm ở `assets/ui/figma/`.
- Icon Figma `ic_*` ánh xạ từ tên cũ qua `ThemeKit.FIGMA_ICON`; có trong bảng thì ưu tiên hơn file trong `assets/ui/`.
- Font Baloo chưa có trong repo (không tải được lúc làm); đang dùng font mặc định của Godot với viền chữ như Foundations. Thêm `assets/fonts/Baloo2.ttf` và đặt làm font mặc định trong `ThemeKit.make_theme()` khi có.

## Trạng thái

| Màn (wireframe) | Trạng thái |
|---|---|
| Nền tảng: palette, nút pill, nút icon, nền gradient, khung popup, ribbon, icon | Xong (`theme_kit.gd`, `ui_atlas.gd`) |
| 2.1 Main Menu Hub (Home) | Xong: avatar, mạng, vàng (+), settings, Daily gift trái, ưu đãi phải, đường level, PLAY, thanh Shop/Home/Ranking |
| Level HUD, Win/Lose, Rescue, Shop, Daily, Profile, Settings, No lives, Offers, Weekly Pass, Challenge | Đã đổi nền/nút/icon theo theme mới; chưa dựng lại bố cục bằng khung popup kem (`ThemeKit.make_popup_frame`, `make_title_ribbon`, `ink_label`) |
| Leaderboard (8), Win Streak (9), ADS Daily (2.3), Remove Ads (2.4), Hearts bundle (5), Boot & Onboarding (1), popup hệ thống (11) | Chưa làm. Cần logic, save, i18n và cập nhật `design.md` trước |

Tab Ranking trên Home đang tắt (chú thích "Ranking soon") cho tới khi có Leaderboard.
