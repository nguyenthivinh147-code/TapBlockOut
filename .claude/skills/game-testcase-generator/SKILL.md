---
name: game-testcase-generator
description: "Sinh bộ test case Candy Away từ design.md hoặc tài liệu thiết kế: CSV trong tests/cases/ (nguồn để viết kịch bản smoke và unit test) và Excel 3 sheet để duyệt (Test Cases, Open Questions, Test Data)."
disable-model-invocation: true
---
# Game Test Case Generator

Phân tích tài liệu thiết kế, xác định phạm vi kiểm thử và sinh bộ test case chuẩn hoá bám sát logic gameplay, UI/UX và các tình huống gián đoạn hệ thống. Đầu ra:
- **`tests/cases/<MODULE>.csv`**: nguồn của sheet Test Cases, có thêm cột `AUTO`. Kịch bản smoke và unit test chấm từng case theo ID. Định dạng, cột `AUTO` và cách chấm: `docs/TESTING.md` mục "Test case"; đọc mục đó trước Bước 4.
- **Một file Excel gồm đúng 3 sheet** (mục "Cấu trúc file Excel 3 sheet"), sheet Test Cases dựng từ CSV.

## Nguyên tắc cốt lõi

- **Bám sát tài liệu:** sinh test case từ logic, mô tả và thông số trong tài liệu thiết kế. Đọc cả phần nằm trong ảnh, bảng và công thức, vì đó thường là nơi chứa số liệu quan trọng nhất.
- **Kiểm chứng được:** mỗi test case có Steps, Input và Expected Result cụ thể. Người test khác đọc vào phải chạy được mà không cần hỏi lại.
- **Kết quả kỳ vọng có giá trị cụ thể:** số dư trước/sau, level, số lượng, trạng thái nút, nội dung thông báo. Câu như "Kiểm tra tính năng hoạt động bình thường" hay "UI hiển thị đúng" chưa phải test case.
- **Điểm mơ hồ thành Open Question:** khi tài liệu thiếu thông tin, mâu thuẫn hoặc mơ hồ, ghi vào sheet Open Questions, dùng một giả định hợp lý và gắn nhãn rõ trong NOTE (Designer cần biết case nào đang đứng trên giả định để xác nhận).
- **Kỳ vọng tính từ công thức:** với mọi công thức hoặc bảng thông số, tính giá trị kỳ vọng thật (kể cả làm tròn) và lưu trong sheet Test Data để người test đối chiếu.
- **Phân cấp Level:**
  - `Level 1`: Module / tính năng lớn.
  - `Level 2`: Nhóm chức năng / màn hình / luồng con.
  - `Level 3`: Test case chi tiết.

## Bước 0: đọc đầy đủ tài liệu nguồn

Nguồn mặc định là các mục của `design.md` mà người dùng chỉ định (luật chơi, con số, nội dung đều ở đó), đối chiếu với số thật trong `src/config.gd`. Người dùng đưa tài liệu khác (docx, pdf, md) thì dùng tài liệu đó. Kiểm tra từng mục sau trước khi sinh test case:

1. **Text và bảng:** trích xuất toàn bộ, giữ số mục (ví dụ `design.md §7`, `§5 "Quà 28 ngày"`) để ghi vào NOTE.
2. **Ảnh:** xem từng ảnh liên quan: ảnh concept và mock trong `art/concepts/`, ảnh nhúng trong docx (thư mục `word/media`). Ảnh có thể chứa bảng, mock UI, sơ đồ vị trí. Phóng to ảnh nhỏ để đọc chính xác từng con số.
3. **Công thức:** với docx, công thức nằm trong `document.xml` và thường vỡ ký hiệu khi trích xuất text. Đọc lại cấu trúc công thức gốc (chỉ số dưới, số mũ, phân số, ngoặc làm tròn).
4. **Liên kết ngoài (Figma, wireframe trên claude.ai...):** thử mở nếu được; UI theo Figma ghi ở `docs/UI_FIGMA.md`, UI dựng từ prefab Unity ở `docs/UI_UNITY.md`. Không mở được thì ghi thành Open Question mức Thấp, nêu lại ở Bước 7, và đối chiếu UI theo mock có sẵn.
5. **Đối chiếu chéo:** text với ảnh, công thức với mock, bảng với mô tả, `design.md` với `src/config.gd`. Mâu thuẫn đi vào Open Questions. Mock khớp công thức thì ghi lại làm căn cứ cho cách hiểu công thức và quy tắc làm tròn.

