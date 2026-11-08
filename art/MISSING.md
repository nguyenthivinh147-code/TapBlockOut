# Còn thiếu và ghi chú

## Hình
- Không có file demo nào thiếu.
- Cơ chế (Task 9.5): đã tạo xong `mech_stone`, `mech_ice`, `mech_chain`, `mech_key`, `mech_fog` (art/manifest.mech.json, gộp vào manifest.json).
- `mech_pulse` (cổng nhịp) chưa có: popup cơ chế mới ở L90 (2026-11-08) dùng placeholder vẽ bằng code của `ThemeKit.icon`. Có file `assets/ui/mech_pulse.png` là tự dùng.
- Bản bỏ (superseded): `art/images/block_surface.png`, `art/images/art_no_lives.png` (thay bằng `_v2`).
- Chưa có icon riêng cho `shop_<sku>` (gói shop, popup offer): `ThemeKit.icon` trả placeholder vẽ bằng code.
- `booster_hint|move|smash` (2026-11-03): bản AI (`art/images/booster_*_ai.png`) dựng từ bố cục SVG vẽ tay (`art/images/booster_*.svg`). Ảnh tách nền của MCP để lại alpha 1-4 phủ cả khung; `tools/fit_icon.gd` đã lọc.
- `booster_hint|move` (2026-11-04): vẽ lại theo phong cách 3D đồ chơi của `art/concepts/ref_booster_style.png`, ảnh gốc `art/images/booster_hint_toy_ai.png`, `booster_move_toy_ai.png`. Đưa icon cũ làm ảnh 1 thì model giữ nguyên kiểu sticker viền đậm, nên chỉ dùng ảnh ref hoặc tả bằng chữ. Mũi tên ra alpha 245-254 nên cắt với `--solid=240`.
- `booster_hint|move` (2026-11-04, lần 2): vẽ lại khối 3D chất liệu kẹo, người dùng chọn từ bảng 3 phương án `art/concepts/concept_booster_candy_v1.png` (cột 1 là bản đồ chơi nhựa trước đó). Ảnh gốc `art/images/booster_hint_candy_ai.png`, `booster_move_candy_ai.png`; bản đồ chơi nhựa `*_toy_ai.png` giữ lại để so. Hint là phương án 1 (bóng đèn kẹo), Move là phương án 2 (chữ "+3" kẹo dẻo xanh; lúc đầu chọn mũi tên gậy kẹo rồi đổi). Model vẫn vẽ vệt bóng mờ dưới số 3 dù prompt cấm, nhìn ở 56-96 px không thành quầng. Thân kẹo ra alpha 245-254 nên cắt với `--solid=240`. `booster_smash` vẫn kiểu sticker viền đậm, lệch phong cách với hai icon này.
- `art_chain_offer` (2026-11-08): ảnh tiêu đề popup Chain Offer, là rương `ic_EndlessTreasure` của prefab với ba booster của game Unity đổi thành `booster_hint|move|smash`. Xoá booster cũ bằng `edit_game_image` (ảnh gốc lót nền trắng, phóng 1024); một lượt chỉ xoá được hai trong ba nên chạy lượt hai trên kết quả lượt một. Model không giữ nguyên ảnh từng điểm ảnh, nên `tools/compose_chain_offer_art.py` chỉ lấy phần AI vẽ lại trong vùng ba booster cũ, dựng lại quầng sáng trắng mờ quanh rương (nền trắng làm mất nó) rồi dán icon booster thật. Đổi icon booster thì chạy lại script, không phải gọi lại AI.
- `booster_hint|move` (2026-11-04, lần 3): vẽ lại phẳng cho khớp `booster_smash`. `edit_game_image` với ảnh 1 là `assets/ui/booster_smash.png` (phong cách), ảnh 2 là bản kẹo 3D `*_candy_ai.png` (nội dung); lần này đưa icon sticker làm ảnh 1 là cố ý, để model giữ viền đậm. Ảnh gốc `art/images/booster_hint_flat_ai.png`, `booster_move_flat_ai.png`. Hint lần đầu ra viền mảnh, bóng đèn trơn; prompt phải tả rõ viền dày, mảng tối cam bên phải, sọc sáng trên từng ren. Ảnh phẳng không còn alpha 245-254 nên cắt không cần `--solid`.

## Âm thanh
- Không có `art/MISSING.audio.md` (không thiếu file demo nào).
- 6 sfx cơ chế (Task 9.5): đã tạo xong (stone, ice, chain, layer, fog, gate). `sfx_stone` to hơn các sfx khác (RMS -14 dB so với khoảng -25 dB), cần cân lại; chưa nghe bằng tai.
- Nhạc nền (`bgm_home`, `bgm_level`) chưa được nghe bằng tai, mới kiểm bằng số liệu và nạp stream. Cần người nghe duyệt.
- `sfx_clap` và `sfx_smash` nhỏ tiếng hơn các hiệu ứng khác khoảng 6-10 dB: cần cân lại (tăng gain trong `tools/process_audio.sh` rồi xuất lại) hoặc chỉnh bus.

- `sfx_shatter` (khối bị nghiền qua thanh) đã tạo ngày 2026-11-08, chi tiết trong `art/manifest.audio.json`. Bản đầu chọn bằng phép đo; người dùng nghe thấy giòn quá nên cùng ngày đã làm êm bằng `tools/process_sfx.gd --lowpass=3000 --soften=3` từ cùng bản gốc. Bản êm chưa ai nghe; nếu vẫn giòn thì hạ `--lowpass` (2200 êm hơn nữa), nếu đục quá thì nâng (4500). Bản Stable Audio nào cũng có tiếng lách tách ở 0,02 giây rồi lặng tới khoảng 0,3 giây, nên xử lý bằng `tools/process_sfx.gd --start=`. Nhiều bản có vạch rít kéo dài ở khoảng 2,5 kHz dù prompt không nhắc; thêm `ringing tone, whistle, hum, sine tone` vào negative thì đỡ.
- `sfx_bump` chưa tạo: máy chủ ComfyUI trả lỗi 502 ngày 2026-11-02. Trong lúc đó game tự dùng `sfx_blocked` (`Sfx.play_or`). Có file là tự dùng, không phải sửa code. Cách tạo:
  - `start_game_audio`, `use_reprompt=false`, `category=SFX`, `file_format=mp3`, `negative_prompt="harsh, loud, noisy, distorted, music, speech, explosion"`, lưu vào `art/audio/<tên>.mp3`; rồi chạy `tools/process_sfx.gd` (cách chạy ở đầu file) và ghi vào `art/manifest.audio.json` cùng `art/manifest.json`.
  - `sfx_bump`, 1 giây: "soft rubbery jelly candy bumping into another candy, gentle muffled thud with a tiny wobble, soft ASMR, no music".
- `sfx_box_tear` chưa có: hộp giấy rách ở thanh đang dùng `sfx_exit`. Có file là tự dùng.

## Icon app (Task 7.3)
- `assets/icon_main_192.png`, `assets/icon_adaptive_fg_432.png` (icon_app thu nhỏ 288 px, bo góc, nền trong), `assets/icon_adaptive_bg_432.png` (màu đặc xanh #2F80ED) dùng cho `launcher_icons/*` của hai preset.
- Chưa có icon đơn sắc (`adaptive_monochrome_432x432`) cho Android 13 themed icons.
