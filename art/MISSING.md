# Còn thiếu và ghi chú

## Hình
- Không có file demo nào thiếu.
- Cơ chế (Task 9.5): đã tạo xong `mech_stone`, `mech_ice`, `mech_chain`, `mech_key`, `mech_fog` (art/manifest.mech.json, gộp vào manifest.json).
- Bản bỏ (superseded): `art/images/block_surface.png`, `art/images/art_no_lives.png` (thay bằng `_v2`).
- Chưa có icon riêng cho `shop_<sku>` (gói shop, popup offer): `ThemeKit.icon` trả placeholder vẽ bằng code.
  `booster_hint|move|smash` dùng tạm `ui_hint|ui_moves|ui_smash` qua `ICON_ALIAS`.

## Âm thanh
- Không có `art/MISSING.audio.md` (không thiếu file demo nào).
- 6 sfx cơ chế (Task 9.5): đã tạo xong (stone, ice, chain, layer, fog, gate). `sfx_stone` to hơn các sfx khác (RMS -14 dB so với khoảng -25 dB), cần cân lại; chưa nghe bằng tai.
- Nhạc nền (`bgm_home`, `bgm_level`) chưa được nghe bằng tai, mới kiểm bằng số liệu và nạp stream. Cần người nghe duyệt.
- `sfx_clap` và `sfx_smash` nhỏ tiếng hơn các hiệu ứng khác khoảng 6-10 dB: cần cân lại (tăng gain trong `tools/process_audio.sh` rồi xuất lại) hoặc chỉnh bus.

- `sfx_shatter`, `sfx_bump` chưa tạo: máy chủ ComfyUI trả lỗi 502 ngày 2026-11-02. Trong lúc đó game tự dùng `sfx_exit`, `sfx_blocked` (`Sfx.play_or`). Có file là tự dùng, không phải sửa code. Cách tạo:
  - `start_game_audio`, `use_reprompt=false`, `category=SFX`, `negative_prompt="harsh, loud, noisy, distorted, music, speech, explosion"`, lưu vào `art/audio/<tên>.flac`; rồi chạy `tools/process_audio.sh <tên>` và ghi vào `art/manifest.audio.json` cùng `art/manifest.json`.
  - `sfx_shatter`, 2 giây: "crisp hard candy shattering into small pieces, glassy sugar crack with tiny tinkling shards scattering, satisfying and gentle, soft ASMR, no music".
  - `sfx_bump`, 1 giây: "soft rubbery jelly candy bumping into another candy, gentle muffled thud with a tiny wobble, soft ASMR, no music".

## Icon app (Task 7.3)
- `assets/icon_main_192.png`, `assets/icon_adaptive_fg_432.png` (icon_app thu nhỏ 288 px, bo góc, nền trong), `assets/icon_adaptive_bg_432.png` (màu đặc xanh #2F80ED) dùng cho `launcher_icons/*` của hai preset.
- Chưa có icon đơn sắc (`adaptive_monochrome_432x432`) cho Android 13 themed icons.