## Phạm vi kiểm thử và độ bao phủ

Khi phân tích tài liệu, tách rõ:
- **In-Scope:** gameplay logic, UI/UX visual và layout, mạng và đồng bộ (cloud save, Remote Config, Leaderboard), quảng cáo và mua hàng, hiệu năng, xử lý gián đoạn phần cứng và hệ điều hành.
- **Out-of-Scope:** phần không thuộc bản build hiện tại (ghi chú rõ nếu có, ví dụ cơ chế trong kế hoạch chưa làm).

#### 1. Happy Path `[HP]`
Luồng chuẩn của người chơi từ đầu đến cuối. Checklist:
- Mỗi tính năng, luồng, quy tắc có ít nhất 1 case chạy trọn luồng.
- Mỗi điều kiện mở khoá hoặc kích hoạt: mở đúng mốc quy định (`design.md` mục 4 "Mở khoá theo level").
- Mỗi công thức và bảng thông số: giá trị đại diện (đầu, giữa, cuối), các mốc làm hành vi đổi, quy tắc làm tròn, giá trị cực đại.
- Mỗi tham số ghi "có thể config" (Remote Config, `docs/HORUS_HANDOFF.md` mục 4): 1 case đổi config rồi xác nhận hành vi đổi theo.
- Mỗi loại tiền tệ và tài nguyên (gold, mạng, booster): trừ/cộng đúng, số dư cập nhật ngay trên mọi màn liên quan.
- Mỗi trạng thái quan trọng (mở khoá, cosmetic đang dùng, level, lượt đã dùng): lưu bền vững sau khi kill app, đăng xuất/đăng nhập, đổi thiết bị (cloud save).
- Tích hợp giữa các module (ví dụ booster mua ở Shop dùng được ngay trong level).

#### 2. Negative Path `[NEG]`
Người chơi vi phạm điều kiện tiên quyết. Checklist:
- Thiếu tài nguyên (bằng 0 và thiếu đúng 1 đơn vị), chưa đủ level, chưa mở khoá, chưa sở hữu vật phẩm.
- Thao tác trái thứ tự, chọn sai đối tượng, trùng lặp không được phép.
- Đã đạt giới hạn (hết lượt mua, hết lượt video trong ngày, mạng đầy).
- Giao dịch bị huỷ hoặc thất bại.
- Mọi câu "không có / không được / không bao giờ" trong tài liệu (ví dụ "không banner") có ít nhất 1 case chứng minh.
- Kết quả kỳ vọng của NEG luôn gồm 2 phần: dữ liệu không đổi (số dư, level, lượt) và phản hồi UI (nút disabled hoặc thông báo).

