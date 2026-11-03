# Tap Block Out: thiết kế (design.md)

Trạng thái: **thiết kế chốt ngày 2026-11-01**, thay bản 2026-10-31.
Nguồn: trao đổi với người dùng ngày 2026-11-01, `tap-block-out-color-puzzle-guideline.vi.md`, `GAME-GUIDE.md`, `AGENTS.md`, `README.md` của Horus, trang Google Play đọc ngày 2026-10-31.

Game làm bằng **Godot 4.7.2, GDScript, xuất Android gốc**. Tài liệu Horus nói về game web chỉ còn là tài liệu tham khảo, xem mục 8.

## 1. Năm dòng

| Câu hỏi của bước 0 | Trả lời |
| --- | --- |
| Vòng chơi một lượt | Nhìn bàn cờ, tìm khối không bị chặn, chạm để khối tự trượt ra cạnh cùng màu, lặp lại tới khi sạch bàn (10 giây đến 2 phút). |
| Cái gì quyết định thắng hay thua | Đọc đúng khối nào đang thoát được. Chạm khối bị chặn tốn 1 MOVES; hết MOVES mà còn khối thì vào luồng cứu (mục 3). Trong level không có timer. Từ L10, thua mất 1 mạng. |
| Tiền nhận theo gì | Gold theo level thắng: +40 ở mọi độ khó; x2 bằng rewarded. Thêm quà 28 ngày và video trong shop. |
| Nâng cấp gì | Không có nâng cấp vĩnh viễn. Gold mua 3 booster dùng một lần (Gợi ý, +3 Move, Phá 1 khối), chơi tiếp, refill tim, avatar và frame. |
| Level sau khác gì | Thêm màu (2 → 4 trong 4 level đầu), nhiều khối hơn, chuỗi chặn sâu hơn, dư MOVES ít hơn, có level HARD xen kẽ theo đường cong độ khó. Từ L14 thêm 6 cơ chế (mục 4). |

## 2. Thông số đã có

- Mục tiêu: game **thư giãn ASMR**, doanh thu **50% IAA, 50% IAP**. Đo theo cohort 30 ngày đầu: doanh thu quảng cáo so với IAP sau phí store. Chưa có số liệu thật nên tỉ lệ này chỉ kiểm chứng được từ soft launch; mọi tần suất, giới hạn video và giá nằm trong config, chỉnh được bằng Remote Config.
- Hướng màn hình: **portrait**
- Nền tảng: **chỉ Android** ở bản hiện tại, iOS phát triển sau. Không có bản web.
- Offline, một người chơi. Ngôn ngữ: `en`, `vi`.
- **Bản demo:** 20 level để duyệt game. **Bản phát hành đầu tiên:** L1–100.
- Game tham khảo: Tap Block Out: Color Puzzle (funsmith). Hôm nay trên Play: 4.7★, 4.11K đánh giá, 100K+ tải, cập nhật 26/10/2026, có sự kiện viền Halloween.
- Đánh giá của người chơi: thích chỉ chạm không cần kéo; chê quảng cáo sau mỗi level và quảng cáo ngay lúc mở game. Game của ta tránh cả hai.

## 3. Luật chơi

- **Bàn cờ cố định, không đổi theo số khối: lưới 14×19 ô, mỗi ô 42 px ở độ phân giải gốc 720×1280, đúng như ảnh ref `art/concepts/ref_board_size.png`** (`Config.BOARD_W`, `BOARD_H`, `BOARD_CELL`). Đây là luật nền của game, mọi level và mọi theme phải giữ.
- Khung đứng cùng một chỗ và cùng một cỡ ở mọi level. Ô chỉ co khi vùng chơi của máy nhỏ hơn bàn chuẩn, không bao giờ phóng to.
- Khối xếp thành một hình ở giữa bàn, không lát kín bàn và không cần kín khung của hình: khoảng trống quanh hình và trong hình là bình thường (mục 4). Khối là polyomino (thanh, L, T, S, U).
- Màu quyết định hướng: vàng lên, xanh lá trái, xanh dương phải, tím xuống. Mỗi cạnh khung là một cổng liền, không có cổng rời.
- Chạm khối, đường thông: khối trượt ra (0,30 s, ease-out), hạt màu bắn ở cạnh, MOVES giảm 1.
- Chạm khối, đường bị chặn: khối trượt tới vật cản, va chạm rồi bật về chỗ cũ, MOVES giảm 1. Bàn cờ không đổi nên không có thế bí.
- `MOVES = số chạm tối thiểu do solver tính + dư`. Dư: L1–3 là 5 (chắc chắn thắng); level thường `max(2, 10% số khối)`; level HARD là 1.
- Cảnh báo độ khó (theo video demo): trên Home có nhãn HARD / VERY HARD phía trên nút Play; vào level thì một dải màu ngang bàn cờ ghi HARD (tím) hoặc VERY HARD (đỏ) trượt vào, giữ `hard_banner_sec` giây rồi tự mờ đi và vào chơi (chạm để bỏ qua). Level HARD từ L100 (`very_hard_from_level`) tính là VERY HARD. Chơi lại cùng level không hiện lại.
- Nghĩ quá lâu rồi đi đúng (mặc định từ 8 giây): hiệu ứng vỗ tay.
- Mỗi level có ít nhất một khối thoát được ngay. Solver kiểm 100% level trong unit test và lúc build.
- Hỗ trợ người mù màu: mũi tên nhỏ trên khối, bật mặc định, tắt được trong Settings.

### Khi hết MOVES

Áp dụng từ L1, không khoá theo level. Mỗi lần hết MOVES hiện một popup +3 Move, tối đa 4 lần mỗi lượt chơi.

| Lần hết MOVES | Có gì | Giá (gold) | Video |
| --- | --- | --- | --- |
| 1 | +3 Move, dùng ngay | 1.900 | Có |
| 2 | +3 Move | 2.200 | Có |
| 3 | +3 Move | 2.500 | Có |
| 4 | +3 Move | 2.800 | Có |
| 5 trở đi | Không còn popup, thua luôn | | |

Luồng:

1. Hết MOVES: hiện popup với giá của lần đó. Mua bằng gold, xem video, hoặc dùng +3 Move trong kho (miễn phí, vẫn tính một lần).
2. Bấm Bỏ cuộc: từ L10 hiện popup xác nhận "Bỏ cuộc sẽ mất 1 mạng". Xác nhận thì thua; huỷ thì quay lại popup. Dưới L10 thua ngay vì không mất mạng.
3. Mua hoặc xem video xong, hết MOVES lần nữa thì sang lần kế (giá kế tiếp). Quá 4 lần là thua luôn, không hiện popup.
4. Chơi lại thì giá về lần 1.

Mọi số (giá từng lần, số lần, số MOVES, số lần có video) nằm trong `Config.ECON` (`rescue_prices`, `rescue_moves`, `rescue_video_max`), Remote Config ghi đè được. Số lần tối đa bằng độ dài mảng `rescue_prices`.

Luật chung:

- Chỉ bán +3 Move: lúc 0 MOVES thì Gợi ý vô dụng, còn Phá khối chỉ thắng được khi còn đúng 1 khối, lúc đó +3 Move rẻ hơn.
- Popup hiện "Còn N khối". Không chặn nút khi N > 3, vì người chơi vẫn có thể mua nhiều lần.
- Thiếu gold: popup vẫn hiện; bấm mua thì mở shop mini tại chỗ, đóng shop thì quay lại popup. Quy tắc không popup offer trong 5 phút đầu phiên đầu (mục 7) không áp dụng cho popup này.

### Mạng

- L1–9: chơi lại miễn phí, không mất mạng. Từ L10: thua mất 1 mạng.
- Tối đa 10 mạng, 15 phút hồi 1 mạng (đang đầy thì không tích thêm).
- Hết mạng: màn chờ đếm ngược, hoặc 900 gold = 5 tim, hoặc xem rewarded = 1 tim. Không có quảng cáo thì báo và cho chờ, không treo. Không bán tim trực tiếp bằng IAP.
- Nút restart từ L10 tốn 1 mạng nếu đã chạm ít nhất một lần trong level, có hỏi xác nhận trước; nếu không, restart sẽ là cách né mất mạng.
- Mỗi lần mua hàng hay xem quảng cáo xong, mạng lưu ngay như gold.

### Tiêu chí thư giãn

- Không timer, không đồng hồ đếm ngược trong level và popup. Màn hết mạng và offer vẫn có đếm ngược vì nằm ngoài level và không phải popup thua.
- Không có màn đỏ hay rung mạnh khi thua. Va chạm dùng rung nhẹ, có thể tắt.
- Mỗi chất liệu khối có âm thanh riêng.
- Không quảng cáo hay popup bán hàng khi mở game, và không chen giữa level.
- Số mạng và level HARD giữ nguyên.

## 4. Level

### Đường cong độ khó L1–100

Độ khó 100 level đầu bám file `difficulty_curve_levels_1-100.json` của PixelFlow (điểm 0–10, trung bình trượt 5 level), nạp vào `src/core/difficulty_curve.gd`. Bộ sinh đổi điểm thành số khối: chuẩn hoá min-max trên 100 level rồi nội suy 2–30 khối; level Hard +2 khối, VeryHard +3 khối, dư MOVES còn 1. Danh sách Hard: 24, 28, 33, 38, 44, 53, 59, 63, 68, 73, 79, 89, 93, 98. VeryHard: 29, 36, 45, 49, 54, 64, 69, 75, 82, 84, 95, 99 (huy hiệu và hộp thoại "rất khó" cho các level này và mọi level HARD từ L100). Cơ chế dày dần theo level kể từ level mở khoá. Bàn có cổng nhịp (L90+) tối đa 20 khối vì solver phải tìm chính xác, nên L91–99 thấp hơn đường cong.

Bốn level đầu làm tay trong `tools/gen_levels.gd` (bảng EARLY). L1–3 chắc chắn thắng: dư 5 MOVES, L1–2 không khối nào bị chặn, L3 chỉ một khối phải chờ.

Mọi level thắng đều +40 gold.

| Level | Màu | Khối | Ghi chú |
| --- | --- | --- | --- |
| 1 | 2 màu (vàng, xanh dương) | 2 | Chữ "Tap the block" |
| 2 | 3 màu | 3 | Không khối bị chặn |
| 3 | 3 màu | 4 | Một khối phải chờ |
| 4 | Đủ 4 màu | 5 | Một khối phải chờ |
| 5–13 | 4 màu | 6–11 | Gợi ý mở ở L5, Rate us ở L10, +3 Move mở ở L12 |
| 14 | 4 màu | 6 | Level dạy Đá |
| 15–29 | 4 màu | 15–24 | Phá khối mở ở L17; L24 là level HARD đầu tiên |

### Hình dạng level

Bàn luôn 14×19 ô (mục 3), nên số khối chỉ quyết định hình to hay nhỏ, không đổi cỡ bàn. Vì ngoài hình là ô trống, dịch cả hình đi không đổi đường thoát của khối.

| Nguồn | Hình |
| --- | --- |
| Từ L21 và Daily Challenge (`src/core/silhouette.gd`) | Chín dạng: oval, thoi, tim, chữ thập, đồng hồ cát, vòm, vòng, mũi tên, nhà. Dưới 6 khối thì xếp hình chữ nhật vì quá ít ô để nhận ra dạng |
| L1–20 | Giữ layout làm tay, dịch vào giữa bàn; L6, 7, 8, 9, 10, 12, 13, 15, 16, 17, 19, 20 trước đây kín hoặc gần kín khung nên sinh lại, giữ số khối trong khoảng của bảng trên (L10 từ 14 còn 13), đúng số màu và HARD |
| Level dạy cơ chế | Giữ bảng làm tay, dịch vào giữa bàn |

- Cỡ hình: số ô khoảng 2,4–3,4 lần số khối, khung hình tối đa 12×17 (chừa một ô mỗi phía), cao tối đa khoảng 1,9 lần rộng, khoét thêm khoảng 6% ô rìa để hình không quá đều. Hình lớn nhất trong ảnh ref là 10×17.
- Sương mù: chỉ khối kề rời đi (thoát hoặc bị phá) mới làm lộ, ô trống sẵn quanh hình không tính. Nhờ vậy mọi khối sương mù đều ẩn lúc đầu, kể cả ở rìa hình.

### Cơ chế sau bản demo

Nguyên tắc: cơ chế chỉ làm bàn cờ dễ hơn theo thời gian hoặc lặp lại theo chu kỳ, không có nước đi nào khiến level không thể thắng. Không timer. Solver phải chứng minh được từng level. Vì vậy không dùng đổi màu ngẫu nhiên hay khối mọc thêm.

Mỗi cơ chế có một level dạy làm tay và một âm thanh riêng. Sau L90 chỉ phối hợp các cơ chế đã có.

| Từ level | Cơ chế | Luật | Âm thanh |
| --- | --- | --- | --- |
| 21 | Đá | Vật cản cố định, không trượt | Va đá trầm |
| 31 | Băng | Cần 2 lần chạm, lần đầu làm nứt; chạm nứt tốn MOVES và đã tính vào `MOVES` | Băng nứt |
| 46 | Xích và chìa | Khối bị xích chỉ đi được khi khối chìa đã thoát | Xích rơi |
| 61 | Hai lớp | Thoát lớp ngoài thì lộ lớp trong, màu khác | Bóc lớp |
| 81 | Sương mù | Không thấy màu cho tới khi một khối kề rời đi | Gió nhẹ |
| 101 | Cổng nhịp | Cổng đóng/mở luân phiên sau mọi lần chạm, kể cả chạm bị chặn | Cổng cơ khí |

Booster với cơ chế:

- Phá khối: không dùng được trên đá; dùng trên băng, xích hoặc hai lớp thì xoá hẳn cả khối.
- Gợi ý: chỉ khối đi được ngay, có tính cổng nhịp.
- Sương mù: mũi tên hỗ trợ mù màu cũng ẩn tới khi lộ. Chạm khối chưa lộ vẫn tốn 1 MOVES nếu bị chặn.

### Mở khoá theo level

