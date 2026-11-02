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
| Level sau khác gì | Thêm màu (1 → 4), nhiều khối hơn, chuỗi chặn sâu hơn, dư MOVES ít hơn, có level HARD xen kẽ. Từ L21 thêm 6 cơ chế (mục 4). |

## 2. Thông số đã có

- Mục tiêu: game **thư giãn ASMR**, doanh thu **50% IAA, 50% IAP**. Đo theo cohort 30 ngày đầu: doanh thu quảng cáo so với IAP sau phí store. Chưa có số liệu thật nên tỉ lệ này chỉ kiểm chứng được từ soft launch; mọi tần suất, giới hạn video và giá nằm trong config, chỉnh được bằng Remote Config.
- Hướng màn hình: **portrait**
- Nền tảng: **chỉ Android** ở bản hiện tại, iOS phát triển sau. Không có bản web.
- Offline, một người chơi. Ngôn ngữ: `en`, `vi`.
- **Bản demo:** 20 level để duyệt game. **Bản phát hành đầu tiên:** L1–300.
- Game tham khảo: Tap Block Out: Color Puzzle (funsmith). Hôm nay trên Play: 4.7★, 4.11K đánh giá, 100K+ tải, cập nhật 26/10/2026, có sự kiện viền Halloween.
- Đánh giá của người chơi: thích chỉ chạm không cần kéo; chê quảng cáo sau mỗi level và quảng cáo ngay lúc mở game. Game của ta tránh cả hai.

## 3. Luật chơi

- Bàn cờ lưới ô vuông, tối đa 8×11 trong 20 level đầu. Khối là polyomino (thanh, L, T, S, U).
- Cỡ ô giữ nguyên qua mọi level: tính theo bàn 8×11 trong vùng chơi, bàn nhỏ hơn thì để trống xung quanh chứ không phóng to ô cho đầy.
- Màu quyết định hướng: vàng lên, xanh lá trái, xanh dương phải, tím xuống. Mỗi cạnh khung là một cổng liền, không có cổng rời.
- Chạm khối, đường thông: khối lao nhanh dần tới thanh cùng màu (tối đa 0,30 s), vỡ thành mảnh kẹo bay xuyên qua thanh, MOVES giảm 1.
- Chạm khối, đường bị chặn: khối lao tới vật cản, nhún khi va chạm rồi bật về chỗ cũ, khối bị va nhún theo, MOVES giảm 1. Bàn cờ không đổi nên không có thế bí.
- `MOVES = số chạm tối thiểu do solver tính + dư`. Dư: L1–5 là 3; level thường `max(2, 10% số khối)`; level HARD là 1.
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

### 20 level đầu

Layout do mình tự thiết kế (đối xứng, vòng lồng nhau, hình vòm), không chép từ video của game gốc.

Mọi level thắng đều +40 gold.

| Level | Màu | Khối | Ghi chú |
| --- | --- | --- | --- |
| 1 | Vàng | 2 | Chữ "Tap the block" |
| 2–3 | Vàng | 3–4 | Khối đầu tiên bị chặn |
| 4–5 | + xanh lá | 5–7 | Mở Gợi ý, tặng 1 lần dùng |
| 6–7 | + xanh dương | 8–10 | Mở +3 Move, tặng 1 lần |
| 8 | 3 màu | 10 | **HARD** |
| 9–11 | Đủ 4 màu | 12–15 | Mở Phá khối ở L9, tặng 1 lần |
| 12 | 4 màu | 16 | **HARD** |
| 13–15 | 4 màu | 16–20 | Chuỗi chặn sâu hơn |
| 16 | 4 màu | 22 | **HARD** |
| 17–19 | 4 màu | 22–26 | L18 hỏi đánh giá store sau khi thắng |
| 20 | 4 màu | 28 | **HARD**, kết chặng |

### Cơ chế sau bản demo

