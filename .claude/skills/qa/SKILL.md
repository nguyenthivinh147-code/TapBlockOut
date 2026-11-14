---
name: qa
description: "QA Candy Away, vai agent test độc lập với người làm task: onboard (agent test mới vào dự án), feature (code/design/art báo xong task cần test), daily (lịch 16h, commit từ 16h hôm trước), full (yêu cầu test full game)."
argument-hint: "onboard | feature <tính năng> [ref] | daily | full [ref]"
---

QA kiểm game độc lập với người làm task: kỳ vọng lấy từ `design.md`, không lấy từ code. Lệnh, tầng test, test case, ma trận bao phủ: `docs/TESTING.md`; đọc mục "Quy trình cho một thay đổi", "Chọn test theo thay đổi" và "Test case" trước bước đầu tiên.

QA sửa `tests/cases/`, `tests/smoke/`, unit test, và mục `design.md` do chính QA suy ngược khi mục đó còn chờ duyệt. Lỗi game là việc của task code: QA báo kèm lệnh tái hiện. Thay đổi của QA để trong cây làm việc và liệt kê trong báo cáo; Orchestrator commit.

Chế độ theo đối số đầu: `onboard`, `feature`, `daily`, `full`. Không có đối số thì suy từ lời yêu cầu, vẫn không rõ thì hỏi.

## Sổ tính năng: `tests/cases/FEATURES.md`

Mỗi dòng một tính năng người chơi gặp được: màn, popup, sự kiện, chế độ chơi, cơ chế khối, giao dịch. QA ghi sổ, người khác đọc. Cột:

| Tính năng | Mục `design.md` | Code chính | MODULE | Trạng thái | Cập nhật |
|---|---|---|---|---|---|

- **MODULE:** mã kịch bản smoke, cũng là tên `tests/cases/<MODULE>.csv`.
- **Trạng thái:**
  - `tắt`: tính năng đang tắt (mục **Phạm vi**).
  - `chờ duyệt`: mục `design.md` còn nhãn `(đề xuất, chờ duyệt)`.
  - `chạy, chưa case`: có kịch bản smoke chạy được, chưa có CSV (kịch bản viết trước Task 11.7).
  - `chưa case`: chưa có CSV.
  - `chưa script`: CSV còn case `todo:`.
  - `đủ`: dòng `CASES <MODULE>` có `todo 0` và kịch bản in `missing=0`.
- **Cập nhật:** ngày QA đổi dòng.

## Phạm vi

Tạo test case và script cho tính năng **đang bật** chưa có script. Tính năng đang tắt (khoá `false` trong `Config._FEATURES`, cơ chế ở `design.md` mục 4 "Cơ chế sau bản demo" chưa có trong level, SKU ẩn) ghi `tắt`: kịch bản OFF đã kiểm chúng vẫn tắt. Tính năng đã có script chạy được thì chạy script đó; thêm case khi luật hay số của nó đổi.

## Vòng tính năng

Dùng ở mọi chế độ, cho một tính năng đang bật.

1. **Design.** Tìm mục: `grep -n "^## \|^### " design.md`.
   - Có mục, tiêu đề không có `(đề xuất, chờ duyệt)` → bước 2.
   - Tiêu đề còn nhãn → `chờ duyệt`, sang tính năng khác.
   - Chưa có mục → `/design-note <tính năng> reverse`, thêm ` (đề xuất, chờ duyệt)` vào cuối tiêu đề mục mới, gửi thông báo **duyệt design**, ghi `chờ duyệt`, sang tính năng khác.

   Người duyệt bỏ nhãn (sửa nội dung nếu cần) là đã duyệt; lần chạy sau vòng đi tiếp từ bước 2.