| Level | Mở |
| --- | --- |
| Từ đầu | Popup hết MOVES, avatar, frame |
| Sau khi thắng L3 | Quà 28 ngày |
| 5 / 12 / 17 | Gợi ý / +3 Move / Phá khối |
| 5 | Shop và video gold |
| 10 | Mạng, Starter Pack |
| Sau L10 | Interstitial trong phiên đầu |
| 10 | Hỏi đánh giá store (Rate us) |
| 14 / 30 / 40 / 55 / 70 / 90 | 6 cơ chế |
| 50 | Daily Challenge |

Booster chưa mở mà nhận từ lịch quà thì vẫn vào kho, tới level mở thì nút mới hiện. Popup hết MOVES vẫn bán hoặc dùng +3 Move trước L12, vì món này áp dụng ngay. Quà hướng dẫn ở L5/L12/L17 vẫn tặng.

### Thẻ thắng và thẻ thua

Hai thẻ là popup chồng lên màn level (bàn cờ khoá input), không đổi scene. Mỗi lượt chỉ kết thúc một lần: `attempt.ended` chặn cộng gold hai lần. Thẻ đọc `attempt.level`, không đọc `s.level` (đã tăng sau khi thắng).

- **Thắng:** sau khi khối cuối rời bàn chờ `win_delay_sec` (0,8 giây) rồi hiện thẻ. Thẻ có +40 gold, nút x2 (L1 miễn phí, sau đó rewarded; thất bại hiện thông báo và thử lại được), nút Tiếp tục.
- **Thanh tiến trình tính năng:** chạy từ mốc mở gần nhất tới mốc kế trong bảng "Mở khoá theo level" (bỏ Starter, Rate us). Đạt 100% thì đổi dòng thành "Đã mở khoá …". Ẩn khi hết tính năng; bản demo chỉ tính mốc tới L20. Daily Challenge không có thanh.
- **Sau Tiếp tục:** rời thẻ (interstitial `result_exit`, offer, xin quyền thông báo, hỏi đánh giá), rồi: vừa mở tính năng ở Home (quà ngày, shop, Daily Challenge, mạng) hoặc vừa thắng Daily Challenge thì về Home; còn lại vào thẳng level kế. Hết mạng thì sang màn hết mạng; hết level demo thì báo rồi về Home.
- **Thua:** thẻ có chơi lại, về Home, `rescue_pack` nếu có. Không interstitial khi thua. Chơi lại từ L10 mà hết mạng thì sang màn hết mạng.
- **Analytics:** `level_end` kèm `won`, `taps`, `moves_left`, `blocks_left`, `rescues`, `ms`, `replay`.

### Phạm vi

- **Demo:** L1–20, có đủ popup hết MOVES, quà 28 ngày, avatar và frame; có Đá từ L14. Sau L20 hiện "Sắp có level mới". Nút Daily Challenge ở Home hiện khoá, ghi "Unlocked at Level 50". Quảng cáo và mua hàng dùng bản giả lập cho tới khi có cấu hình từ Horus.
- **Bản phát hành đầu tiên:** L1–100 sinh trước bằng công cụ theo đường cong độ khó, solver kiểm và đóng gói sẵn; L1–4 và các level dạy cơ chế làm tay.
- **Sau L100 (vòng lặp):** số level hiển thị tăng mãi (L101, L102…), nội dung quay lại từ level `content_loop_start_level` (mặc định 51) đến L100 rồi lặp tiếp. Cấu hình được qua Remote Config. Bản lưu chỉ giữ số hiển thị nên người chơi nâng cấp từ bản cũ (kể cả đã qua L300) tự nhận nội dung theo vòng lặp, không cần migrate. Daily Challenge vẫn sinh bàn trong game.
- **Daily Challenge (L50):** dùng cùng bộ sinh. +100 gold cho lần thắng đầu tiên mỗi ngày, x2 bằng video như level thường, không có chuỗi ngày và bảng xếp hạng. Thua vẫn mất mạng như level thường.

## 5. Kinh tế (số của người dùng, cập nhật ngày 2026-11-01)

Một loại tiền là **Gold**, không có gem. Trong code biến vẫn tên `coins`; người chơi và analytics thấy "gold".

| Mục | Số | Nguồn |
| --- | --- | --- |
| Gold bắt đầu | 1.000 | Người dùng |
| Thắng một level, mọi độ khó | +40 | Người dùng |
| Gợi ý / +3 Move / Phá khối | 900 / 1.900 / 2.900 | Người dùng; thứ tự gán là suy đoán của mình |
| Refill | 900 = 5 tim | Người dùng |
| Popup hết MOVES lần 1/2/3/4 | 1.900 / 2.200 / 2.500 / 2.800 gold, +3 MOVES, video cả 4 lần | Người dùng (2026-11-01, thay cho bản A/B cũ) |
| 1 video trong shop | 200, tối đa 5 video mỗi ngày (1.000 gold/ngày) | Người dùng (ID 200) |
| Avatar, frame | 50 / 75 / 100 gold hoặc 1 video | Người dùng; mốc 75 là đề xuất của mình |
| Quà 28 ngày | Bảng dưới | Tuần 1 là số cũ; tuần 2–4 đề xuất của mình, người dùng đồng ý |

Không có nhiệm vụ ngày và quà quay lại. Booster giữ trong kho, nút tròn hiện số còn lại hoặc dấu +.

### Quà 28 ngày

| Ngày trong tuần | Tuần 1 | Tuần 2 | Tuần 3 | Tuần 4 |
| --- | --- | --- | --- | --- |
| 1 | 50 | 100 | 150 | 200 |
| 2 | 100 | 150 | 200 | 250 |
| 3 | 1 Gợi ý | 1 Gợi ý | 1 Gợi ý | 1 Gợi ý |
| 4 | 200 | 250 | 300 | 350 |
| 5 | 1 +3 Move | 1 +3 Move | 1 +3 Move | 1 +3 Move |
| 6 | 300 | 350 | 400 | 500 |
| 7 | 500 + 1 Phá khối | 600 + 1 Phá khối | 700 + 1 Phá khối | 1.000 + 1 Phá khối + 1 Gợi ý + 1 +3 Move |

Tổng một vòng: **6.650 gold, 5 Gợi ý, 5 +3 Move, 4 Phá khối**. Hết ô 28 thì về ô 1, vòng sau y hệt.

- Popup quà **chỉ mở khi người chơi bấm** icon quà ở Home, không tự hiện. Icon có chấm đỏ khi còn quà chưa nhận.
- Popup hiện **7 ô của tuần đang đi** trong lịch 28 ô (1–7, 8–14, 15–21, 22–28).
- Mỗi ngày nhận miễn phí ô hiện tại, rồi được xem **1 video mỗi ngày** để nhận trước ô kế tiếp. Lịch tiến thêm một ô, nên ngày mai vẫn có quà mới; người xem đều đặn đi hết vòng trong 14 ngày.
- Lỡ ngày thì lịch chỉ dừng lại, không reset, không phạt.
- Tính theo giờ máy. Giờ máy lùi so với lần nhận trước thì không có quà cho tới khi vượt qua mốc đó. Giới hạn 5 video trong shop cũng theo giờ máy. Rủi ro chỉnh đồng hồ được chấp nhận vì game offline.

