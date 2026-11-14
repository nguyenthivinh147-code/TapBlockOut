# Quy trình test

Cách kiểm một thay đổi của Candy Away: các tầng test, lệnh, điều kiện đạt, số case tối thiểu, và phần làm trên điện thoại thật. Lấy mẫu từ quy trình test của Butcher Defense (2026-11-11), viết lại cho dự án này (kế hoạch Phase 11).

Mục ghi *(Task 11.x)* là phần chưa làm xong; khi task xong thì bỏ ghi chú.

## Quy trình cho một thay đổi

1. **Có luật hoặc số mới** → `/design-note` (sửa `design.md` và thêm dòng vào mục 9 "Nhật ký quyết định"). Sửa nhỏ thì bỏ qua.
2. **Code và test.** Sửa lỗi thì test hồi quy đỏ trước (luật trong `CLAUDE.md`). Số case tối thiểu cho từng thành phần: mục **Ma trận bao phủ**.
3. **`tools/test.sh [lọc]`** → dòng cuối `ALL TESTS PASSED (<n>)`, thoát 0. Bộ này gồm cả kiểm tra tĩnh. Lọc và kịch bản smoke headless theo thay đổi: `tools/affected.sh` (mục **Chọn test theo thay đổi**); `tools/affected.sh --run` chạy chúng và thoát 1 khi một hàm đã sửa hay thêm trong `src/` không test nào chạy tới (mục **Cổng test**).
4. **Người chơi nhìn thấy thay đổi** (UI, VFX, animation, chữ) → `tools/smoke.sh window <kịch bản>` (`tools/affected.sh` in dòng này) và **đọc ảnh PNG**. Log có `SMOKE OK` và `SMOKE ERRORS script=0 engine=0`. Test đạt chưa có nghĩa là màn đã hiện đúng. Luật chụp, đọc ảnh, dò chạm: `.claude/rules/ui-testing.md`.
5. **Có quyết định đáng nhớ** → một dòng trong `design.md` mục 9.
6. **Xong task (code, design, art)** → báo QA: tính năng, commit hoặc nhánh, mục `design.md`, chỗ cần nhìn. QA chạy `/qa feature` (mục **Agent test (QA)**).

Thứ tự mặc định: headless trước (`tools/test.sh`, `tools/smoke.sh headless`). Chế độ `window` chỉ khi thay đổi hiện lên màn hình, và chỉ chạy kịch bản liên quan. MCP `godot-ai` dùng để xem và thử nhanh trong editor, không thay bước 3 và 4.

## Agent test (QA)

Agent test kiểm game độc lập với người làm task, bằng skill `/qa`. Các bước, cách phân loại kết quả đỏ, báo cáo và thông báo nằm trong skill.

| Chế độ | Khi nào |
|---|---|
| `/qa onboard` | Agent test lần đầu tham gia: kê tính năng đang có, so với `design.md`. Tính năng đã có design thì tạo test case và script; chưa có thì QA tự viết design, gửi duyệt, duyệt xong mới tạo script |
| `/qa feature <tính năng> [ref]` | Code, design hoặc art xong task và báo (bước 6 ở trên) |
| `/qa daily` | 16:00 hằng ngày, Task Scheduler gọi `tools/qa_daily.sh`: full game và duyệt các commit từ 16:00 hôm trước |
| `/qa full [ref]` | Khi được yêu cầu test full game |

- Tính năng đang tắt (`Config._FEATURES`, cơ chế chưa có trong level, SKU ẩn) không cần script: kịch bản OFF kiểm chúng vẫn tắt. Tính năng đã có script chạy được thì QA chạy script đó.
- Sổ tính năng `tests/cases/FEATURES.md`: mỗi tính năng một dòng (mục `design.md`, MODULE, trạng thái). QA ghi, người khác đọc.
- Duyệt design QA tự viết: tiêu đề mục trong `design.md` mang nhãn `(đề xuất, chờ duyệt)`. Người duyệt bỏ nhãn (sửa nội dung nếu cần) là đã duyệt; lần chạy QA sau tạo test case và script.
- Full game chạy trên desktop (`tools/test.sh`, mọi kịch bản smoke, V 1–500, `window` cho case `look`). Máy thật: người dùng gọi `/device-test`.

Đăng ký lịch 16:00 một lần trên máy Windows (PowerShell, `<repo>` là đường dẫn Git Bash của repo, ví dụ `/e/...`). Máy tắt lúc 16:00 thì task chạy khi máy bật lại; cần đăng nhập Windows vì smoke `window` mở cửa sổ. Log mỗi lần ở `output/qa/scheduler/`.

```powershell
$a = New-ScheduledTaskAction -Execute "C:\Program Files\Git\bin\bash.exe" -Argument '-l "<repo>/tools/qa_daily.sh"'
$t = New-ScheduledTaskTrigger -Daily -At 16:00
$s = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 4) -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName "CandyAway QA daily" -Action $a -Trigger $t -Settings $s
```

## Chọn test theo thay đổi: `tools/affected.sh`

```bash
tools/affected.sh                  # so với HEAD: đã stage, chưa stage, file mới
tools/affected.sh main             # so với merge-base với main, cộng phần chưa commit
tools/affected.sh -v               # kèm đường đi chọn từng test và kịch bản
tools/affected.sh --run            # chạy luôn test (có đo độ phủ) rồi smoke headless, rồi cổng test
tools/affected.sh --files src/ui/shop.gd tests/smoke/scen_events.gd:120-140   # file (và dòng) cho sẵn
tools/affected.sh --check          # kiểm tests/affected_map.txt
tools/affected.sh --coverage       # đo test nào chạy qua hàm nào (cả bộ test, khoảng 10 phút) → output/coverage/map.json
tools/affected.sh --static         # chọn test theo đồ thị tĩnh dù đã có bản đo; --run thì chạy thường, không cổng test
```

In lý do cho từng file đổi, rồi các lệnh: `tools/test.sh <file test>.gd...`, `tools/smoke.sh headless <kịch bản>`, `SMOKE_ARGS="from=<a> to=<b>" tools/smoke.sh headless V` khi có level đổi, `tools/smoke.sh window <kịch bản>` khi người chơi thấy thay đổi (file trong `src/ui/`, `scenes/`, `assets/`, `data/ui_unity/`, `i18n/`, shader; chỉ kịch bản có chụp ảnh), và dòng `Máy thật` khi đổi plugin Android, `src/platform/android_*.gd`, export hay smoke máy thật (người dùng gọi `/device-test`). `--run` không chạy `window` (phải đọc ảnh) và không chạy máy thật; mã thoát là mã tệ nhất của các lệnh và của cổng test. Cần Node. Ở cổng Phase vẫn chạy `tools/test.sh` đủ (kế hoạch mục 2).

**Đồ thị tham chiếu.** File A dùng file B khi A ghi đường dẫn `res://` của B (tiền tố khi đường dẫn dựng lúc chạy, như `"res://scenes/%s.tscn"`), `uid://` của B, tên autoload của B (`Game`, `Platform`, `Sfx`, ngoài comment và chuỗi), tên file B trong chuỗi, hoặc `#include` B trong shader. Tên file trong chuỗi: có đuôi (`"popup_reward.gd"`), hoặc không đuôi khi là CamelCase (`"ShopCashLayer"`, layer Unity nạp theo tên) hay là ảnh, âm thanh, font (`ThemeKit.icon("lb_piece")`); không tính chuỗi trong `config.gd`, vì id tính năng như `"weekly_pass"` trùng tên file. JSON layer trong `data/ui_unity/` tính tên sprite nó vẽ (`"Popup_Lose"`, `"Atlas:Sprite_2"`). Sửa `foo.png.import`, `foo.gd.uid` tính là sửa `foo.png`, `foo.gd`. `project.godot`, `export_presets.cfg` không lan tiếp.

