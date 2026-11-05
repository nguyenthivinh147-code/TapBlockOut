# Candy Away: thiết kế (design.md)

Trạng thái: **thiết kế chốt ngày 2026-11-01**, thay bản 2026-10-31.
Nguồn: trao đổi với người dùng ngày 2026-11-01, `tap-block-out-color-puzzle-guideline.vi.md`, `GAME-GUIDE.md`, `AGENTS.md`, `README.md` của Horus, trang Google Play đọc ngày 2026-10-31.

Game làm bằng **Godot 4.7.2, GDScript, xuất Android gốc**. Tài liệu Horus nói về game web chỉ còn là tài liệu tham khảo, xem mục 8.

## 1. Năm dòng

| Câu hỏi của bước 0 | Trả lời |
| --- | --- |
| Vòng chơi một lượt | Nhìn bàn cờ, tìm khối không bị chặn, chạm để khối tự trượt ra cạnh cùng màu, lặp lại tới khi sạch bàn (10 giây đến 2 phút). |
| Cái gì quyết định thắng hay thua | Đọc đúng khối nào đang thoát được. Chạm khối bị chặn tốn 1 MOVES; hết MOVES mà còn khối thì vào luồng cứu (mục 3). Trong level không có timer. Từ L10, thua mất 1 mạng. |
| Tiền nhận theo gì | Gold theo level thắng: +40 ở mọi độ khó, cộng 10 gold cho mỗi MOVES còn thừa; x2 bằng rewarded. Thêm quà 28 ngày và video trong shop. |
| Nâng cấp gì | Không có nâng cấp vĩnh viễn. Gold mua 3 booster dùng một lần (Gợi ý, +3 Move, Phá 1 khối), chơi tiếp, refill tim, avatar và frame. |
| Level sau khác gì | Thêm màu (2 → 4 trong 4 level đầu), nhiều khối hơn, chuỗi chặn sâu hơn, dư MOVES ít hơn so với số chạm cần, có level HARD xen kẽ theo đường cong độ khó. Từ L14 thêm 6 cơ chế (mục 4). |

## 2. Thông số đã có

- Tên game: **Candy Away**, dòng phụ "Tap Block Puzzle" (cả hai nằm trong logo `assets/ui/loading_logo.png`; chuỗi `APP_NAME`). Tên dự án, thư mục, package id `com.tungcv2.tapblockout` và plugin `tbo_platform` giữ tên cũ Tap Block Out vì đã gắn với cấu hình Horus.
- Mở game: màn loading (`splash`) với nền kẹo `assets/ui/loading_bg.png`, logo, thanh tải và số phiên bản, rồi vào Home. Thanh chạy tới 90% trong ít nhất 1,5 giây, đứng đó nếu khởi động chưa xong, rồi đầy trong 0,3 giây (`Config.CONTENT.splash_*`). Boot splash của Godot (lúc engine nạp) dùng cùng ảnh, chưa có thanh tải.
- Vào màn chơi (Home bấm Chơi, bấm Chơi ở màn Daily Challenge, nạp mạng xong ở màn hết mạng): màn chuyển cảnh `level_curtain` gồm hai cánh kẹo bóng. Cánh tím trượt từ phải vào nửa phải; khi nó gần tới nơi (60% thời gian trượt) cánh hồng trượt từ trái vào nửa trái, đè lên mép cánh tím. Cánh lao nhanh từ mép màn rồi giảm tốc dần khi tới giữa. Logo nhảy lên giữa màn, từ mờ nhoè và trong suốt tới rõ nét. Màn chơi dựng bên dưới, logo giữ một lúc rồi mờ đi, hai cánh trượt ra hai bên. Mỗi cánh trượt vào 0,45 giây, logo bật 0,4 giây, giữ 0,35 giây (`Config.CONTENT.curtain_*`). Màu theo ảnh mẫu: hồng `#fbd3df` → `#f6a9cf`, tím `#e0c1f0` → `#c9abf1`. Chạm và nút Back bị chặn suốt lúc chạy. Qua level kế trong màn chơi không có màn này.
- Chạm màn hình (2026-11-05, làm nhẹ lại cùng ngày): mỗi lần chạm, ở bất kỳ màn hay popup nào (cả lúc màn chuyển cảnh chạy), một vòng tròn trắng ánh hồng dày 4 px, đậm nhất (55%) ở giữa nét và mờ dần về trong suốt ở viền trong lẫn viền ngoài, nở ra tới bán kính 25 px rồi mờ dần, và 5 sao nhỏ 5 cánh màu pastel (vàng, hồng, tím; cỡ 4 → 2 px, đậm 40%) toả ra chừng 40 px, vừa bay vừa xoay và nhỏ dần; tất cả tắt sau 0,4 giây (`Config.CONTENT.tap_fx_*`, px ở màn chuẩn 886×1920, `src/ui/tap_fx.gd`). Hiệu ứng chỉ để nhìn: không chặn chạm, chạm vẫn tác dụng như thường; chạm dồn dập giữ tối đa 8 hiệu ứng cùng lúc.
- Mục tiêu: game **thư giãn ASMR**, doanh thu **50% IAA, 50% IAP**. Đo theo cohort 30 ngày đầu: doanh thu quảng cáo so với IAP sau phí store. Chưa có số liệu thật nên tỉ lệ này chỉ kiểm chứng được từ soft launch; mọi tần suất, giới hạn video và giá nằm trong config, chỉnh được bằng Remote Config.
- Hướng màn hình: **portrait**
- Nền tảng: **chỉ Android** ở bản hiện tại, iOS phát triển sau. Không có bản web.
- Offline, một người chơi. 14 ngôn ngữ (thứ tự như popup Language): `en`, `vi`, `pt_BR`, `tr`, `de`, `fr`, `id`, `es`, `ru`, `ko`, `ja`, `hi`, `uk`, `it`. Lần đầu theo ngôn ngữ của máy (cùng ngôn ngữ khác vùng vẫn khớp, ví dụ `pt_PT` ra `pt_BR`; không có thì `en`); chọn trong popup Language thì lưu cố định, popup không có ô "theo thiết bị". Tên ngôn ngữ trong popup viết bằng chính ngôn ngữ đó. Bản dịch 12 ngôn ngữ mới do Claude dịch, cần người bản xứ duyệt trước khi phát hành (kế hoạch mục 4).
- **Bản demo:** 20 level để duyệt game. **Bản phát hành đầu tiên:** L1–100.
- Game tham khảo: Tap Block Out: Color Puzzle (funsmith). Hôm nay trên Play: 4.7★, 4.11K đánh giá, 100K+ tải, cập nhật 26/10/2026, có sự kiện viền Halloween.
- Đánh giá của người chơi: thích chỉ chạm không cần kéo; chê quảng cáo sau mỗi level và quảng cáo ngay lúc mở game. Game của ta tránh cả hai.

## 3. Luật chơi

- **Khung bàn cố định theo màn, giữ tỉ lệ so với màn như ảnh ref `art/concepts/ref_board_scale.png`, màn chuẩn 886×1920** (`Config.BOARD_SCREEN`). Ở màn chuẩn, vùng trong khung là 724×982 px (`BOARD_AREA`) và trọn khung khoảng 803×1044 px, tức khoảng 90% bề ngang màn. Màn khác thì khung nhân theo min(rộng, cao) so với màn chuẩn, nên màn to thì bàn to theo. Đây là luật nền của game, mọi level và mọi theme phải giữ.
- Lưới level tối đa 14×18 ô (`Config.BOARD_W`, `BOARD_H`). **Cỡ khối đổi theo level**: lấy hình của level (khối và thùng sắt) cộng một ô lề mỗi phía, tối đa 14×18 ô, rồi chọn cỡ ô lớn nhất để hình đó vừa vùng trong khung. Ô to nhất 80 px ở màn chuẩn (`BOARD_CELL_MAX`), bằng cỡ khối trong ảnh ref. Hình càng nhiều khối thì càng lớn và ô càng nhỏ; hình cao 17 ô hoặc rộng 12 ô ra ô nhỏ nhất, 51 px. Cỡ ô là số nguyên px, giữ nguyên suốt level, kể cả khi khối rời bàn.
- Khung đứng cùng một chỗ và cùng một cỡ ở mọi level. Khung chỉ co khi vùng chơi của máy nhỏ hơn khung chuẩn. Hình nằm giữa vùng trong khung; khối thoát lao tới mặt trong của thanh cùng màu.
- Khối xếp thành một hình ở giữa bàn, không lát kín bàn và không cần kín khung của hình: khoảng trống quanh hình và trong hình là bình thường (mục 4). Khối là polyomino bất kỳ: các ô liền nhau theo 4 hướng, không giới hạn số ô hay hình dạng (mục 4, "Hình dạng level").
- Màu quyết định hướng: vàng lên, xanh lá trái, xanh dương phải, tím xuống. Mỗi cạnh khung là một cổng liền, không có cổng rời.
- Chạm khối, đường thông: khối lao nhanh dần tới thanh cùng màu (tối đa 0,42 s), vỡ thành mảnh kẹo bay xuyên qua thanh, MOVES giảm 1.
- Chạm khối, đường bị chặn: khối lao tới vật cản, nhún khi va chạm rồi bật về chỗ cũ, khối bị va nhún theo, MOVES giảm 1. Bàn cờ không đổi nên không có thế bí.
- `MOVES = số chạm tối thiểu do solver tính + dư`. Dư cố định theo bậc, không theo số khối: L1–3 là 5; L4–13 là 3; từ L14 level thường là 4; level HARD và VeryHard là 3 (`Config.CONTENT.slack_*`). Level HARD khó nhờ bàn (thêm khối, chuỗi chặn sâu hơn), không nhờ dư ít. Game cộng dư lúc vào level từ `min_taps` trong file, nên Remote Config đổi được dư mà không phải sinh lại level; `moves` trong file là giá trị theo số mặc định.
- Nghĩ quá lâu rồi đi đúng (mặc định từ 8 giây): hiệu ứng vỗ tay.
- Mỗi level có ít nhất một khối thoát được ngay. Solver kiểm 100% level trong unit test và lúc build.
- Khối không có mũi tên chỉ hướng: hướng đi đọc theo màu khối và thanh cổng cùng màu.

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

Độ khó 100 level đầu bám file `difficulty_curve_levels_1-100.json` của PixelFlow (điểm 0–10, trung bình trượt 5 level), nạp vào `src/core/difficulty_curve.gd`. Bộ sinh đổi điểm thành số khối: chuẩn hoá min-max trên 100 level rồi nội suy 2–30 khối; level Hard +2 khối, VeryHard +3 khối, dư MOVES 3 (mục 3). Danh sách Hard: 24, 28, 33, 38, 44, 53, 59, 63, 68, 73, 79, 89, 93, 98. VeryHard: 29, 36, 45, 49, 54, 64, 69, 75, 82, 84, 95, 99 (huy hiệu và hộp thoại "rất khó" cho các level này và mọi level HARD từ L100). Cơ chế dày dần theo level kể từ level mở khoá. Bàn có cổng nhịp (L90+) tối đa 52 khối (từ L130, khi bàn có tới 2 cổng, tối đa 40) vì bộ sinh phải tìm được trạng thái cổng ban đầu không bắt chạm chờ, nên L91–100 thấp hơn đường cong.

**Từ L14 khó hơn (2026-11-03):** số khối trên nhân 1,3 (trần 40 khối), và lúc gán hướng bộ sinh ưu tiên mạnh hơn những khối bị chặn lúc đầu (số mũ trọng số 2, level Hard/VeryHard 3; trước L14 là 1 và 2), nên chuỗi chặn sâu hơn. Công thức dư MOVES giữ nguyên. Đo trên L14–100 so với bản trước: trung bình 21,4 → 29 khối, khối thoát được ngay lúc đầu 38% → 22% số khối, số lượt cần để dọn bàn (mỗi lượt cho mọi khối đang thông đường đi) 6,5 → 10. Số trong `src/core/difficulty_curve.gd` (`SHAPED_FROM`, `BOOST`, `BOOST_MAX`, `BLOCKED_POWER*`).

**Gấp đôi số khối mọi level (2026-11-03):** số khối tính như trên rồi nhân 2 (`DifficultyCurve.COUNT_SCALE`), nên đường cong là 4–60 khối trước L14 và tối đa 80 khối từ L14. Bàn và cỡ ô giữ nguyên. Hình vẽ tay lớn nhất chỉ khoảng 110 ô nên từ L14 hình giữ cỡ như cũ và khối nhỏ lại (khoảng ô/khối giảm một nửa, mục "Hình dạng level"); L5–13 giữ tỉ lệ ô/khối nên hình to gấp đôi. L1–4 làm tay lại với 4, 6, 8, 10 khối. Đo trên L14–100 so với bản trước: trung bình 29 → 57,9 khối; khối 1 ô 16% → 68%, 2 ô 26% → 24%, từ 3 ô trở lên 58% → 9%. Công thức dư MOVES giữ nguyên nên MOVES cũng tăng theo số khối.

