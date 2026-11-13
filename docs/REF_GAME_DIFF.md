# Logic Candy Away khác game gốc ở đâu

So sánh Candy Away với "Tap Block Out: Color Puzzle" 2.2.1 (Funjo/FunSmith) theo 5 báo cáo REA (`REPORT_overview.md`, `REPORT_gameplay_features.md`, `REPORT_level_data.md`, `REPORT_economy_monetization.md`, `REPORT_backend_security.md`). Ngày đối chiếu: 2026-11-05.

- Phía Candy Away là code đang có trên nhánh `Theme_candy`, gồm cả thay đổi chưa commit ngày 2026-11-05, và 100 level trong `data/levels`.
- Số khối và dư MOVES đo trực tiếp trên file level, không lấy từ tài liệu.
- Phía game gốc lấy nguyên từ báo cáo, không kiểm lại, trừ mục 6 Quảng cáo: mục này kiểm lại trên code của game ngày 2026-11-13 (mục 6, "Logic quảng cáo game gốc"), và đã sửa vài chỗ báo cáo ghi sai.

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
| Khối | Khối đặc, chia 4 cánh kiểu chong chóng | Polyomino 1–7 ô (khoảng 3 ô mỗi khối); L5–13 xếp theo 27 hình vẽ tay, từ L14 theo 88 hình chia 8 chủ đề (mỗi chặng 10 level một chủ đề), cắt theo kiểu đối xứng, hình học hoặc vùng vẽ. Từ L14 màu xen nhau: cặp khối kề cùng màu 33% (game gốc 31%), khối thoát được ngay lúc đầu: L1–10 đúng như game gốc, từ L20 trung bình thường 7,2, Hard 8,2, VeryHard 7,1 (game gốc 8,4 / 9,4 / 10,3; 2026-11-12, trước đó 4,6 / 3,8 / 2,9) |
| Khen khi chơi | Lời khen combo (Good … Unbelievable) | Không có combo; chỉ vỗ tay khi nghĩ ≥ 8 giây rồi đi đúng |
| Thẻ thắng L1–9 | Bỏ qua | Luôn hiện |

## 2. MOVES, thua, cứu, mạng

| Mục | Game gốc | Candy Away |
|---|---|---|
| Dư bước | Số bước − số khối: tutorial khoảng 7, Normal 3,45, Hard 3,94, SuperHard 5,03. **Level khó dư nhiều hơn** | Số chạm tối thiểu + dư cố định (2026-11-12): L1–3 là 7, L4–10 là 5, L11–13 là 4; L14–150 thường 5, Hard 4, VeryHard 5; từ L151 thường 4, Hard 3, VeryHard 4. Đo L21–500: thường 4,3, Hard 3,3, VeryHard 4,3 (game gốc cùng chặng 4,5 / 4,7 / 5,8). Hard vẫn dư ít hơn level thường |
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
| Interstitial: mốc mở | Từ lúc rời thẻ thắng L35 (tải trước từ L30) | Như game gốc từ 2026-11-14 (L35), nhưng interstitial tải ngay khi SDK khởi tạo. Trước đó: phiên đầu phải qua L10, và không trước lượt 4 |
| Interstitial: nhịp | Chỉ có 90 giây giữa hai lần. Đồng hồ đếm từ lúc vào game, và xem xong rewarded cũng đếm lại từ đầu. Không giới hạn số lần mỗi ngày, không đếm lượt | Như game gốc từ 2026-11-14. Trước đó: cách ít nhất 2 lượt và 120 giây, không trong 90 giây đầu phiên, không trong 45 giây sau rewarded |
| Interstitial: chỗ hiện | 9 chỗ: rời thẻ thắng level thường (3 nhánh), nút Return của bảng Rank, thắng Challenge, nút Home ở popup thắng Road Trip, màn Special (nhận hộp khi thắng, popup bom nổ, popup thua). Thua level thường hay Challenge thì không có | Rời thẻ thắng level thường và Daily Challenge, nút Trang chủ của popup thắng Road Trip, Màn đặc biệt (rời thẻ thắng, popup thua bom nổ, popup thua hết bước; thêm hai popup thua 2026-11-14). Không có: bảng Rank (Leaderboard là popup ở Home), lấy x2 (thẻ tự đóng), thua level thường, Challenge, Road Trip |
| Banner | Từ L81, chỉ khi đang chơi (ẩn khi pause, thắng, thua), ở mọi chế độ kể cả Challenge, Special, Road Trip | Không có |
| Popup bán bỏ quảng cáo | Sau interstitial đầu tiên trong ngày (theo giờ máy), tối đa 1 lần/ngày, không giới hạn tổng. Lần đó game đưa người chơi về Home thay vì sang level kế, popup hiện ở Home | Sau interstitial thứ 3 trong ngày; tối đa 1 lần/ngày, 3 lần tổng |
| Rewarded | Không có mốc level, thời gian chờ hay giới hạn chung; mua bỏ quảng cáo không tắt rewarded. Chưa có video thì báo ngay "No videos". Thưởng ngay khi SDK báo người chơi đã nhận thưởng; đóng sớm thì không có thưởng | Giới hạn riêng từng chỗ (`design.md` mục 6). Chưa có video thì chờ tối đa `ADS.rv_wait_sec` giây rồi mới báo. Chỉ thưởng khi xem hết; app bị đóng giữa chừng thì trao lại lúc mở |

