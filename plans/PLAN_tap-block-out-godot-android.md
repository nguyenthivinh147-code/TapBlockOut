# Kế hoạch triển khai: Tap Block Out (Godot 4.7.2, Android gốc)

Tạo ngày 2026-11-01, đối chiếu lại với thư mục thực tế cùng ngày. Đây là nguồn chân lý duy nhất cho việc thực thi. Sub-agent có bộ nhớ độc lập, chỉ biết những gì đọc từ file này và các file được nêu trong task.

**Thứ tự ưu tiên khi mâu thuẫn:**
- Luật chơi, con số, nội dung: [`design.md`](../design.md) thắng.
- Kiến trúc, tên file, interface: file này thắng.
- `reference/horus/*` chỉ để tham khảo. Rule trong đó (build bằng Horus, "không thêm SDK khác", JavaScript) **không áp dụng**. Trước Task 0.1 các file này còn ở gốc, kể cả `AGENTS.md`; quy tắc này áp dụng như nhau.

---

## 1. Architecture & Shared Context

### 1.1 Trạng thái lúc lập kế hoạch

- Có sẵn: `design.md`, `tools/sim.mjs`, `plans/`, các file Horus ở gốc, và phần do editor và MCP tạo: `project.godot`, `icon.svg`, `icon.svg.import`, `.gitignore`, `.gitattributes`, `.editorconfig`, `.godot/`, `addons/godot_ai/` (4.3.1). Chưa phải git repo. Chưa có `src/`, `scenes/`, `tests/`, `export_presets.cfg`, `CLAUDE.md`.
- `project.godot` hiện lệch với kế hoạch, Task 0.2 sửa: tên `TabBlockOut`, renderer `mobile`, feature `Mobile`, chưa có cỡ cửa sổ, hướng màn hình, main scene và autoload của game. Autoload `_mcp_game_helper` và plugin `godot_ai` phải giữ.
- `.gitignore` hiện có `/android/`, sẽ chặn mã plugin của Phase 10. Task 0.1 thay.
- Godot: `/home/tungcv2/Projects/Godot/Engine/Godot_v4.7.2-stable_linux.x86_64`, editor đang mở project này. **Chưa có export templates** (thư mục rỗng).
- Android SDK: `~/Android/Sdk` (build-tools 36.0.0, 37.0.0; platform android-37.0; `sdkmanager` có sẵn; không có NDK). `adb` không nằm trong PATH: dùng `~/Android/Sdk/platform-tools/adb`. Editor settings đã trỏ tới SDK này.
- Debug keystore: editor settings trỏ tới `~/.local/share/godot/keystores/debug.keystore` nhưng **file chưa tồn tại**. Task 0.3 tạo.
- Java: chỉ có OpenJDK 21 tại `/usr/lib/jvm/java-21-openjdk-amd64`. `JAVA_HOME` và `java_sdk_path` của editor đang rỗng.
- Không có `ffmpeg`, `gradle` toàn cục, `sox`, `xvfb-run`. Có `python3` với Pillow, `git`, `keytool`, `node`, và màn hình thật `DISPLAY=:0`.
- `adb devices` không có máy nào. **Mọi kiểm tra trên máy thật là việc thủ công của người dùng** (mục 4).
- MCP `comfyui` và `godot-ai` cấu hình toàn cục trong `~/.claude.json`, phiên chính gọi được cả hai. `COMFYUI_MCP_OUTPUT_ROOT=/home/tungcv2/Projects/Godot/Projects`, project nằm trong thư mục này. Chưa kiểm chứng sub-agent có gọi được không (Phase 7 có phương án dự phòng).

### 1.2 Quyết định đã chốt

- Godot 4.7.2, GDScript, renderer `gl_compatibility`, chỉ Android, portrait. iOS làm sau nên mọi thứ Android nằm sau autoload `Platform`.
- Quảng cáo: AppLovin MAX. IAP: Godot Google Play Billing plugin. Firebase Analytics, Remote Config, Crashlytics, Adjust, In-App Review, thông báo, Play Games Saved Games: một plugin Kotlin v2 tự viết.
- Horus ký AAB, đưa lên Play, cấp `appId`, đăng ký SKU, và **sẽ gửi cấu hình MAX, Firebase, Adjust sau**. Vì thế bản demo dùng hoàn toàn bản giả lập, và mọi code Android phải chạy được khi thiếu cấu hình.
- Không banner. Không nhiệm vụ ngày. Không quà quay lại. Không timer trong level.
- Hai preset export: `Android Demo` (custom feature `demo`, dừng ở L20) và `Android Release`.

### 1.3 Quy ước code

- Biến và hàm `snake_case`, có type hint, tab thụt đầu dòng, script đặt theo `snake_case.gd`. Comment `##` ngắn, chỉ khi không tự hiển nhiên.
- **Không dùng `class_name`.** Tham chiếu qua `const Foo := preload("res://src/.../foo.gd")`. Lý do: `class_name` cần `--import` ghi vào `.godot/`, sẽ race khi chạy song song.
- Sub-agent **không chạy `--import`** trừ khi task nói rõ. Orchestrator chạy ở cổng Phase.
- Sub-agent trong nhóm song song **không gọi tool MCP `godot-ai`**. Quy tắc dùng MCP ở mục 1.12.
- Module trong `src/core` và `src/meta` là logic thuần: `extends RefCounted`, không `Node`, không gọi `Platform`, không đọc giờ hệ thống, không dùng `randf()` toàn cục. Thời gian truyền vào qua tham số `now: int` (unix giây) hoặc `day: int`.
- Mọi con số nằm trong `src/config.gd`. Không viết số kinh tế hay quảng cáo trong code khác.
- Mọi chữ hiển thị qua `tr("KEY")`, khoá trong `i18n/strings.csv`.
- Gold trong code và save tên `coins`; analytics và UI gọi `gold`.
- Sự kiện analytics và tham số: chữ thường, `snake_case`, giá trị phẳng.
- Sub-agent **không chạy lệnh git ghi** (`add`, `commit`, `reset`, `checkout`, `stash`). Orchestrator giữ git.
- Ranh giới file: chỉ sửa file trong Allowed Files. File `.uid` và `.import` do Godot sinh cho file của mình không tính là vi phạm. Thiếu API ở module khác thì báo lại, không sửa hộ.

### 1.4 Lệnh dùng chung

```bash
tools/godot.sh --headless --path . --quit                                  # nạp autoload và main scene, chạy 1 khung
tools/godot.sh --headless --path . -s res://tests/run_all.gd               # toàn bộ test
tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_board # chỉ tests/test_board*.gd
tools/godot.sh --headless --path . --import                                # chỉ Orchestrator hoặc task được phép, khi editor đóng (mục 1.12)
```

`run_all.gd` tự tìm `tests/test_*.gd` nên thêm test không phải sửa file dùng chung. Thoát 0 là đạt. `--quit` **không** parse toàn project: script không nối tới main scene hay autoload có lỗi cú pháp vẫn thoát 0, nên module chỉ được kiểm qua test của nó. `-s` có nạp autoload, gọi được `Platform`, `Game` theo tên.

Dạng file test:

```gdscript
extends RefCounted
const T := preload("res://tests/t.gd")

func test_ten_ca(t: T) -> void:
	t.eq(1 + 1, 2, "cộng")
```

`T` có `eq`, `ok`, `near`, `fail`. Hàm tên `test_*` được chạy tuần tự, có thể `await`. Test dùng file phải ghi trong `user://test_<tên_test>/` để các tiến trình song song không đụng nhau.

### 1.5 Cấu trúc thư mục

```
project.godot  export_presets.cfg  CLAUDE.md  design.md  icon.svg
.gitignore  .gitattributes  .editorconfig
src/config.gd
src/core/      level_data.gd  board_state.gd  solver.gd  level_generator.gd  silhouette.gd
src/meta/      save_schema.gd  save_store.gd  clock.gd  wallet.gd  lives.gd  unlocks.gd
               rescue_flow.gd  daily_calendar.gd  cosmetics.gd  shop_videos.gd
               ad_pacing.gd  offers.gd  notif_plan.gd
src/platform/  platform.gd (autoload Platform)  mock_*.gd  android_*.gd
src/game/      game.gd (autoload Game)  sfx.gd (autoload Sfx)
src/ui/        theme_kit.gd  ...script màn hình...
scenes/        main.tscn  board_view.tscn  ...
data/levels/   level_0001.json ...
i18n/strings.csv
assets/        hình, âm thanh dùng trong game
art/           bản gốc và manifest.json, có .gdignore
android/plugins/tbo_platform/   plugin Kotlin (Phase 10)
addons/        godot_ai/ (đã cài, công cụ editor, có trong git, không vào bản export); plugin Godot (Phase 10)
tests/  tools/  reference/horus/  plans/
```

`art/`, `tools/`, `reference/`, `plans/` có `.gdignore`. Thư mục `android/` cũng có `.gdignore`. Preset loại `tests/*` và `addons/godot_ai/*` khỏi bản export.

### 1.6 Dữ liệu level

`data/levels/level_NNNN.json`. Gốc toạ độ ở góc trên trái, `x` sang phải, `y` xuống dưới.