#### 3. UI / UX & Visual Verification `[UI]`
- **Nội dung hiển thị:** đối chiếu từng thành phần với mock (tên, icon, chỉ số, nhãn, thanh tiến trình, bộ đếm).
- **Layout và vị trí** trên các tỉ lệ màn hình: màn chuẩn 886×1920, tai thỏ, màn dài 20:9/21:9, máy tính bảng 4:3; safe area, gesture bar.
- **Text và localization:** 14 ngôn ngữ trong `i18n/strings.csv`; mọi chữ hiển thị đi qua `tr()` (tương đương I2 của Unity); tràn chữ (tiếng Đức, Nga dài nhất), chữ tự co vừa khung (bestfit) ở mọi chỗ sau khi căn chỉnh, font fallback (Hindi, Hàn, Nhật), thiếu glyph hiện ô vuông, key `tr()` thô lộ ra, font và cỡ chữ khớp mock/ref, định dạng số và tiền tệ thống nhất toàn game.
- **Trạng thái phần tử UI:** Normal, Pressed, Disabled; hết lượt, đã đạt max; highlight khi đủ/thiếu điều kiện.
- **Nút:** phản hồi khi nhấn và suốt lúc giữ (tối màu hoặc nhún); giữ rồi thả trên nút kích hoạt đúng 1 lần; đang giữ mà kéo ngón ra ngoài nút rồi thả, và kéo ngón từ ngoài vào nút. Kỳ vọng `design.md` không nêu thì ghi OQ (mục Open Questions).
- **Popup:**
  - Có lớp dim phía sau; chạm vào UI dưới dim không có tác dụng.
  - Chạm nền tối: đóng popup hay không theo `design.md` của popup đó.
  - Giữ cỡ và tỉ lệ khung của màn chuẩn trên mọi tỉ lệ màn, không kéo giãn theo màn; popup mà `design.md` cho cỡ theo màn (Leaderboard cao 85% màn) thì theo `design.md`.
  - Popup đè nhau, phần tử bị che bởi HUD hoặc tai thỏ, overlay quảng cáo, thứ tự đóng popup.
  - Chuỗi popup mở popup, đi trọn từ đầu đến cuối (ví dụ hết MOVES mà thiếu gold: popup cứu lượt → bấm mua mở shop mini → mua gói → popup thưởng → đóng shop về popup cứu lượt): mỗi lớp đúng nội dung, đóng lớp trên thì về đúng lớp dưới, số dư ở lớp dưới cập nhật ngay.
- **Thứ tự popup tự mở:** tính năng có popup tự mở ở Home hoặc sau thẻ thắng/thua cần case trùng lúc với các popup tự mở khác (quà booster, giới thiệu cơ chế, mời tính năng, offer, kết quả tuần Leaderboard): hiện lần lượt, không đè nhau, không mất popup nào. `design.md` chưa có bảng thứ tự chung: thứ tự giả định ghi thành OQ.
- **Back Android và ESC** (`design.md` mục 2 "Back Android và ESC"): ở mọi màn và popup, trừ lớp loading và lúc đang chuyển cảnh, Back đóng popup trên cùng hoặc làm như nút quay lại của màn. ESC trên máy tính không bắt buộc làm như Back (game chỉ ra Android), nhưng chỗ Back bị khoá thì ESC cũng không được làm gì. Hướng dẫn khoá màn hình (bàn tay chỉ, tutorial) đang chạy thì Back và ESC bị khoá. Tính năng mới có hướng dẫn: thêm case Back và ESC lúc hướng dẫn.
- **Ô nhập chữ** (biệt danh): chạm vào mở bàn phím ảo của máy. Chỉ máy thật thấy được (`manual:`).
- **Animation, VFX, SFX, rung:** mở/đóng popup mượt, âm click phát đúng 1 lần, không chồng âm, rung đúng chỗ, không giật (ngưỡng FPS ghi rõ là đề xuất nếu tài liệu không nêu).
- **Tutorial:** bàn tay chỉ và vùng highlight trùng đúng nút hoặc khối cần bấm trên mọi tỉ lệ màn.
- Mỗi màn hoặc popup có ít nhất 1 case về nội dung và layout đa tỉ lệ, và mỗi nhóm nút có 1 case về trạng thái. Mỗi popup thêm 1 case dim và chạm nền, 1 case Back; mỗi nút mở màn, mở popup hoặc giao dịch có 1 case bấm đúp (`[EDGE]`).