### Avatar và frame

- 12 avatar và 12 frame, thêm 1 avatar và 1 frame mặc định miễn phí.
- Giá 50/75/100 gold hoặc 1 video mỗi món, placement `cosmetic_unlock`, không tính vào giới hạn 5 video trong shop.
- Hiển thị ở Home. Bấm vào profile thì mở màn đổi và mua. Không hiện trên thẻ thắng.
- Mua hết khoảng 1.800 gold. Người mới có thể tiêu hết tiền vào đây rồi thiếu tiền chơi tiếp; đây là lựa chọn của người chơi.

### Bảng mô phỏng (2026-11-01, `node tools/sim.mjs`)

Không dùng `economy.simulateEconomy` của Horus vì hàm đó mô hình hoá nâng cấp theo map và quãng đường. Mô phỏng chưa có IAP và chưa tính độ khó của cơ chế từ L21.

Giả định của mình, chưa có số liệu thật:
- Đọc 2,5 giây mỗi khối (HARD 3,5 giây). Thắng lần đầu 95% ở L1, giảm dần còn 72% ở L19; HARD 50%; từ L21 level thường 70%. Chơi tiếp thì 80% cứu được. Booster dùng ở level HARD cộng 15%.
- 20 phút chơi mỗi ngày, chia 2 phiên, mạng đầy lại giữa hai phiên. Mở popup quà 80–90% số ngày.
- "Xem nhiều" xem đủ 5 video shop mỗi ngày, "Thỉnh thoảng" xem 2. Người chơi chỉ mua avatar bằng gold khi còn đủ 1.900 gold sau khi mua.

| Người chơi | Thời gian L1–20 | Số lần chơi | Thua | A bán | B gold / video | Rewarded | Gold còn | Chuỗi level dài nhất dưới 900 gold |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Không xem quảng cáo | 21,6 phút | 24 | 4 | 0,0 | 1,2 / 0,0 | 0 | 806 | 5,7 |
| Thỉnh thoảng xem | 25,6 phút | 21 | 1 | 0,3 | 0,3 / 2,3 | 16 | 1.983 | 2,1 |
| Xem nhiều | 32,4 phút | 20 | 0 | 0,3 | 0,0 / 3,1 | 34 | 4.302 | 0,1 |

| Chặng | Không xem | Thỉnh thoảng | Xem nhiều |
| --- | --- | --- | --- |
| Hết L5 | 1,4 phút, 1.124 gold | 3,8 phút, 1.777 gold | 6,4 phút, 2.506 gold |
| Hết L10 | 4,5 phút, 1.200 gold | 8,1 phút, 1.979 gold | 11,8 phút, 2.844 gold |
| Hết L15 | 10,9 phút, 1.155 gold | 14,9 phút, 1.923 gold | 19,2 phút, 3.063 gold |
| Hết L20 | 21,6 phút, 806 gold | 25,6 phút, 1.983 gold | 32,4 phút, 4.302 gold |

Hết ngày 28:

| Người chơi | Level | Gold còn | Thắng + x2 | Lịch quà | Video shop | Tiêu A | Tiêu B | Avatar | Rewarded/ngày | Interstitial/ngày | Ô lịch |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Không xem | 280 | 894 | 11.200 | 6.650 | 0 | 802 | 17.152 | 1 | 0,0 | 5,3 | 28 |
| Thỉnh thoảng | 294 | 3.544 | 17.611 | 8.995 | 11.200 | 25.684 | 9.457 | 120 | 10,7 | 2,6 | 42 |
| Xem nhiều | 264 | 44.895 | 19.998 | 11.850 | 28.000 | 13.950 | 1.954 | 49 | 18,3 | 0,5 | 53 |

Popup A trong 28 ngày (mô phỏng theo bản A/B cũ, chưa tính lại cho luồng mới):

| Người chơi | Lần hiện | Dùng từ kho | Mua bằng gold | Thiếu gold | Level đầu đủ 1.900 gold |
| --- | --- | --- | --- | --- | --- |
| Không xem | 138 | 6 | 0 | 130 | 187 (trong số người đạt được) |
| Thỉnh thoảng | 106 | 8 | 14 | 30 | 8 |
| Xem nhiều | 85 | 10 | 7 | 1 | 5 |

Cả 20 level không xem quảng cáo kiếm 800 gold, cộng khởi đầu là 1.800.

| Món | Số level thắng để đủ tiền | Số video trong shop |
| --- | --- | --- |
| Gợi ý, refill, B lần 1 | 22,5 | 4,5 |
| +3 Move, popup A | 47,5 | 9,5 |
| Phá khối | 72,5 | 14,5 |

**Lệch mục tiêu của hướng dẫn và điều cần theo dõi:**

- Người không xem quảng cáo có chuỗi 5,7 level liền không đủ 900 gold (mục tiêu 3). Mục tiêu "không bị kẹt" vẫn đạt, vì level luôn thắng được không cần booster.
- "Xem nhiều" mất 32,4 phút cho L1–20, vượt mục tiêu 20–30 phút một chút; phần lớn chênh lệch là thời gian xem video.
- "Xem nhiều" còn **44.895 gold** sau 28 ngày, chủ yếu từ 28.000 gold video shop. Nhóm này gần như không có lý do mua IAP. Giữ số 5 video theo quyết định của người dùng; soft launch cần theo dõi và hạ bằng Remote Config nếu IAP thấp.
- 20 phút mỗi ngày là tới khoảng L264–294 sau 28 ngày, nên 300 level chỉ đủ cho người chơi chăm khoảng một tháng; sau đó là level sinh theo seed.

### Rủi ro người dùng đã chấp nhận khi giữ giá cũ (2026-11-01)

- Popup A đắt hơn B lần 1 cho cùng +3 MOVES, nên người chơi có thể học cách bỏ qua A. Theo dõi tỉ lệ mua A sau soft launch.
- Người không xem quảng cáo gần như không đủ tiền mua A: phần lớn lần hiện A chỉ là cơ hội mở shop IAP.
- Khi còn hơn 3 khối, một lần +3 MOVES chưa đủ để thắng; "Còn N khối" giúp người chơi tự quyết.
- Không có giá trị chuẩn 1 video ≈ 200 gold. Ô quà nhỏ và avatar đáng ít hơn 1 video trong shop, nên ai còn lượt video shop sẽ có lợi hơn khi xem ở đó.
- Avatar và frame gần như không tiêu nhiều gold, tác dụng chính là giữ chân và thêm lượt xem video.

## 6. Quảng cáo

**Rewarded**

| Placement | Ở đâu | Thưởng |
| --- | --- | --- |
| `x2_coins` | Thẻ thắng (L1 miễn phí để biết nút), Daily Challenge | x2 gold của level |
| `booster_free` | Bấm booster khi thiếu gold, 1 lần mỗi lần chơi | 1 lần dùng booster đó |
| `continue_moves` | Popup B, chỉ lần 1 và 2 | +3 MOVES, chơi tiếp, tính một lần |
| `refill_life` | Màn hết mạng (từ L10) | +1 mạng |
| `shop_coins` | Shop, tối đa 5 video mỗi ngày theo lịch của máy | 200 gold mỗi video |
| `daily_next` | Popup quà, 1 lần mỗi ngày, sau khi nhận ô hiện tại | Nhận trước ô kế tiếp |
| `cosmetic_unlock` | Màn profile | 1 avatar hoặc frame |