Bốn level đầu làm tay trong `tools/gen_levels.gd` (bảng EARLY). L1–3 chắc chắn thắng: dư 5 MOVES, L1–2 không khối nào bị chặn, L3 chỉ một khối phải chờ; L4 cũng chỉ một khối phải chờ.

Mọi level thắng đều +40 gold, cộng thêm 10 gold cho mỗi MOVES còn thừa lúc thắng (mục 5).

| Level | Màu | Khối | Ghi chú |
| --- | --- | --- | --- |
| 1 | 2 màu (vàng, xanh dương) | 4 | Chữ "Tap the block" |
| 2 | 3 màu | 6 | Không khối bị chặn |
| 3 | 3 màu | 8 | Một khối phải chờ |
| 4 | Đủ 4 màu | 10 | Một khối phải chờ |
| 5–13 | 4 màu | 12–22 | Gợi ý mở ở L5, Rate us ở L10, +3 Move mở ở L12 |
| 14 | 4 màu | 34 | Level dạy Thùng sắt; từ đây khối xếp thành hình vẽ tay |
| 15–29 | 4 màu | 40–62 | Phá khối mở ở L17; L24 là level HARD đầu tiên |

### Hình dạng level

Lưới luôn 14×18 ô và khung không đổi (mục 3). Số khối quyết định hình to hay nhỏ, từ đó quyết định cỡ ô trên màn. Hình lớn nhất của bộ sinh là 12×17 ô. Vì ngoài hình là ô trống, dịch cả hình đi không đổi đường thoát của khối.

| Nguồn | Hình |
| --- | --- |
| Từ L14 và Daily Challenge (`src/core/motifs.gd`) | 21 hình vẽ tay, mỗi hình 2–3 cỡ. Hình cơ bản: mũi tên (lên, xuống, trái, phải), tim, ngôi sao, chữ thập, chữ X, thoi rỗng, đồng hồ cát. Theme kẹo: kẹo bọc giấy, kẹo mút, cupcake, kem ốc quế, donut. Hình khác: hoa, cỏ bốn lá, bướm, cây thông, nhà, vương miện, nấm, tên lửa |
| L5–13 | Bộ sinh với 9 dạng trong `src/core/silhouette.gd` (oval, thoi, tim, chữ thập, đồng hồ cát, vòm, vòng, mũi tên, nhà), khoét rìa ngẫu nhiên; dưới 6 khối thì xếp hình chữ nhật. Giữ nguyên, không sinh lại |
| L1–4 | Làm tay (bảng EARLY), dịch vào giữa bàn |
| Level dạy cơ chế (14, 30, 40, 55, 70, 90) | Sinh to như level thường theo hình vẽ tay, chỉ bật đúng cơ chế mới. Bộ sinh chỉ nhận level cho chạm thử cơ chế ngay lúc đầu: Thùng sắt có ít nhất 2 ô; Pudding có khối làm vỡ được; Xích có khối bị xích mà chìa thoát được ngay; Hộp giấy có hộp đẩy ra được; Sương mù có khối ẩn màu; Cổng nhịp đóng lúc đầu và có khối đang chờ cổng |

- Hình vẽ tay (từ L14): mỗi bản vẽ rộng chẵn để nằm đúng giữa bàn 14 cột, tối đa 12×17, đối xứng trái phải hoặc trên dưới (chữ thập, chữ X, thoi, đồng hồ cát, kẹo bọc, donut, hoa, cỏ bốn lá đối xứng cả bốn góc). Không khoét rìa. Chọn cỡ có số ô (trừ thùng sắt) chia số khối trong 1,15–1,8 (`Config.MOTIF_FILL_MIN`, `MOTIF_FILL_MAX`; trước khi gấp đôi số khối là 2,3–3,6). Level liền nhau đi cách nhau 8 bước trong danh sách hình nên ra hình khác nhóm.
- Cắt khối (mọi level sinh): bộ sinh gộp dần các ô đơn thành khối, không giới hạn cỡ hay hình khối (trước 2026-11-05 tối đa 5 ô). Mỗi cách gộp có trọng số nghịch đảo cỡ khối sau gộp, nên khối to vẫn ra nhưng hiếm. Số khối theo đường cong nên từ L14 hình vẽ tay vẫn chỉ khoảng 1,15–1,8 ô mỗi khối, phần lớn khối 1–2 ô. Đo trên L1–100 đóng gói: L5–13 khối 1 ô 40%, 2 ô 20%, 3–5 ô 27%, từ 6 ô 12%, lớn nhất 17 ô; L14–100 khối 1 ô 71%, 2 ô 21%, 3–5 ô 8%, từ 6 ô 0,5%, lớn nhất 10 ô.
- Cắt khối từ L14: thùng sắt và cách cắt khối đối xứng theo trục của hình (lát nửa hình hoặc một phần tư rồi lật ra; khối chạm trục có thể vắt qua trục thành một khối đối xứng). Màu (hướng) vẫn gán tự do theo ván mô phỏng, nên màu không đối xứng. Số khối có thể lệch tối đa 2 so với đường cong vì mỗi lần gộp đối xứng bớt 1, 2 hoặc 4 khối.
- Cỡ hình L5–13: số ô khoảng 2,4–3,4 lần số khối, khung hình tối đa 12×17 (chừa một ô mỗi phía), cao tối đa khoảng 1,9 lần rộng, khoét thêm khoảng 6% ô rìa để hình không quá đều. Hình lớn nhất trong ảnh ref là 10×17.
- Sương mù: chỉ khối kề rời đi (thoát hoặc bị phá) mới làm lộ, ô trống sẵn quanh hình không tính. Nhờ vậy mọi khối sương mù đều ẩn lúc đầu, kể cả ở rìa hình.

### Cơ chế sau bản demo

Nguyên tắc: cơ chế chỉ làm bàn cờ dễ hơn theo thời gian hoặc lặp lại theo chu kỳ, không có nước đi nào khiến level không thể thắng. Không timer. Solver phải chứng minh được từng level. Vì vậy không dùng đổi màu ngẫu nhiên hay khối mọc thêm.

Mỗi cơ chế có một level dạy (chỉ cơ chế đó, xem "Hình dạng level") và một âm thanh riêng. Sau L90 chỉ phối hợp các cơ chế đã có. Mốc level theo `Config.UNLOCK` (bảng "Mở khoá theo level").

Theme kẹo (2026-11-03) đổi hình ba vật cản, luật giữ nguyên; ngày 2026-11-04 khối gỗ đổi tiếp thành thùng sắt. Tên trong dữ liệu và code vẫn là `stone`, `ice`, `chained_by`, `inner_color`.

| Từ level | Cơ chế | Luật | Hình | Âm thanh |
| --- | --- | --- | --- | --- |
| 14 | Thùng sắt (`stone`) | Vật cản cố định, không trượt | Thùng sắt nhìn từ trên: nắp thép xanh xám, viền nổi, bốn đinh tán bạc to ở bốn góc nắp, đọc rõ ở ô 42 px (`mech_stone`) | Tiếng keng thùng sắt rỗng, ngắn 0,5 giây |
| 30 | Pudding (`ice`) | Cần 2 lần chạm, lần đầu làm vỡ lớp pudding; chạm này tốn MOVES và đã tính vào `MOVES` | Lớp pudding hồng gần trong suốt phủ trọn khối kẹo, tràn ra ngoài mép 0,1 ô, viền đậm hơn, bọt khí nhỏ, vệt sáng quét chéo mỗi 3,2 giây | Băng nứt |
| 40 | Xích và chìa | Khối bị xích chỉ đi được khi khối chìa đã thoát | Xích thép bắt chéo chữ X qua trọn khung khối (khối hình L, T thêm chữ X cho ô nằm xa), ổ khoá vàng ở giữa | Xích rơi |
| 55 | Hộp giấy (`inner_color`) | Lớp ngoài thoát thì lộ lớp trong, màu khác | Hộp giấy nhuộm màu hướng đi của lớp ngoài, băng dán chữ thập qua tâm hộp; kẹo bên trong bị che kín | Bóc lớp |
| 70 | Sương mù | Không thấy màu cho tới khi một khối kề rời đi | | Gió nhẹ |
| 90 | Cổng nhịp | Cổng đóng/mở luân phiên sau mọi lần chạm, kể cả chạm bị chặn | | Cổng cơ khí |

Booster với cơ chế:

- Phá khối: không dùng được trên thùng sắt; dùng trên pudding, xích hoặc hộp giấy thì xoá hẳn cả khối. Booster là búa kẹo mút (2026-11-03): chọn khối xong thì kho và bàn cập nhật ngay, búa bật ra giữa màn trên nền tia sáng xoay, lấp lánh một nhịp, thu nhỏ bay vồng tới khối và nhấc lên, rồi vung xuống cho mặt kẹo gõ đúng một ô của khối (khoảng 0,7 giây từ lúc chọn tới lúc gõ, `src/ui/smash_fx.gd`). Lúc gõ: loé trắng toàn màn, tia toả, hai vòng sóng hồng vàng, sao nổ, vòng 5 sao vàng xoay như bị choáng váng; khối vỡ tung thành mảnh kẹo đúng chất liệu (mỗi ô 8 mảnh tam giác, bắn toả khỏi chỗ gõ, hất lên rồi rơi) và bàn rung mạnh hơn va chạm thường. Búa bay thì bàn và các nút không nhận chạm; mảnh leaderboard (nếu có) bay về chip lúc búa gõ.
- Gợi ý: chỉ khối đi được ngay, có tính cổng nhịp. Bấm thì một ngôi sao bay theo đường cong nhẹ từ nút Gợi ý tới khối (khoảng 0,8 giây), kéo đuôi mảnh màu cam hồng và bụi sao; chạm thì loé sáng, toả tia, khối nảy rồi nhấp nháy. Sao còn bay thì bấm Gợi ý không làm gì. Người chơi đi nước khác trong lúc sao bay thì khi chạm nháy gợi ý mới, booster không mất.
- Nhắc Gợi ý (2026-11-04): Gợi ý đã mở, đang chơi mà không chạm màn hình 15 giây (`CONTENT.idle_hint_sec`) thì khung nút Gợi ý lắc, bóng đèn trắng đổi sang ảnh `booster_hint` (bóng đèn vàng), rồi bong bóng kem viền cam "Available Block : N" (N là số khối thoát được ngay, cùng luật với Gợi ý) bật ra trên nút, đuôi chỉ xuống nút. Bong bóng tự tắt sau 2 giây (`CONTENT.idle_hint_show_sec`); chạm bất kỳ đâu thì tắt ngay và chạm đó vẫn có tác dụng như thường. Tắt xong bóng đèn về như cũ, treo tiếp đủ 15 giây thì nhắc lại. Không đếm khi chưa mở Gợi ý, đang chọn khối để Phá, sao Gợi ý đang bay hay có popup; lúc đủ giờ mà không khối nào thoát được thì bỏ lượt nhắc đó. Vẫn nhắc khi hết Gợi ý trong kho (chạm nút thì mở hộp mua).
- Sương mù: chạm khối chưa lộ vẫn tốn 1 MOVES nếu bị chặn.

### Mở khoá theo level

| Level | Mở |
| --- | --- |
| Từ đầu | Popup hết MOVES, avatar, frame |
| 2 | Road Trip (tab phải của thanh dưới, mục 7 "Road Trip") |
| Sau khi thắng L3 | Quà 28 ngày |
| 5 / 12 / 17 | Gợi ý / +3 Move / Phá khối |
| 5 | Shop và video gold |
| 8 | Leaderboard (icon Bảng xếp hạng ở cột trái Home, khối crystal trong level) |
| 10 | Mạng, Starter Pack |
| Sau L10 | Interstitial trong phiên đầu |
| 10 | Hỏi đánh giá store (Rate us) |
| 14 / 30 / 40 / 55 / 70 / 90 | 6 cơ chế |
| 50 | Daily Challenge |

Hàng booster trong level luôn có đủ 3 ô. Ô chưa mở tô tối, có ổ khoá ở góc, không có nhãn số, chữ dưới ô ghi level mở ("Level 12"); chạm vào chỉ báo "Mở khoá ở Level N", không mở hộp mua. Booster chưa mở mà nhận từ lịch quà thì vẫn vào kho, tới level mở thì ô mới dùng được. Popup hết MOVES vẫn bán hoặc dùng +3 Move trước L12, vì món này áp dụng ngay. Quà hướng dẫn ở L5/L12/L17 vẫn tặng.

Dùng +3 Move từ hàng booster: lượt cộng vào bàn ngay, nhưng chip lượt trên thanh trên tăng dần. Mỗi lượt là một dấu "+" bay từ nút tới chip, chạm chip thì số tăng 1; dấu cuối kèm loé sáng và chữ "+3" (cả quá trình khoảng 1 giây, chạm khối trong lúc bay vẫn được). +3 Move từ popup hết MOVES cộng thẳng, không có hiệu ứng này.

