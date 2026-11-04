# Nhạc nền: phân tích người chơi và tiêu chuẩn

Ngày: 2026-11-04. Áp dụng cho `bgm_home` (Home) và `bgm_level` (màn chơi). Luật chơi, con số và nội dung vẫn theo `design.md`; tài liệu này nói nhạc nền phải thế nào, đo bằng gì và hai bài hiện tại đạt ra sao.

## 1. Dòng game

| Đặc điểm | Nguồn trong `design.md` | Ý nghĩa với nhạc |
| --- | --- | --- |
| Casual puzzle nhánh "tap to unblock": chạm khối để khối trượt ra cạnh cùng màu, chỉ chạm, không kéo | Mục 1, 3 | Nhịp chơi chậm, suy nghĩ rồi chạm; nhạc không được giục |
| Mục tiêu "thư giãn ASMR": không timer, không màn đỏ, rung nhẹ, mỗi chất liệu khối có tiếng riêng | Mục 2, "Tiêu chí thư giãn" | Arousal thấp; tiếng khối là nhân vật chính, nhạc là lớp nền |
| Theme kẹo Candy Away: pastel hồng tím, kẹo bóng, pudding, hộp giấy | Mục 2, 4 | Âm sắc "ngọt" và vui nhẹ, không lo-fi chung chung |
| Level 10 giây đến 2 phút, thắng thì vào thẳng level kế; giả định 20 phút mỗi ngày, chia 2 phiên | Mục 1, 4, 5 | Nhạc màn chơi lặp nhiều vòng liền, phải đều và ít hook |
| Hybrid-casual, doanh thu 50% quảng cáo, 50% IAP; Home có quà, shop, leaderboard | Mục 2, 5–7 | Home là sảnh: nhạc chào đón, có màu sắc hơn |
| Android, portrait, offline; đo hiệu năng trên máy 2 GB RAM; 14 ngôn ngữ | Mục 2, 8 | Loa điện thoại, file nhẹ, không lời |

Game tham khảo là Tap Block Out: Color Puzzle (funsmith). Không dùng tên, nhạc hay âm thanh của game đó làm tham chiếu khi tạo nhạc.

## 2. Người chơi

Chưa có số liệu thật. Dưới đây là giả định suy từ dòng game và theme, cần kiểm bằng analytics sau soft launch.

| Nhóm, bối cảnh | Giả định | Hệ quả cho nhạc |
| --- | --- | --- |
| Người chơi chính | Người lớn chơi casual, khoảng 25–55 tuổi, nghiêng về nữ vì theme kẹo; thêm nhóm lớn tuổi thích giải đố không áp lực thời gian | Dễ nghe, ấm, không gắt; không EDM, không trống nặng |
| Lúc chơi | Phiên ngắn lúc nghỉ, trên xe, trước khi ngủ | Không kích thích, không cao trào; nghe trước giờ ngủ vẫn dễ chịu |
| Cách nghe | Nhiều người tắt tiếng nơi công cộng; số còn lại nghe qua loa điện thoại (dải khoảng 300 Hz–8 kHz, thường mono) hoặc tai nghe | Nhạc không mang thông tin gameplay; cân dải trung, ít sub-bass, gộp mono không mất tiếng; có nút tắt nhạc riêng (đã có) |
| Thị trường | 14 ngôn ngữ: Âu Mỹ, Mỹ La-tinh, Thổ, Nga, Ukraina, Ấn, Indonesia, Nhật, Hàn, Việt | Không lời, không chất liệu dân tộc đặc trưng, hoà âm pop phổ thông |
| Thời lượng | Chơi nhiều level liền, nhạc màn chơi nghe hàng chục vòng | Màn chơi ít giai điệu nổi, vòng lặp dài, chỗ nối không lộ |
| Thiết bị | Android tầm thấp và trung | Ogg khoảng 1 MB mỗi bài, phát dạng stream |

## 3. Tiêu chuẩn

### 3.1 Cảm xúc và phối khí