2. **Case** cho phần cần test: cả tính năng khi trạng thái là `chưa case`; luật, số vừa đổi khi tính năng đã có script. Đọc `.claude/skills/game-testcase-generator/SKILL.md` và làm theo (skill đó chỉ gọi được bằng lệnh của người dùng). Case thêm vào CSV có sẵn nối tiếp ID cũ. Open Question mức Cao đưa vào thông báo **kết quả**; script viết theo giả định đã ghi, NOTE mang mã `OQ-xx`.
3. **Script.** Mỗi case `todo:` thành `smoke:` hoặc `unit:` cùng code chấm nó (`docs/TESTING.md` "Quy trình cho một tính năng" bước 3).
4. **Chạy** kịch bản và unit test của tính năng; case `look` chạy `window` và đọc ảnh.

Xong khi: dòng `CASES <MODULE>` có `todo 0`, `tools/smoke.sh headless <MODULE>` in `missing=0`, mỗi case FAIL đã phân loại, ảnh của mọi case `look` đã đọc, sổ ghi `đủ`.

## Phân loại kết quả đỏ

Ba loại của `docs/TESTING.md` "Phân loại case FAIL" (OQ chưa chốt, lỗi smoke, lỗi game), cộng:

- **Hạ tầng:** lệnh thoát `2`. Chạy lại một lần; vẫn `2` thì báo hạ tầng kèm log.
- **WIP:** file liên quan nằm trong `git status --short` (phiên khác đang sửa dở). Báo riêng, không tính cho commit nào.
- **Còn đỏ:** đã đỏ ở lần chạy trước (`output/report/index.html`, phần so với lần trước). Ghi "còn đỏ từ <ngày>", không báo như lỗi mới.
- **Lệch tài liệu:** hành vi, số hoặc interface đổi mà cùng thay đổi không sửa `design.md`, kế hoạch hay `docs/` (luật trong `CLAUDE.md`); hoặc design đã đổi mà code chưa theo.

Lỗi game: ID case, câu luật trong `design.md`, số thấy được so với số kỳ vọng, lệnh tái hiện.

## onboard

Agent test mới vào dự án. Sổ đã có dòng thì đây là lần chạy tiếp: đi thẳng bước 3 với các dòng chưa xong.

1. **Kê tính năng** vào sổ (tạo sổ nếu chưa có). Nguồn: `src/meta/*.gd`, màn và popup trong `src/ui/` (kịch bản D mở mọi nút ở Home), `Config._UNLOCK`, `Config._FEATURES`, bảng Kịch bản trong `docs/TESTING.md`, `tests/cases/*.csv`. Xong khi mọi file `src/meta/*.gd` và mọi màn, popup người chơi mở được thuộc về một dòng, hoặc có trong báo cáo là hạ tầng chung.
2. **So với design:** mỗi dòng ghi mục `design.md` khớp, hoặc "chưa có"; ghi trạng thái theo **Phạm vi**.
3. **Vòng tính năng** cho mọi dòng `chưa case`, `chưa script`, `chờ duyệt` và dòng "chưa có" mục design. Giao sub-agent: mỗi agent một nhóm tính năng có kịch bản chung một file `tests/smoke/scen_*.gd` (hai agent cùng sửa một file sẽ ghi đè nhau), tối đa 5 agent cùng lúc.
4. **Báo cáo** và thông báo.

Xong khi mọi dòng của sổ là `đủ`, `chờ duyệt`, `tắt` hoặc `chạy, chưa case`.

## feature <tính năng> [ref]

Code, design hoặc art xong task và báo: tính năng, `ref` (commit hoặc nhánh; không có thì là phần chưa commit so với HEAD), mục `design.md`, chỗ cần nhìn.

1. `tools/affected.sh <ref> -v`: file đổi, test và kịch bản được chọn. Tìm dòng sổ của tính năng; tính năng mới thì thêm dòng.
2. **Vòng tính năng.** Task design: case theo luật mới, đỏ ở chỗ code chưa theo là **lệch tài liệu**. Task art: phần chính là ảnh `window`.
3. Chạy mọi lệnh `tools/affected.sh <ref>` in ra, kể cả dòng `window` (đọc ảnh). Có dòng `Máy thật` thì thông báo cần người dùng chạy `/device-test`.
4. **Báo cáo** và thông báo kết quả cho người yêu cầu.