**Test theo đồ thị tĩnh** (chưa có bản đo, `--static`, file trong `tests/` và `tools/`). Mọi `tests/test_*.gd` nối tới file đổi qua đồ thị, cộng đích `test:` của dòng trong `tests/affected_map.txt` khớp chính file đổi (hạ tầng test chọn mọi test; mọi file chọn `test_static_check`). Test nạp `main.tscn` hay autoload `Game` nối tới gần như mọi file game, nên một file UI chọn khoảng 50 test, một module `meta` khoảng 52, trên 102 (2026-11-13).

**Test theo độ phủ** (có `output/coverage/map.json`). `tools/affected.sh --coverage` chép cây code (cả phần chưa commit) sang `output/coverage/snap-<pid>`, chèn vào đầu mỗi hàm của `src/**/*.gd` một dòng đánh dấu hàm vào `tests/coverage_hits.gd`, cộng một biến đánh dấu `<new>` mỗi khi tạo object của script, chạy `tools/test.sh` ở đó (`tests/run_all.gd` ghi hàm đã chạy sau mỗi file test vào `CANDY_COV_OUT`), rồi ghi bản đo: hàm nào được file test nào chạy tới, thời gian từng file test. Cây code thật không đổi. Bản đo nằm trong `output/` nên mỗi worktree đo riêng. `--coverage <lọc test>` chỉ đo các file test đó và gộp vào bản đo có sẵn. Đo lại cả bộ khi đã sửa nhiều code hay thêm test; `tools/affected.sh` in bản đo cũ bao nhiêu commit. Rồi với mỗi file đổi:

- Dòng sửa trong một hàm (bản đang sửa, hoặc bản ở `ref` với dòng đã xoá): test đã chạy qua hàm đó. Hàm mới so với bản đo: test của hàm gọi nó (cùng file gọi trơn tên, file khác gọi `.tên`); không tìm được hàm gọi thì mọi test chạy qua file.
- Dòng sửa ở `const`, `enum`, `signal`, `var`: test của các hàm nhắc tên đó, trong file và trong các file nạp file này (`Wallet.KINDS`, `Game.wallet`); `var` cộng test tạo object của script. Không ai dùng thì cả file.
- Sửa `extends`, dòng `class`, annotation, hay cả file (file mới, `--files` không kèm dòng, `.uid`): mọi test chạy qua file. Dòng chỉ có comment không chọn gì.
- Scene và resource: test tạo object của script chỉ scene đó dùng (`shop.tscn` → `shop.gd`). Không có script riêng (ảnh, JSON, shader, scene dùng script chung) thì đi ngược đồ thị tới script gần nhất có trong bản đo, lấy mọi test chạy qua script đó.
- Luôn thêm: test nhắc tên file hoặc đọc cả thư mục của nó (`"res://src/"`, `"res://scenes/"`: `test_i18n`, `test_scene_names`), đích `test:` của `tests/affected_map.txt`, và test bản đo chưa biết (test mới, test lỗi hay quá hạn trong lần đo) theo đồ thị tĩnh. Test chỉ dựng đường dẫn lúc chạy (`"res://scenes/%s.tscn"`) không tính khi file đã có trong bản đo, vì nếu nạp thì bản đo đã ghi.

Dòng `#` cuối cho thời gian của test đã chọn so với cả bộ, tính trong lần đo (chậm hơn chạy thường). `-v` in lý do chọn từng test.

**Cổng test.** Mỗi hàm của `src/**/*.gd` có dòng code đổi trong bản đang sửa (mọi hàm của file mới) phải có ít nhất một test chạy tới, trừ khi `tests/untested_allow.txt` ghi nó. `tools/affected.sh` in hai danh sách: hàm đã sửa mà bản đo không thấy test nào chạy tới, và hàm chưa có trong bản đo (hàm mới, hoặc bản đo một phần). `tools/affected.sh --run` chạy test đã chọn trên bản sao có chèn lệnh đo (`--coverage <test đã chọn>`, log chép về `output/test/`, kết quả gộp vào bản đo), chạy smoke headless, rồi xét lại: hàm nào vẫn không test nào chạy tới thì in "Cổng test" và thoát 1. Hàm mới vì vậy được xét ngay, không phải đo lại cả bộ. "Chạy tới" chỉ là mức tối thiểu: test vẫn phải kiểm kết quả của hàm, không chỉ đi qua nó. `--static` bỏ cổng.

**`tests/untested_allow.txt`.** Hàm được phép không có test: `<file>:<hàm> ## <lý do> (YYYY-MM-DD)`, `*` thay chuỗi bất kỳ trong mỗi phần, hàm của inner class viết `Class.hàm`. Chỉ ghi hàm test tự động không chạy tới được (chỉ có trên máy thật, chỉ có hình); hàm có logic thì viết test. `--check` báo dòng sai dạng hoặc không còn khớp hàm nào.

**Kịch bản smoke.**

- Từ file đổi đi ngược đồ thị, dừng ở file đầu tiên có dòng trong `tests/affected_map.txt` (một file khớp nhiều dòng thì lấy hợp). Đường dẫn tiền tố chỉ dùng khi không file game nào ghi thẳng tên file; không đi qua test và file chỉ mục `data/ui_unity/_*.json` (liệt kê mọi sprite).
- Hàm `scen_*` nhắc tên file trong chuỗi (`r.popup_script("popup_reward.gd")`) cũng chọn kịch bản của nó.
- Sửa trong `tests/smoke/*.gd`: dòng sửa quy về hàm chứa nó (hoặc về các hàm dùng hằng ở dòng đó), rồi đi theo lời gọi tới các hàm `scen_*`. Sửa trong `scen_wp` chỉ chọn WP; sửa `tap()` của runner chọn mọi kịch bản; dòng nhắc mã kịch bản (`"WP": ...`, `scen_wp(r)`) chọn mã đó. Dòng không tới kịch bản nào chọn kịch bản của file đó, hoặc bộ mặc định khi file không có kịch bản (`_ready` của runner); dòng chỉ là comment không chọn gì.
- `tests/cases/<MÃ>.csv` chọn kịch bản `<MÃ>`. `data/levels/level_<n>.json` chọn V từ level nhỏ nhất tới lớn nhất đã đổi; module bàn chơi chọn V L1–L40.

**`tests/affected_map.txt`.** Mỗi dòng `<đích...> : <mẫu...>`, kèm `## lý do` nếu cần. Đích: mã kịch bản, `*` (bộ mặc định của `tools/smoke.sh`), `-` (không kịch bản nào chạy tới, ví dụ màn chỉ mở từ `ui_gallery`), `test:<tên>`, `test:*`. Mẫu: `*` trong một thư mục, `**` qua nhiều thư mục. Chỉ cần ghi file "màn" và module; hiệu ứng, shader, ảnh, scene Unity tự tìm tới màn dùng nó. `--check` chạy trong `tools/test.sh` (`tests/test_affected.gd`) và báo: mẫu không khớp file nào, mã kịch bản hay test không có thật, kịch bản không dòng nào chọn được, file trong `src/` hay `scenes/` không tới được dòng nào. Thêm kịch bản, màn hay module mới thì thêm dòng trong cùng thay đổi.

**Giới hạn.** Đồ thị là tĩnh: tên file ghép lúc chạy (`"ic_music_" + state`) không thấy được, nên file đó đi theo đường dẫn tiền tố (thường qua `theme_kit.gd`) và chọn gần hết kịch bản. Chọn thừa thay vì chọn thiếu. Bản đo chỉ biết hàm đã chạy, không biết dữ liệu: đổi một số trong `const` dùng chung (`Config.ECON`) chọn mọi test chạy qua hàm đọc hằng đó, kể cả test không đụng tới khoá đã đổi. Bản đo cũ thì hàm đổi tên, chuyển file trông như hàm mới. Ở cổng Phase vẫn chạy `tools/test.sh` đủ.

## Tầng 1: `tools/test.sh` (unit, E2E, kiểm tra tĩnh)