#### 4. Edge Cases & Mobile Spec `[EDGE]`
Mỗi mảng liên quan tới tài liệu phải có case:
- **Mạng và đồng bộ:** mất mạng đột ngột, Airplane mode bật/tắt, mạng chập chờn, hai thiết bị cùng tài khoản. Với mọi giao dịch, kiểm bất biến: không "trừ tiền mà không nhận hàng", không "nhận hàng mà không trừ tiền", không trừ hai lần.
- **Gián đoạn thiết bị:** app xuống background, kill app giữa thao tác, cuộc gọi đến, thông báo hệ thống, thiếu bộ nhớ. Để yên lâu ở một màn, màn hình vẫn bật (đề xuất 30 phút), rồi chơi tiếp: không treo, đồng hồ đếm ngược và mốc giờ vẫn đúng.
- **Thao tác dồn dập:**
  - Tap liên tục vào nút hoặc vùng chuyển cảnh (tap 20 lần/giây khi tài nguyên chỉ đủ 1 lần: chỉ 1 giao dịch xảy ra, không số âm); tap nhiều khối cùng lúc trên bàn.
  - Bấm đúp nhanh nút mở popup hoặc chuyển màn: chỉ lần 1 có tác dụng, màn hoặc popup sau mở đúng 1 lần.
  - Bấm nút khác hoặc Back khi màn đang chuyển hoặc đang tải (màn chuyển cảnh, lớp loading, "Đang tải video"): chạm bị bỏ qua, cuối cùng đứng ở đúng màn.
  - Nhiều ngón chạm nhiều nút cùng lúc: chỉ một hành động xảy ra.
- **Vòng lặp giữa các màn:** màn hoặc popup A có nút mở B, B lại có nút mở A: đi vòng nhiều lần, chồng popup không tăng mãi (smoke giới hạn 3 lớp), Back lùi đúng từng lớp.
- **Giá trị biên:** tài nguyên bằng 0, ngưỡng−1 / ngưỡng / ngưỡng+1, level cuối, giá trị rất lớn.
- **Thời gian:** mốc reset ngày/tuần (23:59:59 → 00:00:00, tuần giao năm, tháng 28/29/30/31, năm nhuận), không reset sai thời điểm, hồi mạng theo thời gian, đổi giờ máy để gian lận, múi giờ.
- **Ngẫu nhiên:** kiểm thống kê theo N lượt với biên kỳ vọng ± 3σ (σ = √(N·p·(1−p))), tổng tỷ lệ bằng 100%, mọi kết quả ánh xạ ra vật phẩm tồn tại.
- **Dữ liệu và cấu hình:** bền vững qua kill app, đăng xuất, cài lại; tài khoản cũ trước khi cập nhật bản có tính năng; đổi Remote Config không cần cập nhật client. Mỗi hành động có sự kiện analytics (`docs/HORUS_HANDOFF.md` mục 5) bắn đúng tên, đúng tham số, đúng 1 lần.
- **Quảng cáo:** ads không tải được hoặc không có mạng (nút thưởng ẩn/disabled hoặc có thông báo, game không treo); đóng ads trước khi xong thì không nhận thưởng; xem xong nhận thưởng đúng 1 lần, kể cả khi bấm liên tục hoặc kill app ngay sau khi ads đóng; trần lượt ads mỗi ngày; ads không chen vào tutorial hay giao dịch. Gói Remove Ads: tắt interstitial; hành vi với rewarded theo `design.md` mục 6–7, tài liệu không nêu thì ghi OQ.
- **Mua hàng (IAP):** mua thành công (đúng vật phẩm, đúng 1 lần); huỷ ở hộp thoại thanh toán; thanh toán thất bại; đơn pending (nhận hàng khi giao dịch hoàn tất, kể cả sau khi mở lại app); Restore cho gói không tiêu hao (`remove_ads`, `remove_ads_bundle`); giá hiển thị lấy từ store theo vùng.
- **Hiệu năng:** FPS ở bàn nặng nhất (nhiều khối, nhiều cơ chế, hiệu ứng thắng) trên máy thấp nhất được hỗ trợ (kế hoạch mục 4: máy 2 GB loại Galaxy A10, từ 30 khung/giây); thời gian khởi động lần đầu và các lần sau; thời gian chuyển màn; RAM không tăng dần sau nhiều level; nóng máy và hao pin sau khoảng 30 phút; dung lượng bản cài. Ngưỡng nào tài liệu không nêu thì ghi rõ là đề xuất.