| | Home (`bgm_home`) | Màn chơi (`bgm_level`) |
| --- | --- | --- |
| Vai trò | Sảnh tiệm kẹo, chào đón giữa các level | Nền cho tập trung, chạy nhiều phút liền |
| Cảm xúc | Ngọt, vui nhẹ, nảy, ấm | Dịu, đều, mơ màng, không đòi chú ý |
| Nhịp, giọng | 95–105 BPM, giọng trưởng | 75–85 BPM, giọng trưởng, cùng họ giọng với Home |
| Nhạc cụ | Marimba, pizzicato, ukulele, bass tròn, shaker và búng tay nhẹ, glockenspiel thưa | Felt piano hoặc Rhodes ở dải trung, pad ấm, bass tròn, shaker rất nhẹ |
| Giai điệu | Có motif dễ nhớ nhưng không chói | Không hook; hợp âm và nhịp đập nhẹ là chính |
| Tránh | Lời, hum, choir, trống nặng, drop, build-up, riser, giọng thứ buồn, kèn fanfare | Như Home, thêm chuông, chime, glockenspiel, music box (dễ lẫn với `sfx_coin`, `sfx_hint`, `sfx_crystal`, `sfx_win`) và lead sáng |

Chung cho cả hai bài: file không có fade vào hay fade ra; không ngắt nhạc giữa bài; không giống bài hát có thật; không có tiếng giống hiệu ứng trong game.

### 3.2 Kỹ thuật

Kiểm bằng `tools/music_check.py` (mục 5). Loudness theo ITU-R BS.1770, LRA theo EBU Tech 3342.

| Tiêu chí | Home | Màn chơi | Ghi chú |
| --- | --- | --- | --- |
| Định dạng | Ogg Vorbis stereo 44,1 kHz, q 0,3, `loop=true` trong `.import` | Như Home | |
| Độ dài vòng lặp | 60–90 giây | 80–150 giây, nên từ 90 giây | Màn chơi lặp nhiều nên cần dài hơn |
| Điểm lặp | Tròn ô nhịp, bắt đầu ở phách mạnh | Như Home | |
| Dung lượng | ≤ 1,5 MB | ≤ 1,5 MB | |
| Loudness tích hợp | −18 LUFS ±1 | −20 LUFS ±1 | Màn chơi nhỏ hơn để nhường hiệu ứng |
| True peak sau khi nén | ≤ −1 dBTP | ≤ −1 dBTP | Đo trên Ogg đã giải mã, oversample ×4 |
| LRA | ≤ 6 LU | ≤ 4 LU | Không cao trào, không đoạn hụt |
| Độ trôi nhịp | Mỗi đoạn 20 giây lệch ≤ 1 BPM | Như Home | |
| Hụt qua loa điện thoại | ≤ 5 LU | ≤ 5 LU | LUFS giảm khi lọc band-pass 300 Hz–8 kHz bậc 4 |
| Dải 2–6 kHz so với tổng | ≤ −20 dB | ≤ −30 dB | Vùng của tiếng chạm, xu, gợi ý |
| Dưới 60 Hz so với tổng | ≤ −12 dB | ≤ −12 dB | Loa điện thoại không phát được, chỉ tốn headroom |
| Gộp mono | Hụt ≤ 3 LU, tương quan L/R ≥ 0,3 | Như Home | |
| Khoảng lặng | Không đoạn dưới −50 dBFS nào dài từ 0,3 giây | Như Home | |
| Chỗ nối | Không click (bước mẫu nhỏ hơn bước p99,9 của bài); loudness 1 giây hai bên lệch ≤ 1 LU; pha phách liền; onset ở chỗ nối không mạnh hơn 1,5 lần onset tự nhiên tại điểm bắt đầu trong bản gốc | Như Home | `music_check.py seam` |

### 3.3 Trong game

