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
| Level sau khác gì | Thêm màu (2 → 4 trong 4 level đầu), nhiều khối hơn, chuỗi chặn sâu hơn, dư MOVES ít hơn so với số chạm cần, có level HARD xen kẽ theo đường cong độ khó. Từ L14 thêm 7 cơ chế (mục 4). |

## 2. Thông số đã có

- Tên game: **Candy Away**, dòng phụ "Tap Block Puzzle" (cả hai nằm trong logo `assets/ui/loading_logo.png`; chuỗi `APP_NAME`). Tên dự án, thư mục, package id `com.tungcv2.tapblockout` và plugin `tbo_platform` giữ tên cũ Tap Block Out vì đã gắn với cấu hình Horus.
- Mở game: màn loading (`splash`) với nền kẹo `assets/ui/loading_bg.png`, logo, thanh tải (icon chạy ở mép phần đã đầy là viên kẹo bạc hà xoắn đỏ trắng `candy_drop_00`) và số phiên bản, rồi vào thẳng level đang tới, không qua màn chuyển cảnh. Không bắt đầu được level thì vào Home: hết mạng (Chơi ở Home dẫn tới màn hết mạng) hoặc bản demo đã hết level. Thanh chạy tới 90% trong ít nhất 1,5 giây, đứng đó nếu khởi động chưa xong, rồi đầy trong 0,3 giây (`Config.CONTENT.splash_*`). Boot splash của Godot (lúc engine nạp) dùng cùng ảnh, chưa có thanh tải. Màn loading đặt nền và logo đúng khung Godot vẽ boot splash trên màn đó (theo `application/boot_splash/stretch_mode`, chỗ ảnh không phủ tô màu `boot_splash/bg_color`), nên lúc chuyển từ boot splash sang màn loading, nền và logo không phóng to, thu nhỏ hay xê dịch trên mọi tỉ lệ màn.
- Vào màn chơi từ Home bấm Chơi hoặc nạp mạng xong ở màn hết mạng: màn chuyển cảnh kẹo rơi `candy_curtain`. Mỗi lần một loại kẹo bóng chọn ngẫu nhiên trong 8 loại (`assets/ui/candy_drop/`), không trùng loại của lần trước. Từng viên rơi từ cao phía trên màn xuống như trọng lực (vào màn đã rơi nhanh), chạm chỗ có nảy dẹt nhẹ; hàng đáy chạm chỗ trước nên đống kẹo đầy dần từ dưới lên như đổ kẹo vào hũ, các hàng so le chồng lên nhau, viên chạm sau vẽ đè viên trước. Dưới đống kẹo có nền cùng tông đậm hơn của loại kẹo đó, từ đáy lên tới hàng cao nhất đang nằm yên, nên khe giữa các viên không lộ màn phía sau. Phủ kín thì màn chơi dựng bên dưới, giữ một lúc rồi cả đống rơi qua đáy màn như sàn mở ra (hàng dưới đi trước một chút, vừa rơi vừa xoay), màn chơi lộ dần từ trên xuống. Mỗi hàng 4 viên, viên to 1,6 lần khoảng cột (khoảng 354 px ở màn 886×1920), chừng 54 viên; cứ 0,025 giây một viên chạm chỗ, phủ kín chừng 1,9 giây, giữ 0,05 giây, rơi ra chừng 0,8 giây (`Config.CONTENT.candy_curtain_*`). Chạm và nút Back bị chặn suốt lúc chạy.
- Vào màn chơi từ màn Daily Challenge: màn chuyển cảnh `level_curtain` gồm hai cánh kẹo bóng. Cánh tím trượt từ phải vào nửa phải; khi nó gần tới nơi (60% thời gian trượt) cánh hồng trượt từ trái vào nửa trái, đè lên mép cánh tím. Cánh lao nhanh từ mép màn rồi giảm tốc dần khi tới giữa. Logo nhảy lên giữa màn, từ mờ nhoè và trong suốt tới rõ nét. Màn chơi dựng bên dưới, logo giữ một lúc rồi mờ đi, hai cánh trượt ra hai bên. Mỗi cánh trượt vào 0,45 giây, logo bật 0,4 giây, giữ 0,35 giây (`Config.CONTENT.curtain_*`). Màu theo ảnh mẫu: hồng `#fbd3df` → `#f6a9cf`, tím `#e0c1f0` → `#c9abf1`. Chạm và nút Back bị chặn suốt lúc chạy. Qua level kế trong màn chơi không có màn này.
- Road Trip vào level và về bản đồ: màn chuyển cảnh nắp hộp quà `gift_curtain`. Một hộp quà khổng lồ nhìn chính diện phủ kín màn: thân hộp tím lavender chấm bi trượt từ dưới lên (giảm tốc dần), khi nó đi được 30% quãng đường thì nắp hồng có mép nắp dày và nơ satin trắng ánh hồng rơi từ trên xuống (nhanh dần), chạm thân thì nắp nhún xuống một chút, nơ bẹp rồi nảy lại. Ruy băng trắng ánh hồng chạy dọc giữa nắp và thân, nơ nằm trên mép nắp, đè lên mép nối. Logo nằm trên mặt nắp, phía trên nơ, rơi theo nắp; khi nắp rơi được 50% quãng đường thì logo nhảy lên, từ mờ nhoè tới rõ nét như màn hai cánh. Màn dựng bên dưới, logo rõ hẳn thì giữ một lúc rồi mờ đi, nắp nhấc lên khỏi mép trên, thân rơi khỏi mép dưới. Thân trượt 0,45 giây, nắp rơi 0,32 giây, nhún 0,18 giây, mở 0,3 giây (`Config.CONTENT.gift_*`); logo bật 0,4 giây, giữ 0,35 giây (`curtain_logo_sec`, `curtain_hold_sec`). Hộp phủ kín màn ở mọi tỉ lệ (cắt hai bên hoặc trên dưới, giữ giữa). Màu hồng tím pastel của màn hai cánh. Chạm và nút Back bị chặn suốt lúc chạy.
- Chạm màn hình (2026-11-05, làm nhẹ lại cùng ngày): mỗi lần chạm, ở bất kỳ màn hay popup nào (cả lúc màn chuyển cảnh chạy), một vòng tròn trắng ánh hồng dày 4 px, đậm nhất (55%) ở giữa nét và mờ dần về trong suốt ở viền trong lẫn viền ngoài, nở ra tới bán kính 25 px rồi mờ dần, và 5 sao nhỏ 5 cánh màu pastel (vàng, hồng, tím; cỡ 4 → 2 px, đậm 40%) toả ra chừng 40 px, vừa bay vừa xoay và nhỏ dần; tất cả tắt sau 0,4 giây (`Config.CONTENT.tap_fx_*`, px ở màn chuẩn 886×1920, `src/ui/tap_fx.gd`). Hiệu ứng chỉ để nhìn: không chặn chạm, chạm vẫn tác dụng như thường; chạm dồn dập giữ tối đa 8 hiệu ứng cùng lúc.
- Nút X đóng popup (2026-11-08): ở mọi popup, hình X to gấp đôi cỡ prefab, phóng quanh tâm nên vẫn nằm ở góc khung như cũ (X 64 px thành 128 px ở màn 886×1920). Vùng chạm rộng gấp 2,2 lần vùng chạm cũ (cũ là hình nới tới 96 px, nay khoảng 211 px). Nút X to ra mà lọt ra ngoài màn (popup gần rộng bằng màn như Need More Gold) thì dịch vào, cách mép màn 8 px (`Config.CLOSE_ART_SCALE`, `CLOSE_HIT_SCALE`, `CLOSE_EDGE_GAP`).
- Mục tiêu: game **thư giãn ASMR**, doanh thu **70% IAA, 30% IAP** (người dùng chọn 2026-11-09, trước là 50/50). Đo theo cohort 30 ngày đầu: doanh thu quảng cáo so với IAP sau phí store. Chưa có số liệu thật nên tỉ lệ này chỉ kiểm chứng được từ soft launch; mọi tần suất, giới hạn video và giá nằm trong config, chỉnh được bằng Remote Config.
- Hướng màn hình: **portrait**
- Nền tảng: **chỉ Android** ở bản hiện tại, iOS phát triển sau. Không có bản web.
- Offline, một người chơi. 14 ngôn ngữ (thứ tự như popup Language): `en`, `vi`, `pt_BR`, `tr`, `de`, `fr`, `id`, `es`, `ru`, `ko`, `ja`, `hi`, `uk`, `it`. Lần đầu theo ngôn ngữ của máy (cùng ngôn ngữ khác vùng vẫn khớp, ví dụ `pt_PT` ra `pt_BR`; không có thì `en`); chọn trong popup Language thì lưu cố định, popup không có ô "theo thiết bị". Tên ngôn ngữ trong popup viết bằng chính ngôn ngữ đó. Bản dịch 12 ngôn ngữ mới do Claude dịch, cần người bản xứ duyệt trước khi phát hành (kế hoạch mục 4).
- **Bản demo:** 20 level để duyệt game. **Bản phát hành đầu tiên:** L1–500.
- Game tham khảo: Tap Block Out: Color Puzzle (funsmith). Hôm nay trên Play: 4.7★, 4.11K đánh giá, 100K+ tải, cập nhật 26/10/2026, có sự kiện viền Halloween.
- Đánh giá của người chơi: thích chỉ chạm không cần kéo; chê quảng cáo sau mỗi level và quảng cáo ngay lúc mở game. Game của ta tránh cả hai.

## 3. Luật chơi

- **Khung bàn cố định theo màn, giữ tỉ lệ so với màn như ảnh ref `art/concepts/ref_board_scale.png`, màn chuẩn 886×1920** (`Config.BOARD_SCREEN`). Ở màn chuẩn, vùng trong khung là 724×982 px (`BOARD_AREA`) và trọn khung khoảng 803×1044 px, tức khoảng 90% bề ngang màn. Màn khác thì khung nhân theo min(rộng, cao) so với màn chuẩn, nên màn to thì bàn to theo. Đây là luật nền của game, mọi level và mọi theme phải giữ.
- Lưới level tối đa 14×18 ô (`Config.BOARD_W`, `BOARD_H`). **Cỡ khối đổi theo level**: lấy hình của level (khối và thùng sắt) cộng một ô lề mỗi phía, tối đa 14×18 ô, rồi chọn cỡ ô lớn nhất để hình đó vừa vùng trong khung. Ô to nhất 80 px ở màn chuẩn (`BOARD_CELL_MAX`), bằng cỡ khối trong ảnh ref. Hình càng nhiều khối thì càng lớn và ô càng nhỏ; hình cao 17 ô hoặc rộng 12 ô ra ô nhỏ nhất, 51 px. Cỡ ô là số nguyên px, giữ nguyên suốt level, kể cả khi khối rời bàn.
- Khung đứng cùng một chỗ và cùng một cỡ ở mọi level. Khung chỉ co khi vùng chơi của máy nhỏ hơn khung chuẩn. Hình nằm giữa vùng trong khung; khối thoát lao tới mặt trong của thanh cùng màu.
- Khối xếp thành một hình ở giữa bàn, không lát kín bàn và không cần kín khung của hình: khoảng trống quanh hình và trong hình là bình thường (mục 4). Ngoại lệ: bàn Màn đặc biệt là hình chữ nhật lát kín (mục 7 "Màn đặc biệt"). Khối là polyomino bất kỳ: các ô liền nhau theo 4 hướng, không giới hạn số ô hay hình dạng (mục 4, "Hình dạng level").
- Màu quyết định hướng: vàng lên, xanh lá trái, xanh dương phải, tím xuống. Mỗi cạnh khung là một cổng liền, không có cổng rời.
- Chạm khối, đường thông: khối lao nhanh dần tới thanh cùng màu (tối đa 0,35 s, rồi chậm dần 0,3 s), vỡ thành mảnh kẹo bay xuyên qua thanh, MOVES giảm 1.
- Chạm khối, đường bị chặn: khối lao tới vật cản, nhún khi va chạm rồi bật về chỗ cũ, khối bị va nhún theo, MOVES giảm 1. Bàn cờ không đổi nên không có thế bí.
- `MOVES = số chạm tối thiểu do solver tính + dư`. Dư cố định theo bậc, không theo số khối: L1–3 là 5; L4–13 là 3; từ L14 level thường là 4; level HARD và VeryHard là 3 (`Config.CONTENT.slack_*`). Level HARD khó nhờ bàn (thêm khối, chuỗi chặn sâu hơn), không nhờ dư ít. Game cộng dư lúc vào level từ `min_taps` trong file, nên Remote Config đổi được dư mà không phải sinh lại level; `moves` trong file là giá trị theo số mặc định.
- Nghĩ quá lâu rồi đi đúng (mặc định từ 8 giây): tiếng vỗ tay và lời khen (`level_clap`, "Hay lắm!"; 2026-11-08, `src/ui/praise_fx.gd`). Chữ nằm giữa hàng trên của HUD và khung, đáy chữ cách mép trên khung `BOARD_CAPTION_GAP`, không bao giờ đè khung; chỗ hẹp thì chữ co lại. Chữ vàng chuyển cam, viền tím đậm, bật từ đáy lên to 130% rồi nảy về, nghiêng nhẹ, loé trắng, có vệt sáng quét qua và sao lấp lánh trên chữ, thở nhẹ rồi bay lên và mờ đi; tổng 1,6 giây. Sau chữ có hào quang vàng, tia nắng xoay và một vòng sóng; lớp này nằm sau bàn nên khung che phần dưới. Sao kẹo nhiều màu và confetti bung ra trước bàn rồi rơi. Dòng hướng dẫn trên khung mờ đi trong lúc khen. Hiệu ứng không chặn chạm.
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
2. Bấm Bỏ cuộc: từ L10 hiện popup xác nhận "Bỏ cuộc sẽ mất 1 mạng" (`popup_keep_playing`, wireframe 4.6). Xác nhận thì thua; Chơi tiếp thì quay lại popup. Dưới L10 thua ngay vì không mất mạng. Lượt Win Streak đang đếm mà chuỗi sẽ tụt (mục 7 "Win Streak") thì dùng popup "Giữ chuỗi nhé?" (`popup_streak_keep`, 9.5) thay cho popup này, có báo thêm khi cũng mất mạng; khi đó dưới L10 hay đang có mạng vô hạn vẫn hỏi.
3. Mua hoặc xem video xong, hết MOVES lần nữa thì sang lần kế (giá kế tiếp). Quá 4 lần là thua luôn, không hiện popup.
4. Chơi lại thì giá về lần 1.

Mọi số (giá từng lần, số lần, số MOVES, số lần có video) nằm trong `Config.ECON` (`rescue_prices`, `rescue_moves`, `rescue_video_max`), Remote Config ghi đè được. Số lần tối đa bằng độ dài mảng `rescue_prices`.

Luật chung:

- Chỉ bán +3 Move: lúc 0 MOVES thì Gợi ý vô dụng, còn Phá khối chỉ thắng được khi còn đúng 1 khối, lúc đó +3 Move rẻ hơn.
- Popup hiện "Còn N khối". Không chặn nút khi N > 3, vì người chơi vẫn có thể mua nhiều lần.
- Thiếu gold: popup vẫn hiện; bấm mua thì mở shop mini tại chỗ, đóng shop thì quay lại popup. Quy tắc không popup offer trong 5 phút đầu phiên đầu (mục 7) không áp dụng cho popup này.
- Helper Pack (2026-11-09, wireframe 4.7, `popup_helper_pack`): lần hết MOVES đầu của ván, nếu đây là lần hết MOVES thứ 3 liên tiếp ở level đó (`Config.ECON.helper_pack_fail`, đếm theo `s.fail_streak`) và kho hết +3 Move, popup cứu lượt có thêm dải gói Helper Pack ở đáy màn. Nút miễn phí (video) và nút gold như popup thường; mua gói (`helper_great`, mục 7) thì +3 Move của gói dùng ngay cho lần cứu này, phần còn lại vào kho. Các lần hết MOVES sau trong cùng ván dùng popup thường.

### Mạng

- L1–9: chơi lại miễn phí, không mất mạng. Từ L10: thua mất 1 mạng.
- Tối đa 10 mạng, 5 phút hồi 1 mạng (đang đầy thì không tích thêm).
- Hết mạng: màn chờ đếm ngược, hoặc 900 gold = 5 tim, hoặc xem rewarded = 1 tim. Không có quảng cáo thì báo và cho chờ, không treo. Không bán tim trực tiếp bằng IAP.
- Nút restart từ L10 tốn 1 mạng nếu đã chạm ít nhất một lần trong level, có hỏi xác nhận trước; nếu không, restart sẽ là cách né mất mạng.
- Mỗi lần mua hàng hay xem quảng cáo xong, mạng lưu ngay như gold.

### Tiêu chí thư giãn

- Không timer, không đồng hồ đếm ngược trong level và popup. Màn hết mạng và offer vẫn có đếm ngược vì nằm ngoài level và không phải popup thua.
- **Ngoại lệ duy nhất: Màn đặc biệt** (mục 7 "Màn đặc biệt", 2026-11-09): bom có đồng hồ đếm ngược, và bom nổ thì rung bàn và rung máy (theo công tắc rung). Level thường, Road Trip, Daily Challenge giữ nguyên các luật ở mục này.
- Không có màn đỏ hay rung mạnh khi thua. Va chạm dùng rung nhẹ, có thể tắt.
- Mỗi chất liệu khối có âm thanh riêng.
- Không quảng cáo hay popup bán hàng khi mở game, và không chen giữa level.
- Số mạng và level HARD giữ nguyên.

## 4. Level

### Đường cong độ khó L1–500

Từ 2026-11-08, 500 level thường bám game tham khảo Tap Block Out 2.2.1, đo trên bản giải nén APK: số khối và số lượt dọn bàn của từng level L1–500, cùng tag Hard và Super Hard (ở đây gọi là VeryHard). Số đo nạp vào `src/core/difficulty_curve.gd` (`REF_BLOCKS`, `REF_WAVES`, `HARD`, `VERY_HARD`). Lượt dọn bàn: mỗi lượt chạm mọi khối đang đi được (thoát, bóc hộp giấy, dội cổng nhịp khoá; khối còn pudding hay băng chờ khối kề rời đi), lặp tới khi hết bàn (`Solver.clear_rounds`). Trên bàn không có cơ chế, số lượt bằng độ sâu chuỗi chặn.

- **Tag:** giữ đúng level của game tham khảo, gồm 149 Hard và 69 VeryHard trong L1–500. Riêng tag Hard ở L70 (level dạy Sương mù) dời sang L71, hai level đổi số đo cho nhau. Level dạy và L1–4 không mang tag. Level Hard đầu tiên là L23, VeryHard đầu tiên là L33. Huy hiệu và hộp thoại "rất khó" hiện cho level VeryHard; từ L501 (vòng lặp) mọi level HARD cũng hiện "rất khó" (`CONTENT.very_hard_from_level`).
- **Tag khớp đường cong:** level Hard có số khối và số lượt ít nhất 1,15 lần trung vị các level thường trong 3 level hai bên, VeryHard ít nhất 1,3 lần (`PEAK_*`), tính sau khi kẹp nên vẫn đúng ở level bị trần cắt (trừ khi chính level đó chạm trần). Số đo gốc đã thoả gần hết; số nào chưa đủ thì đường cong nâng lên.
- **Số khối mục tiêu** (`block_count`): L1–4 làm tay 4, 6, 8, 10 khối. Từ L5 lấy số đo, kẹp trong 12–60 khối (`MOTIF_MIN_BLOCKS`, `BLOCK_CAP`). Hình vẽ tay nhỏ nhất có 36 ô nên dưới 12 khối không có hình vừa. Trên 60 khối chỉ còn 6–8 hình vừa nên level to lặp hình. Game tham khảo có 125 level trên 60 khối (tới 112 khối); các level đó bị cắt xuống 60.
- **Số lượt mục tiêu** (`wave_count`): lấy số đo. Level bị cắt số khối thì số lượt giảm theo cùng tỉ lệ. Tối đa 0,55 lượt mỗi khối (`WAVE_SHARE_MAX`), vì hình 12×17 hiếm khi có chuỗi sâu hơn.
- **Bộ sinh:** lúc gán hướng, bộ sinh ưu tiên cách gán làm khối nằm sâu hơn trong chuỗi chặn khi chuỗi còn nông hơn mục tiêu, và giữ lại khi đã đủ sâu. Sau khi rải cơ chế, bộ sinh đo số lượt. Lệch quá max(1, 10%) mục tiêu thì gán lại; vẫn lệch thì cắt lại hoặc sinh lại, và khoảng lệch cho phép nới dần theo số lần thử (`Config.LEVEL_ROUNDS_TOL*`). Daily Challenge sinh ngay trong game nên chỉ gán lại 3 lần trong cùng một hình rồi giữ bàn gần mục tiêu nhất; mỗi bàn trung bình 32 ms, chậm nhất khoảng 140 ms trên máy dev.
- **Đo trên 500 level đóng gói:** số khối lệch đường cong tối đa 2 ở mọi level. Số lượt có 480/496 level (L5–500) trong khoảng lệch, mọi level trong 25%. So với game tham khảo, tính trên L21–500:

| Tag | Số level | Khối (Candy / tham khảo) | Lượt dọn bàn (Candy / tham khảo) |
| --- | --- | --- | --- |
| Thường | 262 | 40,6 / 40,6 | 16,0 / 16,4 |
| Hard | 149 | 54,7 / 57,4 | 27,5 / 31,1 |
| VeryHard | 69 | 59,2 / 77,7 | 29,3 / 42,1 |

  VeryHard thấp hơn game tham khảo vì bị trần 60 khối. Cả 500 level trung bình 46,2 khối và 20,8 lượt, game tham khảo là 49,6 và 23,9. Khối thoát được ngay lúc đầu trung bình 7,3, game tham khảo 8,8.
- **Dư MOVES:** giữ như mục 3 (Hard và VeryHard 3, level thường 4).

Bản trước (L1–100, tới 2026-11-08): điểm độ khó lấy từ file `difficulty_curve_levels_1-100.json` của PixelFlow, nội suy thành 2–30 khối, Hard +2 và VeryHard +3; từ L14 nhân 1,3 (trần 40) rồi nhân 1,5, L1–13 nhân 2. Có 26 level Hard và VeryHard, trung bình L14–100 khoảng 45 khối.

Bốn level đầu làm tay trong `tools/gen_levels.gd` (bảng EARLY). L1–3 chắc chắn thắng: dư 5 MOVES, L1–2 không khối nào bị chặn, L3 chỉ một khối phải chờ; L4 cũng chỉ một khối phải chờ.

Mọi level thắng đều +40 gold, cộng thêm 10 gold cho mỗi MOVES còn thừa lúc thắng (mục 5).

| Level | Màu | Khối | Ghi chú |
| --- | --- | --- | --- |
| 1 | 2 màu (vàng, xanh dương) | 4 | Chữ "Tap the block" |
| 2 | 3 màu | 6 | Không khối bị chặn |
| 3 | 3 màu | 8 | Một khối phải chờ |
| 4 | Đủ 4 màu | 10 | Một khối phải chờ |
| 5–13 | 4 màu | 12–15 | Gợi ý mở ở L5, Rate us ở L10, +3 Move mở ở L12; từ đây khối xếp thành hình vẽ tay |
| 14 | 4 màu | 13 | Level dạy Thùng sắt |
| 15–29 | 4 màu | 15–43 | Phá khối mở ở L17; L23 là level HARD đầu tiên (L26, L29 tiếp theo) |

### Hình dạng level