### Thẻ thắng và thẻ thua

Hai thẻ là popup chồng lên màn level (bàn cờ khoá input), không đổi scene. Mỗi lượt chỉ kết thúc một lần: `attempt.ended` chặn cộng gold hai lần. Thẻ đọc `attempt.level`, không đọc `s.level` (đã tăng sau khi thắng).

- **Thắng:** sau khi khối cuối rời bàn chờ `win_delay_sec` (0,8 giây) rồi hiện thẻ. Thẻ có tổng gold (+40 và gold MOVES thừa), nút x2 (L1 miễn phí, sau đó rewarded; thất bại hiện thông báo và thử lại được), nút Tiếp tục.
- **Gold MOVES thừa bay vào thẻ (2026-11-04):** còn MOVES thì ô gold hiện +40 trước; thẻ hiện được 0,45 giây thì đồng gold nở ra ở chip MOVES trên thanh trên, vừa lật vừa bay vồng (kéo vệt vàng, bụi sao) vào icon gold của thẻ (`src/ui/coin_fx.gd`). Mỗi lượt một đồng, tối đa 10 đồng (nhiều lượt thì mỗi đồng mang nhiều lượt). Đồng rời chip thì số MOVES giảm và chip nảy; đồng chạm icon thì loé sáng, nổ sao, icon và số nảy, tiếng xu, số gold trên ô và trên nút x2 tăng phần của đồng đó; đồng cuối kèm loé lớn và hai vòng sóng. Hết thì MOVES về 0 và ô gold hiện đủ tổng. Bấm x2 hay Tiếp tục lúc đang bay thì cộng nốt ngay. Gold vào ví ngay lúc thắng, hiệu ứng chỉ để xem. Daily Challenge thắng lại trong ngày (0 gold) không bay.
- **Thanh tiến trình tính năng:** chạy từ mốc mở gần nhất tới mốc kế trong bảng "Mở khoá theo level" (bỏ Starter, Rate us). Đạt 100% thì đổi dòng thành "Đã mở khoá …". Ẩn khi hết tính năng; bản demo chỉ tính mốc tới L20. Daily Challenge không có thanh.
- **Leaderboard trên thẻ thắng:** level có khối crystal thì thẻ có thêm thẻ người chơi: tổng điểm đếm dần và hạng cũ đếm tới hạng mới. Dải phần thưởng chỉ có gold, không có ô "+N điểm xếp hạng" và icon của nó (2026-11-05); vừa lên league thì hiện tên league mới, và sau khi bấm Tiếp tục hiện popup Lên giải (nhận thưởng) trước interstitial.
- **Sau Tiếp tục:** rời thẻ (interstitial `result_exit`, offer, xin quyền thông báo, hỏi đánh giá), rồi: vừa mở tính năng ở Home (quà ngày, shop, Leaderboard, Daily Challenge, mạng) hoặc vừa thắng Daily Challenge thì về Home; còn lại vào thẳng level kế. Hết mạng thì sang màn hết mạng; hết level demo thì báo rồi về Home.
- **Thua:** thẻ có chơi lại, về Home, `rescue_pack` nếu có. Không interstitial khi thua. Chơi lại từ L10 mà hết mạng thì sang màn hết mạng.
- **Analytics:** `level_end` kèm `won`, `taps`, `moves_left`, `blocks_left`, `rescues`, `ms`, `replay`.

### Phạm vi

- **Demo:** L1–20, có đủ popup hết MOVES, quà 28 ngày, avatar và frame; có Thùng sắt từ L14. Sau L20 hiện "Sắp có level mới". Icon Daily Challenge ở Home hiện khoá (icon tối, có ổ khoá), ribbon ghi "Level 50". Quảng cáo và mua hàng dùng bản giả lập cho tới khi có cấu hình từ Horus.
- **Bản phát hành đầu tiên:** L1–100 sinh trước bằng công cụ theo đường cong độ khó, solver kiểm và đóng gói sẵn; L1–4 làm tay.
- **Sau L100 (vòng lặp):** số level hiển thị tăng mãi (L101, L102…), nội dung quay lại từ level `content_loop_start_level` (mặc định 51) đến L100 rồi lặp tiếp. Cấu hình được qua Remote Config. Bản lưu chỉ giữ số hiển thị nên người chơi nâng cấp từ bản cũ (kể cả đã qua L300) tự nhận nội dung theo vòng lặp, không cần migrate. Daily Challenge vẫn sinh bàn trong game.
- **Daily Challenge (L50):** dùng cùng bộ sinh. +100 gold và gold MOVES thừa cho lần thắng đầu tiên mỗi ngày (thắng lại trong ngày là 0), x2 bằng video như level thường, không có chuỗi ngày và bảng xếp hạng. Thua vẫn mất mạng như level thường.

## 5. Kinh tế (số của người dùng, cập nhật ngày 2026-11-01)

Một loại tiền là **Gold**, không có gem. Trong code biến vẫn tên `coins`; người chơi và analytics thấy "gold".

| Mục | Số | Nguồn |
| --- | --- | --- |
| Gold bắt đầu | 1.000 | Người dùng |
| Thắng một level, mọi độ khó | +40 | Người dùng |
| MOVES còn thừa lúc thắng | +10 gold mỗi MOVES, cộng vào thưởng thắng nên x2 nhân đôi cả phần này (`ECON.win_move_coins`) | Người dùng (2026-11-04; 1 → 10 ngày 2026-11-05) |
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

### Biệt danh

- Đổi ở Profile: nút bút chì cạnh ô tên mở popup đổi tên. Miễn phí, đổi bao nhiêu lần cũng được.
- Chưa đặt thì ô tên hiện "Người chơi" (`profile_name_default`, theo ngôn ngữ). Tên chỉ hiện ở Profile; BXH vẫn ghi "Bạn" cho hàng của người chơi.
- Luật (`Config.NAME_MIN`, `NAME_MAX`): 3–14 ký tự sau khi bỏ khoảng trắng hai đầu, chỉ chữ cái tiếng Anh, số, `_`, `.`, `-`, có ít nhất một chữ hoặc số, không chứa từ cấm.
- Từ cấm (`src/meta/name_filter.gd`): tục tĩu, xúc phạm, kỳ thị, tình dục của tiếng Anh và 13 ngôn ngữ còn lại viết bằng chữ Latin không dấu, thêm tên dành riêng cho nhân viên và thương hiệu (admin, moderator, official, support, Horus, Candy Away...). Không phân biệt hoa thường; bắt chữ kéo dài ("fuuuck"), chữ chen dấu `_ . -` ("f.u.c.k"), số thay chữ ("sh1t", "a55hole"). Từ ngắn dễ nằm trong từ thường ("ass", "lon", "dit") chỉ cấm khi đứng riêng, nên "class", "London", "Edit" vẫn dùng được.
- Tên sai luật hoặc có từ cấm: popup giữ nguyên và hiện thông báo nhanh (`profile_name_invalid`, `profile_name_banned`). Game offline nên không kiểm trùng tên.

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
| `shop_coins` | Khối ADS Daily trong Shop (không có trên Home), tối đa 5 video mỗi ngày theo lịch của máy | 200 gold mỗi video |
| `daily_next` | Popup quà, 1 lần mỗi ngày, sau khi nhận ô hiện tại | Nhận trước ô kế tiếp |
| `cosmetic_unlock` | Màn profile | 1 avatar hoặc frame |
| `rt_revive` | Hết bước ở level Road Trip, tối đa 3 lần mỗi lượt chơi | +5 bước, chơi tiếp |

Chỉ thưởng khi xem hết. Ghi `S.adPend` trước khi hiện quảng cáo và trao lại nếu app bị hệ điều hành đóng giữa chừng, tương tự `ads.lost` của Horus.

**Interstitial** `result_exit`: chỉ khi rời thẻ thắng và đã bỏ qua x2, hoặc khi đóng popup thắng Road Trip (mục 7 "Road Trip"). Theo số của Crash Ramp: không trước lượt 4, cách ít nhất 2 lượt và 120 giây, không trong 90 giây đầu phiên, không trong 45 giây sau rewarded. Phiên đầu không có cho tới khi qua L10. Không có quảng cáo lúc mở game và không chen giữa level.

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

### Leaderboard theo league (2026-11-03)

Logic ở `src/meta/leaderboard.gd`, số ở `Config.LEADERBOARD`, bản lưu `s.lb`. Mở từ L8 (`Config.UNLOCK.leaderboard`), có cả trong bản demo. Game offline nên mọi người khác trên BXH là bot sinh trong máy (tỉ lệ bot 100%); BXH, World Ranking và Top % đều là mô phỏng.

**Điểm**

- Từ L8, mỗi level thường có khối crystal (khối đặc biệt, trước 2026-11-04 là khối gắn huy hiệu ngôi sao): Normal 2, Hard 3, Very Hard 4 khối (`pieces_*`), không quá số khối của level. Chọn ngẫu nhiên theo số level nên chơi lại cùng level thì cùng khối. Daily Challenge không có. Khối crystal giữ màu và luật đi như khối thường, chỉ đổi chất liệu (xem "Khối crystal" ở mục 8).
- Khối crystal rời bàn (thoát hoặc bị Smash) cho 1 mảnh: icon khối crystal bật ra ở tâm khối rồi bay về chip đếm mảnh ở thanh trên (ngay dưới chip lượt, không nằm ở hàng booster); số trên chip chỉ tăng lúc icon chạm chip. 1 mảnh = 1 điểm, cộng khi thắng level; thua hoặc bỏ ván thì mất mảnh của ván đó. Điểm cập nhật ngay trên máy; thẻ thắng đợi icon đang bay tới chip.

**League** (chỉ lên, không xuống hạng; thưởng nhận một lần khi vào league)

| League | Điểm | Thưởng | Điểm tăng cơ bản của bot / ngày | Người chơi mô phỏng |
| --- | --- | --- | --- | --- |
| Silver | 0–29 | 100 gold | 1 | 48.000 |
| Gold | 30–79 | 300 gold, 1 Hint | 2 | 24.000 |
| Platinum | 80–179 | 500 gold, 1 Move | 3 | 14.000 |
| Emerald | 180–329 | 800 gold, 1 Smash | 4 | 8.000 |
| Diamond | 330–549 | 1.200 gold, 1 Hint, 1 Move | 5 | 4.000 |
| Immortal | 550–999 | 2.000 gold, mỗi booster 1 | 7 | 1.600 |
| One Above All | từ 1.000 | 5.000 gold, mỗi booster 2, 60 phút mạng vô hạn | 10 | 400 |

Thưởng và người chơi mô phỏng là đề xuất của mình, chưa có số liệu thật. Thưởng Silver nhận khi mở màn Leaderboard lần đầu; các league sau nhận ở popup Lên giải ngay sau thẻ thắng. Đóng popup bằng X vẫn nhận thưởng.

**BXH trong league**

- Mỗi BXH 100 người: người chơi và 99 bot. Bot có tên, avatar, frame, mã quốc gia random (từ 2026-11-05 màn BXH không hiện cờ); 80% bot dùng avatar mặc định, 85% dùng frame mặc định, còn lại random đều trong catalog.
- Lúc dựng BXH, điểm bot chia đều theo vị trí: vị trí k nằm trong dải rộng 1% khoảng điểm của league (Silver 0–29: mỗi vị trí cách nhau 0,3 điểm; Diamond 330–549: 2,2 điểm), dải thấp nhất dành cho người chơi vừa vào. Nhờ vậy chơi một level là lên vài hạng. League cuối không có trần: bot random đều trong 1.000–2.000 (`top_span`).
- Hạng = 1 + số bot có điểm cao hơn; bằng điểm thì người chơi đứng trên.
- Bot tăng điểm mỗi ngày lúc 7h00 GMT+7 (`grow_hour`, `grow_tz_hours`): điểm tăng = điểm tăng cơ bản của league + làm tròn(số ngẫu nhiên trong `bot_rand` [0, 4] × hệ số biến động trong `bot_var` [0,5; 1,5]). Mở game lại sau nhiều ngày thì bù từng ngày, tối đa 14 ngày (`grow_max_days`). Đồng hồ lùi thì không tăng.
- Bot chạm điểm tối thiểu của league kế thì rời BXH (lên hạng) và một bot mới vào ở đáy league thay chỗ, để BXH luôn đủ 100. Bot vừa lên hạng được giữ lại (tối đa 10, `carry_max`); khi người chơi lên league, BXH mới gồm các bot đó rồi bot mới cho đủ 100.
- UI hiện tối đa 50 người quanh người chơi (hạng 70 thì hạng 45 tới 94), podium top 3 luôn ở đầu danh sách, hàng của người chơi ghim trên hoặc dưới khi cuộn ra khỏi tầm nhìn, có ▲/▼ so với lần mở trước. Mỗi hàng ghi nhãn "Điểm xếp hạng" trên ô điểm. BXH League chỉ để xem, không chạm vào người khác được.

**Vị trí (Top %) và World Ranking**

