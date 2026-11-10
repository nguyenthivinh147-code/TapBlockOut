# Kế hoạch triển khai: Tap Block Out (Godot 4.7.2, Android gốc)

Tạo ngày 2026-11-01, đối chiếu lại với thư mục thực tế cùng ngày. Đối chiếu lại với code ngày 2026-11-09: mục 1.5, 1.6, 1.7, 1.8, 1.10, 1.11, bảng mục 2, Task 9.1, 9.3, 9.4, thêm Task 9.13–9.19 cho phần đã làm mà chưa có task; Task 9.20–9.23 là việc mới cùng ngày. Đây là nguồn chân lý duy nhất cho việc thực thi. Sub-agent có bộ nhớ độc lập, chỉ biết những gì đọc từ file này và các file được nêu trong task.

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
- Mọi chữ hiển thị qua `tr("KEY")`, khoá trong `i18n/strings.csv` (cột `keys` rồi 14 ngôn ngữ theo `Game.LANGS`; thêm khoá thì điền đủ mọi cột, `tests/test_i18n.gd` kiểm).
- Gold trong code và save tên `coins`; analytics và UI gọi `gold`.
- Sự kiện analytics và tham số: chữ thường, `snake_case`, giá trị phẳng.
- Sub-agent **không chạy lệnh git ghi** (`add`, `commit`, `reset`, `checkout`, `stash`). Orchestrator giữ git.
- Ranh giới file: chỉ sửa file trong Allowed Files. File `.uid` và `.import` do Godot sinh cho file của mình không tính là vi phạm. Thiếu API ở module khác thì báo lại, không sửa hộ.
- Ảnh PNG trong `assets/` từ 256×256 điểm ảnh trở lên (tính sau `process/size_limit`) import dạng WebP lossy (`compress/mode=1`, `compress/lossy_quality=0.9`) để giảm dung lượng game, nếu lossy nhỏ hơn lossless ít nhất 25%. Icon nhỏ hơn và ảnh màu phẳng (pattern, khung trơn) giữ lossless cho nét sắc. Thêm hoặc xuất lại ảnh thì chạy `tools/godot.sh --headless --path . -s res://tools/compress_textures.gd` rồi import lại; thêm `-- --check` thì không sửa gì, thoát 1 nếu còn file chưa đặt.
- Boot splash `assets/ui/boot_splash.png` phải là PNG: Godot nạp nó trước khi có bộ đọc WebP/JPG, sai định dạng thì hiện splash mặc định. File được đóng nguyên vào gói nên `.import` để `importer="skip"`. Đổi ảnh thì chạy `npm ci --prefix tools/node` rồi `node tools/node/png_shrink.mjs --drop-bits=2 assets/ui/boot_splash.png` (làm tròn mỗi kênh màu về bội số của 4, sai lệch tối đa ±2 mức, không thấy dải màu). Ảnh là `loading_bg.png` có `loading_logo.png` vẽ đè ở `Splash.LOGO_RECT` (px của ảnh 1152×2048); màn loading vẽ lại đúng như vậy trong khung `Splash.boot_rect` để nối liền boot splash, nên đổi ảnh hay vị trí logo thì đo lại `LOGO_RECT` rồi chạy `tests/test_splash_art.gd`. `boot_splash/stretch_mode` chỉ dùng Keep Width, Keep Height, Cover hoặc Ignore (test kiểm), vì màn loading chỉ vẽ theo được bốn mode đó. Đang dùng Keep Height: ảnh luôn cao bằng màn nên logo không bị cắt; trên điện thoại (hẹp hơn 9:16) giống Cover, còn màn rộng hơn (tablet) có hai dải bên màu `boot_splash/bg_color` (hồng tím nhạt, trung bình mép trái và phải của ảnh). Chạy trên desktop, cửa sổ mở ở 443×960 (`window/size/window_*_override`): cửa sổ 886×1920 cao hơn màn hình thì Godot vẽ boot splash cho cỡ đó trước khi trình quản lý cửa sổ thu cửa sổ lại, nên khung đầu bị phóng to.
- Font fallback Jua (tiếng Hàn) và M PLUS Rounded (tiếng Nhật) là bản subset trong `art/fonts/subset/`: chữ có trong `i18n/`, `scenes/`, `data/`, `src/`, cộng đủ kana, jamo, dấu câu CJK và các chữ Hán mà autohinter FreeType dùng để đo (thiếu chúng thì nét chữ Nhật lệch so với font đầy đủ). Thêm hoặc sửa text tiếng Hàn, Nhật thì chạy `node tools/node/subset_fonts.mjs` rồi `tools/godot.sh --headless --path . -s res://tools/gen_baloo_font.gd`; `tests/test_shipped_assets.gd` báo lỗi khi quên. Tên người chơi gõ chữ ngoài bộ subset thì dùng font hệ thống.

### 1.4 Lệnh dùng chung

```bash
tools/godot.sh --headless --path . --quit                                  # nạp autoload và main scene, chạy 1 khung
tools/godot.sh --headless --path . -s res://tests/run_all.gd               # toàn bộ test
tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_board # chỉ tests/test_board*.gd
tools/godot.sh --headless --path . --import                                # chỉ Orchestrator hoặc task được phép, khi editor đóng (mục 1.12)
tools/godot.sh --headless --path . -s res://tools/bake_sdf.gd              # bake lại data/pudding_sdf.res sau khi sinh lại level hay đổi cách dựng SDF
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
src/core/      level_data.gd  board_state.gd  solver.gd  level_generator.gd  silhouette.gd  motifs.gd  difficulty_curve.gd
               level_loop.gd (level hiển thị -> level nội dung sau level cuối)  special_board.gd (Màn đặc biệt)
src/meta/      save_schema.gd  save_store.gd  clock.gd  wallet.gd  lives.gd  unlocks.gd
               rescue_flow.gd  daily_calendar.gd  cosmetics.gd  shop_videos.gd
               ad_pacing.gd  offers.gd  notif_plan.gd  leaderboard.gd  road_trip.gd
               nickname.gd  name_filter.gd  win_streak.gd  app_version.gd
               weekly_pass.gd  chain_offer.gd  pack_conditions.gd (Special Pack)  special_bomb.gd (Màn đặc biệt)
src/platform/  platform.gd (autoload Platform)  mock_*.gd  android_*.gd
src/game/      game.gd (autoload Game)  sfx.gd (autoload Sfx)
src/ui/        theme_kit.gd  ...script màn hình...
scenes/        main.tscn  board_view.tscn  ...  unity/<Prefab>.tscn (layout Unity đã bake)
data/levels/   level_0001.json ... level_0500.json (CONTENT.release_pregen_level; sau L500 lặp lại từ CONTENT.loop_start_level)
data/road_trip/ rt_0001.json ... rt_0400.json (Road Trip, nhập bằng tools/import_road_trip.gd)
data/special/  sp_0001.json ... sp_0100.json (Màn đặc biệt, sinh bằng tools/gen_special.gd; bom đặt lúc vào chơi)
data/pudding_sdf.res  SDF thân khối bake sẵn cho mọi hình của ba thư mục trên (tools/bake_sdf.gd)
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
  "id": 21, "w": 14, "h": 18, "hard": false,
  "min_taps": 24, "moves": 26, "seed": 0,
  "stones": [[3, 4]],
  "pulse_sides": [{"side": "up", "open": false}],
  "blocks": [
    {"id": "b1", "color": "yellow", "cells": [[0,0],[0,1]],
     "ice": 0, "chained_by": "", "inner_color": "", "fog": false}
  ]
}
```

- Màu và hướng: `yellow` lên `(0,-1)`, `green` trái `(-1,0)`, `blue` phải `(1,0)`, `purple` xuống `(0,1)`. Mã màu (đề xuất của người lập kế hoạch): `#F5C518`, `#43B649`, `#2F80ED`, `#9B51E0`.
- Cạnh ứng với màu: `up`, `left`, `right`, `down`.
- `ice`: số lớp phủ (0–2, `Config.COVER_MAX_LAYERS`). Khối còn phủ chạm vào không đi; mỗi khối kề rời bàn (thoát hoặc bị Phá) bóc 1 lớp. Lớp phủ là pudding, hoặc băng khi level có `"cover": "frost"` (thiếu khoá là pudding; `LevelData.COVERS`). `chained_by`: id khối chìa. `inner_color`: lớp trong. `fog`: khối ẩn màu tới khi một khối kề rời đi; còn ẩn thì chạm vào không đi (`tap` trả `fog`). `ribbons` (tuỳ chọn, chỉ khối có ruy băng): mảng 1–4 màu ruy băng ngoài vào trong, khi đó `color` là màu kẹo trong cùng; mỗi `peel` bóc ruy băng ngoài cùng, `block_view` trả màu lớp ngoài hiện tại ở `color` và số ruy băng còn lại ở `ribbons` (`LevelData._validate_ribbons`, `design.md` mục 4).
- `choco_sides` (tuỳ chọn, Task 9.25): `[{"side": "up", "layers": 1..4}]`, thanh phủ socola (`Config.CHOCO_MAX_LAYERS`); mỗi cạnh một lần, không chung cạnh với `pulse_sides` (`LevelData._validate_choco`). Khối (hay ruy băng ngoài, vỏ hộp) hướng về thanh còn socola chạm vào không đi, không tốn MOVES (`tap` trả `choco`); mỗi `exit`, `peel` hay `smash` bớt 1 lớp mọi thanh còn socola (`tap` trả các cạnh vừa bớt ở `choco`; `choco()`, `choco_layers`, `melt_choco`).
- `pop` (tuỳ chọn, Task 9.26): `true` ở khối bom kẹo. Bom kẹo rời bàn (`exit` hay `smash`) thì mọi khối có ô cách một ô của nó tối đa `Config.POP_RADIUS` ô theo cả hai trục mất hết lớp phủ và lộ khỏi sương (`tap` trả các khối đó ở `popped`, `smash` để ở `last_popped()`; `pop_targets(id)`). Khối bom kẹo không có cơ chế khác và không làm chìa (`LevelData._validate_pop`). `block_view` có `pop`.
- `moves = min_taps + dư`. Dư cố định theo bậc trong `design.md` mục 3 (`Config.CONTENT.slack_*`), không theo số khối. `Game` cộng lại dư từ `min_taps` lúc vào level, nên `moves` trong file chỉ là giá trị theo số mặc định.
- Level nhiều cổng (Road Trip, `data/road_trip/rt_NNNN.json`, `design.md` mục 7 "Road Trip"): khối có thêm `"dir"` (`up` | `left` | `right` | `down`), khi đó `color` là màu cổng trong `LevelData.GATE_COLORS` (12 màu) và hướng theo `dir`; level có `"gates": {"up": [["red", 0, 7], ["teal", 7, 14]], ...}` (màu, từ ô, tới ô dọc cạnh, phủ hết cạnh, mỗi màu một cổng) để vẽ khung. `moves` lấy thẳng `StepLimit`, không tính lại theo dư.
- Bàn Màn đặc biệt (`data/special/sp_NNNN.json`, Task 9.23, `design.md` mục 7 "Màn đặc biệt"): lát kín hình chữ nhật, thêm `"special": true`, `"rect": [x, y, w, h]`, `"rounds"` (số lượt dọn bàn); bom không nằm trong file mà đặt lúc vào chơi.

### 1.7 Interface `BoardState` (`src/core/board_state.gd`)

`BoardState` là tên hằng preload, không phải `class_name`. Trong chính file này khai báo `const BoardState := preload("res://src/core/board_state.gd")`; cách tự tham chiếu này chạy được trên 4.7.2.

```gdscript
func _init(level: Dictionary) -> void
func clone() -> BoardState
func tap(block_id: String) -> Dictionary
# {kind: "exit"|"peel"|"blocked"|"chained"|"gate_closed"|"fog"|"covered"|"rejected",
#  id, distance: int, blocker: String, moves_left: int, won: bool, revealed: Array[String],
#  stripped: Array[String], popped: Array[String], choco: Array[String]}
#  stripped: khối kề vừa bị bóc 1 lớp phủ vì khối này thoát; popped: bom kẹo vừa thoát, khối trong vùng nổ vừa được gỡ
func can_exit(block_id: String) -> bool     # tính cả xích, lớp phủ, cổng nhịp
func first_exit() -> String                 # khối đầu tiên thoát (hoặc bóc lớp) được ngay; "" nếu không có
func hint() -> String                       # bom kẹo thoát được mà vùng nổ còn khối phủ hoặc ẩn, rồi first_exit(), rồi khối dội cổng khoá
func smash(block_id: String) -> bool        # không tốn MOVES; đá không phải khối nên không chọn được
func last_popped() -> Array[String]         # khối vừa được bom kẹo gỡ ở lần smash gần nhất
func pop_targets(block_id: String) -> Array[String]  # khối còn phủ hoặc ẩn trong vùng nổ của block_id
func reveal(block_id: String) -> void       # bỏ sương của khối; bộ sinh dùng để gỡ bàn kẹt vì sương mù
func strip(block_id: String) -> void        # bóc 1 lớp phủ; bộ sinh dùng để gỡ bàn kẹt vì lớp phủ
func cover_kind() -> String                 # "pudding" hoặc "frost" (khoá `cover` của level)
func add_moves(n: int) -> void
func remaining_count() -> int
func moves_left() -> int
func is_won() -> bool
func is_out_of_moves() -> bool              # moves_left == 0 và chưa thắng
func block_view(block_id: String) -> Dictionary  # màu hiện tại, ô, ice, cover, chained, is_fog_hidden
func block_ids() -> Array[String]
func gate_open(side: String) -> bool
func gates() -> Dictionary                  # cạnh có cổng nhịp -> đang mở
func gate_segments() -> Dictionary          # Road Trip: cạnh -> [[màu, từ ô, tới ô)], chỉ để vẽ khung; {} với level thường
func width() -> int; func height() -> int; func stones() -> Array[Vector2i]
func peek(block_id: String) -> String       # kind mà tap() sẽ trả, không đổi trạng thái
func inspect(block_id: String) -> Dictionary  # như peek, thêm {distance, blocker}; blocker là khối chặn, chìa hoặc "gate"
func state_key() -> String                  # khoá trạng thái (không gồm MOVES) cho solver và test
```

Mọi `tap` hợp lệ giảm 1 MOVES, kể cả `chained`, `blocked`, `gate_closed`. Riêng khối còn trong sương (`is_fog_hidden`) trả `fog`, và khối còn lớp phủ (`ice` > 0) trả `covered`: không đi, không tốn MOVES, không đổi gì; thứ tự ưu tiên sương mù > xích > lớp phủ. `exit` và `smash` bóc 1 lớp phủ của mỗi khối kề (chung cạnh); `peel` không bóc. Cổng nhịp chỉ đổi khi khối của cạnh đó chạm tới thanh: `gate_closed` mở cổng, `exit` hoặc `peel` qua cạnh đó khoá cổng lại; kết quả khác (khối cạnh khác, `blocked`, `chained`, `covered`) và `smash` không đổi cổng. `peel` là thoát lớp ngoài: khối ở nguyên, đổi sang `inner_color`. Khi `moves_left == 0` hoặc đã thắng, `tap` trả `rejected`.

### 1.8 Trạng thái lưu (`src/meta/save_schema.gd`)

`static func defaults() -> Dictionary`, gọi là `s` ở mọi module. Mỗi module meta chỉ đọc và ghi nhóm khoá của mình.