```bash
tools/test.sh                  # mọi tests/test_*.gd
tools/test.sh test_board       # chỉ file bắt đầu bằng test_board
```

- Bọc `tests/run_all.gd` bằng `timeout`: một lỗi script trong `-s` có thể làm Godot treo, nên đạt được xét bằng mã thoát **và** dòng `ALL TESTS PASSED (<n>)`. Mỗi lần chạy ghi vào `output/test/<YYYYmmdd-HHMMSS>-<pid>/` (`run.log`, `meta.json`; giữ 30 lần gần nhất). `TEST_TIMEOUT=<giây>` đổi hạn (mặc định 1800).
- Mỗi lúc chỉ một lần chạy: hai tiến trình chạy cùng một file test dùng chung `user://test_<tên>/` và làm hỏng kết quả của nhau, nên `tools/test.sh` giữ khoá `~/.candy_test.lock` (mọi phiên, mọi worktree). Phiên sau in "Chờ phiên khác chạy test xong" và chờ tối đa `TEST_LOCK_WAIT` giây (mặc định 2400); khoá cũ hơn hạn chạy cộng 5 phút coi là kẹt và gỡ. Gọi thẳng `run_all.gd` bằng `tools/godot.sh` thì không có khoá.
- Mã thoát: `0` sạch; `1` game có lỗi (test `FAIL`, lỗi engine ngoài allowlist); `2` hạ tầng hỏng (không có dòng kết thúc, bị `timeout` giết, Godot không chạy hoặc crash).
- `run_all.gd` tìm `tests/test_*.gd` (không đệ quy), mỗi file một instance, mỗi hàm `test_*` nhận một `T` mới (`tests/t.gd`: `eq`, `ok`, `near`, `fail`, `expect_error`, `allow`). Hạn 120 s mỗi file (`TEST_FILE_TIMEOUT=<giây>` đổi; lần đo độ phủ dùng 600). Test của chính runner: `tests/test_runner.gd`.
- Lỗi engine hoặc lỗi script in ra trong lúc một test chạy làm test đó fail (bắt bằng `Logger`). Lỗi test mong đợi khai bằng `t.expect_error("<chuỗi con>")`; nhiễu engine đã biết ghi trong `tests/allow_errors.txt`, mỗi dòng kèm lý do và ngày; mỗi lần miễn in một dòng `ALLOWED`, cuối lần chạy in `ALLOWED <n>`. Lỗi ghi ra ngoài lúc một test chạy (giữa hai file, lúc dọn cuối) vẫn làm lần chạy fail.
- Lỗi `Unable to open file: res://.godot/imported/...` là cache import thiếu asset mới, không phải lỗi game: editor đóng thì chạy `tools/godot.sh --headless --path . --import`, editor mở thì để editor import (`filesystem_manage(op="scan")`). `tools/test.sh` in gợi ý này khi gặp.
- `t.eq` giữ điều kiện cũ (cùng kiểu và `==`; `==` của Godot đã so sâu Array, Dictionary); khi khác, lỗi chỉ ra phần tử khác đầu tiên (`khác ở .a[1]`).
- Không dùng golden JSON: level được sinh lại thường xuyên (500 level, Road Trip, Special).
- Test dùng file ghi trong `user://test_<tên_test>/` qua `Game.reset_for_test(path)`; ads, mua hàng, analytics, remote config, save cloud, thông báo chạy bằng mock của `Platform` (`src/platform/mock_*.gd`, `simulate()`, `calls`).
- E2E (`tests/test_e2e_demo.gd`, `tests/e2e_driver.gd`) chơi bằng solver, gọi thẳng signal `block_tapped` và `pressed`: nhanh, nhưng không qua hit-test. Lỗi kiểu "phải bấm mấy lần mới ăn" chỉ smoke bắt được.
- Luật UI chung (`design.md` mục 2 "Back Android và ESC", "Chạm vào UI"): `tests/test_ui_back_rules.gd` (Back lúc hướng dẫn, ở popup, dưới lớp đang tải; ESC chỉ kiểm không lọt qua hướng dẫn và lớp đang tải) và `tests/test_ui_tap_rules.gd` (dim, bấm đúp, chạm dưới màn chuyển cảnh, hai ngón, giữ rồi kéo ra). Bấm thật qua hit-test bằng `tests/ui_probe.gd` (chuột, touch nhiều ngón, Back, ESC). Chỗ game chưa theo luật nằm trong `KNOWN` đầu mỗi file: in `ALLOWED` thay vì fail, để `tools/test.sh` vẫn là cổng chung; mục nào đã đúng luật thì test fail đòi xoá khỏi `KNOWN`. Sửa một lỗi trong đó: xoá mục khỏi `KNOWN`, thấy test đỏ, rồi sửa game.

### Kiểm tra tĩnh: `tests/test_static_check.gd`

Chạy cùng `tools/test.sh`, không có lệnh riêng.

- Nạp mọi `res://**/*.gd` (bỏ `addons/`, `art/`, `reference/`, `plans/`, `output/`, `android/`, `build/`, `docs/` và thư mục có `.gdignore` trừ `tools/`): `--quit` không parse script không nối tới main scene hay autoload, nên đây là chỗ bắt lỗi cú pháp của chúng. Nạp bằng `load()` thường: nạp bản thứ hai của script đang chạy bằng `CACHE_MODE_IGNORE` làm Godot 4.7.2 crash.
- Luật máy kiểm được: không `class_name`; `src/core`, `src/meta` là `extends RefCounted` và không đụng `Node`, `Platform`, `Time.get_*`.
- Dò bí mật: `git ls-files` không có `*.jks`, `*.keystore`, `*.p12`, `google-services.json`, `android_config.json`, chuỗi `BEGIN … PRIVATE KEY`.
- Ngoại lệ trong `tests/static_allow.txt` (`<đường dẫn>:<luật> ## <lý do> (YYYY-MM-DD)`), in thành dòng `ALLOWED`; dòng không còn vi phạm nào thì test báo để xoá. Luật: `parse`, `class_name`, `pure_extends`, `pure_node`, `pure_platform`, `pure_time`, `secret`.
- Đã có ở test khác: placeholder và glyph của mọi bản dịch (`test_i18n`), font và splash (`test_shipped_assets`), tên scene (`test_scene_names`), hợp đồng plugin Android (`test_platform_android_contract`), scene gọn (`test_unity_slim`).

## Tầng 2: `tools/smoke.sh` (chơi game bằng bấm thật)

```bash
tools/smoke.sh [headless|window] [kịch bản...]     # mặc định headless A B C D E M S
tools/smoke.sh headless F G H T L                  # không nằm trong mặc định; T, L chạy window mới có ảnh
tools/smoke.sh window B                            # có cửa sổ, chụp PNG
SMOKE_RES=540x1200 tools/smoke.sh window D         # cửa sổ tỉ lệ khác (mặc định 443x960, cùng tỉ lệ 886x1920)
SMOKE_SEED=42 tools/smoke.sh headless M            # chạy lại đúng chuỗi bấm của monkey
```

Biến khác: `SMOKE_SPEED` (`Engine.time_scale`, mặc định 3 khi headless, 1 khi window), `SMOKE_TAPS` (số lần bấm monkey mỗi save, mặc định 250), `SMOKE_TIMEOUT` (giây mỗi kịch bản, mặc định 900).