Nguyên tắc: cơ chế chỉ làm bàn cờ dễ hơn theo thời gian hoặc lặp lại theo chu kỳ, không có nước đi nào khiến level không thể thắng. Không timer. Solver phải chứng minh được từng level. Vì vậy không dùng đổi màu ngẫu nhiên hay khối mọc thêm.

Mỗi cơ chế có một level dạy làm tay và một âm thanh riêng. Sau L101 chỉ phối hợp các cơ chế đã có.

| Từ level | Cơ chế | Luật | Âm thanh |
| --- | --- | --- | --- |
| 21 | Đá | Vật cản cố định, không trượt | Va đá trầm |
| 31 | Băng | Cần 2 lần chạm, lần đầu làm nứt; chạm nứt tốn MOVES và đã tính vào `MOVES` | Băng nứt |
| 46 | Xích và chìa | Khối bị xích chỉ đi được khi khối chìa đã thoát | Xích rơi |
| 61 | Hai lớp | Thoát lớp ngoài thì lộ lớp trong, màu khác | Bóc lớp |
| 81 | Sương mù | Không thấy màu cho tới khi ô bên cạnh trống | Gió nhẹ |
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
| 4 / 6 / 9 | Gợi ý / +3 Move / Phá khối |
| 5 | Shop và video gold |
| 10 | Mạng, Starter Pack |
| Sau L10 | Interstitial trong phiên đầu |
| 18 | Hỏi đánh giá store |
| 21 / 31 / 46 / 61 / 81 / 101 | 6 cơ chế |
| 50 | Daily Challenge |

Booster chưa mở mà nhận từ lịch quà thì vẫn vào kho, tới level mở thì nút mới hiện. Popup hết MOVES vẫn bán hoặc dùng +3 Move trước L6, vì món này áp dụng ngay. Quà hướng dẫn ở L4/L6/L9 vẫn tặng.

### Phạm vi

- **Demo:** L1–20, có đủ popup hết MOVES, quà 28 ngày, avatar và frame; chưa có cơ chế mới. Sau L20 hiện "Sắp có level mới". Nút Daily Challenge ở Home hiện khoá, ghi "Unlocked at Level 50". Quảng cáo và mua hàng dùng bản giả lập cho tới khi có cấu hình từ Horus.
- **Bản phát hành đầu tiên:** L21–300 sinh trước bằng công cụ, solver kiểm và đóng gói sẵn; level dạy cơ chế làm tay.
- **Sau L300 (vòng lặp):** số level hiển thị tăng mãi (L301, L302…), nội dung quay lại từ level `content_loop_start_level` (mặc định 101) đến L300 rồi lặp tiếp. Cấu hình được qua Remote Config. Bản lưu chỉ giữ số hiển thị nên người chơi nâng cấp từ bản cũ (kể cả đã qua L300) tự nhận nội dung theo vòng lặp, không cần migrate. Daily Challenge vẫn sinh bàn trong game.
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

**Gói gold (số của người dùng).** Sale chạy thứ Bảy và Chủ nhật theo lịch của máy. Giá trên store không đổi theo ngày được nên mỗi giá sale là một SKU riêng, đuôi `_sale`.

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

**Concept theme: kẹo sọc (2026-11-02).** Khối trên bàn là viên kẹo gel bóng có sọc chéo, theo ảnh duyệt `art/concepts/concept_candy_board_v5_stripe.png`, thay concept pudding ngày 2026-11-01 (chất liệu tham khảo dòng game kẹo xếp hình, không dùng hình hay tên game đó). Thân khối vẽ bằng shader từ khoảng cách tới mép của hình khối (`src/ui/pudding.gd`, `src/ui/pudding.gdshader`), vệt bóng và phần phủ bằng code (`BoardFx.draw_block`). Số đo lấy trực tiếp từ ảnh duyệt (ô 36 px), đơn vị là ô:

| Lớp | Hình | Số đo |
| --- | --- | --- |
| Hình khối | Ô liền một viên, không đường nối; góc lồi bo, góc lõm bo mềm | Bo lồi 0,25; bo lõm 0,13; khe giữa hai khối 0,028 |
| Bóng đổ | Ám chàm, không đen, mềm, lệch xuống dưới; nằm ở lớp riêng dưới mọi khối nên không đổ lên khối bên cạnh | Lệch 0,09; mờ 0,13; đậm 34% |
| Mép gối | Đậm màu ở mép, chuyển mềm vào mặt, ánh sáng từ trên trái; mép phải tối hơn mép trái | Trên 0,02; hai bên 0,2; đáy 0,28; chuyển 0,11 |
| Sọc | Dải chéo 45 độ lên phải, cạnh sắc, nửa đậm nửa nhạt; theo toạ độ ô nên khối cạnh nhau liền pha và sọc đi theo khối khi trượt; mờ đi khi qua mép gối | Chu kỳ ngang đúng 1 ô |
| Sáng mặt | Pha trắng, mạnh nhất ở mép trên, nhạt dần xuống dưới | Tầm 0,6; tối đa 26% |
| Vệt bóng | Mỗi mép hướng lên một vạch trắng mảnh. Đầu vạch ở góc lồi là đốm trắng móc nhẹ xuống; đầu vạch ở góc lõm là lưỡi liềm cong lên theo thành | Cách mép 0,14; vạch đậm 55%, đốm 100% |
| Vạch đáy | Vạch sáng mảnh sát mép dưới, rõ hơn ở góc dưới phải | Cách mép 0,05 |

Mỗi màu có bốn tông trong `ThemeKit.BLOCK_RAMPS`, vì tông đổi cả sắc độ (vàng về cam, tím về tím đậm) nên không suy ra từ một màu. `face` cũng là `ThemeKit.BLOCK_COLORS`, nên cổng, hạt và khối cùng một màu:

| Màu | `deep` (đáy) | `side` (hai bên) | `face` (sọc đậm) | `stripe` (sọc nhạt) |
| --- | --- | --- | --- | --- |
| Vàng | `F19B09` | `F8B20F` | `FDD414` | `FDE846` |
| Xanh lá | `20A208` | `41C412` | `6DED1E` | `84F437` |
| Xanh dương | `0260E6` | `148FF8` | `0C9CFD` | `41C1FD` |
| Tím | `B113CC` | `C622DC` | `E644F4` | `EC5FF6` |

- Texture khoảng cách tới mép (SDF) dựng một lần cho mỗi hình khối rồi cache (không phụ thuộc màu hay cỡ ô, khoảng 4–35 ms mỗi hình trên máy dev); shader dùng SDF để tính mép gối, vạch đáy và bóng, nên khối chữ L, T, ... đều ra đúng cấu trúc, viền góc liền một nét. Mỗi điểm ảnh đọc texture tối đa 7 lần.
- Cỡ ô là số nguyên (làm tròn xuống) để các ô của một khối khớp pixel.
- Ảnh duyệt không có mũi tên trên khối, nhưng mũi tên mù màu vẫn bật mặc định (mục 2), hạ nhẹ xuống dưới tâm ô để không chạm vệt bóng. Băng tô trong hình khối bằng shader nên không tràn ra góc bo, nháy sáng Gợi ý cũng vậy; xích, sương mù vẽ đè lên lớp kẹo, giữ nguyên cách đọc. Khối hai lớp: viên trong dùng đúng shader và vệt bóng đó ở cỡ nhỏ hơn.
- Chưa áp dụng cho nền, đá, icon (giữ nét hiện tại). Khi tạo hoặc làm lại hình bằng MCP, thêm từ khoá kẹo gel bóng (xem quy tắc prompt bên dưới) để cùng phong cách.

**Khung cổng (2026-11-02).** Khung theo cùng ảnh duyệt, vẽ bằng shader (`src/ui/candy_frame.gd`, `frame_bar.gdshader`, `frame_corner.gdshader`), số đo theo ô:

| Phần | Hình | Số đo |
| --- | --- | --- |
| Thanh cổng | Bốn capsule rời nhau, mỗi cạnh một màu cổng, tô theo mặt cắt đo trung vị dọc thanh trong ảnh (`BAR_RAMPS`); thanh ngang có vạch sáng ở trên và dải đậm ở dưới, thanh dọc đậm ở hai mép; đầu trên thanh dọc có vòng sáng, đầu dưới đậm dần | Dày 0,645–0,70; từ mép bàn tới đường giữa thanh: trên 0,87, dưới 0,89, trái 1,11, phải 1,09 |
| Ống góc | Một phần tư vành tròn hồng đỏ nối hai thanh, nằm dưới đầu thanh; vệt trắng chạy theo cung, vị trí đổi theo từng góc vì ánh sáng từ trên hơi lệch trái | Bán kính tới đường giữa 0,58; rộng 0,52 |
| Mũi tên | Tam giác trắng bo góc, chỉ ra ngoài, viền mờ màu đậm của thanh; ở thanh dọc đặt cao hơn tâm | Ngang 0,525 (thanh dọc 0,59), dọc 0,40–0,415; thanh dọc lệch lên 0,25 |
| Bóng đổ | Mềm, lệch xuống dưới, ám tím đậm | Lệch 0,11; mờ 0,14; đậm 32% |

- Khung chiếm thêm 1,46 ô mỗi bên và 1,23 ô trên dưới (trước là 0,3 ô), nên cỡ ô giảm khoảng 14% ở cùng vùng chứa: 64 → 55 px với bàn 720×1280. Cỡ ô vẫn tính theo bàn tham chiếu 8×11 nên mọi level cùng một cỡ.
- Cổng nhịp đóng: thanh tối đi 55%, mũi tên mờ, hiện các vạch chắn ngang thanh; khi đổi trạng thái thì nháy sáng trong hình thanh. Khối bị cổng đóng chặn trượt qua khoảng trống tới mặt trong của thanh rồi bật về; hạt lúc khối thoát bắn ở mặt trong của thanh.
- Nền bàn giữ màu cũ, chỉ đổi hình theo khung (tới đường giữa thanh, bo theo ống góc).

**Hiệu ứng vỡ và va chạm (2026-11-02).** Mức "đẹp mà vẫn êm" do người dùng chọn: nhiều chi tiết nhưng bàn chỉ rung nhẹ, đúng tiêu chí thư giãn ở mục 3. Không có lần nào chặn thao tác: người chơi chạm tiếp được ngay. Vẽ bằng code và shader (`src/ui/candy_shards.gd`, `candy_shard.gdshader`, `impact_flash.gdshader`); mảnh dùng chung chất liệu với khối qua `candy_body.gdshaderinc`.

| Khoảnh khắc | Diễn biến | Số đo |
| --- | --- | --- |
| Khối lao tới thanh | Nhanh dần, dài ra theo hướng lao, tới đúng mặt trong của thanh cùng màu | 0,14–0,30 giây tuỳ quãng đường; dài ra 9% |
| Vỡ | Khối nứt loé trắng rất ngắn tại chỗ rồi nổ: mảnh gần điểm va bay trước. Mảnh lấy đúng chỗ của nó trên khối nên giữ nguyên sọc, mép và vạch bóng, rìa gãy sáng như kẹo trong có bề dày, loé khi xoay | Khựng 0,05 giây; khoảng 20 mảnh lớn (2–6 mảnh mỗi ô) và 10–24 vụn |
| Mảnh bay | Xuyên qua thanh, toả rộng rồi rơi theo trọng lực, bay đè lên cả vùng ngoài bàn, nút và chữ; nhỏ dần và mờ ở cuối | 7–19 ô/giây; rơi 26 ô/giây²; sống 0,6–1,05 giây |
| Thanh bị va | Bật ra rồi nảy về, sóng sáng chạy dọc thanh từ điểm va, mũi tên phồng lên | 0,45 giây; bật 0,1 ô |
| Loé sáng | Quầng sáng, sao bốn cánh và vòng sóng toả ra, kèm sao lấp lánh | Vỡ: rộng 4,8 ô, 18 sao. Va chạm: rộng 2,6 ô, 7 sao |
| Va chạm | Khối đi va nhún theo trục va, tâm nhún ở điểm chạm rồi về chỗ cũ không vượt quá; vụn kẹo và sao văng ra ở điểm chạm | Nhún 15%, 0,46 giây; 7 vụn mỗi khối |
| Khối bị va | Giật lùi rồi về đúng ô, nhún theo, dư chấn lan sang tối đa 2 khối nằm ngay phía sau, mỗi khối yếu đi một nửa | Nhún 10%; lùi 0,1 ô; trễ 0,05 giây mỗi khối |
| Chạm đá, cổng đóng | Chỉ khối kẹo nhún và văng vụn; cổng đóng còn có thanh bị va | Như trên |