```gdscript
{
  "version": 1, "coins": Config.ECON.start_coins,
  "inv": {"hint": 0, "move": 0, "smash": 0},
  "gifted": {"hint": false, "move": false, "smash": false},
  "mech_seen": [],  # cơ chế đã hiện popup giới thiệu ở level dạy (Unlocks.pending_mech, Game.claim_mech_intro)
  "level": 1, "runs": 0, "play_ms": 0, "fail_streak": {"level": 0, "count": 0},
  "lives": {"count": 10, "next_at": 0,
            "bonus": 0,      # mạng tối đa cộng thêm khi Weekly Pass VIP đang Active (Lives.max_for)
            "inf_until": 0,  # mạng vô hạn tới lúc này, unix giây; 0 là không có (thưởng Weekly Pass, league)
            "inf_forever": false}, # mạng vô hạn vĩnh viễn (SKU có inf_forever: starter_pack, helper_great; Lives.forever)
  "daily": {"idx": 0, "claim_day": -1, "ad_day": -1},
  "shop": {"day": -1, "videos": 0},
  "cos": {"owned": ["avatar_00", "frame_00"], "avatar": "avatar_00", "frame": "frame_00"},
  "profile": {"name": ""},  # biệt danh; "" thì boot ghi mã mặc định CD_ + 6 chữ số (design.md mục 5 "Biệt danh"), src/meta/nickname.gd
  "ads": {"last_inter_run": -99, "last_inter_at": 0, "last_rv_at": 0, "inter_today": 0, "inter_day": -1},
  "ad_pend": {}, "ad_credit": {},
  "offers": {"last_run": -999, "items": {}},
  "buys": [], "no_ads": false,
  "weekly": {"cycle": "", "points": 0, "vip": false, "opened": false, "end_seen": false, "tut_seen": false,
             "claimed_free": [], "claimed_vip": [], "claimed_bank": [],
             "pending_end": {},
             "upsell": ""},  # Weekly Pass (design.md mục 7), src/meta/weekly_pass.gd; tut_seen không reset theo mùa; upsell = mùa đã hiện popup mời VIP
  "chain": {"active": false, "id": "", "step": 0, "expires": 0, "cooldown_until": 0,
            "shown": false, "rotation": 0},  # Chain Offer (design.md mục 7), src/meta/chain_offer.gd
  "challenge": {"day": -1, "won": false},
  "road_trip": {"level": 1, "boxes": 0, "guide": false},  # Road Trip (design.md mục 7), src/meta/road_trip.gd
  "special": {"slot_at": 0, "bonus": 0, "wins": 0, "board": 1, "invited": false, "guide": false},  # Màn đặc biệt (design.md mục 7), src/meta/special_bomb.gd
  "streak": {"week": -1, "started": false, "auto_shown": false, "count": 0, "before": 0,
             "claimed": []},  # Win Streak (design.md mục 7), src/meta/win_streak.gd
  "lb": {"joined": false, "points": 0, "league": 0, "seed": 0, "day": -1, "seen_rank": 0,
         "bots": [], "risen": [], "pending": [], "pending_cos": [],  # pending_cos: avatar/frame đã chọn cho league chờ
         "t0": 0, "week": 0, "clock": 0, "result": {},
         "guide": false},  # Leaderboard (design.md mục 7), src/meta/leaderboard.gd; guide = đã hiện Cách hoạt động ở level crystal đầu
  "notify": {"ignored": 0, "plan": [], "asked": false, "hours": []},
  "settings": {"sfx": true, "music": true, "haptics": true, "notif": true, "lang": ""},
  "meta": {"install_at": 0, "sessions": 0, "first_session_done": false, "rated": false, "ftue": [],
           "intro_seen": false}  # intro_seen: hướng dẫn đầu (wireframe 1.5) đã hiện
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
func wipe() -> void                    # menu tester xoá tài khoản: save.wipe() bỏ backup và cache cloud, iap.wipe() (mock quên món đã mua)
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
signal ad_wait(on: bool)            # watch đang chờ video sẵn sàng: Main hiện ad_loading (11.1)
signal notice(kind: String)         # "not_ready" (popup_notice 11.2) | "offline" (popup_no_internet 1.6), Main hiện
signal cloud_conflict               # bản cloud là lịch sử chơi khác: Main mở select_account (1.4)
var s: Dictionary
var last_ad_reason: String          # lý do lần rewarded gần nhất không thưởng ("closed" | "not_ready" | "offline" | "error")
var test_now: int; var test_tz: Variant  # chỉ test: giờ giả (0 là giờ máy), múi giờ giả (null là của máy)
func boot() -> void                 # thứ tự: backup, cloud, Remote Config, ngôn ngữ, meta, đơn treo, quảng cáo mất
func reset_for_test(path: String) -> void  # file lưu riêng, trạng thái và nhật ký sạch
func now() -> int
func today() -> int
func save_now() -> void
func log_event(event_name: String, params: Dictionary = {}) -> void  # thêm tham số build
func current_lang() -> String       # mã đã chọn trong Settings, chưa chọn thì theo máy
static func match_lang(locale: String) -> String  # mã trong LANGS cho locale máy ("pt_PT" -> "pt_BR"), không khớp thì "en"
func set_in_level(v: bool) -> void  # main báo đang ở màn level/challenge; ra khỏi level thì áp bản cloud đang chờ
func ftue(step: String) -> void     # mỗi bước trong CONTENT.ftue_steps một lần, bước lạ bị bỏ qua
func haptic(ms: int) -> void        # Platform.haptic nếu cài đặt rung bật
func set_setting(key: String, value: Variant) -> void
# level: s.level là số hiển thị, tăng mãi; file nội dung theo content_level (Task 9.4)
func current_level_data() -> Dictionary  # {} khi demo qua demo_max_level hoặc thiếu file
func content_level(lv: int) -> int  # LevelLoop.content_level(lv, CONTENT.loop_start_level, CONTENT.release_pregen_level)
func difficulty_of(lv: int) -> String  # "" | "hard" | "very_hard"
func level_exists(lv: int) -> bool  # demo: tới demo_max_level; phát hành: có file nội dung (kể cả trong vòng lặp)
func generate_checked(id: int, base_seed: int) -> Dictionary  # sinh, validate, Solver, sinh lại seed kế; {} nếu hỏng hết
func start_attempt() -> Dictionary  # {board, rescue, level, ...} hoặc {} khi hết level hay thiếu dữ liệu
func tap(attempt: Dictionary, block_id: String) -> Dictionary  # BoardState.tap + piece (khối crystal rời bàn); đếm lượt chạm
func smash_block(attempt: Dictionary, block_id: String) -> Dictionary  # {ok, piece, popped}; UI đã trừ booster qua use_booster
func on_level_won(attempt: Dictionary) -> Dictionary  # {coins, move_coins, card, x2_available, x2_free, rate_prompt, progress, unlocked, weekly_points, lb, streak_up}; coins gồm move_coins (MOVES thừa x ECON.win_move_coins); card = false dưới ECON.win_card_from_level (không thẻ thắng, không x2, không hỏi đánh giá)
func next_after_win(res: Dictionary, challenge: bool) -> String  # "home" khi thẻ vừa báo mở tính năng ở Home hoặc thắng Daily Challenge, còn lại "level" (card = false luôn "level")
func on_level_lost(attempt: Dictionary) -> void
func restart_cost_life(attempt: Dictionary) -> bool
func claim_x2() -> bool             # coroutine: video x2_coins, thẻ đầu tiên (ECON.win_card_from_level) miễn phí
func leave_win_card(x2_offered: bool, x2_taken: bool) -> void  # coroutine: interstitial result_exit, rồi offer, rồi xin quyền thông báo
func rate_now() -> void             # hộp đánh giá của store, sau popup đánh giá (popup_rate, 4.3)
func leave_attempt(attempt: Dictionary) -> void  # về Home giữa ván đã chạm: chuỗi Win Streak tụt (kể cả không mất mạng)
func helper_pack_due(attempt: Dictionary, offer: Dictionary) -> bool  # popup hết MOVES kèm Helper Pack (4.7) thay popup thường
func take_intro() -> bool           # hướng dẫn đầu (1.5) trước lần chơi đầu L1, true một lần
static func app_version() -> String
func update_state() -> String       # "" | "optional" | "force" (popup_update 1.2, CONTENT.latest_version / min_version)
func mark_update_asked() -> void
func open_store() -> void
func cloud_conflict_view() -> Dictionary  # {local, cloud}: {name, level, avatar}; {} khi không có xung đột
func resolve_cloud(use_cloud: bool) -> void  # giữ một bản, gộp đơn mua của bản kia
func notice_shown(reason: String) -> bool  # lỗi video/mua đã được Main báo bằng popup: màn gọi không báo thêm
func online() -> bool               # coroutine: HEAD CONTENT.net_check_url; test đặt test_online
# Win Streak (design.md mục 7 "Win Streak", Task 9.18)
func streak_refresh() -> void       # WinStreak.validate: ngày Active của tuần mới thì bắt đầu lượt mới, lượt cũ quá hạn thì xoá (quà chưa nhận mất); streak_view tự gọi
func streak_view() -> Dictionary    # WinStreak.view: {visible, running, started, streak, floor, before, milestones, claimable, ends_in, next_in, entry}
func streak_entry() -> String       # "intro" | "main" | "end" | ""
func streak_take_auto_intro() -> bool
func streak_start() -> bool
func streak_claim(streak: int) -> Dictionary  # thưởng đã cộng, {} nếu không nhận được
func streak_at_stake(attempt: Dictionary) -> bool  # bỏ ván lúc này làm chuỗi tụt
func streak_take_lost() -> bool     # chuỗi vừa tụt: true một lần (popup "Bạn đã mất chuỗi")
func weekly_take_upsell() -> bool   # popup Weekly Pass Upsell (7.5) một lần mỗi mùa
func claim_gift() -> String         # booster tặng kèm hướng dẫn tới hạn, "" nếu hết; gọi lặp
func claim_mech_intro(level: int) -> String  # cơ chế mới cần popup giới thiệu ở level dạy, "" nếu không; ghi s.mech_seen ngay
# ví, booster
func spend_coins(n: int, sink: String) -> bool
func use_booster(kind: String) -> bool  # chỉ lấy khỏi kho; hiệu ứng lên bàn do UI làm
func buy_booster(kind: String) -> bool
func booster_video(kind: String) -> bool  # coroutine: video booster_free, kho +1, không giới hạn số lần
# quảng cáo: tự log rv_offer/rv_start/rv_done, lưu trước khi hiện, dừng nhạc
func watch(placement: String, ctx: Dictionary = {}) -> bool  # coroutine; không tự thưởng; hỏng thì xem last_ad_reason
func offer_video(placement: String) -> void  # nút mời xem vừa hiện: log rv_offer một lần tới lần xem kế
# rescue, quà, cosmetic, biệt danh: bọc module meta, log analytics, lưu
func rescue_offer(attempt: Dictionary) -> Dictionary  # RescueFlow.offer + lost (index < 0); log rescue_show
func rescue_accept(attempt: Dictionary, method: String) -> bool  # "inventory" | "gold" | "video"; thành công thì +3 MOVES
func rescue_skip(attempt: Dictionary) -> void
func daily_view() -> Dictionary
func daily_claim() -> Dictionary
func daily_claim_next() -> Dictionary
func cos_buy(id: String) -> bool
func cos_unlock_video(id: String) -> bool  # sai với món chỉ có từ Road Trip hay thưởng league (Cosmetics.for_sale, Config.ROAD_TRIP_COSMETICS, LEADERBOARD.cosmetics)
func cos_equip(id: String) -> bool
func profile_name() -> String       # biệt danh; chưa có thì ghi và trả mã mặc định "CD_042917"
func set_profile_name(raw: String) -> String  # "" là đã lưu, hoặc Nickname.ERR_LENGTH | ERR_CHARS | ERR_BANNED ("length" | "chars" | "banned")
# shop, mua hàng, offer
func shop_watch_video() -> bool
func shop_videos_left() -> int
func shop_opened(source: String = "") -> void  # log shop_open
func shop_catalog() -> Array        # gói gold theo giá sale hôm nay, thêm price_text; lúc sale gói rẻ hơn gói thường có base_price_text, sale_percent
func has_purchased() -> bool        # đã từng mua gói nào (weekend_sale_mode 2)
func is_sale_active() -> bool       # weekend sale bật cho người chơi này (mode, ngày, lịch sử mua)
func buy_sku(sku: String) -> Dictionary  # coroutine: {status, granted}; status "offline" khi lỗi vì mất mạng (đã báo qua notice), "owned" khi owns_once
func owns_once(sku: String) -> bool  # gói mua một lần (consumable false) đã mua; bản thường và bản _sale tính chung
func grant_purchase(p: Dictionary) -> bool  # giao một đơn, mỗi token một lần (gói mua một lần: mỗi gói một lần), luôn finish
func restore_purchases() -> bool
func check_offer(on_lose: bool = false) -> String  # offer cần hiện ("" nếu không); ghi shown, log offer_show, phát offer_ready
func offer_buy(id: String) -> Dictionary  # coroutine: buy_sku(offer_sku(id))
func offers_open() -> Array         # [{id, sku, until}]
func offer_in_shop(id: String) -> bool  # Shop bán thẻ gói của offer không (Offers.in_shop: offer đang mở; rescue khi thua liền)
func offer_sku(id: String) -> String  # Config.OFFERS rồi Config.PACKS; lúc sale đổi sang <sku>_sale nếu có
func special_pack_id() -> String    # gói cần hiện icon ở Home ("" nếu không), PackConditions.first_visible (Task 9.14)
# Weekly Pass (design.md mục 7, Task 9.13)
func weekly_unlock_level() -> int   # level HARD thứ WEEKLY.unlock_hard_index; 0 nếu không có
func weekly_unlocked() -> bool      # s.level đã qua weekly_unlock_level()
func weekly_state() -> String       # WeeklyPass.LOCKED | ACTIVE | WAITING
func weekly_refresh() -> Dictionary # sang mùa nếu cần (VIP tự nhận thưởng tồn), đặt s.lives.bonus; trả {settled, reward}
func weekly_view() -> Dictionary    # {state, unlocked, seconds_left, points, last_points, vip, vip_price, badge, dot, pending_end, main, bank, bank_unlocked, bank_slots, bonus_hearts, tut_seen, tut_row, progress}
func weekly_tutorial_seen() -> bool # chưa xem thì thắng level không cộng key
func weekly_mark_tutorial_seen() -> void
func weekly_opened() -> void        # người chơi mở layer: ghi opened, end_seen
func weekly_take_end() -> Dictionary  # lấy và xoá popup cuối mùa đang chờ ({} nếu không có)
func weekly_claim_free(i: int) -> Dictionary  # các hàm claim trả thưởng đã cộng {coins, items, inf_min}, {} nếu không nhận được
func weekly_claim_vip(i: int) -> Dictionary
func weekly_claim_bank(i: int) -> Dictionary
func weekly_claim_all() -> Dictionary  # hết Main Tree và Bonus Bank đang nhận được
func weekly_buy_vip() -> Dictionary # coroutine: chỉ khi Active và chưa VIP; kết quả như buy_sku
# Chain Offer (design.md mục 7, Task 9.14)
func chain_view() -> Dictionary     # {id, steps, step, count, expires, seconds_left} hoặc {}
func chain_take_autoshow() -> bool  # true đúng một lần mỗi chuỗi: main mở layer khi ở Home
func chain_claim() -> Dictionary    # coroutine: bước free / ad (chain_offer) / pay (SKU của bước); {ok, type, reward, status}
# Leaderboard (design.md mục 7, Task 9.15, 9.20)
func lb_open() -> bool              # UNLOCK.leaderboard và LEADERBOARD.enabled
func lb_refresh() -> void           # vào BXH khi vừa mở khoá (tuần đầu bắt đầu), chốt tuần đã hết, bù điểm bot theo ngày; gọi lúc boot, resume, vào level, trước khi đọc view
func lb_view() -> Dictionary        # tab League: {open, unlock_level, league, league_index, league_count, points, league_min, next_min, next_league, progress, rank, size, delta, top_percent, ends_in, podium, rows, pending}
func lb_world_view() -> Dictionary  # tab World: Leaderboard.world + points, league
func lb_leagues_view() -> Dictionary  # thang league: {current, points, rows: [{id, min, max, reward, has_reward, reached, current}]}; reward là Leaderboard.preview_reward (cos_random 0 khi hết món)
func lb_opened() -> void            # ghi hạng đang thấy để lần sau hiện ▲/▼
func lb_pending_view() -> Dictionary  # popup lên league: {leagues, league, reward} hoặc {}
func lb_claim() -> Dictionary       # nhận thưởng các league đang chờ, {} nếu không có; thưởng {coins, items, inf_min, cos: [id avatar/frame]}, cos vào đồ đã có (không đeo)
func lb_week_result_view() -> Dictionary  # kết quả tuần chờ xem: {week, league, points, rank, reward} hoặc {}
func lb_week_claim() -> Dictionary  # đóng kết quả tuần: cộng thưởng của nó, {} nếu không có kết quả
func lb_ends_in() -> int            # giây tới lúc hết tuần
func lb_badge() -> bool             # chấm đỏ ở icon Bảng xếp hạng: kết quả tuần hoặc thưởng league chờ
func lb_take_guide(attempt: Dictionary) -> bool  # true một lần khi attempt có khối crystal (popup Cách hoạt động lúc vào level, s.lb.guide)
# mạng
func lives_view() -> Dictionary     # {count, max, seconds_to_next, open, infinite, infinite_left, infinite_forever, can_play, refill_price, refill_lives, can_refill_gold, video_ready}
func refill_gold() -> bool
func refill_video() -> bool
# Daily Challenge (Task 9.4); tắt bằng Config.FEATURES.challenge
func challenge_level_id() -> int    # level đã thắng gần nhất (s.level - 1), kẹp vào [50, CONTENT.release_pregen_level]
func challenge_data(day: int = -1) -> Dictionary  # generate_checked(challenge_level_id(), today() * 1000)
func challenge_view() -> Dictionary # {enabled, open, locked, unlock_level, available, won, coins, level}
func start_challenge() -> Dictionary  # như start_attempt, thêm challenge = true; {} khi khoá hoặc đã thắng hôm nay
func challenge_needs_generation() -> bool  # chưa có trong cache: UI hiện màn chờ
# Road Trip (design.md mục 7 "Road Trip"): attempt có road_trip = true, thắng/thua qua on_level_won / on_level_lost
func road_trip_view() -> Dictionary  # {open, unlock_level, level, done, levels, progress, next_box, prev_box, boxes, guide, tier}
func road_trip_data(lv: int) -> Dictionary  # data/road_trip/rt_NNNN.json, {} nếu ngoài 1..levels hoặc thiếu file
func road_trip_tier(lv: int) -> String  # "" | "hard" | "very_hard" theo Difficulty của file
func start_road_trip() -> Dictionary
func road_trip_revive_view(attempt: Dictionary) -> Dictionary  # {available, moves, left}
func road_trip_revive(attempt: Dictionary) -> bool  # coroutine: video rt_revive, +revive_moves bước
func road_trip_mark_guide() -> void
func road_trip_leave_win(rt_level: int) -> void  # coroutine: interstitial result_exit, cùng luật thẻ thắng
# Màn đặc biệt (design.md mục 7 "Màn đặc biệt", Task 9.23): attempt có special = true, bombs, ticket
func special_view() -> Dictionary  # {open, unlock_level, tickets, timer_ready, wait_sec, bonus, wins, bombs, invite_first, guide}
func special_data(n: int) -> Dictionary  # data/special/sp_NNNN.json của bàn thứ n (quay vòng), {} nếu thiếu
func special_start() -> Dictionary  # dùng 1 vé (ngăn chờ trước), đặt bom theo số trận thắng; {} khi khoá / hết vé
func special_lost(attempt: Dictionary, reason: String, bombs_left: int = 0) -> void  # steps | bomb | quit, không mất mạng
func special_claim_x2() -> bool  # coroutine: video special_x2, +1 booster cùng loại
func special_leave_win(x2_taken: bool) -> void  # coroutine: interstitial result_exit
func special_queue_invite() -> void  # vé từ Hard / VeryHard mà sau thẻ thắng về Home: Home mời
func special_take_invite() -> bool  # lần đầu sau khi mở, hoặc lời mời đang chờ khi còn vé
func special_mark_guide() -> void
# on_level_won: thêm special_tickets (vé vừa cộng khi thắng Hard / VeryHard); bàn special trả {special, reward, x2_available}
# menu tester, chỉ khi Config.account_tool() (bản debug); không log earn/spend
func tester_edit(edits: Dictionary) -> bool  # {coins?, level?, inv?: {hint, move, smash}, rt_level?}
func tester_wipe() -> bool          # coroutine: xoá file lưu, Platform.wipe(), boot lại như lần cài đầu
```

### 1.11 Màn hình

`scenes/main.tscn` (`src/ui/main.gd`) giữ một màn hiện tại và một lớp popup:

```gdscript
func go(screen: String, args: Dictionary = {}) -> void  # "splash", "home", "level", "no_lives", "profile", "shop", "challenge", "road_trip" (Leaderboard là popup, open_popup)
func open_popup(scene_path: String, args: Dictionary = {}) -> Node
func boot_to_level() -> bool  # sau màn loading: vào thẳng level khi chơi được (còn mạng, còn level), không thì Home
```

Mọi màn và popup là scene có script `func setup(args: Dictionary) -> void` và signal `closed(result: Variant)`. UI tĩnh của màn là node trong scene (layout Unity instance từ `scenes/unity/<Prefab>.tscn`); script chỉ tìm node, điền chữ, dữ liệu, signal, còn phần theo dữ liệu thì sinh lúc chạy (`docs/UI_NODES.md`). Nút Back Android đóng popup trên cùng. Đường dẫn scene: `scenes/<tên>.tscn`, script `src/ui/<tên>.gd`. Kích thước gốc 720×1280, stretch `canvas_items`, aspect `expand`, nút tối thiểu 96×96 ở độ phân giải gốc (tương đương khoảng 48dp).

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
3. **Task sửa `project.godot`, `export_presets.cfg` hoặc editor settings chạy khi editor đóng**, gồm 0.2, 0.3, 7.3, 9.17, 10.3, 10.4, vì editor giữ bản trong RAM và có thể ghi đè. MCP cũng từ chối ghi `editor_plugins/*`. Trước các task này Orchestrator kiểm `editor_state`: `current_scene` rỗng thì đóng bằng `editor_manage(op="quit")`; khác rỗng thì có thể người dùng đang làm việc, phải hỏi trước, không tự lưu. Xong task thì mở lại bằng `nohup tools/godot.sh --editor --path . >/dev/null 2>&1 &` và kiểm `session_manage(op="list")`. Không có session cũng không chặn việc.
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
| 9 | Nội dung phát hành | 9.1, 9.2, 9.5 | sau đó 9.3 → 9.4; 9.6–9.32 tuần tự (chung `game.gd`, `config.gd`, `save_schema.gd`, `home.gd`, `i18n/strings.csv`) |
| 10 | Android thật | 10.1, 10.2 | sau đó 10.3 → 10.4 |