Chỉ thưởng khi xem hết. Ghi `S.adPend` trước khi hiện quảng cáo và trao lại nếu app bị hệ điều hành đóng giữa chừng, tương tự `ads.lost` của Horus.

**Interstitial** `result_exit`: chỉ khi rời thẻ thắng và đã bỏ qua x2. Theo số của Crash Ramp: không trước lượt 4, cách ít nhất 2 lượt và 120 giây, không trong 90 giây đầu phiên, không trong 45 giây sau rewarded. Phiên đầu không có cho tới khi qua L10. Không có quảng cáo lúc mở game và không chen giữa level.

**Banner: không có.** Giữ màn hình sạch cho cảm giác thư giãn.

**Nền tảng:** AppLovin MAX có mediation. Có luồng đồng ý GDPR, nút "Privacy settings" trong Settings và mediation debugger trong menu tester.

## 7. Mua hàng và offer

**Gói gold (số của người dùng).** Sale chạy thứ Sáu, thứ Bảy và Chủ nhật theo lịch của máy. Remote Config `weekend_sale_mode` chọn đối tượng: 1 = mọi người chơi, 2 = chỉ người chưa mua gói nào (`Game.s.buys` rỗng), 3 = tắt. Lúc sale, Shop gạch giá gói thường, hiện giá `_sale` và nhãn `SALE -50%`; Home có nút Weekend Sale mở Shop (chỉ hiện khi Shop đã mở). Giá trên store không đổi theo ngày được nên mỗi giá sale là một SKU riêng, đuôi `_sale`.

| ID | SKU | Giá | Gold | Gold/$ | Giá sale | Gold khi sale | Gold/$ khi sale |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 201 | `gold_pack_1` | $1.99 | 1.000 | 503 | $0.99 | 2.000 | 2.020 |
| 202 | `gold_pack_2` | $7.99 | 5.000 | 626 | $3.99 | 5.000 | 1.253 |
| 203 | `gold_pack_3` | $14.99 | 10.000 | 667 | $7.49 | 10.000 | 1.335 |
| 204 | `gold_pack_4` | $29.99 | 25.000 | 834 | $14.99 | 25.000 | 1.668 |
| 205 | `gold_pack_5` | $49.99 | 50.000 | 1.000 | $24.99 | 50.000 | 2.001 |
| 206 | `gold_pack_6` | $99.99 | 100.000 | 1.000 | $49.99 | 100.000 | 2.000 |

**Gói khác (nội dung là đề xuất của mình theo bảng giá mới, giá giữ như cũ).** Tính gold/$ theo giá booster mới; các gói đều không vượt giá sale, riêng Rescue là gói nhỏ khi kẹt.

| SKU | Giá | Có gì | Gold/$ quy đổi | Loại |
| --- | --- | --- | --- | --- |
| `remove_ads` | $4.99 | Bỏ interstitial + 500 gold | | Mua một lần, có Restore |
| `starter_pack` | $6.99 | 6.000 gold + 1 mỗi booster; qua L10 hoặc lượt 12, mở 48 giờ | 1.674 | Mua một lần |
| `rescue_pack` | $0.99 | 1 booster +3 Move; thua 3 lần liền một level, mỗi 24 giờ | 1.919 | Dùng hết |
| `level_pack` | $4.99 | 2.000 gold + 1 mỗi booster; mỗi khi qua 10 level, mở 72 giờ | 1.543 | Dùng hết |

Offer Remove Ads hiện ngay sau interstitial thứ 3 trong ngày, tối đa 1 lần/ngày và 3 lần tổng. Không popup offer trong 5 phút đầu phiên đầu, cách nhau ít nhất 3 lượt. `rescue_pack` hiện trên màn thua, sau khi đã bỏ qua popup hết MOVES, nên không tính vào giới hạn popup khi hết MOVES.

**Giao hàng:** lưu hàng trước, xác nhận đơn sau; mỗi token giao một lần; lúc mở game giao hết đơn còn treo; `remove_ads` có Restore. Soft launch kiểm chữ ký của Play Billing ngay trên máy, vì game offline và gold lưu cục bộ nên gian lận khó ảnh hưởng người chơi khác. Khi phát hành toàn cầu, nếu số liệu cho thấy gian lận thì thêm server kiểm đơn.


### Sự kiện: Weekly Pass, Chain Offer, Special Pack (2026-11-02)

Port từ các gói của dự án pixelflow. Mọi số nằm trong `Config.WEEKLY`, `Config.CHAIN`, `Config.PACKS`; mốc thưởng và giá là đề xuất của mình, chưa có số liệu thật.

**Weekly Pass** (`src/meta/weekly_pass.gd`, SKU `weekly_pass`, $4.99, consumable vì mua lại mỗi tuần)

- Mở khoá sau khi qua level HARD thứ 2 (`weekly_unlock_hard_index`). Bản demo dừng ở L20 nên không bao giờ mở; chỉ có ở bản phát hành.
- Chu kỳ theo giờ máy: thứ Hai 06:00 đến thứ Hai 00:00 tuần sau. Thứ Hai 00:00-06:00 là Waiting (nút còn, layer chỉ có đếm ngược). Config tắt hoặc SKU sai là Locked.
- Thắng level (không tính Daily Challenge) khi Active: Normal +1 key, Hard +3, VeryHard +5. Chỉ cộng key sau khi người chơi xem xong tutorial (cờ `s.weekly.tut_seen`, nằm trong bản lưu và không reset theo mùa); xem lần đầu mở layer, nên key thắng trước lúc đó không tính.
- Main Tree: mốc khởi đầu 0 key (free 15 phút mạng vô hạn, VIP 150 gold, nhận được ngay) rồi 10 mốc (VIP mốc 3 key có thêm 30 phút mạng vô hạn), mỗi mốc có thưởng free và thưởng VIP. Bonus Bank mở khi đủ mốc cuối + có VIP + đã xem End popup; cứ 15 key thừa được 1 mốc, tối đa 10 mốc, mỗi mốc 400 gold.
- VIP: +3 mạng tối đa trong tuần (cộng luôn vào số mạng hiện có; hết tuần hoặc sang Waiting thì bỏ, số mạng kẹp lại).
- Sang mùa: chỉ VIP tự nhận mọi thưởng chưa claim; người không VIP không nhận lại phần free chưa claim. Sau đó reset điểm, VIP, danh sách đã nhận. Mùa không chơi thì không có popup cuối mùa.
- Tutorial (`src/ui/weekly_pass_tutorial.gd`, theo video `pixelflow/Recordings/WeeklyPassTutorial.mp4`): lần đầu mở layer khi Active, sau khi popup hiện xong, overlay dim nền và khoét lỗ quanh target, 3 bước trên hàng mốc đầu tiên chưa nhận free (mốc khởi đầu): thưởng free ("Claim your first reward!"), thưởng VIP, thanh tiến độ. Chạm bất kỳ đâu để sang bước kế; bước cuối lưu cờ `tut_seen` rồi mở popup "How to earn rewards" (key theo độ khó, cách nhận thưởng, quyền lợi VIP). Đóng layer giữa chừng thì không lưu cờ, lần sau chạy lại. Nút "i" và biểu tượng chìa ở hàng tiến độ mở lại popup đó bất cứ lúc nào.