- `tests/smoke/smoke.gd` (Node; desktop chạy `-s tests/smoke/smoke_main.gd` gắn node này vào root, máy thật dùng `tests/smoke/device_main.tscn` làm màn chính, mục "Thiết bị thật"): mở `main.tscn` như game thật và cung cấp thao tác dùng chung; kịch bản ở `tests/smoke/scenarios.gd`, save mẫu ở `tests/smoke/smoke_saves.gd`. Game boot thẳng vào level khi còn mạng (như trên máy), nên kịch bản về Home bằng Cài đặt trong màn → Home (`go_home_from_level`). Từ khi Màn đặc biệt mở (L50) game boot vào Home: kịch bản cần level ngay sau khi mở game gọi `Scen.ensure_playing(r, lvl)` (đang ở Home thì bấm Chơi).
- Bấm là `push_input` vào toạ độ thật của nút hoặc khối (khối do solver chọn), trong toạ độ canvas (`get_global_transform_with_canvas`). Trước khi bấm, smoke đợi tối đa 2 giây cho nút đứng yên (tâm nút lệch dưới 1 px qua 2 khung; popup đang phóng to thì nút còn chạy, nút chỉ nhún tại chỗ thì không phải đợi) và hit-test trúng (`gui_get_hovered_control`), như người chơi đợi hiệu ứng xong; tâm bị che thì thử lưới 3x3 và log `SMOKE WARN`; không điểm nào trúng thì vẫn bấm tâm và log `(NOT the target: trúng <node>)`. Cú nhấn rơi vào node khác nút (nút vừa dịch đi) thì log `SMOKE WARN bấm <nút> trượt: lúc nhấn trúng <node>` và `tap` trả false.
- Như bản phát hành: `Config.demo_override`, `ui_preview_override`, `account_tool_override` về 0 (smoke chạy bằng Godot editor nên là bản debug). Link ra ngoài của Settings (mail hỗ trợ, chính sách, điều khoản) đi qua `settings.opener`; smoke thay bằng hàm chỉ log `mở URL bị chặn: <url>`, nên không bao giờ mở trình duyệt hay ứng dụng mail.
- Ads và mua hàng dùng mock của `Platform`. Khi chạy window, mock hiện lớp phủ: smoke bấm "Xem hết" và "Mua" như người dùng.
- Save mỗi kịch bản ở `user://smoke_<kịch bản>/` qua `Game.reset_for_test`; không bao giờ đụng save thật. Save mẫu dựng bằng code (`fresh`, `veteran`, `rich`, `all_unlocked`), không dùng file JSON, để không lỗi thời khi đổi schema, mốc mở tính năng hay sinh lại level. Popup lạc (quà booster, giới thiệu cơ chế, offer, mời tính năng) được đóng bằng chạm thật khi kịch bản không đợi chúng.
- Ảnh chỉ chụp ở `window` (hoặc `capture=1` trên máy thật), sau khi màn yên (không popup đang đóng, không curtain, không màn chuyển level); census chạy cả headless.
- Mỗi kịch bản một tiến trình Godot, bọc `timeout`, có watchdog bên trong. `smoke.sh` giữ khoá `~/.candy_godot.lock` (chờ tối đa 10 phút; khoá cũ hơn 30 phút coi là kẹt và gỡ) để các phiên song song không tranh cửa sổ, chuột và `user://smoke_*`. Ở `window` cửa sổ cho chuột đi xuyên qua (`mouse_passthrough`); input thật vẫn tới được (phím) thì log `SMOKE REAL INPUT` và lần chạy không hợp lệ (mã 2).
- Mã thoát như tầng 1: `0` / `1` (`SMOKE FAILED`: kịch bản dừng, `SMOKE ERRORS` khác 0, vi phạm bất biến) / `2`. Lỗi engine khớp `tests/allow_errors.txt` in `SMOKE ALLOWED`, không tính.
- Kết quả: `output/smoke/<mode>/<kịch bản>/smoke.log`, ảnh PNG, `census_<ảnh>.json`, `meta.json`.

Dòng log: `SMOKE STEP`, `SMOKE SHOT`, `SMOKE CENSUS`, `SMOKE WARN`, `SMOKE FRAMES <phase> n p50 p95 max hitch` (hitch: khung > 33 ms), `SMOKE HITCH` (khung > 99 ms), `SMOKE MEM`, `SMOKE INVARIANT`, `SMOKE STATE` (màn, popup, level lúc kịch bản dừng), `SMOKE REAL INPUT`, `SMOKE ERROR`, `SMOKE CASE <id> pass|FAIL|look|blocked|missing`, `SMOKE CASES <kịch bản> pass= fail= look= blocked= missing=` (mục "Test case"), `SMOKE ERRORS script=<n> engine=<n>`, cuối cùng `SMOKE OK` hoặc `SMOKE FAILED <lý do>`.

Kịch bản:

| | Nội dung |
|---|---|
| A | Cài mới: splash → hướng dẫn chạm khối dưới bàn tay → thắng L1 (không có thẻ dưới L11) → L2 → Home |
| B | Người chơi lâu (L30, có booster): boot vào L30 (giới thiệu cơ chế) → Home → Chơi → thắng → thẻ thắng → Tiếp tục → L31 → Home. Kịch bản dùng nhiều nhất |
| C | Thua (level có khối bị chặn từ đầu, 2 mạng): hết MOVES → cứu bằng video → hết MOVES → Bỏ cuộc → xác nhận mất mạng → thẻ thua → Chơi lại; thua lần nữa → Chơi lại mở màn hết mạng → Home |
| D | Save mở hết tính năng: mở và đóng từng nút ở Home (popup hoặc màn), chụp từng cái |
| E | Shop: mua mọi SKU đang bán qua store giả → popup thưởng → kiểm số dư theo `Config.SKUS` |
| M | Monkey: bấm ngẫu nhiên (seed in ra log) trên save cài mới rồi save mở hết |
| S | Soak: 10 level liên tiếp từ L30, `SMOKE FRAMES` từng level và `SMOKE MEM` sau mỗi level |
| F | Ads có thưởng (ads giả): x2 ở thẻ thắng L30 đóng sớm (không thưởng, nút còn), không có video khi còn mạng (lớp "Đang tải video" rồi popup "chưa có video") và khi mất mạng (popup "Mất kết nối"), xem hết (gold cộng đúng phần nhân đôi, thẻ tự đóng); ADS Daily trong Shop đóng sớm rồi xem hết (+`ECON.shop_video_coins`, bớt 1 lượt); mở một avatar bán bằng video ở Profile |
| G | Lưu qua khởi động lại: thắng L30, dùng hint ở L31, tắt nhạc trong Settings, phát `Platform.paused` như Android rồi chạy một tiến trình Godot mới (`scen=G2`, headless, cùng save, giờ giả muộn hơn 1 phút). G2 so level, gold, từng booster, mạng, cài đặt nhạc với số G ghi trong `user://smoke_G/expect.json` và phải vào lại đúng level. Dòng của G2 in trong log của G với tiền tố `G2 \| ` |
| H | Booster ở L30: hint (có hiệu ứng gợi ý), move (+`ECON.rescue_moves` MOVES), búa (vào chế độ phá, phá một khối chưa đi được), mỗi lần trừ đúng 1 trong kho; hết hint mà đủ gold thì mua (trừ `ECON.booster_price`); hết move và hết gold thì xem video `booster_free` |
| T | Chuyển cảnh, ảnh mỗi 150 ms (`r.film`, chỉ khi `window`): level → Home, Home → Chơi (curtain kẹo), thẻ thắng → level kế, Home → Shop → Home (trượt tab), mở và đóng Settings |
| L | Mỗi ngôn ngữ của `Game.LANGS`: Home và popup Settings, census cả headless (chữ rộng hơn nhãn, ra ngoài màn, giống key chưa dịch), ảnh khi `window` |
| V | Quét level `from`–`to` (mặc định 1–500, `SMOKE_ARGS="from=1 to=40"`): chơi liền bằng solver, mỗi level một dòng `SMOKE LEVEL`; mục "Thiết bị thật" |
| WP | Weekly Pass (`scen_events.gd`), chấm từng case `smoke:WP` của `tests/cases/WP.csv`: mỗi phần (`WP_PARTS`) mở game với save dựng theo PRE COND nên độc lập, phần dừng thì case của nó là blocked và các phần sau vẫn chạy. Mở khoá sau L26, Active / Waiting, nút ở Home; tutorial (Back, tắt app, chạm dồn), How to earn rewards; key theo độ khó, Waiting, thua, x2, qua mốc tuần; nhận từng mốc, Nhận tất cả, Bonus Bank, chạm dồn; mua VIP (huỷ, lỗi, pending, mất mạng, chờ store), Upsell; sang mùa (tắt app, resume, layer đang mở); lưu qua tắt app, không mạng, analytics, FRAMES; bố cục ở 4 tỉ lệ màn và 14 ngôn ngữ. Headless đặt cửa sổ 443x960 (Godot headless bỏ qua `--resolution`). `SMOKE_ARGS="parts=bank,drag"` chạy vài phần. Khoảng 6 phút headless; `window` chậm hơn nên đặt `SMOKE_TIMEOUT=2400` |
| CO | Chain Offer (`scen_events.gd`): không bắt đầu trước mốc; bắt đầu, tự mở một lần; gói khoá; nhận đủ 8 bước (free, ads, mua), đóng ads sớm và huỷ mua không thưởng; cửa sổ 6 ô trượt; hết hạn đóng màn, cooldown; chuỗi sau xoay vòng |
| SP | Special Pack (`scen_events.gd`): ẩn khi chưa mua Starter và dưới `level_appear`; bản sale cuối tuần; huỷ mua không thưởng; mua đúng số; ẩn sau khi mua (giới hạn 1) |
| RT | Road Trip (`scen_modes.gd`): tab khoá trước L95; hướng dẫn lần đầu; chơi level bằng solver, không đổi gold, mạng, level chính, điểm League, key Weekly Pass; hồi sinh bằng video đúng `revive_max` lần rồi thẻ thua, không mất mạng; hộp quà có avatar và hộp khi avatar đã có |
| LB | Leaderboard (`scen_modes.gd`): khoá trước L70; vào giải Silver; hướng dẫn; điểm theo crystal; lên giải Gold và nhận thưởng đúng một lần; hết tuần lúc đang mở (kết quả tuần, tuần mới) |
| SB | Màn đặc biệt (`scen_modes.gd`): không icon trước L50; mời và 1 vé; bom chỉ đếm sau lần chạm đầu, đứng khi mở cài đặt; bom nổ không mất gì; hết vé, vé hồi đúng giờ; thắng +1 booster, x2 miễn phí một lần |
| DG | Quà 28 ngày (`scen_meta.gd`): khoá trước mốc; thẻ thắng báo mở; chấm đỏ; nhận ô hôm nay đúng số, nhận hai lần không thêm; nhận trước bằng video (đóng sớm không thưởng); qua 00:00 (cả lúc đang ở Home), múi giờ, lùi giờ; ô 28 rồi về tuần 1 |
| PR | Profile (`scen_meta.gd`): avatar và frame bán bằng video (xem thử, đóng sớm, xem hết rồi đeo), món của Road Trip và league khoá; biệt danh gõ bằng phím thật: mặc định, quá ngắn, ký tự cấm, tên cấm, giới hạn độ dài, cắt khoảng trắng, X không lưu |
| IDLE | Để yên lâu (`scen_ui.gd`, chạy tay): Home, Shop, màn chơi, mỗi nơi đứng yên `stay` giây thật (mặc định 60; `SMOKE_ARGS="stay=1800" SMOKE_TIMEOUT=6000` là 30 phút mỗi nơi), `SMOKE FRAMES idle <nơi>` và `SMOKE MEM` trước, sau; object không tăng quá 200; rồi vẫn nhận chạm (Settings mở và đóng, tab Home, thắng level). Trên máy: `tools/device_smoke.sh run IDLE stay=1800` với `DEVICE_MAX` đủ lớn |
| OFF | Tính năng đang tắt (`scen_meta.gd`, `Config._FEATURES`): Daily Challenge và Win Streak không mở ở level nào, không icon, không có trên thẻ thắng, sự kiện streak đang chạy không đếm |

**Monkey (M).** Mỗi lần: nút bấm được ở lớp trên cùng (popup trên cùng, hoặc popup lồng bên trong nó như hướng dẫn của Weekly Pass, hoặc lớp phủ mock nếu có, không thì màn hiện tại; lúc màn chuyển cảnh `Main.curtain` đang chạy thì không bấm gì, như người chơi đợi nó mở ra), hoặc 40% là toạ độ ngẫu nhiên trên bàn khi đang chơi; hướng dẫn L1 thì chạm theo bàn tay. Không bao giờ bấm: `SupportButton`, `VersionButton` (10 lần chạm mở menu tester), `GalleryButton`, `DebuggerButton`, `WipeButton`, `SaveButton`, `PrivacyButton`, mọi thứ trong menu tester, `popup_update` (mở store), `ui_gallery`; link của Settings đã bị chặn nên bấm được. Đạt khi không có lỗi script hay engine và không kẹt: 20 lần bấm liền không đổi màn, popup (kể cả popup lồng), bàn chơi hay các số người chơi thấy (gold, booster, level, mạng, cài đặt, avatar, quà ngày, mua hàng).

**Bất biến.** Mọi kịch bản kiểm mỗi 30 khung hình; vi phạm 3 lần liên tiếp mới báo `SMOKE INVARIANT <tên> <giá trị>` và làm kịch bản fail (để không báo nhầm khi trạng thái đổi giữa chừng một khung). Danh sách: gold, từng booster, mạng là số hữu hạn ≥ 0; mạng ≤ `Lives.max_for(s)`; level ≥ 1 (sau L500 game lặp nội dung nên không có trần); MOVES ≥ 0 trong level; chồng popup không quá 3 lớp. Cuối mỗi kịch bản: save trên đĩa khớp bộ nhớ (gold, level, booster, mạng) sau `save_now`.

**Census.** Mỗi ảnh có `census_<ảnh>.json`: mọi Label đang hiện với chữ đã dịch, khung, cỡ, màu, đường dẫn node. Nhãn trong khung cắt (ScrollContainer, Unity Mask: `clip_contents`, `clip_children`) chỉ tính phần nằm trong khung; cuộn khuất hẳn thì bỏ qua. Cảnh báo (không fail): chữ giống key `tr()` chưa dịch, nhãn ra ngoài màn, chữ một dòng rộng hơn nhãn.

## Báo cáo: `output/report/index.html`

`tools/report.mjs` đọc log trong `output/` và sinh trang HTML; `tools/test.sh` và `tools/smoke.sh` tự gọi khi chạy xong, chạy tay bằng `node tools/report.mjs`.

- Đầu trang: commit, file đang sửa dở, thời gian, số đạt / lỗi / bỏ qua.
- Test lỗi kèm lý do; lỗi engine gom theo nội dung kèm số lần; mục trong allowlist hiện là Skipped, không phải Passed.
- Mỗi kịch bản smoke: các bước, ảnh thu nhỏ (bấm để xem to), FRAMES p50/p95/max, vi phạm bất biến, cảnh báo census.
- So với lần chạy trước có cùng chuỗi lọc (phiên khác có thể chạy bộ lọc khác xen giữa): test mới lỗi, test vừa hết lỗi. `node tools/report.mjs output/test/<lần chạy>` sinh lại báo cáo của một lần chạy cũ.
- Ảnh dẫn bằng đường dẫn tương đối; muốn gửi người khác thì nén cả `output/`.

## Công cụ kiểm khác

- `tools/validate_levels.gd`: khung, cỡ bàn, giải được, khối thoát ngay, công thức `min_taps` / MOVES của mọi level. Chạy sau mỗi lần sinh level.
- `tools/compress_textures.gd -- --check`: ảnh chưa nén theo luật kế hoạch mục 1.3.
- `tests/shot.gd`: chụp màn cố định vào `tests/shots/` (được theo dõi trong git) để so trước và sau.
- `node tools/sim.mjs`: mô phỏng kinh tế 28 ngày (`design.md` mục 5, "Bảng mô phỏng"). Số đọc thẳng từ `src/config.gd` (mặc định, chưa Remote Config) và `data/levels/`; hành vi người chơi là giả định ghi trong file. Đổi số kinh tế hay sinh lại level thì chạy lại và cập nhật bảng.