Lưới luôn 14×18 ô và khung không đổi (mục 3). Số khối quyết định hình to hay nhỏ, từ đó quyết định cỡ ô trên màn. Hình lớn nhất của bộ sinh là 12×17 ô. Vì ngoài hình là ô trống, dịch cả hình đi không đổi đường thoát của khối.

| Nguồn | Hình |
| --- | --- |
| Từ L5 và Daily Challenge (`src/core/motifs.gd`) | 27 hình vẽ tay, mỗi hình 4–6 cỡ từ 36 tới 182 ô. Hình cơ bản: mũi tên (lên, xuống, trái, phải), tim, ngôi sao, chữ thập, chữ X, thoi, đồng hồ cát. Theme kẹo: kẹo bọc giấy, kẹo mút, cupcake, kem ốc quế, donut, thanh sô-cô-la, hộp quà, hũ kẹo, bánh kem, kem que, macaron. Hình khác: hoa, cỏ bốn lá, bướm, cây thông, nhà, vương miện, nấm, tên lửa |
| L1–4 | Làm tay (bảng EARLY), dịch vào giữa bàn |
| Level dạy cơ chế (14, 30, 40, 55, 70, 90, 110, 130) | Sinh to như level thường theo hình vẽ tay, chỉ bật đúng cơ chế mới. Bộ sinh chỉ nhận level cho chạm thử cơ chế ngay lúc đầu: Thùng sắt có ít nhất 2 ô; Pudding và Băng chỉ có lớp phủ 1 lớp, và có khối phủ kề một khối thoát được ngay; Xích có khối bị xích mà chìa thoát được ngay; Hộp giấy có hộp đẩy ra được; Sương mù có khối ẩn màu; Cổng nhịp khoá lúc đầu và có khối cùng màu dội vào được ngay; Ruy băng có khối ruy băng bóc được ngay và một khối 3–4 lớp |

- Hình vẽ tay (từ L5; trước 2026-11-08 từ L14, còn L5–13 dùng 9 dạng sinh ngẫu nhiên có khoét rìa trong `src/core/silhouette.gd`): mỗi bản vẽ rộng chẵn để nằm đúng giữa bàn 14 cột, tối đa 12×17, đối xứng trái phải hoặc trên dưới (chữ thập, chữ X, đồng hồ cát, kẹo bọc, donut và các cỡ nhỏ của thoi, hoa, cỏ bốn lá đối xứng cả bốn góc; cỡ lớn của thoi, hoa, cỏ bốn lá có thêm cuống hoặc mũi nhọn nên chỉ đối xứng trái phải). Không khoét rìa. Chọn cỡ có số ô (trừ thùng sắt) chia số khối trong 2,5–3,4 (`Config.MOTIF_FILL_MIN`, `MOTIF_FILL_MAX`), tức khoảng 3 ô mỗi khối như Road Trip (trước 2026-11-08 là 1,15–1,8). Level nhiều khối dùng cỡ gần kín khung 12×17 (tới khoảng 90% ô) nên nhận ra hình qua đường viền và vùng vẽ. Mỗi số khối 12–59 có ít nhất 12 hình vừa, 60 khối có 16 hình (61–64 khối chỉ còn 6–8 hình, nên đường cong dừng ở 60). Level liền nhau đi cách nhau 8 bước trong danh sách hình nên ra hình khác nhóm.
- Vùng vẽ: mỗi ô của bản vẽ ghi tên vùng bằng một chữ cái. Vùng là phần người vẽ muốn tô khác nhau: dải, vòng, cánh hoa, giấy gói, kem phủ, ô sô-cô-la. Vùng đối xứng theo trục của hình (cùng tên hoặc một cặp tên lật cho nhau), mỗi mảnh vùng ít nhất 2 ô.
- Cắt khối (mọi level sinh): bộ sinh gộp dần các ô đơn thành khối, mỗi khối tối đa 7 ô (`Config.BLOCK_MAX_CELLS`, từ 2026-11-08; trước 2026-11-05 tối đa 5 ô, giữa hai mốc không giới hạn). Mỗi cách gộp có trọng số 1,5 mũ số khối 1 ô được gộp (0, 1 hoặc 2), chia cho bình phương cỡ khối sau gộp (`Config.TILE_SINGLE_BIAS` = 1,5; trước bản 500 level là 5). Khối 1 ô vẫn được gộp trước nhưng ít hơn bản trước, nên tỉ lệ khối 1 ô tăng từ khoảng 5% lên khoảng 11% (game tham khảo khoảng 31%); khối 6–7 ô vẫn hiếm. Hình c ô cắt thành n khối thì ít nhất 2n − c khối chỉ có 1 ô; với khoảng 3 ô mỗi khối thì không có khối 1 ô bắt buộc. Đo trên L1–500 đóng gói: L5–13 khối 1 ô 9%, 2 ô 39%, 3 ô 12%, 4 ô 23%, 5–7 ô 17%; L14–500 khối 1 ô 11%, 2 ô 40%, 3 ô 20%, 4 ô 21%, 5–7 ô 8%, lớn nhất 7 ô.
- Kiểu cắt khối (từ L5, `LevelGenerator.cut_style`), xen kẽ theo level: id chia 3 dư 0 là đối xứng tự do (gộp ngẫu nhiên trong nửa hình rồi lật); dư 1 là hình học, lần lượt dải ngang, vòng theo viền hình, đan rổ (ô 4×4, dải ngang và dải dọc xen kẽ), dải dọc, gạch xây so le dài 4; dư 2 là theo vùng vẽ (khối không vượt ranh vùng). Khi kiểu hình học hoặc vùng vẽ hết cách gộp mà số khối còn nhiều hơn đường cong thì gộp tự do vài khối cuối; trong các hình to nhất, ít nhất 90% khối đúng quy luật của kiểu.
- Cắt khối đối xứng (từ L5): thùng sắt và cách cắt khối đối xứng theo trục của hình (lát nửa hình hoặc một phần tư rồi lật ra; khối chạm trục có thể vắt qua trục thành một khối đối xứng). Màu (hướng) vẫn gán tự do theo ván mô phỏng, nên màu không đối xứng. Số khối có thể lệch tối đa 2 so với đường cong vì mỗi lần gộp đối xứng bớt 1, 2 hoặc 4 khối.
- Sương mù: chỉ khối kề rời đi (thoát hoặc bị phá) mới làm lộ, ô trống sẵn quanh hình không tính. Nhờ vậy mọi khối sương mù đều ẩn lúc đầu, kể cả ở rìa hình. Khối còn ẩn không đi được (mục 4), nên rải sương ngẫu nhiên có thể làm bàn kẹt: khối thường chờ khối sương đi, khối sương chờ khối kề rời đi. Bộ sinh (`LevelGenerator._unstick`) đi thử như Solver, mỗi lần kẹt thì bỏ sương ở khối ẩn đầu tiên (theo thứ tự khối) mà lộ ra là đi được, tới khi dọn hết bàn. Sương mù cũng tính vào số lượt dọn bàn như pudding, xích, hộp giấy.
- Pudding và băng (2026-11-09): khối phủ cũng chờ khối kề rời đi nên có thể làm bàn kẹt như sương mù. `_unstick` xử lý cả hai: kẹt mà không có khối sương nào lộ ra là đi được thì bóc 1 lớp ở khối phủ đầu tiên (theo thứ tự khối) mà hết phủ là đi được, lặp tới khi dọn hết bàn. Khối phủ không chung khối với sương mù, xích, hộp giấy, và không phải khối đầu tiên trong thứ tự giải. Số khối phủ tăng từ 10% lên 28% số khối trong 60 level kể từ mốc mở (`Config.COVER_SHARE_*`). Từ 10 level sau mốc mở (`COVER_DOUBLE_AFTER`; pudding từ L40, băng từ L120), tỉ lệ khối 2 lớp trong các khối phủ tăng từ 20% lên 50% trong 60 level (`COVER_DOUBLE_*`); chỉ khối kề ít nhất 2 khối khác mới được 2 lớp.
- Ruy băng (2026-11-09, `LevelGenerator._ribbons`): lớp ngoài là màu gán của khối lúc mô phỏng, mỗi lớp sau (gồm kẹo) rút trong các màu thoát được lúc khối đó đi, khác màu lớp ngay trước; các hướng đó vẫn thông về sau vì chỉ có khối rời bàn, nên bóc hết ruy băng rồi thoát ở lượt của khối vẫn giải được. Chỉ khối chưa có cơ chế khác, từ 2 ô, có ít nhất 2 màu thoát và không phải khối đầu tiên trong thứ tự giải. Level thường: tối đa min(5, 1 + (id − 130) / 15) khối ruy băng (`RIBBON_COUNT_*`), mỗi khối 1 tới min(4, 2 + (id − 130) / 30) lớp (`RIBBON_LAYERS_*`), tức tối đa 2 lớp tới L159, 3 lớp tới L189, 4 lớp từ L190, và theo cỡ khối. Level dạy L130: 3–5 khối 1–2 lớp đi sớm nhất (`RIBBON_TEACH_SMALL*`) cộng một khối từ 3 ô đi muộn nhất mang 3–4 lớp (`RIBBON_TEACH_BIG`). Mỗi lớp qua cổng nhịp tính một lần qua khi chọn cạnh đặt cổng. Level đóng gói chưa có ruy băng cho tới đợt sinh lại chung.

### Cơ chế sau bản demo

Nguyên tắc: cơ chế chỉ làm bàn cờ dễ hơn theo thời gian hoặc lặp lại theo chu kỳ, không có nước đi nào khiến level không thể thắng. Không timer. Solver phải chứng minh được từng level. Vì vậy không dùng đổi màu ngẫu nhiên hay khối mọc thêm.

Mỗi cơ chế có một level dạy (chỉ cơ chế đó, xem "Hình dạng level") và một âm thanh riêng. Sau L130 chỉ phối hợp các cơ chế đã có. Pudding và băng cùng luật nhưng không bao giờ cùng một level: khi rút cơ chế cho level, `mech_plan` chỉ giữ loại đứng trước trong thứ tự rút (từ L110 tới L119 băng luôn có mặt nên không có pudding). Mốc level theo `Config.UNLOCK` (bảng "Mở khoá theo level").

Cơ chế trên từng level (2026-11-08, `LevelGenerator.mech_plan`, chỉ theo id): mỗi level tối đa 3 loại (`Config.LEVEL_MECH_MAX`). Từ L15, cứ 4 level có một level nghỉ không có cơ chế nào (id chia 4 dư 3, `LEVEL_REST_EVERY`, `LEVEL_REST_AT`; level dạy vẫn giữ cơ chế của nó), nên các level sau vẫn xen kẽ level không cơ chế. Level khác rút 1, 2 hoặc 3 loại trong các cơ chế đã mở, xác suất 35%, 40%, 25% (`LEVEL_MECH_WEIGHTS`). Trong 10 level sau level dạy (`LEVEL_MECH_FRESH`), cơ chế vừa mở luôn có mặt ở mọi level không nghỉ. Cổng nhịp chỉ vào bàn có số khối mục tiêu tới 52 (`GATE_MAX_BLOCKS`); từ L130 bàn tới 40 khối có 2 cổng. Cổng đặt ở cạnh có ít lần qua nhất (khối theo màu, hộp giấy tính cả màu vỏ lẫn màu trong), vì mỗi lần qua cổng khoá tốn một cú dội; lúc đầu cổng mở hay khoá ngẫu nhiên (level dạy luôn khoá), và bàn phải có khối thoát được ngay (cú dội không tính). Đo trên L15–500 (bộ level đóng gói ngày 2026-11-08, trước khi có băng): 121 level không cơ chế, 133 level 1 loại, 124 level 2 loại, 108 level 3 loại. Thùng sắt có ở 139 level, pudding 142, xích 135, hộp giấy 124, sương mù 120, cổng nhịp 46. Bộ sinh mới (có băng) trên L5–504: pudding 106 level, băng 84; level đóng gói chưa sinh lại (xem "Pudding và băng" dưới bảng). Trước bản này, cơ chế bật theo xác suất 70% mỗi loại nên từ L76 nhiều level có 5–6 loại.

Giới thiệu cơ chế mới (2026-11-08): lần đầu vào level dạy của level chính, trước khi chơi hiện popup cùng khung với quà booster (`scenes/booster_unlocked.tscn`, wireframe 3.8): tiêu đề "VẬT CẢN MỚI!" (`mech_new_title`; không dùng "CƠ CHẾ MỚI!" vì chữ "Ơ" hoa chưa có trong font con `mplus_rounded`, muốn đổi thì chạy lại `tools/node/subset_fonts.mjs` và `tools/gen_baloo_font.gd`), tên và icon cơ chế (`mech_<tên>`) giữa tia sáng quay, luật (`mech_<tên>_desc`) ở chỗ số lượng, dòng "Chạm để tiếp tục". Không tặng gì, không có số lượng, không có nút. Chạm đâu hoặc Back thì vào chơi. Mỗi cơ chế chỉ hiện một lần (bản lưu `mech_seen`, ghi ngay khi mở): thua chơi lại không hiện nữa; dòng "Tên: luật" ở đầu level vẫn hiện mọi lượt, trong bong bóng kem viền cam (cùng kiểu bong bóng gợi ý khối của màn level) giữa khung, đáy cách thanh trên của khung `Config.BOARD_CAPTION_GAP` px. Dòng ngắn thì bong bóng ôm chữ, dài hơn khung thì xuống dòng trong bong bóng rộng bằng khung và mọc lên trên, không đè khung; không có chữ thì ẩn bong bóng (dòng "chạm khối để đập" của booster búa cùng chỗ, cùng bong bóng). Có quà booster cùng level thì quà hiện trước. Daily Challenge và Road Trip không có popup này. Cổng nhịp chưa có ảnh riêng nên icon là placeholder.

Theme kẹo (2026-11-03) đổi hình ba vật cản, luật giữ nguyên; ngày 2026-11-04 khối gỗ đổi tiếp thành thùng sắt. Tên trong dữ liệu và code vẫn là `stone`, `ice`, `chained_by`, `inner_color`. Băng (2026-11-09) có khoá cơ chế `frost`; level băng ghi `"cover": "frost"`, số lớp phủ của khối vẫn ở `ice` (0–2) như pudding. Ruy băng (2026-11-09) có khoá cơ chế `ribbon`; khối ghi `"ribbons": [màu ngoài, …]` (chỉ khối có ruy băng), `color` là màu kẹo trong cùng.

| Từ level | Cơ chế | Luật | Hình | Âm thanh |
| --- | --- | --- | --- | --- |
| 14 | Thùng sắt (`stone`) | Vật cản cố định, không trượt | Thùng sắt nhìn từ trên: nắp thép xanh xám, viền nổi, bốn đinh tán bạc to ở bốn góc nắp, đọc rõ ở ô 42 px (`mech_stone`) | Tiếng keng thùng sắt rỗng, ngắn 0,5 giây |
| 30 | Pudding (`ice`) | Khối phủ 1 hoặc 2 lớp pudding. Còn phủ thì chạm vào không đi: nhún dẹt rồi rung như thạch tại chỗ, không tốn MOVES, không tính là nước đi. Mỗi khối kề (chung cạnh) rời bàn, tức thoát qua thanh hoặc bị Phá, bóc 1 lớp; một khối kề nhiều ô vẫn chỉ bóc 1 lớp. Bóc vỏ hộp giấy, bị chặn rồi bật về, dội cổng, va vào khối phủ không bóc; ô trống sẵn quanh hình không tính. Lớp vỡ trên màn lúc khối kề chạm thanh (hoặc lúc búa gõ khối kề); tới lúc đó khối vẫn tính là còn phủ, chạm vào chỉ nhún. Không còn cú chạm làm nứt nên lớp phủ không tốn MOVES (2026-11-09; trước đó cần 2 lần chạm, lần đầu làm vỡ lớp pudding) | 1 lớp: lớp pudding hồng gần trong suốt phủ trọn khối kẹo, tràn ra ngoài mép 0,1 ô, viền đậm hơn, bọt khí nhỏ, vệt sáng quét chéo mỗi 3,2 giây. 2 lớp: tràn 0,16 ô, hồng đậm và đục hơn, thêm một viền trong ở mép lớp 1; không ghi số | Thạch bung "bộp" mềm (`sfx_pudding`); bóc lớp ngoài của khối 2 lớp phát nhỏ hơn 6 dB |
| 40 | Xích và chìa | Khối bị xích chỉ đi được khi khối chìa đã thoát | Xích thép mảnh chạy một đường chéo nằm gọn trong thân khối: hai đầu lùi vào 0,24 ô từ mép khung, không chìa ra ngoài hay đè sang khối bên cạnh, hai đầu là mắt tròn; mắt xích tròn dài 0,21 ô, cách nhau 0,15 ô; khối hình L, T chọn đường chéo có nhiều mắt nằm trên ô của khối hơn và bỏ mắt nào chìa sang ô trống ở góc lõm. Ổ khoá vàng nằm trên đường xích ở giữa khối. Khối chìa mang ảnh chìa vàng to (`mech_key`, 0,8 ô) giữa một ô, không có đường nối tới khối bị xích | Xích rơi |
| 55 | Hộp giấy (`inner_color`) | Lớp ngoài thoát thì lộ lớp trong, màu khác | Hộp giấy bìa mờ nhuộm màu hướng đi của lớp ngoài (pha 26% kraft, vân sợi giấy ngắn, đốm xơ thưa), thành hộp lộ quanh nắp dày ở đáy với cạnh gấp sắc, viền sẫm cùng tông màu khối, băng dán chữ thập qua tâm hộp đè qua cạnh xuống thành hộp (2026-11-09); kẹo bên trong bị che kín | Bóc lớp |
| 70 | Sương mù | Không thấy màu cho tới khi một khối kề rời đi. Khối còn trong sương (kể cả hộp giấy) chạm vào không đi: chỉ lắc ngang tại chỗ, không tốn MOVES, không tính là nước đi (2026-11-08; trước đó khối ẩn vẫn trượt theo màu thật). Pudding, xích trên khối ẩn cũng chờ khối lộ ra mới phản ứng | Kẹo xám dưới một lớp sương trắng ánh tím phủ chồng lên, loang dày mỏng và trôi chậm; viền sương mờ dần, lấn ra ngoài mép khối tới 0,24 ô nên phủ nhẹ mép khối bên cạnh; các khối sương kề nhau chung một đám sương; ảnh đám mây `mech_fog` giữa một ô | Gió nhẹ |
| 90 | Cổng nhịp | Cổng chỉ đổi khi khối cùng màu chạm tới thanh: dội vào cổng khoá thì cổng mở (cú dội tốn 1 MOVES, đã tính trong MOVES của level), một khối qua cổng (kể cả hộp giấy) thì cổng khoá lại. Khối màu khác, khối bị chặn giữa đường, nứt pudding, giật xích không đổi cổng; bàn 2 cổng thì hai cổng độc lập | Thanh cổng đóng phủ sọc kẹo gậy trắng chéo, huy hiệu ổ khoá thay mũi tên (mục 8 "Khung cổng"); vẽ bằng shader, không có ảnh | Cổng cơ khí |
| 110 | Băng (`frost`) | Như pudding (1 hoặc 2 lớp, khối kề rời bàn thì bóc 1 lớp); chạm khối còn phủ thì lắc ngang tại chỗ như khối sương mù. Không cùng level với pudding | Băng trong trắng xanh phủ trọn khối kẹo, tràn ra ngoài mép 0,1 ô, viền đóng sương trắng loang, mảnh băng xanh lệch nhau với vết nứt trắng mảnh, vệt sáng lạnh quét chéo mỗi 2,6 giây, hạt sương lấp lánh. 2 lớp: tràn 0,16 ô, đục hơn, sương viền dày hơn, nhiều vết nứt hơn. Icon `mech_frost` | Băng nứt (`sfx_ice`) |
| 130 | Ruy băng (`ribbons`) | Như hộp giấy nhiều lớp (2026-11-09): khối quấn 1–4 lớp ruy băng (`Config.RIBBON_MAX_LAYERS`) ngoài viên kẹo, mỗi lớp một màu là hướng đi, lớp nào cũng khác màu lớp ngay trong nó (kẹo tính là lớp trong cùng). Chạm khi đường thông thì ruy băng ngoài cùng bay về thanh cùng màu (tốn 1 MOVES, đã tính trong MOVES của level), khối ở lại và lộ lớp kế; hết ruy băng thì kẹo thoát như khối thường. Màu các lớp trong bị ẩn. Khối 1 ô không có ruy băng, khối 2 ô tối đa 2 lớp (`RIBBON_CELL_CAP`). Không chung khối với pudding, băng, xích, hộp giấy; sương mù phủ lên được (còn trong sương thì chạm không đi). Ruy băng qua cổng nhịp mở thì khoá cổng như hộp giấy | Satin cùng màu khối quấn chéo (theo x + y), số dải bằng số lớp còn lại, các dải rộng phủ gần kín khối và cách nhau bằng khe tối mảnh (kẹo lộ ở khe nằm trong bóng ruy băng), nên số lớp đọc qua số khe; nơ satin to 1,3 ô (`ribbon_bow`, xám) giữa khối, tô theo bốn tông của khối: nếp gấp tông đáy, thân màu mặt khối, vệt bóng sáng, có viền tối và bóng đổ nhẹ để tách khỏi thân khối cùng màu (`BoardFx.bow_parts`, 2026-11-09 theo yêu cầu làm nơ rõ hơn; trước đó nhân phẳng màu mặt khối nên nơ chìm vào khối), không vẽ khi khối còn trong sương. Không vệt bóng kẹo. Concept `art/concepts/ribbon_concept_v2.png`; icon popup `mech_ribbon` (nơ satin ngọc trai) | Ruy băng satin tuột (`sfx_ribbon`, thiếu thì `sfx_layer`) |

Booster với cơ chế:

- Phá khối: không dùng được trên thùng sắt; dùng trên pudding, băng, xích, hộp giấy hoặc ruy băng thì xoá hẳn cả khối (ruy băng: mọi lớp). Khối bị Phá rời bàn nên bóc 1 lớp phủ của mỗi khối kề, lớp vỡ lúc búa gõ. Booster là búa kẹo mút (2026-11-03): chọn khối xong thì kho và bàn cập nhật ngay, búa bật ra giữa màn trên nền tia sáng xoay, lấp lánh một nhịp, thu nhỏ bay vồng tới khối và nhấc lên, rồi vung xuống cho mặt kẹo gõ đúng một ô của khối (khoảng 0,7 giây từ lúc chọn tới lúc gõ, `src/ui/smash_fx.gd`). Lúc gõ: loé trắng toàn màn, tia toả, hai vòng sóng hồng vàng, sao nổ, vòng 5 sao vàng xoay như bị choáng váng; khối vỡ tung thành mảnh kẹo đúng chất liệu (mỗi ô 8 mảnh tam giác, bắn toả khỏi chỗ gõ, hất lên rồi rơi) và bàn rung mạnh hơn va chạm thường. Búa bay thì bàn và các nút không nhận chạm; mảnh leaderboard (nếu có) bay về chip lúc búa gõ.
- Gợi ý: chỉ khối đi được ngay, có tính cổng nhịp; không còn khối nào đi được thì chỉ khối cùng màu đang chạy thẳng tới cổng nhịp khoá (dội vào để mở cổng). Bong bóng nhắc khi ngồi yên chỉ đếm khối đi được. Bấm thì một ngôi sao bay theo đường cong nhẹ từ nút Gợi ý tới khối (khoảng 0,8 giây), kéo đuôi mảnh màu cam hồng và bụi sao; chạm thì loé sáng, toả tia, khối nảy rồi nhấp nháy. Từ lúc chạm, sao lấp lánh phủ khắp khối (2026-11-08, `src/ui/hint_glitter.gd`): mỗi ô 3 sao bốn cánh trắng viền vàng hoặc hồng, kèm tia chéo nhỏ, loé lên rồi tắt ở chỗ ngẫu nhiên trong ô, tắt xong sang chỗ khác; các sao trong một ô thay phiên nên ô nào cũng luôn có sao. Sao cỡ 0,4–0,75 ô, mỗi nhịp 0,55–1,05 giây (sáng 70% nhịp), xoay chậm; sáng dần trong 0,3 giây, bám theo khối lúc nảy và nhấp nháy, vẽ trên mọi khối. Còn tới lần chạm kế tiếp (hoặc khối bị Phá) thì tắt trong 0,15 giây. Nháy khối ở hướng dẫn level 1 không có sao này. Sao còn bay thì bấm Gợi ý không làm gì. Người chơi đi nước khác trong lúc sao bay thì khi chạm nháy gợi ý mới (vẫn có sao lấp lánh), booster không mất.
- Nhắc Gợi ý (2026-11-04): Gợi ý đã mở, đang chơi mà không chạm màn hình 15 giây (`CONTENT.idle_hint_sec`) thì khung nút Gợi ý lắc, bóng đèn trắng đổi sang ảnh `booster_hint` (bóng đèn vàng), rồi bong bóng kem viền cam "Available Block : N" (N là số khối thoát được ngay, cùng luật với Gợi ý) bật ra trên nút, đuôi chỉ xuống nút. Bong bóng tự tắt sau 2 giây (`CONTENT.idle_hint_show_sec`); chạm bất kỳ đâu thì tắt ngay và chạm đó vẫn có tác dụng như thường. Tắt xong bóng đèn về như cũ, treo tiếp đủ 15 giây thì nhắc lại. Không đếm khi chưa mở Gợi ý, đang chọn khối để Phá, sao Gợi ý đang bay hay có popup; lúc đủ giờ mà không khối nào thoát được thì bỏ lượt nhắc đó. Vẫn nhắc khi hết Gợi ý trong kho (chạm nút thì mở hộp mua).
- Sương mù: Gợi ý và bong bóng nhắc không chỉ khối còn ẩn (khối ẩn không đi được). Phá khối dùng được trên khối ẩn, làm lộ các khối sương kề bên.
- Pudding, băng: Gợi ý và bong bóng nhắc không chỉ khối còn phủ (khối còn phủ không đi được).

### Mở khoá theo level

| Level | Mở |
| --- | --- |
| Từ đầu | Popup hết MOVES, avatar, frame |
| Sau khi thắng L3 | Quà 28 ngày |
| 5 / 12 / 17 | Gợi ý / +3 Move / Phá khối |
| 5 | Shop và video gold |
| 8 | Leaderboard (icon Bảng xếp hạng ở cột trái Home, khối crystal trong level) |
| 10 | Mạng, Starter Pack |
| Sau L10 | Interstitial trong phiên đầu |
| 10 | Hỏi đánh giá store (Rate us): sau thẻ thắng, popup "Đánh giá" (wireframe 4.3) hỏi trước, chọn Có mới mở hộp đánh giá của store; một lần |
| 14 / 30 / 40 / 55 / 70 / 90 / 110 / 130 | 8 cơ chế |
| Sau khi thắng L26 (level HARD thứ 2) | Weekly Pass (mục 7, `Config.WEEKLY.unlock_hard_index`) |
| 40 | Win Streak (icon ở cột trái Home, mục 7 "Win Streak") |
| 50 | Màn đặc biệt: thắng L49 thì về Home, popup mời tự mở (mục 7 "Màn đặc biệt") |
| 50 | Daily Challenge (đang tắt từ 2026-11-08, xem "Phạm vi") |
| Sau khi thắng L50 | Level Pack, rồi mỗi 50 level (mục 7, `Config.OFFERS.level_pack.every_levels`) |
| 70 | Road Trip (tab phải của thanh dưới, mục 7 "Road Trip"); cùng level dạy Sương mù |
| 100 | Chain Offer (mục 7, `Config.CHAIN.level_unlock`) |

Weekly Pass, Level Pack và Chain Offer giữ mốc trong config riêng của chúng; `Unlocks.levels()` gom các mốc đó cùng `Config.UNLOCK` cho thanh tiến trình (mốc theo level đang tới: Weekly Pass L27, Level Pack L51, Chain Offer L100). Cả ba không kéo người chơi về Home.

Hàng booster trong level luôn có đủ 3 ô. Ô chưa mở tô tối, có ổ khoá ở góc, không có nhãn số, chữ dưới ô ghi level mở ("Level 12"); chạm vào thì hiện popup "Chơi tiếp nhé!" (wireframe 3.7, `booster_soon`, 2026-11-09): ba ô theo thứ tự hàng booster, booster đã mở hiện icon, booster còn khoá hiện ổ khoá, dòng "<Tên> mở ở Level N"; chạm đâu cũng đóng, không mở hộp mua. Booster chưa mở mà nhận từ lịch quà thì vẫn vào kho, tới level mở thì ô mới dùng được. Popup hết MOVES vẫn bán hoặc dùng +3 Move trước L12, vì món này áp dụng ngay. Quà hướng dẫn ở L5/L12/L17 vẫn tặng.

Quà hướng dẫn (1 booster vào kho khi tới level mở) hiện bằng popup booster mới (wireframe 3.8, `scenes/booster_unlocked.tscn`, từ 2026-11-08) trước khi chơi: tiêu đề "BOOSTER MỚI!", tên và icon booster giữa tia sáng quay, số trong kho ("x1"), lời tặng (`tut_<kind>_gift`) và dòng "Chạm để tiếp tục" ở chỗ nút của prefab. Nút vàng của prefab ẩn: quà không bán kèm. Chạm đâu hoặc Back thì vào chơi. Nhiều quà cùng lúc thì hiện lần lượt. Sau mỗi quà là popup "Dùng thử miễn phí!" (wireframe 3.9, `popup_free_pick`, 2026-11-09): booster tặng đã vào kho nên dùng không tốn gì; Dùng thử thì vào chơi với bàn tay nhấp vào nút booster đó tới khi bấm (chơi lại level thì hiện lại), X thì vào chơi bình thường.

Hướng dẫn lần đầu (wireframe 1.5, `tutorial_intro`, 2026-11-09): trước lần chơi đầu của L1, lớp hướng dẫn với bàn tay nhấp và lời "Chạm khối để trượt nó ra cạnh cùng màu"; chạm đâu cũng vào chơi, sau đó vẫn có chữ và gợi ý khối của L1. Một lần (`s.meta.intro_seen`).

Chuyển level (wireframe 3.1, `load_transition`, 2026-11-09): sang level kế sau thẻ thắng hoặc chơi lại sau thẻ thua, màn đen có tên level giữ 0,25 giây rồi mở ra qua lỗ hình bom lớn dần trên bàn mới (0,8 giây, LoadLevelProcessVer2). Không chặn luồng: bàn mới dựng ngay bên dưới, chỉ chặn chạm lúc mở. Vào level từ Home vẫn dùng màn kẹo rơi, Road Trip dùng màn hộp quà.

Dùng +3 Move từ hàng booster: lượt cộng vào bàn ngay, nhưng chip lượt trên thanh trên tăng dần. Mỗi lượt là một dấu "+" bay từ nút tới chip, chạm chip thì số tăng 1; dấu cuối kèm loé sáng và chữ "+3" (cả quá trình khoảng 1 giây, chạm khối trong lúc bay vẫn được). +3 Move từ popup hết MOVES cộng thẳng, không có hiệu ứng này.

### Thẻ thắng và thẻ thua

Hai thẻ là popup chồng lên màn level (bàn cờ khoá input), không đổi scene. Mỗi lượt chỉ kết thúc một lần: `attempt.ended` chặn cộng gold hai lần. Thẻ đọc `attempt.level`, không đọc `s.level` (đã tăng sau khi thắng).

- **Thắng:** khối cuối nghiền xong qua thanh (và mảnh crystal đang bay đã tới chip) thì hiện thẻ ngay, không chờ thêm. Thẻ được nạp nền từ lúc vào màn level nên mở không khựng. Thẻ có tổng gold (+40 và gold MOVES thừa), nút x2 (L1 miễn phí, sau đó rewarded; thất bại hiện thông báo và thử lại được), nút Tiếp tục.
- **Gold MOVES thừa bay vào thẻ (2026-11-04):** còn MOVES thì ô gold hiện +40 trước; thẻ hiện được 0,45 giây thì đồng gold nở ra ở chip MOVES trên thanh trên, vừa lật vừa bay vồng (kéo vệt vàng, bụi sao) vào icon gold của thẻ (`src/ui/coin_fx.gd`). Lúc gold bay, cả khung chip MOVES hiện lên trên nền tối của thẻ (sáng dần 0,2 giây, đồng gold bay trên chip); đồng cuối chạm icon hoặc bấm x2, Tiếp tục thì chip mờ lại về dưới nền tối (2026-11-08). Mỗi lượt một đồng, tối đa 10 đồng (nhiều lượt thì mỗi đồng mang nhiều lượt). Đồng rời chip thì số MOVES giảm và chip nảy; đồng chạm icon thì loé sáng, nổ sao, icon và số nảy, tiếng xu, số gold trên ô và trên nút x2 tăng phần của đồng đó; đồng cuối kèm loé lớn và hai vòng sóng. Hết thì MOVES về 0 và ô gold hiện đủ tổng. Bấm x2 hay Tiếp tục lúc đang bay thì cộng nốt ngay. Gold vào ví ngay lúc thắng, hiệu ứng chỉ để xem. Daily Challenge thắng lại trong ngày (0 gold) không bay.
- **Gold x2 bay lên thanh trên (2026-11-08):** x2 thành công (L1 miễn phí hoặc xem hết video) thì ô gold hiện gấp đôi, rồi thanh trên dùng chung (`HubTop`, chỉ mạng và gold như Shop) trượt xuống đầu màn trong 0,3 giây. Sau đó 10 đồng gold bay từ icon gold của thẻ lên icon gold của thanh (cùng hiệu ứng `coin_fx.gd`). Số trên chip gold bắt đầu từ ví trước lúc thắng, mỗi đồng chạm chip thì số tăng phần của đồng đó, icon nảy và có tiếng xu. Đồng cuối chạm thì chip hiện đúng số trong ví. Chờ thêm 0,6 giây rồi thẻ tự đóng như bấm Tiếp tục và sang màn kế (level kế hoặc Home, coi như đã lấy x2 nên không có interstitial). Trong lúc bay, nút x2 và Tiếp tục bị khoá. x2 thất bại thì không có hiệu ứng này, thẻ vẫn mở để thử lại hoặc Tiếp tục.
- **Thanh tiến trình tính năng:** chạy từ mốc mở gần nhất tới mốc kế trong bảng "Mở khoá theo level" (bỏ Starter, Rate us; có Weekly Pass, Level Pack, Chain Offer từ 2026-11-09). Đạt 100% thì đổi dòng thành "Đã mở khoá …". Ẩn khi hết tính năng; bản demo chỉ tính mốc tới L20. Daily Challenge không có thanh.
- **Leaderboard trên thẻ thắng:** level có khối crystal thì thẻ có thêm thẻ người chơi: điểm tuần đếm dần và hạng cũ đếm tới hạng mới. Dải phần thưởng chỉ có gold, không có ô "+N điểm xếp hạng" và icon của nó (2026-11-05); vừa lên league thì hiện tên league mới, và sau khi bấm Tiếp tục hiện popup Lên giải (nhận thưởng) trước interstitial.
- **Sau Tiếp tục:** rời thẻ (interstitial `result_exit`, offer, xin quyền thông báo, hỏi đánh giá), rồi: vừa mở tính năng ở Home (quà ngày, shop, Leaderboard, Daily Challenge, mạng) hoặc vừa thắng Daily Challenge thì về Home; còn lại vào thẳng level kế. Hết mạng thì sang màn hết mạng; hết level demo thì báo rồi về Home.
- **Thua:** thẻ có chơi lại, về Home, `rescue_pack` nếu có. Không interstitial khi thua. Chơi lại từ L10 mà hết mạng thì sang màn hết mạng.
- **Analytics:** `level_end` kèm `won`, `taps`, `moves_left`, `blocks_left`, `rescues`, `ms`, `replay`.

### Phạm vi

- **Demo:** L1–20, có đủ popup hết MOVES, quà 28 ngày, avatar và frame; có Thùng sắt từ L14. Sau L20 hiện "Sắp có level mới". Daily Challenge đang tắt nên Home không có icon; khi bật lại, bản demo hiện icon khoá (icon tối, có ổ khoá), ribbon ghi "Level 50". Quảng cáo và mua hàng dùng bản giả lập cho tới khi có cấu hình từ Horus.
- **Bản phát hành đầu tiên:** L1–500 sinh trước bằng công cụ theo đường cong độ khó, solver kiểm và đóng gói sẵn; L1–4 làm tay.
- **Sau L500 (vòng lặp):** số level hiển thị tăng mãi (L501, L502…), nội dung quay lại từ level `content_loop_start_level` (mặc định 51) đến L500 rồi lặp tiếp (`content_release_pregen_level` = 500, trước 2026-11-08 là 100). Cấu hình được qua Remote Config. Bản lưu chỉ giữ số hiển thị nên người chơi nâng cấp từ bản cũ (kể cả đã qua L300) tự nhận nội dung theo vòng lặp, không cần migrate. Daily Challenge vẫn sinh bàn trong game.
- **Daily Challenge (L50):** dùng cùng bộ sinh. +100 gold và gold MOVES thừa cho lần thắng đầu tiên mỗi ngày (thắng lại trong ngày là 0), x2 bằng video như level thường, không có chuỗi ngày và bảng xếp hạng. Thua vẫn mất mạng như level thường.
  - **Đang tắt (2026-11-08, người dùng yêu cầu):** công tắc `Config.FEATURES.challenge` = false. Mọi level đều coi là chưa mở: Home ẩn hẳn icon (Bảng xếp hạng dồn lên chỗ đó), thẻ thắng không báo mở và thanh tiến trình không ghi Daily Challenge ở mốc L50 (mốc đó chỉ còn Màn đặc biệt), Main bỏ qua lệnh mở màn Daily Challenge. Code, màn, chuỗi chữ và bản lưu (`s.challenge`) giữ nguyên. Bật lại bằng cách đổi công tắc thành true, hoặc Remote Config `features_challenge` = "1" (không cần ra bản mới).

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
| `booster_free` | Bấm booster khi thiếu gold, không giới hạn số lần (2026-11-08; trước đó 1 lần mỗi lần chơi) | 1 lần dùng booster đó |
| `continue_moves` | Popup B, chỉ lần 1 và 2 | +3 MOVES, chơi tiếp, tính một lần |
| `refill_life` | Màn hết mạng (từ L10) | +1 mạng |
| `shop_coins` | Khối ADS Daily trong Shop (không có trên Home), tối đa 5 video mỗi ngày theo lịch của máy | 200 gold mỗi video |
| `daily_next` | Popup quà, 1 lần mỗi ngày, sau khi nhận ô hiện tại | Nhận trước ô kế tiếp |
| `cosmetic_unlock` | Màn profile | 1 avatar hoặc frame |
| `rt_revive` | Hết bước ở level Road Trip, tối đa 3 lần mỗi lượt chơi | +5 bước, chơi tiếp |

Chỉ thưởng khi xem hết. Ghi `S.adPend` trước khi hiện quảng cáo và trao lại nếu app bị hệ điều hành đóng giữa chừng, tương tự `ads.lost` của Horus.

Chờ và lỗi (2026-11-09): video chưa sẵn sàng thì game chờ tối đa `ADS.rv_wait_sec` giây, trong lúc đó lớp "Đang tải video" (wireframe 11.1, `ad_loading`) phủ toàn màn và chặn chạm. Hết giờ mà vẫn không có video thì kiểm có mạng (HEAD `CONTENT.net_check_url`, tối đa `net_check_sec` giây): mất mạng thì popup "Mất kết nối" (1.6, `popup_no_internet`, Thử lại kiểm lại mạng, có mạng thì đóng), còn mạng thì popup "Thông báo: hiện chưa có video" (11.2, `popup_notice`). Mua hàng lỗi (không phải huỷ, chờ, đã có) cũng kiểm mạng; mất mạng thì popup 1.6. Hai popup này thay dòng báo lỗi tại chỗ của màn gọi; lỗi khác (xem chưa hết, lỗi SDK) vẫn báo tại chỗ.

**Interstitial** `result_exit`: chỉ khi rời thẻ thắng và đã bỏ qua x2, hoặc khi đóng popup thắng Road Trip (mục 7 "Road Trip"). Theo số của Crash Ramp: không trước lượt 4, cách ít nhất 2 lượt và 120 giây, không trong 90 giây đầu phiên, không trong 45 giây sau rewarded. Phiên đầu không có cho tới khi qua L10. Không có quảng cáo lúc mở game và không chen giữa level.

**Banner: không có.** Giữ màn hình sạch cho cảm giác thư giãn.

**Nền tảng:** AppLovin MAX có mediation. Có luồng đồng ý GDPR, nút "Privacy settings" trong Settings và mediation debugger trong menu tester.

## 7. Mua hàng và offer

**Gói gold (số của người dùng).** Sale chạy thứ Sáu, thứ Bảy và Chủ nhật theo lịch của máy. Remote Config `weekend_sale_mode` chọn đối tượng: 1 = mọi người chơi, 2 = chỉ người chưa mua gói nào (`Game.s.buys` rỗng), 3 = tắt. Lúc sale, Shop hiện giá `_sale` và nhãn trên ô: gói 1 giữ giá, gấp đôi gold, nhãn `x2` (người dùng chọn, 2026-11-09; trước là $0.99); gói 2-6 giảm nửa giá, nhãn `-50%`. Home có nút Weekend Sale mở Shop (chỉ hiện khi Shop đã mở). Giá trên store không đổi theo ngày được nên mỗi giá sale là một SKU riêng, đuôi `_sale`.

| ID | SKU | Giá | Gold | Gold/$ | Giá sale | Gold khi sale | Gold/$ khi sale |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 201 | `gold_pack_1` | $1.99 | 1.000 | 503 | $1.99 (không giảm) | 2.000 | 1.005 |
| 202 | `gold_pack_2` | $7.99 | 5.000 | 626 | $3.99 | 5.000 | 1.253 |
| 203 | `gold_pack_3` | $14.99 | 11.000 | 734 | $7.49 | 11.000 | 1.469 |
| 204 | `gold_pack_4` | $29.99 | 25.000 | 834 | $14.99 | 25.000 | 1.668 |
| 205 | `gold_pack_5` | $49.99 | 50.000 | 1.000 | $24.99 | 50.000 | 2.001 |
| 206 | `gold_pack_6` | $99.99 | 120.000 | 1.200 | $49.99 | 120.000 | 2.400 |

Gói 3 (10.000 → 11.000) và gói 6 (100.000 → 120.000) tăng gold ngày 2026-11-09 (người dùng chọn) để gói lớn hơn luôn rẻ hơn tính theo gold/$; giá store giữ nguyên, bản `_sale` cùng lượng gold.

**Gói khác (nội dung là đề xuất của mình theo bảng giá mới, giá giữ như cũ).** Tính gold/$ theo giá booster mới; các gói đều không vượt giá sale, riêng Rescue là gói nhỏ khi kẹt.

| SKU | Giá | Có gì | Gold/$ quy đổi | Loại |
| --- | --- | --- | --- | --- |
| `remove_ads` | $5.99 | Chỉ bỏ interstitial | | Mua một lần, có Restore |
| `starter_pack` | $6.99 | 6.000 gold + 1 mỗi booster; qua L10 hoặc lượt 12, mở 48 giờ | 1.674 | Mua một lần |
| `rescue_pack` | $0.99 | 1 booster +3 Move; thua 3 lần liền một level, mỗi 24 giờ | 1.919 | Dùng hết |
| `level_pack` | $4.99 | 3.000 gold + 2 mỗi booster (2026-11-09, trước là 2.000 gold + 1 mỗi booster); mỗi khi qua 50 level (L50, L100, …; người dùng chọn 2026-11-09, trước là 10), mở 72 giờ | 2.886 | Dùng hết |
| `remove_ads_bundle` | $9.99 | Bỏ interstitial + 3.000 gold + 3 mỗi booster (thẻ bundle của popup Remove Ads và của Shop) | | Mua một lần, có Restore |
| `helper_great` | $3.99 | 2 Gợi ý + 2 +3 Move + 1 Phá khối (2026-11-09, trước là 1 +3 Move); Shop (Helper Packs) và popup hết MOVES kèm Helper Pack | 2.130 | Dùng hết |
| `helper_epic` | $4.99 | 3 Gợi ý + 2 +3 Move + 1 Phá khối; ẩn khỏi Shop | 1.884 | Dùng hết |
| `bundle_sweet` | $4.99 | 3.000 gold + 1 mỗi booster + 1 giờ mạng vô hạn; ẩn khỏi Shop | 1.743 | Dùng hết |
| `bundle_tasty` | $9.99 | 7.000 gold + 2 mỗi booster + 3 giờ mạng vô hạn; ẩn khỏi Shop | 1.842 | Dùng hết |
| `bundle_yummy` | $14.99 | 12.000 gold + 3 mỗi booster + 6 giờ mạng vô hạn; ẩn khỏi Shop | 1.941 | Dùng hết |

Sáu gói cuối thêm ngày 2026-11-09 (nội dung là đề xuất của mình, người dùng duyệt), gold/$ quy đổi không tính mạng vô hạn. Mua xong gói có booster hoặc mạng thì hiện popup thưởng (wireframe 6.3, `popup_reward`). Mục Hearts trong Shop (6.1) chưa bán, chỉ hiện ở bản debug. Người dùng chọn ẩn `helper_epic`, `bundle_sweet`, `bundle_tasty`, `bundle_yummy` khỏi Shop (2026-11-09): mục Helper Packs chỉ còn `helper_great`, mục Bundles không hiện; các SKU vẫn giữ trong `Config.SKUS`.

Remove Ads (wireframe 2.4, `popup_remove_ads`, 2026-11-09): icon Remove Ads ở cột phải Home (từ khi mở Shop, ẩn khi đã có `no_ads`) và offer Remove Ads mở cùng popup này. Hai thẻ: bundle (`remove_ads_bundle`) và Remove Ads thường (`remove_ads`); có Restore. Có một trong hai gói thì không còn quảng cáo xen kẽ và không còn offer.

Hai gói bỏ quảng cáo theo game tham khảo (người dùng chọn, 2026-11-09): giá và nội dung như `cube.sort.color.ads.1` và `ads.3` (booster của họ là AutoFill, Storage, Capacity; của mình là Gợi ý, +3 Move, Phá khối). Không làm gói bundle giảm giá `ads.3.discount`. Cả hai gói bật cùng cờ `no_ads`: chặn interstitial, không chặn rewarded (game không có banner). Shop có mục No Ads gồm hai thẻ, bundle trên, gói thường dưới. Có một trong hai gói thì ẩn cả mục, ngay lúc mua hoặc Restore xong và mỗi lần mở Shop, nên không mua được cả hai. Mua gói thường không hiện popup thưởng vì gói không có gold hay booster.