```json
{
  "id": 21, "w": 14, "h": 19, "hard": false,
  "min_taps": 24, "moves": 26, "seed": 0,
  "stones": [[3, 4]],
  "pulse_sides": [{"side": "up", "open": false}],
  "blocks": [
    {"id": "b1", "color": "yellow", "cells": [[0,0],[0,1]],
     "ice": 0, "chained_by": "", "inner_color": "", "fog": false}
  ]
}
```

- Màu và hướng: `yellow` lên `(0,-1)`, `green` trái `(-1,0)`, `blue` phải `(1,0)`, `purple` xuống `(0,1)`. Mã màu (đo từ concept, xem `design.md` mục 8): `#FDE437`, `#8DD142`, `#2EA4FF`, `#8D45E0`.
- Cạnh ứng với màu: `up`, `left`, `right`, `down`.
- `ice`: 1 nghĩa là phải chạm 1 lần để nứt rồi mới đi được. `chained_by`: id khối chìa. `inner_color`: lớp trong. `fog`: chỉ làm mờ màu.
- `moves = min_taps + dư`. Dư theo `design.md` mục 3, tính trên số khối.

### 1.7 Interface `BoardState` (`src/core/board_state.gd`)

`BoardState` là tên hằng preload, không phải `class_name`. Trong chính file này khai báo `const BoardState := preload("res://src/core/board_state.gd")`; cách tự tham chiếu này chạy được trên 4.7.2.

```gdscript
func _init(level: Dictionary) -> void
func clone() -> BoardState
func tap(block_id: String) -> Dictionary
# {kind: "exit"|"peel"|"crack"|"blocked"|"chained"|"gate_closed"|"rejected",
#  id, distance: int, blocker: String, moves_left: int, won: bool, revealed: Array[String]}
func can_exit(block_id: String) -> bool     # tính cả xích, băng, cổng nhịp
func hint() -> String                       # "" nếu không có khối đi được ngay
func smash(block_id: String) -> bool        # không tốn MOVES; đá không phải khối nên không chọn được
func add_moves(n: int) -> void
func remaining_count() -> int
func moves_left() -> int
func is_won() -> bool
func is_out_of_moves() -> bool              # moves_left == 0 và chưa thắng
func block_view(block_id: String) -> Dictionary  # màu hiện tại, ô, ice, chained, is_fog_hidden
func block_ids() -> Array[String]
func gate_open(side: String) -> bool
```

Mọi `tap` hợp lệ giảm 1 MOVES, kể cả `crack`, `chained`, `blocked`, `gate_closed`. Sau mọi `tap` hợp lệ, các cạnh trong `pulse_sides` đổi trạng thái. `peel` là thoát lớp ngoài: khối ở nguyên, đổi sang `inner_color`. Khi `moves_left == 0` hoặc đã thắng, `tap` trả `rejected`.

### 1.8 Trạng thái lưu (`src/meta/save_schema.gd`)

`static func defaults() -> Dictionary`, gọi là `s` ở mọi module. Mỗi module meta chỉ đọc và ghi nhóm khoá của mình.

```gdscript
{
  "version": 1, "coins": Config.ECON.start_coins,
  "inv": {"hint": 0, "move": 0, "smash": 0},
  "gifted": {"hint": false, "move": false, "smash": false},
  "level": 1, "runs": 0, "play_ms": 0, "fail_streak": {"level": 0, "count": 0},
  "lives": {"count": 10, "next_at": 0},
  "daily": {"idx": 0, "claim_day": -1, "ad_day": -1},
  "shop": {"day": -1, "videos": 0},
  "cos": {"owned": ["avatar_00", "frame_00"], "avatar": "avatar_00", "frame": "frame_00"},
  "ads": {"last_inter_run": -99, "last_inter_at": 0, "last_rv_at": 0, "inter_today": 0, "inter_day": -1},
  "ad_pend": {}, "ad_credit": {},
  "offers": {"last_run": -999, "items": {}},
  "buys": [], "no_ads": false,
  "challenge": {"day": -1, "won": false},
  "notify": {"ignored": 0, "plan": [], "asked": false, "hours": []},
  "settings": {"sfx": true, "music": true, "haptics": true, "notif": true, "lang": ""},
  "meta": {"install_at": 0, "sessions": 0, "first_session_done": false, "rated": false, "ftue": []}
}
```

Không thêm khoá gốc ngoài danh sách này nếu task không được phép. Task 1.2 sở hữu file.

### 1.9 Interface `Platform` (autoload, `src/platform/platform.gd`)

Chọn backend lúc khởi động: `Engine.has_singleton("TboPlatform")` thì dùng Android, còn lại dùng mock. Mọi hàm async là coroutine, gọi bằng `await`.

```gdscript
signal paused; signal resumed
var ads; var iap; var an; var rc; var save; var notif
func haptic(ms: int) -> void            # Input.vibrate_handheld ở mọi backend, không qua plugin
func review() -> void
func open_privacy() -> void
func open_debugger() -> void            # mediation debugger của MAX; mock không làm gì

# ads
func ready_rewarded() -> bool
func ready_inter() -> bool
func load_ads() -> void
func rewarded(placement: String) -> Dictionary  # {ok: bool, reason: ""|"closed"|"not_ready"|"error"}
func inter(placement: String) -> Dictionary     # {shown: bool}
var has_privacy: bool
# iap
func price(sku: String) -> String
func buy(sku: String) -> Dictionary    # {status: ok|pending|cancel|owned|invalid|error, sku, token, order_id}
func pending() -> Array
func finish(p: Dictionary, consumable: bool) -> void
func restore() -> bool
# an
func log_event(name: String, params: Dictionary = {}) -> void
func earn(currency: String, amount: int, source: String) -> void
func spend(currency: String, amount: int, sink: String) -> void
func user(props: Dictionary) -> void
# rc
var values: Dictionary  # String -> String
func fetch() -> void
# save
func mirror(json: String) -> void
func backup() -> String
func flush() -> void
func sync_cloud() -> void
# notif
func ask() -> bool
func enabled() -> bool
func schedule(items: Array) -> void    # [{at: int, kind: String, title: String, body: String}]
func cancel_all() -> void
```

Mock: `simulate(result)` trên `ads` và `iap` để test. Khi có `DisplayServer` thật và không gọi `simulate`, mock hiện overlay "Quảng cáo giả lập: Xem hết / Đóng" và "Mua giả lập: Mua / Huỷ" để người duyệt demo đi được hết luồng. Headless thì trả ngay kết quả `ok`.

### 1.10 Interface `Game` (autoload, `src/game/game.gd`)

UI chỉ gọi `Game` và `Sfx`, không gọi thẳng `Platform` hay module meta để ghi trạng thái.

```gdscript
signal coins_changed(value: int); signal inv_changed; signal lives_changed; signal cos_changed
signal offer_ready(id: String)
var s: Dictionary
func boot() -> void                 # thứ tự: backup, cloud, Remote Config, ngôn ngữ, đơn treo, quảng cáo mất
func now() -> int
func today() -> int
# level
func current_level_data() -> Dictionary
func start_attempt() -> Dictionary  # trả BoardState mới và RescueFlow mới: {board, rescue}
func on_level_won(attempt: Dictionary) -> Dictionary  # {coins, x2_available, x2_free, rate_prompt}
func on_level_lost(attempt: Dictionary) -> void
func restart_cost_life(attempt: Dictionary) -> bool
func leave_win_card(x2_offered: bool, x2_taken: bool) -> void  # chạy luật interstitial
# ví
func spend_coins(n: int, sink: String) -> bool
func use_booster(kind: String) -> bool
func buy_booster(kind: String) -> bool
# quảng cáo: tự log rv_offer/rv_start/rv_done, lưu trước khi hiện, dừng nhạc
func watch(placement: String) -> bool
# rescue, quà, cosmetic, shop, offer: bọc module meta, log analytics, lưu
func rescue_accept(attempt: Dictionary, method: String) -> bool
func rescue_skip(attempt: Dictionary) -> void
func daily_view() -> Dictionary
func daily_claim() -> Dictionary
func daily_claim_next() -> Dictionary
func cos_buy(id: String) -> bool
func cos_unlock_video(id: String) -> bool
func cos_equip(id: String) -> bool
func shop_watch_video() -> bool
func shop_catalog() -> Array        # gói gold theo giá sale hôm nay
func buy_sku(sku: String) -> Dictionary
func restore_purchases() -> bool
func lives_view() -> Dictionary
func refill_gold() -> bool
func refill_video() -> bool
func challenge_view() -> Dictionary
func start_challenge() -> Dictionary
func set_setting(key: String, value: Variant) -> void
```

### 1.11 Màn hình

`scenes/main.tscn` (`src/ui/main.gd`) giữ một màn hiện tại và một lớp popup:

```gdscript
func go(screen: String, args: Dictionary = {}) -> void  # "home", "level", "no_lives", "profile", "shop", "challenge"
func open_popup(scene_path: String, args: Dictionary = {}) -> Node
```