### Ma trận bao phủ tối thiểu

Luật cứng khi liệt kê test case cho từng thành phần: bảng ở `docs/TESTING.md` mục "Ma trận bao phủ", cột "Tối thiểu phải có". Đọc bảng đó trước Bước 4. Cột tầng tự động của bảng dùng để ghi vào NOTE khi case đã có test tự động tương ứng (tên file test hoặc kịch bản smoke).

### Tự kiểm tra bao phủ trước khi xuất file

1. Duyệt ma trận bao phủ cho từng module; thành phần nào thiếu thì bổ sung case.
2. Mỗi module có đủ 4 tag; nhóm nào vắng mặt trong một module phải có lý do (ví dụ module không có UI riêng).
3. Phân bổ tham khảo toàn bộ: `[HP]` 30-40%, `[NEG]` 12-18%, `[UI]` 15-20%, `[EDGE]` 25-35%. Lệch nhiều thì rà lại xem có bỏ sót nhóm không.
4. P0 chỉ dành cho case chặn gameplay hoặc ảnh hưởng tiền tệ/dữ liệu người chơi; P0 vượt khoảng 35% tổng số thì hạ bớt case ít nghiêm trọng xuống P1.
5. Mỗi Open Question được nhắc trong NOTE của ít nhất 1 test case, và mỗi case dựa trên giả định đều có mã OQ.
6. Case `manual:` quá khoảng 15% tổng số thì rà lại: phần lớn hành vi thấy được trên màn hoặc trong save đều chấm được bằng smoke.

## Định dạng bảng Test Case chuẩn

Cấu trúc cột của sheet `Test Cases`:

| **ID** | **CASE** | **PRIORITY** | **DESCRIPTIONS** | **PRE COND** | **INPUT** | **STEP** | **EXPECTED RESULT** | **ACTUAL RESULT** | **STATUS** | **NOTE** | **AUTO** |
|:---:|:---:|:---:|:---|:---|:---|:---|:---|:---:|:---:|:---|:---|
| **Level 1** | | | | | | | | | Ready | | |
| **Level 2** | | | | | | | | | Ready | | |
| **Level 3** | | | | | | | | | Ready | | `todo:smoke:WP` |

### Giải thích các trường
- **ID:** mã duy nhất. Level 3: `TC_CA_<MODULE>_<NNN>` (ví dụ `TC_CA_SHOP_007`), `<MODULE>` trùng tên file CSV (mã kịch bản smoke của tính năng nếu có); Level 1: `M01`, `M02`...; Level 2: `M01.1`, `M01.2`... Tiền tố `TC_` chỉ dùng cho Level 3 để đếm đúng số test case thật bằng `=COUNTIF('Test Cases'!$A:$A,"TC_*")`. Không trùng ID.
- **CASE:** `[HP|NEG|UI|EDGE] Tên trường hợp ngắn gọn`. Dòng Level 1/2 ghi tên module/nhóm, không có tag.
- **PRIORITY:** `P0` (Blocker / Critical: chặn gameplay hoặc ảnh hưởng tiền tệ/dữ liệu), `P1` (Major), `P2` (Minor / Trivial). Để trống ở Level 1/2.
- **DESCRIPTIONS:** mục tiêu cần xác minh. Ở Level 1/2: phạm vi và mục tài liệu tương ứng.
- **PRE COND:** trạng thái tài khoản (level, gold, mạng, booster), build và config áp dụng. Bản debug có menu tester để dựng nhanh trạng thái (`docs/DEMO_NOTES.md` mục 3b).
- **INPUT:** dữ liệu cụ thể nhập vào hoặc chọn (SKU, số gold, số level); với case công thức ghi cách tính (ví dụ `+3 MOVES lần 2: 2.200 gold`).
- **STEP:** các bước đánh số `1.`, `2.`, `3.`, mỗi bước một dòng.
- **EXPECTED RESULT:** mỗi ý một dòng bắt đầu bằng `- `: dữ liệu thay đổi (số trước → sau), UI phản hồi, thông báo. Case thất bại nêu rõ dữ liệu nào giữ nguyên. Case mạng hoặc kill app nêu bất biến phải đúng ("hoặc hoàn tất đầy đủ, hoặc không đổi gì"). Case tự động (`AUTO` không phải `manual:`): mỗi ý là thứ code đọc được, gồm số trong save hoặc trên màn, popup hay nút nào hiện hoặc ẩn, chữ của khoá i18n nào, và số viết ra (tính từ `design.md`), không viết "theo config".
- **ACTUAL RESULT:** để trống khi khởi tạo.
- **STATUS:** mặc định `Ready`. Giá trị hợp lệ: `Ready`, `Pass`, `Fail`, `Blocked`, `N/A`.
- **NOTE:** mục tài liệu (`design.md §7`), mã Open Question (`OQ-05`), `CẦN XÁC NHẬN` khi tài liệu chưa quy định, thiết bị hoặc tài khoản test, bug liên quan, test tự động đã có.
- **AUTO:** tầng sẽ chấm case. Skill chỉ ghi `todo:smoke:<kịch bản>`, `todo:unit:test_<file>` hoặc `manual:<lý do>`; task viết test đổi `todo:` thành giá trị thật cùng code chấm. Chọn tầng theo `docs/TESTING.md` mục "Test case". `manual:` chỉ cho thứ không tầng tự động nào quan sát được (âm thanh, rung, cảm giác chơi, SDK thật, máy 2 GB) và ghi lý do. Dòng Level 1/2 để trống.