Restore và cài lại khác game tham khảo (người dùng chọn giữ, 2026-11-09). Bản tham khảo khi Restore chỉ trả cờ bỏ quảng cáo. Game mình giao lại đủ gói (gold, booster) nếu bản lưu chưa có đơn đó, ví dụ khi cài lại mà không có bản cloud. Lý do là lúc mở game, Play trả lại món mua một lần đang sở hữu.

Offer Remove Ads hiện ngay sau interstitial thứ 3 trong ngày, tối đa 1 lần/ngày và 3 lần tổng. Không popup offer trong 5 phút đầu phiên đầu, cách nhau ít nhất 3 lượt. `rescue_pack` hiện trên màn thua, sau khi đã bỏ qua popup hết MOVES, nên không tính vào giới hạn popup khi hết MOVES.

**Giao hàng:** lưu hàng trước, xác nhận đơn sau; mỗi token giao một lần; lúc mở game giao hết đơn còn treo; `remove_ads` và `remove_ads_bundle` có Restore. Soft launch kiểm chữ ký của Play Billing ngay trên máy, vì game offline và gold lưu cục bộ nên gian lận khó ảnh hưởng người chơi khác. Khi phát hành toàn cầu, nếu số liệu cho thấy gian lận thì thêm server kiểm đơn.

**Anim màn Shop (2026-11-08, `src/ui/shop_fx.gd`):**
- Mở màn: các thẻ (tiêu đề, gói, lưới gold, Restore) hiện lần lượt từ trên xuống. Thẻ sau trễ 0,06 giây; mỗi thẻ mờ dần vào trong 0,2 giây và phóng từ 86% lên đủ cỡ trong 0,4 giây, có nảy nhẹ ở cuối. Từ thẻ thứ 8 trở đi (dưới mép màn) hiện cùng lúc.
- Lúc đứng yên (từ 0,7 giây): icon gold của các ô nổi lên rồi hạ xuống, nhãn −50% lắc, vệt sáng xiên quét qua nút giá và gói gold lớn. Các ô lệch nhịp nhau nên chuyển động lan từ trên xuống. Nút đang khoá không loé. Số đo chi tiết ở `docs/UI_UNITY.md`.
- Mua gói có gold (cả 3.000 gold của No Ads Bundle) hoặc xem xong video gold: gold vào ví ngay, rồi 10 đồng bay từ icon gold của ô hoặc thẻ (thẻ không có icon gold thì từ nút mua) lên chip gold của thanh trên, cùng hiệu ứng với thẻ thắng (`coin_fx.gd`). Chip bắt đầu từ số trước khi mua; mỗi đồng chạm thì chip cộng phần của đồng đó, icon nảy và có tiếng xu. Đồng cuối chạm thì chip hiện đúng số trong ví. Hai lần mua chồng nhau thì chip đếm nối tiếp. Bay không khoá nút, rời Shop giữa chừng thì bỏ phần bay.
- Món mua một lần vừa thành Owned (mua hoặc Restore): chữ giá phóng lên 135% rồi về cỡ cũ trong 0,35 giây.


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
- Upsell (2026-11-09, wireframe 7.5, `popup_weekly_upsell`): một lần mỗi mùa, khi về Home lúc mùa Active, đã xem tutorial, đã có key và chưa VIP, popup mời mua VIP: đếm ngược mùa, ba quyền lợi VIP (thưởng VIP mỗi mốc, Bonus Bank, +3 mạng tối đa cả mùa), nút giá. Mua xong thì mở Weekly Pass. Mùa đã hiện lưu ở `s.weekly.upsell`.

**Chain Offer** (`src/meta/chain_offer.gd`)

- Chuỗi bước `free` / `ad` (placement `chain_offer`) / `pay` (SKU `chain_pack_1`, `chain_pack_2`; thưởng lấy từ chính gói, không cộng hai lần). Hai chuỗi xoay vòng, mỗi chuỗi 8 bước, layer hiện cửa sổ 6 bước. Cửa sổ đứng ở đầu chuỗi, chỉ trượt khi bước hiện tại phải sang ô cuối, nên gói vừa nhận được tích ngay tại ô người chơi bấm; lúc phải trượt thì giữ dấu tích 0,8 giây rồi mới trượt. Nhận xong mở popup Reward (`popup_reward`, prefab `PopupRewardLayer`, 2026-11-09) liệt kê thưởng của bước (bước Pay: gold và booster của gói); thưởng đã cộng lúc nhận, Claim, X hay chạm nền chỉ đóng popup. Cửa sổ cần trượt thì trượt sau khi popup đóng. Thưởng rỗng hoặc thiếu scene popup thì hiện dòng "Đã nhận thưởng!" dưới đồng hồ như trước.
- Bật sau một ván thắng hoặc thua (không tính Challenge; Road Trip, Special Bomb và Restart cũng không xét) khi chưa có chuỗi, level >= 100 (2026-11-09, trước là 150; level đang tới `s.level`, nên thắng L99 là đủ) và hết cooldown. `chain_require_lose = -1` (mặc định) xét sau mọi ván; giá trị khác chỉ xét khi thua ở level không HARD.
- Sống 1 ngày, nghỉ 3 ngày. Khác pixelflow: cooldown tính từ **lúc hết hạn**, không phụ thuộc lúc người chơi mở game lại (bản gốc tính từ lúc hàm tắt chạy nên có thể trễ). Làm hết bước không tắt chuỗi.
- Tự mở layer một lần mỗi chuỗi khi về Home; sau đó mở bằng nút ở Home. Không kiểm tra mạng (game offline; bước `ad` và `pay` tự báo không dùng được khi thiếu mạng).
- Nút ở Home (cột phải, ribbon "Chain offer") dùng icon riêng `ic_chain_offer` (2026-11-08): ba hộp quà hồng, tím, xanh ngọc nối bằng xích vàng, thay icon lịch `ic_dailygift` dùng chung trước đó.

**Special Pack** (`src/meta/pack_conditions.gd`, SKU `special_pack`, $10.99, bản sale `special_pack_sale` $5.49)

- Hiện icon ở Home từ L16, phải đã mua `starter_pack`, mua không giới hạn số lần. Mỗi lần chỉ một gói (gói đầu tiên đủ điều kiện trong `Config.PACKS`). Mở bằng popup offer chung; lúc weekend sale tự đổi sang SKU `_sale`.
- Nội dung: 12.000 gold + 2 mỗi booster.

### Win Streak (2026-11-09)

Theo `ME_WinStreak`, `ME_WinStreakConfig`, `EWStreakMilestoneItem`, `DataManager.PlayStreakEvent` của color-cube-match-puzzle (người dùng chọn theo code Unity). Logic ở `src/meta/win_streak.gd`, số ở `Config.WIN_STREAK`, bản lưu `s.streak` (`week`, `started`, `auto_shown`, `count`, `before`, `claimed`). Giờ máy như Weekly Pass (Unity dùng UTC).

- **Mở khoá:** `Config.UNLOCK.win_streak` = 40 (`LevelAppear` của Unity). Thắng L39 thì về Home (như các tính năng ở Home). Icon ở cột trái Home luôn hiện từ khi mở (`IsVisibleAnyDay`); ribbon ghi thời gian còn lại của lượt, hoặc "Chuỗi thắng (N)" khi có N mốc chờ nhận.
- **Lịch tuần:** thứ Sáu, thứ Bảy, Chủ nhật là ngày Active (`active_days`); các ngày khác chỉ nhận quà. Lượt bắt đầu ở ngày Active đầu tiên người chơi mở game trong tuần (thứ Hai là đầu tuần): chuỗi về 0, mốc đã nhận xoá, phải bấm Start lại. Lượt hết lúc qua Chủ nhật. Lượt cũ chưa được thay mà đã tới ngày bắt đầu của lượt kế thì cũng xoá: quà chưa nhận mất.
- **Đếm chuỗi:** chỉ sau khi bấm Start ở popup giới thiệu và chỉ trong ngày Active. Thắng level chính +1 (Daily Challenge, Road Trip không tính). Thua (hết đường cứu) hoặc bỏ ván đã chạm (Home, chơi lại, bỏ cứu lượt) thì chuỗi **tụt về mốc đã đạt gần nhất**, không về 0, và sau thẻ thua (hoặc ngay khi bỏ ván) hiện popup "Bạn đã mất chuỗi thắng." (`popup_notice`). Đang đúng mốc thì thua không mất gì.
- **Mốc và thưởng** (mốc là chuỗi thực = tổng Gap của Unity; gold Unity nhân 6 theo giá refill 150 → 900; AutoFill, Storage, Capacity đổi thành Gợi ý, +3 Move, Phá khối; mạng vô hạn theo phút của `HeartConfigSO`):

| Chuỗi | Thưởng |
| --- | --- |
| 2 | 15 phút mạng vô hạn |
| 4 | 1 Gợi ý |
| 7 | 20 phút mạng vô hạn |
| 10 | 1 +3 Move |
| 14 | 20 phút mạng vô hạn + 1 Gợi ý |
| 18 | 300 gold + 1 +3 Move |
| 23 | 20 phút mạng vô hạn + 1 Phá khối |
| 28 | 300 gold + 45 phút mạng vô hạn + 1 +3 Move |
| 34 | 600 gold + 20 phút mạng vô hạn + 1 Gợi ý |
| 40 | 1.500 gold + 60 phút mạng vô hạn + 2 Phá khối |

- **Nhận thưởng:** thủ công từng mốc bằng nút Nhận của mốc trong popup Main; đạt mốc lúc thắng không tự trao gì. Nhận xong hiện popup thưởng, mốc đổi sang dấu tích và rương xám. Mốc đã đạt mà chưa nhận vẫn nhận được khi chuỗi tụt và trong các ngày chỉ nhận quà.
- **Các popup:** bấm icon Home mở theo trạng thái (`ShowEvent`): lượt đang chạy mà chưa Start thì Giới thiệu (9.1), đã Start thì Main (9.2); ngày chỉ nhận quà mà còn quà thì Main, hết quà (hoặc chưa có lượt) thì End (9.4). Giới thiệu tự mở một lần mỗi lượt khi về Home. Start thì mở popup luật "Cách chơi" (9.3: thắng liên tiếp, nhận mốc, thua tụt về mốc, lượt mới mỗi thứ Sáu), chạm để đóng thì mở Main. Main: tháp mốc, mèo ở chuỗi hiện tại, đếm ngược tới hết lượt (ngày chỉ nhận quà ghi "Đã kết thúc"), nút "i" mở luật, chạm rương hiện bảng thưởng của mốc (chạm tiếp thì tắt), nút Chơi vào level. End chỉ tổng kết: chuỗi cuối và thời gian tới lượt sau ("{d}d {h}h" hoặc "{h}h {m}m"), không có thưởng. Bỏ ván mà chuỗi sẽ tụt thì popup "Giữ chuỗi nhé?" (9.5, mục 3 "Khi hết MOVES").

### Leaderboard theo league (2026-11-03)

Logic ở `src/meta/leaderboard.gd`, số ở `Config.LEADERBOARD`, bản lưu `s.lb`. Mở từ L8 (`Config.UNLOCK.leaderboard`), có cả trong bản demo. Game offline nên mọi người khác trên BXH là bot sinh trong máy (tỉ lệ bot 100%); BXH, World Ranking và Top % đều là mô phỏng.

**Tuần (2026-11-09, người dùng chọn)**

- Điểm tính theo tuần. Tuần đầu bắt đầu lúc Leaderboard mở khoá (thắng L7, `t0` trong `s.lb`); các tuần nối liền nhau theo mốc đó (`week_days` = 7), không chờ người chơi mở lại. Bản lưu cũ chưa có mốc thì tuần đầu bắt đầu lần chạy đầu tiên sau khi cập nhật (giữ điểm, league tính lại theo ngưỡng mới, không thêm thưởng).
- Hết tuần: điểm về 0, về Silver, BXH sinh lại ở Silver, thưởng các league nhận lại được từ đầu. Không có thưởng theo vị trí.
- Kết quả tuần tính lúc mở app (và resume, bắt đầu level), hoặc lúc đồng hồ trên popup Leaderboard về 0. Trước khi chốt hạng, bot được bù điểm tới lúc hết tuần. Tuần có điểm thì có kết quả (giải cuối tuần, hạng, điểm); thưởng lên giải còn chờ (chưa thấy popup Lên giải) được cộng vào kết quả, không mất. Vắng nhiều tuần chỉ tính một lần: kết quả của tuần gần nhất có điểm, kết quả cũ chưa xem thì gộp thưởng; tuần không điểm bỏ qua.
- Đồng hồ máy: chỉnh tới trước thì tuần kết thúc sớm (chấp nhận, game offline); chỉnh lùi thì tuần không kết thúc và đồng hồ đứng yên (`clock` là giờ lớn nhất đã thấy), không quá 7 ngày.
- Điểm cộng vào tuần tại lúc thắng (ván bắt đầu ở tuần trước vẫn tính cho tuần mới).

**Điểm**

- Từ L8, mỗi level thường có khối crystal (khối đặc biệt, trước 2026-11-04 là khối gắn huy hiệu ngôi sao): Normal 2, Hard 3, Very Hard 4 khối (`pieces_*`), không quá số khối của level. Chọn ngẫu nhiên theo số level nên chơi lại cùng level thì cùng khối. Daily Challenge không có. Khối crystal giữ màu và luật đi như khối thường, chỉ đổi chất liệu (xem "Khối crystal" ở mục 8).
- Khối crystal rời bàn (thoát hoặc bị Smash) cho 1 mảnh: icon khối crystal bật ra ở tâm khối rồi bay về chip đếm mảnh ở thanh trên (ngay dưới chip lượt, không nằm ở hàng booster); số trên chip chỉ tăng lúc icon chạm chip. 1 mảnh = 1 điểm, cộng khi thắng level; thua hoặc bỏ ván thì mất mảnh của ván đó. Điểm cập nhật ngay trên máy; thẻ thắng đợi icon đang bay tới chip.

**League** (theo điểm tuần, chỉ lên trong tuần; thưởng nhận khi vào league, mỗi tuần một lần)

| League | Điểm tuần | Tương đương (level thắng/ngày trong 7 ngày) | Thưởng | Điểm tăng cơ bản của bot / ngày | Người chơi mô phỏng |
| --- | --- | --- | --- | --- | --- |
| Silver | 0–149 | | không có | 6 | 48.000 |
| Gold | 150–299 | ~9 | 300 gold, 1 Hint | 7 | 24.000 |
| Platinum | 300–449 | ~19 | 500 gold, 1 Move | 8 | 14.000 |
| Emerald | 450–599 | ~28 | 800 gold, 1 Smash | 9 | 8.000 |
| Diamond | 600–769 | ~37 | 1.200 gold, 1 Hint, 1 Move | 10 | 4.000 |
| Immortal | 770–949 | ~48 | 2.000 gold, mỗi booster 1 | 11 | 1.600 |
| One Above All | từ 950 | ~59 | 5.000 gold, mỗi booster 2, 60 phút mạng vô hạn | 12 | 400 |

Ngưỡng điểm (2026-11-09, người dùng chọn mốc): chơi 20 level/ngày lên khoảng Platinum, 60 level/ngày chạm One Above All; tính với trung bình 2,3 điểm mỗi level thắng (từ L8 khoảng 3/4 level là Normal 2 điểm, còn lại Hard 3, Very Hard 4). Thưởng, ngưỡng và người chơi mô phỏng là đề xuất, chưa có số liệu thật; chỉnh trong `Config.LEADERBOARD` khi có `lb_week_end`. Silver là giải xuất phát của mọi tuần nên không có thưởng (trước 2026-11-09 là 100 gold khi mở màn lần đầu). Các league sau nhận ở popup Lên giải ngay sau thẻ thắng; đóng popup vẫn nhận thưởng.

**BXH trong league**

- Mỗi BXH 100 người: người chơi và 99 bot. Bot có tên, avatar, frame, mã quốc gia random (từ 2026-11-05 màn BXH không hiện cờ); 80% bot dùng avatar mặc định, 85% dùng frame mặc định, còn lại random đều trong catalog.
- Lúc dựng BXH, điểm bot chia đều theo vị trí: vị trí k nằm trong dải rộng 1% khoảng điểm của league (Silver 0–149: mỗi vị trí cách nhau 1,5 điểm; Diamond 600–769: 1,7 điểm), dải thấp nhất dành cho người chơi vừa vào. Nhờ vậy chơi một level là lên một hai hạng. League cuối không có trần: bot random đều trong 950–1.900 (`top_span`).
- Hạng = 1 + số bot có điểm cao hơn; bằng điểm thì người chơi đứng trên.
- Bot tăng điểm mỗi ngày lúc 7h00 GMT+7 (`grow_hour`, `grow_tz_hours`): điểm tăng = điểm tăng cơ bản của league + làm tròn(số ngẫu nhiên trong `bot_rand` [0, 4] × hệ số biến động trong `bot_var` [0,5; 1,5]). Mở game lại sau nhiều ngày thì bù từng ngày, tối đa 14 ngày (`grow_max_days`). Đồng hồ lùi thì không tăng.
- Bot chạm điểm tối thiểu của league kế thì rời BXH (lên hạng) và một bot mới vào ở đáy league thay chỗ, để BXH luôn đủ 100. Bot vừa lên hạng được giữ lại (tối đa 10, `carry_max`); khi người chơi lên league, BXH mới gồm các bot đó rồi bot mới cho đủ 100.
- UI hiện tối đa 50 người quanh người chơi (hạng 70 thì hạng 45 tới 94), podium top 3 luôn ở đầu danh sách, hàng của người chơi ghim trên hoặc dưới khi cuộn ra khỏi tầm nhìn, có ▲/▼ so với lần mở trước. Mỗi hàng ghi nhãn "Điểm xếp hạng" trên ô điểm. BXH League chỉ để xem, không chạm vào người khác được.

**Vị trí (Top %) và World Ranking**

- Top % = số người có thứ hạng cao hơn / tổng người tham gia × 100%, làm tròn lên, ít nhất 1%. Người có thứ hạng cao hơn = mọi người ở league cao hơn + (hạng trong BXH − 1) / 100 × số người của league mình, theo cột "Người chơi mô phỏng". Ví dụ đứng đầu BXH Silver: 52.000 / 100.000 → Top 52%.
- Tab World (từ 2026-11-05, theo wireframe): thẻ người chơi (huy hiệu giải, avatar, điểm, Top %, hạng thế giới) và thang 7 giải, giải cao nhất ở trên. Mỗi giải ghi số người chơi mô phỏng theo cột "Người chơi mô phỏng" (dạng 48K, 1,6K). Giải hiện tại nền xanh, quầng sáng sau huy hiệu, mũi tên và avatar "Bạn"; giải chưa tới mờ 60%; giải đã qua rõ. Chạm huy hiệu một giải có thưởng thì hiện bong bóng thưởng của giải đó, ghi "Lên Giải X nhận:" hoặc "Đã nhận" nếu đã vào giải đó trong tuần (Silver không có thưởng nên không hiện); từ 2026-11-09 bỏ nút "Phần thưởng"/"Thông tin". Mở tab thì thang tự cuộn để giải hiện tại nằm giữa. Điểm, Top % và hạng thế giới theo điểm tuần. Hạng thế giới: 50 người đứng đầu là bot có điểm trên trần BXH league cuối, sinh lại mỗi tuần và đổi theo ngày BXH; người chơi đủ điểm thì chen vào, không thì ước tính từ số người có thứ hạng cao hơn. Danh sách top 50 và thẻ người chơi khi chạm hàng không còn hiện ở màn này.

**UI**: icon Bảng xếp hạng (cúp) ở cột trái Home, dưới Daily Challenge (khoá tới L8: tối, có ổ khoá, ghi "Level 8"); có chấm đỏ khi có kết quả tuần chờ xem hoặc thưởng league chờ nhận (`Game.lb_badge`). Từ 2026-11-09 Leaderboard là popup đè lên Home (người dùng chọn), không còn thanh trên, thanh dưới và banner: khung popup chung (Popup2, dải tiêu đề "Bảng xếp hạng"), cách mép màn 16 px ở màn chuẩn, cao 85% màn; nút X ở góc phải, nút "i" Cách hoạt động ở góc trái đối xứng với X, có ở cả hai tab; đóng bằng X, nút Back hoặc chạm nền tối. Lòng khung là gradient xanh trời `BG_Winstreak` (`assets/ui/cc/BG_Winstreak.png`, cùng nền màn Win Streak); khung thân `BG/Panel` trong suốt, chỉ thanh hai tab giữ dải xanh đậm. Từ trên xuống: phần thân của tab (League: PromoBox rồi BXH; World: thẻ người chơi rồi thang giải), thanh hai tab ở đáy khung (tab trái là huy hiệu và tên giải hiện tại, tab phải là icon Bảng xếp hạng của Home và "Thế giới"). Màn hẹp hơn một hàng BXH thì lòng khung thu nhỏ theo.
- PromoBox (tab League, cả ở giải cao nhất): huy hiệu giải hiện tại (RankBadge của prefab: quầng sáng, cúp, hộp quà nhỏ), tên giải, và đồng hồ "Kết thúc sau 6n 23g" (dưới 1 ngày thì `HH:MM:SS`) tới lúc hết tuần. Chạm huy hiệu: bong bóng thưởng như `GiftPanelController` của Unity (bản sao `RewardsParent`, mũi tên chỉ vào huy hiệu) với thưởng của giải kế, ghi "Lên Giải X nhận:"; ở giải cao nhất là thưởng của chính giải đó, ghi "Đã nhận". Chạm lần nữa, chạm chỗ khác hoặc cuộn BXH thì bong bóng đóng. Đồng hồ về 0 khi popup đang mở thì chốt tuần, dựng lại và mở popup kết quả tuần.
- Mở popup: có kết quả tuần chờ xem thì mở popup Kết quả tuần (khung `popup_lb_result`: thẻ người chơi với hạng và điểm của tuần, giải cuối tuần, cúp, dòng "Tuần mới bắt đầu lại từ Giải Bạc", thưởng chờ nếu có, "Chạm để tiếp tục"; chạm là nhận); rồi tới popup Lên giải nếu còn thưởng league chờ.
- Bỏ dải 7 huy hiệu, thanh tiến độ tới league kế (và Top % ở tab League), nút PLAY. Bảng 7 league vẫn có ở popup `popup_leagues` nhưng popup Leaderboard không mở nó.
- Huy hiệu league là vòng màu + cúp, mảnh là icon khối lập phương crystal 3D màu loang bốn màu khối (`lb_piece`, `assets/ui/lb_piece.png`) ở chip đếm trong level, BXH, thẻ thắng và thẻ người chơi.

**Analytics**: `lb_join` (week, level: lần có điểm đầu tiên của mỗi tuần), `lb_points` (level, points, total, rank), `lb_promote` (league), `lb_week_end` (week, league, points, rank: lúc chốt tuần có điểm), `lb_claim` (league, coins; thêm week khi nhận ở kết quả tuần), `lb_open`.

### Road Trip (2026-11-05)

Đường 400 level riêng, chơi song song với level chính. Logic ở `src/meta/road_trip.gd`, số ở `Config.ROAD_TRIP` và `Config.ROAD_TRIP_REWARDS`, bản lưu `s.road_trip` (`level` đang chơi, `boxes` đã nhận, `guide` đã xem hướng dẫn). UI theo wireframe `roadtrip_wireframe.html` (bộ REA của game gốc).

**Luật chơi:** đúng cơ chế level thường: bàn lưới, mỗi khối một hướng thoát theo màu, chạm thì trượt ra nếu đường không bị chắn, mỗi lần chạm tốn 1 bước kể cả khi bị chặn. Đưa hết khối ra là thắng; hết bước là thua.