- Top % = số người có thứ hạng cao hơn / tổng người tham gia × 100%, làm tròn lên, ít nhất 1%. Người có thứ hạng cao hơn = mọi người ở league cao hơn + (hạng trong BXH − 1) / 100 × số người của league mình, theo cột "Người chơi mô phỏng". Ví dụ đứng đầu BXH Silver: 52.000 / 100.000 → Top 52%.
- Tab World (từ 2026-11-05, theo wireframe): thẻ người chơi (huy hiệu giải, avatar, điểm, Top %, hạng thế giới) và thang 7 giải, giải cao nhất ở trên. Mỗi giải ghi số người chơi mô phỏng theo cột "Người chơi mô phỏng" (dạng 48K, 1,6K). Giải hiện tại nền xanh, quầng sáng sau huy hiệu, mũi tên và avatar "Bạn"; giải chưa tới mờ 60%; giải đã qua rõ. Nút trên banner đổi thang sang thưởng của từng giải ("Phần thưởng" ↔ "Thông tin"), giữ chỗ cuộn. Mở tab thì thang tự cuộn để giải hiện tại nằm giữa. Hạng thế giới vẫn tính như trước: 50 người đứng đầu là bot có điểm trên trần BXH league cuối, đổi theo ngày BXH; người chơi đủ điểm thì chen vào, không thì ước tính từ số người có thứ hạng cao hơn. Danh sách top 50 và thẻ người chơi khi chạm hàng không còn hiện ở màn này.

**UI**: icon Bảng xếp hạng (cúp) ở cột trái Home, dưới Daily Challenge (khoá tới L8: tối, có ổ khoá, ghi "Level 8"); từ 2026-11-05 không còn là tab của thanh dưới, màn Leaderboard vẫn có thanh dưới nhưng không tab nào sáng và không trượt như tab. Bố cục màn theo wireframe Leaderboard (2026-11-05), từ trên xuống: thanh trên chung; banner ảnh kẹo (`assets/ui/lb_banner.png`) có huy hiệu và tên giải hiện tại, tab League thêm đếm ngược tới lần bot tăng điểm (góc trái dưới) và nút "i" Cách hoạt động (góc phải dưới), tab World thêm nút "Phần thưởng"/"Thông tin"; phần thân của tab (League: khung "Thưởng thăng hạng: Giải X" với thưởng của giải kế, ẩn ở giải cao nhất, rồi BXH; World: thẻ người chơi rồi thang giải); thanh hai tab (tab trái là huy hiệu và tên giải hiện tại, tab phải là icon Bảng xếp hạng của Home và "Thế giới"); thanh dưới chung. Bỏ dải 7 huy hiệu, thanh tiến độ tới league kế (và Top % ở tab League), nút PLAY. Bảng 7 league vẫn có ở popup `popup_leagues` nhưng màn này không còn mở. Huy hiệu league là vòng màu + cúp, mảnh là icon khối lập phương crystal 3D màu loang bốn màu khối (`lb_piece`, `assets/ui/lb_piece.png`) ở chip đếm trong level, BXH, thẻ thắng và thẻ người chơi.

**Analytics**: `lb_join`, `lb_points` (level, points, total, rank), `lb_promote` (league), `lb_claim`, `lb_open`.

### Road Trip (2026-11-05)

Đường 400 level riêng, chơi song song với level chính. Logic ở `src/meta/road_trip.gd`, số ở `Config.ROAD_TRIP` và `Config.ROAD_TRIP_REWARDS`, bản lưu `s.road_trip` (`level` đang chơi, `boxes` đã nhận, `guide` đã xem hướng dẫn). UI theo wireframe `roadtrip_wireframe.html` (bộ REA của game gốc).

**Luật chơi:** đúng cơ chế level thường: bàn lưới, mỗi khối một hướng thoát theo màu, chạm thì trượt ra nếu đường không bị chắn, mỗi lần chạm tốn 1 bước kể cả khi bị chặn. Đưa hết khối ra là thắng; hết bước là thua.

**Level:** bộ MoreColor của game gốc (`configs_morecolorlevels` + `tb_morecolorlevel_config`, id 10001–10400), nhập bằng `tools/import_road_trip.gd` vào `data/road_trip/rt_0001.json` … `rt_0400.json`. Độ khó theo cột Difficulty: 310 level Normal, 68 Hard, 22 Super Hard (huy hiệu, dải cảnh báo và màu nút như level chính). Bước = `StepLimit` của bảng (số khối + 3, 4 hoặc 8), không theo dư MOVES của level chính. Trong dữ liệu gốc `x` là hàng, `y` là cột (cách đọc duy nhất mà cả 400 level giải được), nên hình vốn đã dọc: rộng 10–14, cao 12–24 ô; đặt giữa lưới ít nhất 14×18, khung bàn co ô theo hình như level chính (level cao 24 ô có ô nhỏ hơn). Không có đá, băng, xích, lớp, sương mù, cổng nhịp. Công cụ nhập kiểm mọi level giải hết bằng cách rút lần lượt khối thoát được, đúng số khối lần chạm.

**Cổng màu:** khác level chính (mỗi cạnh một màu, màu báo hướng), mỗi cạnh khung chia nhiều cổng, mỗi cổng một màu và một mũi tên; khối mang màu cổng nó thoát qua, nên nhìn màu khối rồi tìm cổng cùng màu trên khung là biết hướng. L1–200: 2 cổng mỗi cạnh, 8 màu, chia đúng chỗ game gốc chia (cột 10, hàng 14 của lưới 20×28 gốc). L201–400: 3 cổng mỗi cạnh, 12 màu, chia gần một phần ba bề ngang/dọc của hình, chọn chỗ ít khối nằm vắt qua ranh nhất. Màu xáo theo số level. 12 màu: vàng, xanh lá, xanh dương, tím (4 màu gốc), đỏ, cam, xanh ngọc, nâu (thêm cho 8 màu), hồng, chàm, kem, cam thảo đen (thêm cho 12 màu) (`LevelData.GATE_COLORS`, tông khối ở `ThemeKit.BLOCK_RAMPS`; mặt cắt thanh của màu mới suy từ thanh vàng theo sắc độ, `CandyFrame.color_ramp`). Khối nằm vắt hai cổng (49 khối trên cả 400 level) lấy màu cổng chứa nhiều ô của nó nhất. Dữ liệu: khối có `dir` (hướng thoát) tách khỏi `color`, level có `gates` (cạnh → [màu, từ ô, tới ô)); game gốc chỉ có 8 cổng mọi level (L1–200 dùng 4 màu, L201–400 dùng 8 màu), số 8/12 là của người dùng.

**Mở khoá:** `Config.UNLOCK.road_trip` (hiện là 2). Thắng L1 vẫn sang L2 như cũ (Road Trip không kéo về Home); thanh tính năng của thẻ thắng báo "Road Trip". Lần đầu về Home sau khi mở: lớp hướng dẫn phủ tối Home trừ thanh dưới, bong bóng "Road Trip unlocked!" và bàn tay chỉ vào tab; chạm đâu cũng tắt, không hiện lại.

**Mạng và kinh tế:** chơi không tốn mạng, thua hay bỏ giữa chừng không mất mạng, chơi lại miễn phí. Thắng không cộng gold, không x2, không điểm Weekly Pass hay leaderboard. Có interstitial `result_exit` khi đóng popup thắng, cùng luật nhịp của thẻ thắng thường (mục 6; không có x2 nên coi như đã bỏ qua x2; level Road Trip tính một lượt trong `s.runs`; cổng phiên đầu theo level chính đã qua); thua thì không có. Booster dùng được, mở theo level chính. Hết bước: hộp thoại "Hết lượt rồi" mời xem video `rt_revive` +5 bước (`revive_moves`), tối đa 3 lần mỗi lượt chơi (`revive_max`); không có lựa chọn gold hay kho. Bỏ cuộc thì thẻ thua (Chơi lại hoặc về bản đồ).

**Hộp quà:** 16 hộp ở level 15, 35, 69, 89, 123, 143, 163, 197, 217, 251, 271, 291, 325, 345, 379, 400 (`ROAD_TRIP.boxes`). Thắng level có hộp thì nhận thưởng của hộp đó, vào kho ngay, mỗi hộp một lần. Thưởng theo `tb_roadtripreward_config` (Hint = Gợi ý, Hammer = Phá khối, StepCount = +3 Move): 1 Hint; 1 Búa; 1 Bước; Hint + Bước; Hint + Búa; Búa + Bước; 2 Hint; Hint + Bước; Hint + Búa; Búa + Bước; Hint + Búa; Hint + Bước; Hint + Búa; Búa + Bước; Hint + Búa; Hint + Búa + Bước. Tổng 12 Hint, 10 Búa, 8 Bước.

**Màn Road Trip** (tab phải thanh dưới, trượt như Shop): thanh trên, ribbon "ROAD TRIP", bản đồ cuộn dọc, level 1 ở đáy. Mỗi hàng chạy 6 ô, chiều chạy đổi qua lại; giữa hai hàng chạy là hàng nối chỉ một mốc ở rìa; hộp rộng 2 ô ở đầu một hàng chạy (hàng đó 5 level). Mốc: lục giác xám (khoá), xanh dương có dấu tích (đã qua), mốc hiện tại to hơn, màu theo độ khó, có quầng sáng thở và mũi tên đỏ nhún cắm ở đỉnh. Hộp: hộp quà kẹo (`ic_giftbox1-3`, tạm dùng asset có sẵn); hộp đang nhắm có quầng sáng, hộp đã mở mờ đi kèm dấu tích. Đường kẹo kem viền tím, vạch hồng đứt khúc nối các mốc. Chip dính mép phải: icon hộp kế và thanh "đã qua / khoảng" (0/15 ở đầu; qua hộp 15 thì 0/20). Chạm hộp: bong bóng thưởng của hộp 2,5 giây. Chạm mốc hiện tại hoặc nút "Level N" trên thanh dưới: màn chuyển cảnh rồi vào level. Đi hết đường: ẩn nút và chip, dòng "You finished the Road Trip!".

**Thắng:** popup "Hoàn thành level!": hộp đang nhắm nảy vào, thanh tiến độ chạy từ trước tới sau, dòng "Còn N level nữa tới hộp quà" và nút Tiếp tục. Level có hộp: thanh đầy, hộp rung, bật mở rồi các vật phẩm nảy ra, nút Nhận. Đóng popup thì màn chuyển cảnh về bản đồ, mũi tên và quầng sáng trượt sang mốc mới.

**Analytics**: `rt_start` (level, runs, moves), `rt_end` (cùng tham số `level_end`), `rt_box` (level, box), `rt_revive` (level, n).

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
| Thông báo | Local, dùng AlarmManager. Lịch theo mục 15 của `GAME-GUIDE.md`: tuần đầu tối đa 3 lần/ngày, không trước 8:00 hay sau 22:00, rồi thưa dần tới ngày 30, bỏ qua 9 lần liền thì 1 lần/ngày. Chỉ nói thứ đang chờ thật: quà ngày, mạng đầy, gói đang mở. Thêm thông báo buổi tối: mỗi ngày đúng 20:00 giờ máy (`Config.NOTIF.evening_minute`), lập trước `evening_days` = 30 ngày nên vẫn chạy sau ngày 30; mỗi ngày chọn ngẫu nhiên 1 trong 10 nội dung (`notif_evening_01`..`10`, tiêu đề mở đầu bằng emoji, kèm icon lớn lấy từ icon trong game: đồng hồ, búa kẹo, sao, cúp, đầu lâu, nam châm, khối cầu vồng, hộp quà, gold, tim), đủ 10 nội dung mới lặp, hai ngày liền không trùng. Thông báo này tính vào mức mỗi ngày (tuần đầu còn 2 thông báo thường, sau đó và khi bị bỏ qua 9 lần chỉ còn 20:00); thông báo thường cách 20:00 ít nhất 2 giờ. Báo thức không chính xác nên có thể lệch vài phút. Xin quyền sau lượt 2. Chưa dùng push | Theo cách của Horus |
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
| Sọc | Dải chéo 45 độ lên phải, cạnh sắc, nửa đậm nửa nhạt; theo toạ độ ô nên khối cạnh nhau liền pha và sọc đi theo khối khi trượt; mờ đi khi qua mép gối | Chu kỳ ngang đúng 1 ô; sọc nhạt pha 50% tông `stripe` vào `face`, trên mép gối 8% |
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
- Khối không có mũi tên, đúng như ảnh duyệt. Lớp pudding và hộp giấy vẽ trong cùng shader thân khối (`pudding.gdshader`) theo SDF nên ôm đúng mọi hình khối, nháy sáng Gợi ý cũng vậy; xích, sương mù vẽ đè lên lớp kẹo, giữ nguyên cách đọc.
- Chưa áp dụng cho nền, icon (giữ nét hiện tại). Khi tạo hoặc làm lại hình bằng MCP, thêm từ khoá kẹo gel bóng (xem quy tắc prompt bên dưới) để cùng phong cách.

