# Logic Candy Away khác game gốc ở đâu

So sánh Candy Away với "Tap Block Out: Color Puzzle" 2.2.1 (Funjo/FunSmith) theo 5 báo cáo REA (`REPORT_overview.md`, `REPORT_gameplay_features.md`, `REPORT_level_data.md`, `REPORT_economy_monetization.md`, `REPORT_backend_security.md`). Ngày đối chiếu: 2026-11-05.

- Phía Candy Away là code đang có trên nhánh `Theme_candy`, gồm cả thay đổi chưa commit ngày 2026-11-05, và 100 level trong `data/levels`.
- Số khối và dư MOVES đo trực tiếp trên file level, không lấy từ tài liệu.
- Phía game gốc lấy nguyên từ báo cáo, không kiểm lại.

Bảng này chỉ ghi chỗ khác, không phải danh sách việc phải làm. Muốn đổi điểm nào theo game gốc thì quyết trước, rồi sửa `design.md` và config trong cùng thay đổi.

## Phần giống nhau

- **Cách tính bị chặn:** khối trượt từng bước, xét mọi ô của khối, chỉ khối khác mới chặn.
- **Chạm khối bị chặn vẫn trừ 1 bước.**
- **Thắng được xét trước thua:** chạm cuối vừa hết bước vừa hết khối thì vẫn thắng.
- **Màu quyết định hướng:** vàng lên, xanh dương sang phải, tím xuống, xanh lá sang trái.
- **Khối 2 lớp:** bóc lớp ngoài thì khối ở lại và đổi hướng theo màu lớp trong.
- **Booster:** 3 loại cùng tác dụng (Gợi ý, +3 bước, phá 1 khối).
- **Mỗi lần chạm sai mất 10 coin/gold thưởng**, vì thưởng cộng 10 cho mỗi bước còn lại.
- **Road Trip:** cùng 400 nút, hộp ở cùng 16 mốc, cùng bảng thưởng hộp (tổng 12 Gợi ý, 10 Búa, 8 bước), có interstitial khi xong level.
- **Khác:** chỉ có một loại tiền, bảng xếp hạng toàn bot, tiền và vật phẩm lưu ở máy.

## 1. Luật trên bàn