Phase 9–10 làm tiếp sau mốc demo, ẩn sau preset `Android Release`, nên không đổi bản demo. Nếu người dùng duyệt demo và đổi luật, các phase này có thể phải sửa theo.

### Mốc theo ngày

Ngày lấy từ tiêu đề task và các đoạn "Bổ sung" trong mục 3. Task 0.1–9.5 và Phase 10 không ghi ngày, lấy theo commit đầu `5031784` (2026-11-01). Task làm qua nhiều ngày có mặt ở mỗi ngày; các ngày sau ghi "(bổ sung)" kèm phần làm hôm đó. Thêm task mới hay bổ sung có ngày thì ghi thêm vào đây.

**2026-11-01:** lập kế hoạch, **mốc bản demo** (L1–20, APK `Android Demo`).

- **Phase 0, Nền dự án:** Task 0.1: Repo và dọn file Horus; Task 0.2: Project Godot và test runner; Task 0.3: Môi trường xuất Android.
- **Phase 1, Config và schema:** Task 1.1: Config; Task 1.2: Save schema và kho lưu.
- **Phase 2, Logic thuần:** Task 2.1: Bàn cờ và solver; Task 2.2: Ví, mạng, mở khoá; Task 2.3: Luồng hết MOVES; Task 2.4: Quà 28 ngày; Task 2.5: Avatar, frame, video shop; Task 2.6: Nhịp interstitial; Task 2.7: Offer và sale; Task 2.8: Lịch thông báo.
- **Phase 3, Nền tảng, chữ, level demo:** Task 3.1: Platform và mock; Task 3.2: Chữ en và vi; Task 3.3: 20 level demo.
- **Phase 4, Điều phối:** Task 4.1: Autoload Game; Task 4.2: Theme và Sfx.
- **Phase 5, UI từng màn:** Task 5.1: BoardView; Task 5.2: Home và Profile; Task 5.3: Popup hết MOVES, thắng, thua, hết mạng; Task 5.4: Shop và offer; Task 5.5: Popup quà và Settings.
- **Phase 6, Ráp màn level:** Task 6.1: Màn level và điều hướng; Task 6.2: E2E headless toàn demo.
- **Phase 7, Hình và âm thanh:** Task 7.1: Hình; Task 7.2: Âm thanh; Task 7.3: Nối tài nguyên.
- **Phase 8, Mốc bản demo:** Task 8.1: Kiểm tra bằng hình; Task 8.2: APK demo và ghi chú duyệt.
- **Phase 9, Nội dung phát hành:** Task 9.1: Bộ sinh level; Task 9.2: Hiển thị cơ chế; Task 9.3: Sinh L21–100 và level dạy; Task 9.4: Daily Challenge, vòng lặp sau level cuối, cơ chế trong game; Task 9.5: Tài nguyên cơ chế.
- **Phase 10, Android thật:** Task 10.1: Plugin Kotlin; Task 10.2: Plugin Billing; Task 10.3: Backend Android của Platform; Task 10.4: Bản Gradle và AAB bàn giao.

**2026-11-02:**

- Task 5.3: Popup hết MOVES, thắng, thua, hết mạng (bổ sung): thẻ thắng có thanh tiến trình tính năng.
- Task 9.4: Daily Challenge, vòng lặp sau level cuối, cơ chế trong game (bổ sung): sau level cuối lặp lại nội dung, không sinh level mới.
- Task 9.13: Weekly Pass.
- Task 9.14: Chain Offer và Special Pack.

**2026-11-03:**

- Task 9.1: Bộ sinh level (bổ sung): mọi level nhân `DifficultyCurve.COUNT_SCALE` = 2.
- Task 9.2: Hiển thị cơ chế (bổ sung): vật cản vẽ theo theme kẹo.
- Task 9.6: Khó hơn từ L14, hình có chủ đích.
- Task 9.7: Gấp đôi số khối mọi level.
- Task 9.13: Weekly Pass (bổ sung): tutorial.
- Task 9.15: Leaderboard theo league.
- Task 9.17: Màn loading khi mở game.

**2026-11-04:**

- Task 6.1: Màn level và điều hướng (bổ sung): không chạm `idle_hint_sec` giây thì nhắc Gợi ý.
- Task 9.2: Hiển thị cơ chế (bổ sung): đá đổi thành thùng sắt bốn đinh tán.

**2026-11-05:**

- Task 9.8: Không giới hạn hình dạng khối.
- Task 9.9: Road Trip, Bảng xếp hạng thành icon ở Home.
- Task 9.15: Leaderboard theo league (bổ sung): màn mới, icon cúp ở cột trái Home.
- Task 9.16: Biệt danh.

**2026-11-08:**

- Task 5.3: Popup hết MOVES, thắng, thua, hết mạng (bổ sung): thẻ thắng hiện ngay khi khối cuối rời bàn.
- Task 6.1: Màn level và điều hướng (bổ sung): popup `booster_unlocked`, video `booster_free` không giới hạn, lời khen `PraiseFx`.
- Task 9.4: Daily Challenge, vòng lặp sau level cuối, cơ chế trong game (bổ sung): công tắc `Config.FEATURES.challenge`.
- Task 9.10: Khối to hơn, xếp có chủ đích (kèm luật cổng nhịp mới).
- Task 9.11: Bake sẵn SDF thân khối.
- Task 9.12: 500 level bám game tham khảo.
- Task 9.17: Màn loading khi mở game (bổ sung): nối boot splash, vào thẳng level.

**2026-11-09:** đối chiếu kế hoạch với code, thêm Task 9.13–9.19 cho phần đã làm; mục 4 thêm việc duyệt chỗ đặt `load_transition` và việc báo sinh lại level.

- Task 9.18: Win Streak.
- Task 9.19: Nối logic các màn wireframe còn lại, gói No Ads, Helper Packs, Bundles.
- Task 9.20: Leaderboard thành popup, điểm theo tuần.
- Task 9.21: Road Trip khó hơn 10%, bỏ ghi nguồn.
- Task 9.22: Pudding bóc theo khối kề, thêm băng (còn bước sinh lại level).
- Task 9.23: Màn đặc biệt (Special Bomb).

**2026-11-10:**

- Task 9.25: Socola phủ thanh (cơ chế thứ 9, L150; từ 2026-11-10 là L300).
- Task 9.26–9.32: lập kế hoạch 7 cơ chế mới (bom kẹo, dây kẹo kéo, hũ kẹo, kẹo hai vị, kẹo tên lửa, ống kẹo, kẹo mút chong chóng), chưa làm.

---

## 3. Sub-agent Work Packages

### Phase 0: Nền dự án

- [x] **Task 0.1: Repo và dọn file Horus**
  - **Allowed Files:** `.git/`, `.gitignore`, `.gitattributes`, `CLAUDE.md`, `reference/horus/*`, `reference/.gdignore`, `plans/.gdignore`, `tools/.gdignore`; di chuyển `AGENTS.md`, `CHANGELOG.md`, `GAME-GUIDE.md`, `HorusBuild.cmd`, `horus-build.mjs`, `horus-game.json`, `horus-logic.mjs`, `horus-sdk.d.ts`, `horus-sdk.js`, `horus-sdk.mjs`, `README.md`.
  - **Specs:** `git init -b main`. Task này được phép chạy `git mv` hoặc `mv`, không commit. Chỉ di chuyển, không sửa nội dung file Horus. **Thay** nội dung `.gitignore` hiện có (bỏ dòng `/android/`) bằng: `.godot/`, `build/`, `tools/bin/`, `*.apk`, `*.aab`, `*.keystore`, `android/plugins/**/build/`, `android/plugins/**/.gradle/`, `android/build/`, `android/config/platform_config.json`, `android/config/google-services.json`, `android_config.json`. `.gitattributes` và `.editorconfig` giữ nguyên. `addons/godot_ai/` đưa vào git, vì `project.godot` tham chiếu tới nó. `CLAUDE.md` ngắn: trỏ tới `design.md` và file plan này, nêu các lệnh mục 1.4, quy tắc MCP mục 1.12, nêu `reference/horus/` chỉ để tham khảo.
  - **Verification:** `git rev-parse --is-inside-work-tree && test -f reference/horus/horus-sdk.d.ts && test ! -f AGENTS.md && test -f design.md && test -f tools/sim.mjs && ! grep -q '^/android/' .gitignore`

- [x] **Task 0.2: Project Godot và test runner**
  - **Allowed Files:** `project.godot`, `icon.svg`, `tools/godot.sh`, `i18n/strings.csv`, `tests/run_all.gd`, `tests/t.gd`, `tests/test_smoke.gd`, `scenes/main.tscn`, `src/ui/main.gd`, `src/platform/platform.gd`, `src/game/game.gd`, `src/game/sfx.gd`.
  - **Specs:** Chạy khi editor đóng (mục 1.12). `tools/godot.sh` chạy Godot theo đường dẫn mục 1.1, truyền nguyên tham số, cho phép ghi đè bằng biến `GODOT`, có quyền thực thi. **Sửa** `project.godot` hiện có, không tạo mới: đổi `config/name` thành "Candy Away" (tên cũ "Tap Block Out"), `config/features` thành `("4.7", "GL Compatibility")`, `renderer/rendering_method` và `renderer/rendering_method.mobile` thành `gl_compatibility`; thêm 720×1280 portrait, handheld orientation portrait, autoload `Platform`, `Game`, `Sfx` theo thứ tự này sau `_mcp_game_helper`, main scene `scenes/main.tscn`, dịch `i18n/strings.en.translation` và `.vi.translation`, ETC2/ASTC bật. Giữ stretch như mục 1.11, autoload `_mcp_game_helper`, `editor_plugins/enabled`. `i18n/strings.csv` là stub một khoá (`keys,en,vi`) để import sinh ra hai file `.translation`; thiếu chúng thì mọi lệnh Godot in `ERROR: Failed loading resource`. Task 3.2 thay nội dung file này. Autoload là stub `extends Node`; `Platform` và `Game` không lỗi khi chưa có backend. Stub `Sfx` đã có sẵn các hàm rỗng `play`, `music`, `stop_music`, `pause_for_ad`, `resume_after_ad` để Task 4.1 gọi được khi Task 4.2 đang chạy song song. `main.gd` có `go` và `open_popup` như mục 1.11. `run_all.gd` như mục 1.4: lọc theo user arg, in tổng kết, `quit(0)` hoặc `quit(1)`, có timeout 120 giây mỗi file test, file test `load()` lỗi thì tính là không đạt.
  - **Verification:** `tools/godot.sh --headless --path . --import; ! tools/godot.sh --headless --path . --quit 2>&1 | grep -E "^ERROR|SCRIPT ERROR" && tools/godot.sh --headless --path . --quit && tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_smoke && grep -q '_mcp_game_helper' project.godot && grep -q 'rendering_method.mobile="gl_compatibility"' project.godot`

- [x] **Task 0.3: Môi trường xuất Android**
  - **Allowed Files:** `export_presets.cfg`, `tools/export_apk.sh`; ngoài repo: `~/.local/share/godot/export_templates/4.7.2.stable/`, `~/.local/share/godot/keystores/debug.keystore`, editor settings của Godot, JDK trong `~/.local/` nếu cần.
  - **Specs:** Chạy khi editor đóng (mục 1.12). Tải `https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz` (khoảng 1,3 GB), giải nén vào đúng thư mục templates. Đặt `export/android/java_sdk_path` thành `/usr/lib/jvm/java-21-openjdk-amd64`. Tạo debug keystore còn thiếu bằng `keytool -genkeypair` với alias `androiddebugkey`, mật khẩu `android`, RSA 2048, hạn 9999 ngày. Tạo preset `Android Demo` (custom feature `demo`, `use_gradle_build=false`, package tạm `com.tungcv2.tapblockout`, arm64-v8a và armeabi-v7a, portrait, quyền `permissions/vibrate=true` để rung chạy được, `exclude_filter` loại `tests/*`, `build/*` (output export và ảnh tham chiếu Figma), `addons/godot_ai/*` và các script editor plugin `export_plugin.gd`, `plugin.gd`) và `Android Release` (giống vậy nhưng không có feature `demo`). `tools/export_apk.sh <preset> <đường_dẫn>` tạo thư mục và export debug. Tài liệu Godot khuyến nghị JDK 17 còn máy có 21: thử trước, lỗi thì tải Temurin 17 vào `~/.local/jdk-17` không cần sudo và đặt `export/android/java_sdk_path`.
  - **Verification:** `test -f ~/.local/share/godot/keystores/debug.keystore && tools/export_apk.sh "Android Demo" build/stub.apk && ~/Android/Sdk/build-tools/37.0.0/aapt2 dump badging build/stub.apk | head -3 && ! python3 -m zipfile -l build/stub.apk | grep -q 'addons/godot_ai/'`

**Cổng Phase 0:** cổng mặc định, và `build/stub.apk` tồn tại. Orchestrator đóng editor trước Task 0.2, mở lại sau Task 0.3 (mục 1.12), rồi kiểm `editor_state` có session và tên project mới.

### Phase 1: Config và schema

- [x] **Task 1.1: Config**
  - **Allowed Files:** `src/config.gd`, `tests/test_config.gd`.
  - **Specs:** Đọc `design.md` mục 3–7. `extends RefCounted`, các `static var` dạng Dictionary để Remote Config ghi đè được: `ECON` (start_coins, win_coins, win_card_from_level=11, booster_price hint/move/smash, refill_coins, refill_lives, shop_video_coins, shop_video_max, rescue_prices=[1900,2200,2500,2800], rescue_moves=3, rescue_video_max=4, challenge_coins=100), `LIVES` (max, regen_sec, from_level=10), `ADS` (inter_from_run=4, inter_every=2, inter_cooldown=120, session_warmup=90, rewarded_grace=45, first_session_block_until_level=10), `UNLOCK` (mục "Mở khoá": daily_gift=14, hint=5, shop=5, move=12, smash=17, lives=10, starter=10, review=10, challenge=50, stone=14, ice=30, chain=40, layer=55, fog=70, pulse=90), `DAILY` (28 ô đúng bảng trong `design.md`, mỗi ô `{coins:int, items:{...}}`), `COSMETICS` (avatar_01–12, frame_01–12, xoay giá 50/75/100), `SKUS` (mọi SKU và `_sale` trong mục 7, có usd, consumable, nội dung), `OFFERS`, `NOTIF`, `CONTENT` (`demo_max_level=20`, `release_pregen_level=100`, `loop_start_level=51`, `slack_easy=5`, `slack_easy_until=3`, `slack_early=3`, `slack_early_until=13`, `slack_normal=4`, `slack_hard=3`, `think_clap_sec=8`, `build="v1"`, `support_email="support@horusvn.com"`, `ftue_steps=["open","first_tap","first_win","first_x2","first_booster","run_2","run_5","level_10"]`), `SALE_WEEKDAYS`. `static func is_demo() -> bool` trả `OS.has_feature("demo")`. `static func apply_remote(values: Dictionary) -> void` ghi đè theo khoá `<nhóm>_<khoá>`, giá trị là chuỗi, ép về đúng kiểu cũ, bỏ qua khoá lạ và giá trị hỏng.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_config` (test tổng quà 28 ô phải đúng 6.650 gold, 5 hint, 5 move, 4 smash; test `apply_remote`).

- [x] **Task 1.2: Save schema và kho lưu**
  - **Allowed Files:** `src/meta/save_schema.gd`, `src/meta/save_store.gd`, `src/meta/clock.gd`, `tests/test_save.gd`.
  - **Specs:** Schema đúng mục 1.8; `merge_defaults(s)` thêm khoá thiếu, không xoá khoá cũ, có `migrate`. `save_store.gd`: `_init(path: String, mirror: Callable)`; `load_state() -> Dictionary` (file hỏng thì thử `.bak`, rồi `backup_json` truyền vào, rồi mặc định); `queue(s)` gộp ghi, `flush()`, `save_now(s)` ghi file tạm rồi đổi tên, giữ `.bak`, gọi `mirror`. `further(a, b)`: bản `runs`, `play_ms` cao hơn. `merge_purchases(into, from)`: gộp `buys` theo token, cấp lại hàng thiếu qua Callable, giữ `no_ads` nếu một bên có. `clock.gd`: `day_number(now, tz_offset_sec) -> int` tính theo giờ máy, `weekday(now, tz_offset_sec)`, `local_tz_offset() -> int` là hàm duy nhất đọc hệ thống.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_save` (ghi đọc, file hỏng, mất file chính, gộp đơn không trùng token).

### Phase 2: Logic thuần

Các module chỉ phụ thuộc `src/config.gd` và `save_schema.gd`. Test tự tạo `s` bằng `SaveSchema.defaults()`.