**Khung cổng (2026-11-02).** Khung theo cùng ảnh duyệt, vẽ bằng shader (`src/ui/candy_frame.gd`, `frame_bar.gdshader`, `frame_corner.gdshader`), số đo theo đơn vị khung (`Config.BOARD_FRAME_UNIT`):

| Phần | Hình | Số đo |
| --- | --- | --- |
| Thanh cổng | Bốn capsule rời nhau, mỗi cạnh một màu cổng, tô theo mặt cắt đo trung vị dọc thanh trong ảnh (`BAR_RAMPS`), hạ sắc độ cho bớt chói (saturation ×0,9, value ×0,9: `BAR_SAT`, `BAR_VAL`); thanh ngang có vạch sáng ở trên và dải đậm ở dưới, thanh dọc đậm ở hai mép; đầu trên thanh dọc có vòng sáng, đầu dưới đậm dần | Dày 0,55–0,60; từ mép bàn tới đường giữa thanh: trên 0,305, dưới 0,32, trái 0,46, phải 0,47 |
| Ống góc | Một phần tư vành tròn hồng đỏ nối hai thanh, nằm dưới đầu thanh; vệt trắng chạy theo cung, vị trí đổi theo từng góc vì ánh sáng từ trên hơi lệch trái | Bán kính tới đường giữa 0,49; rộng 0,44 |
| Mũi tên | Tam giác trắng bo góc, chỉ ra ngoài, viền mờ màu đậm của thanh; ở thanh dọc đặt cao hơn tâm | Ngang 0,45 (thanh dọc 0,50), dọc 0,34–0,35; thanh dọc lệch lên 0,21 |
| Bóng đổ | Mềm, lệch xuống dưới, ám tím đậm | Lệch 0,11; mờ 0,14; đậm 32% |

- Số đo hình học theo ảnh ref `art/concepts/ref_board_size.png`, màu giữ theo ảnh duyệt kẹo. Các số trong bảng tính theo đơn vị khung (`Config.BOARD_FRAME_UNIT`, 51,7 px ở màn chuẩn 886×1920), không theo cỡ ô khối. Khung chiếm thêm 0,77 đơn vị mỗi bên và 0,61 đơn vị trên dưới, trọn khung 803×1044 px ở màn chuẩn. Ảnh ref `ref_board_scale.png` quy đổi ra 803×1038 px.
- Màn level chỉ có thanh trên (lượt, tên level, restart, bánh răng; Home nằm trong popup cài đặt; hàng dưới giữ chỗ cao cố định cho chip đếm mảnh, kể cả level không có mảnh) và hàng booster (luôn 3 ô) chiếm chiều cao; chữ hướng dẫn và nhãn Phá khối phủ lên phần trên của bàn. Nhờ vậy khung không xê dịch giữa các level. Nền bàn trơn, không vẽ lưới ô.
- Vị trí và cỡ ở màn chuẩn 886×1920 (`scenes/level.tscn`). Chip lượt 244×169 px (số 85, chữ MOVES 36). Tên level cỡ 50, pill HARD 120×55 (chữ 30). Hàng chip mảnh cao 66 px (icon 50, số 35), chip căn giữa theo chip lượt (`PieceRow` là `CenterContainer` rộng 244 px). Chip mảnh dùng cùng khung kẹo tím với chip lượt (`hud_moves_panel`, 9-slice). Khung này vẽ bằng `src/ui/u_image.gd` với viền thu nhỏ 0,39 lần (66/169), để góc bo cùng tỉ lệ với chip lượt. `StyleBoxTexture` vẽ viền đúng 44–48 px của ảnh, lớn hơn chiều cao chip mảnh. Hàng booster cách đáy màn 175 px (lề dưới của `Margin`), nên nút booster nằm ở y 1577–1706 như ảnh ref quy theo chiều cao màn. Khung bàn nằm giữa thanh trên và hàng booster, ở y 406–1450 (ảnh ref: 359–1410).
- HUD level dùng bộ sprite kẹo thạch tím `assets/ui/hud/` (theo `art/concepts/ref_hud_candy.png`): khung MOVES ghi "MOVES" nhỏ trên số lượt to; pill tím ghi HARD hoặc VERY HARD dưới tên level; restart và bánh răng là nút tròn; 3 booster là nút vuông bo có glyph trắng. Huy hiệu góc dưới phải ô booster là tròn xanh ghi số còn lại (`x2`), hết kho thì là sprite dấu + xanh. Chữ và số đều vẽ bằng code.
- Nền màn level là ảnh `bg_level` (phong cảnh kẹo), giống nhau ở cả 3 độ khó, vẽ nhạt ở độ trong suốt 35% (`ThemeKit.LEVEL_BG_IMAGE_ALPHA`) trên nền hồng pastel `LEVEL_BG` (`#FFEEF4`) để nền ám hồng sáng; lớp dim `ThemeKit.LEVEL_BG_DIM` để trong suốt hoàn toàn (bàn có khung cổng bao quanh nên vẫn tách khỏi nền); ảnh cắt kiểu cover nên không méo trên màn dài. Độ khó chỉ báo bằng huy hiệu HARD/VERY HARD và dải cảnh báo, không đổi màu nền. Thiếu ảnh thì còn nền màu `LEVEL_BG`.
- Cổng nhịp đóng: thanh tối đi 55%, mũi tên mờ, hiện các vạch chắn ngang thanh; khi đổi trạng thái thì nháy sáng trong hình thanh. Khối bị cổng đóng chặn trượt qua khoảng trống tới mặt trong của thanh rồi bật về; hạt lúc khối thoát bắn ở mặt trong của thanh.
- Nền bàn (`ThemeKit.BOARD_BG`, `#E9CDD2`) cùng tông hồng với nền màn level (ảnh `bg_level` phủ lên `LEVEL_BG`, trung bình vùng bàn khoảng `#F7E6E5`) nhưng tối hơn một chút; hình theo khung (tới đường giữa thanh, bo theo ống góc).

**Hiệu ứng thoát và va chạm (2026-11-02, đổi sang nghiền qua thanh 2026-11-03).** Mức "đẹp mà vẫn êm" do người dùng chọn: nhiều chi tiết nhưng bàn chỉ rung nhẹ, đúng tiêu chí thư giãn ở mục 3. Không có lần nào chặn thao tác: người chơi chạm tiếp được ngay. Vẽ bằng code và shader (`src/ui/candy_shards.gd`, `candy_shard.gdshader`, `impact_flash.gdshader`); mảnh dùng chung chất liệu với khối qua `candy_body.gdshaderinc`.

| Khoảnh khắc | Diễn biến | Số đo |
| --- | --- | --- |
| Khối lao tới thanh | Nhanh dần, dài ra theo hướng lao; gần tới thanh thì chậm dần đều về đúng tốc độ nghiền để trôi êm vào thanh, không còn đâm vào thanh ở tốc độ cao nhất rồi khựng lại; độ dài ra co lại theo tốc độ; tới đúng mặt trong của thanh cùng màu (2026-11-04). Khối sát thanh không đủ đường để hãm thì nhanh dần tới tốc độ nghiền rồi đi đều. Khối cuối trên bàn không hãm: nhanh dần tới tận thanh như trước, đâm vào thanh ở tốc độ cao nhất cho cú chốt ván | Nhanh dần 0,20–0,42 giây tuỳ quãng đường, rồi chậm dần 0,1 giây về 9 ô/giây; dài ra 9% lúc nhanh nhất, theo bình phương tốc độ so với lúc nhanh nhất |
| Gió hút vào thanh (2026-11-04) | Khi khối thoát gần chạm thanh cùng màu và suốt lúc bị nghiền, vệt gió mảnh trắng pha màu thanh, có quầng mờ quanh vệt, dài ngắn khác nhau, hiện sát mặt trong của thanh, chạy nhanh dần vào thanh, chạm thanh thì bị nuốt vào. Vệt rải trong đúng bề ngang khối (không toả ra ngoài); miệng thanh trước khối sáng lên một quầng cùng bề ngang, mờ dần vào bàn. Thanh giữ nguyên hình dạng và kích thước, vệt không vẽ lên thanh. Vệt nằm trên lớp khối, vẽ cộng sáng nên rực lên cả trên nền bàn lẫn trên khối đang bị hút. Chỉ khi khối thoát, dội vào cổng đóng thì không có (`src/ui/suck_wind.gd`) | 5 vệt mỗi ô bề ngang khối (ít nhất 4), rải đều từ 0,2 giây trước lúc chạm tới lúc khối trôi hết qua thanh, mỗi vệt sống 0,16–0,24 giây, rõ dần trong 40% đầu đời vệt; cả cụm gió (vệt và quầng) rõ dần từ trong suốt trong 0,18 giây đầu, êm ở hai đầu, để không hiện đột ngột; đầu vệt hiện cách thanh 0,1–0,8 ô; dài 0,3–1,4 ô, lõi dày 0,035 ô, đậm 80%; quầng vệt rộng 0,28 ô, đậm 30%; quầng miệng sâu 0,6 ô, đậm 30%, tắt 0,12 giây sau vệt cuối; màu thanh pha 60% trắng |
| Nghiền qua thanh (theo video ref `art/concepts/2026-11-03_08-48-53.mp4`) | Không nổ một lần: khối trôi đều tiếp qua thanh, phần đã qua mặt trong của thanh bị cắt đi như lùa dưới thanh. Mỗi ô đang vắt qua thanh phun ra khối vuông nhỏ ở mặt ngoài thanh, theo phần diện tích vừa qua, nên vụn ra liên tục suốt lúc khối đi qua; kèm vài sao lấp lánh lúc bắt đầu. Khối vuông lấy màu đúng chỗ đang qua thanh trên khối (sọc, mép) và có mặt bên đùn xuống (tối theo hướng mặt, vạch sáng ở mép trên) nên trông như hạt kẹo cứng. Góc khối vuông bo tròn, viền sáng của mặt trên mảnh hơn viền mảnh vỡ thường, không có viền tối giữa mặt trên và mặt bên (2026-11-04; bỏ viền tối áp dụng cho mọi mảnh kẹo) | Trôi 9 ô/giây; 22 khối vuông mỗi ô diện tích; cạnh khối vuông khoảng 0,15–0,24 ô (nửa đường chéo 0,11–0,17 ô, tính trước khi bo), dày 0,8 lần nửa đường chéo; bo góc bán kính 0,45 lần nửa cạnh, 2 đỉnh mỗi góc; viền mặt gãy rộng 0,5 lần viền mảnh thường; mỗi khối vuông kèm 1 mảnh nhỏ hơn (nửa đường chéo 0,05–0,09 ô) ra lệch ngang tối đa 0,25 ô, bay riêng cùng tốc độ và đời (2026-11-04); phun 2,2–5,5 ô/giây, lệch ngang tối đa 0,5 lần tốc độ phun, sống 1,1–1,6 giây, mờ dần từ 45% đời (2026-11-04: văng chậm hơn, ít toả hơn, mờ chậm hơn); 6 sao |
| Vụn bay | Phun ra khỏi thanh theo hướng khối đi, toả hình nón rộng sang hai bên, chậm dần, trôi nhẹ chứ không rơi, vừa bay vừa lật; bay đè lên cả vùng ngoài bàn, nút và chữ; nhỏ dần và mờ ở cuối | 3,5–9 ô/giây theo hướng đi, ngang tới ±1 lần; hãm 1,8/giây; trọng lực 3 ô/giây²; xoay 3–9 rad/giây; sống 0,75–1,15 giây; bay xa khoảng 1,5–4,5 ô (trước đây 0,7–2,2 ô) |
| Thanh bị va | Bật ra rồi nảy về, sóng sáng chạy dọc thanh từ điểm va, mũi tên phồng lên | 0,45 giây; bật 0,1 ô |
| Đoạn thanh lăn (theo video ref `art/concepts/2026-11-03_08-48-53.mp4`) | Đoạn thanh khối phủ lên nổi thành lăng trụ lục giác hơi to hơn thân thanh, có chốt trục ló ở hai đầu, lăn quanh trục thanh theo hướng khối đi; nằm yên thì một mặt hướng lên người nhìn; mỗi mặt tô theo mặt cắt thanh nên khớp ánh sáng, cạnh giữa hai mặt sáng lên. Lăn đều suốt lúc khối trôi qua thanh, rồi chậm dần, dừng đúng một mặt (bội 60°) và chìm lại vào thanh. Khối thoát: đoạn dài bằng toàn bộ khối chiếu lên trục thanh. Dội vào cổng đóng: chỉ các ô mép trước, lăn 1 mặt | Nổi lên 0,05 giây; chậm dần 0,6 giây qua 2 mặt = 120° (cổng đóng 1 mặt = 60°), chìm lại trong 30% cuối; lúc khối đang qua quay khoảng 1,7 vòng/giây; lăng trụ rộng đỉnh-tới-đỉnh 1,12 lần bề dày thanh; chốt dài 0,09 ô |
| Loé sáng | Chỉ khi va chạm: quầng sáng, sao bốn cánh và vòng sóng toả ra, kèm sao lấp lánh. Khối thoát không loé, không rung bàn | Rộng 1,8 ô, 4 sao |
| Va chạm | Khối đi va nhún theo trục va, tâm nhún ở điểm chạm rồi về chỗ cũ không vượt quá; vụn kẹo và sao văng ra ở điểm chạm | Nhún 15%, 0,46 giây; 4 vụn mỗi khối, văng 2–5 ô/giây |
| Khối bị va | Giật lùi rồi về đúng ô, nhún theo, dư chấn lan sang tối đa 2 khối nằm ngay phía sau, mỗi khối yếu đi một nửa | Nhún 10%; lùi 0,1 ô; trễ 0,05 giây mỗi khối |
| Chạm cổng đóng | Chỉ khối kẹo nhún và văng vụn; thanh bị va | Như trên |
| Thùng sắt | Ảnh thùng sắt (`mech_stone`) phủ kín ô vuông. Người chơi chạm vào ô thùng: thùng rung, nắp loé, đinh loé, tia lửa nhỏ, không tốn MOVES | Như "Va thùng sắt", độ mạnh 70% |