### Logic quảng cáo game gốc (kiểm lại trên code, 2026-11-13)

Nguồn: mã IL của `GameBlockGO.dll` và `GameLogic.dll` (bản hot-update HybridCLR, có đủ thân hàm, đọc bằng `dnfile`/`dncil`), cùng tầng Java trong APK 2.2.1. Đây là phân tích tĩnh, chưa chạy game. Tên hàm dưới đây là tên trong code của game gốc.

**Interstitial** (`BlockGOAdManager.CanRequestInterstitial`, `TryShowInterstitial`)

- Hiện khi đủ ba điều kiện: chưa mua bỏ quảng cáo, `CurrentLevel > 35`, đã qua 90 giây. `CurrentLevel` tăng ngay lúc thắng (`LevelManager.SettleCurrentLevelWin`), trước khi hiện thẻ thắng. Vì vậy lần đầu có thể hiện là lúc rời thẻ thắng L35.
- Code có hai thử nghiệm A/B, nhưng static constructor của `BlockGOABTest` ép cứng nhóm:
  - `int_opentime_20260929` luôn nhóm B: tải trước từ L30, mở từ L35. Nhóm A (L10 / L22) không bao giờ chạy. Giá trị mặc định `int_opentime_20260929 = 100` (nhóm A) trong `funsmith_config.json` không có tác dụng.
  - `ab20260910_ios_interad_interval` luôn nhóm A: 90 giây. Nhóm B (180 giây cho lần đầu trong 24 giờ) và nhóm 300 (110 giây) không bao giờ chạy.
- Đồng hồ 90 giây dùng `Time.realtimeSinceStartup`:
  - Bắt đầu khi vào game (`InitializeInterstitialCooldownOnGameEntry`, gọi từ `GameApp.StartGameLogicAsync` sau khi tải xong Home), nên quảng cáo đầu phiên cách lúc mở app ít nhất 90 giây.
  - Đếm lại khi interstitial đóng (`OnInterstitialSuccess`) và khi rewarded trao thưởng (`OnRewardedSuccess`).
  - Interstitial lỗi thì không đếm lại.
  - Tham số bỏ qua đồng hồ (`bypassCooldown`) chỉ panel cheat dùng.
- Lấy x2 bằng video thì đồng hồ vừa đếm lại, nên interstitial ngay sau đó bị chặn. Code không có luật riêng "đã x2 thì bỏ interstitial"; đây là hệ quả của đồng hồ. Người chơi ngồi ở thẻ thắng quá 90 giây sau khi xem video thì vẫn có interstitial.
- Hỏi SDK có quảng cáo chưa: chưa có thì bỏ qua ngay, không chờ. Chờ SDK trả lời tối đa 10 giây.
- 9 chỗ gọi (`BlockGOAdPlace`):

| Chỗ | Ad place | Ghi chú |
|---|---|---|
| Thẻ thắng level thường, bấm Claim: sang level kế, về Home, hoặc vào luồng Rank bắt buộc | 6 | Ba hàm `ContinueAfterLevelWinPanelClosed`, `ContinueHomeAfterLevelWinPanelClosed`, `ContinueMandatoryRankFlowAfterLevelWinPanelClosed` |
| Nút Return của bảng Rank | 6 | Về Home. Đây là chỗ duy nhất có cờ "app bị tắt giữa lúc quảng cáo thì lần mở sau vào Home" |
| Thắng Challenge | 7 | Về lịch Challenge |
| Màn Special: nhận hộp khi thắng, popup bom nổ, popup thua (nút X và Next) | 8 | Thua Special cũng có interstitial |
| Popup thắng Road Trip, nút Home | 9 | |

**Popup bán bỏ quảng cáo** (`OnInterstitialSuccess`, `GetInterstitialSuccessResult`)

- Interstitial thành công đầu tiên trong ngày, khi chưa mua bỏ quảng cáo: đặt cờ "hôm nay đã hiện" và cờ chờ popup, rồi trả kết quả 2 cho màn gọi. Các cờ lưu theo ngày `DateTime.Now`, tức ngày của máy.
- Kết quả 2 làm game gọi `ExitLevelToHomeAfterInterstitial` (về Home) thay vì sang level kế. Home hiện popup trong `UIHomePanel0910.TryShowDailyPopPanel`.
- Cờ chờ cũng theo ngày: qua ngày mà người chơi chưa về Home thì popup không hiện nữa.