- [x] **Task 2.1: Bàn cờ và solver**
  - **Allowed Files:** `src/core/level_data.gd`, `src/core/board_state.gd`, `src/core/solver.gd`, `tests/test_board.gd`, `tests/test_solver.gd`, `tests/fixtures/*.json`.
  - **Specs:** Làm đúng mục 1.6–1.7, gồm cả 6 cơ chế để Phase 9 không phải viết lại. Khối trượt cứng theo hướng màu tới khi rời hẳn bàn; bị chặn thì `distance` là số ô trượt được trước vật cản. Sương mù: hết ẩn khi có ô kề (4 hướng) trống. `level_data.gd`: `validate(d) -> Array[String]` kiểm khung, ô trùng, ô ngoài bàn, khoá bắt buộc, `chained_by` tồn tại, không có chu trình xích. `solver.gd`: `solve(level) -> {ok, min_taps, order}`. Vì cơ chế đơn điệu nên đi tham lam: ưu tiên khối thoát được, rồi lớp ngoài, cuối cùng dội vào cổng nhịp khoá (khối còn phủ chờ khối kề rời đi, từ 2026-11-09); số cú dội của một cạnh luôn là số lần qua cạnh đó (trừ 1 nếu cổng mở sẵn) nên thứ tự không đổi `min_taps`. `immediate_exit_exists(level)`. `compute_moves(level)` = `min_taps` + `slack_for(level)`; dư cố định theo bậc trong `design.md` mục 3 (L1–3, L4–13, level thường, HARD), không theo số khối. `Game` cộng lại dư lúc vào level từ `min_taps` trong file, nên Remote Config đổi `content_slack_*` có tác dụng cả với level ghi sẵn. Test đối chiếu solver với BFS vét cạn trên ít nhất 200 bàn ngẫu nhiên nhỏ (RNG có seed) và kiểm luật không có thế bí: mọi trạng thái đạt được đều còn lời giải khi đủ MOVES.
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
  - **Specs:** Đọc `design.md` mục 7. `is_sale(now, tz)` thứ Bảy và Chủ nhật; `catalog(now, tz)` trả gói đúng SKU thường hoặc `_sale`. `due(s, ctx) -> id`, với `ctx {now, day, level, runs, session_start, first_session, inter_today}` (không gọi `AdPacing`), cho `starter_pack` (qua L10 hoặc lượt 12, mở 48 giờ, một lần), `remove_ads` (sau interstitial thứ 3 trong ngày, 1 lần/ngày, 3 lần tổng), `rescue_pack` (thua 3 lần liền một level, mỗi 24 giờ, hiện trên màn thua; tắt từ 2026-11-10 bằng `enabled: false`, Shop ẩn thẻ, `Offers.enabled(id)`), `level_pack` (mốc đầu `first_level` L60 rồi mỗi 50 level, mở 72 giờ; trước 2026-11-10 là sau mỗi 50 level từ L50). Không trong 5 phút đầu phiên đầu, cách nhau ít nhất 3 lượt. `shown`, `bought`, `open_offers(s, now)`, `note_fail(s, level)`, `note_win(s, level)`.
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
  - **Specs:** Bảng trong `design.md` mục 4: đúng màu, số khối, HARD ở L8, 12, 16, 20, polyomino (từ Task 9.8 cỡ và hình bất kỳ), lưới 14×18 (`Config.BOARD_W`, `BOARD_H`), hình ở giữa bàn (đối xứng, vòng lồng nhau, hình vòm), không chép game gốc. Không dùng cơ chế mới. `moves` và `min_taps` do solver tính, không viết tay. `tools/validate_levels.gd` (chạy bằng `-s`) kiểm `validate`, solver, có khối thoát ngay, `moves` đúng công thức. Task này phụ thuộc đọc `src/core/*`, không sửa.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tools/validate_levels.gd && tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_levels_demo` (`tools/` có `.gdignore` chỉ chặn import; đã kiểm trên 4.7.2 là script trong đó vẫn chạy được bằng `-s`).

### Phase 4: Điều phối

- [x] **Task 4.1: Autoload Game**
  - **Allowed Files:** `src/game/game.gd`, `tests/test_game.gd`.
  - **Specs:** Làm đúng mục 1.10 trên nền các module Phase 1–3. Thứ tự `boot` theo `reference/horus/GAME-GUIDE.md` mục 4. Mọi rewarded: ghi `s.ad_pend`, `save_now`, dừng nhạc, hiện, chỉ thưởng khi `ok`, log `rv_offer`, `rv_start`, `rv_done`, `rv_cancel`, `rv_fail`; quảng cáo mất thì trao lại khi mở game. Mua hàng: cộng hàng, `save_now`, rồi `finish`; mỗi token một lần; `invalid` không thưởng. Log `boot` (`ms` từ lúc mở tới khi chơi được), `level_start`, `level_end`, `popup_a_show`, `popup_a_buy`, `popup_b_show`, `popup_b_use`, `daily_claim`, `cos_buy`, `offer_show`, `offer_buy`, `inter_show`, `shop_open`, `ad_reward_recovered` (trao lại quảng cáo mất), `ftue` (`step` theo `Config.CONTENT.ftue_steps`, mỗi bước một lần, ghi vào `s.meta.ftue`), và `earn`/`spend` mỗi lần đổi gold. Mọi sự kiện có tham số `build`. Restart từ L10 trừ mạng theo `design.md`. Hỗ trợ `Game.reset_for_test(path)`. Demo: sau L20 `current_level_data()` trả `{}`. Áp dụng `Config.apply_remote` lúc boot. Khi `Platform.paused`: dừng nhạc, `save_now`, lập lại lịch thông báo (`NotifPlan.plan` rồi `Platform.schedule`). Gọi `Platform.ask()` sau lượt thứ 2, một lần, ghi `s.notify.asked`. `set_setting("notif", false)` gọi `Platform.cancel_all()`. `challenge_view` và `start_challenge` tạm trả trạng thái khoá; Task 9.4 làm thật.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_game` (thắng cộng gold, thua L9 và L10, luồng A và B qua mock, x2, mua không giao hai lần, đóng video sớm không thưởng, quảng cáo mất).

- [x] **Task 4.2: Theme và Sfx**
  - **Allowed Files:** `src/ui/theme_kit.gd`, `src/game/sfx.gd`, `tests/test_sfx.gd`.
  - **Specs:** `theme_kit`: bảng màu mục 1.6, nền, cỡ chữ, `make_button(text, kind)`, `make_panel()`, popup vào ra bằng tween nhẹ, hình tạm vẽ bằng code khi chưa có asset. `icon(name) -> Texture2D` nạp `assets/ui/<name>.png`, thiếu thì trả placeholder, không lỗi. `Sfx`: `play(name)`, `pulse(name)` (chỉ rung theo `HAPTIC_MS`, không tiếng), `music(name)`, `stop_music()`, `pause_for_ad()`, `resume_after_ad()`, đọc cài đặt qua tham số, thiếu file thì im lặng. Tự viết bus `SFX` và `Music` bằng code. Rung qua `Platform.haptic` nhẹ.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_sfx`

### Phase 5: UI từng màn

Mỗi màn có `setup(args)` và signal `closed`, chạy được khi `Game` dùng mock. Test tạo scene trong SceneTree headless, bấm nút qua hàm hoặc tín hiệu `pressed`, kiểm trạng thái.

- [x] **Task 5.1: BoardView**
  - **Allowed Files:** `scenes/board_view.tscn`, `src/ui/board_view.gd`, `src/ui/board_fx.gd`, `src/ui/pudding.gd`, `src/ui/pudding.gdshader`, `tests/test_ui_board.gd`.
  - **Specs:** `setup(board: BoardState)`, signal `block_tapped(id)`, `animation_done`, `apply_result(result: Dictionary)`. Vẽ nền trơn, khung cổng gồm bốn thanh capsule theo màu và bốn ống góc (`src/ui/candy_frame.gd`, chiếm thêm 0,77 đơn vị khung mỗi bên và 0,61 đơn vị trên dưới, `frame_rect()` trả về trọn khung, `frame_unit()` là đơn vị khung), khối kẹo sọc bóng (thân bằng shader từ SDF trong `src/ui/pudding.gd`, bóng đổ ở lớp riêng dưới mọi khối, vệt bóng và phần phủ bằng code; concept theme trong `design.md` mục 8; khung cố định theo màn: `board_rect()` là `Config.BOARD_AREA` ở màn chuẩn `BOARD_SCREEN` nhân theo màn, chỉ co khi vùng chứa nhỏ hơn khung; cỡ ô là số nguyên, theo hình của level `content_box()` cộng một ô lề mỗi phía, tối đa 14×18 ô, vừa `board_rect()`, to nhất `BOARD_CELL_MAX`; hình ở giữa khung, `content_rect()`). Khối thoát lao nhanh dần tới thanh cùng màu (0,20–0,35 giây theo quãng đường, `SLIDE_MIN`–`SLIDE_TIME`), 0,3 giây cuối chậm dần về đúng tốc độ nghiền (`EXIT_BRAKE`; từ 4 ô trở xuống không đủ đường hãm thì đi đều ở tốc độ nghiền; khối cuối trên bàn không hãm) rồi trôi qua thanh và bị nghiền thành khối vuông kẹo nhỏ phun ra ngoài thanh (`src/ui/candy_shards.gd`, chi tiết ở `design.md` mục 8); bị chặn thì lao tới vật cản, nhún, văng vụn, bật về, rung nhẹ, không màn đỏ. Vùng chạm đúng ô của khối. `highlight(id)` cho Gợi ý, `smash_anim(id)` (khối vỡ thành mảnh kẹo, gọi lúc búa kẹo mút của `src/ui/smash_fx.gd` gõ), `strike_point(id)` (tâm ô của khối gần tâm khối nhất, nơi búa gõ). Cơ chế mới để Task 9.2.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_ui_board`

- [x] **Task 5.2: Home và Profile**
  - **Allowed Files:** `scenes/home.tscn`, `src/ui/home.gd`, `scenes/profile.tscn`, `src/ui/profile.gd`, `tests/test_ui_home.gd`, `tests/test_ui_profile.gd`.
  - **Specs:** Home (bố cục theo Figma "main menu", xem `docs/UI_FIGMA.md`): đường level ba mốc có số level, nút PLAY đổi màu theo độ khó, gold, mạng và đếm hồi, avatar và frame đang đeo (bấm mở Profile), icon quà có chấm đỏ, icon shop khoá tới L11 (trước 2026-11-10 là L5), Settings, icon Daily Challenge khoá ghi "Level 50", icon offer đang mở kèm thời gian còn. Demo xong L20 hiện "Sắp có level mới". Không tự mở popup quà. Profile: lưới 12 avatar, 12 frame và mặc định; chọn món đã có để đeo; món chưa có hiện giá và nút video.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_ui_home && tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_ui_profile`

- [x] **Task 5.3: Popup hết MOVES, thắng, thua, hết mạng**
  - **Allowed Files:** `scenes/popup_rescue.tscn`, `src/ui/popup_rescue.gd`, `scenes/win_card.tscn`, `src/ui/win_card.gd`, `scenes/lose_card.tscn`, `src/ui/lose_card.gd`, `scenes/no_lives.tscn`, `src/ui/no_lives.gd`, `tests/test_ui_rescue.gd`, `tests/test_ui_result.gd`.
  - **Specs:** `popup_rescue` nhận kết quả `RescueFlow.offer`, một popup duy nhất cho cả 4 lần. Hiện "Còn N khối", giá, nút Dùng khi có trong kho, nút video khi được, không đếm ngược; cảnh báo mất mạng nằm ở hộp xác nhận Bỏ cuộc do level dựng (Task 6.1), không ở popup. Thiếu gold: bấm mua trả `result="need_coins"` để level mở shop mini. Win card: +40, x2 (L1 miễn phí), tiếp tục. Lose card: chơi lại, về Home, `rescue_pack` nếu `Game` báo. No lives: đếm ngược, 900 gold, video, không có quảng cáo thì báo. Bổ sung ngày 2026-11-02 (theo `design.md` mục "Thẻ thắng và thẻ thua"): `Game.on_level_won` trả thêm `progress` và `unlocked` từ `Unlocks.feature_progress`; win card có thanh tiến trình tính năng (`FeatureProgress`, `FeatureLabel`, `FeaturePercent`); `Game.next_after_win(res, challenge)` chọn "home" hoặc "level"; `level.gd` chờ `CONTENT.win_delay_sec` trước thẻ thắng (bỏ qua khi headless; bỏ hẳn ngày 2026-11-08: thẻ hiện ngay khi khối cuối rời bàn, `level.gd` nạp nền thẻ bằng `ResourceLoader.load_threaded_request` từ lúc vào màn); `level_end` thêm `blocks_left`, `rescues`, `replay`.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_ui_rescue && tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_ui_result`

- [x] **Task 5.4: Shop và offer**
  - **Allowed Files:** `scenes/shop.tscn`, `src/ui/shop.gd`, `scenes/shop_mini.tscn`, `src/ui/shop_mini.gd`, `scenes/popup_offer.tscn`, `src/ui/popup_offer.gd`, `tests/test_ui_shop.gd`.
  - **Specs:** Shop đầy đủ (mở từ L11; trước 2026-11-10 là L5): gói gold theo `Game.shop_catalog()`, nhãn sale cuối tuần, video 200 gold còn N/5, gói khác, Remove Ads, Restore. Shop mini: chỉ gói gold, mở được ở mọi level khi người chơi bấm mua, đóng thì trả về popup. Popup offer dùng chung cho 4 offer.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_ui_shop`

- [x] **Task 5.5: Popup quà và Settings**
  - **Allowed Files:** `scenes/popup_daily.tscn`, `src/ui/popup_daily.gd`, `scenes/settings.tscn`, `src/ui/settings.gd`, `tests/test_ui_daily.gd`, `tests/test_ui_settings.gd`.
  - **Specs:** Popup quà chỉ mở khi bấm, hiện đúng 7 ô của tuần đang đi, nút nhận, nút video nhận ô kế tiếp (không tự chạy). Settings: âm thanh, nhạc, rung, thông báo, ngôn ngữ, Privacy khi `has_privacy`, Restore, Contact support (mở `mailto:` tới `Config.CONTENT.support_email`), phiên bản. Chạm 10 lần vào dòng phiên bản (hoặc phím F1 ở `main.gd`) mở menu tester (`scenes/tester_menu.tscn`) có nút mediation debugger (`Platform.open_debugger()`); bản debug thêm ô sửa gold, level, booster và nút xoá tài khoản (`Game.tester_edit`, `Game.tester_wipe`).
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_ui_daily && tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_ui_settings`

### Phase 6: Ráp màn level

- [x] **Task 6.1: Màn level và điều hướng**
  - **Allowed Files:** `scenes/level.tscn`, `src/ui/level.gd`, `src/ui/main.gd`, `scenes/main.tscn`, `tests/test_ui_level.gd`.
  - **Specs:** HUD: level, MOVES, HARD, nút restart có xác nhận từ L10, luôn 3 ô booster (chưa mở thì hiện khoá kèm level mở, chạm báo level mở; đã mở thì hiện tồn kho), chip đếm mảnh leaderboard ở thanh trên dưới chip lượt, hướng dẫn L1, tặng booster ở level mở kèm giới thiệu (từ 2026-11-08 là popup `booster_unlocked`, nút vàng ẩn, chạm đâu cũng đóng); level dạy cơ chế của level chính mở cùng popup đó với `view = {mech}` một lần (`Game.claim_mech_intro`, `Unlocks.pending_mech`, bản lưu `mech_seen`). Booster thiếu gold mời `booster_free`, không giới hạn số lần (từ 2026-11-08; `Game.booster_video(kind)`). Hết MOVES: chạy `RescueFlow`, hiện `popup_rescue`, `need_coins` mở `shop_mini` rồi quay lại popup. Bỏ cuộc: từ `from_level` hiện hộp xác nhận mất 1 mạng (huỷ thì quay lại popup, xác nhận thì `rescue_skip` rồi thẻ thua), dưới đó thua ngay. Thắng mở win card; rời win card gọi `Game.leave_win_card`. Thua mở lose card. Vỗ tay khi nghĩ từ `think_clap_sec`, kèm lời khen `PraiseFx` (`src/ui/praise_fx.gd`, từ 2026-11-08) đặt giữa hàng trên của HUD và khung (`level.gd` `praise_rect()`), không đè khung. Bổ sung 2026-11-04: không chạm màn hình `CONTENT.idle_hint_sec` (15) giây thì nhắc Gợi ý (`design.md` mục booster với cơ chế): nút Gợi ý lắc, node `%BoosterNudge_hint` (ảnh `booster_hint`) phủ lên bóng đèn, bong bóng `%IdleTip` ("Available Block : N", khoá `level_idle_blocks`) hiện `idle_hint_show_sec` (2) giây, chạm là tắt; test lùi `idle_start_ms`. Hết mạng chuyển `no_lives`. Hỏi đánh giá sau L18. `main.gd` gọi `Game.boot()`, nối đủ màn và nút Back.
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
  - **Specs:** `generate(id: int, seed: int) -> Dictionary` thuần, theo `RandomNumberGenerator` có seed: chọn hình trong `src/core/silhouette.gd`, lát hình thành khối (tự do hoặc đối xứng), dịch vào giữa lưới 14×18 (hình lớn nhất 12×17), bật cơ chế theo `Config.UNLOCK`, HARD mỗi 4 level, số khối tăng tới trần 30 (từ L14 xem Task 9.6; mọi level nhân `DifficultyCurve.COUNT_SCALE` = 2 từ 2026-11-03, `design.md` mục 4), qua `validate` và `solver`, sinh lại với seed kế tiếp nếu không đạt. Dùng cho Daily Challenge; level sau level cuối (`CONTENT.release_pregen_level`, nay 500) không sinh mà lặp lại nội dung từ `CONTENT.loop_start_level` (`src/core/level_loop.gd`, `Game.content_level`). Cùng `id` và `seed` phải ra cùng level.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_generator` (500 level hợp lệ, xác định, mỗi level dưới 200 ms trên máy dev).

- [x] **Task 9.2: Hiển thị cơ chế**
  - **Allowed Files:** `src/ui/board_view.gd`, `src/ui/board_fx.gd`, `scenes/board_view.tscn`, `tests/test_ui_mech.gd`.
  - **Specs:** Vẽ đá, băng và nứt, xích và chìa, hai lớp và bóc lớp, sương mù, cổng nhịp đóng mở. Âm thanh gọi `Sfx` theo bảng `design.md`, thiếu file thì im. Dùng `assets/ui/mech_*` nếu có, nếu không vẽ bằng code. Theme kẹo (2026-11-03): đá vẽ thành khối gỗ (2026-11-04 đổi thành thùng sắt bốn đinh tán), băng thành lớp pudding, hai lớp thành hộp giấy, xích quấn cả khối; hiệu ứng va chạm và mất vật cản theo chất liệu ở `src/ui/obstacle_fx.gd` (`design.md` mục 4 và 8). Tên trong dữ liệu và code giữ nguyên.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_ui_mech`