**Hiệu ứng vật cản (2026-11-03).** Gọn, mỗi khoảnh khắc dưới 0,9 giây, không chặn thao tác; có loé sáng sao bốn cánh và sao lấp lánh như va chạm thường. Code ở `src/ui/obstacle_fx.gd`, nối trong `board_view.gd`; số đo cỡ theo ô.

| Khoảnh khắc | Diễn biến | Số đo |
| --- | --- | --- |
| Va thùng sắt | Ô thùng rung cứng và nhanh theo hướng va (ép ít, dao động tắt dần); nắp loé trắng rồi một vệt sáng quét chéo từ góc trên trái xuống, bốn đinh loé sao lần lượt khi vệt sáng đi qua; tia lửa thép trắng vàng toé ngược về phía khối va rồi rơi, vài tia đỏ cam nặng rơi sớm; loé trắng xanh với vòng sóng rõ | Ép 7%, 3,5 nhịp, 0,42 giây; vệt sáng 0,27 giây; 12 tia lửa 6–15 ô/giây, 5 tia nặng; loé 1,9 ô |
| Va khối pudding | Khối bị va nhún mạnh như thạch; vài giọt pudding bắn ra; loé hồng | Nhún gấp 2,2 lần khối thường; 6 giọt |
| Pudding vỡ (lần chạm đầu) | Khối nảy, loé trắng; lớp pudding phồng ra và mờ đi; bọt pudding bóng toả tròn rồi rơi, giọt nhỏ bắn xa; loé hồng lớn với vòng sóng, sao lấp lánh | Lớp pudding to 1,28 lần trong 0,3 giây; 16 bọt, 14 giọt; loé rộng bằng khối + 2,2 ô |
| Va hoặc chạm khối bị xích | Khối rung (khi chạm), tia lửa thép toả nhanh từ ổ khoá hoặc điểm va, loé trắng nhỏ; khối chìa phồng lên để chỉ chỗ | 9 tia, sống 0,32 giây; loé 1,3 ô |
| Xích đứt (chìa đã thoát) | Ổ khoá bật quai, phóng to, xoay và bay lên rồi mờ; mắt xích văng tung, xoay rồi rơi; lớp xích phồng ra mờ dần; tia lửa vàng, loé vàng lớn, sao lấp lánh | Ổ khoá 0,55 giây, to 1,6 lần, bay lên 0,9 ô; 12 mắt xích, 12 tia lửa |
| Va hộp giấy | Bụi giấy và 3 mẩu giấy bay lả; loé màu giấy nhỏ | Loé 1,3 ô |
| Hộp bay ra (lớp ngoài thoát) | Hộp giấy lao về thanh cùng màu như khối thoát (có gió hút), kẹo bên trong ở lại, nảy và loé, sao lấp lánh màu mới; tới thanh thì thanh lăn và hộp rách tung thành giấy vụn (màu hộp, giấy kraft, băng dán) bay lả theo hướng đi | 0,22–0,42 giây tới thanh; 22 mẩu giấy, sống 0,9 giây |

- Khối còn trong sương mù: vụn va chạm dùng màu xám để không lộ màu. Khi nghiền thì đã thoát nên vụn dùng đúng màu thật.
- Trận thắng chờ khối cuối nghiền xong thêm 0,25 giây rồi mới hiện thẻ thắng; vụn còn lại bay tiếp đè lên thẻ tới hết đời.
- Shader hiệu ứng được biên dịch sẵn khi vào màn đầu tiên.

**Khối crystal (2026-11-04).** Khối đặc biệt của leaderboard (mục 7) không còn huy hiệu ngôi sao; cả thân khối đổi sang chất liệu kẹo đường kết tinh trong như thuỷ tinh theo ảnh ref `art/concepts/concept_candy_board_v4_crystal_semi.png` (trước là `concept_candy_board_v3_crystal.png`), vẽ trong cùng shader thân khối (`crystal_color` trong `src/ui/candy_body.gdshaderinc`, bật bằng tham số `crystal`), dùng bốn tông của màu khối nên vẫn đọc được hướng đi. Khác khối thường ở năm chỗ để nhận ra ngay: không sọc, lòng đậm và loang, vết nứt trắng, viền đường cát lởm chởm, vệt bóng lưỡi liềm ở góc. Còn trong sương mù thì vẫn là kẹo xám. Mảnh vụn, khối vuông nhỏ lúc nghiền và mảnh vỡ khi bị búa của khối crystal cũng tô chất liệu crystal (không có vạch bóng của kẹo sọc). Số đo theo ô:

| Lớp | Hình | Số đo |
| --- | --- | --- |
| Lòng khối | Đậm hơn kẹo thường (tông `face` ngả về `deep`), không sọc; sáng tối loang như nhìn xuyên vào khối; ánh sáng vào từ trên trái nên lòng khối sáng lên sát mép dưới phải | Ngả tông đáy 42%; nhiễu loang 1,5 và 3,6 mỗi ô; vùng sáng sát mép dưới phải sâu 0,3 |
| Mảnh vỡ, vết nứt | Mảnh Voronoi lệch sáng tối (pha về tông đáy hoặc tông sáng nên vẫn tươi màu); vết nứt trắng sắc, đứt quãng; vết nứt nhỏ mờ hơn, thưa | Mảnh lớn 1,1 mỗi ô mỗi chiều, nứt rộng 0,02; nứt nhỏ 2,6 mỗi ô |
| Viền trong, mép vát | Viền trong là vạch sáng quanh khối, rõ nhất ở dưới phải; ngoài viền là mép vát thuỷ tinh: sáng ở trên trái, tông `deep` ở dưới phải, vạch sáng sát đáy | Viền trong cách mép 0,15 |
| Đường cát | Dải hạt trắng dày quanh mép, phủ mờ như sương: dày ở trên, mỏng còn một nửa ở dưới; hạt lồi ra khỏi mép nên viền lởm chởm; hạt thưa trong lòng khối | Dải 0,11 ở trên, 0,055 ở dưới; hạt 17 và 36 mỗi ô; lồi ra 0,025 |
| Vệt bóng | Lưỡi liềm trắng ôm góc lồi trên trái của mỗi mép hướng lên, dày ở góc, thon về hai đầu (`BoardFx.draw_crystal_gloss`, thay cho vệt bóng của kẹo sọc) | Dọc mép trái 0,46, dọc mép trên 0,64; dày nhất 0,11 |
| Ánh kính | Một vệt sáng quét chéo qua lòng khối theo chu kỳ | Mỗi 2,8 giây, 32% |
| Sao nhấp nháy | Mỗi ô một sao bốn cánh nhỏ ở chỗ ngẫu nhiên, loé lên rồi tắt | Khoảng 0,45 lần mỗi giây mỗi ô |

| Khoảnh khắc | Diễn biến | Số đo |
| --- | --- | --- |
| Khối crystal va (hoặc bị va) | Thay loé và sao thường: vụn crystal, mảnh kính hình thoi cộng sáng toé ngược ra, vừa bay vừa lật rồi rơi; loé trắng lạnh pha màu khối với vòng sóng rõ; sao lấp lánh; tiếng "ting" thuỷ tinh `sfx_crystal` (`ObstacleFx.crystal_hit`) | Cỡ 60% so với mảnh kính lúc qua thanh: 10 mảnh kính 3–8 ô/giây, sống 0,5 giây; loé 1,3 ô; 6 sao nhỏ. Khối crystal bị va: 70% |
| Khối crystal qua thanh | Như khối thường (không loé), thêm mảnh kính phun theo hướng đi | 8 mảnh kính |
| Khối crystal bị búa | Như Phá khối thường, thêm mảnh kính toả tròn và tiếng "ting" | 16 mảnh kính |
| Icon bật ra (lúc chạm khối, ở tâm khối) | Icon khối crystal (`lb_piece`) nở quá đà từ 0 và xoay về thẳng, loé trắng phủ icon; quầng xanh băng, tia bảy sắc xoay mọc dài, vòng sóng, sao bốn cánh lớn loé ở góc trên trái icon; kim tuyến bảy sắc và mảnh kính nổ; tiếng `sfx_crystal`. Đứng lắc nhẹ một nhịp (`src/ui/crystal_fly.gd`) | Nở 0,18 giây tới 72 px; đứng 0,08 giây |
| Icon bay về chip | Vòng cung: vọt lên, ngả ra xa chip rồi lượn vào chip từ phía dưới; nhỏ dần tới cỡ icon chip, lắc nhẹ; đuôi lăng kính màu trôi kèm lõi trắng xanh, kim tuyến rơi dọc đường, sao nhấp nháy ở góc icon. Lúc rời chỗ phát `sfx_crystal_get` (chuông lên dần, đỉnh rơi đúng lúc chạm chip) | 0,44 giây; đuôi dài 34% đường bay |
| Chạm chip | Icon chip nảy dẻo, nghiêng, loé sáng; số trên chip tăng và nảy; sao bốn cánh lớn quay co lại, tia bảy sắc toả, hai vòng sóng (xanh, hồng), kim tuyến và mảnh kính nổ. Lớp màu đậm vẽ trộn thường để nổi trên nền sáng, quầng và sao vẽ cộng sáng | Icon chip to 1,6 lần, về trong 0,55 giây; tắt hẳn sau 0,5 giây; tổng từ lúc chạm khối khoảng 1,2 giây |