## Test case (`tests/cases/`)

Mỗi tính năng có một danh sách test case theo form của skill `/game-testcase-generator`, lưu trong repo. Kịch bản smoke và unit test chấm từng case theo ID, nên bao phủ đếm được bằng máy.

**File.** `tests/cases/<MODULE>.csv`, `<MODULE>` là mã kịch bản smoke viết hoa (`WP`, `RT`...). UTF-8, ô nhiều dòng đặt trong ngoặc kép. Cột: 11 cột của skill (`ID, CASE, PRIORITY, DESCRIPTIONS, PRE COND, INPUT, STEP, EXPECTED RESULT, ACTUAL RESULT, STATUS, NOTE`) cộng `AUTO`. ID Level 3 là `TC_CA_<MODULE>_<3 số>`; dòng Level 1, 2 (`M01`, `M01.1`) để trống `AUTO`. Excel để người duyệt (cả Open Questions và Test Data) sinh từ CSV vào `output/testcase-<module>/`. Thư mục có `.gdignore` để Godot không import CSV thành bản dịch.

**Cột AUTO**, nơi case được chấm:

| Giá trị | Nghĩa |
|---|---|
| `smoke:<kịch bản>` | Kịch bản smoke chấm bằng `r.tc`, `r.tc_look` hoặc `r.tc_blocked` với đúng ID |
| `unit:test_<file>` | `tests/test_<file>.gd` có assert cho case, ID ghi trong comment cạnh assert hoặc trong thông báo của assert |
| `todo:smoke:<kịch bản>`, `todo:unit:test_<file>` | Đã chọn tầng, chưa viết. Skill sinh case luôn ghi `todo:`; task viết kịch bản đổi thành giá trị thật |
| `manual:<lý do>` | Không tầng tự động nào quan sát được: âm thanh, rung, cảm giác chơi, SDK quảng cáo và mua hàng thật, máy 2 GB |

Chọn tầng theo cột "Tầng tự động gợi ý" của ma trận bao phủ: công thức, ngưỡng số, chu kỳ thời gian, bảng tỉ lệ đi unit; luồng qua UI (chạm, popup, chuyển màn, số trên màn, lưu qua mở lại app) đi smoke; một case có thể có unit cho công thức và smoke cho luồng, khi đó tách thành hai case.

**Chấm trong smoke** (`tests/smoke/smoke.gd`):

- `r.tc(id, ok, detail)` ngay khi kết quả kỳ vọng thấy được; `detail` ghi số thấy so với số kỳ vọng. In `SMOKE CASE <id> pass|FAIL <detail>`. FAIL không dừng kịch bản, các case sau vẫn chạy; cuối lần chạy còn case FAIL thì `SMOKE FAILED case FAIL: <id>...`.
- `await r.tc_look(id, shot)` cho case `[UI]` cần mắt (layout, chữ đè, màu, thứ tự lớp): chụp rồi in `look <ảnh>`. Người hoặc agent đọc ảnh rồi chấm. Headless không có ảnh nên case là `blocked`; chạy `window` hoặc `capture=1` để có ảnh.
- `r.tc_blocked(id, why)` khi bước trước hỏng nên case không chấm được.
- Cuối lần chạy, case `smoke:<kịch bản>` của CSV chưa được chấm in `missing` và làm kịch bản fail. Một ID chấm nhiều lần lấy kết quả nặng nhất (FAIL > blocked > look > pass).

**Kỳ vọng độc lập với code game.** Số kỳ vọng lấy từ cột EXPECTED RESULT (nguồn `design.md`), ghi thẳng trong kịch bản cạnh ID. Không tính lại kỳ vọng bằng `Config`, `src/meta` hay hàm của game: kịch bản phải chấm đúng cả khi code game tính sai hoặc `config.gd` lệch `design.md`. Dùng `Config` chỉ khi EXPECTED RESULT nói kỳ vọng đi theo cấu hình (Remote Config, dữ liệu level) và ghi rõ khoá.

**Phân loại case FAIL.** NOTE có mã Open Question (`OQ-xx`) thì báo là "OQ chưa chốt" kèm giả định, chưa phải lỗi game. Còn lại: lỗi smoke (chạm trượt, đợi thiếu) sửa trong smoke; lỗi game báo kèm ID, câu luật trong `design.md` và số thấy được.

**Kiểm bằng máy.** `tests/test_cases.gd` (chạy trong `tools/test.sh`): đúng cột, ID không trùng và đúng module, nhãn `[HP]`/`[NEG]`/`[UI]`/`[EDGE]`, `P0`–`P2`, `STATUS`, ô bắt buộc có chữ, `AUTO` đúng dạng; mỗi case `smoke:` có ID trong `tests/smoke/*.gd`, mỗi case `unit:` có ID trong file test đó; mọi ID trong code test có trong CSV. In dòng `CASES <MODULE>: <n> case; smoke, unit, todo, manual; [HP], [NEG], [UI], [EDGE]`. Báo cáo HTML có bảng test case của từng kịch bản smoke.

**Quy trình cho một tính năng:**

1. Sinh case: skill `/game-testcase-generator` ra `tests/cases/<MODULE>.csv` (mọi `AUTO` là `todo:` hoặc `manual:`) và Excel. Xong khi `tools/test.sh test_cases` đạt và dòng `CASES` đủ 4 nhãn.
2. Duyệt: người dùng xem Excel, chốt Open Questions mức Cao (hoặc chấp nhận giả định).
3. Viết test: mỗi case `todo:` thành `smoke:` hoặc `unit:` cùng code chấm nó. Xong khi dòng `CASES` có `todo 0`, `tools/test.sh` đạt, `tools/smoke.sh headless <kịch bản>` in `missing=0`, và mỗi case FAIL đã được phân loại.
4. Case `look`: chạy `tools/smoke.sh window <kịch bản>`, đọc từng ảnh có trong dòng `look`, ghi kết quả vào báo cáo.

## Ma trận bao phủ

Nguồn duy nhất của ma trận (skill `/game-testcase-generator` trỏ tới đây). Dùng ở bước 2: mỗi thành phần trong `design.md` phải có đủ case tối thiểu. Ô nào không tự động được (mất mạng thật, đổi thiết bị) thì phải có test case chạy tay.