- Khối còn trong sương mù: vụn va chạm dùng màu xám để không lộ màu. Khi vỡ thì đã thoát nên mảnh dùng đúng màu thật.
- Trận thắng chờ tối đa 0,55 giây sau lần vỡ cuối trước khi hiện thẻ thắng; mảnh còn lại rơi tiếp đè lên thẻ tới hết đời.
- Shader hiệu ứng được biên dịch sẵn khi vào màn đầu tiên.

**Vẫn vẽ bằng code (và shader):** hình khối, lưới, cổng, mũi tên hỗ trợ mù màu, hạt, và mọi chữ. Khối phải khớp từng ô, mũi tên phải rõ ở cỡ nhỏ, chữ phải đổi được giữa `en` và `vi`. Hình do MCP tạo không có chữ; số như "+3" vẽ đè bằng code.

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
| `block_surface` | Bỏ | | Không còn dùng: chất liệu khối vẽ hoàn toàn bằng code (xem Concept theme) |
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
| `sfx_exit` | `SFX` | 1 giây → khoảng 0,4 giây | Khối thoát, dùng tạm lúc khối vỡ khi chưa có `sfx_shatter` |
| `sfx_blocked` | `SFX` | 1 giây → khoảng 0,3 giây | Khối va chạm rồi bật về, dùng tạm khi chưa có `sfx_bump` |
| `sfx_shatter` | `SFX` | 2 giây → tối đa 0,7 giây | Khối vỡ ở thanh; **chưa tạo**, xem `art/MISSING.md` |
| `sfx_bump` | `SFX` | 1 giây → tối đa 0,3 giây | Kẹo va vào kẹo; **chưa tạo**, xem `art/MISSING.md` |
| `sfx_coin`, `sfx_hint`, `sfx_moves`, `sfx_smash`, `sfx_life_lost` | `SFX` | 2 giây → tối đa 1 giây | Nhận gold, 3 booster, mất mạng |
| `sfx_win`, `sfx_lose`, `sfx_clap` | `SFX` | 3 giây | Thắng, thua, vỗ tay khi nghĩ lâu rồi đi đúng |
| `sfx_stone`, `sfx_ice`, `sfx_chain`, `sfx_layer`, `sfx_fog`, `sfx_gate` | `SFX` | 2 giây → tối đa 1 giây | 6 cơ chế sau demo |
| `bgm_home`, `bgm_level` | `Music` | 90 và 120 giây, lặp | Nhạc Home, nhạc trong level; nhẹ, không lời, không tạo cảm giác gấp |

**Cách làm**