**Vẫn vẽ bằng code (và shader):** hình khối, cổng, hạt, và mọi chữ. Khối phải khớp từng ô, chữ phải đổi được giữa `en` và `vi`. Hình do MCP tạo không có chữ; số như "+3" vẽ đè bằng code.

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
| `bg_home` | `background` | 768×1664 → rộng 720 | Nền ít chi tiết, phần giữa yên để bàn cờ nổi; cắt được cho 360×640 |
| `bg_level` | Ảnh có sẵn (`art/images/bg_level_candy.png`) | 880×1787 → rộng 720 | Phong cảnh kẹo, giữa là bãi cát trống cho bàn cờ; code phủ dim và cắt kiểu cover theo màn |
| `block_surface` | Bỏ | | Không còn dùng: chất liệu khối vẽ hoàn toàn bằng code (xem Concept theme) |
| `ui_gold`, `ui_heart`, `ui_hint`, `ui_moves`, `ui_smash` | `icon`, nền trong | 1024 → 128 | Gold, mạng, 3 booster (bản cũ; booster nay dùng `booster_*`) |
| `booster_hint`, `booster_move`, `booster_smash` | Cùng một phong cách sticker phẳng của Smash: viền đậm, tô khối 2-3 tông phẳng, mảng sáng trắng, không gradient. Smash: `edit_game_image` từ bản cũ. Hint, Move (2026-11-04, lần 3): `edit_game_image`, ảnh 1 là `booster_smash.png` làm mẫu phong cách, ảnh 2 là bản kẹo 3D trước đó (`art/images/booster_*_candy_ai.png`, chọn từ bảng `art/concepts/concept_booster_candy_v1.png`) làm mẫu nội dung, nền trong. Cắt bằng `tools/fit_icon.gd` | 1024 → 256 | Bóng đèn kẹo chanh, đế kẹo hồng có ren, ba tia kẹo; chữ "+3" kẹo dẻo xanh lá có vệt xoắn; búa kẹo mút (hai mặt kẹo xoắn hồng trắng, thân sọc, nơ hồng, cán que trắng; 2026-11-03 sửa từ `booster_smash.png` cũ, ảnh gốc `art/images/booster_smash_lollipop_ai.png`, cùng ảnh cắt 384 px làm `fx_lollipop_hammer` cho hiệu ứng Phá khối). Move dùng chữ "+3" thay cho mũi tên vòng để khỏi lẫn với nút restart |
| `hud_btn_restart`, `hud_btn_settings`, `hud_booster_hint`, `hud_booster_move`, `hud_booster_smash`, `hud_panel`, `hud_moves_panel`, `hud_pill`, `hud_badge_plus`, `hud_badge_count` (`assets/ui/hud/`) | `edit_game_image`, nền trong, tham chiếu `art/concepts/ref_hud_candy.png` (cắt từng nút ở `art/images/hud_ref/`); cắt bằng `tools/fit_icon.gd --solid=200` | 1024 → 192 (nút tròn), 256 (booster), 288×185 (khung MOVES, 9-slice ~44 px), 96×44 (pill, 9-slice ~22 px), 96 (huy hiệu) | Bộ HUD kẹo thạch tím theo ảnh ref: nút tròn restart, bánh răng; 3 booster vuông bo có glyph trắng hồng (búa kẹo mút mặt xoắn hồng, sửa 2026-11-03 từ ảnh nút cũ; số 3 trong vòng mũi tên đầu hồng, bóng đèn có vòng xoắn hồng, sửa 2026-11-04 theo búa: glyph trắng hồng, một điểm nhấn hồng); khung MOVES và pill độ khó để trống, chữ và số vẽ bằng code; huy hiệu xanh dấu + (hết booster) và tròn trống (số còn lại). `hud_panel` (squircle, cạnh cong nên không 9-slice) chưa dùng |
| `ui_shop`, `ui_settings`, `ui_lock`, `ui_restart`, `ui_video`, `ui_gift`, `ui_profile`, `ui_sound`, `ui_music` | `icon`, nền trong | 1024 → 128 | Nút và trạng thái; tắt âm thì code vẽ gạch chéo |
| `art_win`, `art_lose`, `art_no_lives` | `ui`, nền trong | 1024 → 512 | Thẻ thắng, popup thua, màn hết mạng |
| `art_lose_tear` | Cắt từ `art_lose` (`tools/split_tear.gd`) | 32×35 | Giọt nước mắt của popup thua, chảy xuống má; `art_lose` đã bỏ giọt này |
| `avatar_00`–`avatar_12` | `icon`, nền trong | 1024 → 256 | Avatar; `00` là mặc định |
| `frame_00`–`frame_12` | Vẽ bằng code (`python3 tools/gen_frames.py`, không AI), nền trong; nguồn `art/images/frame_XX_candy.png`. Theo ảnh ref `assets/ui/figma/ava_frame.png` (2026-11-04): vuông bo góc kín canvas, bán kính góc 24/124, viền 10/124 (mép trong trùng chỗ avatar thụt 8%), đổ sáng phẳng 3 tông từ trên | 1024 → 256 | Frame bao avatar, giữa trong suốt; `00` là mặc định (vẽ lại đúng ref, viền 8/124). 01–12 từ đơn giản tới cầu kỳ: hồng bubblegum trơn, bạc hà chip sô-cô-la, việt quất đường lấp lánh, kẹo gậy sọc đỏ trắng, kem dâu rắc cốm, nho với jelly bean, sô-cô-la sốt caramel và ngọc trai, thạch xanh ngọc với kẹo gum ở góc, đai cầu vồng, tim đỏ có nơ hồng, kem viền bắt bông có cherry, caramel vàng gắn đá quý. Thay bộ vòng tròn AI cũ (`art/images/frame_XX.png`) |
| `mech_stone`, `mech_ice`, `mech_chain`, `mech_key`, `mech_fog` | `image`, nền trong | 512 → 128 | Lớp phủ cơ chế sau demo |
| `lb_piece` (`assets/ui/lb_piece.png`) | `edit_game_image`, nền trong, một vùng cắt của ảnh ref `concept_candy_board_v4_crystal_semi.png` làm tham chiếu chất liệu; nguồn `art/images/lb_piece_cube.png`; cắt bằng `tools/fit_icon.gd --size=128 --margin=0.04` | 1024 → 128 | Mảnh leaderboard: một khối lập phương kẹo crystal 3D nhìn chéo từ trên (thấy mặt trên và hai mặt bên), màu loang mềm qua xanh dương, tím hồng, vàng hổ phách, xanh lá; viền đường cát, vệt bóng trên trái, vết nứt mảnh |
| `lb_banner` (`assets/ui/lb_banner.png`) | `start_game_image` (`asset_type=background`, `style=3d_render`), 1536×448; ba phương án nguồn `art/images/lb_banner_a.png` (đồi kem, mây pastel), `lb_banner_b.png` (vương quốc kẹo ban đêm), `lb_banner_c.png` (sân khấu kẹo); dùng C, bỏ kênh alpha (ComfyUI trả alpha 249–255) | 1536×448 | Banner màn Leaderboard (2026-11-05): rèm kẹo sọc hồng xanh hai bên, kẹo mút và khối thạch ở hai góc dưới, giữa là bục sáng có tia sáng cho huy hiệu giải; nền xanh hợp màu màn |

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
| `sfx_crystal`, `sfx_crystal_get` | `SFX` 2 giây → 0,75 giây; `One-shot` 1,5 giây → 1 giây | Khối crystal va, icon crystal bật ra; chuông nhặt mảnh lúc icon bay về chip. Thiếu file thì dùng `sfx_coin` |
| `bgm_home`, `bgm_level` | `Music` | 100 và 150 giây → vòng lặp 28 ô nhịp, 67,2 và 84 giây | `bgm_home`: Home, Shop, Leaderboard, Profile, màn Daily Challenge, màn hết mạng; nhạc kẹo vui nhẹ 100 BPM. `bgm_level`: màn chơi; dịu, đều, 80 BPM. Không lời, không cao trào. Tiêu chuẩn, phân tích người chơi, cách tạo và kiểm: `docs/AUDIO_MUSIC.md` |

**Cách làm**

1. Prompt nào cũng theo một bộ quy tắc: nét bo tròn, màu tươi, chất liệu kẹo gel bóng (sọc chéo 45 độ, mép gối đậm màu dày ở đáy, vạch sáng trắng ở mép trên), đổ bóng nhẹ, nền sạch, không chữ, không logo, không watermark. Màu khối ghi đúng mã màu đang dùng trong game. Không đưa tên hay ảnh của game gốc vào prompt hoặc ảnh tham chiếu.
2. Dùng seed cố định và `use_reprompt=false`, để prompt lưu lại đúng là prompt đã chạy. Ghi công cụ, prompt, seed, steps và SHA256 của từng file vào `art/manifest.json`.
3. Tạo thư mục cha trước khi gửi job. MCP không ghi đè file, nên làm lại thì lưu tên mới (`_v2`). Job chưa xong thì gọi lại `collect_*` với cùng `prompt_id`, không gửi job mới.
4. Bản gốc nằm trong `art/`, không vào bản build (loại khỏi export bằng filter hoặc `.gdignore`). File dùng trong game nằm trong `assets/`: PNG cho hình, Godot tự import; **WAV cho hiệu ứng** để giảm độ trễ, **Ogg cho nhạc nền** để lặp liền mạch. Thu nhỏ, cắt khoảng lặng và cân âm lượng bằng `ffmpeg`, chỉ là công cụ dev.
5. Nhạc nền phải nghe thử chỗ nối vòng lặp và đặt loop trong import của Godot; thời lượng tạo ra không bảo đảm nối liền. Điểm nối chọn tròn ô nhịp bằng `tools/music_check.py loops`, ghi vào bảng `MUSIC` của `tools/process_audio.sh`, kiểm bằng `music_check.py report` và `seam` (`docs/AUDIO_MUSIC.md` mục 5).
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
- Đổi concept hình khối từ pudding sang kẹo cứng bóng có vệt chéo (ảnh tham chiếu của người dùng), vẫn vẽ bằng shader `src/ui/pudding.gdshader`.
- Thêm avatar và frame, 6 cơ chế từ L21, bảng mở khoá, thưởng Daily Challenge, tiêu chí thư giãn.
- Dùng AppLovin MAX, không có banner.

**2026-11-02**

- Đổi concept hình khối sang kẹo sọc (ảnh duyệt `concept_candy_board_v5_stripe`), đo số từ ảnh; bốn màu khối và cổng đổi theo ảnh. Giữ mũi tên mù màu dù ảnh không có.
- Đổi khung cổng từ bốn dải vát chéo sát bàn sang bốn thanh capsule và ống góc theo cùng ảnh; chấp nhận cỡ ô giảm khoảng 14% để giữ đúng tỉ lệ khung.
- Khối thoát thì vỡ thành mảnh kẹo ở mặt trong thanh, mảnh bay xuyên qua thanh và được đè lên vùng ngoài bàn; bị chặn thì nhún, văng vụn, dư chấn lan sang khối sau. Áp dụng cả với đá và cổng đóng. Giữ mức rung nhẹ.
- Bàn cờ cố định 14×19 ô, ô 42 px theo ảnh ref, không đổi theo số khối; khối xếp thành nhiều hình ở giữa bàn, có khoảng trống. Sinh lại L21–300; L1–20 giữ layout tay, trừ 12 level trước đây kín hoặc gần kín khung. Sương mù chỉ lộ khi khối kề rời đi. Đưa MOVES lên thanh trên, bỏ lưới ô trên nền bàn.
- Thêm Weekly Pass, Chain Offer, Special Pack (mục 7). Weekly Pass chỉ có ở bản phát hành vì demo không có level HARD thứ 2 trong phạm vi L1-20.
- Weekly Pass: thêm mốc khởi đầu 0 key, hàng tiến độ (nút "i", chìa, thanh tới mốc kế), tutorial 3 bước và popup "How to earn rewards"; key chỉ được cộng sau khi xem tutorial. Giảm chiều cao vùng cuộn của layer (640 xuống 500) vì panel vượt màn 720x1280.
- Thêm loại thưởng "mạng vô hạn" (`inf_min`, phút; `s.lives.inf_until`): đang còn hạn thì thua không mất mạng, Home hiện "Mạng: vô hạn" cùng đếm ngược, cảnh báo mất mạng khi bỏ ván bị ẩn; cấp thêm khi còn hạn thì cộng dồn. Dùng cho mốc khởi đầu Weekly Pass (15 phút, theo video) và VIP mốc 3 key (30 phút).

**2026-11-03**

- Nối logic Leaderboard (mục 7) thay cho bản UI giải đấu theo tuần: league theo tổng điểm, 7 league, chỉ lên không xuống, không có mùa. Điểm lấy từ khối ngôi sao trong level, cộng khi thắng. BXH 100 người toàn bot, bot tăng điểm mỗi ngày 7h00 GMT+7. Mở ở L8; tab Ranking không còn phụ thuộc `Config.ui_preview`.
- Spec gốc ghi "7 League" nhưng chỉ liệt kê 6 khoảng điểm và nhắc tới "One Above All"; mình đặt One Above All là league thứ 7 từ 1.000 điểm, không có trần.
- Bỏ mũi tên hỗ trợ mù màu trên khối và dòng bật tắt trong Settings (`settings.arrows`, chuỗi `settings_arrows`); mũi tên trên thanh khung cổng giữ nguyên. Bản lưu cũ còn khoá `arrows` thì để yên, không đọc nữa.
- Dựng lại Settings, cài đặt trong màn và Profile theo khung hi-fi Figma (node 47:3486). Settings: bốn icon bật tắt (âm thanh, rung, nhạc, thông báo) thay cho dòng On/Off, nút Support và Language, ngôn ngữ chọn trong popup Language; Privacy, Restore là chữ gạch chân; số phiên bản nằm dưới góc phải popup. Cài đặt trong màn: Home và Restart gắn "-1 tim" khi bỏ ván sẽ mất mạng. Profile: chạm ô để chọn, một nút dưới lưới (đang đeo, Đeo, hoặc giá gold kèm nút video); tab Avatar và Frame. Figma có biệt danh và UID nhưng game chưa có tài khoản, nên ô tên hiện "Người chơi" và dòng UID hiện gold.
- Tăng độ khó từ L14 (mức "vừa"): số khối nhân 1,3, trần 40; bộ sinh ưu tiên khối bị chặn lúc đầu mạnh hơn; công thức dư MOVES giữ nguyên. Từ L14 khối xếp theo 21 hình vẽ tay (`src/core/motifs.gd`, ba nhóm: hình cơ bản, theme kẹo, hình khác; không dùng hoa văn sinh ngẫu nhiên). Ô, đá và cách cắt khối đối xứng theo hình, màu (hướng) vẫn tự do. Level dạy cơ chế bỏ bảng làm tay nhỏ, sinh to như level thường và chỉ bật cơ chế mới. Bàn có cổng nhịp tối đa 26 khối (trước là 20). Sinh lại L14–100 bằng lệnh phát hành (cờ `--teach` đổi tên thành `--early`); L1–13 không đổi.
- Menu tester mở bằng 10 lần chạm nhanh vào số phiên bản trong Settings (trước là 7) hoặc phím F1 ở mọi màn. Bản debug (`Config.account_tool()`, gồm APK demo) có thêm phần sửa tài khoản: gold, level, số booster gợi ý, +3 Move, phá khối (Save), và Xoá tài khoản (chạm hai lần). Xoá tài khoản xoá file lưu, `.bak`, bản sao cloud và trạng thái mua giả lập, rồi chạy lại như lần cài đầu; bản lưu mới ghi đè bản cloud. Mua hàng thật trên Google Play vẫn giữ, Restore lấy lại được. Bản phát hành chỉ còn nút mediation debugger.
- Gấp đôi số khối mọi level (`DifficultyCurve.COUNT_SCALE` = 2): L1–4 làm tay lại (4, 6, 8, 10 khối), sinh lại L5–100 bằng lệnh phát hành. Hình vẽ tay giữ cỡ, khối nhỏ lại (`MOTIF_FILL_MIN`, `MOTIF_FILL_MAX` 2,3–3,6 → 1,15–1,8), phần lớn khối giờ chỉ 1 ô. Bàn có cổng nhịp tối đa 52 khối, từ L130 (tới 2 cổng) tối đa 40 để sinh trong game vẫn dưới 200 ms.
- Đổi tên game thành Candy Away (dòng phụ "Tap Block Puzzle"); package id và tên dự án giữ nguyên. Thêm màn loading khi mở game, art từ `concept_loading_v1_s2102` (nền, khối kẹo) và `concept_loading_v1_s2103` (logo).
- Theme kẹo cho vật cản: đá thành khối gỗ nâu, băng thành lớp pudding gần trong suốt phủ trọn khối, xích quấn chữ X qua cả khối kèm ổ khoá vàng, hai lớp thành hộp giấy (che kín kẹo bên trong, lớp ngoài bay ra thanh rồi rách tung). Thêm hiệu ứng va chạm và mất vật cản theo chất liệu (mục 8). Luật, dữ liệu level và tên trong code giữ nguyên. Icon popup mới `mech_stone`, `mech_ice`, `mech_layer` tạo bằng MCP ComfyUI; âm thanh chưa đổi. Bảng "Cơ chế sau bản demo" sửa mốc level cho khớp `Config.UNLOCK` (trước ghi 21/31/46/61/81/101).