| Thành phần trong `design.md` | Tối thiểu phải có | Tầng tự động gợi ý |
|---|---|---|
| Mỗi tính năng / luồng | 1 `[HP]` + ít nhất 1 `[NEG]` hoặc `[EDGE]` | Smoke: kịch bản mới hoặc bước thêm vào kịch bản có sẵn; E2E |
| Mỗi điều kiện / ràng buộc | 1 `[NEG]`; có ngưỡng số thì thêm case biên | Unit |
| Mỗi ngưỡng số (giá, level mở tính năng, MOVES, mạng) | Ngưỡng−1 và đúng ngưỡng | Unit; smoke với save dựng ở `smoke_saves.gd` |
| Mỗi công thức (độ khó, `min_taps`, thưởng) | Giá trị đại diện, mốc đổi hành vi, làm tròn, giá trị cực, đổi tham số trong `config.gd` | Unit |
| Mỗi level hoặc cơ chế khối mới | Giải được, MOVES đúng công thức, vừa khung, có trong level dạy cơ chế | `tools/validate_levels.gd`, `test_levels_all`, `test_generator` |
| Mỗi giao dịch gold / booster / mạng / mua hàng | Mất mạng, kill app, spam tap | Smoke E với store giả; mất mạng, kill app thật: thiết bị |
| Mỗi bảng tỉ lệ / RNG | Kiểm thống kê từng dòng (±3σ, σ = √(N·p·(1−p))) và tổng tỉ lệ = 100% | Unit, seed cố định |
| Mỗi chu kỳ reset (quà ngày, ads daily, Weekly Pass, league, hồi mạng) | Biên thời điểm, không reset sai mốc, đổi giờ máy | Unit với đồng hồ giả (`test_now`, `src/meta/clock.gd`); smoke G |
| Mỗi màn hình / popup | `[UI]`: nội dung, layout nhiều tỉ lệ, ngôn ngữ, trạng thái nút, thứ tự lớp; popup: dim chặn chạm phía sau, chạm nền, Back Android, thứ tự với popup tự mở khác | Smoke `window` + đọc PNG + census; `SMOKE_RES`; L; dim, Back của popup mở từ Home: `test_ui_tap_rules`, `test_ui_back_rules` |
| Mỗi nút mở màn, mở popup hoặc giao dịch | `[EDGE]`: bấm đúp nhanh (chỉ lần 1 có tác dụng), bấm trong lúc chuyển cảnh hoặc đang tải, nhiều ngón cùng lúc, giữ rồi kéo ra | `test_ui_tap_rules` (nút ở Home, nút Chơi), `test_ui_back_rules` (lớp đang tải); nút ở màn khác: thêm vào hai file đó |
| Mỗi cặp màn hoặc popup mở được nhau | `[EDGE]`: đi vòng nhiều lần, chồng popup không tăng, Back lùi đúng từng lớp | Smoke (bất biến chồng popup ≤ 3) |
| Mỗi trạng thái cần lưu | Bền qua kill app, save cloud, thiết bị khác | Unit (`test_save`, `test_cloud`); smoke G; thiết bị khác: chạy tay |
| Mỗi mục "chưa có ở bản đầu" (cơ chế sau demo, SKU ẩn) | 1 `[NEG]`: không xuất hiện hoặc được xử lý an toàn | Unit trên `Config` và dữ liệu level |
| Mỗi vị trí quảng cáo có thưởng | Xem xong thưởng đúng 1 lần, đóng sớm không thưởng, ads không tải được, spam nút | Unit với `mock_ads.simulate`; smoke F; ads thật: thiết bị (test device) |
| Mỗi gói IAP | Thành công, huỷ, thất bại, pending; restore gói không tiêu hao | Smoke E (`mock_iap`); trường hợp mock không giả lập được: thiết bị |
| Mỗi cảnh nặng / luồng tải | FPS trên máy thấp nhất, thời gian tải lần đầu và các lần sau, RAM sau nhiều level, để yên lâu (đề xuất 30 phút) rồi chơi tiếp | `SMOKE FRAMES`, `SMOKE HITCH`, `SMOKE MEM`, kịch bản S; số thật: thiết bị; để yên lâu: kịch bản IDLE |

Nhóm case: `[HP]` luồng chuẩn; `[NEG]` vi phạm điều kiện (kỳ vọng gồm dữ liệu không đổi và phản hồi UI); `[UI]` hiển thị, layout, trạng thái nút; `[EDGE]` mạng, gián đoạn, spam tap, giá trị biên, thời gian, RNG, dữ liệu. Checklist chi tiết từng nhóm nằm trong skill `/game-testcase-generator`.

## Thiết bị thật (Android)

Cài bản demo: `docs/DEMO_NOTES.md`. Ngân sách: ổn định từ 30 khung/giây trên máy 2 GB (`design.md` mục 8, "Bản thử"). Số đo trên desktop không thay cho số trên điện thoại. Âm thanh trễ, rung, cảm giác chơi vẫn là việc thủ công của người dùng (kế hoạch mục 4).

### Smoke trên máy: `tools/device_smoke.sh` (Task 11.5, 11.6)

Chạy trọn bộ trên máy (mọi kịch bản và 500 level) bằng skill `/device-test`. Lệnh rời:

```bash
export JAVA_HOME="C:/Program Files/Android/Android Studio/jbr"      # Windows, như export_apk.sh
GODOT=<exe> SNAP=<thư mục> tools/device_smoke.sh build              # build/CandyAway-demo.apk và build/CandyAway-smoke.apk
adb install -r build/CandyAway-smoke.apk
tools/device_smoke.sh run A capture=1                              # cài mới, có ảnh
tools/device_smoke.sh run S G                                      # soak 10 level; lưu qua lần tắt app thật
tools/device_smoke.sh run V                                        # 500 level, đợt 50, khoảng 75 phút
adb install -r build/CandyAway-demo.apk                            # xong thì cài lại bản demo
```

- `GODOT`: Godot 4.7.2 có export template Android, editor settings trỏ JDK 17, Android SDK và debug keystore. Máy Windows này dùng bản tự chứa (có file `_sc_` cạnh exe, settings riêng trong `editor_data/`) để không đụng editor đang mở: tìm `godot_sc/Godot_v4.7.2-stable_win64.exe` trong `%TEMP%/claude/*/*/scratchpad/`; không còn thì hỏi người dùng. `SNAP`: thư mục snapshot; dùng lại thư mục cũ (đã có `android/build`) thì bỏ được bước cài Gradle template, mỗi lần build khoảng 2–3 phút cho mỗi APK.
- Template Android xuất ra bỏ qua `-s` (kể cả bản debug), nên `build` chép cây code sang snapshot (`SNAP`, mặc định `output/device/snap`; Windows dùng `robocopy`), xuất bản demo thường, rồi đổi màn chính của snapshot thành `tests/smoke/device_main.tscn` (gốc là runner `smoke.gd`), cho preset `Android Demo` mang `tests/smoke/`, và xuất APK smoke. Code game trong snapshot lấy bản HEAD (phiên song song có thể đang sửa dở), test và tool lấy bản đang sửa; `SNAP_GAME=worktree` lấy cả code game đang sửa. Cây code thật không đổi. APK smoke cùng package và chữ ký với bản demo: cài đè lên nhau, giữ dữ liệu; mở app là chạy smoke.
- V (quét level, `tests/smoke/scen_levels.gd`): mỗi đợt một lần mở app, chơi liền bằng solver; mỗi level một dòng `SMOKE LEVEL <n> ok taps= moves=<còn>/<đầu> board=` hoặc `SMOKE LEVEL FAIL L<n>: <lý do>` (không vào được, hình ra ngoài khung cổng, khung cổng ra ngoài màn, hết MOVES, solver không có nước); level hỏng thì mở save mới ở level kế và chạy tiếp. `levels.tsv` ở thư mục kết quả gộp mọi đợt (kết quả, chạm, MOVES, cỡ hình, khung hình, solver). Mặc định chạm liên tục (khung hình là trường hợp nặng); `pace=0.5` chạm theo nhịp người chơi để đo khung hình vài level. Desktop: `SMOKE_ARGS="from=1 to=40" tools/smoke.sh headless V`.
- `run` ghi tham số vào `user://device_smoke_args.txt` bằng `run-as` (APK debug), mở app bằng `GodotAppLauncher` (`GodotApp` không export, `am start` bị từ chối), theo `logcat` tới `SMOKE OK`/`FAILED`, lấy PSS (`dumpsys meminfo`) mỗi 5 giây, kéo census và ảnh về `output/device/<thời điểm>/<kịch bản>/` (`logcat.txt`, `pss.txt`, `summary.txt`). Trên Android smoke không tự thoát; script force-stop.
- G trên máy (`restart=external`): sau khi ghi số mong đợi, smoke in `SMOKE G READY` và đợi; script bấm Home (onPause thật của Android), force-stop, rồi tự chạy G2 trên cùng save.
- Kiểm trước khi chạy: đúng một máy (hoặc `ANDROID_SERIAL`), đã cho phép gỡ lỗi USB, không khoá. Bật `svc power stayon usb` trong lúc chạy, xong trả lại như cũ. Không chạm vào máy khi đang chạy (`SMOKE REAL INPUT`).
- `summary.txt`: thời gian khởi động (từ dòng đầu của Godot tới `SMOKE START` và tới main boot xong; `am start -W` là tới khung đầu), `SMOKE FRAMES` và `SMOKE SOLVER` từng level, `SMOKE MEM`, lỗi, PSS thấp nhất, cao nhất, cuối.
- Đo khung hình như người chơi: `run S idle=3 pace=0.5` (pha `idle L<n>` 3 giây bàn đứng yên, rồi chạm mỗi 0,5 giây). Mặc định smoke chạm cách 2 khung, nhiều khối trượt cùng lúc: đó là trường hợp chạm liên tục, nặng hơn người chơi thường. Solver của smoke chạy trên luồng chính trong khung đang đo (`SMOKE SOLVER`): khung giật trùng lần solver chạy là của smoke, không phải của game.
- adb server bị khởi động lại thì máy chưa tích "Luôn cho phép từ máy tính này" sẽ hỏi lại quyền gỡ lỗi USB và `adb devices` báo `unauthorized`. Thủ phạm hay gặp: chính lúc export APK, Godot dò máy bằng adb của Android SDK (`export/android/android_sdk_path`), khác phiên bản với adb trong PATH (máy Windows này: 34.0.3 và 37.0.1), nên thay server; `build` cuối cùng trả server về adb trong PATH. Nhờ người dùng tích "Luôn cho phép" một lần. Lúc bắt đầu: script dừng mã 2, nhờ người dùng bấm Cho phép rồi chạy lại. Giữa chừng: app trên máy vẫn chạy, script in `mất kết nối adb`, chờ, rồi nối logcat từ dòng cuối đã có.

