# Quy trình test

Cách kiểm một thay đổi của Candy Away: các tầng test, lệnh, điều kiện đạt, số case tối thiểu, và phần làm trên điện thoại thật. Lấy mẫu từ quy trình test của Butcher Defense (2026-11-11), viết lại cho dự án này (kế hoạch Phase 11).

Mục ghi *(Task 11.x)* là phần chưa làm xong; khi task xong thì bỏ ghi chú.

## Quy trình cho một thay đổi

1. **Có luật hoặc số mới** → `/design-note` (sửa `design.md` và thêm dòng vào mục 9 "Nhật ký quyết định"). Sửa nhỏ thì bỏ qua.
2. **Code và test.** Sửa lỗi thì test hồi quy đỏ trước (luật trong `CLAUDE.md`). Số case tối thiểu cho từng thành phần: mục **Ma trận bao phủ**.
3. **`tools/test.sh [lọc]`** → dòng cuối `ALL TESTS PASSED (<n>)`, thoát 0. Bộ này gồm cả kiểm tra tĩnh.
4. **Người chơi nhìn thấy thay đổi** (UI, VFX, animation, chữ) → `tools/smoke.sh window <kịch bản>` và **đọc ảnh PNG**. Log có `SMOKE OK` và `SMOKE ERRORS script=0 engine=0`. Test đạt chưa có nghĩa là màn đã hiện đúng.
5. **Có quyết định đáng nhớ** → một dòng trong `design.md` mục 9.

Thứ tự mặc định: headless trước (`tools/test.sh`, `tools/smoke.sh headless`). Chế độ `window` chỉ khi thay đổi hiện lên màn hình, và chỉ chạy kịch bản liên quan. MCP `godot-ai` dùng để xem và thử nhanh trong editor, không thay bước 3 và 4.

## Tầng 1: `tools/test.sh` (unit, E2E, kiểm tra tĩnh)

```bash
tools/test.sh                  # mọi tests/test_*.gd
tools/test.sh test_board       # chỉ file bắt đầu bằng test_board
```

- Bọc `tests/run_all.gd` bằng `timeout`: một lỗi script trong `-s` có thể làm Godot treo, nên đạt được xét bằng mã thoát **và** dòng `ALL TESTS PASSED (<n>)`. Mỗi lần chạy ghi vào `output/test/<YYYYmmdd-HHMMSS>-<pid>/` (`run.log`, `meta.json`; giữ 30 lần gần nhất). `TEST_TIMEOUT=<giây>` đổi hạn (mặc định 1800).
- Mỗi lúc chỉ một lần chạy: hai tiến trình chạy cùng một file test dùng chung `user://test_<tên>/` và làm hỏng kết quả của nhau, nên `tools/test.sh` giữ khoá `~/.candy_test.lock` (mọi phiên, mọi worktree). Phiên sau in "Chờ phiên khác chạy test xong" và chờ tối đa `TEST_LOCK_WAIT` giây (mặc định 2400); khoá cũ hơn hạn chạy cộng 5 phút coi là kẹt và gỡ. Gọi thẳng `run_all.gd` bằng `tools/godot.sh` thì không có khoá.
- Mã thoát: `0` sạch; `1` game có lỗi (test `FAIL`, lỗi engine ngoài allowlist); `2` hạ tầng hỏng (không có dòng kết thúc, bị `timeout` giết, Godot không chạy hoặc crash).
- `run_all.gd` tìm `tests/test_*.gd` (không đệ quy), mỗi file một instance, mỗi hàm `test_*` nhận một `T` mới (`tests/t.gd`: `eq`, `ok`, `near`, `fail`, `expect_error`, `allow`). Hạn 120 s mỗi file. Test của chính runner: `tests/test_runner.gd`.
- Lỗi engine hoặc lỗi script in ra trong lúc một test chạy làm test đó fail (bắt bằng `Logger`). Lỗi test mong đợi khai bằng `t.expect_error("<chuỗi con>")`; nhiễu engine đã biết ghi trong `tests/allow_errors.txt`, mỗi dòng kèm lý do và ngày; mỗi lần miễn in một dòng `ALLOWED`, cuối lần chạy in `ALLOWED <n>`. Lỗi ghi ra ngoài lúc một test chạy (giữa hai file, lúc dọn cuối) vẫn làm lần chạy fail.
- Lỗi `Unable to open file: res://.godot/imported/...` là cache import thiếu asset mới, không phải lỗi game: editor đóng thì chạy `tools/godot.sh --headless --path . --import`, editor mở thì để editor import (`filesystem_manage(op="scan")`). `tools/test.sh` in gợi ý này khi gặp.
- `t.eq` giữ điều kiện cũ (cùng kiểu và `==`; `==` của Godot đã so sâu Array, Dictionary); khi khác, lỗi chỉ ra phần tử khác đầu tiên (`khác ở .a[1]`).
- Không dùng golden JSON: level được sinh lại thường xuyên (500 level, Road Trip, Special).
- Test dùng file ghi trong `user://test_<tên_test>/` qua `Game.reset_for_test(path)`; ads, mua hàng, analytics, remote config, save cloud, thông báo chạy bằng mock của `Platform` (`src/platform/mock_*.gd`, `simulate()`, `calls`).
- E2E (`tests/test_e2e_demo.gd`, `tests/e2e_driver.gd`) chơi bằng solver, gọi thẳng signal `block_tapped` và `pressed`: nhanh, nhưng không qua hit-test. Lỗi kiểu "phải bấm mấy lần mới ăn" chỉ smoke bắt được.

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