Mọi màn và popup là scene có script `func setup(args: Dictionary) -> void` và signal `closed(result: Variant)`. Nút Back Android đóng popup trên cùng. Đường dẫn scene: `scenes/<tên>.tscn`, script `src/ui/<tên>.gd`. Kích thước gốc 720×1280, stretch `canvas_items`, aspect `expand`, nút tối thiểu 96×96 ở độ phân giải gốc (tương đương khoảng 48dp).

### 1.12 MCP `godot-ai`

Addon `addons/godot_ai` nối editor đang mở với MCP `godot-ai`. MCP chỉ bổ sung cho việc kiểm tra bằng mắt và chạy thử: mọi **Verification** vẫn là lệnh headless ở mục 1.4, chạy được khi không có editor. MCP không kết nối được thì ghi vào báo cáo rồi đi tiếp.

**Ai được dùng:** Orchestrator và các task tuần tự trong bảng mục 2. Editor chỉ có một scene đang mở và một phiên chạy game, nên sub-agent trong nhóm song song viết `.gd`, `.tscn` bằng công cụ file thường. Không sửa bằng file một scene đang mở trong editor.

| Việc | Tool |
| --- | --- |
| Kiểm kết nối | `session_manage(op="list")`, `editor_state` |
| Quét file mới và import khi editor mở | `filesystem_manage(op="scan")` |
| Chạy, dừng game | `project_run(mode="main")` hoặc `project_run(mode="custom", scene="res://scenes/x.tscn")`; `project_manage(op="stop")` |
| Đọc lỗi | `logs_read(source="game")`, `logs_read(source="editor")`. Log game sạch nhưng có `editor_errors_hint` nghĩa là đã mất script, không phải chạy tốt |
| Chụp màn game | `editor_screenshot(source="game", max_resolution=0)`. Có `stale_frame: true` thì cửa sổ game đang bị che, đưa lên trước rồi chụp lại |
| Đọc UI, bấm thử | `game_manage(op="get_ui_elements")`, `game_manage(op="input_mouse")` |
| Dựng trạng thái để kiểm | `editor_manage(op="game_eval")`, ví dụ `TranslationServer.set_locale("vi")`, `get_window().size = Vector2i(360, 640)`. Không dùng trong Verification |

**Quy tắc:**

1. **Không dùng `test_run`, `test_manage`.** Runner này chỉ nhận `McpTestSuite` và báo mọi file `tests/test_*.gd` của ta là `not a McpTestSuite subclass`. Test của dự án chạy bằng `run_all.gd`.
2. **Editor đang mở thì không chạy `--import`**, vì hai tiến trình editor sẽ cùng ghi `.godot/`. Dùng `filesystem_manage(op="scan")`. `--quit` và `-s` chạy song song với editor được.
3. **Task sửa `project.godot`, `export_presets.cfg` hoặc editor settings chạy khi editor đóng**, gồm 0.2, 0.3, 7.3, 10.3, 10.4, vì editor giữ bản trong RAM và có thể ghi đè. MCP cũng từ chối ghi `editor_plugins/*`. Trước các task này Orchestrator kiểm `editor_state`: `current_scene` rỗng thì đóng bằng `editor_manage(op="quit")`; khác rỗng thì có thể người dùng đang làm việc, phải hỏi trước, không tự lưu. Xong task thì mở lại bằng `nohup tools/godot.sh --editor --path . >/dev/null 2>&1 &` và kiểm `session_manage(op="list")`. Không có session cũng không chặn việc.
4. **Giữ autoload `_mcp_game_helper` và plugin `godot_ai` trong `project.godot`.** Bản export không mang theo: plugin tự gỡ autoload lúc export, kể cả headless, còn preset loại file addon. Đã kiểm bằng `--export-pack` trên bản sao project, gói không có autoload và file addon, vẫn có `data/levels/*.json` và `.translation`.
5. Headless không đụng MCP: plugin tự tắt và in `MCP | plugin disabled in headless mode`. Khi chạy `-s` hoặc `--quit`, helper in một dòng `[godot_ai game_helper]`, không phải lỗi.

**Điểm dùng trong kế hoạch:** cổng Phase 6 và 9, Task 8.1.

---

## 2. Execution Phases & Parallel Matrix

Hai task chạy song song không bao giờ có chung file. Kết thúc mỗi Phase, Orchestrator chạy cổng kiểm tra rồi `git add -A`. **Không commit** (người dùng chưa yêu cầu); stage làm mốc để `git diff` chỉ hiện thay đổi mới.

**Cổng mặc định của mỗi Phase:**

```bash
tools/godot.sh --headless --path . --import   # editor đang mở: thay bằng MCP filesystem_manage(op="scan")
tools/godot.sh --headless --path . --quit
tools/godot.sh --headless --path . -s res://tests/run_all.gd
git status --short
```

| Phase | Mục tiêu | Chạy song song | Tuần tự |
| --- | --- | --- | --- |
| 0 | Nền dự án | | 0.1 → 0.2 → 0.3 |
| 1 | Config, schema | 1.1, 1.2 | |
| 2 | Logic thuần | 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8 | |
| 3 | Nền tảng, chữ, level demo | 3.1, 3.2, 3.3 | |
| 4 | Điều phối | 4.1, 4.2 | |
| 5 | UI từng màn | 5.1, 5.2, 5.3, 5.4, 5.5 | |
| 6 | Ráp màn level | | 6.1 → 6.2 |
| 7 | Hình, âm thanh | 7.1, 7.2 | sau đó 7.3 |
| 8 | **Mốc: bản demo** | | 8.1 → 8.2 |
| 9 | Nội dung phát hành | 9.1, 9.2, 9.5 | sau đó 9.3 → 9.4 |
| 10 | Android thật | 10.1, 10.2 | sau đó 10.3 → 10.4 |

Phase 9–10 làm tiếp sau mốc demo, ẩn sau preset `Android Release`, nên không đổi bản demo. Nếu người dùng duyệt demo và đổi luật, các phase này có thể phải sửa theo.

---

## 3. Sub-agent Work Packages

### Phase 0: Nền dự án

- [x] **Task 0.1: Repo và dọn file Horus**
  - **Allowed Files:** `.git/`, `.gitignore`, `.gitattributes`, `CLAUDE.md`, `reference/horus/*`, `reference/.gdignore`, `plans/.gdignore`, `tools/.gdignore`; di chuyển `AGENTS.md`, `CHANGELOG.md`, `GAME-GUIDE.md`, `HorusBuild.cmd`, `horus-build.mjs`, `horus-game.json`, `horus-logic.mjs`, `horus-sdk.d.ts`, `horus-sdk.js`, `horus-sdk.mjs`, `README.md`.
  - **Specs:** `git init -b main`. Task này được phép chạy `git mv` hoặc `mv`, không commit. Chỉ di chuyển, không sửa nội dung file Horus. **Thay** nội dung `.gitignore` hiện có (bỏ dòng `/android/`) bằng: `.godot/`, `build/`, `tools/bin/`, `*.apk`, `*.aab`, `*.keystore`, `android/plugins/**/build/`, `android/plugins/**/.gradle/`, `android/build/`, `android/config/platform_config.json`, `android/config/google-services.json`, `android_config.json`. `.gitattributes` và `.editorconfig` giữ nguyên. `addons/godot_ai/` đưa vào git, vì `project.godot` tham chiếu tới nó. `CLAUDE.md` ngắn: trỏ tới `design.md` và file plan này, nêu các lệnh mục 1.4, quy tắc MCP mục 1.12, nêu `reference/horus/` chỉ để tham khảo.
  - **Verification:** `git rev-parse --is-inside-work-tree && test -f reference/horus/horus-sdk.d.ts && test ! -f AGENTS.md && test -f design.md && test -f tools/sim.mjs && ! grep -q '^/android/' .gitignore`

- [x] **Task 0.2: Project Godot và test runner**
  - **Allowed Files:** `project.godot`, `icon.svg`, `tools/godot.sh`, `i18n/strings.csv`, `tests/run_all.gd`, `tests/t.gd`, `tests/test_smoke.gd`, `scenes/main.tscn`, `src/ui/main.gd`, `src/platform/platform.gd`, `src/game/game.gd`, `src/game/sfx.gd`.
  - **Specs:** Chạy khi editor đóng (mục 1.12). `tools/godot.sh` chạy Godot theo đường dẫn mục 1.1, truyền nguyên tham số, cho phép ghi đè bằng biến `GODOT`, có quyền thực thi. **Sửa** `project.godot` hiện có, không tạo mới: đổi `config/name` thành "Tap Block Out", `config/features` thành `("4.7", "GL Compatibility")`, `renderer/rendering_method` và `renderer/rendering_method.mobile` thành `gl_compatibility`; thêm 720×1280 portrait, handheld orientation portrait, autoload `Platform`, `Game`, `Sfx` theo thứ tự này sau `_mcp_game_helper`, main scene `scenes/main.tscn`, dịch `i18n/strings.en.translation` và `.vi.translation`, ETC2/ASTC bật. Giữ stretch như mục 1.11, autoload `_mcp_game_helper`, `editor_plugins/enabled`. `i18n/strings.csv` là stub một khoá (`keys,en,vi`) để import sinh ra hai file `.translation`; thiếu chúng thì mọi lệnh Godot in `ERROR: Failed loading resource`. Task 3.2 thay nội dung file này. Autoload là stub `extends Node`; `Platform` và `Game` không lỗi khi chưa có backend. Stub `Sfx` đã có sẵn các hàm rỗng `play`, `music`, `stop_music`, `pause_for_ad`, `resume_after_ad` để Task 4.1 gọi được khi Task 4.2 đang chạy song song. `main.gd` có `go` và `open_popup` như mục 1.11. `run_all.gd` như mục 1.4: lọc theo user arg, in tổng kết, `quit(0)` hoặc `quit(1)`, có timeout 120 giây mỗi file test, file test `load()` lỗi thì tính là không đạt.
  - **Verification:** `tools/godot.sh --headless --path . --import; ! tools/godot.sh --headless --path . --quit 2>&1 | grep -E "^ERROR|SCRIPT ERROR" && tools/godot.sh --headless --path . --quit && tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_smoke && grep -q '_mcp_game_helper' project.godot && grep -q 'rendering_method.mobile="gl_compatibility"' project.godot`