- `bgm_home` phát ở Home, Shop, Leaderboard, Profile, màn Daily Challenge và màn hết mạng. `bgm_level` phát trong màn chơi, kể cả level chạy trong màn Daily Challenge. Màn loading chưa có nhạc.
- Qua level kế, thẻ thắng, thẻ thua và popup: nhạc chạy tiếp, không phát lại từ đầu.
- Bài mới to dần từ −30 dB tới 0 dB trong 1 giây. Khi đổi bài, bài cũ nhỏ dần trong 0,5 giây, sau đó bài mới bắt đầu và to dần (`Config.CONTENT.music_fade_in_sec`, `music_fade_out_sec`).
- Bus `Music` thấp hơn bus `SFX` 8 dB (`Sfx.MUSIC_DB`). Ở đầu ra, nhạc Home khoảng −26 LUFS, nhạc màn chơi khoảng −28 LUFS; hiệu ứng có peak −3 dBFS.
- Quảng cáo mở hoặc app ra nền thì nhạc dừng ngay. Khi quay lại, bài phát lại từ đầu và to dần.
- Tắt nhạc trong Settings: bus `Music` bị mute và player dừng.

## 4. Hai bài hiện tại

Hai bài cũ là lo-fi chung chung, làm trước khi đổi sang theme kẹo; `bgm_level` cũ chạy 106 BPM và nghe ra giọng thứ. Trước ngày 2026-11-04 chưa màn nào gọi `Sfx.music`, nên game chưa từng phát nhạc nền.

Mỗi bài tạo 3 bản bằng Stable Audio 3 Medium Base (MCP `comfyui`, `use_reprompt=false`, 50 steps), mỗi bản dài hơn vòng lặp để bỏ được intro và outro.

| | Home | Màn chơi |
| --- | --- | --- |
| Prompt | `cheerful cozy candy shop background music for a relaxing mobile puzzle game, playful bouncy marimba melody, soft pizzicato strings, light ukulele strums, warm round bass, soft shaker and finger snaps, occasional soft glockenspiel accents, sweet whimsical pastel mood, happy but calm, steady light groove, consistent energy throughout, seamless loop, instrumental, 100 BPM, C major` | `calm sweet dreamy background music for a relaxing puzzle game, soft felt piano chords and a gentle piano melody, warm airy pads, mellow nylon guitar plucks, soft round bass, very light shaker, gentle steady pulse, cozy cotton candy mood, peaceful and focused, sparse and minimal, low energy, even dynamics, seamless loop, instrumental, 80 BPM, F major` |
| Negative | `vocals, singing, humming, speech, choir, loud drums, heavy kick, trap hi-hats, electric guitar, distortion, synth lead, EDM, dubstep, drop, build-up, riser, fast tempo, aggressive, dark, sad, minor key, tense, horror, epic orchestra, brass fanfare, vinyl crackle, noise, fade out, silence` | `vocals, singing, humming, speech, choir, drums, kick, snare, loud percussion, bells, chimes, glockenspiel, music box, sparkle, whistle, bright synth lead, electric guitar, distortion, build-up, drop, riser, fast tempo, tense, dark, sad, minor key, vinyl crackle, noise, fade out, silence` |
| Bản tạo | Seed 3101, 3102, 3103; 100 giây | Seed 3201, 3202, 3203; 150 giây |
| Chọn | 3103: đều nhất (LRA 1,6 LU), ít sub nhất. 3102 có đoạn hụt quanh giây 45; 3101 có intro nhỏ và nhiều sub | 3201: từ giây 50 trở đi loudness chỉ dao động 1,6 LU, vòng lặp khớp nhất. 3202 động hơn (LRA 8,9 LU); 3203 nhịp yếu, khó tìm chỗ nối |
| Vòng lặp | 28 ô nhịp ở 99,96 BPM: từ giây 15,261, dài 67,19989 giây, crossfade 0,6 giây | 28 ô nhịp ở 80 BPM: từ giây 53,986, dài 84,00025 giây, crossfade 0,75 giây |
| EQ | High-pass 40 Hz | High-pass 40 Hz, low shelf −5 dB ở 200 Hz |

Đã thử thêm đợt thứ hai cho màn chơi (Rhodes, guitar fingerpick ở dải trung; seed 3211–3213, 190 giây). Đợt này đỡ trầm hơn nhưng bị loại: nhạc ngắt 0,3–0,5 giây mỗi 12–24 giây, có bản ngả giọng thứ, có bản nhịp nhảy giữa 78 và 82 BPM.

Kết quả đo trên file Ogg trong `assets/music/` (đã giải mã lại):