| Mục | Game gốc | Candy Away |
|---|---|---|
| Chạm lệch | Vẫn nhận khối gần nhất: ô trống trong 0,3 ô, khối sai trong 0,2 ô | Chỉ nhận đúng ô ([board_view.gd:315](../src/ui/board_view.gd#L315)); ô nhỏ nhất khoảng 51 px |
| Gợi ý chọn khối nào | Ngẫu nhiên trong các khối thoát được | Luôn lấy khối thoát được đầu tiên theo thứ tự ([board_state.gd:151](../src/core/board_state.gd#L151)) |
| Nhắc Gợi ý khi đứng yên | 10 giây | 15 giây (`CONTENT.idle_hint_sec`) |
| Khối 2 lớp | Ở bộ Colorful, đường của lớp trong đã thông thì khối ra luôn trong 1 chạm | Luôn bóc lớp ngoài trước; khối 2 lớp mở ở L55 |
| Vật cản | Bom đếm ngược, chỉ ở level Special | Level chính không có bom đếm ngược (bom đếm ngược chỉ ở Màn đặc biệt; Bom kẹo L220 có ngòi cháy nhưng không đếm giờ và giúp người chơi). Có 6 vật cản game gốc không có: thùng sắt (L14), pudding (L30), xích (L45), sương mù (L85), cổng nhịp (L115), băng (L165; cùng luật pudding, không cùng level); mốc từ 2026-11-10 |
| Màu và cạnh bàn | Bộ MoreColor có 12 màu, mỗi cạnh nhiều đoạn màu | 4 màu, mỗi cạnh một cổng liền. Road Trip: mỗi cạnh 2 cổng (8 màu, L1–200) hoặc 3 cổng (12 màu, L201–400), khối mang màu cổng nó thoát qua |
| Lưới | 20×28, 28×36, 32×32 | Tối đa 14×18 (Road Trip cao tới 24); cỡ ô đổi theo hình của level |
| Khối | Khối đặc, chia 4 cánh kiểu chong chóng | Polyomino 1–7 ô (khoảng 3 ô mỗi khối); từ L5 xếp theo 27 hình vẽ tay, cắt theo kiểu đối xứng, hình học hoặc vùng vẽ |
| Khen khi chơi | Lời khen combo (Good … Unbelievable) | Không có combo; chỉ vỗ tay khi nghĩ ≥ 8 giây rồi đi đúng |
| Thẻ thắng L1–9 | Bỏ qua | Luôn hiện |

## 2. MOVES, thua, cứu, mạng

| Mục | Game gốc | Candy Away |
|---|---|---|
| Dư bước | Số bước − số khối: tutorial khoảng 7, Normal 3,45, Hard 3,94, SuperHard 5,03. **Level khó dư nhiều hơn** | Số chạm tối thiểu + dư cố định: L1–3 là 5, L4–13 là 3, từ L14 level thường là 4, HARD và VeryHard là 3. **Level khó dư ít hơn** (đo L51–100: thường 4,0, HARD 3,0) |
| Hết bước | Hồi sinh chỉ bằng video, cộng số khối còn lại, kẹp trong 5–10 bước. Hồi sinh 300 coin có trong code nhưng không dùng | Popup +3 Move, tối đa 4 lần: 1.900 / 2.200 / 2.500 / 2.800 gold, video, hoặc +3 Move trong kho |
| Mạng | Không có | 10 mạng, 5 phút hồi 1 mạng. Từ L10 thua mất 1 mạng. Nạp: 900 gold được 5 mạng, 1 video được 1 mạng |
| Chơi lại | Chỉ cảnh báo mất chuỗi thắng (giảm hệ số điểm Rank) | Từ L10 mất 1 mạng nếu đã chạm khối |

## 3. Gold và booster

Bảng tính "số level để đủ tiền" dùng thưởng một level chơi hoàn hảo, không x2: game gốc 43,1 coin, Candy Away 80 gold (40 + 10 × 4 bước dư, level thường từ L14).

| Mục | Game gốc | Candy Away |
|---|---|---|
| Lúc bắt đầu | 0 coin, 1 mỗi booster, không thấy mốc mở booster | 1.000 gold, 0 booster. Tặng 1 khi mở: Gợi ý L5, +3 Move L12, Phá khối L17 |
| Giá booster | Gợi ý 400, Búa 600, +bước 500 mỗi món, luôn bán theo cặp | Gợi ý 900, +3 Move 1.900, Phá khối 2.900, bán từng món |
| Số level để đủ tiền 1 món | Gợi ý 9,3 · +bước 11,6 · Búa 13,9 | Gợi ý 11 · +3 Move 24 · Phá khối 36 (đắt hơn 1,2 / 2 / 2,6 lần) |
| Video lấy booster | +1 món, báo cáo không thấy giới hạn | +1 món, 1 lần mỗi lượt chơi |
| Thưởng thắng | 5 coin + 10 coin mỗi bước còn lại | 40 gold + 10 gold mỗi MOVES còn lại |
| Nút x2 | Chỉ khi level > 50 và còn ≥ 3 bước | Từ L11 (L1–10 không có thẻ thắng, sang thẳng level kế); L11 miễn phí |
| Video đổi gold | Không có | Shop: 200 gold mỗi video, tối đa 5 video/ngày |
| Quà hằng ngày | Daily Win từ L100: thắng 7 ngày liên tiếp được 2 Gợi ý + 1 bước + 1 Búa | Lịch quà 28 ngày từ L14, lỡ ngày không mất chuỗi. Win Streak mới có giao diện, **chưa nối logic** |
| Avatar, frame | 30 avatar; frame nhận từ thưởng Challenge và Rank | 12 avatar + 12 frame, 1 video mỗi món, không bán gold |
| Biệt danh | 3–15 ký tự, 4.991 từ cấm | 3–14 ký tự, từ cấm 14 ngôn ngữ cộng tên dành riêng, đổi miễn phí. Tên chỉ hiện ở Profile |

## 4. Level và độ khó

| Mục | Game gốc | Candy Away |
|---|---|---|
| Số level | 6.000 level thường + 6 bộ biến thể; hết level thì hiện "Coming soon" | 500 level đóng gói (từ 2026-11-08, số khối, số lượt dọn bàn và tag bám L1–500 của game tham khảo); sau L500 lặp lại L51–500 |
| Màu theo level | 1 màu ở L1–2, đủ 4 màu từ L5 | 2 màu ở L1, đủ 4 màu từ L4 |
| Level 1 | 5 khối, cùng hướng lên, 10 bước | 4 khối, 2 màu, 9 MOVES |
| Số khối trung bình | L1–10: 5,9 · L11–20: 16,1 · L21–32: 23,1 · L33–50: 33,8 · L51–100: 44,9 | L1–10: 13,4 · L11–20: **38,2** · L21–32: **52,1** · L33–50: 54,7 · L51–100: 62,8 (tối đa 78) |
| Level khó | Hard đầu tiên L23, SuperHard L33. Sau L50: 54% thường, 45% khó | Hard đầu tiên L24, VeryHard L29. L51–100: 66% thường, 34% khó |

Ở L11–32 level của Candy Away có số khối gấp khoảng 2,3 lần game gốc.

## 5. Chế độ chơi

| Mục | Game gốc | Candy Away |
|---|---|---|
| Daily Challenge | Mở L51. Lịch tháng, chơi được mọi ngày đã qua. Bàn khoảng 103 khối, dư 6,8 bước. Đủ tháng được frame. Thua thì hồi sinh bằng video | Mở L50. Chỉ chơi bàn hôm nay, sinh theo level hiện tại. Thắng lần đầu trong ngày +100 gold. Thua mất mạng |
| Road Trip | Mở L61. Sự kiện có hạn chót (2026-10-29/30, giờ +08:00). Level MoreColor 12 màu. Thắng 0 coin cơ bản + 10 coin mỗi bước còn lại (trung bình 35,8) | Mở L95 (từ 2026-11-10; 2026-11-09 là L70, trước đó L2), không hạn chót. 400 level nhập từ bộ MoreColor của game gốc, chia lại cổng (8 hoặc 12 màu), đổi hướng một phần khối cho thêm 10% khối bị chặn lúc đầu. Thắng không có gold. Không tốn mạng. Hết bước: video +5 bước, tối đa 3 lần |
| Special (level có bom) | Mở L41. Mời 1 lần/ngày sau 1–3 lần thắng level Hard | Màn đặc biệt, mở L50 (từ 2026-11-09, trước là L41). Vé: ngăn chờ 2 giờ (không cộng dồn) và +1 vé mỗi lần thắng Hard / VeryHard, không giới hạn. 100 bàn tự sinh hình chữ nhật lát kín. 1 bom, thêm 1 sau mỗi 20 trận thắng, tối đa 6. Thắng được 1 booster ngẫu nhiên, x2 bằng video |
| Xếp hạng | Rank từ L70, chu kỳ 24 giờ. Điểm theo chuỗi thắng (x1 / x2 / x4), thưởng top 6 | Leaderboard từ L70 (từ 2026-11-10, trước là L8; icon ở cột trái Home, mở popup). 7 league theo điểm tuần, chỉ lên trong tuần; hết tuần (7 ngày từ lúc mở khoá) về 0 điểm và Silver. Điểm từ khối crystal, bot tăng điểm mỗi ngày |
| Thu thập Lego | Có | Không có |
| Chỉ Candy Away có | | Weekly Pass, Chain Offer, Special Pack, Rescue Pack, Level Pack, sale cuối tuần |

## 6. Quảng cáo

| Mục | Game gốc | Candy Away |
|---|---|---|
| Interstitial | Từ L22 (nhóm B: L35), cách nhau 90 giây (bản thử 110 / 180 giây). 9 chỗ hiện: đóng thẻ thắng, đóng popup thưởng, về Home, Challenge, Rank, Road Trip… | Chỉ khi rời thẻ thắng mà không lấy x2, hoặc đóng popup thắng Road Trip. Từ lượt 4, cách 2 lượt và 120 giây, không trong 90 giây đầu phiên, không trong 45 giây sau rewarded. Phiên đầu phải qua L10 |
| Banner | Từ L81, khi đang chơi | Không có |
| Popup bán bỏ quảng cáo | Sau interstitial đầu tiên trong ngày | Sau interstitial thứ 3 trong ngày; tối đa 1 lần/ngày, 3 lần tổng |

## 7. Mua hàng (IAP)

| Mục | Game gốc | Candy Away |
|---|---|---|
| Gói coin | 1.000 … 100.000; gói 4: 22.000 ($29,99); gói 5: 50.000 ($59,99) | 1.000 … 100.000; gói 4: 25.000 ($29,99); gói 5: 50.000 ($49,99); mỗi gói có bản sale |
| Bỏ quảng cáo | $9,99; bản kèm booster $12,99 (+3 Gợi ý, +3 bước) | $4,99 + 500 gold; không có bản kèm booster |
| Gói khởi đầu | $5,99: 3.000 coin + 3 Gợi ý + 3 bước | $6,99: 6.000 gold + 1 mỗi booster, mở 48 giờ |
| Khôi phục mua hàng | Gỡ quyền bỏ quảng cáo nếu Google Play không còn đơn | Chỉ cấp lại, không bao giờ gỡ ([game.gd:1143](../src/game/game.gd#L1143)) |

## 8. Hạ tầng

| Mục | Game gốc | Candy Away |
|---|---|---|
| Giờ | Giờ máy chủ cho Challenge, Road Trip, Rank (không kiểm chứng chỉ TLS) | Giờ máy; `design.md` đã chấp nhận rủi ro chỉnh đồng hồ |
| Lưu game | File trên máy, tắt sao lưu Android, không có cloud | File trên máy có phiên bản, cloud qua Play Games, thêm Auto Backup |
| Ngôn ngữ | 8 | 14 |
| Góp ý, đánh giá | Popup góp ý gửi về server; popup chấm 1–5 sao rồi mở trang Google Play | Email hỗ trợ; In-App Review ở L10 |

## Đã đổi trong ngày 2026-11-05

Các chỗ này trước đó khác game gốc nhiều hơn:

- **Gold mỗi MOVES dư: 1 → 10.** Chạm sai giờ mất 10 gold, bằng game gốc.
- **Dư MOVES cố định theo bậc**, thay cho `max(2, 10% số khối)` và HARD dư 1. Trước khi đổi, level thường ở L51–100 dư 6,5.
- **Popup đổi tên đã nối logic.**
- **Thêm Road Trip.**

## Còn khác mà `design.md` chưa có quyết định

1. **Không nhận chạm lệch:** người chơi phải chạm đúng ô, trong khi ô có thể chỉ khoảng 51 px.
2. **Khôi phục mua hàng không gỡ quyền bỏ quảng cáo** khi người mua đã được hoàn tiền.
3. **Win Streak** mới có giao diện, chưa có logic.
4. **Gợi ý chọn cố định**, không ngẫu nhiên.

## Có quyết định nhưng ngược hướng game gốc

- Level HARD dư 3, ít hơn level thường (4). Game gốc cho level khó dư nhiều hơn.
- Ở L11–32 số khối tăng nhanh hơn game gốc khoảng 2,3 lần.
- Tính theo số level phải thắng, booster đắt hơn 1,2–2,6 lần.
- Road Trip mở ở L95 (game gốc L61; 2026-11-09 là L70, trước đó L2) và thắng không có gold (game gốc khoảng 36 coin mỗi level).

## `design.md` còn tự mâu thuẫn

[design.md:315](../design.md#L315) ghi video `continue_moves` "chỉ lần 1 và 2". Mục 3 và `ECON.rescue_video_max = 4` thì cho video cả 4 lần.

## Lưu ý khi chỉnh theo game gốc

Nên chỉ lấy luật và con số. Road Trip đang dùng 400 level nhập từ bundle của game gốc (`data/road_trip`): hình, ô và số bước giữ nguyên, chỉ chia lại cổng và đổi hướng một phần khối (`design.md` mục 7 "Road Trip"). Dữ liệu level là nội dung có bản quyền của Funjo/FunSmith, nên có rủi ro bị gỡ khỏi store hoặc bị khiếu nại. Ngày 2026-11-09 người dùng chọn giữ bộ này khi phát hành, không thay bằng level tự sinh (`design.md` mục 9).