- [x] **Task 0.3: Môi trường xuất Android**
  - **Allowed Files:** `export_presets.cfg`, `tools/export_apk.sh`; ngoài repo: `~/.local/share/godot/export_templates/4.7.2.stable/`, `~/.local/share/godot/keystores/debug.keystore`, editor settings của Godot, JDK trong `~/.local/` nếu cần.
  - **Specs:** Chạy khi editor đóng (mục 1.12). Tải `https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz` (khoảng 1,3 GB), giải nén vào đúng thư mục templates. Đặt `export/android/java_sdk_path` thành `/usr/lib/jvm/java-21-openjdk-amd64`. Tạo debug keystore còn thiếu bằng `keytool -genkeypair` với alias `androiddebugkey`, mật khẩu `android`, RSA 2048, hạn 9999 ngày. Tạo preset `Android Demo` (custom feature `demo`, `use_gradle_build=false`, package tạm `com.tungcv2.tapblockout`, arm64-v8a và armeabi-v7a, portrait, quyền `permissions/vibrate=true` để rung chạy được, `exclude_filter="tests/*, addons/godot_ai/*"`) và `Android Release` (giống vậy nhưng không có feature `demo`). `tools/export_apk.sh <preset> <đường_dẫn>` tạo thư mục và export debug. Tài liệu Godot khuyến nghị JDK 17 còn máy có 21: thử trước, lỗi thì tải Temurin 17 vào `~/.local/jdk-17` không cần sudo và đặt `export/android/java_sdk_path`.
  - **Verification:** `test -f ~/.local/share/godot/keystores/debug.keystore && tools/export_apk.sh "Android Demo" build/stub.apk && ~/Android/Sdk/build-tools/37.0.0/aapt2 dump badging build/stub.apk | head -3 && ! python3 -m zipfile -l build/stub.apk | grep -q 'addons/godot_ai/'`

**Cổng Phase 0:** cổng mặc định, và `build/stub.apk` tồn tại. Orchestrator đóng editor trước Task 0.2, mở lại sau Task 0.3 (mục 1.12), rồi kiểm `editor_state` có session và tên project mới.

### Phase 1: Config và schema

- [x] **Task 1.1: Config**
  - **Allowed Files:** `src/config.gd`, `tests/test_config.gd`.
  - **Specs:** Đọc `design.md` mục 3–7. `extends RefCounted`, các `static var` dạng Dictionary để Remote Config ghi đè được: `ECON` (start_coins, win_coins, booster_price hint/move/smash, refill_coins, refill_lives, shop_video_coins, shop_video_max, rescue_prices=[1900,2200,2500,2800], rescue_moves=3, rescue_video_max=4, challenge_coins=100), `LIVES` (max, regen_sec, from_level=10), `ADS` (inter_from_run=4, inter_every=2, inter_cooldown=120, session_warmup=90, rewarded_grace=45, first_session_block_until_level=10), `UNLOCK` (mục "Mở khoá": daily_gift=4, hint=5, shop=5, move=12, smash=17, lives=10, starter=10, review=10, challenge=50, stone=14, ice=30, chain=40, layer=55, fog=70, pulse=90), `DAILY` (28 ô đúng bảng trong `design.md`, mỗi ô `{coins:int, items:{...}}`), `COSMETICS` (avatar_01–12, frame_01–12, xoay giá 50/75/100), `SKUS` (mọi SKU và `_sale` trong mục 7, có usd, consumable, nội dung), `OFFERS`, `NOTIF`, `CONTENT` (`demo_max_level=20`, `release_pregen_level=100`, `loop_start_level=51`, `slack_easy=5`, `slack_easy_until=3`, `slack_hard=1`, `slack_min=2`, `slack_pct=10`, `think_clap_sec=8`, `build="v1"`, `support_email="support@horusvn.com"`, `ftue_steps=["open","first_tap","first_win","first_x2","first_booster","run_2","run_5","level_10"]`), `SALE_WEEKDAYS`. `static func is_demo() -> bool` trả `OS.has_feature("demo")`. `static func apply_remote(values: Dictionary) -> void` ghi đè theo khoá `<nhóm>_<khoá>`, giá trị là chuỗi, ép về đúng kiểu cũ, bỏ qua khoá lạ và giá trị hỏng.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_config` (test tổng quà 28 ô phải đúng 6.650 gold, 5 hint, 5 move, 4 smash; test `apply_remote`).

- [x] **Task 1.2: Save schema và kho lưu**
  - **Allowed Files:** `src/meta/save_schema.gd`, `src/meta/save_store.gd`, `src/meta/clock.gd`, `tests/test_save.gd`.
  - **Specs:** Schema đúng mục 1.8; `merge_defaults(s)` thêm khoá thiếu, không xoá khoá cũ, có `migrate`. `save_store.gd`: `_init(path: String, mirror: Callable)`; `load_state() -> Dictionary` (file hỏng thì thử `.bak`, rồi `backup_json` truyền vào, rồi mặc định); `queue(s)` gộp ghi, `flush()`, `save_now(s)` ghi file tạm rồi đổi tên, giữ `.bak`, gọi `mirror`. `further(a, b)`: bản `runs`, `play_ms` cao hơn. `merge_purchases(into, from)`: gộp `buys` theo token, cấp lại hàng thiếu qua Callable, giữ `no_ads` nếu một bên có. `clock.gd`: `day_number(now, tz_offset_sec) -> int` tính theo giờ máy, `weekday(now, tz_offset_sec)`, `local_tz_offset() -> int` là hàm duy nhất đọc hệ thống.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_save` (ghi đọc, file hỏng, mất file chính, gộp đơn không trùng token).

### Phase 2: Logic thuần

Các module chỉ phụ thuộc `src/config.gd` và `save_schema.gd`. Test tự tạo `s` bằng `SaveSchema.defaults()`.

- [x] **Task 2.1: Bàn cờ và solver**
  - **Allowed Files:** `src/core/level_data.gd`, `src/core/board_state.gd`, `src/core/solver.gd`, `tests/test_board.gd`, `tests/test_solver.gd`, `tests/fixtures/*.json`.
  - **Specs:** Làm đúng mục 1.6–1.7, gồm cả 6 cơ chế để Phase 9 không phải viết lại. Khối trượt cứng theo hướng màu tới khi rời hẳn bàn; bị chặn thì `distance` là số ô trượt được trước vật cản. Sương mù: hết ẩn khi có ô kề (4 hướng) trống. `level_data.gd`: `validate(d) -> Array[String]` kiểm khung, ô trùng, ô ngoài bàn, khoá bắt buộc, `chained_by` tồn tại, không có chu trình xích. `solver.gd`: `solve(level) -> {ok, min_taps, order, wasted}`. Vì cơ chế đơn điệu nên đi tham lam: ưu tiên khối thoát được, rồi nứt băng, rồi lớp ngoài; chỉ cạnh nhịp mới có chạm chờ. `immediate_exit_exists(level)`. `compute_moves(level)`: dư theo `design.md`, level thường là `max(slack_min, ceil(slack_pct% × số khối))`; `design.md` không nói cách làm tròn nên làm tròn lên cho hợp tiêu chí thư giãn. Test đối chiếu solver với BFS vét cạn trên ít nhất 200 bàn ngẫu nhiên nhỏ (RNG có seed) và kiểm luật không có thế bí: mọi trạng thái đạt được đều còn lời giải khi đủ MOVES.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_board && tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_solver`

- [x] **Task 2.2: Ví, mạng, mở khoá**
  - **Allowed Files:** `src/meta/wallet.gd`, `src/meta/lives.gd`, `src/meta/unlocks.gd`, `tests/test_wallet.gd`, `tests/test_lives.gd`, `tests/test_unlocks.gd`.
  - **Specs:** Hàm `static`. `wallet`: `earn(s,n)`, `spend(s,n)->bool`, `inv_count(s,k)`, `inv_add(s,k,n)`, `inv_use(s,k)->bool`. `lives`: `tick(s,now)`, `count(s,now)`, `lose(s,now,level)` (không làm gì khi `level < from_level`), `add(s,n,now)`, `seconds_to_next(s,now)`, `refill_coins(s,now)->bool`. Đầy thì không tích giờ. `unlocks`: `is_open(feature, level)->bool`; `rescue`, avatar, frame luôn mở. `pending_gift(s, level)->String` trả booster cần tặng ở L4/6/9, `mark_gifted`.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_wallet && tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_lives && tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_unlocks`