| Tiêu chí | Home | Màn chơi |
| --- | --- | --- |
| Vòng lặp, dung lượng | 67,2 giây, 0,97 MB | 84,0 giây, 1,12 MB |
| Loudness, true peak | −17,98 LUFS, −2,05 dBTP | −20,00 LUFS, −2,57 dBTP |
| LRA | 1,6 LU | 1,8 LU |
| Nhịp, độ trôi | 99,96 BPM, 0,03 | 79,97 BPM, 0,04 |
| Giọng (ước lượng theo chroma) | C major | F major |
| Hụt qua loa điện thoại | 3,2 LU | 4,8 LU (6,9 LU khi chưa có low shelf) |
| Dải 2–6 kHz, dưới 60 Hz | −27,6 dB, −16,7 dB | −47,5 dB, −15,6 dB |
| Gộp mono | Hụt 1,2 LU, tương quan 0,52 | Hụt 1,5 LU, tương quan 0,49 |
| Khoảng lặng | Không có | Không có |
| Chỗ nối | Bước mẫu 0,008 (p99,9 của bài: 0,20); loudness −18,0 → −18,3 LUFS (bản gốc tại điểm bắt đầu −16,3 → −16,2); pha phách liền; onset ×1,24 | Bước mẫu 0,002 (p99,9: 0,04); −20,8 → −20,5 LUFS (bản gốc −19,3 → −19,4); pha phách liền; onset ×0,48 |

Màn chơi đạt mọi tiêu chí nhưng vòng lặp 84 giây ngắn hơn mức nên dùng (90 giây). Bản 3201 chỉ ổn định từ giây 50 nên không cắt được vòng 32 ô nhịp mà vẫn khớp tốt.

## 5. Làm lại hoặc thêm bài

1. Viết prompt theo mục 3.1. Tạo 3 seed, dài hơn vòng lặp 30–60 giây, lưu bản gốc `flac` vào `art/audio/` (thư mục này có `.gdignore`, không vào bản build).
2. Đo từng bản. Lệnh đo dùng numpy, scipy và soundfile qua `uv`, chỉ dùng lúc làm:
   `uv run --no-project --with numpy --with scipy --with soundfile python -I tools/music_check.py report <file> --kind home|level`
3. Tìm điểm lặp: `music_check.py loops art/audio/<bài>.flac --bpm <nhịp> --min <giây> --max <giây>`. Lệnh liệt kê các cặp điểm ở phách mạnh, cách nhau tròn ô nhịp, xếp theo độ khớp (chroma, dải âm, onset) và tương quan dạng sóng. Chọn cặp nằm trong đoạn ổn định, xa intro và outro.
4. Ghi `start=`, `len=`, `xfade=`, `lufs=`, `shelf=` vào bảng `MUSIC` trong `tools/process_audio.sh`, rồi chạy `tools/process_audio.sh <bài>`. Script lọc high-pass 40 Hz và low shelf, cắt vòng lặp với crossfade từ đoạn ngay trước điểm bắt đầu (gain bù theo tương quan, nên không phồng +3 dB khi hai đoạn gần như trùng nhau), bù độ trôi loudness bằng một đường gain tuyến tính theo dB, chuẩn về LUFS đích, chặn peak −2 dBFS, rồi nén Ogg.
5. Kiểm lại file Ogg bằng `report` và `seam <ogg> --bpm <nhịp> --source <flac> --start <giây>`, cập nhật `art/manifest.audio.json` và `art/manifest.json`, rồi mở Godot để import lại (editor đang mở thì quét lại filesystem).
6. Nghe thử trên máy thật, cả loa ngoài và tai nghe: chỗ nối, độ to so với hiệu ứng, cảm giác lặp sau 10 phút chơi.

## 6. Còn mở

- Chưa ai nghe hai bài mới bằng tai. Mọi kết luận ở mục 4 đến từ phép đo.
- Nếu thấy nhạc màn chơi lặp lộ, tạo thêm bản 200 giây bằng prompt màn chơi ở mục 4 để có vòng 32–40 ô nhịp.
- Sau soft launch, kiểm giả định ở mục 2 bằng analytics: độ tuổi, quốc gia, tỉ lệ tắt nhạc (`settings.music`).