- `tests/smoke/smoke.gd` (SceneTree): mở `main.tscn` như game thật và cung cấp thao tác dùng chung; kịch bản ở `tests/smoke/scenarios.gd`, save mẫu ở `tests/smoke/smoke_saves.gd`. Game boot thẳng vào level khi còn mạng (như trên máy), nên kịch bản về Home bằng Cài đặt trong màn → Home.
- Bấm là `push_input` vào toạ độ thật của nút hoặc khối (khối do solver chọn), trong toạ độ canvas (`get_global_transform_with_canvas`). Trước khi bấm, smoke đợi tối đa 2 giây cho nút đứng yên (tâm nút lệch dưới 1 px qua 2 khung; popup đang phóng to thì nút còn chạy, nút chỉ nhún tại chỗ thì không phải đợi) và hit-test trúng (`gui_get_hovered_control`), như người chơi đợi hiệu ứng xong; tâm bị che thì thử lưới 3x3 và log `SMOKE WARN`; không điểm nào trúng thì vẫn bấm tâm và log `(NOT the target: trúng <node>)`. Cú nhấn rơi vào node khác nút (nút vừa dịch đi) thì log `SMOKE WARN bấm <nút> trượt: lúc nhấn trúng <node>` và `tap` trả false.
- Như bản phát hành: `Config.demo_override`, `ui_preview_override`, `account_tool_override` về 0 (smoke chạy bằng Godot editor nên là bản debug). Link ra ngoài của Settings (mail hỗ trợ, chính sách, điều khoản) đi qua `settings.opener`; smoke thay bằng hàm chỉ log `mở URL bị chặn: <url>`, nên không bao giờ mở trình duyệt hay ứng dụng mail.
- Ads và mua hàng dùng mock của `Platform`. Khi chạy window, mock hiện lớp phủ: smoke bấm "Xem hết" và "Mua" như người dùng.
- Save mỗi kịch bản ở `user://smoke_<kịch bản>/` qua `Game.reset_for_test`; không bao giờ đụng save thật. Save mẫu dựng bằng code (`fresh`, `veteran`, `rich`, `all_unlocked`), không dùng file JSON, để không lỗi thời khi đổi schema, mốc mở tính năng hay sinh lại level. Popup lạc (quà booster, giới thiệu cơ chế, offer, mời tính năng) được đóng bằng chạm thật khi kịch bản không đợi chúng.
- Ảnh chỉ chụp ở `window`, sau khi màn yên (không popup đang đóng, không curtain, không màn chuyển level); census chạy cả headless.
- Mỗi kịch bản một tiến trình Godot, bọc `timeout`, có watchdog bên trong. `smoke.sh` giữ khoá `~/.candy_godot.lock` (chờ tối đa 10 phút; khoá cũ hơn 30 phút coi là kẹt và gỡ) để các phiên song song không tranh cửa sổ, chuột và `user://smoke_*`. Ở `window` cửa sổ cho chuột đi xuyên qua (`mouse_passthrough`); input thật vẫn tới được (phím) thì log `SMOKE REAL INPUT` và lần chạy không hợp lệ (mã 2).
- Mã thoát như tầng 1: `0` / `1` (`SMOKE FAILED`: kịch bản dừng, `SMOKE ERRORS` khác 0, vi phạm bất biến) / `2`. Lỗi engine khớp `tests/allow_errors.txt` in `SMOKE ALLOWED`, không tính.
- Kết quả: `output/smoke/<mode>/<kịch bản>/smoke.log`, ảnh PNG, `census_<ảnh>.json`, `meta.json`.