- [x] **Task 2.3: Luồng hết MOVES**
  - **Allowed Files:** `src/meta/rescue_flow.gd`, `tests/test_rescue.gd`.
  - **Specs:** Đọc `design.md` mục "Khi hết MOVES". Đối tượng theo từng lượt chơi. `offer(inv_move:int, coins:int, remaining:int, level:int) -> Dictionary` trả `{index, price, use_inventory, video, affordable, remaining, warn_life}` (`index` -1 khi hết đường cứu). `accept(method) -> {moves:3, price}` với `inventory|gold|video`. `skip()`: thua. `is_lost()`. Luật: tối đa `len(rescue_prices)` lần (mặc định 4), giá lần n theo `rescue_prices[n]`, video khi `index < rescue_video_max`, dùng kho vẫn tính một lần; hết lần thì `index=-1`. `warn_life` đúng khi `level >= from_level`. Module không trừ tiền.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_rescue` (mọi nhánh, gồm mua A rồi hết MOVES, bỏ qua A, 4 lần B, thiếu gold, video lần 3 bị tắt).

- [x] **Task 2.4: Quà 28 ngày**
  - **Allowed Files:** `src/meta/daily_calendar.gd`, `tests/test_daily.gd`.
  - **Specs:** `view(s, day, level) -> {open, cells (7 ô của tuần đang đi), week, idx, can_claim, can_ad_next, badge}`; `claim(s, day) -> reward hoặc {}`; `claim_next_ad(s, day) -> reward hoặc {}`. Xem video chỉ sau khi đã nhận ô hiện tại, 1 lần/ngày, tiến thêm một ô. Lỡ ngày không reset. Hết ô 28 về ô 1. `day` nhỏ hơn `claim_day` (giờ lùi) thì `can_claim=false` cho tới khi vượt mốc. Reward là `{coins, items}`. Module chỉ tiến lịch, không cộng hàng và không gọi `Wallet`; `Game` cộng hàng ở Task 4.1.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_daily`

- [x] **Task 2.5: Avatar, frame, video shop**
  - **Allowed Files:** `src/meta/cosmetics.gd`, `src/meta/shop_videos.gd`, `tests/test_cosmetics.gd`, `tests/test_shop_videos.gd`.
  - **Specs:** `cosmetics`: `catalog()`, `is_owned`, `buy(s,id)->bool`, `unlock(s,id)->bool`, `equip(s,id)->bool`; mặc định `*_00` miễn phí; `buy` trừ thẳng `s.coins`, không gọi `Wallet`. `shop_videos`: `remaining(s,day)`, `note_watch(s,day)->coins`, reset theo ngày, tối đa `shop_video_max`. Video cosmetic không tính vào giới hạn này.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_cosmetics && tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_shop_videos`

- [x] **Task 2.6: Nhịp interstitial**
  - **Allowed Files:** `src/meta/ad_pacing.gd`, `tests/test_ad_pacing.gd`.
  - **Specs:** `inter_due(s, ctx) -> bool` với `ctx {now, session_start, first_session, level, x2_offered, x2_taken, day}`. Luật trong `design.md` mục 6 (viết lại theo `monetize.interDue` trong `reference/horus/horus-sdk.d.ts` dòng 839). `note_inter(s, now, day)`, `note_rewarded(s, now)`, `inter_count_today(s, day)`. Có `no_ads` thì luôn sai.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_ad_pacing`

- [x] **Task 2.7: Offer và sale**
  - **Allowed Files:** `src/meta/offers.gd`, `tests/test_offers.gd`.
  - **Specs:** Đọc `design.md` mục 7. `is_sale(now, tz)` thứ Bảy và Chủ nhật; `catalog(now, tz)` trả gói đúng SKU thường hoặc `_sale`. `due(s, ctx) -> id`, với `ctx {now, day, level, runs, session_start, first_session, inter_today}` (không gọi `AdPacing`), cho `starter_pack` (qua L10 hoặc lượt 12, mở 48 giờ, một lần), `remove_ads` (sau interstitial thứ 3 trong ngày, 1 lần/ngày, 3 lần tổng), `rescue_pack` (thua 3 lần liền một level, mỗi 24 giờ, hiện trên màn thua), `level_pack` (mỗi 10 level, mở 72 giờ). Không trong 5 phút đầu phiên đầu, cách nhau ít nhất 3 lượt. `shown`, `bought`, `open_offers(s, now)`, `note_fail(s, level)`, `note_win(s, level)`.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_offers`

- [x] **Task 2.8: Lịch thông báo**
  - **Allowed Files:** `src/meta/notif_plan.gd`, `tests/test_notif.gd`.
  - **Specs:** Theo `reference/horus/GAME-GUIDE.md` mục 15. `plan(s, now, tz, candidates) -> Array[{at, kind}]`: tuần đầu tối đa 3 lần/ngày, đặt trước giờ hay mở game 15 phút; rồi 1 lần/ngày tới ngày 14; rồi ngày 16, 18, 21, 24, 27, 30; không trước 8:00 hay sau 22:00; bỏ qua 9 lần liền thì 1 lần/ngày. `candidates` chỉ có thứ đang chờ thật: `daily_gift`, `lives_full`, `offer_open`. `note_open(s, now, tz)` ghi giờ mở vào `s.notify.hours`. `note_return(s, now, opened_kind)`.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_notif`

**Cổng Phase 2:** cổng mặc định.

### Phase 3: Nền tảng, chữ, level demo

- [x] **Task 3.1: Platform và mock**
  - **Allowed Files:** `src/platform/platform.gd`, `src/platform/mock_ads.gd`, `src/platform/mock_iap.gd`, `src/platform/mock_an.gd`, `src/platform/mock_rc.gd`, `src/platform/mock_save.gd`, `src/platform/mock_notif.gd`, `tests/test_platform_mock.gd`.
  - **Specs:** Làm đúng mục 1.9. `an` mock giữ danh sách sự kiện để test đọc. Overlay giả lập chỉ dùng code UI đơn giản, không phụ thuộc `src/ui`. Bắt `NOTIFICATION_APPLICATION_PAUSED` và `RESUMED` thành signal. `platform.gd` nạp backend Android bằng `load()` có điều kiện để file chưa tồn tại không lỗi.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_platform_mock`

- [x] **Task 3.2: Chữ en và vi**
  - **Allowed Files:** `i18n/strings.csv`, `tests/test_i18n.gd`.
  - **Specs:** Thay stub của Task 0.2. Cột `keys,en,vi`. Khoá theo nhóm `home_`, `level_`, `rescue_`, `win_`, `lose_`, `no_lives_`, `shop_`, `daily_`, `profile_`, `settings_`, `offer_`, `ads_`, `tut_`, `mech_`, `notif_`, `booster_`. Viết đủ mọi chữ trong `design.md`: "Còn N khối", cảnh báo mất mạng, "Sắp có level mới", "Unlocked at Level 50", hướng dẫn L1 "Tap the block", thông báo. Tiếng Việt có dấu. Giọng nhẹ nhàng, không gây áp lực. Liệt kê các khoá ở đầu báo cáo để Phase 5 dùng; thiếu khoá thì task UI được phép báo lại.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_i18n` (mọi hàng đủ 2 cột, không trùng khoá, có các khoá bắt buộc). Orchestrator import ở cổng Phase.