- [x] **Task 9.3: Sinh L21–100 và level dạy**
  - **Allowed Files:** `data/levels/level_0021.json` … `level_0100.json`, `tests/test_levels_all.gd`, `tools/gen_levels.gd`.
  - **Specs:** Chạy `tools/gen_levels.gd`. L1–20 giữ layout tay, trừ các level kín khung (`design.md` mục 4). Bản đầu sinh tới L100 (`CONTENT.release_pregen_level`), không làm L101–300 và không cần `index.json` (tải từng file đủ nhanh). Level dạy ban đầu làm tay ở 21, 31, 46, 61, 81, 101. Đã thay: Task 9.6 dời level dạy sang 14, 30, 40, 55, 70, 90 và để bộ sinh tạo; Task 9.12 nâng lên 500 level (`level_0001.json` … `level_0500.json`).
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_levels_all` (mọi level `1..TOTAL` qua validator và solver; `TOTAL` nay là 500).

- [x] **Task 9.4: Daily Challenge, vòng lặp sau level cuối, cơ chế trong game**
  - **Allowed Files:** `scenes/challenge.tscn`, `src/ui/challenge.gd`, `src/game/game.gd`, `src/core/level_loop.gd`, `src/ui/home.gd`, `src/ui/level.gd`, `tests/test_challenge.gd`, `tests/test_level_loop.gd`.
  - **Specs:** Daily Challenge từ L50 theo `design.md`: seed theo ngày, +100 gold lần thắng đầu trong ngày, x2 bằng video, thua mất mạng; bàn sinh trong game (`Game.challenge_data`), phải sinh thì có màn chờ ngắn (`challenge_needs_generation`). Sau level cuối (`CONTENT.release_pregen_level`, lúc làm task là L100, nay L500) không sinh level mới (2026-11-02, thay cho ý cũ "sau L300 gọi generator"): `s.level` là số hiển thị, tăng mãi; `Game.content_level` đọc file theo `LevelLoop.content_level(display, loop_start, last)`, lặp `[CONTENT.loop_start_level, release_pregen_level]` (mặc định 51–500); bản lưu cũ có `s.level` lớn hơn level cuối tự nhận nội dung vòng lặp, không migrate (`design.md` mục 4 "Phạm vi"). Preset demo vẫn dừng ở L20 và khoá nút. Level dạy cơ chế có hướng dẫn. Mở khoá các nút theo `Unlocks`. Từ 2026-11-08 tính năng tắt bằng công tắc `Config.FEATURES.challenge` = false (Remote Config `features_challenge`; `Unlocks.enabled`, `Game.challenge_view().enabled`): Home ẩn icon, thẻ thắng bỏ mốc L50; `design.md` mục 4 "Phạm vi".
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_challenge test_level_loop test_e2e`

- [x] **Task 9.5: Tài nguyên cơ chế**
  - **Allowed Files:** `art/images/mech_*`, `art/audio/sfx_*`, `art/manifest.mech.json`, `art/MISSING.mech.md`, `assets/ui/mech_*.png`, `assets/sfx/sfx_stone.wav`, `assets/sfx/sfx_ice.wav`, `assets/sfx/sfx_chain.wav`, `assets/sfx/sfx_layer.wav`, `assets/sfx/sfx_fog.wav`, `assets/sfx/sfx_gate.wav`.
  - **Specs:** Phần Task 7.1 và 7.2 đã bỏ: `mech_stone`, `mech_ice`, `mech_chain`, `mech_key`, `mech_fog` và 6 `sfx` cơ chế theo `design.md` mục "Tài nguyên". Cùng quy tắc prompt, seed, xử lý và phương án dự phòng như Phase 7, dùng lại `tools/resize_images.py`, `tools/process_audio.sh`. Không sửa `art/manifest.json`; Orchestrator gộp `art/manifest.mech.json` vào đó ở cổng Phase. Tổng `assets/` vẫn tối đa 10 MB.
  - **Verification:** `python3 -c "import json;m=json.load(open('art/manifest.mech.json'));print(len(m))" && du -sm assets | awk '{exit !($1<=10)}'` (hoặc `art/MISSING.mech.md` liệt kê phần thiếu).

- [x] **Task 9.6: Khó hơn từ L14, hình có chủ đích (2026-11-03)**
  - **Allowed Files:** `src/core/motifs.gd`, `src/core/level_generator.gd`, `src/core/difficulty_curve.gd`, `src/config.gd`, `tools/gen_levels.gd`, `data/levels/level_0014.json` … `level_0100.json`, `tests/test_motifs.gd`, `tests/test_generator.gd`, `tests/test_levels_all.gd`, `design.md`.
  - **Specs:** Từ `DifficultyCurve.SHAPED_FROM` (L14): số khối nhân `BOOST` 1,3 (trần 40), trọng số khối bị chặn lúc đầu mũ 2 (Hard 3). Hình lấy từ 21 bản vẽ tay trong `motifs.gd` (rộng chẵn, đối xứng), đá và cách cắt khối đối xứng theo trục, màu tự do. Level dạy cơ chế sinh to bằng bộ sinh, chỉ cơ chế mới, phải chạm thử được ngay (`_teach_ok`). L1–13 không đổi. Sinh lại bằng `tools/gen_levels.gd -- --from=1 --to=100 --seed=20261101 --early=1 --out=res://data/levels`.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_motifs test_generator test_levels_all`

- [x] **Task 9.7: Gấp đôi số khối mọi level (2026-11-03)**
  - **Allowed Files:** `src/core/difficulty_curve.gd`, `src/core/level_generator.gd`, `src/config.gd`, `tools/gen_levels.gd`, `data/levels/level_0001.json` … `level_0100.json`, `tests/test_motifs.gd`, `tests/test_levels_all.gd`, `tests/test_levels_demo.gd`, `design.md`.
  - **Specs:** `DifficultyCurve.block_count` nhân `COUNT_SCALE` = 2 ở bước cuối. Hình vẽ tay giữ cỡ, `MOTIF_FILL_MIN`, `MOTIF_FILL_MAX` giảm một nửa (1,15–1,8). Bảng EARLY làm lại với 4, 6, 8, 10 khối, giữ luật L1–4. `GATE_MAX_BLOCKS` 26 → 52; từ `GATE2_FROM` (L130, tới 2 cổng) trần `GATE2_MAX_BLOCKS` = 40 để mỗi level sinh dưới 200 ms. Sinh lại L1–100 bằng lệnh phát hành của Task 9.6.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tools/validate_levels.gd && tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_motifs test_generator test_levels_all test_levels_demo`

- [x] **Task 9.8: Không giới hạn hình dạng khối (2026-11-05)**
  - **Allowed Files:** `src/core/level_generator.gd`, `data/levels/level_0005.json` … `level_0100.json`, `tests/test_motifs.gd`, `tests/test_generator.gd`, `design.md`.
  - **Specs:** Bỏ `BLOCK_CAP` (trần 5 ô) ở `_tile` và `_tile_sym`; trọng số mỗi cách gộp là `_merge_weight(cỡ khối sau gộp)` = 1/cỡ. Khối vẫn phải liền 4 hướng (`LevelData.validate`). Số khối, `MOTIF_FILL_*`, cách cắt đối xứng giữ nguyên. Test: trong 300 level sinh (seed 0) có khối hơn 5 ô cả trước và từ `SHAPED_FROM`. Sinh lại L1–100 bằng lệnh phát hành của Task 9.6 (L1–4 không đổi).
  - **Verification:** `tools/godot.sh --headless --path . -s res://tools/validate_levels.gd && tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_motifs test_generator test_levels_all test_levels_demo`

- [x] **Task 9.9: Road Trip, Bảng xếp hạng thành icon ở Home (2026-11-05)**
  - **Allowed Files:** `tools/import_road_trip.gd`, `data/road_trip/rt_0001.json` … `rt_0400.json`, `src/meta/road_trip.gd`, `src/meta/save_schema.gd`, `src/meta/unlocks.gd`, `src/config.gd`, `src/game/game.gd`, `src/ui/road_trip.gd`, `src/ui/road_trip_map.gd`, `src/ui/popup_road_trip_win.gd`, `scenes/road_trip.tscn`, `scenes/popup_road_trip_win.tscn`, `src/ui/level.gd`, `src/ui/board_view.gd`, `src/ui/candy_frame.gd`, `src/ui/frame_bar.gdshader`, `src/core/level_data.gd`, `src/core/board_state.gd`, `src/ui/tester_menu.gd`, `src/ui/profile.gd`, `src/ui/hub_nav.gd`, `scenes/hub_nav.tscn`, `src/ui/home.gd`, `scenes/home.tscn`, `src/ui/main.gd`, `src/ui/leaderboard.gd`, `src/ui/shop.gd`, `src/ui/win_card.gd`, `src/ui/theme_kit.gd`, `i18n/strings.csv`, `tests/test_road_trip.gd`, `tests/test_unlocks.gd`, `tests/test_i18n.gd`, `tests/test_ui_motion.gd`, `tests/test_ui_stubs.gd`, `tests/test_ui_leaderboard.gd`, `design.md`, `docs/`.
  - **Specs:** `design.md` mục 7 "Road Trip". Nhập 400 level MoreColor bằng `tools/godot.sh --headless --path . -s res://tools/import_road_trip.gd -- <thư mục cfg>` (thư mục chứa `configs_base_tabledata` và `configs_morecolorlevels`). Thanh dưới Shop · Home · Road Trip; `HUB_SCREENS` = shop, home, road_trip. Màn Road Trip nhúng `scenes/level.tscn` với `setup({road_trip: true})` như Daily Challenge. Khung bàn nhận lưới cao hơn `BOARD_H`. Cổng màu: L1–200 2 cổng mỗi cạnh (8 màu), L201–400 3 cổng (12 màu); khối có `dir` riêng, khung chia đoạn màu theo `gates`. Interstitial `result_exit` khi đóng popup thắng (`Game.road_trip_leave_win`).
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_road_trip test_unlocks test_i18n test_ui_motion test_ui_stubs test_ui_leaderboard test_ui_level`

- [x] **Task 9.10: Khối to hơn, xếp có chủ đích (2026-11-08)**
  - **Allowed Files:** `src/core/level_generator.gd`, `src/core/motifs.gd`, `src/core/difficulty_curve.gd`, `src/core/solver.gd`, `src/core/board_state.gd` (thêm `inspect`), `src/config.gd`, `data/levels/level_0005.json` … `level_0100.json`, `tests/test_generator.gd`, `tests/test_motifs.gd`, `tests/test_levels_all.gd`, `design.md`, `docs/REF_GAME_DIFF.md`.
  - **Specs:** `design.md` mục 4. Từ L14 `block_count` nhân `SHAPED_COUNT_SCALE` = 1,5 (L1–13 vẫn `COUNT_SCALE` = 2). Từ `MOTIF_FROM` = 5 mọi level dùng hình vẽ tay (`_attempt_motif`); `MOTIF_FILL` 2,5–3,4. Bản vẽ: ký tự khác '.' là tên vùng (`Motifs.variants` trả `regions`), vùng đối xứng theo trục của hình, mỗi mảnh vùng ≥ 2 ô; 27 hình, mỗi số khối 12–59 có ≥ 12 hình vừa. `_tile_sym(..., style, regions)`: mỗi khối ≤ `Config.BLOCK_MAX_CELLS` (7); trọng số `TILE_SINGLE_BIAS` ^ số khối 1 ô / cỡ²; `cut_style(id)` theo id % 3: "sym", một kiểu trong `GEO_STYLES` (rows, rings, weave, cols, bricks; `_edge_ok`), "template" (cùng vùng); hết cách gộp hợp kiểu thì gộp tự do; một lần quét chọn tới 1/`TILE_BATCH` số lần gộp còn lại. `_stone_dead` đặt lại thùng sắt tối đa `STONE_TRIES` lần. Cổng nhịp đặt ở cạnh có ít lần qua nhất, mở hay khoá lúc đầu ngẫu nhiên (level dạy khoá), bàn phải có khối thoát được ngay (2026-11-08, thay `_fix_gates`/`_no_wait` của luật cũ "mọi lần chạm đều đảo cổng"). Level dạy xích xích khối thứ hai vào khối thứ nhất. Test: khối ≤ 7 ô, khối 1 ô ≤ 10% trên 300 level sinh, ≥ 90% khối đúng quy luật kiểu cắt, 500 level dưới 200 ms. Sinh lại L1–100 bằng lệnh phát hành của Task 9.6 (L1–4 không đổi).
  - **Verification:** `tools/godot.sh --headless --path . -s res://tools/validate_levels.gd && tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_motifs test_generator test_levels_all test_levels_demo test_challenge test_board test_solver`

- [x] **Task 9.11: Bake sẵn SDF thân khối (2026-11-08)**
  - **Allowed Files:** `src/ui/pudding.gd`, `src/ui/pudding_bank.gd`, `data/pudding_sdf.res`, `tools/bake_sdf.gd`, `src/ui/level.gd`, `src/ui/main.gd`, `tools/export_apk.sh`, `tools/export_release.sh`, `tests/test_pudding_bank.gd`, `design.md`.
  - **Specs:** `design.md` mục 8. `tools/bake_sdf.gd` dựng song song (WorkerThreadPool) SDF của mọi hình khối trong `data/levels` và `data/road_trip` cộng hình một ô, ghi `data/pudding_sdf.res` (`pudding_bank.gd`: mỗi hình một ảnh `FORMAT_RH` nén zstd riêng, kèm `Pudding.signature()`); không có `--force` thì giữ bank đã khớp chữ ký và bộ hình. Hai script export chạy tool này trước khi xuất. `Main._boot` gọi `Pudding.load_bank_async()`; `sdf_for` lấy theo thứ tự cache, job đang dựng, bank, dựng ngay; bank khác chữ ký thì bỏ qua. `Pudding.prewarm(shapes)` dựng hình ngoài bank trên WorkerThreadPool (ưu tiên cao); `Level._start_level` gọi cho mọi level, Daily Challenge đợi `is_warm()` sau dòng `common_loading`. Đổi `field()` thì tăng `FIELD_VERSION` rồi bake lại. Sinh lại level (Task 9.6, 9.10, 9.9) thì bake lại.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tools/bake_sdf.gd && tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_pudding_bank test_ui_candy test_ui_level test_challenge`

- [x] **Task 9.12: 500 level bám game tham khảo (2026-11-08)**
  - **Allowed Files:** `src/core/difficulty_curve.gd`, `src/core/level_generator.gd`, `src/core/solver.gd`, `src/config.gd`, `src/game/game.gd`, `tools/gen_levels.gd`, `data/levels/level_0001.json` … `level_0500.json`, `data/pudding_sdf.res`, `tests/test_levels_all.gd`, `tests/test_generator.gd`, `tests/test_levels_demo.gd`, `tests/test_motifs.gd`, `tests/test_level_loop.gd`, `tests/test_challenge.gd`, `tests/test_ui_level.gd`, `design.md`, `docs/HORUS_HANDOFF.md`, `docs/REF_GAME_DIFF.md`.
  - **Specs:** `design.md` mục 4. `DifficultyCurve`: `REF_BLOCKS`, `REF_WAVES` (500 số đo), `HARD`, `VERY_HARD` theo game tham khảo; `block_count` kẹp `MOTIF_MIN_BLOCKS`..`BLOCK_CAP` (12–60), `wave_count` giảm theo tỉ lệ khi bị kẹp, tối đa `WAVE_SHARE_MAX` lượt mỗi khối; tag là đỉnh (`PEAK_*`, `PEAK_SPAN`). `Solver.clear_rounds`. `LevelGenerator`: `_assign(..., aim)` lái độ sâu chuỗi (`DEPTH_PUSH`, `DEPTH_HOLD`, `DEPTH_FREE`), `_finish` gán lại tối đa `ASSIGN_TRIES` lần cho số lượt trong `_rounds_tol` (`Config.LEVEL_ROUNDS_TOL*`, nới mỗi `ROUNDS_RELAX_EVERY` lần thử), `ROUNDS_STALL`; `generate(id, seed, strict_rounds = true)`, `Game.generate_checked` dùng `false`. `mech_plan(id)`, `is_rest(id)`: tối đa `Config.LEVEL_MECH_MAX` cơ chế, level nghỉ `LEVEL_REST_*`, `LEVEL_MECH_WEIGHTS`, `LEVEL_MECH_FRESH`; cổng nhịp chỉ bàn tới `GATE_MAX_BLOCKS`. `Config.TILE_SINGLE_BIAS` 5 → 1,5. `CONTENT.release_pregen_level` 500, `very_hard_from_level` 501. Sinh bằng `tools/gen_levels.gd -- --from=1 --to=500 --seed=20261101 --early=1 --out=res://data/levels`, rồi `tools/bake_sdf.gd`.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tools/validate_levels.gd && tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_levels_all test_generator test_levels_demo test_motifs test_level_loop test_challenge test_pudding_bank test_ui_level`

Task 9.13–9.17 ghi lại phần đã làm từ 2026-11-02 tới 2026-11-08 mà lúc đó chưa có task (đối chiếu ngày 2026-11-09). Cả năm task sửa chung `src/game/game.gd`, `src/config.gd`, `i18n/strings.csv` nên chạy tuần tự.