Dòng log: `SMOKE STEP`, `SMOKE SHOT`, `SMOKE CENSUS`, `SMOKE WARN`, `SMOKE FRAMES <phase> n p50 p95 max hitch` (hitch: khung > 33 ms), `SMOKE HITCH` (khung > 99 ms), `SMOKE MEM`, `SMOKE INVARIANT`, `SMOKE STATE` (màn, popup, level lúc kịch bản dừng), `SMOKE REAL INPUT`, `SMOKE ERROR`, `SMOKE ERRORS script=<n> engine=<n>`, cuối cùng `SMOKE OK` hoặc `SMOKE FAILED <lý do>`.

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
| Mỗi màn hình / popup | `[UI]`: nội dung, layout nhiều tỉ lệ, ngôn ngữ, trạng thái nút, thứ tự lớp | Smoke `window` + đọc PNG + census; `SMOKE_RES`; L |
| Mỗi trạng thái cần lưu | Bền qua kill app, save cloud, thiết bị khác | Unit (`test_save`, `test_cloud`); smoke G; thiết bị khác: chạy tay |
| Mỗi mục "chưa có ở bản đầu" (cơ chế sau demo, SKU ẩn) | 1 `[NEG]`: không xuất hiện hoặc được xử lý an toàn | Unit trên `Config` và dữ liệu level |
| Mỗi vị trí quảng cáo có thưởng | Xem xong thưởng đúng 1 lần, đóng sớm không thưởng, ads không tải được, spam nút | Unit với `mock_ads.simulate`; smoke F; ads thật: thiết bị (test device) |
| Mỗi gói IAP | Thành công, huỷ, thất bại, pending; restore gói không tiêu hao | Smoke E (`mock_iap`); trường hợp mock không giả lập được: thiết bị |
| Mỗi cảnh nặng / luồng tải | FPS trên máy thấp nhất, thời gian tải lần đầu và các lần sau, RAM sau nhiều level | `SMOKE FRAMES`, `SMOKE HITCH`, `SMOKE MEM`, kịch bản S; số thật: thiết bị |

Nhóm case: `[HP]` luồng chuẩn; `[NEG]` vi phạm điều kiện (kỳ vọng gồm dữ liệu không đổi và phản hồi UI); `[UI]` hiển thị, layout, trạng thái nút; `[EDGE]` mạng, gián đoạn, spam tap, giá trị biên, thời gian, RNG, dữ liệu. Checklist chi tiết từng nhóm nằm trong skill `/game-testcase-generator`.

## Thiết bị thật (Android)

Chưa có máy nào cắm vào máy dev (kế hoạch mục 1.1): mọi kiểm tra trên máy thật là việc thủ công của người dùng (kế hoạch mục 4). Cài bản demo: `docs/DEMO_NOTES.md`. Ngân sách: ổn định từ 30 khung/giây trên máy 2 GB (`design.md` mục 8, "Bản thử"). Số đo trên desktop không thay cho số trên điện thoại.

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

- Script kế thừa `tests/smoke/smoke.gd`, chạy `tools/godot.sh --path . --write-movie output/<việc>/video.avi --fixed-fps 30 -s <script>`.
- Ở chế độ movie, game vẽ chậm hơn thời gian thật: animation chạy theo `delta` (tween, `_process`) vẫn đúng nhịp, animation đọc đồng hồ thật (`Time.get_ticks_*`) sẽ chạy quá nhanh trong video.
- Cắt sang MP4 bằng ffmpeg (máy này chưa cài): quay chậm 0,5 lần dùng `setpts=2.0*PTS`, đặt `-t` trước `-i`.

## File sinh ra

Ảnh, log, video, Excel test case, báo cáo ghi vào `output/<việc>/` ở gốc repo (`.gitignore` bỏ qua). Riêng `tests/shots/` là ảnh của `tests/shot.gd`, được theo dõi trong git.