- [x] **Task 3.3: 20 level demo**
  - **Allowed Files:** `data/levels/level_0001.json` … `level_0020.json`, `tools/validate_levels.gd`, `tests/test_levels_demo.gd`.
  - **Specs:** Bảng trong `design.md` mục 4: đúng màu, số khối, HARD ở L8, 12, 16, 20, polyomino thanh, L, T, S, U, bàn cố định 14×19 (`Config.BOARD_W`, `BOARD_H`), hình ở giữa bàn (đối xứng, vòng lồng nhau, hình vòm), không chép game gốc. Không dùng cơ chế mới. `moves` và `min_taps` do solver tính, không viết tay. `tools/validate_levels.gd` (chạy bằng `-s`) kiểm `validate`, solver, có khối thoát ngay, `moves` đúng công thức. Task này phụ thuộc đọc `src/core/*`, không sửa.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tools/validate_levels.gd && tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_levels_demo` (`tools/` có `.gdignore` chỉ chặn import; đã kiểm trên 4.7.2 là script trong đó vẫn chạy được bằng `-s`).

### Phase 4: Điều phối

- [x] **Task 4.1: Autoload Game**
  - **Allowed Files:** `src/game/game.gd`, `tests/test_game.gd`.
  - **Specs:** Làm đúng mục 1.10 trên nền các module Phase 1–3. Thứ tự `boot` theo `reference/horus/GAME-GUIDE.md` mục 4. Mọi rewarded: ghi `s.ad_pend`, `save_now`, dừng nhạc, hiện, chỉ thưởng khi `ok`, log `rv_offer`, `rv_start`, `rv_done`, `rv_cancel`, `rv_fail`; quảng cáo mất thì trao lại khi mở game. Mua hàng: cộng hàng, `save_now`, rồi `finish`; mỗi token một lần; `invalid` không thưởng. Log `boot` (`ms` từ lúc mở tới khi chơi được), `level_start`, `level_end`, `popup_a_show`, `popup_a_buy`, `popup_b_show`, `popup_b_use`, `daily_claim`, `cos_buy`, `offer_show`, `offer_buy`, `inter_show`, `shop_open`, `ad_reward_recovered` (trao lại quảng cáo mất), `ftue` (`step` theo `Config.CONTENT.ftue_steps`, mỗi bước một lần, ghi vào `s.meta.ftue`), và `earn`/`spend` mỗi lần đổi gold. Mọi sự kiện có tham số `build`. Restart từ L10 trừ mạng theo `design.md`. Hỗ trợ `Game.reset_for_test(path)`. Demo: sau L20 `current_level_data()` trả `{}`. Áp dụng `Config.apply_remote` lúc boot. Khi `Platform.paused`: dừng nhạc, `save_now`, lập lại lịch thông báo (`NotifPlan.plan` rồi `Platform.schedule`). Gọi `Platform.ask()` sau lượt thứ 2, một lần, ghi `s.notify.asked`. `set_setting("notif", false)` gọi `Platform.cancel_all()`. `challenge_view` và `start_challenge` tạm trả trạng thái khoá; Task 9.4 làm thật.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_game` (thắng cộng gold, thua L9 và L10, luồng A và B qua mock, x2, mua không giao hai lần, đóng video sớm không thưởng, quảng cáo mất).

- [x] **Task 4.2: Theme và Sfx**
  - **Allowed Files:** `src/ui/theme_kit.gd`, `src/game/sfx.gd`, `tests/test_sfx.gd`.
  - **Specs:** `theme_kit`: bảng màu mục 1.6, nền, cỡ chữ, `make_button(text, kind)`, `make_panel()`, popup vào ra bằng tween nhẹ, hình tạm vẽ bằng code khi chưa có asset. `icon(name) -> Texture2D` nạp `assets/ui/<name>.png`, thiếu thì trả placeholder, không lỗi. `Sfx`: `play(name)`, `music(name)`, `stop_music()`, `pause_for_ad()`, `resume_after_ad()`, đọc cài đặt qua tham số, thiếu file thì im lặng. Tự viết bus `SFX` và `Music` bằng code. Rung qua `Platform.haptic` nhẹ.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_sfx`

### Phase 5: UI từng màn

Mỗi màn có `setup(args)` và signal `closed`, chạy được khi `Game` dùng mock. Test tạo scene trong SceneTree headless, bấm nút qua hàm hoặc tín hiệu `pressed`, kiểm trạng thái.

- [x] **Task 5.1: BoardView**
  - **Allowed Files:** `scenes/board_view.tscn`, `src/ui/board_view.gd`, `src/ui/board_fx.gd`, `src/ui/pudding.gd`, `src/ui/pudding.gdshader`, `tests/test_ui_board.gd`.
  - **Specs:** `setup(board: BoardState)`, signal `block_tapped(id)`, `animation_done`, `apply_result(result: Dictionary)`. Vẽ nền trơn, cổng liền bốn cạnh theo màu, khối pudding 3D (thân bằng shader từ các trường khoảng cách trong `src/ui/pudding.gd`, phần phủ bằng code; concept theme trong `design.md` mục 8; cỡ ô là số nguyên, cố định `Config.BOARD_CELL`, chỉ co khi vùng chứa nhỏ hơn bàn chuẩn). Trượt ra 0,30 giây ease-out, hạt màu ở cạnh; bị chặn thì trượt tới vật cản, bật về, rung nhẹ, không màn đỏ. Vùng chạm đúng ô của khối. `highlight(id)` cho Gợi ý, `smash_anim(id)`. Cơ chế mới để Task 9.2.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_ui_board`

- [x] **Task 5.2: Home và Profile**
  - **Allowed Files:** `scenes/home.tscn`, `src/ui/home.gd`, `scenes/profile.tscn`, `src/ui/profile.gd`, `tests/test_ui_home.gd`, `tests/test_ui_profile.gd`.
  - **Specs:** Home: nút Chơi với số level, gold, mạng và đếm hồi, avatar và frame đang đeo (bấm mở Profile), icon quà có chấm đỏ, icon shop khoá tới L5, Settings, nút Daily Challenge khoá ghi "Unlocked at Level 50", chip offer đang mở. Demo xong L20 hiện "Sắp có level mới". Không tự mở popup quà. Profile: lưới 12 avatar, 12 frame và mặc định; chọn món đã có để đeo; món chưa có hiện giá và nút video.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_ui_home && tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_ui_profile`

- [x] **Task 5.3: Popup hết MOVES, thắng, thua, hết mạng**
  - **Allowed Files:** `scenes/popup_rescue.tscn`, `src/ui/popup_rescue.gd`, `scenes/win_card.tscn`, `src/ui/win_card.gd`, `scenes/lose_card.tscn`, `src/ui/lose_card.gd`, `scenes/no_lives.tscn`, `src/ui/no_lives.gd`, `tests/test_ui_rescue.gd`, `tests/test_ui_result.gd`.
  - **Specs:** `popup_rescue` nhận kết quả `RescueFlow.offer`, một popup duy nhất cho cả 4 lần. Hiện "Còn N khối", giá, nút Dùng khi có trong kho, nút video khi được, không đếm ngược; cảnh báo mất mạng nằm ở hộp xác nhận Bỏ cuộc do level dựng (Task 6.1), không ở popup. Thiếu gold: bấm mua trả `result="need_coins"` để level mở shop mini. Win card: +40, x2 (L1 miễn phí), tiếp tục. Lose card: chơi lại, về Home, `rescue_pack` nếu `Game` báo. No lives: đếm ngược, 900 gold, video, không có quảng cáo thì báo. Bổ sung ngày 2026-11-02 (theo `design.md` mục "Thẻ thắng và thẻ thua"): `Game.on_level_won` trả thêm `progress` và `unlocked` từ `Unlocks.feature_progress`; win card có thanh tiến trình tính năng (`FeatureProgress`, `FeatureLabel`, `FeaturePercent`); `Game.next_after_win(res, challenge)` chọn "home" hoặc "level"; `level.gd` chờ `CONTENT.win_delay_sec` trước thẻ thắng (bỏ qua khi headless); `level_end` thêm `blocks_left`, `rescues`, `replay`.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_ui_rescue && tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_ui_result`

- [x] **Task 5.4: Shop và offer**
  - **Allowed Files:** `scenes/shop.tscn`, `src/ui/shop.gd`, `scenes/shop_mini.tscn`, `src/ui/shop_mini.gd`, `scenes/popup_offer.tscn`, `src/ui/popup_offer.gd`, `tests/test_ui_shop.gd`.
  - **Specs:** Shop đầy đủ (mở từ L5): gói gold theo `Game.shop_catalog()`, nhãn sale cuối tuần, video 200 gold còn N/5, gói khác, Remove Ads, Restore. Shop mini: chỉ gói gold, mở được ở mọi level khi người chơi bấm mua, đóng thì trả về popup. Popup offer dùng chung cho 4 offer.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_ui_shop`

- [x] **Task 5.5: Popup quà và Settings**
  - **Allowed Files:** `scenes/popup_daily.tscn`, `src/ui/popup_daily.gd`, `scenes/settings.tscn`, `src/ui/settings.gd`, `tests/test_ui_daily.gd`, `tests/test_ui_settings.gd`.
  - **Specs:** Popup quà chỉ mở khi bấm, hiện đúng 7 ô của tuần đang đi, nút nhận, nút video nhận ô kế tiếp (không tự chạy). Settings: âm thanh, nhạc, rung, thông báo, ngôn ngữ, Privacy khi `has_privacy`, Restore, Contact support (mở `mailto:` tới `Config.CONTENT.support_email`), phiên bản. Chạm nhiều lần vào dòng phiên bản mở menu tester có nút mediation debugger (`Platform.open_debugger()`).
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_ui_daily && tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_ui_settings`

### Phase 6: Ráp màn level