- [x] **Task 9.13: Weekly Pass (2026-11-02, tutorial 2026-11-03)**
  - **Allowed Files:** `src/meta/weekly_pass.gd`, `src/meta/lives.gd` (`bonus`, `inf_until`, `max_for`, `grant_infinite`), `src/meta/save_schema.gd` (`weekly`, `lives.bonus`, `lives.inf_until`), `src/config.gd` (`WEEKLY`, SKU `weekly_pass`), `src/game/game.gd` (`weekly_*`, cộng key trong `on_level_won`, thưởng `inf_min` trong `_give`), `src/ui/weekly_pass.gd`, `scenes/weekly_pass.tscn`, `src/ui/weekly_pass_tutorial.gd`, `scenes/weekly_pass_tutorial.tscn`, `src/ui/popup_weekly_tutorial.gd`, `scenes/popup_weekly_tutorial.tscn`, `src/ui/reward_text.gd`, `src/ui/home.gd`, `scenes/home.tscn`, `src/ui/main.gd`, `i18n/strings.csv`, `tests/test_weekly_pass.gd`, `tests/test_lives.gd`, `tests/test_game_events.gd`, `tests/test_ui_events.gd`, `design.md`, `docs/HORUS_HANDOFF.md`.
  - **Specs:** `design.md` mục 7 "Weekly Pass", port từ pixelflow. `weekly_pass.gd` là logic thuần, giờ truyền vào (`now`, `tz`): chu kỳ thứ Hai 06:00 tới thứ Hai 00:00 tuần sau theo giờ máy (`window`, `cycle`), thứ Hai 00:00–06:00 là `WAITING`, config tắt hoặc SKU sai (`config_valid`) là `LOCKED`. Mở sau khi qua level HARD thứ `WEEKLY.unlock_hard_index` (2) (`Game.weekly_unlock_level`), nên bản demo không bao giờ mở. Thắng level chính khi `ACTIVE` cộng key theo `points_for` (Normal 1, Hard 3, VeryHard 5), không tính Daily Challenge và Road Trip, chỉ sau khi đã xem tutorial (`s.weekly.tut_seen`, không reset theo mùa). Main Tree: mốc 0 key và 10 mốc, mỗi mốc có thưởng free và VIP; Bonus Bank mở khi đủ mốc cuối, có VIP và đã xem End popup, cứ `bank_step` (15) key thừa thêm 1 mốc, tối đa `bank_max` (10), mỗi mốc `bank_reward_coins` (400). VIP: SKU `weekly_pass` ($4.99, consumable, mua lại mỗi tuần), +`vip_bonus_hearts` (3) mạng tối đa khi `ACTIVE` (`s.lives.bonus`, tăng thì cộng luôn vào số mạng, hết tuần thì kẹp lại). Sang mùa (`refresh`): chỉ VIP tự nhận thưởng chưa claim, rồi reset điểm, VIP, danh sách đã nhận; ghi `pending_end` để UI hiện popup cuối mùa một lần. Module không cộng hàng: trả `{coins, items, inf_min}`, `Game._give` cộng (`inf_min` thành `Lives.grant_infinite`). UI: nút ở Home có badge và chấm (`weekly_view`), layer `weekly_pass` (Main Tree, Bonus Bank, mua VIP), tutorial spotlight 3 bước lần đầu mở layer khi `ACTIVE` (đóng giữa chừng thì lần sau chạy lại), popup "How to earn rewards" mở sau tutorial hoặc bằng nút "i". Analytics `weekly_points`, `weekly_open`, `weekly_tutorial`, `weekly_claim`, `weekly_vip`, `weekly_end`.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_weekly_pass test_lives test_game_events test_ui_events`

- [x] **Task 9.14: Chain Offer và Special Pack (2026-11-02)**
  - **Allowed Files:** `src/meta/chain_offer.gd`, `src/meta/pack_conditions.gd`, `src/meta/offers.gd`, `src/meta/save_schema.gd` (`chain`), `src/config.gd` (`CHAIN`, `PACKS`, SKU `chain_pack_1`, `chain_pack_2`, `special_pack`, `special_pack_sale`), `src/game/game.gd` (`chain_*`, `_chain_check`, `special_pack_id`, `offer_sku`), `src/ui/chain_offer.gd`, `scenes/chain_offer.tscn`, `src/ui/popup_offer.gd`, `src/ui/reward_text.gd`, `src/ui/home.gd`, `scenes/home.tscn`, `src/ui/main.gd` (`_chain_autoshow`), `src/ui/shop.gd`, `i18n/strings.csv`, `tests/test_chain_offer.gd`, `tests/test_offers.gd`, `tests/test_game_events.gd`, `tests/test_ui_events.gd`, `design.md`, `docs/HORUS_HANDOFF.md`.
  - **Specs:** `design.md` mục 7 "Chain Offer", "Special Pack". Chain Offer (`chain_offer.gd`, logic thuần): hai chuỗi trong `CHAIN.sequences` xoay vòng, mỗi chuỗi 8 bước `free` / `ad` (placement `chain_offer`) / `pay` (SKU của bước; thưởng lấy từ chính gói qua `grant_purchase`, không cộng hai lần), layer hiện cửa sổ `CHAIN.window` (6) bước. Sau mỗi ván `Game._chain_check` bật chuỗi khi chưa có chuỗi, level từ `level_unlock` (100, từ 2026-11-09; trước là 150) và hết cooldown; `require_lose` -1 xét mọi ván, giá trị khác chỉ xét khi thua ở level không HARD. Sống `days_to_existence` (1) ngày, hết hạn thì nghỉ `days_to_reset` (3) ngày tính từ lúc hết hạn; làm hết bước không tắt chuỗi. Hết hạn trong lúc xem quảng cáo hay thanh toán thì vẫn trao phần đã xong. Layer tự mở đúng một lần mỗi chuỗi khi người chơi ở Home (`chain_take_autoshow`, `main._chain_autoshow`), sau đó mở bằng nút ở Home. Special Pack (`pack_conditions.gd`): `PACKS.special_pack` hiện icon ở Home từ `level_appear` (16), phải đã mua mọi gói trong `required` (`starter_pack`), `purchase_limit` 0 là không giới hạn; mỗi lần chỉ một gói (`first_visible`, theo thứ tự trong `PACKS`); mở bằng popup offer chung, lúc weekend sale `offer_sku` đổi sang `special_pack_sale`; gói `_sale` tính như gói gốc khi đếm số lần mua. Analytics `chain_start`, `chain_claim`, cùng `offer_show`, `offer_buy` của offer.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_chain_offer test_offers test_game_events test_ui_events`

- [x] **Task 9.15: Leaderboard theo league (2026-11-03, màn mới 2026-11-05)**
  - **Allowed Files:** `src/meta/leaderboard.gd`, `src/meta/save_schema.gd` (`lb`), `src/meta/unlocks.gd`, `src/config.gd` (`LEADERBOARD`, `UNLOCK.leaderboard`), `src/game/game.gd` (`lb_*`, khối crystal trong `start_attempt`, `piece` của `tap` và `smash_block`, `_lb_award` trong `on_level_won`), `src/ui/board_view.gd`, `src/ui/board_fx.gd`, `src/ui/pudding.gd`, `src/ui/crystal_fly.gd`, `src/ui/level.gd`, `scenes/level.tscn`, `src/ui/win_card.gd`, `src/ui/leaderboard.gd`, `scenes/leaderboard.tscn`, `src/ui/lb_kit.gd`, `src/ui/popup_lb_howto.gd`, `src/ui/popup_lb_player.gd`, `src/ui/popup_lb_result.gd`, `src/ui/popup_leagues.gd` và `.tscn` cùng tên, `src/ui/home.gd`, `scenes/home.tscn`, `src/ui/hub_nav.gd`, `src/ui/main.gd`, `src/ui/theme_kit.gd`, `assets/ui/lb_banner.png`, `assets/ui/lb_piece.png`, `i18n/strings.csv`, `tests/test_leaderboard.gd`, `tests/test_ui_leaderboard.gd`, `tests/test_unlocks.gd`, `tests/test_ui_stubs.gd`, `tests/shot.gd`, `design.md`, `docs/UI_FIGMA.md`.
  - **Specs:** `design.md` mục 7 "Leaderboard theo league". `leaderboard.gd` là logic thuần, mọi người khác trên BXH là bot sinh trong máy theo seed (game offline). Mở từ `UNLOCK.leaderboard` (L70 từ 2026-11-10, trước là L8 và có cả bản demo). Điểm: từ mốc mở mỗi level chính có `pieces_*` khối crystal (Normal 1, Hard 2, Very Hard 3, `Leaderboard.pick_specials` theo số level nên chơi lại cùng khối), Daily Challenge và Road Trip không có; khối crystal rời bàn (thoát hoặc Smash) cho 1 mảnh, icon bay về chip đếm ở thanh trên (`crystal_fly.gd`), mảnh cộng thành điểm khi thắng, thua thì mất. 7 league chỉ lên không xuống, thưởng một lần khi vào league (Silver nhận lúc mở màn lần đầu, các league sau ở popup Lên giải sau thẻ thắng, đóng bằng X vẫn nhận). BXH 100 người (người chơi và 99 bot), điểm bot chia dải theo vị trí, bot tăng điểm mỗi ngày lúc `grow_hour` theo `grow_tz_hours`, bù tối đa `grow_max_days` ngày, đồng hồ lùi thì không tăng; bot chạm league kế thì rời BXH, giữ tối đa `carry_max` bot vừa lên hạng cho BXH mới. Top % và World Ranking mô phỏng theo cột người chơi mô phỏng. UI (2026-11-05): icon cúp ở cột trái Home (khoá tới `UNLOCK.leaderboard`), không còn là tab thanh dưới; màn `leaderboard` có banner, tab League (khung thưởng thăng hạng, podium, tối đa `view_size` hàng quanh người chơi, hàng của mình ghim khi cuộn, ▲/▼ so với lần mở trước qua `lb_opened`) và tab World (thẻ người chơi, thang 7 giải). Analytics `lb_join`, `lb_points`, `lb_promote`, `lb_claim`, `lb_open`. Từ 2026-11-09 thay bởi Task 9.20 (popup, tuần).
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_leaderboard test_ui_leaderboard test_unlocks test_ui_stubs`

- [x] **Task 9.16: Biệt danh (2026-11-05)**
  - **Allowed Files:** `src/meta/nickname.gd`, `src/meta/name_filter.gd`, `src/meta/save_schema.gd` (`profile`), `src/config.gd` (`NAME_MIN`, `NAME_MAX`), `src/game/game.gd` (`profile_name`, `set_profile_name`), `src/ui/profile.gd`, `scenes/profile.tscn`, `src/ui/popup_change_name.gd`, `scenes/popup_change_name.tscn`, `i18n/strings.csv` (`profile_name_*`), `tests/test_nickname.gd`, `tests/test_ui_change_name.gd`, `tests/test_ui_profile.gd`, `design.md`.
  - **Specs:** `design.md` mục 5 "Biệt danh". `nickname.gd` chỉ đọc và ghi `s.profile`: `check(raw)` bỏ khoảng trắng hai đầu, dài `NAME_MIN`–`NAME_MAX` (3–14) ký tự, chỉ chữ cái tiếng Anh, số, `_`, `.`, `-`, có ít nhất một chữ hoặc số, không chứa từ cấm; trả `""` hoặc `ERR_LENGTH`, `ERR_CHARS`, `ERR_BANNED`; `change(s, raw)` lưu bản đã bỏ khoảng trắng. `name_filter.gd` (`is_banned`): từ cấm của 14 ngôn ngữ viết bằng chữ Latin không dấu cùng tên dành riêng (admin, support, Horus, Candy Away...), không phân biệt hoa thường, bắt chữ kéo dài, chữ chen `_ . -`, số thay chữ; từ ngắn dễ nằm trong từ thường chỉ cấm khi đứng riêng. Profile: ô tên có nút bút chì mở `popup_change_name`. Bản lưu chưa có tên nhận mã mặc định `CD_` + 6 chữ số (`Nickname.make_default(rng)`, `ensure(s, rng)`; `Config.NAME_CODE`, `NAME_CODE_DIGITS`), sinh trong `Game.profile_name()` và lúc boot; `profile_name_default` chỉ còn cho bản cloud cũ chưa có tên trong popup chọn bản lưu. Tên sai luật hay có từ cấm thì popup giữ nguyên và báo nhanh (`profile_name_invalid`, `profile_name_banned`). Miễn phí, đổi bao nhiêu lần cũng được, không kiểm trùng tên. Tên chỉ hiện ở Profile; hàng của người chơi trên BXH vẫn ghi "Bạn". Chữ ngoài bộ font subset dùng font hệ thống (mục 1.3).
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_nickname test_ui_change_name test_ui_profile`

- [x] **Task 9.17: Màn loading khi mở game (2026-11-03, nối boot splash và vào thẳng level 2026-11-08)**
  - **Allowed Files:** `scenes/splash.tscn`, `src/ui/splash.gd`, `src/ui/main.gd` (`_boot`, `boot_to_level`), `src/config.gd` (`CONTENT.splash_min_sec`, `splash_hold`, `splash_fill_sec`), `project.godot` (`application/boot_splash/*`, `window/size/window_*_override`), `assets/ui/loading_bg.png`, `assets/ui/loading_logo.png`, `assets/ui/boot_splash.png`, `i18n/strings.csv` (`boot_loading`), `tests/test_splash_art.gd`, `tests/test_shipped_assets.gd`, `tests/test_ui_stubs.gd`, `tests/test_ui_level.gd`, `design.md`, `docs/UI_FIGMA.md`, `docs/UI_UNITY.md`.
  - **Specs:** `design.md` mục 2. Chạy khi editor đóng vì sửa `project.godot` (mục 1.12). `main._boot` mở màn `splash` (layout `DownloadDataLayer` của Unity, ảnh thay bằng `loading_bg.png` phủ kín màn và `loading_logo.png`; icon trên thanh là kẹo bạc hà `candy_drop_00`; dòng phiên bản lấy `application/config/version`, rỗng thì ẩn), chạy thanh tới `splash_hold` (0,9) trong ít nhất `splash_min_sec` (1,5) giây, đứng đó nếu `Game.boot()` chưa xong, rồi đầy trong `splash_fill_sec` (0,3) giây. Trong lúc đó nạp bank SDF ở luồng nền (`Pudding.load_bank_async`, Task 9.11). Màn loading không phát nhạc. Xong thì vào thẳng level đang tới, không màn chuyển cảnh (`boot_to_level`: còn mạng như nút Chơi ở Home và `level_exists`), không thì Home; popup tự mở ở Home (Chain Offer) chờ tới khi người chơi về Home. Boot splash của Godot dùng cùng ảnh (PNG, quy tắc ở mục 1.3); màn loading vẽ logo đúng chỗ boot splash vẽ (`Splash.LOGO_RECT`, `boot_rect`) để nối liền, không nhảy ảnh.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_splash_art test_shipped_assets test_ui_stubs test_ui_level`

Task 9.18–9.19 ghi lại phần nối logic các màn wireframe ngày 2026-11-09 (`design.md` mục 9, `docs/UI_FIGMA.md` bảng "Trạng thái"). Chạy tuần tự sau 9.17 vì cùng sửa `game.gd`, `main.gd`, `level.gd`, `home.gd`, `config.gd`, `i18n/strings.csv`.

- [x] **Task 9.18: Win Streak (2026-11-09)**
  - **Allowed Files:** `src/meta/win_streak.gd`, `src/meta/save_schema.gd` (`streak`), `src/meta/unlocks.gd`, `src/config.gd` (`WIN_STREAK`, `UNLOCK.win_streak`), `src/game/game.gd` (`streak_*`, `leave_attempt`, `streak_up` của `on_level_won`), scene và script cùng tên của `popup_streak_intro`, `streak_main`, `popup_streak_rewards`, `popup_streak_end`, `popup_streak_keep`, `src/ui/popup_notice.gd`, `src/ui/popup_reward.gd`, `src/ui/home.gd`, `scenes/home.tscn`, `src/ui/level.gd`, `src/ui/main.gd` (`_open_streak`), `i18n/strings.csv`, `tests/test_win_streak.gd`, `tests/test_ui_streak.gd`, `design.md`, `docs/UI_FIGMA.md`.
  - **Specs:** `design.md` mục 7 "Win Streak", theo `ME_WinStreak` của color-cube-match-puzzle. `win_streak.gd` là logic thuần, giờ truyền vào (`now`, `tz`), giờ máy như Weekly Pass. Mở từ `UNLOCK.win_streak` (L45 từ 2026-11-10, trước là L40), icon ở cột trái Home. Lượt theo tuần: ngày trong `WIN_STREAK.active_days` (thứ Sáu, Bảy, Chủ nhật) là Active, lượt bắt đầu ở ngày Active đầu tiên người chơi mở game, các ngày khác chỉ nhận quà; lượt mới xoá chuỗi và mốc đã nhận, quà chưa nhận mất (`validate`). Chuỗi chỉ đếm sau khi bấm Start và chỉ trong ngày Active: thắng level chính +1 (Daily Challenge, Road Trip không tính); thua hoặc bỏ ván đã chạm (`Game.leave_attempt`) thì tụt về mốc đã đạt gần nhất, rồi hiện "Bạn đã mất chuỗi thắng" (`popup_notice`, `streak_take_lost`). Mốc và thưởng trong `WIN_STREAK.milestones` (gold, booster, phút mạng vô hạn `inf_min`), nhận thủ công từng mốc (`streak_claim`) rồi hiện `popup_reward`. Icon Home mở theo `streak_entry()`: Giới thiệu 9.1, Main 9.2, End 9.4; Giới thiệu tự mở một lần mỗi lượt (`streak_take_auto_intro`); Start mở luật 9.3 rồi Main. Bỏ ván khi chuỗi sẽ tụt (`streak_at_stake`) dùng `popup_streak_keep` (9.5) thay `popup_keep_playing`.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_win_streak test_ui_streak test_ui_level test_ui_stubs`

- [x] **Task 9.19: Nối logic các màn wireframe còn lại, gói No Ads, Helper Packs, Bundles (2026-11-09)**
  - **Allowed Files:** `src/meta/app_version.gd`, `src/meta/save_schema.gd` (`meta.intro_seen`, `weekly.upsell`), `src/config.gd` (SKU `remove_ads_bundle`, `helper_great`, `helper_epic`, `bundle_sweet`, `bundle_tasty`, `bundle_yummy`; `ECON.helper_pack_sku`; `CONTENT.latest_version`, `min_version`, `store_url`, `net_check_url`, `net_check_sec`), `src/game/game.gd` (signal `ad_wait`, `notice`, `cloud_conflict`; `update_state`, `mark_update_asked`, `open_store`, `cloud_conflict_view`, `resolve_cloud`, `online`, `notice_shown`, `take_intro`, `helper_pack_due`, `rate_now`, `weekly_take_upsell`), `src/ui/main.gd`, `src/ui/home.gd`, `scenes/home.tscn`, `src/ui/level.gd`, `src/ui/shop.gd`, `src/ui/settings.gd`, scene và script cùng tên của `popup_update`, `select_account`, `tutorial_intro`, `popup_no_internet`, `popup_remove_ads`, `load_transition`, `booster_soon`, `popup_free_pick`, `popup_rate`, `popup_keep_playing`, `popup_helper_pack`, `popup_weekly_upsell`, `popup_language`, `popup_help`, `ad_loading`, `popup_notice`, `popup_reward`; `src/ui/stub_ui.gd`, `src/ui/ui_gallery.gd`, `src/ui/sample_data.gd`; xoá scene và script `download_data`, `popup_bonus`, `popup_mechanic`, `speedup_tutorial`; `i18n/strings.csv`, `tests/test_ui_wired.gd`, `tests/test_cloud.gd`, `tests/test_ui_shop.gd`, `tests/test_ui_stubs.gd`, `tests/test_ui_level.gd`, `tests/test_ui_settings.gd`, `design.md`, `docs/UI_FIGMA.md`, `docs/HORUS_HANDOFF.md`.
  - **Specs:** Theo cách "Nối logic cho một màn" trong `docs/UI_FIGMA.md`: `view` thật từ `Game` thay dữ liệu mẫu, nút làm hành động thật, bỏ điều kiện `Config.ui_preview` ở lối vào; script vẫn có thể `extends stub_ui.gd` để dùng chung phần dựng. Từng màn:
    - **Khởi động:**
      - 1.2 `popup_update`: so `CONTENT.latest_version`, `min_version` (Remote Config) bằng `AppVersion`; bản bắt buộc thì ẩn Để sau và X, Back không đóng.
      - 1.4 `select_account`: bản cloud là lịch sử chơi khác thì phát `cloud_conflict`; chọn "Máy này" hoặc "Google Play", gộp đơn mua của bản kia (`resolve_cloud`).
      - 1.5 `tutorial_intro`: hiện một lần trước lần chơi đầu của L1 (`take_intro`, `s.meta.intro_seen`).
    - **Video và mạng:** rewarded chưa sẵn sàng thì chờ tối đa `ADS.rv_wait_sec`, có lớp `ad_loading` (11.1). Hết giờ thì kiểm mạng (`online`): mất mạng hiện `popup_no_internet` (1.6), còn mạng hiện `popup_notice` (11.2). Mua hàng lỗi cũng kiểm mạng. `popup_reward` (11.3, 6.3) hiện sau khi nhận mốc Win Streak, nhận bước Chain Offer hoặc mua gói.
    - **Mua hàng:**
      - 2.4 `popup_remove_ads`: mở từ icon ở cột phải Home và offer `remove_ads`; thẻ `remove_ads_bundle` và `remove_ads`, có Restore. Shop có mục No Ads, ẩn khi đã có `no_ads`.
      - Shop có Helper Packs (`helper_great`); `helper_epic` và Bundles (`bundle_*`) ẩn khỏi Shop (người dùng chọn, 2026-11-09), SKU vẫn trong `Config.SKUS`. Từ 2026-11-10 `helper_great` chỉ bán ở popup hết MOVES (mục Helper Packs không hiện); gói mua một lần (`consumable: false`, `Game.owns_once`) đã sở hữu thì ẩn thẻ.
      - 7.5 `popup_weekly_upsell`: một lần mỗi mùa trên Home khi chưa VIP.
    - **Trong level:**
      - 3.1 `load_transition`: khi sang level kế hoặc chơi lại.
      - 3.7 `booster_soon`: khi chạm booster còn khoá.
      - 3.9 `popup_free_pick`: bỏ (người dùng yêu cầu, 2026-11-10), xoá scene và script; quà booster chỉ còn scene `booster_unlocked`.
      - 4.3 `popup_rate`: một lần, sau thẻ thắng ở level mở Rate us (`rate_now`).
      - 4.6 `popup_keep_playing`: thay hộp thoại xác nhận bỏ ván mất mạng.
      - 4.7 `popup_helper_pack`: ở lần cứu đầu khi hết MOVES lần thứ 3 liên tiếp ở level và kho hết +3 Move (`helper_pack_due`), bán `ECON.helper_pack_sku`.
    - **Settings:** mở `popup_language` (10.4) và `popup_help` (10.5); Gửi mở mail tới `CONTENT.support_email`.
    - **Bỏ:** 1.3, 3.3, 3.11, 4.2.
    - **Còn chỉ UI:** 5.2, 5.3. Mục Hearts (gói mạng) của Shop tắt ở mọi bản build, kể cả debug (`shop.gd` `SHOW_HEARTS`, 2026-11-10). `popup_ads_daily` (2.3) chỉ còn trong danh sách xem trước; ADS Daily thật nằm trong Shop.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_ui_wired test_cloud test_ui_shop test_ui_stubs test_ui_level test_ui_settings test_e2e`

- [x] **Task 9.20: Leaderboard thành popup, điểm theo tuần (2026-11-09)**
  - **Allowed Files:** `src/meta/leaderboard.gd`, `src/meta/save_schema.gd` (`lb`), `src/config.gd` (`LEADERBOARD`), `src/game/game.gd` (`lb_*`), `src/ui/leaderboard.gd`, `scenes/leaderboard.tscn`, `src/ui/popup_lb_result.gd`, `src/ui/lb_kit.gd` (`fmt_week`), `src/ui/home.gd`, `scenes/home.tscn` (`LeaderboardDot`), `src/ui/main.gd`, `i18n/strings.csv`, `assets/ui/lb_banner.png` (xoá), `art/manifest.json`, `tests/test_leaderboard.gd`, `tests/test_ui_leaderboard.gd`, `tests/shot.gd`, `design.md`.
  - **Specs:** `design.md` mục 7 "Leaderboard theo league", phần "Tuần" và "UI". Popup qua `main._popup_then` (khung PopupOkLayer dựng không reveal, canvas LeaderboardLayer đặt vào lòng khung, `BG/Image` ẩn), X, Back, nền tối đóng; nút "i" đối xứng với X. PromoBox: bản sao `RankBadge` (chạm thì bong bóng là bản sao `RewardsParent`, dùng chung cho thang World), tên giải, đồng hồ tới hết tuần (`LbKit.fmt_week`). Tuần trong `leaderboard.gd`: `join` đặt `t0`, `ensure_week` cho bản lưu cũ, `roll` (bù bot tới hết tuần, ghi `result`, reset), `claim_result`, `seconds_to_week_end` theo `clock`. `popup_lb_result` nhận `{week}` cho kết quả tuần. Analytics thêm `lb_week_end`; `lb_join` mỗi tuần một lần.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_leaderboard test_ui_leaderboard test_unlocks test_ui_stubs`