**Chain Offer** (`src/meta/chain_offer.gd`)

- Chuỗi bước `free` / `ad` (placement `chain_offer`) / `pay` (SKU `chain_pack_1`, `chain_pack_2`; thưởng lấy từ chính gói, không cộng hai lần). Hai chuỗi xoay vòng, mỗi chuỗi 8 bước, layer hiện cửa sổ 6 bước.
- Bật sau một ván khi chưa có chuỗi, level >= 24 và hết cooldown. `chain_require_lose = -1` (mặc định) xét sau mọi ván; giá trị khác chỉ xét khi thua ở level không HARD.
- Sống 1 ngày, nghỉ 3 ngày. Khác pixelflow: cooldown tính từ **lúc hết hạn**, không phụ thuộc lúc người chơi mở game lại (bản gốc tính từ lúc hàm tắt chạy nên có thể trễ). Làm hết bước không tắt chuỗi.
- Tự mở layer một lần mỗi chuỗi khi về Home; sau đó mở bằng nút ở Home. Không kiểm tra mạng (game offline; bước `ad` và `pay` tự báo không dùng được khi thiếu mạng).

**Special Pack** (`src/meta/pack_conditions.gd`, SKU `special_pack`, $10.99, bản sale `special_pack_sale` $5.49)

- Hiện icon ở Home từ L16, phải đã mua `starter_pack`, mua không giới hạn số lần. Mỗi lần chỉ một gói (gói đầu tiên đủ điều kiện trong `Config.PACKS`). Mở bằng popup offer chung; lúc weekend sale tự đổi sang SKU `_sale`.
- Nội dung: 12.000 gold + 2 mỗi booster.

## 8. Kỹ thuật

### Quan hệ với Horus

Horus SDK là JavaScript và `JavaScriptBridge` của Godot chỉ có ở bản Web, nên APK Godot gốc không gọi được SDK. `AGENTS.md`, `GAME-GUIDE.md`, `README.md`, `horus-logic.mjs` chỉ để tham khảo; quy tắc build và rule "không thêm SDK khác" trong đó không áp dụng cho game này. Khi dựng project, chuyển các file Horus vào `reference/horus/`, chỉ di chuyển, không sửa nội dung.

| Việc | Ai làm |
| --- | --- |
| Ký AAB, đưa lên Play, bản nội bộ để test | Horus (đã xác nhận) |
| `appId`, đăng ký SKU trong Play Console | Horus (đã xác nhận) |
| Cấu hình AppLovin MAX và Firebase | Horus, **sẽ bổ sung sau** |
| Gắn Adjust | Bắt buộc theo Horus; ta gắn trong plugin, Horus gửi cấu hình |
| Viết lại logic của `horus-logic.mjs` bằng GDScript | Được phép (Horus đã xác nhận) |
| Build AAB, APK test | Ta, bằng Godot |

### Cấu trúc