**Banner** (`CanRequestBanner`, `LevelManager.RefreshBannerByLevelState`)

- Mỗi lần trạng thái level đổi: đang chơi thì hiện, trạng thái khác (pause, thắng, thua) thì ẩn.
- Điều kiện: `CurrentLevel >= 81`, chưa mua bỏ quảng cáo. Code không xét loại level.

**Rewarded** (`TryShowRewarded`)

- Không có mốc level, thời gian chờ hay giới hạn chung. Mua bỏ quảng cáo không tắt rewarded.
- Hỏi SDK có video chưa; chưa có thì báo `UI/Ads/NoVideos`.
- Màn Special: đồng hồ bom dừng trong lúc xem.
- 7 chỗ: mua booster bằng video (Gợi ý, +bước, Búa), hồi sinh level thường và Challenge, x2 khi thắng level thường và Challenge, x2 hộp Special.

**Tầng Java** (`com.xy.fusiontsjl.SDKHelper` → SDK FunSmith `com.hhhy.gamesdk` → AppLovin MAX)

- Không thêm điều kiện nào về thời gian, số lần hay level. SDK chỉ chặn khi:
  - cờ bỏ quảng cáo của SDK bật;
  - MAX chưa khởi tạo;
  - đang có quảng cáo trên màn;
  - app ở nền;
  - chưa biết nhóm của thử nghiệm chiến lược `ab20261010_ad_strategy` (thử nghiệm này chỉ chọn ad unit theo CPM).
- Cờ `AD_TYPE_SWAP` chỉ đổi cách đọc mã `ad_type` cho sự kiện analytics `ad_touch`. Nó không đổi loại quảng cáo hiện ra, và không có chuyện chưa có interstitial thì hiện rewarded thay.
- Cờ `AD_PRELOAD_BY_GAME`: SDK không tự tải interstitial và banner, chỉ tải khi game gọi (interstitial từ L30). Rewarded vẫn tự tải.
- Interstitial báo thành công lúc quảng cáo đóng. Rewarded báo thành công lúc người chơi nhận thưởng, khi quảng cáo còn trên màn; đóng sớm thì báo lỗi.

**Báo cáo REA ghi sai hoặc thiếu** (`REPORT_economy_monetization.md` mục 4)

- Mốc L22 và nhịp 110 / 180 giây nằm trong nhánh không bao giờ chạy. Báo cáo còn ghi ngược điều kiện 110 giây: ghi `!= 300`, code là `== 300`.
- Báo cáo không ghi ba điểm: rewarded cũng làm đồng hồ interstitial đếm lại, đồng hồ đếm từ lúc vào game, và thua màn Special có interstitial.
- Popup bán bỏ quảng cáo: báo cáo để là suy luận. Code xác nhận đúng, và cho thấy thêm việc game đưa người chơi về Home.

**Chưa kiểm được**

- Nhóm thực tế của `ab20261010_ad_strategy`: server quyết định lúc chạy. Thử nghiệm này không đổi nhịp quảng cáo.
- Trên Android, `Time.realtimeSinceStartup` có tính thời gian app ở nền hay không, tức để app ở nền 90 giây có làm hết thời gian chờ không.

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

- Level Hard dư ít hơn level thường 1 MOVES (VeryHard thì bằng). Game gốc cho level khó dư nhiều hơn.
- Ở L11–32 số khối tăng nhanh hơn game gốc khoảng 2,3 lần.
- Tính theo số level phải thắng, booster đắt hơn 1,2–2,6 lần.
- Road Trip mở ở L95 (game gốc L61; 2026-11-09 là L70, trước đó L2) và thắng không có gold (game gốc khoảng 36 coin mỗi level).

## `design.md` còn tự mâu thuẫn

[design.md:315](../design.md#L315) ghi video `continue_moves` "chỉ lần 1 và 2". Mục 3 và `ECON.rescue_video_max = 4` thì cho video cả 4 lần.

## Lưu ý khi chỉnh theo game gốc

Nên chỉ lấy luật và con số. Road Trip đang dùng 400 level nhập từ bundle của game gốc (`data/road_trip`): hình, ô và số bước giữ nguyên, chỉ chia lại cổng và đổi hướng một phần khối (`design.md` mục 7 "Road Trip"). Dữ liệu level là nội dung có bản quyền của Funjo/FunSmith, nên có rủi ro bị gỡ khỏi store hoặc bị khiếu nại. Ngày 2026-11-09 người dùng chọn giữ bộ này khi phát hành, không thay bằng level tự sinh (`design.md` mục 9).