- [x] **Task 9.21: Road Trip khó hơn 10%, bỏ ghi nguồn (2026-11-09)**
  - **Allowed Files:** `tools/import_road_trip.gd`, `data/road_trip/rt_0001.json` … `rt_0400.json`, `tests/test_road_trip.gd`, `src/config.gd` (comment `ROAD_TRIP`), `design.md`.
  - **Specs:** `design.md` mục 7 "Road Trip", phần "Làm khó". `import_road_trip.gd`: `convert_level` chia cổng, `color_blocks` tô màu theo cổng, `harden_all` đổi hướng khối rồi tô lại; mỗi level tất định theo id (`harden`: lật khối đang thoát được không tạo vòng chặn, thiếu thì dựng lại từ ngoài vào `_peel` + `_climb`, cuối cùng `_cleanup` trả khối thừa về hướng cũ; trước hết cấm sang cạnh vắt hai cổng, thiếu mức mới bỏ luật này). Không ghi khoá `source`. Đã chạy một lần trên 400 file có sẵn (thư mục cấu hình gốc không có trên máy này), cùng hàm, giữ nguyên định dạng file.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_road_trip test_pudding_bank`

- [ ] **Task 9.22: Pudding bóc theo khối kề, thêm băng (2026-11-09; còn bước sinh lại level)**
  - **Allowed Files:** `src/core/board_state.gd`, `src/core/solver.gd`, `src/core/level_data.gd`, `src/core/level_generator.gd`, `src/config.gd` (`UNLOCK.frost`, `COVER_*`), `src/meta/unlocks.gd`, `src/game/game.gd` (`tap`), `src/game/sfx.gd` (`volume_db`), `src/ui/level.gd`, `src/ui/board_view.gd`, `src/ui/board_fx.gd`, `src/ui/obstacle_fx.gd`, `src/ui/pudding.gd`, `src/ui/pudding.gdshader`, `tools/gen_levels.gd`, `i18n/strings.csv` và `.translation`, `assets/ui/mech_frost.png`, `assets/sfx/sfx_pudding.wav`, `art/`, `tests/fixtures/mechanics.json`, test của các file trên, `design.md`.
  - **Specs:** `design.md` mục 4 "Cơ chế sau bản demo" (dòng Pudding, Băng), "Hình dạng level"; mục 8 hiệu ứng. Board: kind `covered` thay `crack`; `_remove` bóc 1 lớp mỗi khối kề và trả `stripped`; `strip`, `cover_kind`. Solver bỏ `crack` khỏi `RANK`. Bộ sinh: `MECHS` thêm `frost`, `mech_plan` không giữ cả `ice` lẫn `frost`, `_mechanics` nhận `groups` (số lớp theo `COVER_*`, khối 2 lớp kề ít nhất 2 khối, không chung khối với sương), `_unstick` thay `_fog_fix` (gỡ cả sương lẫn lớp phủ), `_teach_ok` cho `ice`/`frost`, `_build` ghi `cover`. View: `_cover_hold` giữ lớp trên hình tới khi khối kề chạm thanh (`_grind` gọi `_release_covers`), `cover_held(id)` để `level.gd` coi chạm sớm là `covered`; `_cover_burst` theo chất liệu và số lớp; shader thêm `jelly_thick`, `ice_mat`.
  - **Còn lại:** sinh lại 500 level (`tools/gen_levels.gd`) và bake lại `data/pudding_sdf.res` khi người dùng báo đã thêm xong các cơ chế khác. Tới lúc đó `test_levels_all` báo lỗi ở các level đóng gói có pudding, `cover` và các level dạy theo mốc 2026-11-10 (Xích L45, Hộp giấy L65, Sương mù L85, Cổng nhịp L115, Băng L165, Socola L300, Ruy băng L350; level đóng gói còn theo mốc cũ).
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_board test_solver test_generator test_unlocks test_challenge test_i18n test_ui_mech test_ui_board test_ui_candy`

- [x] **Task 9.23: Màn đặc biệt (Special Bomb) (2026-11-09)**
  - **Allowed Files:** `src/core/special_board.gd` (mới), `src/meta/special_bomb.gd` (mới), `src/meta/save_schema.gd` (`special`), `src/meta/unlocks.gd` (`HOME_FEATURES`), `src/config.gd` (`SPECIAL`, `UNLOCK.special_bomb`), `src/game/game.gd` (`special_*`, `_begin_attempt`, `_finish_attempt`, `on_level_won`, `_end_lost`, `_notif_candidates`), `src/ui/special_bombs.gd` (mới), `src/ui/popup_special.gd` + `scenes/popup_special.tscn` (mới), `src/ui/popup_special_end.gd` + `scenes/popup_special_end.tscn` (mới), `src/ui/bomb_curtain.gd` (mới), `src/ui/candy_curtain.gd` (`custom_tex`), `src/ui/level.gd`, `src/ui/main.gd`, `src/ui/home.gd`, `scenes/home.tscn` (`BombItem`), `src/ui/win_card.gd` (ô "+N vé"), `src/ui/booster_unlocked.gd` (`special`), `src/ui/popup_ingame_settings.gd` (`no_retry`), `tools/gen_special.gd` (mới), `tools/bake_sdf.gd` (`DIRS`), `data/special/sp_0001.json` … `sp_0100.json`, `data/pudding_sdf.res`, `assets/ui/special_bomb.png`, `assets/sfx/sfx_bomb_*.wav`, `art/`, `i18n/strings.csv` và `.translation`, font subset, `tests/test_special.gd`, `tests/test_ui_special.gd`, `tests/test_unlocks.gd`, `design.md`, `CLAUDE.md`.
  - **Specs:** `design.md` mục 7 "Màn đặc biệt", mục 3 "Tiêu chí thư giãn" (ngoại lệ). Bàn: `SpecialBoard.generate(index, seed)` lát kín hình chữ nhật `rect_w_*` x `rect_h_*` bằng `LevelGenerator._tile` / `_assign` (không sửa `level_generator.gd`), file có `special`, `rect`, `rounds`; sinh bằng `tools/gen_special.gd -- --to=100 --seed=20261109 --out=res://data/special`, rồi `tools/bake_sdf.gd`. Bom: `bomb_count(wins)`, `bomb_plan(level, count, seed)` (tầng độ sâu, giây cộng dồn `bomb_seconds` = 0,8 × (19 + số khối phải chạm), làm tròn lên), `urgent_hint(board, bombs)`. Vé: `SpecialBomb` (ngăn chờ `slot_at`, ngăn thưởng `bonus`, `consume` ngăn chờ trước, `normalize` khi giờ lùi). UI: `level.gd` chế độ `special` (bom là con của `BoardView.block_node`, `_tick_bombs` chỉ khi đang chơi, không popup của màn hay Main, không búa / sao Gợi ý bay, app không ở nền; hết bước thua ngay; Restart thành Rời màn; xong thì đổi tại chỗ sang level chính kế), mời sau thẻ thắng Hard / VeryHard, `main._open_special` (Home, màn mưa bom `BombCurtain`), icon `BombItem` cột trái Home.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_special test_ui_special test_unlocks test_i18n test_pudding_bank test_save`
  - **Kính vỡ khi nổ (2026-11-10):** `src/ui/glass_crack.gd`, `src/ui/glass_shard.gdshader` (mới), `special_bombs.gd` (`explode`), `level.gd` (`_start_level` gỡ kính còn sót), `tests/test_ui_glass_crack.gd` (mới), `tests/test_ui_special.gd`, `design.md`. Verification thêm `test_ui_glass_crack`.

- [x] **Task 9.24: Avatar, frame ở thưởng league (2026-11-10)**
  - **Allowed Files:** `src/config.gd` (`LEADERBOARD.cosmetics`, `reward.cos_random`), `src/meta/leaderboard.gd`, `src/meta/save_schema.gd` (`lb.pending_cos`), `src/meta/cosmetics.gd` (`league_only`, `for_sale`), `src/game/game.gd` (`_give` cấp `cos`, `lb_leagues_view`, `lb_claim`, `lb_week_claim`), `src/ui/lb_kit.gd` (`reward_entries`, `set_entry_icon`), `src/ui/reward_text.gd`, `src/ui/popup_lb_result.gd` (`_fit_rewards`), `src/ui/profile.gd` (`_league_parts`), `src/ui/main.gd` (Profile → `ranking`), `i18n/strings.csv` và `.translation`, `tests/test_leaderboard.gd`, `tests/test_ui_leaderboard.gd`, `tests/test_ui_profile.gd`, `tests/test_cosmetics.gd`, `design.md`.
  - **Specs:** `design.md` mục 7 "Leaderboard theo league" (bảng League, "Avatar/khung ngẫu nhiên"), mục 5 "Avatar và frame". `Leaderboard.reward_of` thêm `cos_random`; `_roll_cos` chọn lúc vào league (`join`, `add_points`) trong `cos_left` (chưa có, không nằm trong `pending_cos` hay `result.reward.cos`) theo seed BXH, tuần, league; `pending_reward`, `claim`, `roll`, `claim_result` mang `cos: [id]`; `preview_reward` kẹp `cos_random` theo số món còn lại. Bot: `make_bot(rng, li)`, league dưới `cos_from()` không đeo món league.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_leaderboard test_ui_leaderboard test_ui_profile test_cosmetics test_i18n`