### Quy tắc đặt số liệu trong test case
- Số lấy từ tài liệu hoặc `src/config.gd` thì dùng nguyên; số tự đặt để test (số dư gold, số booster, level mẫu) ghi rõ "giả định" hoặc "dữ liệu test" trong PRE COND/INPUT để người test thay bằng giá trị thật của build.
- Giá trị kỳ vọng khớp bảng trong sheet Test Data. Đổi một bên thì cập nhật bên kia.

## Cấu trúc file Excel 3 sheet

Xuất **một file `.xlsx` gồm đúng 3 sheet, đúng tên và thứ tự sau**, vì các sheet tham chiếu nhau bằng công thức. Sheet nào không có dữ liệu áp dụng vẫn tồn tại và ghi "Không áp dụng" kèm lý do.

| # | Tên sheet | Vai trò |
|:---:|:---|:---|
| 1 | `Test Cases` | Toàn bộ test case theo bảng chuẩn ở trên |
| 2 | `Open Questions` | Điểm chưa rõ/mâu thuẫn cần Designer xác nhận |
| 3 | `Test Data` | Tham số, công thức, bảng tỷ lệ, config giả định để tính giá trị kỳ vọng |

### Sheet 1 - `Test Cases`
- Hàng 1 là tiêu đề 12 cột đúng tên: `ID, CASE, PRIORITY, DESCRIPTIONS, PRE COND, INPUT, STEP, EXPECTED RESULT, ACTUAL RESULT, STATUS, NOTE, AUTO`. Nội dung đọc từ `tests/cases/<MODULE>.csv`, không gõ lại.
- Dòng Level 1 nền xanh đậm chữ trắng đậm; Level 2 nền xanh nhạt chữ đậm; Level 3 không tô nền. Level 1/2 có `STATUS = Ready`.
- Độ rộng cột: ID 19, CASE 42, PRIORITY 10, DESCRIPTIONS 40, PRE COND 38, INPUT 34, STEP 52, EXPECTED RESULT 58, ACTUAL RESULT 22, STATUS 11, NOTE 38, AUTO 22. Mọi ô xuống dòng, căn trên.
- Đóng băng khung tại `C2`, bật AutoFilter cho cả bảng.
- Nhóm dòng (outline) theo Level: Level 1 = 0, Level 2 = 1, Level 3 = 2, nút +/- ở dòng tiêu đề nhóm (`summaryBelow = False`).
- Dropdown (data validation): cột STATUS (`Ready,Pass,Fail,Blocked,N/A`) và PRIORITY (`P0,P1,P2`).
- Định dạng có điều kiện: P0 nền đỏ nhạt, P1 vàng, P2 xanh dương nhạt; Pass xanh lá, Fail đỏ, Blocked vàng.