**2026-11-04**

- Vật cản `stone` đổi từ khối gỗ thành thùng sắt. Ảnh `mech_stone` mới: nắp thép xanh xám nhìn từ trên, bốn đinh tán to đọc rõ ở ô 42 px (nguồn `art/images/mech_iron.png`, chọn trong 3 bản vì đinh to nhất). `sfx_stone` mới là tiếng keng thùng sắt (nguồn `art/audio/sfx_iron.mp3`), cắt còn 0,5 giây vì bản gốc có cú gõ thứ hai ở 0,6 giây. Hiệu ứng va đổi theo chất liệu (mục 8): thùng rung cứng, nắp loé, vệt sáng quét làm đinh loé, tia lửa thép thay cho dằm gỗ và mùn cưa. Luật, dữ liệu level, tên trong code và tên file giữ nguyên.
- Máy Windows không có Python và GStreamer thì xử lý sfx bằng `tools/process_sfx.gd` (bản Godot của nhánh `sfx` trong `tools/process_audio.py`, cùng thông số). Godot không đọc được flac nên sfx tạo mới lưu bản gốc dạng mp3.
- Khối ngôi sao của leaderboard thành khối crystal (mục 7, mục 8 "Khối crystal"): cả thân khối vẽ chất liệu kẹo đường kết tinh theo ảnh ref `concept_candy_board_v3_crystal.png`, bỏ huy hiệu ngôi sao; va chạm, nghiền và búa ra mảnh crystal, mảnh kính và tiếng "ting". Icon mảnh `lb_piece` đổi từ ngôi sao `ic_star1` sang khối crystal xanh vẽ bằng AI (người dùng chọn vẽ AI theo ref thay vì vẽ bằng shader). Khi khối crystal rời bàn, icon crystal bật ra ở tâm khối rồi bay về chip đếm (người dùng chọn icon ở tâm khối thay vì bản thu nhỏ của khối ở thanh); số trên chip tăng lúc icon tới (người dùng chọn), nên thẻ thắng đợi icon đang bay. Thêm `sfx_crystal`, `sfx_crystal_get` (người dùng chọn tạo tiếng mới).
- Khối crystal rõ chất crystal hơn để không lẫn với khối thường (mục 8 "Khối crystal"): đổi ảnh ref sang `concept_candy_board_v4_crystal_semi.png`; bỏ sọc, lòng khối đậm và loang, mảnh vỡ với vết nứt trắng, viền đường cát dày lồi ra khỏi mép, vệt bóng lưỡi liềm ở góc trên trái thay cho vệt bóng của kẹo sọc. Icon mảnh `lb_piece` đổi từ khối vuông xanh một màu sang khối lập phương 3D màu loang bốn màu khối (người dùng yêu cầu dạng khối 3D, màu gradient loang, không một màu).
- Bỏ luật bàn cố định 14×19 ô, ô 42 px (mục 3). Màn level chạy ở 886×1920 nên ô 42 px chỉ cho khung chiếm 74% bề ngang, nhỏ hơn ảnh ref. Theo ảnh ref mới `art/concepts/ref_board_scale.png`, khung cố định theo màn (khoảng 90% bề ngang ở màn chuẩn, màn to thì to theo). Cỡ khối đổi theo hình của level, tối đa 80 px (cỡ khối trong ảnh ref). Lưới tối đa 14×18 ô. 100 level đóng gói chỉ dời hình vào giữa lưới 14×18, nội dung, `min_taps` và `moves` giữ nguyên. Bộ sinh giữ hình lớn nhất 12×17 nên level sinh với cùng seed không đổi.
- Màn level theo ảnh ref `ref_board_scale.png`: nâng hàng booster lên đúng vị trí trong ảnh (cách đáy 175 px ở 886×1920, trước là 36 px). Tên level, pill độ khó và chip mảnh trên thanh trên to thêm 1,25 lần. Chip lượt to thêm 1,25 rồi 1,3 lần (người dùng yêu cầu), thành 244×169. Chip mảnh đổi từ viên thuốc xanh đậm sang khung kẹo tím của chip lượt (mục 8). Thanh trên cao hơn nên khung bàn thấp hơn ảnh ref khoảng 45 px.
- Nhạc nền theo theme kẹo thay hai bài lo-fi cũ (mục 8, `docs/AUDIO_MUSIC.md`): `bgm_home` 100 BPM C major (marimba, pizzicato, ukulele), vòng lặp 67,2 giây, −18 LUFS; `bgm_level` 80 BPM F major (felt piano, pad), vòng lặp 84 giây, −20 LUFS, low shelf −5 dB ở 200 Hz để nghe rõ trên loa điện thoại. Vòng lặp cắt tròn ô nhịp ở phách mạnh. Trước đây chưa màn nào gọi `Sfx.music` nên game chưa phát nhạc; nay mọi màn ngoài màn chơi và loading phát `bgm_home`, màn chơi (kể cả trong Daily Challenge) phát `bgm_level`. Bài mới to dần 1 giây; đổi bài thì bài cũ nhỏ dần 0,5 giây trước (`CONTENT.music_fade_in_sec`, `music_fade_out_sec`). `tools/process_audio.py` nhánh `music` chuẩn theo LUFS thay cho RMS −21 dBFS, cắt vòng lặp theo tham số và bù độ trôi loudness.

**2026-11-05**

- Dư MOVES cố định theo bậc thay cho `max(2, 10% số khối)` và HARD dư 1 (mục 3): L1–3 là 5, L4–13 là 3, từ L14 level thường là 4, HARD và VeryHard là 3. Đo L51–100 trước khi đổi: level thường dư trung bình 6,5 nên gần như không bao giờ hết MOVES; HARD dư 1 trên khoảng 70 chạm, khối 1 ô chỉ 51 px, nên chạm nhầm hai lần là phải cứu. Level HARD giờ khó nhờ bàn (thêm khối, chuỗi chặn sâu hơn). Gold mỗi MOVES thừa 1 → 10 (`ECON.win_move_coins`). Game tính MOVES lúc vào level bằng `min_taps` trong file cộng dư hiện hành, nên Remote Config (`content_slack_*`) chỉnh được cả L1–100; trường `moves` của 100 file level ghi lại theo công thức mới, bàn giữ nguyên. Số dư cần chỉnh lại theo số lần chạm sai đo được ở bản demo và soft launch (`taps` của `level_end` trừ `min_taps`).
- Bỏ giới hạn hình dạng khối (mục 3, mục 4 "Hình dạng level"): khối là polyomino cỡ và hình bất kỳ. Bộ sinh bỏ trần 5 ô (`BLOCK_CAP`) và trọng số ưu tiên gộp mảnh nhỏ, thay bằng trọng số 1/cỡ khối sau gộp (người dùng chọn giữ số khối, cỡ hình và độ khó). Sinh lại L5–100 bằng lệnh phát hành, L1–4 làm tay không đổi. L5–13: khối 1 ô 23% → 40%, từ 6 ô 0 → 12%, lớn nhất 5 → 17 ô. L14–100 gần như cũ (khối 1 ô 68% → 71%, lớn nhất 5 → 10 ô) vì hình vẽ tay chỉ khoảng 1,5 ô mỗi khối; muốn khối to hơn từ L14 thì phải giảm số khối hoặc tăng cỡ hình. Thời gian sinh không tăng (500 level seed 0: chậm nhất khoảng 155 ms, bản cũ 173 ms).
- Thêm Road Trip (mục 7 "Road Trip", 2026-11-05): đường 400 level MoreColor của game gốc, tab phải của thanh dưới thay cho tab Ranking; Bảng xếp hạng thành icon ở cột trái Home. Người dùng chọn: bộ MoreColor (khớp tỉ lệ 310/68/22) thay cho bộ Colorful có khối 2 lớp; màu khối theo hướng như game (bỏ màu theo đoạn cạnh bàn); không tốn mạng, hồi sinh bằng video, thắng không gold, thưởng là 16 hộp; tạm dùng asset có sẵn (hộp quà, lục giác của Home), vẽ art riêng sau. Người dùng chọn xoay level nằm ngang, nhưng dữ liệu gốc đọc đúng trục (`x` là hàng) thì vốn đã dọc nên không xoay. Mở ở L2 (`Config.UNLOCK.road_trip`), không kéo về Home sau L1 để L1 → L2 liền mạch; hướng dẫn hiện lần đầu về Home. Khung bàn nhận lưới cao hơn 18 ô (level Road Trip cao tới 24).
- Màn Leaderboard dựng lại theo wireframe Leaderboard (mục 7 "Leaderboard theo league", 2026-11-05): banner ảnh kẹo có huy hiệu và tên giải, thanh hai tab chuyển xuống ngay trên thanh dưới, tab League có khung thưởng thăng hạng, tab World thành thẻ người chơi và thang 7 giải có chế độ xem thưởng. Người dùng chọn: tab World theo wireframe (thang giải thay danh sách top 50 và thẻ người chơi khi chạm hàng); giữ podium top 3 thay vì khối "Mới thăng hạng"; giữ hàng ghim và đếm ngược cùng nút "i"; bỏ thanh tiến độ tới league kế và nút PLAY; bỏ cờ quốc gia; banner tạo bằng ComfyUI, huy hiệu và icon dùng hình có sẵn. Không làm trạng thái tải và offline của wireframe vì BXH là bot trong máy.
- Nối logic popup đổi tên (mục 5 "Biệt danh", 2026-11-05): bút chì ở Profile có ở mọi bản, không còn chỉ ở bản xem trước; tên lưu ở `s.profile.name`. Người dùng chọn: tên chỉ hiện ở Profile (BXH vẫn ghi "Bạn"), bỏ lỗi "tên đã có người dùng" vì không có server (bỏ khoá `profile_name_taken`), danh sách từ cấm gồm 14 ngôn ngữ và tên dành riêng, đổi tên miễn phí không giới hạn (nút Buy của prefab giữ ẩn).
- Level Road Trip có interstitial (người dùng yêu cầu, 2026-11-05): `result_exit` khi đóng popup thắng Road Trip, cùng luật nhịp với thẻ thắng thường (`Game.road_trip_leave_win`); trước đó Road Trip không có interstitial.
- Road Trip đổi từ 4 màu theo hướng sang cổng màu (người dùng yêu cầu, 2026-11-05; mục 7 "Road Trip"): L1–200 có 8 cổng 8 màu, L201–400 có 12 cổng 12 màu, khối mang màu cổng nó thoát qua. Dữ liệu gốc chỉ có 8 cổng (L1–200 dùng 4 màu, L201–400 dùng 8 màu); người dùng chọn số 8/12 của mình sau khi được báo. Thêm khoá `dir` của khối và `gates` của level (`LevelData`, `BoardState`), 8 màu kẹo mới, thanh khung chia tối đa 3 cổng (`frame_bar.gdshader`, `CandyFrame.set_segments`). Level chính không đổi.