**Level:** bộ MoreColor của game gốc (`configs_morecolorlevels` + `tb_morecolorlevel_config`, id 10001–10400), nhập bằng `tools/import_road_trip.gd` vào `data/road_trip/rt_0001.json` … `rt_0400.json`. Độ khó theo cột Difficulty: 310 level Normal, 68 Hard, 22 Super Hard (huy hiệu, dải cảnh báo và màu nút như level chính). Bước = `StepLimit` của bảng (số khối + 3, 4 hoặc 8), không theo dư MOVES của level chính. Trong dữ liệu gốc `x` là hàng, `y` là cột (cách đọc duy nhất mà cả 400 level giải được), nên hình vốn đã dọc: rộng 10–14, cao 12–24 ô; đặt giữa lưới ít nhất 14×18, khung bàn co ô theo hình như level chính (level cao 24 ô có ô nhỏ hơn). Không có đá, băng, xích, lớp, sương mù, cổng nhịp. **Làm khó** (2026-11-09): sau khi chia cổng, công cụ nhập đổi hướng thoát của một số khối để lúc đầu nhiều khối bị chặn hơn (khối bị chặn: có khối khác nằm trên đường trượt ra). Mỗi level nhắm 110% số khối bị chặn của bản nhập (`HARDEN_PERCENT`, làm tròn lên, còn ít nhất một khối thoát được); không tìm được thì lấy mức cao nhất tìm được, nhưng cả bộ phải đạt 110%. Hình, ô, lưới, số khối, bước, độ khó và cổng giữ nguyên; độ sâu chuỗi chặn (số lượt rút hết các khối thoát được cùng lúc) không level nào giảm; đổi hướng càng ít khối càng tốt; khối đổi hướng lấy màu cổng của cạnh mới, và chỉ sang cạnh mà nó vắt hai cổng khi level không đạt mức theo cách khác. Kết quả: khối bị chặn lúc đầu 80,6% → 89,3% (Normal 79,0% → 87,6%, Hard 83,9% → 92,6%, Super Hard 85,5% → 94,5%), độ sâu trung bình 29,1 → 31,0, 5398 khối đổi hướng (13,5 mỗi level), 28 level chưa đạt 110% (thiếu 1–6 khối). Công cụ nhập kiểm mọi level giải hết bằng cách rút lần lượt khối thoát được, đúng số khối lần chạm.

**Cổng màu:** khác level chính (mỗi cạnh một màu, màu báo hướng), mỗi cạnh khung chia nhiều cổng, mỗi cổng một màu và một mũi tên; khối mang màu cổng nó thoát qua, nên nhìn màu khối rồi tìm cổng cùng màu trên khung là biết hướng. L1–200: 2 cổng mỗi cạnh, 8 màu, chia đúng chỗ game gốc chia (cột 10, hàng 14 của lưới 20×28 gốc). L201–400: 3 cổng mỗi cạnh, 12 màu, chia gần một phần ba bề ngang/dọc của hình, chọn chỗ ít khối nằm vắt qua ranh nhất. Màu xáo theo số level. 12 màu: vàng, xanh lá, xanh dương, tím (4 màu gốc), đỏ, cam, xanh ngọc, nâu (thêm cho 8 màu), hồng, chàm, kem, cam thảo đen (thêm cho 12 màu) (`LevelData.GATE_COLORS`, tông khối ở `ThemeKit.BLOCK_RAMPS`; mặt cắt thanh của màu mới suy từ thanh vàng theo sắc độ, `CandyFrame.color_ramp`). Khối nằm vắt hai cổng (177 khối trên cả 400 level sau khi làm khó, trước đó 49) lấy màu cổng chứa nhiều ô của nó nhất. Dữ liệu: khối có `dir` (hướng thoát) tách khỏi `color`, level có `gates` (cạnh → [màu, từ ô, tới ô)); game gốc chỉ có 8 cổng mọi level (L1–200 dùng 4 màu, L201–400 dùng 8 màu), số 8/12 là của người dùng.

**Mở khoá:** `Config.UNLOCK.road_trip` = 70 (người dùng chọn 2026-11-09, trước là 2; bản demo L1–20 không có Road Trip, tab hiện khoá "Level 70"). Thắng L69 vẫn sang L70 như thường (Road Trip không kéo về Home); thanh tính năng của thẻ thắng báo "Road Trip". Lần đầu về Home sau khi mở: lớp hướng dẫn phủ tối Home trừ thanh dưới, bong bóng "Road Trip unlocked!" và bàn tay chỉ vào tab; chạm đâu cũng tắt, không hiện lại.

**Mạng và kinh tế:** chơi không tốn mạng, thua hay bỏ giữa chừng không mất mạng, chơi lại miễn phí. Thắng không cộng gold, không x2, không điểm Weekly Pass hay leaderboard. Có interstitial `result_exit` khi đóng popup thắng, cùng luật nhịp của thẻ thắng thường (mục 6; không có x2 nên coi như đã bỏ qua x2; level Road Trip tính một lượt trong `s.runs`; cổng phiên đầu theo level chính đã qua); thua thì không có. Booster dùng được, mở theo level chính. Hết bước: hộp thoại "Hết lượt rồi" mời xem video `rt_revive` +5 bước (`revive_moves`), tối đa 3 lần mỗi lượt chơi (`revive_max`); không có lựa chọn gold hay kho. Bỏ cuộc thì thẻ thua (Chơi lại hoặc về bản đồ).

**Hộp quà:** 16 hộp ở level 15, 35, 69, 89, 123, 143, 163, 197, 217, 251, 271, 291, 325, 345, 379, 400 (`ROAD_TRIP.boxes`). Thắng level có hộp thì nhận thưởng của hộp đó, vào kho ngay, mỗi hộp một lần. Thưởng theo `tb_roadtripreward_config` (Hint = Gợi ý, Hammer = Phá khối, StepCount = +3 Move): 1 Hint; 1 Búa; 1 Bước; Hint + Bước; Hint + Búa; Búa + Bước; 2 Hint; Hint + Bước; Hint + Búa; Búa + Bước; Hint + Búa; Hint + Bước; Hint + Búa; Búa + Bước; Hint + Búa; Hint + Búa + Bước. Tổng 12 Hint, 10 Búa, 8 Bước.

**Màn Road Trip** (tab phải thanh dưới, trượt như Shop): thanh trên, bản đồ cuộn dọc ngay dưới thanh trên (không ribbon tiêu đề), level 1 ở đáy. Mỗi hàng chạy 6 ô, chiều chạy đổi qua lại; giữa hai hàng chạy là hàng nối chỉ một mốc ở rìa; hộp rộng 2 ô ở đầu một hàng chạy (hàng đó 5 level). Mốc: lục giác xám (khoá), xanh dương có dấu tích (đã qua), mốc hiện tại to hơn, màu theo độ khó, có quầng sáng thở và mũi tên đỏ nhún cắm ở đỉnh. Hộp: 3 hộp quà của atlas `UI_Winstreak_Atlas.png` (đỏ, xanh, tím luân phiên theo thứ tự hộp; vùng `gift_red`, `gift_blue`, `gift_purple` trong `UiAtlas`), dùng chung cho bản đồ, chip và popup thắng; hộp đang nhắm có quầng sáng, hộp đã mở mờ đi kèm dấu tích. Đường kẹo kem viền tím, vạch hồng đứt khúc nối các mốc. Chip dính mép phải: icon hộp kế và thanh "đã qua / khoảng" (0/15 ở đầu; qua hộp 15 thì 0/20). Chạm hộp: bong bóng thưởng của hộp 2,5 giây. Chạm mốc hiện tại hoặc nút "Level N" trên thanh dưới: màn chuyển cảnh nắp hộp quà (mục 2) rồi vào level. Đi hết đường: ẩn nút và chip, dòng "You finished the Road Trip!".

**Thắng:** popup "Hoàn thành level!": hộp đang nhắm nảy vào, thanh tiến độ chạy từ trước tới sau, dòng "Còn N level nữa tới hộp quà" và nút Tiếp tục. Level có hộp: thanh đầy, hộp rung, bật mở rồi các vật phẩm nảy ra, nút Nhận. Đóng popup thì màn chuyển cảnh nắp hộp quà về bản đồ, mũi tên và quầng sáng trượt sang mốc mới.

**Analytics**: `rt_start` (level, runs, moves), `rt_end` (cùng tham số `level_end`), `rt_box` (level, box), `rt_revive` (level, n).

### Màn đặc biệt (Special Bomb, 2026-11-09)

Chế độ chơi riêng có bom hẹn giờ, mở từ L50 (người dùng chọn 2026-11-09, trước là L41). Luật và số do người dùng chốt qua phỏng vấn ngày 2026-11-09, phần còn thiếu lấy theo code thật của game tham khảo (`SpecialLevelManager`, `BombLogic`, `LevelManager.HandleSceneBombInteraction` trong DLL `GameBlockGO` của dự án Blocktap). Logic ở `src/meta/special_bomb.gd` (vé, tiến độ), `src/core/special_board.gd` (bàn, bom); số ở `Config.SPECIAL`; bản lưu `s.special` (`slot_at`, `bonus`, `wins`, `board`, `invited`, `guide`); UI ở `src/ui/special_bombs.gd` (bom trên bàn), `level.gd` (chế độ `special`), `popup_special`, `popup_special_end`, `bomb_curtain.gd`.

**Mở khoá và lối vào:** `Config.UNLOCK.special_bomb` = 50: thắng L49 thì về Home, popup mời tự mở một lần; thanh tính năng của thẻ thắng báo "Màn đặc biệt". Icon quả bom ở cột trái Home (dưới Win Streak) hiện từ khi mở: còn vé thì chấm đỏ ghi số vé, hết vé thì ribbon đếm ngược tới vé chờ kế; chạm thì mở popup mời (hết vé: popup báo thời gian chờ, nút OK). Thắng level chính Hard hoặc VeryHard được vé thì thẻ thắng có thêm ô "+1 vé" (icon bom), và sau thẻ thắng (sau interstitial, offer, xin quyền thông báo, hỏi đánh giá) popup mời hiện trước khi sang level kế; X thì vào level kế như thường và giữ vé. Lần thắng đó dẫn về Home (vừa mở tính năng ở Home) thì Home mời. Popup mời: tiêu đề "Màn đặc biệt", quả bom, luật "Gỡ khối có bom trước khi hết giờ!", hộp quà "?", dòng vé (và đếm ngược tới vé chờ kế nếu đang chờ), nút Bắt đầu và X. Bản demo dừng ở L20 nên không bao giờ mở.

**Vé:** hai ngăn độc lập. Ngăn chờ giữ tối đa 1 vé: dùng vé thì đồng hồ 2 giờ (`timer_sec`) bắt đầu, đủ giờ thì có vé và dừng (không cộng dồn); lúc tính năng mở đã có sẵn 1 vé. Ngăn thưởng: thắng level chính Hard +1, VeryHard +1 (`ticket_hard`, `ticket_very_hard`; độ khó theo `Game.difficulty_of`, nên từ L501 level HARD tính là VeryHard), chỉ khi tính năng đã mở ở level vừa thắng; Road Trip và Daily Challenge không tính; không giới hạn số vé (`bonus_cap` 0). Vé thưởng không ảnh hưởng đồng hồ của ngăn chờ. Vào chơi dùng vé ngăn chờ trước (để đồng hồ chạy lại sớm nhất), vé trừ lúc bấm Bắt đầu; thua, rời màn hay tắt app giữa trận đều mất vé. Đồng hồ theo giờ máy (`Game.now`); giờ máy bị chỉnh lùi thì thời gian chờ không vượt 2 giờ. Có thông báo local "Màn đặc biệt đã sẵn sàng!" lúc vé chờ hồi xong, chỉ khi ngăn thưởng trống, chung giới hạn của lịch thông báo (mục 8).

**Bàn:** 100 bàn sinh sẵn bằng `tools/gen_special.gd` vào `data/special/sp_0001.json` … `sp_0100.json`, hết thì quay lại bàn 1. Bàn là hình chữ nhật lát kín (ngoại lệ của luật "không lát kín" ở mục 3), rộng 10–12 ô, cao 14–16 ô (cộng một ô lề vừa lưới 14×18, ô nhỏ nhất 51 px như level chính), 3,0–3,4 ô mỗi khối (tối đa 7 ô), tức 41–64 khối, trung bình 51,5. 4 cạnh 4 màu như level chính, không cơ chế, không khối crystal. Cắt và gán hướng bằng `LevelGenerator._tile` / `_assign`, số lượt dọn bàn nhắm 0,45 × số khối (trung bình 23,4). Cỡ bàn random theo seed, không tăng dần; độ khó chỉ tăng theo số bom. `StepLimit` = số khối + 3; 10% bàn +4, 2% bàn +5 (theo seed, tỉ lệ của game tham khảo). Chỉ thắng mới sang bàn kế; thua thì lần sau gặp lại đúng bàn và bom đó.

**Bom:** số bom = 1 + (số trận thắng / 20), tối đa 6 (`bombs_start`, `bombs_every`, `bombs_max`). Bom không nằm trong file: lúc vào chơi `SpecialBoard.bomb_plan` chọn khối. "Số lần chạm để gỡ" một khối = số khối phải rời bàn trước nó (cả chuỗi chặn) + 1. Khoảng [4, 80% số khối] chia k tầng đều nhau, mỗi tầng một khối random, nên có quả nông, quả vừa, quả sâu; không khối thoát được ngay nào mang bom. Số giây: xếp bom từ nông tới sâu, quả thứ k có 19 + số khối khác nhau phải chạm để gỡ hết quả 1..k (`bomb_base_sec`, `bomb_sec_per_tap` 1 giây). Với 1 bom, công thức này cho đúng số giây của game tham khảo (đo trên 180 quả của 90 level: `bombSeconds` = 19 + số lần chạm, khớp tuyệt đối); cộng dồn để level nhiều bom vẫn luôn kịp với nhịp 1 lần chạm mỗi giây. Ngắn nhất 23 giây. Bom nằm ở ô của khối gần trọng tâm khối nhất, cỡ 1,3 ô, là node con của khối nên đi theo khối khi trượt, nảy, qua thanh.
- Bom chưa đếm cho tới lần chạm hợp lệ đầu tiên (kể cả chạm khối bị chặn, kể cả búa); lúc đó mọi quả cùng bắt đầu. Khối mang bom thoát hoặc bị búa đập thì quả đó tắt hẳn (số ẩn, tiếng tách, lấp lánh); quả khác vẫn đếm.
- Chỉ đếm khi người chơi chạm được vào bàn: đang chơi, không có popup nào (của màn hay của Main), búa không đang bay, sao Gợi ý không đang bay, app không ở nền (khung đầu sau khi app quay lại bị bỏ). Mỗi khung trừ tối đa 0,25 giây. Đang chọn khối để đập búa thì vẫn đếm.
- Số trên bom = làm tròn lên số giây còn lại. Còn 3 giây (`warn_sec`): ngòi toé lửa, bom phồng nhịp và đỏ dần, tiếng tích tắc mỗi giây.
- Về 0: thua ngay (ghi lại trước), chặn chạm, bom nổ (loé sáng, mảnh kẹo, rung bàn, rung máy `boom_haptic_ms`), 1 giây sau (`boom_popup_sec`) popup "Bùm!".
- Gợi ý ưu tiên khối thoát được nằm trong chuỗi chặn của quả bom gấp nhất; không có thì như level thường.

**Trong màn:** dùng luật trượt khối như level thường. Không cần mạng để vào, thua không mất mạng. Hết bước là thua ngay, không có popup cứu lượt. Hàng booster vẫn dùng và mua được (booster mở theo level chính). Không có chơi lại: nút Restart đổi icon Home và thành nút Rời màn; Back và Home trong cài đặt cũng vậy; popup cài đặt ẩn Chơi lại. Rời màn hỏi "Rời màn? Bỏ màn này và về Home? Vé đã dùng sẽ mất.", đồng ý thì thua và về Home, không interstitial. HUD ghi "Màn đặc biệt", không huy hiệu độ khó; bàn, khung và chất liệu khối như level chính. Lần đầu vào Special: popup hướng dẫn (khung "Vật cản mới", `booster_unlocked`) với quả bom và luật, chạm để tiếp tục, một lần.

**Kết thúc:** thắng: popup hộp quà nảy vào, rung, bật mở, 1 booster rút theo tỉ lệ Gợi ý 60%, +3 Move 30%, Phá khối 10% (2026-11-09, trước là rút đều; `reward_kinds` rút đều trong mảng nên tỉ lệ ghi bằng cách lặp tên: 6 `hint`, 3 `move`, 1 `smash`) bay ra, đã vào kho ngay khi thắng; nút x2 (rewarded `special_x2`, thêm 1 cái cùng loại) và nút Nhận; Nhận thì interstitial `result_exit` theo nhịp thẻ thắng thường (đã lấy x2 thì không), rồi vào thẳng level chính kế (màn `load_transition`; hết mạng thì màn hết mạng). Thua (hết bước: "Thử thách thất bại"; bom nổ: "Bùm!", ảnh bom tối và nghiêng): "Hẹn gặp lần sau!", nút "Level N" vào level chính kế, X về Home; không interstitial khi thua. Special không cộng gold, không tăng level chính, không cộng điểm Weekly Pass, Leaderboard, không tính Win Streak; thua không tụt chuỗi, không tính vào Helper Pack hay offer.

**Chuyển cảnh:** vào Special (từ Home hay từ popup mời sau thẻ thắng) dùng màn mưa bom `bomb_curtain.gd`: như màn kẹo rơi nhưng mỗi viên là quả bom, nền chàm đậm; một loại sprite (chưa có nhiều tông màu). Sang level chính sau Special dùng `load_transition`; về Home không có màn chuyển cảnh.

**Hình và âm:** quả bom kẹo cao su xanh tím, vòng cổ hồng, ngòi kẹo gậy hồng trắng, đầu ngòi ngôi sao vàng (`assets/ui/special_bomb.png`; người dùng chọn phương án C trong `art/concepts/concept_bomb_v1.png`). Âm `sfx_bomb_tick`, `sfx_bomb_defuse`, `sfx_bomb_explode` (ComfyUI); chưa có file thì dùng `tap`, `hint`, `smash`.

**Analytics:** `sp_start` (level = số bàn, board, bombs, moves, ticket: timer | bonus, wins, tickets_left, runs), `sp_end` (tham số `level_end`, thêm reason: won | steps | bomb | quit, bombs, bombs_left), `sp_reward` (level, kind, wins), `sp_x2` (kind), `sp_ticket` (source: hard | very_hard, n, level, total).

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
| Cloud save | Play Games Saved Games; xung đột cùng lịch sử chơi thì giữ bản chơi nhiều hơn và gộp danh sách đơn đã mua; hai lịch sử khác nhau (cả hai đã chơi, khác level, `meta.install_at` khác nhau: máy khác hoặc cài lại) thì hỏi người chơi bằng popup "Chọn tài khoản" (wireframe 1.4, `select_account`, 2026-11-09): hai ô "Máy này" và "Google Play" (tên, level), phải chọn một, bản kia bị bỏ, chỉ đơn mua của nó được gộp; có xung đột lúc mở game thì vào Home thay vì vào thẳng level, xung đột tới lúc đang chơi thì hỏi khi về Home. Android Auto Backup làm dự phòng | Không phải vận hành server |
| Cập nhật app | Remote Config `content_latest_version`, `content_min_version` (trống là tắt). Sau khi mở game, phiên bản app (`application/config/version`) thấp hơn `latest_version` thì popup "Có bản cập nhật" (wireframe 1.2, `popup_update`) có Để sau, một lần mỗi lần mở; thấp hơn `min_version` thì bắt buộc: không Để sau, không X, Back không đóng. Cập nhật mở `content_store_url` | Không bắt người chơi gỡ bản cũ |
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

Mỗi màu có bốn tông trong `ThemeKit.BLOCK_RAMPS`, vì tông đổi cả sắc độ (vàng về cam, tím về tím đậm) nên không suy ra từ một màu. `face` cũng là `ThemeKit.BLOCK_COLORS`, nên cổng, hạt và khối cùng một màu. Bảng dưới là màu gốc; khi vẽ khối và hạt, `ThemeKit.block_color`, `block_ramp` hạ sắc độ cho bớt chói (saturation ×0,85, value ×0,97: `BLOCK_SAT`, `BLOCK_VAL`). Khung cổng suy từ màu gốc rồi hạ theo `BAR_SAT`, `BAR_VAL` riêng:

| Màu | `deep` (đáy) | `side` (hai bên) | `face` (sọc đậm) | `stripe` (sọc nhạt) |
| --- | --- | --- | --- | --- |
| Vàng | `F19B09` | `F8B20F` | `FDD414` | `FDE846` |
| Xanh lá | `20A208` | `41C412` | `6DED1E` | `84F437` |
| Xanh dương | `0260E6` | `148FF8` | `0C9CFD` | `41C1FD` |
| Tím | `B113CC` | `C622DC` | `E644F4` | `EC5FF6` |

- Texture khoảng cách tới mép (SDF) dựng một lần cho mỗi hình khối rồi cache (không phụ thuộc màu hay cỡ ô, khoảng 4–35 ms mỗi hình trên máy dev). Hình của mọi level trong `data/levels` và `data/road_trip` bake sẵn vào `data/pudding_sdf.res` (`tools/bake_sdf.gd`), nạp ở luồng nền lúc splash, nên vào bàn không phải dựng (mở level lúc nguội dưới 1 ms thay vì 133–767 ms). Hình ngoài bank (Daily Challenge sinh lúc chạy, khoảng 1,5% số hình) dựng trên WorkerThreadPool trong lúc hiện dòng chờ; shader dùng SDF để tính mép gối, vạch đáy và bóng, nên khối chữ L, T, ... đều ra đúng cấu trúc, viền góc liền một nét. Mỗi điểm ảnh đọc texture tối đa 7 lần.
- Cỡ ô là số nguyên (làm tròn xuống) để các ô của một khối khớp pixel.
- Khối không có mũi tên, đúng như ảnh duyệt. Lớp phủ (pudding hoặc băng, 1 hay 2 lớp; tham số `jelly`, `jelly_thick`, `ice_mat`), hộp giấy, ruy băng (tham số `ribbons`) và lớp sương mù vẽ trong cùng shader thân khối (`pudding.gdshader`) theo SDF nên ôm đúng mọi hình khối, nháy sáng Gợi ý cũng vậy. Sương lấn ra ngoài mép nên khối còn trong sương vẽ sau mọi khối khác. Xích vẽ đè lên lớp kẹo thành một triangle array (một draw call cho cả lớp xích của khối), dựng một lần cho mỗi hình khối và cỡ ô rồi cache; ổ khoá, ảnh chìa, ảnh đám mây vẽ trên cùng.
- Chưa áp dụng cho nền, icon (giữ nét hiện tại). Khi tạo hoặc làm lại hình bằng MCP, thêm từ khoá kẹo gel bóng (xem quy tắc prompt bên dưới) để cùng phong cách.

**Khung cổng (2026-11-02).** Khung theo cùng ảnh duyệt, vẽ bằng shader (`src/ui/candy_frame.gd`, `frame_bar.gdshader`, `frame_corner.gdshader`), số đo theo đơn vị khung (`Config.BOARD_FRAME_UNIT`):