### Sheet 2 - `Open Questions`
Hàng 1 là tiêu đề, dữ liệu từ hàng 2. Cột: `ID, MỨC ĐỘ, MỤC TÀI LIỆU, VẤN ĐỀ / MÂU THUẪN, GIẢ ĐỊNH ĐANG DÙNG TRONG TEST CASE, SỐ TC, TC LIÊN QUAN, TRẠNG THÁI, NGƯỜI XÁC NHẬN, QUYẾT ĐỊNH CỦA DESIGNER`.
- ID dạng `OQ-01`, `OQ-02`...; MỨC ĐỘ là `Cao` / `Trung bình` / `Thấp` (Cao = ảnh hưởng tiền tệ, công thức, tỷ lệ hoặc nhiều test case).
- `SỐ TC` là công thức đếm số case nhắc mã OQ trong NOTE; ở hàng 2 là `=COUNTIF('Test Cases'!$K:$K,"*"&A2&"*")`, các dòng sau kéo xuống. `TC LIÊN QUAN` liệt kê ID rút gọn (bỏ tiền tố `TC_CA_`). `TRẠNG THÁI` mặc định `Open` với dropdown (`Open, Confirmed, Spec updated, Won't fix`); hai cột cuối để trống cho Designer điền.
- Ghi thành OQ khi: text mâu thuẫn với ảnh/mock; `design.md` lệch `src/config.gd`; thiếu thông số (giá, múi giờ, giới hạn tối đa); ký hiệu công thức mơ hồ; quy tắc làm tròn không nêu; hành vi khi vượt giới hạn hoặc hết hạn không nêu; nội dung "tương lai" xuất hiện trong dữ liệu của bản hiện tại; hành vi UI không được mô tả.
- Mỗi OQ có giả định cụ thể (đủ để test case vẫn chạy được) và được nhắc trong NOTE của ít nhất 1 test case.

### Sheet 3 - `Test Data`
Nơi tính mọi giá trị kỳ vọng. Ô tham số nhập tay nền vàng nhạt chữ xanh dương; ô còn lại là công thức. Gồm các khối (khối nào không áp dụng thì giữ tiêu đề và ghi "Không áp dụng"):
- **A. Tham số:** hằng số và config mặc định lấy từ tài liệu hoặc `src/config.gd`, kèm cột nguồn (§ hoặc `file:line`) hoặc ghi chú giả định. Đổi tham số thì các bảng bên dưới tự tính lại.
- **B. Đối chiếu mock:** giá trị hiển thị trong mock hoặc ví dụ của tài liệu, công thức tính ra, cột `Khớp/Lệch`.
- **C. Bảng theo level/mốc:** chi phí, phần thưởng, giá trị tích luỹ theo từng mốc bằng công thức Excel (`ROUND`, `INT`, `^`...), đủ để tra mọi giá trị dùng trong test case, kể cả các mốc đổi hành vi.
- **D. Bảng tỷ lệ (RNG):** tỷ lệ từng dòng nhập tay (phân số, định dạng `0%`), cột Tổng, cột Kiểm tra `OK/LỖI` (`=IF(ROUND(tổng,6)=1,"OK","LỖI")`), các cột phái sinh, tổng số lượt tích luỹ.
- **E. Config giả định:** giá trị tài liệu cho phép đổi nhưng không nêu số, tiêu đề "GIẢ ĐỊNH - thay bằng config thật của build".