1. Prompt nào cũng theo một bộ quy tắc: nét bo tròn, màu tươi, chất liệu kẹo gel bóng (sọc chéo 45 độ, mép gối đậm màu dày ở đáy, vạch sáng trắng ở mép trên), đổ bóng nhẹ, nền sạch, không chữ, không logo, không watermark. Màu khối ghi đúng mã màu đang dùng trong game. Không đưa tên hay ảnh của game gốc vào prompt hoặc ảnh tham chiếu.
2. Dùng seed cố định và `use_reprompt=false`, để prompt lưu lại đúng là prompt đã chạy. Ghi công cụ, prompt, seed, steps và SHA256 của từng file vào `art/manifest.json`.
3. Tạo thư mục cha trước khi gửi job. MCP không ghi đè file, nên làm lại thì lưu tên mới (`_v2`). Job chưa xong thì gọi lại `collect_*` với cùng `prompt_id`, không gửi job mới.
4. Bản gốc nằm trong `art/`, không vào bản build (loại khỏi export bằng filter hoặc `.gdignore`). File dùng trong game nằm trong `assets/`: PNG cho hình, Godot tự import; **WAV cho hiệu ứng** để giảm độ trễ, **Ogg cho nhạc nền** để lặp liền mạch. Thu nhỏ, cắt khoảng lặng và cân âm lượng bằng `ffmpeg`, chỉ là công cụ dev.
5. Nhạc nền phải nghe thử chỗ nối vòng lặp và đặt loop trong import của Godot; thời lượng tạo ra không bảo đảm nối liền.
6. File lỗi hoặc giải mã không được thì game vẫn chơi tiếp, chỉ thiếu tiếng hoặc thiếu hình trang trí. Quảng cáo mở hoặc app ra nền thì dừng nhạc và lưu game.

**Xong khi:** mọi file trong hai bảng trên có trong `art/manifest.json`; icon nhìn rõ ở 48px trên máy thật cỡ 360×640; không có chữ lạ hay viền cắt xấu; hiệu ứng khớp lúc chạm; nhạc không có tiếng nảy khi lặp; tổng `assets/` tối đa 10 MB (trần đề xuất của mình, nâng từ 5 MB vì WAV và avatar). Tài nguyên cơ chế sau demo chưa cần cho demo.

## 9. Nhật ký quyết định

**2026-11-01**

- Chuyển sang Godot 4.7.2 Android gốc; iOS làm sau; bỏ bản web.
- Horus lo tài khoản store, ký và phát hành; quảng cáo, IAP tự tích hợp; analytics, Remote Config, cloud save, thông báo làm theo cách của Horus.
- Luồng hết MOVES: một popup +3 MOVES tối đa 4 lần, giá 1.900 / 2.200 / 2.500 / 2.800, có video; bỏ qua thì xác nhận mất 1 mạng (từ L10) rồi thua. Thay cho bản popup A + B cũ.
- Quà 28 ngày thay quà 7 ngày, có video nhận trước ô kế tiếp, popup chỉ mở khi bấm và hiện 7 ô.
- Bỏ nhiệm vụ ngày, quà quay lại và `comeback_x2`.
- Đổi concept hình khối sang pudding/gel bóng (ảnh duyệt `concept_candy_board_v1`), vẽ bằng code; bỏ tài nguyên `block_surface`.
- Thêm avatar và frame, 6 cơ chế từ L21, bảng mở khoá, thưởng Daily Challenge, tiêu chí thư giãn.
- Dùng AppLovin MAX, không có banner.

**2026-11-02**

- Đổi concept hình khối sang kẹo sọc (ảnh duyệt `concept_candy_board_v5_stripe`), đo số từ ảnh; bốn màu khối và cổng đổi theo ảnh. Giữ mũi tên mù màu dù ảnh không có.
- Đổi khung cổng từ bốn dải vát chéo sát bàn sang bốn thanh capsule và ống góc theo cùng ảnh; chấp nhận cỡ ô giảm khoảng 14% để giữ đúng tỉ lệ khung.
- Khối thoát thì vỡ thành mảnh kẹo ở mặt trong thanh, mảnh bay xuyên qua thanh và được đè lên vùng ngoài bàn; bị chặn thì nhún, văng vụn, dư chấn lan sang khối sau. Áp dụng cả với đá và cổng đóng. Giữ mức rung nhẹ.