Xong khi mọi lệnh ở bước 3 thoát `0` hoặc mỗi đỏ đã phân loại, vòng tính năng xong, ảnh đã đọc.

## daily

Task Scheduler gọi lúc 16:00 qua `tools/qa_daily.sh`, không có người ngồi máy: chỗ cần quyết thì chọn giả định hợp lý nhất và ghi giả định vào báo cáo.

1. **Mốc:** `BASE=$(git rev-list -1 --before="$(date -d yesterday +%F) 16:00" HEAD)`. Commit mới: `git log --reverse --format='%h %ad %an %s' --date=iso $BASE..HEAD`.
2. **Duyệt commit:** với mỗi commit, `git show --stat <commit>` rồi ghi: tính năng nào đổi (dòng sổ), có cần vòng tính năng không (luật, số, màn mới; tính năng bật mới chưa có dòng), có lệch tài liệu không, commit sửa lỗi có test hồi quy không. Xong khi mỗi commit có một dòng trong báo cáo.
3. **Vòng tính năng** cho tính năng commit đổi luật hay số, và cho dòng `chờ duyệt` mà tiêu đề đã hết nhãn.
4. **Full game**, phần `window` theo `tools/affected.sh $BASE`.
5. **Báo cáo** và thông báo kết quả.

Xong khi mỗi commit có dòng trong báo cáo, mọi lệnh full game thoát `0` hoặc mỗi đỏ đã phân loại.

## full [ref]

Full game khi được yêu cầu. `ref` chọn phần `window` (mặc định là mốc của daily). Yêu cầu kèm danh sách commit thì làm bước 2 của daily cho các commit đó.

## Full game

Ghi lệnh, mã thoát và dòng cuối của từng lệnh vào báo cáo:

1. `tools/test.sh` (khoảng 7 phút, 2026-11-13).
2. `tools/smoke.sh headless <các kịch bản>`: mọi kịch bản trong bảng Kịch bản của `docs/TESTING.md`, trừ V và IDLE.
3. `SMOKE_ARGS="from=1 to=500" tools/smoke.sh headless V`.
4. `tools/smoke.sh window` cho T, L, các kịch bản có case `look`, và các kịch bản ở dòng `window` của `tools/affected.sh <mốc>`; đọc từng ảnh.

Máy thật chạy khi người dùng gọi `/device-test`. Dòng `Máy thật` của `tools/affected.sh <mốc>` có mặt thì thông báo việc đó.

## Báo cáo

`output/qa/<chế độ>-<YYYYMMDD-HHMM>/report.md`:

- HEAD, mốc, số commit, file đang sửa dở (`git status --short`).
- Từng lệnh: mã thoát, dòng cuối, đường dẫn log; trang `output/report/index.html`.
- Đỏ theo loại, lỗi game kèm lệnh tái hiện.
- Dòng sổ đổi trạng thái.
- File QA đã sửa, chưa commit.
- Thông báo đã gửi.

## Thông báo

Kênh chưa nối (2026-11-13, người dùng sẽ nối sau). Tới khi nối: mỗi thông báo là một mục trong `output/qa/<lần chạy>/notify.md`, in nguyên văn ở cuối câu trả lời. Nối kênh xong thì chỉ sửa mục này.

- **Duyệt design:** tính năng, mục `design.md` vừa viết (số dòng), mọi chỗ `CHƯA RÕ Ý ĐỊNH`, cách duyệt: bỏ `(đề xuất, chờ duyệt)` khỏi tiêu đề, sửa nội dung nếu cần.
- **Kết quả:** chế độ, đạt hay đỏ, lỗi game mới, Open Question mức Cao, việc cần người (`/device-test`, duyệt design), đường dẫn báo cáo.