### Quy tắc kỹ thuật khi tạo file
- Đọc skill `xlsx` trước nếu môi trường có. Python chạy bằng `uv run --with openpyxl python <script>`; script đặt trong scratchpad, không vào repo. Font Arial 10 toàn file.
- Số liệu tính toán là **công thức**, không gõ cứng kết quả. Chỉ dùng hàm tương thích rộng: `COUNTIF`, `COUNTIFS`, `SUM`, `ROUND`, `INT`, `INDEX`, `IF`, `IFERROR`. Không dùng `XLOOKUP`, `FILTER`, `SORT`, `UNIQUE`, `SEQUENCE`.
- Tên sheet có khoảng trắng đặt trong nháy đơn khi tham chiếu: `'Test Cases'!$A:$A`.
- Sau khi tạo, tính lại toàn bộ công thức (ví dụ `recalc.py` của skill xlsx) và đạt **0 lỗi công thức**. Công cụ tính lại có thể làm mất nhóm dòng; kiểm lại `summaryBelow = False`, các dropdown và định dạng có điều kiện.
- Kiểm chứng sau khi tính: (a) giá trị trong Test Data khớp các con số trong test case, đặc biệt các biên làm tròn; (b) số dòng `TC_` đếm bằng `COUNTIF` khớp số dòng Level 3 đếm bằng chương trình và khớp số báo ở Bước 7; (c) không trùng ID; (d) không ô bắt buộc nào trống ở Level 3 (trừ ACTUAL RESULT); (e) mọi OQ có tham chiếu.
- Lưu file vào `output/testcase-<tên tính năng>/` ở gốc repo, rồi trình bày file cho người dùng.

### CSV `tests/cases/<MODULE>.csv`
- 12 cột như sheet Test Cases, UTF-8, dấu phẩy, ô có xuống dòng hoặc dấu phẩy đặt trong ngoặc kép (`csv` của Python với `quoting=csv.QUOTE_MINIMAL`). Gồm cả dòng Level 1/2.
- Viết CSV trước, dựng Excel từ CSV. Sửa case thì sửa CSV rồi dựng lại Excel.
- Kiểm: `tools/test.sh test_cases` đạt và dòng `CASES <MODULE>` trong log khớp số case theo nhóm.

## Quy trình xử lý đầu ra

1. **Bước 1 - Đọc và phân tích:** nhận mục `design.md` hoặc tài liệu từ người dùng, thực hiện Bước 0, tóm tắt Scope (In/Out) và kỹ thuật test áp dụng.
2. **Bước 2 - Điểm chưa rõ và giả định:** liệt kê Open Questions, chọn giả định cho từng điểm.
3. **Bước 3 - Tính dữ liệu kiểm thử:** dựng tham số, bảng công thức, bảng tỷ lệ và config giả định (nội dung sheet Test Data).
4. **Bước 4 - Sinh test case:** với từng module và nhóm chức năng, sinh case theo 4 nhóm bao phủ và ma trận tối thiểu, theo template Level 1 / Level 2 / Level 3. Người dùng chỉ muốn xem trong chat thì xuất bảng Markdown đúng cột chuẩn; bộ lớn (trên khoảng 30 case) chỉ hiện sườn Level 1/2 cùng vài case mẫu mỗi module, phần đầy đủ để trong file.
5. **Bước 5 - Tự kiểm tra bao phủ:** chạy checklist "Tự kiểm tra bao phủ" và bổ sung chỗ thiếu.
6. **Bước 6 - Xuất CSV rồi Excel 3 sheet:** ghi `tests/cases/<MODULE>.csv`, dựng đúng 3 sheet `Test Cases`, `Open Questions`, `Test Data` từ CSV, rồi chạy các bước kiểm chứng kỹ thuật và `tools/test.sh test_cases`.
7. **Bước 7 - Báo cáo ngắn:** cùng ngôn ngữ với người dùng: số test case theo nhóm, priority và tầng `AUTO` (dòng `CASES`), Open Questions mức Cao, số liệu giả định cần thay bằng giá trị thật, hạn chế đã gặp (ví dụ liên kết không mở được). Bảng đầy đủ nằm trong file.