**Lần đo đầu, 2026-11-12** (vivo V2206: Snapdragon 680, Adreno 610, 8 GB, 720×1612, 60 Hz, Android 14; không phải máy 2 GB của ngân sách):

| | Kết quả |
|---|---|
| A, S, G→G2 | Đạt, không lỗi script hay engine; ảnh A (màn tải, hướng dẫn L1, L2, Home) hiện đúng. G2 đọc đúng save sau Home + force-stop |
| Khởi động | Lần đầu sau khi cài: 3,5 giây tới autoload, 9,1 giây tới main boot xong (gồm một ảnh chụp). Các lần sau: 2,1 và 6,4–6,9 giây (`splash_min_sec` 1,5) |
| Bộ nhớ | PSS 300–380 MB; object, node không tăng qua 10 level, orphan 0 |
| Chơi theo nhịp người (`pace=0.5`, L30–L39) | Trung vị 16,6 ms (60 FPS), p95 18,6–21,3 ms; khung > 33 ms 2–8 mỗi level (L38: 30/1759), phần lớn trùng lần solver chạy (2–16 ms, tối đa 56 ms) |
| Bàn đứng yên | 16,6–18,5 ms; L38 20,8 ms (48 FPS) |
| Chạm liên tục (mặc định) | Trung vị 17–27 ms, p95 40–51 ms |

**Lần chạy đủ, 2026-11-12** (Task 11.6; game bản HEAD 1ee91af):

| | vivo V2206 (720×1612, 60 Hz) | Samsung SM-F731B (Snapdragon 8 Gen 2, 1080×2640, 120 Hz, Android 17) |
|---|---|---|
| Kịch bản | 17/21 đạt; RT, LB, DG đỏ vì lỗi game (cũng đỏ trên desktop); D đỏ vì smoke chạm tâm nút "No thanks" phủ cả popup (đã sửa: `tap` thử tâm các Label con) | D (sau khi sửa smoke), A, L đạt |
| Level | 500/500 đạt (V 1–500, chạm liên tục); p95 trung bình 46,5 ms, ≤ 33 ms chỉ ở 8 level đầu | L165–167, L420–424 theo nhịp `pace=0.5`: trung vị 8,3 ms, p95 10,3–11,3 ms, 2–5 khung > 33 ms mỗi level (L422: 29/4959), lẻ tẻ tới 110 ms |
| Khởi động | 2,0–2,2 giây tới autoload, 6,3–7,4 giây tới main boot xong | 0,9–1,2 và 3,5–5,1 giây |
| PSS cao nhất | 424 MB (M, monkey) | 533 MB |

Kết quả từng lần ở `output/device/<thời điểm>/`; bảng 500 level gộp ở `output/device_levels/levels_1-500.tsv`.

Kinh nghiệm từ Butcher Defense (cùng Godot 4.7.2, `gl_compatibility`), dùng khi bắt đầu đo trên máy:

- `adb` trên máy Windows này nằm trong PATH (`C:\adb\platform-tools`); trên máy Linux theo kế hoạch là `~/Android/Sdk/platform-tools/adb`. Nhiều máy cắm cùng lúc thì mọi lệnh cần `ANDROID_SERIAL`.
- Điện thoại phải mở khoá khi cài (`INSTALL_FAILED_ABORTED: User rejected permissions`). Máy đang khoá thì engine khởi động mà không chạy khung nào: script đo phải kiểm khoá trước khi bắt đầu.
- Template release bỏ qua `-s`, launcher bỏ tham số intent: harness đo trên máy đi qua một autoload trong `assets/override.cfg` của APK, in một dòng `PERF` mỗi giây (fps, ms script, ms draw, bộ nhớ).
- Sửa APK bằng `zipfile` của Python làm hỏng tên file không phải ASCII (crash khi boot): dùng `zip`.
- Tắt vsync không mở khoá FPS trên Android. `OS.get_memory_info().physical` trả -1 trên Android: đọc `/proc/meminfo`.
- Lần mở đầu sau khi cài phải biên dịch shader (khung draw vài trăm ms): đo lần đầu và các lần sau riêng.
- Samsung giới hạn bộ đệm log 5 MB: giữ một luồng `adb logcat` chạy suốt, bản dump cuối có thể rỗng.
- Chỉ so hai bản build cùng một cây code. Bộ nhớ đo bằng PSS (`dumpsys meminfo <package>`).
- Lệnh `pkill -f <tên>` gọi từ một dòng bash có chứa cùng tên đó sẽ giết luôn shell đang gọi.

**Quảng cáo thật.** Trên bản có id AppLovin MAX thật, bấm vào ads từ máy dev có thể bị tính là traffic không hợp lệ:

- Trước khi tự động hoá trên máy, đăng ký máy vào test device của MAX (`testDeviceIds`), build lại; log phải có `Test Mode On: true`.
- Trong vòng lặp bấm, cứ trước mỗi lần bấm đọc `dumpsys activity activities | grep topResumedActivity`; gặp `com.applovin.adview.AppLovinFullscreenActivity` (đang hiện ads) thì dừng bấm. Bấm mù vào toạ độ cố định theo nhịp là cách đã làm bấm trúng ads thật.
- Ads test của MAX đôi khi không có nút đóng: bấm nút "Google Play" góc trên trái, Back, nút X hiện ra.
- Đang hiện ads thì không mở lại game bằng `am start`: Godot bị đóng và mở lại, mất kết quả rewarded.

## Quay video review

- Script kế thừa `tests/smoke/smoke.gd` (Node) cộng một launcher SceneTree như `tests/smoke/smoke_main.gd`, chạy `tools/godot.sh --path . --write-movie output/<việc>/video.avi --fixed-fps 30 -s <script>`.
- Ở chế độ movie, game vẽ chậm hơn thời gian thật: animation chạy theo `delta` (tween, `_process`) vẫn đúng nhịp, animation đọc đồng hồ thật (`Time.get_ticks_*`) sẽ chạy quá nhanh trong video.
- Cắt sang MP4 bằng ffmpeg (máy này chưa cài): quay chậm 0,5 lần dùng `setpts=2.0*PTS`, đặt `-t` trước `-i`.

## File sinh ra

Ảnh, log, video, Excel test case, báo cáo ghi vào `output/<việc>/` ở gốc repo (`.gitignore` bỏ qua); báo cáo của QA ở `output/qa/`. Riêng `tests/shots/` là ảnh của `tests/shot.gd`, được theo dõi trong git.