- [ ] **Task 9.25: Socola phủ thanh (2026-11-10; còn bước sinh lại level của Task 9.22)**
  - **Allowed Files:** `src/core/board_state.gd`, `src/core/solver.gd` (chú thích), `src/core/level_data.gd` (`_validate_choco`), `src/core/level_generator.gd` (`MECHS`, `EXCLUSIVE`, `_choco`, `_unstick`, `_melt_side`, `_teach_ok`, `_finish`, `_build`), `src/config.gd` (`UNLOCK.choco`, `CHOCO_*`), `src/meta/unlocks.gd` (`MECHS`), `src/game/game.gd` (`tap`), `src/game/sfx.gd` (`HAPTIC_MS.choco`), `src/ui/level.gd` (`choco_held`), `src/ui/board_view.gd`, `src/ui/choco_cover.gd` (mới), `src/ui/choco_cover.gdshader` (mới), `assets/ui/mech_choco.png`, `assets/sfx/sfx_choco.wav`, `art/images/mech_choco.png`, `art/audio/sfx_choco.mp3`, `art/manifest.json`, `i18n/strings.csv` (`mech_choco`, `mech_choco_desc`, `feature_choco`), `i18n/*.translation`, `art/fonts/subset/*`, `assets/fonts/*.res`, `art/concepts/concept_choco_v1.png`, `art/concepts/choco/*`, `tests/test_choco.gd`, `tests/test_ui_choco.gd`, `tests/test_i18n.gd`, `tests/test_levels_all.gd` (`_mechs`, level dạy socola).
  - **Specs:** `design.md` mục 4 "Cơ chế sau bản demo" (dòng Socola, "Socola" dưới "Hình dạng level", booster), mục 9. Board: thứ tự ưu tiên sương mù > socola > xích > lớp phủ; `choco` không tốn MOVES, không đếm lượt chạm. Bộ sinh: socola và cổng nhịp không cùng level (`EXCLUSIVE`); thanh phủ là cạnh có lần qua đầu tiên sớm nhất (bỏ màu của khối đầu tiên); `_unstick` bớt lớp khi kẹt. BoardView: `ChocoCover` con của `Frame`, hình bớt lớp khi thứ đi qua thanh khác chạm thanh của nó (`_choco_due` theo lượt) hoặc lúc búa gõ (`_sync_choco`); `choco_held` giữ khối tới lúc đó.
  - **Hình:** biến thể A (socola sữa) của `art/concepts/concept_choco_v1.png`; `choco_cover.gdshader` vẽ tấm và giọt theo khung chuẩn của thanh (ColorRect xoay theo thanh), huy hiệu số vẽ trên node con `Badge`; vụn socola bằng `CandyShards.chips` với `ChocoCover.RAMP`.
  - **Còn lại:** level đóng gói có socola sau đợt sinh lại chung (Task 9.22 "Còn lại"); nghe thử `sfx_choco` trên máy thật.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_choco test_ui_choco test_board test_solver test_generator test_unlocks test_i18n test_ribbon`

**Bảy cơ chế mới (Task 9.26–9.32, lập kế hoạch 2026-11-10, chưa làm).** Người dùng chọn 7 trong 10 cơ chế Claude đề xuất ngày 2026-11-10: bỏ "Bánh quy giòn" (vật cản vỡ sau vài cú va) và "Hộp quà sao" (+2 MOVES khi khối rời bàn); "Cổng sô-cô-la niêm phong" trùng Socola phủ thanh (Task 9.25) nên không thêm. Chung cho cả bảy task:

- **Thứ tự:** tuần tự theo số task (chung `board_state.gd`, `level_generator.gd`, `config.gd`, `strings.csv`), sau Task 9.25 và trước đợt sinh lại 500 level (Task 9.22 "Còn lại"), để chỉ sinh lại một lần. Mốc mở là đề xuất, chốt lại cùng luật; các mốc L170–L320 dưới đây lập trước khi dời mốc ngày 2026-11-10 (Băng L165, Socola L300, Ruy băng L350) nên phải chọn lại.
- **Bước đầu mỗi task:** luật dưới đây là bản đề xuất. Chốt từng "Điểm cần chốt" với người dùng (như Socola), ghi vào `design.md` mục 4 (bảng cơ chế, "Hình dạng level", "Booster với cơ chế", "Mở khoá theo level", danh sách level dạy, dòng "Sau L350 chỉ phối hợp…" đổi thành mốc cơ chế cuối) và mục 9, rồi mới code. Hình: concept sheet 3 phương án cho người dùng chọn trước khi làm thật.
- **Mỗi task gồm:** khoá trong `Config.UNLOCK` và `Unlocks.MECHS`; dữ liệu level (kế hoạch mục 1.6) và `LevelData.validate`; `BoardState.tap` (kind mới nếu cần, xếp vào thứ tự ưu tiên sương mù > socola > xích > lớp phủ > bị chặn > cổng nhịp > thoát); solver, `clear_rounds` và chú thích đầu `solver.gd`; bộ sinh (`MECHS`, `EXCLUSIVE`, rải cơ chế, `_unstick`, `_teach_ok`, `_build`); level dạy; Gợi ý và bong bóng nhắc; Phá khối; hình trên bàn và hiệu ứng theo chất liệu; icon `mech_<khoá>`, `sfx_<khoá>`; chuỗi `mech_<khoá>`, `mech_<khoá>_desc`, `feature_<khoá>` đủ 14 ngôn ngữ (chữ hoa mới thì chạy lại `tools/node/subset_fonts.mjs` và `tools/gen_baloo_font.gd`); test logic và test UI.
- **Allowed Files chung:** `src/core/board_state.gd`, `src/core/solver.gd`, `src/core/level_data.gd`, `src/core/level_generator.gd`, `src/config.gd` (`UNLOCK.<khoá>`, hằng số của cơ chế), `src/meta/unlocks.gd`, `src/game/game.gd` (`tap`), `src/game/sfx.gd`, `src/ui/level.gd`, `src/ui/board_view.gd`, `src/ui/board_fx.gd`, `src/ui/obstacle_fx.gd`, file view mới của cơ chế, `assets/ui/mech_<khoá>.png`, `assets/sfx/sfx_<khoá>.wav`, `art/`, `i18n/strings.csv` và `.translation`, `art/fonts/subset/*`, `assets/fonts/*.res`, `tests/fixtures/mechanics.json`, `tests/test_<khoá>.gd`, `tests/test_ui_<khoá>.gd`, `tests/test_i18n.gd`, `tests/test_levels_all.gd` (`_mechs`, level dạy), `design.md`, kế hoạch mục 1.6 và 1.7.
- **Verification chung:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_<khoá> test_ui_<khoá> test_board test_solver test_generator test_unlocks test_i18n test_choco test_ribbon`

- [x] **Task 9.26: Bom kẹo (`pop`, L220, giúp người chơi; luật chốt và làm xong 2026-11-10)**
  - **Allowed Files:** như "Allowed Files chung" ở trên, cụ thể: `src/core/board_state.gd` (`pop`, `popped`, `pop_targets`, `last_popped`, `hint`), `src/core/level_data.gd` (`_validate_pop`), `src/core/level_generator.gd` (`MECHS`, `mech_plan`, `_pops`, `_pop_scores`, `_teach_ok`, `_finish`), `src/core/solver.gd` (chú thích), `src/config.gd` (`UNLOCK.pop`, `POP_*`), `src/meta/unlocks.gd`, `src/game/game.gd` (`_begin_attempt`: tắt `pop` từ xa, khối crystal; `smash_block`), `src/game/sfx.gd` (`HAPTIC_MS.pop`, `pop_hit`), `src/ui/pop_fuse.gd` (mới), `src/ui/board_view.gd`, `src/ui/level.gd`, `src/ui/booster_unlocked.gd` (`HELPER_TITLES`), `assets/ui/pop_fuse.png`, `assets/ui/mech_pop.png`, `assets/sfx/sfx_pop.wav` (và `.import`), `art/images/pop_fuse.png`, `art/images/mech_pop.png`, `art/audio/sfx_pop.mp3`, `art/concepts/concept_pop_v1.png`, `art/concepts/concept_pop_v2.png`, `art/concepts/pop/*`, `art/manifest.json`, `i18n/strings.csv` (`mech_pop`, `mech_pop_desc`, `mech_pop_title`, `feature_pop`), `i18n/*.translation`, `art/fonts/subset/*`, `assets/fonts/*.res`, `tests/test_pop.gd`, `tests/test_ui_pop.gd`, `tests/test_generator.gd` (`test_mech_plan`), `tests/test_i18n.gd`, `tests/test_levels_all.gd`, `design.md`, `docs/REF_GAME_DIFF.md`, `docs/HORUS_HANDOFF.md`, kế hoạch mục 1.6, 1.7.
  - **Còn lại:** level đóng gói có bom kẹo sau đợt sinh lại chung (Task 9.22 "Còn lại"); riêng L220 đã sinh lại theo yêu cầu (`--from=220 --to=220 --seed=20261101 --out=res://data/levels`, `tools/gen_levels.gd` ghi thêm khoá `pop`; `data/pudding_sdf.res` đã có đủ hình). Nghe thử `sfx_pop` và xem nhịp nổ trên máy thật.
  - **Verification:** `tools/godot.sh --headless --path . -s res://tests/run_all.gd -- test_pop test_ui_pop test_board test_solver test_generator test_unlocks test_i18n test_choco test_ribbon test_ui_level`
  - **Luật (đã chốt, `design.md` mục 4 dòng Bom kẹo, "Hình dạng level", "Booster với cơ chế", mục 3 "Tiêu chí thư giãn", mục 8):** khối bom kẹo rời bàn (thoát hoặc bị Phá) thì bóc sạch mọi lớp pudding hoặc băng và xoá sương của mọi khối có ít nhất 1 ô trong vùng 5×5 quanh bất kỳ ô nào của nó (Chebyshev ≤ `POP_RADIUS` = 2; thùng sắt, ô trống không chắn). Không đụng thùng sắt, xích, hộp giấy, ruy băng, cổng nhịp, socola. Không nổ dây chuyền: bom kẹo khác trong vùng không tự rời bàn. Khối bom kẹo "sạch" (không lớp phủ, sương, xích hay chìa, hộp giấy, ruy băng, crystal). Bàn cập nhật lúc chạm, hình vỡ lúc bom kẹo chạm thanh hoặc búa gõ.
  - **Solver:** `min_taps` không đổi (số chạm không phụ thuộc thứ tự, chú thích đầu `solver.gd`), tham lam vẫn tối ưu. `clear_rounds` và `_unstick` mô phỏng cú nổ, nên bộ sinh bám đường cong số lượt dọn bàn như cũ.
  - **Bộ sinh:** chỉ rải vào level đã có pudding, băng hoặc sương; bom kẹo tính là 1 trong `LEVEL_MECH_MAX` loại; L220–229 luôn có bom kẹo cùng ít nhất một trong ba loại đó. 1 khối tới L249, 1–2 từ L250 (`POP_COUNT_*`). Khối không nằm ở lượt dọn đầu tiên, và theo thứ tự giải, lúc nó rời bàn vùng nổ còn ít nhất `POP_MIN_TARGETS` = 3 khối phủ hoặc ẩn. Level dạy L220: bom kẹo cùng pudding (ngoại lệ của luật "chỉ cơ chế mới"), bom kẹo thoát được ngay, vùng nổ có ít nhất 4 khối pudding và ít nhất 1 khối 2 lớp (`_teach_ok`).
  - **Gợi ý, Phá khối, Remote Config:** Gợi ý và bong bóng nhắc ưu tiên bom kẹo khi nó thoát được và vùng nổ còn khối phủ hoặc ẩn; "Available Block : N" đếm như cũ. Phá khối trên bom kẹo thì nổ lúc búa gõ. `features_pop` = "0" thì khối bom kẹo thành khối thường. Không thêm sự kiện analytics.
  - **Dữ liệu:** khối có `"pop": true`; `LevelData.validate` từ chối bom kẹo mang cơ chế khác; `tap` trả các khối được gỡ ở `popped` (như `stripped`), `smash` để ở `last_popped()`, `Game.smash_block` trả `popped`.
  - **View:** `PopFuse` con của khối bom kẹo (khối vẽ sau cùng); `_pop_hold` giữ hình khối trong vùng nổ tới lúc nổ (`pop_held(id)` để `level.gd` coi chạm sớm là `covered`/`fog`); `_pop_due` theo lượt, `_grind` gọi `_pop_blast`; `smash_anim(id, popped)`; tiếng vỡ qua `_sfx_db`, `_sfx_mute`.
  - **Chữ:** tên `mech_pop` "Bom kẹo" / "Candy Bomb"; popup dùng tiêu đề riêng `mech_pop_title` "BOM KẸO!" / "CANDY BOMB!" thay `mech_new_title` và ẩn dòng tên; `mech_pop_desc` VI "Rời bàn thì bóc sạch pudding, băng và sương mù trong 2 ô quanh nó.", EN "When it leaves, it clears pudding, ice and fog within 2 cells."; đủ 14 ngôn ngữ; thêm "Ẹ" hoa vào font con (`subset_fonts.mjs`, `gen_baloo_font.gd`).
  - **Hình:** người dùng chọn phương án A của `art/concepts/concept_pop_v1.png` (cam thảo đỏ xoắn, đế tròn, tia pháo que vàng trắng), làm to và ngắn hơn, rồi chọn bản A2 cao 1,6 ô của `art/concepts/concept_pop_v2.png`. Ngòi là ảnh tĩnh `assets/ui/pop_fuse.png` làm từ `art/concepts/pop/fuse_a_short.png` (xoá tia có sẵn trong ảnh), code xoay 35° ngược chiều kim đồng hồ, cao 1,6 ô sau khi xoay, tâm cách góc trên trái của ô vào 0,06 ô, bóng đổ lệch (0,05; 0,06) ô (`Config.POP_FUSE_SIZE`, `POP_FUSE_ANGLE`, `POP_FUSE_INSET`); tia vẽ bằng code, luôn toả lên trên, cháy đều mãi (không ngắn dần, không số); khác hẳn bom Màn đặc biệt (kẹo gậy hồng trắng, đầu ngôi sao, tông xanh tím). Đặt ở góc trên trái của khối (ô trái nhất của hàng trên cùng), chĩa chéo lên trái: nửa phía đế trong khối, nửa đầu ngòi lấn ra ô bên ngoài, nên ngòi vẽ ở lớp trên mọi khối (lề 1 ô quanh hình đủ chỗ cho phần lấn ra). Nổ: sóng vuông 5×5 từ chỗ khối vừa rời, khối trong vùng vỡ từ gần ra xa, 0,06 giây mỗi bậc, hiệu ứng vỡ sẵn có ở cỡ đầy đủ; không vẽ vùng trước; không rung bàn.
  - **Âm, rung:** `sfx_pop` lách tách tối đa 1 giây; tiếng vỡ của các khối trong vùng tối đa 4 tiếng, nhỏ hơn 6 dB; rung máy 25 ms lúc nổ, 10 ms mỗi khối vỡ (`Sfx.HAPTIC_MS.pop`), không tiếng ngòi lặp.
  - **Tài liệu thêm:** `docs/REF_GAME_DIFF.md` (dòng Vật cản).

- [ ] **Task 9.27: Dây kẹo kéo (`taffy`, đề xuất L190, khó hơn)**
  - **Luật đề xuất:** hai khối (khác màu được) nối bằng sợi kẹo kéo. Chạm một khối thì cả hai cùng đi về thanh của mình, cần cả hai đường thông; một bên bị chặn thì cả hai nhún rồi bật về (1 MOVES). Đi được thì 1 chạm đưa 2 khối ra (1 MOVES). Một khối còn sương, lớp phủ, xích hay chờ socola thì cả cặp bị giữ như khối đó. Phá khối một khối thì dây đứt, khối kia thành khối thường. Khối trong cặp không có hộp giấy hay ruy băng.
  - **Solver:** cặp rời bàn cùng lúc, bàn chỉ dễ đi nên tham lam vẫn tối ưu. Bộ sinh chỉ nối hai khối mà đường khối này không đi qua ô khối kia, tối đa 3 cặp mỗi level. Hai khối qua hai thanh khác thanh socola thì bớt 2 lớp.
  - **Dữ liệu:** `"taffy_with": "<id>"` ở cả hai khối; `validate` kiểm hai chiều.
  - **Điểm cần chốt:** 1 hay 2 MOVES khi đi được; hai khối có phải kề nhau không.

- [ ] **Task 9.28: Hũ kẹo (`jar`, đề xuất L210, lối tắt và vật cản)**
  - **Luật đề xuất:** hũ thuỷ tinh có nắp màu đặt ở ô trống trong hình. Khối cùng màu có ô đi qua hũ thì cả khối bị hút vào hũ, tính là thoát (không cần đường tới thanh). Khối khác màu coi hũ như thùng sắt. Hũ không đầy, không mất; Phá khối không dùng trên hũ.
  - **Solver:** hũ nằm yên; đường thoát dừng ở hũ cùng màu đầu tiên trên đường, tham lam vẫn tối ưu. Khối vào hũ không qua thanh nên không đổi cổng nhịp. Bộ sinh đặt 1–2 hũ ở ô trống trong hình (hình có lỗ, hoặc bỏ 1 ô của hình).
  - **Dữ liệu:** level có `"jars": [{"cell": [x, y], "color": "yellow"}]`; ô hũ không trùng khối hay thùng sắt.
  - **Điểm cần chốt:** khối khác màu bị chặn hay đi xuyên qua hũ; khối vào hũ có bớt socola không.

- [ ] **Task 9.29: Kẹo hai vị (`twotone`, đề xuất L230, thêm lựa chọn)**
  - **Luật đề xuất:** khối từ 2 ô chia hai nửa liền, mỗi nửa một màu. Chạm nửa nào thì cả khối đi theo màu nửa đó, cần cả khối thông theo hướng đó; nửa bị chặn thì nhún bật về, tốn 1 MOVES. Nửa có màu thanh socola thì chạm nửa đó chỉ nhích. Không chung khối với hộp giấy, ruy băng, xích. Gợi ý chỉ sáng nửa đi được.
  - **Solver:** khối thoát khi một trong hai hướng thông; với khối khác, khối này rời bàn hướng nào cũng như nhau, nên tham lam vẫn tối ưu. Không cùng level với cổng nhịp (chọn hướng làm đổi số lần qua cổng; thêm vào `EXCLUSIVE`).
  - **Dữ liệu:** khối có `"color2"` và `"cells2"` (ô của nửa thứ hai, tập con của `cells`). Interface: `BoardState.tap` và `peek` nhận thêm ô được chạm (mục 1.7), `Game.tap` và `level.gd` truyền ô.
  - **Điểm cần chốt:** cách chia nửa (đường thẳng hay theo vùng vẽ); hai màu có được đối nhau (lên và xuống) không.

- [ ] **Task 9.30: Kẹo tên lửa (`rocket`, đề xuất L260, chiến thuật)**
  - **Luật đề xuất:** đường thông thì tên lửa thoát như khối thường. Bị khối chặn thì không bật về mà đâm vỡ khối chặn đầu tiên (rời bàn như bị Phá: bóc lớp phủ khối kề, bớt socola, mở xích nếu là chìa), rồi tên lửa nổ và cũng rời bàn; 1 MOVES. Vật chặn đầu tiên là thùng sắt hay hũ thì bật về như thường. Gợi ý chỉ chỉ tên lửa khi đường thông.
  - **Solver:** tham lam không còn tối ưu (khối bị phá tuỳ lúc bắn), nhưng bàn chỉ dễ đi nên không kẹt. Tham lam xếp cú đâm sau `gate_closed`, cho số chạm làm được; muốn đúng tối thiểu thì thử mọi thời điểm bắn (tối đa 2 tên lửa mỗi level). Sửa chú thích đầu `solver.gd`.
  - **Dữ liệu:** khối có `"rocket": true`; `tap` trả kind `rocket` và id khối bị phá.
  - **Điểm cần chốt:** MOVES theo tham lam (dư thêm 1–2) hay tìm đúng tối thiểu; tên lửa còn trong sương có bắn được không.

- [ ] **Task 9.31: Ống kẹo (`pipe`, đề xuất L290, khó đọc hơn)**
  - **Luật đề xuất:** cặp miệng ống cùng hoa văn (không dùng màu vì màu là hướng) ở hai ô trống trong hình. Khối đi vào miệng A thì chui ra miệng B và đi tiếp cùng hướng tới thanh; cần cả hai đoạn thông, đoạn sau bị chặn thì bật về chỗ cũ. Chỉ khối rộng 1 ô theo chiều vuông góc với đường đi mới chui lọt; khối khác coi miệng ống như thùng sắt. Ống đi được hai chiều.
  - **Solver:** ống nằm yên, tham lam vẫn tối ưu; `BoardState` nối đường qua ống. Bộ sinh đặt 1 cặp mỗi level, chỉ nhận level có khối dùng ống trong lời giải.
  - **Dữ liệu:** level có `"pipes": [[[x1, y1], [x2, y2]]]`.
  - **View:** khối chui vào miệng A (mặt nạ ở miệng) rồi chui ra miệng B; file mới `src/ui/pipe_view.gd`.
  - **Điểm cần chốt:** luật chiều rộng; cách phân biệt nhiều cặp ống.

- [ ] **Task 9.32: Kẹo mút chong chóng (`spinner`, đề xuất L320, có chu kỳ)**
  - **Luật đề xuất:** chân kẹo mút cố định ở 1 ô, que dài 2 ô chặn ô nó nằm. Sau mỗi chạm có tính MOVES (thoát, bị chặn, bóc lớp, dội cổng) que quay 90° theo chiều kim đồng hồ; chạm không tốn MOVES (sương, lớp phủ, socola) không quay. Bàn không kẹt vì luôn chạm được một khối bị chặn để que quay tiếp. Phá khối không dùng trên chong chóng.
  - **Solver:** phá nguyên tắc "không có nước chờ" của `solver.gd`: phải tìm kiếm trên trạng thái (khối còn lại, góc que), BFS hoặc A* có giới hạn. Tối đa 1 chong chóng mỗi level, bàn tới `SPINNER_MAX_BLOCKS` (đề xuất 30) khối; sinh quá 200 ms thì bỏ chong chóng. Bộ sinh để trống chữ thập bán kính 2 quanh chân.
  - **Dữ liệu:** level có `"spinners": [{"cell": [x, y], "dir": "up"}]`.
  - **Điểm cần chốt:** có giữ cơ chế này không (rủi ro cao nhất, đổi luật nền "không có nước chờ"); que quay theo mọi chạm tính MOVES hay chỉ khi có khối rời bàn.

**Cổng Phase 9:** cổng mặc định, gộp manifest của Task 9.5, thêm xem cơ chế qua MCP (mục 1.12): chạy level dạy 14, 30, 45, 65, 85, 115, 165, 300, 350 (mốc 2026-11-10) và chụp từng màn. Không có session MCP thì ghi vào báo cáo, không chặn.

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
- [ ] Nhờ người bản xứ duyệt 12 cột dịch máy trong `i18n/strings.csv` (`pt_BR`, `tr`, `de`, `fr`, `id`, `es`, `ru`, `ko`, `ja`, `hi`, `uk`, `it`) và xem chữ có tràn khung trên máy thật (tiếng Đức, Nga dài nhất; Hindi, Hàn, Nhật dùng font fallback).
- [ ] Duyệt lại chỗ đặt màn chuyển cảnh 3.1 (`load_transition`): đang dùng khi sang level kế hoặc chơi lại, không đặt ở Road Trip vì Road Trip đã có màn nắp hộp quà (`design.md` mục 9, 2026-11-09).
- [ ] Chốt luật, hình và âm của từng cơ chế Task 9.26–9.32 (các mục "Điểm cần chốt") trước khi task đó bắt đầu.
- [ ] Báo khi đã thêm xong các cơ chế để sinh lại 500 level và bake lại `data/pudding_sdf.res` (Task 9.22 "Còn lại"). Tới lúc đó `test_levels_all` báo lỗi ở level đóng gói.

## 5. Blocker thật sự

Chỉ các trường hợp sau mới dừng để hỏi người dùng:

- Không xuất được Android sau khi đã thử JDK 17 và tải lại templates.
- `design.md` mâu thuẫn tới mức không thể suy ra hành vi và ảnh hưởng tới kinh tế.
- Một plugin bắt buộc không tương thích Godot 4.7.2 và không có cách thay trong kiến trúc này.
- Cần đóng editor (mục 1.12) trong khi `current_scene` khác rỗng.

Thiếu cấu hình Horus, thiếu máy thật, MCP ComfyUI hoặc MCP `godot-ai` không chạy: **không phải blocker**, ghi lại rồi đi tiếp.