| Phần | Hình | Số đo |
| --- | --- | --- |
| Thanh cổng | Bốn capsule rời nhau, mỗi cạnh một màu cổng, tô theo mặt cắt đo trung vị dọc thanh trong ảnh (`BAR_RAMPS`), hạ sắc độ cho bớt chói (saturation ×0,9, value ×0,9: `BAR_SAT`, `BAR_VAL`); thanh ngang có vạch sáng ở trên và dải đậm ở dưới, thanh dọc đậm ở hai mép; đầu trên thanh dọc có vòng sáng, đầu dưới đậm dần | Dày 0,55–0,60; từ mép bàn tới đường giữa thanh: trên 0,305, dưới 0,32, trái 0,46, phải 0,47 |
| Ống góc | Một phần tư vành tròn hồng phấn nối hai thanh, cùng sắc với nền và tấm bàn (`ThemeKit.BOARD_BG`), đậm hơn nền một chút để còn nổi khối (dải `F9DCE3` → `C4889A`, viền `B57D8E` trong `frame_corner.gdshader`), nằm dưới đầu thanh; vệt trắng chạy theo cung, vị trí đổi theo từng góc vì ánh sáng từ trên hơi lệch trái | Bán kính tới đường giữa 0,49; rộng 0,44 |
| Mũi tên | Tam giác trắng bo góc, chỉ ra ngoài, viền mờ màu đậm của thanh; ở thanh dọc đặt cao hơn tâm | Ngang 0,45 (thanh dọc 0,50), dọc 0,34–0,35; thanh dọc lệch lên 0,21 |
| Bóng đổ | Mềm, lệch xuống dưới, ám tím đậm | Lệch 0,11; mờ 0,14; đậm 32% |

- Số đo hình học theo ảnh ref `art/concepts/ref_board_size.png`, màu giữ theo ảnh duyệt kẹo. Các số trong bảng tính theo đơn vị khung (`Config.BOARD_FRAME_UNIT`, 51,7 px ở màn chuẩn 886×1920), không theo cỡ ô khối. Khung chiếm thêm 0,77 đơn vị mỗi bên và 0,61 đơn vị trên dưới, trọn khung 803×1044 px ở màn chuẩn. Ảnh ref `ref_board_scale.png` quy đổi ra 803×1038 px.
- Màn level chỉ có thanh trên (lượt, tên level, restart, bánh răng; Home nằm trong popup cài đặt; hàng dưới giữ chỗ cao cố định cho chip đếm mảnh, kể cả level không có mảnh) và hàng booster (luôn 3 ô) chiếm chiều cao; chữ hướng dẫn và nhãn Phá khối phủ lên phần trên của bàn. Nhờ vậy khung không xê dịch giữa các level. Nền bàn trơn, không vẽ lưới ô.
- Vị trí và cỡ ở màn chuẩn 886×1920 (`scenes/level.tscn`). Chip lượt 244×169 px (số 85, chữ MOVES 36). Số MOVES nằm thấp hơn chữ MOVES 14 px so với trước (2026-11-08), để khối chữ và số cân giữa mặt chip, không dồn lên trên. Tên level cỡ 50, pill HARD 120×55 (chữ 30). Hàng chip mảnh cao 66 px (icon 50, số 35), chip căn giữa theo chip lượt (`PieceRow` là `CenterContainer` rộng 244 px). Chip mảnh dùng cùng khung kẹo tím với chip lượt (`hud_moves_panel`, 9-slice). Khung này vẽ bằng `src/ui/u_image.gd` với viền thu nhỏ 0,39 lần (66/169), để góc bo cùng tỉ lệ với chip lượt. `StyleBoxTexture` vẽ viền đúng 44–48 px của ảnh, lớn hơn chiều cao chip mảnh. Hàng booster cách đáy màn 175 px (lề dưới của `Margin`), nên nút booster nằm ở y 1577–1706 như ảnh ref quy theo chiều cao màn. Khung bàn nằm giữa thanh trên và hàng booster, ở y 406–1450 (ảnh ref: 359–1410).
- HUD level dùng bộ sprite kẹo thạch tím `assets/ui/hud/` (theo `art/concepts/ref_hud_candy.png`): khung MOVES ghi "MOVES" nhỏ trên số lượt to; pill tím ghi HARD hoặc VERY HARD dưới tên level; restart và bánh răng là nút tròn; 3 booster là nút vuông bo có glyph trắng. Năm nút này, khung MOVES, khung chip mảnh và pill HARD được chỉnh tông cho bớt chói (shader `src/ui/hud_tone.gdshader`): vệt bóng tím nhạt kéo một nửa về màu thân (`Config.HUD_TONE_GLOSS` 0,5), rồi saturation ×0,8, value ×0,97 (`HUD_TONE_SAT`, `HUD_TONE_VAL`); glyph trắng hồng, chấm bóng trắng nhỏ, chữ, huy hiệu, ổ khoá giữ màu, trừ chữ HARD vẽ chung node với pill nên viền tím của chữ dịu theo. Huy hiệu góc dưới phải ô booster là tròn xanh ghi số còn lại (`x2`), hết kho thì là sprite dấu + xanh. Chữ và số đều vẽ bằng code.
- Dải cảnh báo đầu level Hard và VeryHard (2026-11-08): khung kẹo gậy theo concept, viền là dây kẹo xoắn sọc trắng, lòng thạch trơn; Hard đỏ dâu, VeryHard tím nho, cùng màu bậc ở Home và Road Trip. Đầu lâu nằm trên huy hiệu tròn cùng bộ (vòng kẹo gậy, lõi thạch) ở bên trái, chữ HARD hoặc VERY HARD ở phần còn lại. Khung cách mép màn 16 px, cao 200 px ở màn chuẩn, giãn ngang theo bề rộng (9-slice, hai đầu tròn giữ nguyên); huy hiệu 250 px, nhô khỏi khung 25 px trên dưới. Ảnh tạo bằng ComfyUI (`art/manifest.json`, mục `warn_*`), bản đỏ đổi sắc từ bản tím bằng `tools/make_warn_banner_art.py`. Bỏ hai tam giác "!" và vạch chắn trắng của prefab vì đè lên viền khung; đầu lâu và chữ vẫn nhịp như cũ.
- Nền màn level là ảnh `bg_level` (phong cảnh kẹo), giống nhau ở cả 3 độ khó, vẽ nhạt ở độ trong suốt 35% (`ThemeKit.LEVEL_BG_IMAGE_ALPHA`) trên nền hồng pastel `LEVEL_BG` (`#FFEEF4`) để nền ám hồng sáng; lớp dim `ThemeKit.LEVEL_BG_DIM` để trong suốt hoàn toàn (bàn có khung cổng bao quanh nên vẫn tách khỏi nền); ảnh cắt kiểu cover nên không méo trên màn dài. Độ khó chỉ báo bằng huy hiệu HARD/VERY HARD và dải cảnh báo, không đổi màu nền. Thiếu ảnh thì còn nền màu `LEVEL_BG`.
- Cổng nhịp đóng (2026-11-08): thân thanh ngả một nửa về màu đậm của cổng (vẫn đọc được màu, không tối thành nâu xám), phủ sọc kẹo gậy trắng kem chéo 45° hướng "/" (chu kỳ 0,9 bề dày thanh, sọc chiếm 42%, mép sau của sọc tối nhẹ cho sọc nổi lên, sọc nhạt dần sát mép thanh để chừa viền màu cổng); mũi tên thu lại và một huy hiệu tròn màu đậm của cổng (bán kính 0,33 đơn vị khung, to hơn bề dày thanh chút, viền sáng, có bóng đổ) nảy ra cùng chỗ, giữa là ổ khoá trắng có lỗ khoá. Khi đổi trạng thái sọc dày dần hoặc mỏng dần, mũi tên và huy hiệu đổi chỗ cho nhau trong lúc thanh chuyển (0,22 giây), kèm nháy sáng trong hình thanh. Đoạn thanh lăn khi khối dội vào cổng đóng cũng mang sọc, sọc lăn theo từng mặt lăng trụ. Vẽ trong `frame_bar.gdshader`, trạng thái mở không đổi.
- Lúc cổng nhịp đổi hình (2026-11-08): board đổi cổng ngay lúc khối cùng màu được chạm (luật mục 4), nhưng hình cổng chỉ đổi khi hoạt ảnh của lượt chạm đó xong. Khối dội vào cổng đang khoá: cổng còn khoá tới khi khối bật về hẳn chỗ cũ rồi mới mở. Khối nghiền qua cổng đang mở: cổng còn mở tới khi khối qua hết thanh rồi mới khoá; hộp giấy bay qua cổng cũng vậy, tới khi hộp rách xong. Chạm nhanh nhiều lượt thì cổng đổi theo thứ tự lượt; khối của lượt sau chạm tới thanh trước khi lượt trước xong thì cổng đổi ngay sang trạng thái lượt đó gặp, để khối luôn dội vào cổng khoá và đi qua cổng mở. Khối cuối trên bàn đi qua thì cổng không đổi nữa (thẻ thắng hiện ngay). Tiếng cổng kêu lúc cổng đổi hình; lượt bị cổng chặn thì tiếng cổng đã kêu lúc va nên cổng mở ra sau đó không kêu lại (`BoardView._gate_move`, `_move_end`, `_gate_reach`). Khối bị cổng đóng chặn trượt qua khoảng trống tới mặt trong của thanh rồi bật về; hạt lúc khối thoát bắn ở mặt trong của thanh.
- Nền bàn (`ThemeKit.BOARD_BG`, `#E9CDD2`) cùng tông hồng với nền màn level (ảnh `bg_level` phủ lên `LEVEL_BG`, trung bình vùng bàn khoảng `#F7E6E5`) nhưng tối hơn một chút; hình theo khung (tới đường giữa thanh, bo theo ống góc).

**Hiệu ứng thoát và va chạm (2026-11-02, đổi sang nghiền qua thanh 2026-11-03).** Mức "đẹp mà vẫn êm" do người dùng chọn: nhiều chi tiết nhưng bàn chỉ rung nhẹ, đúng tiêu chí thư giãn ở mục 3. Không có lần nào chặn thao tác: người chơi chạm tiếp được ngay. Vẽ bằng code và shader (`src/ui/candy_shards.gd`, `candy_shard.gdshader`, `impact_flash.gdshader`); mảnh dùng chung chất liệu với khối qua `candy_body.gdshaderinc`.

| Khoảnh khắc | Diễn biến | Số đo |
| --- | --- | --- |
| Khối lao tới thanh | Nhanh dần, dài ra theo hướng lao; gần tới thanh thì chậm dần đều về đúng tốc độ nghiền để trôi êm vào thanh, không còn đâm vào thanh ở tốc độ cao nhất rồi khựng lại; độ dài ra co lại theo tốc độ; tới đúng mặt trong của thanh cùng màu (2026-11-04). Khối sát thanh (từ 4 ô trở xuống) không đủ đường để hãm thì nhanh dần tới tốc độ nghiền rồi đi đều. Khối cuối trên bàn không hãm: nhanh dần tới tận thanh như trước, đâm vào thanh ở tốc độ cao nhất cho cú chốt ván | Nhanh dần 0,20–0,35 giây tuỳ quãng đường (0,20 giây cộng 0,026 giây mỗi ô, `SLIDE_MIN`, `SLIDE_PER_CELL`, `SLIDE_TIME`), rồi chậm dần 0,3 giây (`EXIT_BRAKE`) về 9 ô/giây; dài ra 9% lúc nhanh nhất, theo bình phương tốc độ so với lúc nhanh nhất |
| Gió hút vào thanh (2026-11-04) | Khi khối thoát gần chạm thanh cùng màu và suốt lúc bị nghiền, vệt gió mảnh trắng pha màu thanh, có quầng mờ quanh vệt, dài ngắn khác nhau, hiện sát mặt trong của thanh, chạy nhanh dần vào thanh, chạm thanh thì bị nuốt vào. Vệt rải trong đúng bề ngang khối (không toả ra ngoài); miệng thanh trước khối sáng lên một quầng cùng bề ngang, mờ dần vào bàn. Thanh giữ nguyên hình dạng và kích thước, vệt không vẽ lên thanh. Vệt nằm trên lớp khối, vẽ cộng sáng nên rực lên cả trên nền bàn lẫn trên khối đang bị hút. Chỉ khi khối thoát, dội vào cổng đóng thì không có (`src/ui/suck_wind.gd`) | 5 vệt mỗi ô bề ngang khối (ít nhất 4), rải đều từ 0,2 giây trước lúc chạm tới lúc khối trôi hết qua thanh, mỗi vệt sống 0,16–0,24 giây, rõ dần trong 40% đầu đời vệt; cả cụm gió (vệt và quầng) rõ dần từ trong suốt trong 0,18 giây đầu, êm ở hai đầu, để không hiện đột ngột; đầu vệt hiện cách thanh 0,1–0,8 ô; dài 0,3–1,4 ô, lõi dày 0,035 ô, đậm 80%; quầng vệt rộng 0,28 ô, đậm 30%; quầng miệng sâu 0,6 ô, đậm 30%, tắt 0,12 giây sau vệt cuối; màu thanh pha 60% trắng |
| Nghiền qua thanh (theo video ref `art/concepts/2026-11-03_08-48-53.mp4`) | Không nổ một lần: khối trôi đều tiếp qua thanh, phần đã qua mặt trong của thanh bị cắt đi như lùa dưới thanh. Ô đang vắt qua thanh phun ra khối vuông nhỏ (mảnh to và mảnh nhỏ) ở mặt ngoài thanh, theo phần diện tích vừa qua, nên vụn ra liên tục suốt lúc khối đi qua; số mảnh theo bề ngang khối (số cột ô khối phủ dọc thanh), khối dài hay ngắn theo hướng đi cũng vậy; mảnh rải đều theo bề ngang chứ không chụm một chỗ, bay xa (2026-11-08); kèm vài sao lấp lánh lúc bắt đầu. Khối vuông lấy màu đúng chỗ đang qua thanh trên khối (sọc, mép) và có mặt bên đùn xuống (tối theo hướng mặt, vạch sáng ở mép trên) nên trông như hạt kẹo cứng. Góc khối vuông bo tròn, viền sáng của mặt trên mảnh hơn viền mảnh vỡ thường, không có viền tối giữa mặt trên và mặt bên (2026-11-04; bỏ viền tối áp dụng cho mọi mảnh kẹo) | Trôi 9 ô/giây; khối rộng 1 ô ra 15 mảnh to và 10 mảnh nhỏ (`BoardView.GRIND_BITS`, `GRIND_SMALL`), mỗi ô bề ngang thêm ra thêm 0,5 lần chừng ấy (`GRIND_BITS_EXTRA`), làm tròn: rộng 2 ô ra 23 to 15 nhỏ, rộng 3 ô ra 30 to 20 nhỏ; ra dần theo phần diện tích khối qua thanh, vị trí ngang theo dãy tỉ lệ vàng trên bề ngang các ô đang qua thanh (mảnh to và nhỏ chung một dãy), lệch ra ngoài thanh ngẫu nhiên 0–0,4 ô; mảnh hiện ngay ngoài mặt ngoài thanh (tâm lùi ra đúng nửa đường chéo) để không đè lên thanh; cạnh mảnh to khoảng 0,23–0,36 ô (nửa đường chéo 0,165–0,255 ô, tính trước khi bo), mảnh nhỏ nửa đường chéo 0,075–0,135 ô (2026-11-08: cả hai to gấp 1,5 lần), dày 0,8 lần nửa đường chéo; bo góc bán kính 0,45 lần nửa cạnh, 2 đỉnh mỗi góc; viền mặt gãy rộng 0,5 lần viền mảnh thường; phun 3–7,5 ô/giây, lệch ngang tối đa 0,8 lần tốc độ phun, hãm 1,2 mỗi giây (bay xa khoảng 2–5 ô; 2026-11-08), sống 1,1–1,6 giây, mờ dần từ 45% đời; 6 sao |
| Vụn bay | Phun ra khỏi thanh theo hướng khối đi, toả hình nón rộng sang hai bên, chậm dần, trôi nhẹ chứ không rơi, vừa bay vừa lật; bay đè lên cả vùng ngoài bàn, nút và chữ; nhỏ dần và mờ ở cuối | 3,5–9 ô/giây theo hướng đi, ngang tới ±1 lần; hãm 1,8/giây; trọng lực 3 ô/giây²; xoay 3–9 rad/giây; sống 0,75–1,15 giây; bay xa khoảng 1,5–4,5 ô (trước đây 0,7–2,2 ô) |
| Thanh bị va | Bật ra rồi nảy về, sóng sáng chạy dọc thanh từ điểm va, mũi tên phồng lên | 0,45 giây; bật 0,1 ô |
| Đoạn thanh lăn (theo video ref `art/concepts/2026-11-03_08-48-53.mp4`) | Đoạn thanh khối phủ lên nổi thành lăng trụ lục giác hơi to hơn thân thanh, có chốt trục ló ở hai đầu, lăn quanh trục thanh theo hướng khối đi; nằm yên thì một mặt hướng lên người nhìn; mỗi mặt tô theo mặt cắt thanh nên khớp ánh sáng, cạnh giữa hai mặt sáng lên. Lăn đều suốt lúc khối trôi qua thanh, rồi chậm dần, dừng đúng một mặt (bội 60°) và chìm lại vào thanh. Khối thoát: đoạn dài bằng toàn bộ khối chiếu lên trục thanh. Dội vào cổng đóng: chỉ các ô mép trước, lăn 1 mặt | Nổi lên 0,05 giây; chậm dần 0,6 giây qua 2 mặt = 120° (cổng đóng 1 mặt = 60°), chìm lại trong 30% cuối; lúc khối đang qua quay khoảng 1,7 vòng/giây; lăng trụ rộng đỉnh-tới-đỉnh 1,12 lần bề dày thanh; chốt dài 0,09 ô |
| Loé sáng | Chỉ khi va chạm: quầng sáng, sao bốn cánh và vòng sóng toả ra, kèm sao lấp lánh. Khối thoát không loé, không rung bàn (khối crystal có cú chốt sao loé riêng, xem "Khối crystal qua thanh") | Rộng 1,8 ô, 4 sao |
| Va chạm | Khối đi va nhún theo trục va, tâm nhún ở điểm chạm rồi về chỗ cũ không vượt quá; vụn kẹo và sao văng ra ở điểm chạm | Nhún 15%, 0,46 giây; 4 vụn mỗi khối, văng 2–5 ô/giây |
| Khối bị va | Giật lùi rồi về đúng ô, nhún theo, dư chấn lan sang tối đa 2 khối nằm ngay phía sau, mỗi khối yếu đi một nửa | Nhún 10%; lùi 0,1 ô; trễ 0,05 giây mỗi khối |
| Chạm cổng đóng | Chỉ khối kẹo nhún và văng vụn; thanh bị va | Như trên |
| Thùng sắt | Ảnh thùng sắt (`mech_stone`) phủ kín ô vuông. Người chơi chạm vào ô thùng: thùng rung, nắp loé, đinh loé, tia lửa nhỏ, không tốn MOVES | Như "Va thùng sắt", độ mạnh 70% |

**Hiệu ứng vật cản (2026-11-03).** Gọn, mỗi khoảnh khắc dưới 0,9 giây, không chặn thao tác; có loé sáng sao bốn cánh và sao lấp lánh như va chạm thường. Code ở `src/ui/obstacle_fx.gd`, nối trong `board_view.gd`; số đo cỡ theo ô.