- [x] **Task 6.1: Màn level và điều hướng**
  - **Allowed Files:** `scenes/level.tscn`, `src/ui/level.gd`, `src/ui/main.gd`, `scenes/main.tscn`, `tests/test_ui_level.gd`.
  - **Specs:** HUD: level, MOVES, HARD, nút restart có xác nhận từ L10, 3 nút booster theo mở khoá và tồn kho, hướng dẫn L1, tặng booster L4/6/9 kèm giới thiệu. Booster thiếu gold mời `booster_free` một lần mỗi lượt. Hết MOVES: chạy `RescueFlow`, hiện `popup_rescue`, `need_coins` mở `shop_mini` rồi quay lại popup. Bỏ cuộc: từ `from_level` hiện hộp xác nhận mất 1 mạng (huỷ thì quay lại popup, xác nhận thì `rescue_skip` rồi thẻ thua), dưới đó thua ngay. Thắng mở win card; rời win card gọi `Game.leave_win_card`. Thua mở lose card. Vỗ tay khi nghĩ từ `think_clap_sec`. Hết mạng chuyển `no_lives`. Hỏi đánh giá sau L18. `main.gd` gọi `Game.boot()`, nối đủ màn và nút Back.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_ui_level`

- [x] **Task 6.2: E2E headless toàn demo**
  - **Allowed Files:** `tests/test_e2e_demo.gd`, `tests/e2e_driver.gd`.
  - **Specs:** Driver mở `main.tscn`, dùng solver chọn nước và bấm qua `block_tapped`, chơi L1–20 với save trống, preset giả lập `demo`. Thêm kịch bản: chạm sai tới hết MOVES, A, B, thua; quà ngày qua 8 ngày giả lập; mua avatar; x2; interstitial đúng luật; đóng video sớm. Không log `ERROR` hay `SCRIPT ERROR`.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_e2e 2>&1 | tee /tmp/tbo_e2e.log; ! grep -E "SCRIPT ERROR|^ERROR" /tmp/tbo_e2e.log`

**Cổng Phase 6:** cổng mặc định, thêm chạy thử qua MCP (mục 1.12): `project_run(mode="main")`, chơi xong L1 bằng `game_manage(op="input_mouse")`, chụp `editor_screenshot(source="game")`, `logs_read(source="game")` và `logs_read(source="editor")` không có lỗi, rồi `project_manage(op="stop")`. Không có session MCP thì ghi vào báo cáo, không chặn.

### Phase 7: Hình và âm thanh

Bước đầu mỗi task: thử gọi MCP `comfyui`. **Không có MCP hoặc gọi lỗi thì không coi là blocker:** giữ placeholder, ghi phần thiếu vào file `MISSING` trong Allowed Files của task, báo lại, tiếp tục. `COMFYUI_MCP_OUTPUT_ROOT` là `/home/tungcv2/Projects/Godot/Projects`, chứa project này, nên MCP ghi thẳng vào `art/` theo đường dẫn tuyệt đối.

- [x] **Task 7.1: Hình**
  - **Allowed Files:** `art/images/*`, `art/manifest.images.json`, `art/MISSING.images.md`, `art/.gdignore`, `assets/ui/*.png`, `assets/bg/*.png`, `assets/avatars/*.png`, `assets/frames/*.png`, `assets/icon_app.png`, `tools/resize_images.py`.
  - **Specs:** Làm theo `design.md` mục "Tài nguyên" các file demo: bỏ `mech_*`. Quy tắc prompt, seed, manifest theo mục đó. Duyệt `ui_gold` trước rồi dùng làm tham chiếu. Thu nhỏ bằng Pillow. Không dùng tên hay ảnh game gốc. Không tự kiểm được bằng mắt thì mở file ảnh bằng công cụ đọc ảnh.
  - **Verification:** `python3 -c "import json;m=json.load(open('art/manifest.images.json'));print(len(m))" && du -sh assets` (hoặc `art/MISSING.images.md` tồn tại và liệt kê phần thiếu).

- [x] **Task 7.2: Âm thanh**
  - **Allowed Files:** `art/audio/*`, `art/manifest.audio.json`, `art/MISSING.audio.md`, `assets/sfx/*.wav`, `assets/music/*.ogg`, `tools/bin/*`, `tools/process_audio.sh`.
  - **Specs:** Các file demo trong `design.md`, bỏ 6 `sfx` cơ chế. Xuất `flac` làm gốc. Máy không có `ffmpeg`: tải bản static vào `tools/bin/`. Hiệu ứng ra WAV, nhạc nền ra Ogg, cắt khoảng lặng, cân âm lượng.
  - **Verification:** `python3 -c "import json;m=json.load(open('art/manifest.audio.json'));print(len(m))" && ls assets/sfx assets/music` (hoặc `art/MISSING.audio.md`).

- [x] **Task 7.3: Nối tài nguyên**
  - **Allowed Files:** `art/manifest.json`, `art/MISSING.md`, `src/ui/theme_kit.gd`, `src/game/sfx.gd`, `export_presets.cfg`, file `.import` trong `assets/`.
  - **Specs:** Chạy khi editor đóng (mục 1.12), được phép chạy `--import`. Gộp 2 manifest và 2 file MISSING. Đặt loop cho nhạc nền trong file `.import`. Icon app vào preset. Tổng `assets/` tối đa 10 MB.
  - **Verification:** `tools/godot.sh --headless --path . --import; tools/godot.sh --headless --path . -s res://tests/run_all.gd && du -sm assets | awk '{exit !($1<=10)}'`

### Phase 8: Mốc bản demo

- [x] **Task 8.1: Kiểm tra bằng hình**
  - **Allowed Files:** `tests/shot.gd`, `tests/shots/.gdignore`, các bản sửa UI nhỏ trong `src/ui/*` chỉ khi ảnh cho thấy lỗi tràn chữ hoặc vỡ layout.
  - **Specs:** Chụp bằng cửa sổ thật, không `--headless` (renderer dummy cho ảnh trống): Home, level L8, popup hết MOVES (lần 1 và lần cuối), win, lose, shop, quà, profile, settings, ở 720×1280 và 360×640, `en` và `vi`. Cách chính là `tests/shot.gd` chạy trên `DISPLAY=:0` (`--resolution 360x640`, máy không có `xvfb-run`), vì lặp lại được và không cần editor. Màn khó dựng trạng thái bằng script thì chụp qua MCP (mục 1.12): `project_run`, `editor_manage(op="game_eval")`, `editor_screenshot(source="game")`; dùng `game_manage(op="get_ui_elements")` đối chiếu rect để tìm chỗ tràn. Không chụp được thì ghi rõ phần chưa kiểm vào báo cáo. Đọc từng ảnh, sửa lỗi hiển nhiên.
  - **Verification:** `ls tests/shots/*.png | wc -l` và test toàn bộ đạt.

- [x] **Task 8.2: APK demo và ghi chú duyệt**
  - **Allowed Files:** `docs/DEMO_NOTES.md`, `export_presets.cfg`.
  - **Specs:** Build `build/TapBlockOut-demo.apk` từ preset `Android Demo`. Viết `docs/DEMO_NOTES.md`: cài bằng `~/Android/Sdk/platform-tools/adb install`, danh sách cần duyệt trên máy thật (mục 4), bảng phần còn placeholder.
  - **Verification:** `tools/export_apk.sh "Android Demo" build/TapBlockOut-demo.apk && ~/Android/Sdk/build-tools/37.0.0/aapt2 dump badging build/TapBlockOut-demo.apk | head -3 && du -h build/TapBlockOut-demo.apk`

**Cổng Phase 8:** cổng mặc định, thêm `node tools/sim.mjs`. Báo một dòng cho người dùng rằng APK demo đã có, rồi đi tiếp.

### Phase 9: Nội dung phát hành

- [x] **Task 9.1: Bộ sinh level**
  - **Allowed Files:** `src/core/level_generator.gd`, `src/core/silhouette.gd`, `tests/test_generator.gd`, `tests/test_silhouette.gd`, `tools/gen_levels.gd`.
  - **Specs:** `generate(id: int, seed: int) -> Dictionary` thuần, theo `RandomNumberGenerator` có seed: chọn hình trong `src/core/silhouette.gd`, lát hình thành khối (tự do hoặc đối xứng), dịch vào giữa bàn cố định 14×19, bật cơ chế theo `Config.UNLOCK`, HARD mỗi 4 level, số khối tăng tới trần 30, qua `validate` và `solver`, sinh lại với seed kế tiếp nếu không đạt. Dùng cho Daily Challenge; level sau L300 không sinh mà lặp lại nội dung từ `CONTENT.loop_start_level` (`src/core/level_loop.gd`, `Game.content_level`). Cùng `id` và `seed` phải ra cùng level.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_generator` (500 level hợp lệ, xác định, mỗi level dưới 200 ms trên máy dev).

- [x] **Task 9.2: Hiển thị cơ chế**
  - **Allowed Files:** `src/ui/board_view.gd`, `src/ui/board_fx.gd`, `scenes/board_view.tscn`, `tests/test_ui_mech.gd`.
  - **Specs:** Vẽ đá, băng và nứt, xích và chìa, hai lớp và bóc lớp, sương mù, cổng nhịp đóng mở. Âm thanh gọi `Sfx` theo bảng `design.md`, thiếu file thì im. Dùng `assets/ui/mech_*` nếu có, nếu không vẽ bằng code.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_ui_mech`