| Chủ đề | Chọn | Lý do |
| --- | --- | --- |
| Engine | Godot 4.7.2, GDScript, renderer Compatibility | Phủ máy Android yếu. Máy dev đã có Android SDK và Java, còn thiếu export templates |
| Lớp nền tảng | Autoload `Platform` với các nhóm `ads`, `iap`, `an`, `rc`, `save`, `notif` đặt tên giống `horus-sdk.d.ts`, kèm bản giả lập để chạy trong editor | Gameplay không phụ thuộc Android; làm iOS sau chỉ cần viết thêm phần nền tảng |
| Plugin Android | Một plugin Kotlin (v2 của Godot) gói MAX, Firebase Analytics, Remote Config, Crashlytics, Adjust, In-App Review, thông báo | Chưa kiểm plugin sẵn có cho MAX; plugin mỏng dễ kiểm soát |
| IAP | Plugin [Godot Google Play Billing](https://github.com/godot-sdk-integrations/godot-google-play-billing), cần Gradle build | Hỗ trợ Godot 4.2 trở lên |
| Số liệu | Mọi con số trong `config.gd`, khoá Remote Config dạng `<nhóm>_<khoá>`, giá trị luôn có mặc định | Theo cách của Horus |
| Logic kiếm tiền | Luật interstitial, offer, lịch quà, lịch thông báo viết bằng GDScript theo mẫu `horus-logic.mjs`, có unit test | SDK không chạy được trong APK gốc |
| Analytics | Tên sự kiện theo mục 16 của `GAME-GUIDE.md`, thêm `rescue_show`, `rescue_use`; mỗi nút video gửi `rv_offer`, `rv_start`, `rv_done`; mọi lần nhận hay tiêu gold đều ghi | Đo được tỉ lệ mua A và 50/50 |
| Lưu game | `user://`, có phiên bản, gộp ghi. Lưu ngay sau khi mua hàng, trước khi hiện quảng cáo và khi ra nền | Theo cách của Horus |
| Cloud save | Play Games Saved Games; xung đột thì giữ bản chơi nhiều hơn và gộp danh sách đơn đã mua; Android Auto Backup làm dự phòng | Không phải vận hành server |
| Thông báo | Local, dùng AlarmManager. Lịch theo mục 15 của `GAME-GUIDE.md`: tuần đầu tối đa 3 lần/ngày, không trước 8:00 hay sau 22:00, rồi thưa dần tới ngày 30, bỏ qua 9 lần liền thì 1 lần/ngày. Chỉ nói thứ đang chờ thật: quà ngày, mạng đầy, gói đang mở. Xin quyền sau lượt 2. Chưa dùng push | Theo cách của Horus |
| Rung | `Input.vibrate_handheld`, có nút tắt | Native |
| Test | Solver và logic chạy bằng script headless | |
| Mô phỏng | `node tools/sim.mjs`, chỉ là công cụ dev | |

### Bản thử

1. **Giai đoạn 1 (làm ngay):** APK debug đo hiệu năng, âm thanh, rung và lưu game trên máy 2 GB. Quảng cáo và mua hàng dùng bản giả lập của `Platform`. Đạt khi chạy ổn định từ 30 khung/giây trở lên. Demo 20 level cũng làm theo cách này.
2. **Giai đoạn 2 (khi Horus gửi cấu hình):** bật MAX, Firebase, Adjust và Play Billing thật, rồi test rewarded, interstitial và mua hàng bằng license tester trên bản nội bộ.

### Tài nguyên hình, icon, âm thanh (MCP ComfyUI)

Hình, icon và âm thanh tạo bằng MCP `comfyui`, không dùng tài nguyên có sẵn của người khác, rồi lưu thành file trong project. Game chạy offline nên bản build không gọi MCP và không cần máy chủ ComfyUI.

**Concept theme: pudding 3D (2026-11-02).** Khối trên bàn là viên pudding trong như gel, theo ảnh duyệt `art/concepts/concept_pudding_board.png` (chất liệu tham khảo dòng game kẹo xếp hình, không dùng hình hay tên game đó). Khe giữa các khối và vị trí lòng khối cố ý khác ảnh: khe hẹp hơn, lòng khối lệch về góc trên trái nhiều hơn một chút. Mã màu bốn khối lấy từ tâm khối trong ảnh, nằm trong `ThemeKit.BLOCK_COLORS`: vàng `#FDE437`, xanh lá `#8DD142`, xanh dương `#2EA4FF`, tím `#8D45E0`. Cổng và hạt dùng chung mã này vì màu quyết định hướng. Thân khối vẽ bằng shader từ các trường khoảng cách của hình khối (`src/ui/pudding.gd`, `src/ui/pudding.gdshader`), phần phủ (mũi tên, băng, xích, sương mù) vẽ bằng code (`BoardFx.draw_block`):

| Lớp | Hình |
| --- | --- |
| Bóng đổ | Cùng hình khối, tối mờ, lệch nhẹ xuống dưới, sát hai bên để không đè lên khối kế bên |
| Thành đáy | Dải tối mỏng khoảng 4% ô dưới mặt khối; ở khối vàng là màu be, ba màu còn lại là màu gốc đậm |
| Vạch sáng đáy | Đường sáng mảnh ngay trên thành đáy, cong theo hai góc dưới |
| Viền | Vạch nhạt ở trên; hai bên chỉ có đường rất mảnh; mép phải tối dần |
| Sườn | Vát quanh lòng khối: hẹp ở trên và bên trái (khoảng 10% ô), rộng hơn ở bên phải (khoảng 15% ô); màu theo hướng: trên sáng, trái vừa, phải tối |
| Dải đáy | Dày khoảng 21% ô, trong và sáng dần về phía vạch sáng |
| Lòng khối | Lõm, bo góc mềm, lệch nhẹ về góc trên trái; sáng ở trên và góc trên trái, đậm dần về đáy và bên phải; đường sáng mảnh dọc mép trái; nếp sáng mảnh ngoài mép dưới và mép phải |
| Vệt sáng | Mỗi góc lồi trên trái có một vệt cong trắng, một chấm nhỏ dưới đuôi vệt và một vệt mờ ngang ở mép trên; góc lõm mở về phía trên trái có một chấm sáng nhỏ |

- Mỗi màu có bảng 12 màu đo từ ảnh (`Pudding.PALETTES`). Sương mù và khối bị xích suy ra từ bảng này hoặc từ màu gốc, nên giữ cùng cấu trúc vật liệu.
- Trường khoảng cách dựng một lần cho mỗi hình rồi cache (không phụ thuộc màu hay cỡ ô, khoảng 3–18 ms mỗi hình trên máy dev). Shader chỉ đọc texture 3 lần mỗi pixel, nên khối chữ L, T, vòng rỗng... đều ra đúng cấu trúc.
- Khối nhiều ô liền một viên: không khe giữa các ô trong khối; góc lồi bo khoảng 15% ô, góc lõm mềm. Khe giữa hai khối là 1% ô.
- Cỡ ô là số nguyên (làm tròn xuống) để các ô của một khối khớp pixel, không lộ đường nối.
- Mũi tên mù màu hạ nhẹ xuống dưới tâm ô để không chạm vệt sáng. Băng, xích, sương mù vẽ đè lên lớp pudding, giữ nguyên cách đọc. Khối hai lớp: lớp trong là viên pudding nhỏ bằng nửa ô, dùng cùng shader.
- Chưa áp dụng cho nền, khung cổng, đá, icon (giữ nét hiện tại, trừ màu cổng). Khi tạo hoặc làm lại hình bằng MCP, thêm từ khoá pudding/gel 3D (xem quy tắc prompt bên dưới) để cùng phong cách.
- Màn level chỉ có thanh trên (lượt, tên level, restart, bánh răng; Home nằm trong popup cài đặt) và hàng booster chiếm chiều cao, luôn giữ chỗ cho booster; chữ hướng dẫn và nhãn Phá khối phủ lên phần trên của bàn. Nhờ vậy khung không xê dịch giữa các level. Nền bàn trơn, không vẽ lưới ô.

**Vẫn vẽ bằng code (và shader):** hình khối, cổng, mũi tên hỗ trợ mù màu, hạt, và mọi chữ. Khối phải khớp từng ô, mũi tên phải rõ ở cỡ nhỏ, chữ phải đổi được giữa `en` và `vi`. Hình do MCP tạo không có chữ; số như "+3" vẽ đè bằng code.

| Việc | Công cụ | Ghi chú |
| --- | --- | --- |
| Hình và icon mới | `start_game_image`, rồi `collect_game_image` | Qwen Image 2.1, xuất PNG, cạnh 256–2048 và là bội số của 32 |
| Icon nền trong | Như trên, `transparent_background=true` | Kiểm alpha chỉ biết file có trong suốt, không biết đường cắt có đẹp không |
| Giữ đồng bộ phong cách | `edit_game_image` với ảnh tham chiếu | Duyệt `ui_gold` trước, rồi dùng làm tham chiếu cho các icon còn lại |
| Tách nền ảnh có sẵn | `remove_image_background` | Qwen vẽ lại ảnh, không phải cắt chính xác, nên có thể đổi chi tiết |
| Hiệu ứng và nhạc | `start_game_audio`, rồi `collect_game_audio` | Stable Audio 3 Medium Base, 1–384 giây, xuất `flac` làm bản gốc |

**Hình** (danh sách và cỡ là đề xuất của mình)

| File | `asset_type` | Cỡ tạo → cỡ dùng | Nội dung |
| --- | --- | --- | --- |
| `icon_app` | `icon`, nền đặc | 1024 → các cỡ bản build cần | Một khối màu trượt ra cổng |
| `bg_home`, `bg_level` | `background` | 768×1664 → rộng 720 | Nền ít chi tiết, phần giữa yên để bàn cờ nổi; cắt được cho 360×640 |
| `block_surface` | Bỏ | | Không còn dùng: chất liệu kẹo cứng vẽ hoàn toàn bằng code (xem Concept theme) |
| `ui_gold`, `ui_heart`, `ui_hint`, `ui_moves`, `ui_smash` | `icon`, nền trong | 1024 → 128 | Gold, mạng, 3 booster |
| `ui_shop`, `ui_settings`, `ui_lock`, `ui_restart`, `ui_video`, `ui_gift`, `ui_profile`, `ui_sound`, `ui_music` | `icon`, nền trong | 1024 → 128 | Nút và trạng thái; tắt âm thì code vẽ gạch chéo |
| `art_win`, `art_lose`, `art_no_lives` | `ui`, nền trong | 1024 → 512 | Thẻ thắng, popup thua, màn hết mạng |
| `avatar_00`–`avatar_12` | `icon`, nền trong | 1024 → 256 | Avatar; `00` là mặc định |
| `frame_00`–`frame_12` | `ui`, nền trong | 1024 → 256 | Frame bao avatar, giữa trong suốt; `00` là mặc định |
| `mech_stone`, `mech_ice`, `mech_chain`, `mech_key`, `mech_fog` | `image`, nền trong | 512 → 128 | Lớp phủ cơ chế sau demo |

**Âm thanh** (danh sách và thời lượng là đề xuất của mình)

| File | `category` | Tạo → dùng | Dùng ở |
| --- | --- | --- | --- |
| `sfx_button`, `sfx_tap` | `One-shot` | 1 giây → cắt còn tối đa 0,2 giây | Bấm nút, chạm khối |
| `sfx_exit` | `SFX` | 1 giây → khoảng 0,4 giây | Khối trượt ra (hoạt ảnh 0,30 giây) |
| `sfx_blocked` | `SFX` | 1 giây → khoảng 0,3 giây | Khối va chạm rồi bật về |
| `sfx_coin`, `sfx_hint`, `sfx_moves`, `sfx_smash`, `sfx_life_lost` | `SFX` | 2 giây → tối đa 1 giây | Nhận gold, 3 booster, mất mạng |
| `sfx_win`, `sfx_lose`, `sfx_clap` | `SFX` | 3 giây | Thắng, thua, vỗ tay khi nghĩ lâu rồi đi đúng |
| `sfx_stone`, `sfx_ice`, `sfx_chain`, `sfx_layer`, `sfx_fog`, `sfx_gate` | `SFX` | 2 giây → tối đa 1 giây | 6 cơ chế sau demo |
| `bgm_home`, `bgm_level` | `Music` | 90 và 120 giây, lặp | Nhạc Home, nhạc trong level; nhẹ, không lời, không tạo cảm giác gấp |

**Cách làm**

1. Prompt nào cũng theo một bộ quy tắc: nét bo tròn, màu tươi, chất liệu pudding/gel 3D trong suốt (viền nhạt mỏng, sườn vát, lòng lõm đậm dần về góc dưới phải, dải đáy dày sáng dần, thành đáy tối mỏng, vệt sáng trắng cong ở góc trên trái), đổ bóng nhẹ, nền sạch, không chữ, không logo, không watermark. Màu khối ghi đúng mã màu đang dùng trong game. Không đưa tên hay ảnh của game gốc vào prompt hoặc ảnh tham chiếu.
2. Dùng seed cố định và `use_reprompt=false`, để prompt lưu lại đúng là prompt đã chạy. Ghi công cụ, prompt, seed, steps và SHA256 của từng file vào `art/manifest.json`.
3. Tạo thư mục cha trước khi gửi job. MCP không ghi đè file, nên làm lại thì lưu tên mới (`_v2`). Job chưa xong thì gọi lại `collect_*` với cùng `prompt_id`, không gửi job mới.
4. Bản gốc nằm trong `art/`, không vào bản build (loại khỏi export bằng filter hoặc `.gdignore`). File dùng trong game nằm trong `assets/`: PNG cho hình, Godot tự import; **WAV cho hiệu ứng** để giảm độ trễ, **Ogg cho nhạc nền** để lặp liền mạch. Thu nhỏ, cắt khoảng lặng và cân âm lượng bằng `ffmpeg`, chỉ là công cụ dev.
5. Nhạc nền phải nghe thử chỗ nối vòng lặp và đặt loop trong import của Godot; thời lượng tạo ra không bảo đảm nối liền.
6. File lỗi hoặc giải mã không được thì game vẫn chơi tiếp, chỉ thiếu tiếng hoặc thiếu hình trang trí. Quảng cáo mở hoặc app ra nền thì dừng nhạc và lưu game.

**Xong khi:** mọi file trong hai bảng trên có trong `art/manifest.json`; icon nhìn rõ ở 48px trên máy thật cỡ 360×640; không có chữ lạ hay viền cắt xấu; hiệu ứng khớp lúc chạm; nhạc không có tiếng nảy khi lặp; tổng `assets/` tối đa 10 MB (trần đề xuất của mình, nâng từ 5 MB vì WAV và avatar). Tài nguyên cơ chế sau demo chưa cần cho demo.

## 9. Nhật ký quyết định

**2026-11-02**

- Đổi concept hình khối sang pudding 3D theo ảnh duyệt `concept_pudding_board`; đổi bốn mã màu khối theo ảnh; khe giữa hai khối còn 1% ô; lòng khối lệch nhẹ về góc trên trái, nhiều hơn trong ảnh một chút; mỗi góc lồi trên trái có vệt sáng riêng.

**2026-11-01**

- Chuyển sang Godot 4.7.2 Android gốc; iOS làm sau; bỏ bản web.
- Horus lo tài khoản store, ký và phát hành; quảng cáo, IAP tự tích hợp; analytics, Remote Config, cloud save, thông báo làm theo cách của Horus.
- Luồng hết MOVES: một popup +3 MOVES tối đa 4 lần, giá 1.900 / 2.200 / 2.500 / 2.800, có video; bỏ qua thì xác nhận mất 1 mạng (từ L10) rồi thua. Thay cho bản popup A + B cũ.
- Quà 28 ngày thay quà 7 ngày, có video nhận trước ô kế tiếp, popup chỉ mở khi bấm và hiện 7 ô.
- Bỏ nhiệm vụ ngày, quà quay lại và `comeback_x2`.
- Đổi concept hình khối sang pudding/gel bóng (ảnh duyệt `concept_candy_board_v1`), vẽ bằng code; bỏ tài nguyên `block_surface`.
- Đổi concept hình khối từ pudding sang kẹo cứng bóng có vệt chéo (ảnh tham chiếu của người dùng), vẫn vẽ bằng shader `src/ui/pudding.gdshader`.
- Thêm avatar và frame, 6 cơ chế từ L21, bảng mở khoá, thưởng Daily Challenge, tiêu chí thư giãn.
- Dùng AppLovin MAX, không có banner.

**2026-11-02**

- Bàn cờ cố định 14×19 ô, ô 42 px theo ảnh ref, không đổi theo số khối; khối xếp thành nhiều hình ở giữa bàn, có khoảng trống. Sinh lại L21–300; L1–20 giữ layout tay, trừ 12 level trước đây kín hoặc gần kín khung. Sương mù chỉ lộ khi khối kề rời đi. Đưa MOVES lên thanh trên, bỏ lưới ô trên nền bàn.
- Thêm Weekly Pass, Chain Offer, Special Pack (mục 7). Weekly Pass chỉ có ở bản phát hành vì demo không có level HARD thứ 2 trong phạm vi L1-20.
- Weekly Pass: thêm mốc khởi đầu 0 key, hàng tiến độ (nút "i", chìa, thanh tới mốc kế), tutorial 3 bước và popup "How to earn rewards"; key chỉ được cộng sau khi xem tutorial. Giảm chiều cao vùng cuộn của layer (640 xuống 500) vì panel vượt màn 720x1280.
- Thêm loại thưởng "mạng vô hạn" (`inf_min`, phút; `s.lives.inf_until`): đang còn hạn thì thua không mất mạng, Home hiện "Mạng: vô hạn" cùng đếm ngược, cảnh báo mất mạng khi bỏ ván bị ẩn; cấp thêm khi còn hạn thì cộng dồn. Dùng cho mốc khởi đầu Weekly Pass (15 phút, theo video) và VIP mốc 3 key (30 phút).