| Khoảnh khắc | Diễn biến | Số đo |
| --- | --- | --- |
| Va thùng sắt | Ô thùng rung cứng và nhanh theo hướng va (ép ít, dao động tắt dần); nắp loé trắng rồi một vệt sáng quét chéo từ góc trên trái xuống, bốn đinh loé sao lần lượt khi vệt sáng đi qua; tia lửa thép trắng vàng toé ngược về phía khối va rồi rơi, vài tia đỏ cam nặng rơi sớm; loé trắng xanh với vòng sóng rõ | Ép 7%, 3,5 nhịp, 0,42 giây; vệt sáng 0,27 giây; 12 tia lửa 6–15 ô/giây, 5 tia nặng; loé 1,9 ô |
| Va khối pudding | Khối bị va nhún mạnh như thạch; vài giọt pudding bắn ra; loé hồng | Nhún gấp 2,2 lần khối thường; 6 giọt |
| Va khối băng | Khối bị va nhún như khối thường; vài mảnh băng nhỏ toé ra, xoay; loé xanh lạnh | 6 mảnh |
| Chạm khối còn phủ | Pudding: khối nén dẹt từ đáy rồi rung như thạch tại chỗ. Băng: lắc ngang như khối sương mù. Không âm thanh riêng | Nén 0,16, 0,5 giây (`COVER_SQUISH*`) |
| Pudding vỡ (khối kề chạm thanh hoặc bị búa gõ) | Khối nảy nhẹ; lớp pudding phồng ra và mờ đi; bọt pudding bóng toả tròn rồi rơi, giọt nhỏ bắn xa; loé hồng lớn với vòng sóng, sao lấp lánh. Bóc lớp ngoài của khối 2 lớp: cùng kiểu nhưng nhỏ bằng nửa (`COVER_HALF`), lớp dày phồng ra rồi tan, còn lại lớp mỏng | Lớp pudding to 1,28 lần trong 0,3 giây (lớp ngoài 1,14 lần); 16 bọt, 14 giọt; loé rộng bằng khối + 2,2 ô |
| Băng vỡ (cùng lúc như pudding) | Khối nảy nhẹ; lớp băng phồng ra và mờ đi; mảnh băng trong như kính bung tròn rồi rơi xoay; một làn hơi lạnh phồng ra rồi tan; loé xanh trắng lớn với vòng sóng, sao lấp lánh. Lớp ngoài của khối 2 lớp nhỏ bằng nửa | 18 mảnh, 8 làn hơi; loé rộng bằng khối + 2,2 ô (`ObstacleFx.frost_burst`) |
| Va hoặc chạm khối bị xích | Khối rung (khi chạm), tia lửa thép toả nhanh từ ổ khoá hoặc điểm va, loé trắng nhỏ; khối chìa phồng lên để chỉ chỗ | 9 tia, sống 0,32 giây; loé 1,3 ô |
| Xích đứt (chìa đã thoát) | Ổ khoá bật quai, phóng to, xoay và bay lên rồi mờ; mắt xích văng tung, xoay rồi rơi; lớp xích phồng ra mờ dần; tia lửa vàng, loé vàng lớn, sao lấp lánh | Ổ khoá 0,55 giây, to 1,6 lần, bay lên 0,9 ô; 12 mắt xích, 12 tia lửa |
| Sương tan (khối kề rời đi) | Khối lộ màu thật ngay và nảy nhẹ; lớp sương tách ra, phồng ra và tan dần trên khối | Sương to 1,15 lần trong 0,45 giây; nảy 1,08 lần |
| Va hộp giấy | Bụi giấy và 3 mẩu giấy bay lả; loé màu giấy nhỏ | Loé 1,3 ô |
| Hộp bay ra (lớp ngoài thoát) | Hộp giấy lao về thanh cùng màu như khối thoát (có gió hút), kẹo bên trong ở lại, nảy và loé, sao lấp lánh màu mới; tới thanh thì thanh lăn và hộp rách tung thành giấy vụn (màu hộp, giấy kraft, băng dán) bay lả theo hướng đi | 0,22–0,35 giây tới thanh; 22 mẩu giấy, sống 0,9 giây |
| Ruy băng bay ra (bóc một lớp) | Lớp ruy băng ngoài (các dải satin cùng nơ, màu cũ, không có kẹo) lao về thanh cùng màu như hộp giấy (có gió hút); khối ở lại đổi sang màu lớp kế với ít hơn một dải, nảy và loé, sao lấp lánh màu mới; tới thanh thì thanh lăn và ruy băng bung thành sợi satin uốn lượn (màu ruy băng, đậm nhạt) bay lả theo hướng đi (`ObstacleFx.ribbon_burst`) | Như hộp bay ra; 14 sợi, sống 1 giây; loé rộng bằng khối + 1,4 ô |

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
| Khối crystal qua thanh (2026-11-08: ánh lăng kính, `src/ui/crystal_grind.gd`) | Như khối thường, thêm mảnh kính phun theo hướng đi lúc chạm, và ánh lăng kính suốt lúc nghiền, gọn quanh chỗ cắt. **Tia lửa bảy sắc** toé ra từ hai mép bên của khối, chạy dọc mặt trong của thanh về hai phía và hơi ngả vào bàn, như máy mài cắt kẹo kết tinh; khối thoát hướng nào cũng thấy. Ở mỗi mép có một sao trắng nóng nhấp nháy, lúc chạm thanh thì nở to rồi về. **Vạch cắt** dạng lens flare ở mặt trong của thanh: lõi trắng, quầng bảy sắc (đỏ tới tím theo bề ngang khối), dài hơn khối một chút, chập chờn; sao nhỏ lấp lánh dọc vạch. **Quạt lăng kính**: tia bảy sắc toả ra từ mặt ngoài của thanh theo hướng đi, màu đỏ tới tím theo bề ngang khối, chập chờn và quét nhẹ; kim tuyến bảy sắc phun theo. **Cú chốt** lúc đuôi khối qua hết: sao bốn cánh lớn loé và xoay ở mặt ngoài thanh, vòng sóng bảy sắc toả ra ngoài, nổ một nhúm kim tuyến; quạt vụt dài ra rồi tắt. Màu bảy sắc và xanh băng vẽ trộn thường để nổi trên nền bàn và nền màn sáng, chỉ lõi trắng vẽ cộng sáng; vụn kẹo bay đè lên ánh sáng | 8 mảnh kính. Hiện rõ trong 0,08 giây sau khi chạm, tắt trong 0,24 giây sau khi đuôi qua; tắt hẳn 0,45 giây sau khi đuôi qua. Tia lửa: mỗi bên 26 tia mỗi 0,24 giây nghiền, dài 0,3–0,6 ô, 4–9 ô/giây, hãm 8–14 ô/giây², ngả vào bàn 0,3 rad, sống tới 0,24 giây (bay xa chừng 1,5 ô); sao ở mép 0,6 ô, lúc chạm to hơn 80% rồi về trong 0,15 giây. Vạch cắt: quầng rộng 0,16 ô, dài quá mỗi bên khối 0,5 ô, lõi 0,05 ô quá 0,8 ô; 3 sao nhỏ 0,5 ô, mỗi sao loé mỗi 0,15 giây. Quạt: 9 tia, mở ±0,5 rad, dài 0,75 và 1,45 ô xen kẽ, vụt dài thêm 40% lúc tắt; kim tuyến 16 hạt mỗi 0,45 giây nghiền, 2,5–6 ô/giây. Cú chốt: sao 1,7 ô trong 0,3 giây; vòng sóng mở ±2 rad, to tới 1 ô trong 0,32 giây; 10 kim tuyến |
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
| `icon_app` | `icon` rồi sửa nhiều bước bằng `edit_game_image`, nền đặc (`art/images/icon_app_candy.png`, 2026-11-09) | 1024 → 512, 192 và các lớp adaptive 432 (`tools/make_app_icon.gd`) | Khối kẹo chữ L hồng đậm sọc chéo, liền một khối, bay lên khỏi khay nhỏ màu nhạt và mờ, vệt trắng trượt dưới khối, nền hồng nhạt chuyển sang tím lavender; khối là chủ thể. Icon đơn sắc (Android 13) là hình L phẳng có sọc và vệt trượt |
| `bg_home` | `background` | 768×1664 → rộng 720 | Nền ít chi tiết, phần giữa yên để bàn cờ nổi; cắt được cho 360×640 |
| `bg_level` | Ảnh có sẵn (`art/images/bg_level_candy.png`) | 880×1787 → rộng 720 | Phong cảnh kẹo, giữa là bãi cát trống cho bàn cờ; code phủ dim và cắt kiểu cover theo màn |
| `bg_shop` | `background` (`art/images/bg_shop_candy.png`) | 896×1920 → 886×1920 | Nền màn Shop: gradient pastel hồng → tím nhạt, kẹo mờ ở hai mép, giữa trống để thẻ gói nổi; kéo giãn phủ kín màn |
| `block_surface` | Bỏ | | Không còn dùng: chất liệu khối vẽ hoàn toàn bằng code (xem Concept theme) |
| `ui_gold`, `ui_heart`, `ui_hint`, `ui_moves`, `ui_smash` | `icon`, nền trong | 1024 → 128 | Gold, mạng, 3 booster (bản cũ; booster nay dùng `booster_*`) |
| `booster_hint`, `booster_move`, `booster_smash` | Cùng một phong cách sticker phẳng của Smash: viền đậm, tô khối 2-3 tông phẳng, mảng sáng trắng, không gradient. Smash: `edit_game_image` từ bản cũ. Hint, Move (2026-11-04, lần 3): `edit_game_image`, ảnh 1 là `booster_smash.png` làm mẫu phong cách, ảnh 2 là bản kẹo 3D trước đó (`art/images/booster_*_candy_ai.png`, chọn từ bảng `art/concepts/concept_booster_candy_v1.png`) làm mẫu nội dung, nền trong. Cắt bằng `tools/fit_icon.gd` | 1024 → 256 | Bóng đèn kẹo chanh, đế kẹo hồng có ren, ba tia kẹo; chữ "+3" kẹo dẻo xanh lá có vệt xoắn; búa kẹo mút (hai mặt kẹo xoắn hồng trắng, thân sọc, nơ hồng, cán que trắng; 2026-11-03 sửa từ `booster_smash.png` cũ, ảnh gốc `art/images/booster_smash_lollipop_ai.png`, cùng ảnh cắt 384 px làm `fx_lollipop_hammer` cho hiệu ứng Phá khối). Move dùng chữ "+3" thay cho mũi tên vòng để khỏi lẫn với nút restart |
| `hud_btn_restart`, `hud_btn_settings`, `hud_booster_hint`, `hud_booster_move`, `hud_booster_smash`, `hud_panel`, `hud_moves_panel`, `hud_pill`, `hud_badge_plus`, `hud_badge_count` (`assets/ui/hud/`) | `edit_game_image`, nền trong, tham chiếu `art/concepts/ref_hud_candy.png` (cắt từng nút ở `art/images/hud_ref/`); cắt bằng `tools/fit_icon.gd --solid=200` | 1024 → 192 (nút tròn), 256 (booster), 288×185 (khung MOVES, 9-slice ~44 px), 96×44 (pill, 9-slice ~22 px), 96 (huy hiệu) | Bộ HUD kẹo thạch tím theo ảnh ref: nút tròn restart, bánh răng; 3 booster vuông bo có glyph trắng hồng (búa kẹo mút mặt xoắn hồng, sửa 2026-11-03 từ ảnh nút cũ; số 3 trong vòng mũi tên đầu hồng, bóng đèn có vòng xoắn hồng, sửa 2026-11-04 theo búa: glyph trắng hồng, một điểm nhấn hồng); khung MOVES và pill độ khó để trống, chữ và số vẽ bằng code; huy hiệu xanh dấu + (hết booster) và tròn trống (số còn lại). `hud_panel` (squircle, cạnh cong nên không 9-slice) chưa dùng |
| `ui_shop`, `ui_settings`, `ui_lock`, `ui_restart`, `ui_video`, `ui_gift`, `ui_profile`, `ui_sound`, `ui_music` | `icon`, nền trong | 1024 → 128 | Nút và trạng thái; tắt âm thì code vẽ gạch chéo |
| `art_win`, `art_lose`, `art_no_lives` | `ui`, nền trong | 1024 → 512 | Thẻ thắng, popup thua, màn hết mạng |
| `art_lose_tear` | Cắt từ `art_lose` (`tools/split_tear.gd`) | 32×35 | Giọt nước mắt của popup thua, chảy xuống má; `art_lose` đã bỏ giọt này |
| `avatar_00`–`avatar_12` | `icon`, nền trong | 1024 → 256 | Avatar; `00` là mặc định |
| `frame_00`–`frame_12` | Vẽ bằng code (`python3 tools/gen_frames.py`, không AI), nền trong; nguồn `art/images/frame_XX_candy.png`. Theo ảnh ref `assets/ui/figma/ava_frame.png` (2026-11-04): vuông bo góc kín canvas, bán kính góc 24/124, viền 10/124 (mép trong trùng chỗ avatar thụt 8%; góc avatar bo to hơn góc lỗ nên thanh trên Home cho avatar thụt 3% để không hở góc), đổ sáng phẳng 3 tông từ trên | 1024 → 256 | Frame bao avatar, giữa trong suốt; `00` là mặc định (vẽ lại đúng ref, viền 8/124). 01–12 từ đơn giản tới cầu kỳ: hồng bubblegum trơn, bạc hà chip sô-cô-la, việt quất đường lấp lánh, kẹo gậy sọc đỏ trắng, kem dâu rắc cốm, nho với jelly bean, sô-cô-la sốt caramel và ngọc trai, thạch xanh ngọc với kẹo gum ở góc, đai cầu vồng, tim đỏ có nơ hồng, kem viền bắt bông có cherry, caramel vàng gắn đá quý. Thay bộ vòng tròn AI cũ (`art/images/frame_XX.png`) |
| `mech_stone`, `mech_ice`, `mech_chain`, `mech_key`, `mech_fog` | `image`, nền trong | 512 → 128 | Lớp phủ cơ chế sau demo |
| `lb_piece` (`assets/ui/lb_piece.png`) | `edit_game_image`, nền trong, một vùng cắt của ảnh ref `concept_candy_board_v4_crystal_semi.png` làm tham chiếu chất liệu; nguồn `art/images/lb_piece_cube.png`; cắt bằng `tools/fit_icon.gd --size=128 --margin=0.04` | 1024 → 128 | Mảnh leaderboard: một khối lập phương kẹo crystal 3D nhìn chéo từ trên (thấy mặt trên và hai mặt bên), màu loang mềm qua xanh dương, tím hồng, vàng hổ phách, xanh lá; viền đường cát, vệt bóng trên trái, vết nứt mảnh |
| `ic_chain_offer` (`assets/ui/ic_chain_offer.png`) | `edit_game_image`, nền trong, hai lượt: lượt 1 lấy `assets/ui/figma/ic_store.png` và `ic_leaderboard.png` làm mẫu phong cách (`art/images/chain_icon/chain_icon_a.png`), lượt 2 gom bố cục trên kết quả lượt 1 (nguồn `chain_icon_d.png`); cắt bằng `tools/fit_icon.gd --size=192 --margin=0.02` | 1024 → 192 | Icon Chain Offer ở cột phải Home (2026-11-08): ba hộp quà nối bằng xích vàng theo đường chéo, hộp hồng nơ vàng to phía trước, hộp tím ruy băng hồng ở giữa, hộp xanh ngọc ruy băng vàng nhỏ trên phải; kiểu sticker viền đậm như các icon Figma của Home. Bỏ phương án rương quấn xích vì trông như rương bị khoá |
| `candy_drop_00`–`candy_drop_07` (`assets/ui/candy_drop/`) | `edit_game_image`, nền trong, tham chiếu là đống kẹo cắt từ `assets/ui/loading_bg.png` (`art/images/candy_drop/ref_loading_candies.png`); nguồn `art/images/candy_drop/`; cắt bằng `tools/fit_icon.gd --size=256 --margin=0.02 --solid=200` (sao thêm `--floor=8` vì một pixel lạc ở góc) | 1024 → 256 | Kẹo của màn chuyển cảnh kẹo rơi: kẹo bạc hà xoắn đỏ trắng, xanh trắng, kẹo mút xoắn cam (không que), kẹo dẻo trái tim hồng, sao vàng, gumdrop xanh lá, viên kẹo vuông tím sọc, xanh dương sọc; cùng chất kẹo cứng bóng trong của ảnh loading. `candy_drop_00` còn là icon chạy trên thanh tải của màn loading và màn tải dữ liệu |
| `gift_lid`, `gift_body` (`assets/ui/gift_curtain/`) | `start_game_image` (`asset_type=ui`), 896×1920, hộp quà chính diện phủ kín khung, nắp hồng chấm bi cao gần nửa khung, thân tím lavender, ruy băng dọc; nguồn `art/images/gift_curtain/box_c_tall_s7321.png` (bản nắp thấp `box_a`, `box_b` và bản edit `box_d` mất ruy băng trên nắp, bỏ); cắt bằng `python3 tools/cut_gift_curtain.py` (bỏ viền trắng, góc bo, dải bóng dưới mép nắp) | 896×1920 → 864×792, 864×1014 | Nắp và thân của màn chuyển cảnh nắp hộp quà Road Trip |
| `gift_bow` (`assets/ui/gift_curtain/`) | `start_game_image` (`asset_type=icon`), nền trong, 1280×1024; nguồn `art/images/gift_curtain/bow_s7311.png`; cắt bằng `tools/fit_icon.gd --size=560 --margin=0.02 --keep-aspect` | 1280×1024 → 560×434 | Nơ satin trắng ánh hồng trên mép nắp |
| `lb_banner` (đã bỏ khỏi `assets/ui/` ngày 2026-11-09, Leaderboard thành popup không banner; nguồn còn ở `art/images/`) | `start_game_image` (`asset_type=background`, `style=3d_render`), 1536×448; ba phương án nguồn `art/images/lb_banner_a.png` (đồi kem, mây pastel), `lb_banner_b.png` (vương quốc kẹo ban đêm), `lb_banner_c.png` (sân khấu kẹo); dùng C, bỏ kênh alpha (ComfyUI trả alpha 249–255) | 1536×448 | Banner màn Leaderboard (2026-11-05): rèm kẹo sọc hồng xanh hai bên, kẹo mút và khối thạch ở hai góc dưới, giữa là bục sáng có tia sáng cho huy hiệu giải; nền xanh hợp màu màn |

**Âm thanh** (danh sách và thời lượng là đề xuất của mình)

| File | `category` | Tạo → dùng | Dùng ở |
| --- | --- | --- | --- |
| `sfx_button`, `sfx_tap` | `One-shot` | 1 giây → cắt còn tối đa 0,2 giây | Bấm nút, chạm khối |
| `sfx_exit` | `SFX` | 1 giây → khoảng 0,4 giây | Hộp giấy (lớp ngoài) rách ở thanh, gọi bằng tên `box_tear` và dùng tạm khi chưa có tiếng giấy riêng |
| `sfx_blocked` | `SFX` | 1 giây → khoảng 0,3 giây | Khối va chạm rồi bật về; thiếu `sfx_bump` thì dùng thay |
| `sfx_shatter` | `SFX` | 2 giây → bỏ 0,25 giây đầu, lọc thông thấp 3 kHz, làm mềm đầu tiếng 3 ms, 0,7 giây | Khối bị nghiền qua thanh (phát lúc khối chạm thanh, rung 15 ms): kẹo vụn êm, khô, dày trong 0,4 giây đầu rồi lách tách thưa dần như vụn kẹo rơi, không vang, không tiếng rít hay tiếng thuỷ tinh (thuỷ tinh là của `sfx_crystal`). Không giòn gắt: tâm phổ khoảng 1,8 kHz, năng lượng dồn vào 300 Hz–4 kHz (vẫn trong dải loa điện thoại), từng tiếng tách không bật lên tức thì. Độ to đỉnh nhỏ hơn `sfx_exit` khoảng 2,5 dB vì phát ở mọi lần khối thoát |
| `sfx_bump` | `SFX` | 1 giây → 0,14 giây | Kẹo va vào kẹo: một cú thịch trầm, mềm. Nguồn mp3, xử lý bằng `tools/process_sfx.gd` |
| `sfx_coin`, `sfx_hint`, `sfx_moves`, `sfx_smash`, `sfx_life_lost` | `SFX` | 2 giây → tối đa 1 giây | Nhận gold, 3 booster, mất mạng |
| `sfx_win`, `sfx_lose`, `sfx_clap` | `SFX` | 3 giây | Thắng, thua, vỗ tay khi nghĩ lâu rồi đi đúng |
| `sfx_stone`, `sfx_ice`, `sfx_pudding`, `sfx_chain`, `sfx_layer`, `sfx_fog`, `sfx_gate`, `sfx_ribbon` | `SFX` | 2 giây → tối đa 1 giây | 8 cơ chế sau demo (`sfx_ice` cho băng vỡ, `sfx_pudding` cho pudding vỡ, `sfx_ribbon` lúc chạm bóc ruy băng; ruy băng bung ở thanh dùng `sfx_exit`) |
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

**2026-11-08**