- [x] **Task 9.3: Sinh L21–300 và level dạy**
  - **Allowed Files:** `data/levels/level_0021.json` … `level_0300.json`, `data/levels/index.json`, `tests/test_levels_all.gd`, `tools/gen_levels.gd`.
  - **Specs:** Chạy `tools/gen_levels.gd`. Các level 21, 31, 46, 61, 81, 101 làm tay, chỉ một cơ chế mới, dễ. L1–20 giữ layout tay, trừ các level kín khung (`design.md` mục 4). Ghi `index.json` nếu cần tăng tốc tải.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_levels_all` (300 level qua validator và solver).

- [x] **Task 9.4: Daily Challenge, tuỳ chọn sau L300, cơ chế trong game**
  - **Allowed Files:** `scenes/challenge.tscn`, `src/ui/challenge.gd`, `src/game/game.gd`, `src/ui/home.gd`, `src/ui/level.gd`, `tests/test_challenge.gd`, `tests/test_level_after_300.gd`.
  - **Specs:** Daily Challenge từ L50 theo `design.md`: seed theo ngày, +100 gold lần thắng đầu trong ngày, x2 bằng video, thua mất mạng. Sau L300 gọi generator, solver kiểm, có màn chờ ngắn. Preset demo vẫn dừng ở L20 và khoá nút. Level dạy cơ chế có hướng dẫn. Mở khoá các nút theo `Unlocks`.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_challenge && tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_level_after_300 && tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_e2e`

- [x] **Task 9.5: Tài nguyên cơ chế**
  - **Allowed Files:** `art/images/mech_*`, `art/audio/sfx_*`, `art/manifest.mech.json`, `art/MISSING.mech.md`, `assets/ui/mech_*.png`, `assets/sfx/sfx_stone.wav`, `assets/sfx/sfx_ice.wav`, `assets/sfx/sfx_chain.wav`, `assets/sfx/sfx_layer.wav`, `assets/sfx/sfx_fog.wav`, `assets/sfx/sfx_gate.wav`.
  - **Specs:** Phần Task 7.1 và 7.2 đã bỏ: `mech_stone`, `mech_ice`, `mech_chain`, `mech_key`, `mech_fog` và 6 `sfx` cơ chế theo `design.md` mục "Tài nguyên". Cùng quy tắc prompt, seed, xử lý và phương án dự phòng như Phase 7, dùng lại `tools/resize_images.py`, `tools/process_audio.sh`. Không sửa `art/manifest.json`; Orchestrator gộp `art/manifest.mech.json` vào đó ở cổng Phase. Tổng `assets/` vẫn tối đa 10 MB.
  - **Verification:** `python3 -c "import json;m=json.load(open('art/manifest.mech.json'));print(len(m))" && du -sm assets | awk '{exit !($1<=10)}'` (hoặc `art/MISSING.mech.md` liệt kê phần thiếu).

**Cổng Phase 9:** cổng mặc định, gộp manifest của Task 9.5, thêm xem cơ chế qua MCP (mục 1.12): chạy level dạy 21, 31, 46, 61, 81, 101 và chụp từng màn. Không có session MCP thì ghi vào báo cáo, không chặn.

### Phase 10: Android thật

Chưa có cấu hình của Horus: code phải biên dịch được, chạy không crash khi thiếu cấu hình (`ready_*` trả `false`, không log lỗi nghiêm trọng). Test thật để ở mục 4. Đây **không phải** blocker.

- [x] **Task 10.1: Plugin Kotlin**
  - **Allowed Files:** `android/plugins/tbo_platform/**`, `android/.gdignore`, `android/config/platform_config.example.json`, `addons/tbo_platform/**`, `tools/build_plugin.sh`.
  - **Specs:** Theo [tài liệu plugin v2](https://docs.godotengine.org/en/stable/tutorials/platform/android/android_plugin.html), singleton `TboPlatform`, thư viện `org.godotengine:godot:4.7.2.stable` (kiểm phiên bản thật trên Maven Central), Gradle wrapper. Gói: AppLovin MAX (rewarded, interstitial, consent, mediation debugger), Firebase Analytics, Remote Config, Crashlytics, Adjust, In-App Review, thông báo local bằng AlarmManager và quyền POST_NOTIFICATIONS, Play Games Saved Games. Rung không nằm trong plugin (mục 1.9). Đọc khoá từ `res://android_config.json` hoặc manifest lúc chạy; file này do `tools/export_release.sh` chép từ `android/config/platform_config.json` lúc build (Task 10.4), thiếu file thì coi như thiếu cấu hình. Signal cho mọi kết quả. Export plugin của Godot trong `addons/tbo_platform/` để đưa AAR và dependency vào Gradle build. Android Auto Backup cấu hình trong manifest.
  - **Verification:** `tools/build_plugin.sh && ls android/plugins/tbo_platform/build/outputs/aar/ addons/tbo_platform/bin/`

- [x] **Task 10.2: Plugin Billing**
  - **Allowed Files:** `addons/GodotGooglePlayBilling/**`, `tools/install_billing.sh`, `docs/BILLING_NOTES.md`.
  - **Specs:** Lấy bản mới nhất tương thích Godot 4.7 từ `godot-sdk-integrations/godot-google-play-billing`. Ghi API thực tế vào `docs/BILLING_NOTES.md` cho task sau: tên hàm, signal, cách kiểm chữ ký.
  - **Verification:** `test -f addons/GodotGooglePlayBilling/plugin.cfg && test -f docs/BILLING_NOTES.md`

- [x] **Task 10.3: Backend Android của Platform**
  - **Allowed Files:** `src/platform/android_ads.gd`, `src/platform/android_iap.gd`, `src/platform/android_an.gd`, `src/platform/android_rc.gd`, `src/platform/android_save.gd`, `src/platform/android_notif.gd`, `src/platform/platform.gd`, `project.godot`, `tests/test_platform_android_contract.gd`.
  - **Specs:** Chạy khi editor đóng (mục 1.12). Cùng interface mục 1.9. `android_iap` kiểm chữ ký bằng public key trong config, đơn sai trả `invalid`, giao đơn treo, consume hoặc acknowledge đúng loại, Restore cho `remove_ads`. Bật plugin trong `project.godot`, thêm vào `editor_plugins/enabled` và giữ `godot_ai`. Test hợp đồng so hàm của backend Android với mock bằng reflection, chạy được trên desktop.
  - **Verification:** `tools/godot.sh --headless --path . --import; tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_platform_android_contract`

- [x] **Task 10.4: Bản Gradle và AAB bàn giao**
  - **Allowed Files:** `export_presets.cfg`, `android/build/**` (template, không commit), `android_config.json` (file tạm, không commit), `tools/export_release.sh`, `docs/HORUS_HANDOFF.md`, `tools/godot.sh`.
  - **Specs:** Chạy khi editor đóng (mục 1.12). Chạy `--install-android-build-template`, bật `use_gradle_build=true` cho `Android Release`, `gradle_build/export_format=1` (AAB), target SDK theo yêu cầu hiện hành của Play. `Android Demo` giữ nguyên để vẫn build APK nhanh. `tools/export_release.sh` chép `android/config/platform_config.json` thành `android_config.json` nếu có, export, rồi xoá file tạm; ra APK debug dùng plugin và AAB chưa ký bản phát hành. `docs/HORUS_HANDOFF.md`: danh sách SKU kèm giá USD, placement, khoá Remote Config, sự kiện analytics, file cấu hình Horus cần gửi và nơi đặt, cách build, quy tắc tăng version.
  - **Verification:** `tools/export_release.sh && ls -lh build/*release*.aab build/*gradle*.apk && tools/godot.sh --headless --path . -s res://tests/run_all.gd`

**Cổng Phase 10:** cổng mặc định, `tools/export_apk.sh "Android Demo" build/TapBlockOut-demo.apk` vẫn đạt.

---

## 4. Việc thủ công của người dùng (không chặn Orchestrator)

Orchestrator không đánh dấu các mục này, chỉ liệt kê lại trong báo cáo cuối.

- [ ] Cài APK demo trên máy 2 GB (loại Galaxy A10): chạy từ 30 khung/giây trở lên, âm thanh không trễ, rung nhẹ, lưu game sau khi tắt app.
- [ ] Duyệt cảm giác chơi và các số trong `design.md` mục 5.
- [ ] Nhận từ Horus: `appId`, khoá MAX và ad unit, `google-services.json`, token Adjust, id Play Games, public key Billing. Đặt theo `docs/HORUS_HANDOFF.md`.
- [ ] Có cấu hình rồi: test rewarded, interstitial, mua hàng bằng license tester, Remote Config, cloud save, thông báo trên bản nội bộ.
- [ ] Thông báo trên máy thật, Android 13 trở lên.

## 5. Blocker thật sự

Chỉ các trường hợp sau mới dừng để hỏi người dùng:

- Không xuất được Android sau khi đã thử JDK 17 và tải lại templates.
- `design.md` mâu thuẫn tới mức không thể suy ra hành vi và ảnh hưởng tới kinh tế.
- Một plugin bắt buộc không tương thích Godot 4.7.2 và không có cách thay trong kiến trúc này.
- Cần đóng editor (mục 1.12) trong khi `current_scene` khác rỗng.

Thiếu cấu hình Horus, thiếu máy thật, MCP ComfyUI hoặc MCP `godot-ai` không chạy: **không phải blocker**, ghi lại rồi đi tiếp.