- Mở game vào thẳng level (người dùng yêu cầu; mục 2): màn loading đầy thì hiện ngay level đang tới, không qua Home và không chạy màn chuyển cảnh (người dùng bỏ màn chuyển cảnh ở trường hợp này). Hết mạng hoặc demo hết level thì vẫn vào Home. Popup tự mở ở Home (Chain Offer, hướng dẫn Road Trip) hiện khi người chơi về Home lần đầu trong phiên. Level mở lúc khởi động vẫn ghi `level_start` như mọi lượt; `boot.ms` không đổi (đo lúc `Game.boot()` xong).
- Số khối vuông nhỏ lúc nghiền qua thanh cố định cho mỗi khối (người dùng yêu cầu; mục 8 "Nghiền qua thanh"): 22 khối vuông (mỗi khối kèm 1 mảnh nhỏ hơn) dù khối 1 ô hay nhiều ô, trước là 22 khối vuông mỗi ô. Khối 1 ô (phần lớn khối từ L14) không đổi; khối nhiều ô vụn thưa hơn.
- Mảnh nghiền to gấp 1,5 lần, thưa và bay xa hơn; số mảnh theo bề ngang khối thay cho 22 cố định (người dùng yêu cầu; mục 8 "Nghiền qua thanh"). Bề ngang là số cột ô khối phủ dọc thanh, tính cho cả khối: khối dài theo hướng đi không ra thêm. Khối rộng 1 ô ra 15 mảnh to và 10 mảnh nhỏ; mảnh nhỏ thành số đếm riêng, không còn 1 mảnh nhỏ đi kèm mỗi mảnh to (trước 22 + 22). Mỗi ô bề ngang thêm ra thêm 0,5 lần, làm tròn (rộng 2 ô ra 23 + 15, rộng 3 ô ra 30 + 20). Các bản trước trong cùng ngày, người dùng đổi lại ngay: to gấp 2,5 với 1,5 khối vuông mỗi ô bề ngang (khối 1 ô chỉ ra 2), rồi to gấp 1,8 với 22 + 22 × 1,5 mỗi ô thêm, rồi 20 to + 10 nhỏ với 0,8 lần mỗi ô thêm. Thưa: vị trí ngang theo dãy tỉ lệ vàng thay cho ngẫu nhiên, lệch ra ngoài thanh tới 0,4 ô (trước 0,15). Xa: phun 3–7,5 ô/giây (trước 2,2–5,5), toả ngang 0,8 (trước 0,5), hãm 1,2 (trước 1,8), bay chừng 2–5 ô (trước 1–3).
- x2 trên thẻ thắng xong thì gold bay từ ô gold của thẻ lên chip gold của thanh trên, rồi thẻ tự sang màn kế (người dùng yêu cầu; mục 4 "Thẻ thắng và thẻ thua"). Trước đây x2 xong vẫn phải bấm Tiếp tục. Màn level không có ô gold nên thanh trên (`HubTop`, chỉ mạng và gold) chỉ hiện lúc gold bay.
- Thêm `sfx_shatter`, tiếng khối bị nghiền qua thanh (người dùng yêu cầu; mục 8 "Âm thanh"). Trước đây chưa có file nên lúc này phát tạm `sfx_exit` (tiếng vút trượt). Tiếng mới là kẹo cứng vụn giòn rồi thưa dần, hợp với người chơi casual thư giãn và theme kẹo: mềm, khô, không chói, nghe nhiều lần không mệt. Chọn trong 8 bản AI vì không có vạch rít, ít cắt đỉnh nhất, dải trung đủ cho loa điện thoại. Hộp giấy rách ở thanh trước cũng gọi `shatter`; nay gọi `box_tear` và vẫn phát `sfx_exit` cùng rung 15 ms như cũ, để giấy không kêu như kẹo. `tools/process_sfx.gd` có thêm `--start=` để bỏ tiếng lách tách và khoảng lặng ở đầu bản AI.
- `sfx_shatter` êm hơn (người dùng yêu cầu vì bản đầu giòn quá; mục 8 "Âm thanh"): xử lý lại từ cùng bản gốc, lọc thông thấp 3 kHz và làm mềm đầu từng tiếng tách trong 3 ms. Tâm phổ 5,0 → 1,8 kHz, năng lượng trên 4 kHz khoảng 40% → 3,5%, độ to đỉnh giảm 2 dB và nay nhỏ hơn `sfx_exit` khoảng 2,5 dB. `tools/process_sfx.gd` có thêm `--lowpass=` và `--soften=`; không truyền thì ra đúng file như trước.
- Khối to hơn, ít khối 1 ô (người dùng yêu cầu; mục 4). Bước đầu chỉ đổi trọng số gộp khi cắt khối: L14–100 khối 1 ô chỉ giảm 71% → 63%, vì hình chỉ khoảng 1,4 ô mỗi khối nên ít nhất 58% khối buộc phải 1 ô. Người dùng chọn: từ L14 số khối nhân 1,5 thay cho 2 (`DifficultyCurve.SHAPED_COUNT_SCALE`; L14–100 trung bình 58 → 45 khối, MOVES 69 → 55); hình khoảng 3 ô mỗi khối như Road Trip (`MOTIF_FILL` 1,15–1,8 → 2,5–3,4); mỗi khối tối đa 7 ô (`Config.BLOCK_MAX_CELLS`); khối xếp có chủ đích theo ba kiểu xen kẽ (đối xứng tự do, hình học, theo vùng vẽ), áp dụng cả L5–13 (L5–13 bỏ hình sinh ngẫu nhiên, dùng hình vẽ tay). Thư viện hình 21 → 27 hình (thêm thanh sô-cô-la, hộp quà, hũ kẹo, bánh kem, kem que, macaron), mỗi hình thêm cỡ lớn 116–182 ô và vài cỡ tí hon 36–40 ô; mọi bản vẽ ghi vùng bằng chữ cái. Trọng số gộp: 5^(số khối 1 ô được gộp)/cỡ² (`Config.TILE_SINGLE_BIAS` = 5). Sinh lại L5–100 bằng lệnh phát hành, L1–4 làm tay không đổi. Đo trên L1–100 đóng gói so với bản đã commit: L5–13 khối 1 ô 40% → 4%, lớn nhất 17 → 6 ô; L14–100 khối 1 ô 71% → 5%, 1,43 → 2,91 ô mỗi khối, lớn nhất 10 → 7 ô. Để sinh trong game vẫn dưới 200 ms (500 level seed 0: trung bình 35 ms, chậm nhất 141 ms): cắt khối chọn nhiều cách gộp không chung nhóm trong một lần quét; thùng sắt chắn cả bốn hướng của một khối thì đặt lại và cắt lại; bàn cổng nhịp thử thêm cạnh đặt cổng, 2 cổng không được thì còn 1; level dạy xích luôn xích khối thứ hai trong thứ tự giải vào khối thứ nhất; kiểm "không phải chờ cổng" và cách chơi tham lam của Solver dùng cổng lúc nó mở trước (`min_taps` không đổi vì tham lam không chờ là tối ưu). `test_deterministic` chỉ đòi `generate(id, level.seed)` ra đúng level khi level sinh được trước lần thử thứ 20 (`LevelGenerator.COUNT_RELAX_EVERY`), vì từ lần đó bộ sinh bớt khối mục tiêu.
- Home bấm Chơi và nạp mạng xong ở màn hết mạng vào level qua màn chuyển cảnh kẹo rơi mới `candy_curtain` (người dùng yêu cầu, theo video mẫu của một game khác; mục 2): kẹo rơi xếp chồng từ trên xuống tới khi phủ kín màn, rồi rơi khỏi màn từ dưới lên. Daily Challenge giữ hai cánh kẹo `level_curtain`; `curtain_swap` của Main nhận thêm loại màn chuyển cảnh. 8 ảnh kẹo vẽ bằng ComfyUI theo đống kẹo của ảnh loading (`candy_drop_*`, mục "Tài nguyên").
- Màn kẹo rơi đổi cách rơi (người dùng yêu cầu; mục 2): từng viên rơi từ trên xuống và đầy dần từ dưới lên, thay cho cả hàng rơi cùng lúc và chồng từ trên xuống; mỗi lần một loại kẹo ngẫu nhiên thay cho 8 loại trộn; kẹo to hơn (4 viên mỗi hàng, 1,6 lần khoảng cột, trước 5 viên và 1,5 lần) và chậm hơn (phủ kín chừng 1,9 giây, trước 0,45 giây). Lúc mở, cả đống rơi qua đáy màn thay cho từng hàng rơi từ dưới lên, để khớp với kiểu đổ đầy từ đáy.
- Road Trip vào level và về bản đồ qua màn chuyển cảnh nắp hộp quà mới `gift_curtain` thay cho hai cánh kẹo (người dùng yêu cầu; mục 2). Người dùng chọn: chỉ Road Trip (Daily Challenge giữ hai cánh, Home dùng kẹo rơi), nắp trượt xuống và thân hộp trượt lên khớp ở mép nối, giữ logo nảy ra trên nắp, màu hồng tím pastel của màn hai cánh. Chỉnh lại cùng ngày: nắp rơi khi thân đi được 30% quãng đường (trước là 55% thời gian, tức gần hết đường), logo rơi theo nắp và bật khi nắp rơi được 50% quãng đường thay vì đợi nắp chạm thân. Ảnh nắp, thân và nơ vẽ bằng ComfyUI (`gift_lid`, `gift_body`, `gift_bow`, mục "Tài nguyên").
- Khối crystal qua thanh có ánh lăng kính (người dùng yêu cầu "đẹp choáng váng nhưng vẫn nhỏ gọn"; mục 8 "Khối crystal qua thanh", `src/ui/crystal_grind.gd`): tia lửa bảy sắc toé dọc mặt trong của thanh từ hai mép khối, vạch cắt lens flare, quạt tia bảy sắc ở mặt ngoài, cú chốt sao loé và vòng sóng bảy sắc. Chọn tia lửa dọc thanh làm điểm nhấn vì phía ngoài thanh trái, phải sát mép màn, quạt ra ngoài thanh hầu như không thấy; màu vẽ trộn thường vì lớp cộng sáng trắng bị bệch trên nền bàn hồng nhạt. Tắt hẳn 0,45 giây sau khi đuôi khối qua thanh.
- Xích, chìa và sương mù vẽ lại (người dùng yêu cầu; mục 4 "Cơ chế sau bản demo", mục 8): xích còn một đường chéo thay cho chữ X; khối chìa mang ảnh chìa to giữa một ô thay cho huy hiệu nhỏ ở góc, bỏ đường nét đứt nối chìa với khối bị xích; sương mù thành lớp sương phủ chồng lên khối, viền mờ dần và lấn nhẹ sang khối bên cạnh, thay cho vòng tròn và nét cung trắng trong từng ô; sương tan thành lớp sương phồng ra rồi tan thay cho khối xám mờ dần. Lý do chính là hiệu năng: mỗi vòng tròn, nét cung, mắt xích là một draw call riêng trong renderer Compatibility, nên L79 tốn 882 draw call mỗi khung, L98 1585, L100 1461; nay sương nằm trong shader thân khối, xích là một triangle array có cache, còn 239, 224, 231 (GPU máy dev 4,1 → 2,9 ms, 3,8 → 2,3 ms, 3,7 → 2,2 ms). Hình xích phải cache: dựng lại mỗi lần vẽ thì chậm gấp 3 cách vẽ cũ (khoảng 2,3 ms so với 0,8 ms mỗi khối), có cache còn khoảng 0,1 ms. Sương chỉ lấn được trong lề texture SDF (0,31 ô) nên lấn tối đa 0,24 ô cộng độ xô lệch của viền.
- Thanh cổng nhịp lúc đóng vẽ lại (người dùng yêu cầu "dạng đẹp hơn"; mục 8 "Khung cổng"): bỏ cách tối thân 55% và các vạch trắng ngang thanh, vì thanh vàng tối thành nâu bùn, thanh xanh thành xám lục, vạch trông như thước kẻ. Thay bằng sọc kẹo gậy trắng chéo trên thân ngả về màu đậm của cổng, và huy hiệu ổ khoá thay mũi tên, nên cổng đóng vẫn cùng chất liệu kẹo, vẫn đọc được màu cổng, nhìn qua là phân biệt đóng với mở. Trạng thái mở giữ nguyên từng pixel.
- Hình cổng nhịp đổi sau hoạt ảnh của lượt chạm thay cho ngay lúc chạm (người dùng báo lỗi; mục 8 "Khung cổng"): trước đây cổng đổi hình ngay lúc chạm, nên khối dội lại khi cổng đã mở ra, còn khối nghiền qua khi cổng đã khoá. Giờ cổng khoá chỉ mở sau khi khối dội về xong, cổng mở chỉ khoá sau khi khối nghiền qua hết thanh. Luật trên board không đổi.
- 500 level thường bám game tham khảo Tap Block Out (người dùng yêu cầu; mục 4 "Đường cong độ khó L1–500", "Cơ chế sau bản demo", "Hình dạng level"): số khối, số lượt dọn bàn và tag Hard/VeryHard của từng level L1–500 lấy theo số đo game tham khảo, tag giữ đúng level (chỉ L70 dời sang L71). Số khối kẹp 12–60 vì giới hạn của hình vẽ tay, nên level VeryHard trung bình 59 khối so với 78 của game tham khảo. Bộ sinh lái độ sâu chuỗi chặn lúc gán hướng để bám số lượt dọn bàn. Mỗi level tối đa 3 cơ chế, cứ 4 level có một level nghỉ không cơ chế. Trọng số gộp khối 1 ô từ 5 xuống 1,5 nên tỉ lệ khối 1 ô từ khoảng 5% lên khoảng 11%. Hình vẽ tay, kiểu cắt và cỡ khối tối đa giữ nguyên. Daily Challenge sinh trong game ở chế độ nhanh (không cắt lại vì số lượt), mỗi bàn dưới 200 ms trên máy dev. Dư MOVES giữ như cũ, dù game tham khảo dư nhiều hơn ở level Hard và Super Hard (trung bình 4,7 và 5,8 so với 4,5 ở level thường).
- Nút X đóng popup to gấp đôi, vùng chạm rộng gấp 2,2 lần (người dùng yêu cầu; mục 2): đổi lúc chạy trong `UnityUI._grow_close` cho mọi nút X của layout Unity (`btnTurnOff`, `ExitButton`...), scene không đổi. X lọt ra ngoài màn thì dịch vào trong.
- Tắt Daily Challenge (người dùng yêu cầu; mục 4 "Phạm vi"): thêm nhóm công tắc `Config.FEATURES` (theo tên trong `Config.UNLOCK`, thiếu khoá là bật; Remote Config `features_<tên>`), `Unlocks` coi tính năng tắt là chưa mở ở mọi level và bỏ khỏi thẻ thắng. `challenge` = false: Home ẩn icon, không còn mốc L50. Code và màn giữ nguyên để bật lại.
- Đổi luật cổng nhịp (người dùng yêu cầu; mục 4): trước đây mọi lần chạm hợp lệ (khối màu bất kỳ, kể cả bị chặn) đều đảo mọi cổng nhịp; giờ cổng chỉ đổi khi khối cùng màu chạm tới thanh: dội vào cổng khoá thì mở, một khối qua thì khoá lại. Người dùng chọn: giữ tên "Cổng nhịp", chỉ đổi câu mô tả (`mech_pulse_desc`, 14 ngôn ngữ; bản tiếng Hàn viết lại bằng chữ có sẵn trong font con); cú dội tốn 1 MOVES và tính sẵn trong MOVES; Gợi ý chỉ cú dội khi không còn khối nào đi được; cổng đặt ở cạnh ít lần qua nhất, không trần số cú dội; lúc đầu mở hay khoá 50%, L90 khoá; giữ trần 52/40 khối. Số cú dội của một cạnh luôn là số lần qua cạnh đó (trừ 1 nếu mở sẵn) dù đi theo thứ tự nào, nên Solver bỏ phần tìm chính xác và đi tham lam (khớp BFS trên bàn ngẫu nhiên); bộ sinh bỏ `_fix_gates`/`_no_wait` (kiểm "không phải chờ cổng"). Sinh lại L1–500 bằng lệnh phát hành: 454 level không có cổng không đổi, 46 level có cổng sinh lại, trung bình thêm 7 cú dội mỗi level, nhiều nhất 17 (L90: 2 cú dội, MOVES 36).
- Icon chạy trên thanh tải của màn loading đổi thành viên kẹo bạc hà xoắn đỏ trắng `candy_drop_00` thay cho viên kẹo cam hình thoi của prefab (người dùng yêu cầu; mục 2, `Splash.HANDLE_TEX`). Màn tải dữ liệu dùng chung `Splash.loading_screen()` nên đổi theo.
- Xích của khối bị xích thu nhỏ và nằm gọn trong khối (người dùng yêu cầu; mục 4 "Cơ chế sau bản demo"): trước đây đường xích chìa ra ngoài mép khung 0,08 ô cộng nửa mắt xích nên đè lên khối bên cạnh. Nay hai đầu lùi vào 0,24 ô (`BoardFx.CHAIN_IN`, mắt đầu vẫn trong góc bo 0,25 ô), mắt xích nhỏ còn khoảng 0,7 lần (mắt tròn 0,15 × 0,085 → 0,105 × 0,06 ô, nét 0,042 → 0,03 ô, cách nhau 0,21 → 0,15 ô), chỉ giữ mắt có cả bốn đầu mút trên ô của khối, số khoảng luôn chẵn để hai đầu là mắt tròn. Mắt xích văng lúc xích đứt nhỏ theo. Ổ khoá giữ cỡ cũ.
- Khối còn trong sương mù chạm vào không đi nữa (người dùng yêu cầu; mục 4 "Cơ chế sau bản demo"): trước đây khối ẩn màu, kể cả hộp giấy trong sương, vẫn trượt về thanh theo màu thật nên người chơi bấm mò mà vẫn đi được. Nay chạm khối ẩn chỉ lắc ngang tại chỗ (`BoardView._anim_fogged`), không tốn MOVES, không tính là nước đi; pudding, xích trên khối ẩn cũng chờ khối lộ ra. Với luật mới 79/120 level có sương mù bị kẹt (khối thường chờ khối sương, khối sương chờ khối kề rời đi), nên bộ sinh thêm `_fog_fix` bỏ sương ở khối gây kẹt và tính sương mù vào số lượt dọn bàn. Sinh lại L1–500 bằng seed gốc: chỉ 102 level có sương mù đổi (41 level chỉ bớt sương, 61 level ra bàn khác để bám đường cong, 2 level đổi MOVES), level không sương mù giữ nguyên; tổng khối sương 2.843 → 2.654, vẫn 120 level có sương mù. Chữ luật `mech_fog_desc` chưa đổi.
- Nối logic các màn đã dựng UI theo wireframe (người dùng yêu cầu, 2026-11-09): Win Streak 9.1–9.5 theo code `ME_WinStreak` của Unity (người dùng chọn: nhận thủ công từng mốc, đứt chuỗi tụt về mốc gần nhất, End chỉ tổng kết, tuần mới mất quà chưa nhận; mục 7 "Win Streak"), Remove Ads 2.4, Weekly Upsell 7.5, Rate 4.3, Keep Playing 4.6, Helper Pack 4.7, Booster soon 3.7, Free pick 3.9, chuyển level 3.1, update 1.2, chọn tài khoản 1.4, hướng dẫn đầu 1.5, mất mạng 1.6, Language 10.4 (Settings mở scene popup Language), Help 10.5 (nút Support của Settings mở popup Help: chọn chủ đề, viết nội dung, Gửi mở mail tới `CONTENT.support_email`, tiêu đề có chủ đề, thân có nội dung kèm level, ngôn ngữ, phiên bản), chờ video 11.1, không có video 11.2, popup thưởng 11.3/6.3, Shop Helper Packs và Bundles. Thêm 6 SKU (`remove_ads_bundle`, `helper_great`, `helper_epic`, `bundle_sweet`, `bundle_tasty`, `bundle_yummy`; nội dung do mình đề xuất, người dùng duyệt). Người dùng chọn giữ x2 ở thẻ thắng nên bỏ màn Bonus 4.2; bỏ 1.3 (game không tải dữ liệu) và 3.11 (không có tăng tốc); bỏ popup 3.3 vì giới thiệu cơ chế đã dùng popup 3.8 từ 2026-11-08. Màn 3.1 dùng khi sang level kế hoặc chơi lại, không thay màn hộp quà của Road Trip (người dùng chọn đặt ở Road Trip, nhưng Road Trip đã có màn nắp hộp quà từ 2026-11-08 nên mình đặt ở chuyển level; cần duyệt lại).
- Chain Offer mở popup Reward khi nhận thưởng một bước (người dùng yêu cầu, theo ảnh game tham khảo; mục 7 "Chain Offer"): thay dòng "Đã nhận thưởng! …" dưới đồng hồ, dòng này chỉ còn làm dự phòng. Cửa sổ trượt sau khi đóng popup để người chơi thấy bước kế.
- Leaderboard thành popup và tính theo tuần (người dùng yêu cầu, 2026-11-09; mục 7 "Leaderboard theo league"). Popup đè lên Home, có X, bỏ banner, thanh trên và thanh dưới. Nút "i" lên góc trái đầu khung, đối xứng với X, có ở cả hai tab. Thanh hai tab giữ ở đáy khung. PromoBox gồm huy hiệu giải hiện tại, tên giải và đồng hồ tới lúc hết tuần. Thưởng không còn hiện sẵn: chạm huy hiệu mới hiện bong bóng thưởng, theo `GiftPanelController` của Unity. Tab World bỏ nút "Phần thưởng"/"Thông tin", chạm huy hiệu trên thang để xem thưởng. Người dùng chọn: icon là giải hiện tại, bong bóng hiện thưởng của giải kế ("Đã nhận" ở giải cao nhất). Hết tuần thì xoá sạch: điểm về 0, về Silver, thưởng nhận lại từ đầu (không theo kiểu lên/xuống hạng theo vị trí của Unity). Tuần tính từ lúc mở khoá, các tuần nối liền nhau. Ngưỡng điểm hạ theo mốc 20 level/ngày tới Platinum, 60 level/ngày tới One Above All. Silver không còn thưởng. Không có thưởng theo vị trí. Thưởng lên giải còn chờ lúc hết tuần được giữ trong kết quả tuần. Vắng nhiều tuần chỉ hiện kết quả tuần gần nhất có điểm. Popup kết quả tuần hiện khi mở Leaderboard, Home có chấm đỏ. Thêm `lb_week_end`, `lb_join` thành mỗi tuần một lần. Bỏ `assets/ui/lb_banner.png`.
- Road Trip khó hơn 10% (người dùng yêu cầu, 2026-11-09; mục 7 "Road Trip", phần "Làm khó"): đổi hướng thoát của một số khối để lúc đầu có thêm 10% khối bị chặn (80,6% → 89,3%); hình, ô, lưới, số khối, bước, nhãn độ khó và cổng giữ nguyên. Người dùng chọn: tăng số khối bị chặn lúc đầu (không bớt bước, không cắt thêm khối, không đổi nhãn độ khó); mỗi level ×1,1 nếu tìm được, cả bộ phải đạt ×1,1; độ sâu chuỗi chặn không giảm; đổi ít khối nhất; giữ cổng. Bỏ khoá `source` (tên level gốc) khỏi 400 file, bỏ comment nhắc nguồn trong `tools/import_road_trip.gd` và `Config`; ghi chú nguồn ở mục 7 giữ lại. Thêm trong lúc làm: khối chỉ sang cạnh vắt hai cổng khi level không đạt mức theo cách khác (không có luật này thì khối vắt hai cổng 49 → 432, có luật còn 177, vẫn dưới 1% của test).
- Pudding đổi luật, thêm băng (người dùng yêu cầu, 2026-11-09; mục 4 "Cơ chế sau bản demo", "Hình dạng level"; mục 8 hiệu ứng): lớp pudding không còn vỡ bằng cú chạm. Khối phủ 1 hoặc 2 lớp, mỗi khối kề rời bàn (thoát hoặc bị Phá) bóc 1 lớp; chạm khối còn phủ không đi, không tốn MOVES, nên lớp phủ không còn tính vào `min_taps`. Thêm băng (`frost`, level dạy L110) cùng luật, hình băng trắng xanh, không cùng level với pudding. Người dùng chọn: lớp vỡ trên màn lúc khối kề chạm thanh (không phải lúc chạm), và tới lúc đó khối vẫn tính là còn phủ; bóc vỏ hộp giấy, bị chặn, dội cổng không bóc; lớp phủ không chung khối với sương mù; khối 2 lớp phân biệt bằng độ dày, không ghi số; băng vỡ dùng `sfx_ice`, pudding có tiếng mới `sfx_pudding`. Chưa sinh lại 500 level đóng gói (người dùng sẽ báo sau khi thêm xong các cơ chế khác): level đóng gói còn pudding 1 lớp với `min_taps` theo luật cũ, có thể kẹt theo luật mới, và test level đóng gói báo lỗi tới đợt sinh lại.
- Màn đặc biệt (Special Bomb) mở từ L41 (người dùng yêu cầu, 2026-11-09; mục 7 "Màn đặc biệt", mục 3 "Tiêu chí thư giãn"): chế độ riêng có bom hẹn giờ trên bàn hình chữ nhật lát kín, là ngoại lệ duy nhất của luật không đồng hồ và không rung mạnh khi thua. Người dùng chốt qua phỏng vấn: vé hai ngăn (chờ 2 giờ không cộng dồn; thắng Hard / VeryHard +1, không giới hạn), tự sinh 100 bàn thay vì nhập 90 level của game tham khảo, bom +1 sau mỗi 20 trận thắng tới tối đa 6, thưởng 1 booster random (x2 bằng quảng cáo), không huy hiệu độ khó, màn mưa bom khi vào. Đã cảnh báo rủi ro kinh tế: khoảng 0,6 vé mỗi level chính (149 Hard + 69 VeryHard trên L21–500), mỗi booster đáng 900–2.900 gold; người dùng giữ không giới hạn vé, số nằm trong `Config.SPECIAL` để Remote Config chỉnh sau soft launch. Số giây của bom theo đúng công thức đo được trên dữ liệu game tham khảo (19 + số lần chạm để gỡ), cộng dồn khi nhiều bom.
- Giữ 400 level Road Trip khi phát hành, không thay bằng level tự sinh (người dùng chọn, 2026-11-09; mục 7 "Road Trip"): sau đợt làm khó, level đã khác bản nhập (cổng 8 hoặc 12 màu, một phần khối đổi hướng, bỏ khoá `source`). Hình, ô và số bước vẫn lấy từ bộ MoreColor của game gốc; rủi ro bản quyền ghi ở `docs/REF_GAME_DIFF.md`, người dùng chấp nhận.
- Thêm ruy băng (`ribbon`, level dạy L130; người dùng yêu cầu, 2026-11-09; mục 4 "Cơ chế sau bản demo", "Hình dạng level"; mục 8 hiệu ứng, âm thanh): khối quấn 1–4 lớp ruy băng, luật như hộp giấy nhiều lớp. Người dùng chốt qua phỏng vấn: 4 lớp không tính kẹo; mỗi lớp một màu là hướng đi, khác màu lớp ngay trong; màu lớp trong ẩn, số lớp còn lại thấy được; không chung khối với pudding, băng, xích, hộp giấy, sương mù phủ lên được; khối 1 ô không có ruy băng, khối 2 ô tối đa 2 lớp; Phá xoá cả khối; mốc L130 vì L110 đã là băng; level dạy có 3–5 khối 1–2 lớp cộng một khối 3–4 lớp; vào nhóm rút cơ chế của level thường, số khối và số lớp tăng dần. Hình: người dùng bỏ cả ba phương án dải trắng, vàng kim, sọc kẹo ở bản concept đầu (`art/concepts/ribbon_concept_v1.png`) và chọn satin cùng màu khối, quấn chéo, dải rộng phủ gần kín khối, nơ to 1,3 ô giữa khối (`ribbon_concept_v2.png`); số lớp chỉ đọc qua khe giữa các dải, không ghi số. Chưa sinh lại 500 level đóng gói (đợt sinh lại chung sau khi thêm xong các cơ chế).
- Hồi mạng 5 phút thay cho 15 phút (người dùng yêu cầu, 2026-11-09; mục 3 "Mạng"): `Config.LIVES.regen_sec` 900 → 300, Remote Config `lives_regen_sec` mặc định 300. Tối đa 10 mạng, giá refill và mốc mất mạng từ L10 giữ nguyên; đầy 10 mạng từ 0 mất 50 phút thay vì 2,5 giờ.
- Chain Offer mở từ L150 thay cho L24 (người dùng yêu cầu, 2026-11-09; mục 7 "Chain Offer"): `Config.CHAIN.level_unlock` 24 → 150, Remote Config `chain_level_unlock` mặc định 150. Điều kiện bật giữ nguyên: sau ván thắng hoặc thua không phải Challenge, chưa có chuỗi, hết cooldown.
- Cân bằng kinh tế lần 2 (người dùng chọn sau phân tích, 2026-11-09; mục 2, 4 "Mở khoá theo level", mục 7): mục tiêu doanh thu 70% IAA, 30% IAP (trước 50/50). Gói gold 3 10.000 → 11.000, gói 6 100.000 → 120.000 (cả bản `_sale`, giá store giữ nguyên), thang gold/$ thành 503 / 626 / 734 / 834 / 1.000 / 1.200. Level Pack 3.000 gold + 2 mỗi booster (trước 2.000 + 1). Helper Great 2 Gợi ý + 2 +3 Move + 1 Phá khối (trước 1 +3 Move). Thưởng thắng Màn đặc biệt rút Gợi ý 60%, +3 Move 30%, Phá khối 10% (lặp tên trong `Config.SPECIAL.reward_kinds`), hệ vé giữ nguyên. Mở khoá: Chain Offer L150 → L100, Màn đặc biệt L41 → L50, Road Trip L2 → L70. Bảng mở khoá và thanh tiến trình của thẻ thắng thêm Weekly Pass, Level Pack, Chain Offer (`Unlocks.levels()`), các tính năng này không kéo về Home. Không đổi: giá booster, cứu lượt có video 4 lần, `booster_free` không giới hạn, weekend sale cho mọi người, Weekly Pass, Starter.
