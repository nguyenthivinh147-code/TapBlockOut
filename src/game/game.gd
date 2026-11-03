extends Node
## Autoload Game (kế hoạch mục 1.10): điều phối module meta, Platform và Sfx. UI chỉ gọi lớp này.
## Quy ước: gold trong code là `coins`; analytics gọi `gold`. Mọi sự kiện có tham số `build`.

signal coins_changed(value: int)
signal inv_changed
signal lives_changed
signal cos_changed
signal offer_ready(id: String)

const Config := preload("res://src/config.gd")
const SaveSchema := preload("res://src/meta/save_schema.gd")
const SaveStore := preload("res://src/meta/save_store.gd")
const Clock := preload("res://src/meta/clock.gd")
const Wallet := preload("res://src/meta/wallet.gd")
const Lives := preload("res://src/meta/lives.gd")
const Unlocks := preload("res://src/meta/unlocks.gd")
const RescueFlow := preload("res://src/meta/rescue_flow.gd")
const DailyCalendar := preload("res://src/meta/daily_calendar.gd")
const Cosmetics := preload("res://src/meta/cosmetics.gd")
const ShopVideos := preload("res://src/meta/shop_videos.gd")
const AdPacing := preload("res://src/meta/ad_pacing.gd")
const Offers := preload("res://src/meta/offers.gd")
const WeeklyPass := preload("res://src/meta/weekly_pass.gd")
const ChainOffer := preload("res://src/meta/chain_offer.gd")
const PackConditions := preload("res://src/meta/pack_conditions.gd")
const NotifPlan := preload("res://src/meta/notif_plan.gd")
const Leaderboard := preload("res://src/meta/leaderboard.gd")
const BoardState := preload("res://src/core/board_state.gd")
const LevelData := preload("res://src/core/level_data.gd")
const LevelLoop := preload("res://src/core/level_loop.gd")
const LevelGenerator := preload("res://src/core/level_generator.gd")
const Solver := preload("res://src/core/solver.gd")
const DifficultyCurve := preload("res://src/core/difficulty_curve.gd")

const SAVE_PATH := "user://save.json"
const LEVEL_PATH := "res://data/levels/level_%04d.json"
## Gộp ghi: có thay đổi nhỏ (queue) thì ghi sau chừng này giây.
const FLUSH_SEC := 2.5
const LANGS := ["en", "vi"]
## Daily Challenge không dùng level thấp hơn mức này (mở khoá ở L50).
const CHALLENGE_MIN_ID := 50
## Level Daily Challenge sinh trong game: seed cơ sở = id * SEED_STRIDE, mỗi lần sinh lại cộng RESEED_STEP
## (generate tự thử thêm 60 seed liền kề nên RESEED_STEP > 60). Giữ SEED_STRIDE > RESEED_STEP * số lần thử
## để hai level (hay hai ngày) kế nhau không trùng seed.
const SEED_STRIDE := 1000
const RESEED_STEP := 64
const GEN_TRIES := 8

var s: Dictionary = SaveSchema.defaults()
var store: SaveStore = null
var save_path: String = SAVE_PATH
## Lý do thất bại của lần `watch` gần nhất: "" | "not_ready" | "closed" | "error".
var last_ad_reason: String = ""
## Chỉ test đặt: 0 = giờ thật; test_tz null = múi giờ máy.
var test_now: int = 0
var test_tz: Variant = null

var _booted: bool = false
var _session_start: int = 0
var _first_session: bool = false
var _in_ad: bool = false
var _flush_timer: Timer = null
var _offered: Dictionary = {}  # placement -> true (đã log rv_offer)
var _last_win_level: int = 0
var _last_attempt_level: int = 0
var _x2_pending: int = 0
var _x2_free: bool = false
var _connected: bool = false
## Màn level/challenge đang mở (do Main đặt qua set_in_level). Bản cloud tới muộn không áp lúc này.
var in_level: bool = false
var _boot_done: bool = false
var _buying: int = 0
## JSON bản cloud đã xử lý (tránh áp hai lần) và bản tới muộn đang chờ ra khỏi level.
var _cloud_applied: String = ""
var _cloud_late: String = ""
## Cache level sinh trong game (khoá: "C<ngày>:<id>").
var _gen_cache: Dictionary = {}


func _ready() -> void:
	_ensure_store()
	_flush_timer = Timer.new()
	_flush_timer.one_shot = true
	_flush_timer.wait_time = FLUSH_SEC
	_flush_timer.timeout.connect(_on_flush_timer)
	add_child(_flush_timer)
	if not _connected:
		_connected = true
		Platform.paused.connect(_on_paused)
		Platform.resumed.connect(_on_resumed)
		if Platform.save.has_signal("cloud_synced"):
			Platform.save.connect("cloud_synced", _on_cloud_synced)


func _ensure_store() -> void:
	if store == null or store.path != save_path:
		store = SaveStore.new(save_path, Callable(Platform, "mirror"))


# --- thời gian ---

func now() -> int:
	if test_now > 0:
		return test_now
	return int(Time.get_unix_time_from_system())


func _tz() -> int:
	if test_tz != null:
		return int(test_tz)
	return Clock.local_tz_offset()


func today() -> int:
	return Clock.day_number(now(), _tz())


# --- khởi động và lưu ---

## Thứ tự: backup, cloud, Remote Config, ngôn ngữ, meta, đơn treo, quảng cáo mất.
func boot() -> void:
	if _booted:
		return
	_booted = true
	_ensure_store()
	s = store.load_state(Platform.backup())
	Platform.sync_cloud()
	await Platform.fetch()
	# Bản cloud đã về (nếu kịp) thì chọn bản chơi nhiều hơn; về muộn hơn thì _on_cloud_synced lo.
	var cloud_raw: Variant = Platform.save.get("cloud_json")
	_apply_cloud(str(cloud_raw) if cloud_raw != null else "")
	Config.apply_remote(Platform.values)
	_apply_language()
	Sfx.apply_settings(s.settings)
	var t := now()
	_session_start = t
	var meta: Dictionary = s.meta
	if int(meta.install_at) <= 0:
		meta["install_at"] = t
	meta["sessions"] = int(meta.sessions) + 1
	_first_session = not bool(meta.first_session_done)
	meta["first_session_done"] = true
	NotifPlan.note_open(s, t, _tz())
	NotifPlan.note_return(s, t, "", Platform.enabled())
	weekly_refresh()
	lb_refresh()
	Lives.tick(s, t)
	_deliver_pending()
	_recover_lost_ads()
	Platform.user({"build": Config.CONTENT.build, "level": int(s.level), "sessions": int(meta.sessions)})
	ftue("open")
	save_now()
	_replan_notifications()
	coins_changed.emit(int(s.coins))
	inv_changed.emit()
	lives_changed.emit()
	cos_changed.emit()
	log_event("boot", {"ms": Time.get_ticks_msec(), "level": int(s.level), "sessions": int(meta.sessions)})
	_boot_done = true


## Dùng trong test: file lưu riêng, trạng thái và nhật ký sạch.
func reset_for_test(path: String) -> void:
	save_path = path
	_remove_save_files()
	Config.reset()
	_clear_session()
	in_level = false
	test_now = 0
	test_tz = null
	_session_start = now()
	_first_session = false
	if Platform.an != null and Platform.an.has_method("clear"):
		Platform.an.clear()


func _remove_save_files() -> void:
	for p in [save_path, save_path + ".bak", save_path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


## Back to the state before boot: default save, new store (drops a queued write), no session leftovers.
func _clear_session() -> void:
	store = null
	_ensure_store()
	s = SaveSchema.defaults()
	_booted = false
	_boot_done = false
	_buying = 0
	_cloud_applied = ""
	_cloud_late = ""
	_in_ad = false
	_offered = {}
	_last_win_level = 0
	_last_attempt_level = 0
	_x2_pending = 0
	_x2_free = false
	_gen_cache = {}
	last_ad_reason = ""


func save_now() -> void:
	_ensure_store()
	store.save_now(s)


func _queue_save() -> void:
	_ensure_store()
	store.queue(s)
	if _flush_timer != null and _flush_timer.is_inside_tree() and _flush_timer.is_stopped():
		_flush_timer.start()


func _on_flush_timer() -> void:
	if store != null:
		store.flush()


func log_event(event_name: String, params: Dictionary = {}) -> void:
	var p := params.duplicate()
	p["build"] = Config.CONTENT.build
	Platform.log_event(event_name, p)


func _apply_language() -> void:
	var lang := str(s.settings.get("lang", ""))
	if lang == "":
		lang = OS.get_locale_language()
	if not LANGS.has(lang):
		lang = "en"
	TranslationServer.set_locale(lang)


func _on_paused() -> void:
	if _in_ad:
		save_now()
		return
	Sfx.pause_for_ad()
	save_now()
	Platform.flush()
	_replan_notifications()


func _on_resumed() -> void:
	if _in_ad:
		return
	Sfx.resume_after_ad()
	# Đơn treo có thể hoàn tất khi người chơi ra ngoài thanh toán. Đang chờ buy_sku thì để nó giao.
	if _boot_done and _buying == 0:
		_deliver_pending()
	var t := now()
	NotifPlan.note_open(s, t, _tz())
	NotifPlan.note_return(s, t, "", Platform.enabled())
	weekly_refresh()
	lb_refresh()
	Lives.tick(s, t)
	ChainOffer.update(s, t)
	lives_changed.emit()
	_queue_save()


## Giao hết đơn treo (grant_purchase chống trùng theo token). Trả số đơn đã cộng hàng.
func _deliver_pending() -> int:
	var n := 0
	for p in Platform.pending():
		if p is Dictionary and str(p.get("status", "ok")) == "ok" and grant_purchase(p):
			n += 1
	return n


# --- cloud save ---

## Main báo đang ở màn level/challenge hay không. Ra khỏi level thì áp bản cloud đang chờ.
func set_in_level(v: bool) -> void:
	in_level = v
	if not v and _cloud_late != "":
		var raw := _cloud_late
		_cloud_late = ""
		_apply_cloud_late(raw)


## Cloud_synced tới sau boot. Đang chơi level thì giữ lại đến khi về Home (không đè ván đang chơi),
## còn lại áp ngay. Trước khi boot xong thì bỏ qua: boot đọc Platform.save.cloud_json sau fetch.
func _on_cloud_synced(json: String) -> void:
	if not _boot_done:
		return
	if in_level:
		_cloud_late = json
	else:
		_apply_cloud_late(json)


func _apply_cloud_late(raw: String) -> void:
	if not _apply_cloud(raw):
		return
	_apply_language()
	Sfx.apply_settings(s.settings)
	coins_changed.emit(int(s.coins))
	inv_changed.emit()
	lives_changed.emit()
	cos_changed.emit()


## Gộp bản cloud vào `s`: giữ bản chơi nhiều hơn (SaveStore.further), gộp đơn đã mua theo token và cấp
## lại hàng của đơn chỉ một bên có. Trả true nếu `s` đổi (đã save_now). Bản rỗng, hỏng hoặc đã xử lý
## rồi thì bỏ qua. Mỗi chuỗi JSON chỉ xử lý một lần.
func _apply_cloud(raw: String) -> bool:
	if raw.strip_edges().is_empty() or raw == _cloud_applied:
		return false
	_cloud_applied = raw
	var j := JSON.new()
	if j.parse(raw) != OK or not (j.data is Dictionary) or (j.data as Dictionary).is_empty():
		return false
	var cloud := SaveSchema.merge_defaults(j.data)
	var cloud_wins := is_same(SaveStore.further(s, cloud), cloud)  # hoà thì giữ bản local
	var other := cloud
	if cloud_wins:
		other = s
		s = cloud
	var granted := SaveStore.merge_purchases(s, other, _regrant)
	if not cloud_wins and granted.is_empty():
		return false
	save_now()
	return true


## Cấp lại hàng của đơn chỉ có ở bản kia (entry đã nằm trong s.buys). Món mua một lần đã có
## ở bản này bằng token khác thì không cộng hàng lần hai.
func _regrant(entry: Dictionary) -> void:
	var sku := str(entry.get("sku", ""))
	var info: Dictionary = Config.SKUS.get(sku, {})
	if info.is_empty():
		return
	if not bool(info.get("consumable", true)):
		var n := 0
		for e in s.buys:
			if e is Dictionary and str(e.get("sku", "")) == sku:
				n += 1
		if n > 1:
			return
	_give({"coins": int(info.get("gold", 0)), "items": info.get("inv", {})}, "iap_" + sku)
	if bool(info.get("no_ads", false)):
		s["no_ads"] = true


# --- FTUE ---

## Mỗi bước một lần; bước lạ bị bỏ qua.
func ftue(step: String) -> void:
	var steps: Array = Config.CONTENT.ftue_steps
	var done: Array = s.meta.ftue
	if not steps.has(step) or done.has(step):
		return
	done.append(step)
	log_event("ftue", {"step": step, "idx": steps.find(step)})
	_queue_save()


func _ftue_runs() -> void:
	var runs := int(s.runs)
	if runs >= 2:
		ftue("run_2")
	if runs >= 5:
		ftue("run_5")


# --- level ---

## Level người chơi sắp chơi. Demo dừng ở `demo_max_level`. `s.level` là số hiển thị, tăng mãi; nội dung đọc
## từ data/levels theo `content_level`: sau level cuối (`release_pregen_level`) lặp lại từ `loop_start_level`.
## Bản lưu cũ có `s.level` lớn hơn level cuối tự nhận nội dung vòng lặp, không cần migrate.
func current_level_data() -> Dictionary:
	var lv := int(s.level)
	if not level_exists(lv):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LEVEL_PATH % content_level(lv)))
	return parsed if parsed is Dictionary else {}


## Level nội dung (số file) mà level hiển thị `lv` chơi.
func content_level(lv: int) -> int:
	return LevelLoop.content_level(lv, int(Config.CONTENT.loop_start_level), int(Config.CONTENT.release_pregen_level))


## Độ khó của level hiển thị `lv`: "" | "hard" | "very_hard". Level HARD từ `very_hard_from_level` luôn là rất khó.
func difficulty_of(lv: int) -> String:
	var c := content_level(lv)
	if DifficultyCurve.is_very_hard(c) or (lv >= int(Config.CONTENT.very_hard_from_level) and DifficultyCurve.is_hard(c)):
		return "very_hard"
	return "hard" if DifficultyCurve.is_hard(c) else ""


## Level `lv` có thể chơi không. Demo: tới `demo_max_level`; phát hành: có file nội dung (kể cả sau vòng lặp).
func level_exists(lv: int) -> bool:
	if lv < 1:
		return false
	if Config.is_demo() and lv > int(Config.CONTENT.demo_max_level):
		return false
	return FileAccess.file_exists(LEVEL_PATH % content_level(lv))


## Sinh (id, seed cơ sở), qua validate và Solver, sinh lại với seed kế tiếp nếu không đạt. {} nếu hỏng hết.
func generate_checked(id: int, base_seed: int) -> Dictionary:
	for k in GEN_TRIES:
		var d := LevelGenerator.generate(id, base_seed + k * RESEED_STEP)
		if d.is_empty() or not LevelData.validate(d).is_empty():
			continue
		if bool(Solver.solve(d).get("ok", false)):
			return d
	return {}


func _generated(key: String, id: int, base_seed: int) -> Dictionary:
	if not _gen_cache.has(key):
		var d := generate_checked(id, base_seed)
		if d.is_empty():
			return {}
		if _gen_cache.size() > 4:
			_gen_cache.clear()
		_gen_cache[key] = d
	return (_gen_cache[key] as Dictionary).duplicate(true)


## {board, rescue, level, ...} hoặc {} khi hết level (demo) hay thiếu dữ liệu.
func start_attempt() -> Dictionary:
	var data := current_level_data()
	if data.is_empty():
		return {}
	return _begin_attempt(data, int(s.level), false)


func _begin_attempt(data: Dictionary, level: int, challenge: bool) -> Dictionary:
	var board := BoardState.new(data)
	var attempt := {
		"board": board, "rescue": RescueFlow.new(), "level": level,
		"taps": 0, "moves0": board.moves_left(), "count0": board.remaining_count(),
		"start_ms": Time.get_ticks_msec(), "free_used": {}, "ended": false,
		"life_charged": false, "challenge": challenge, "hard": bool(data.get("hard", false)),
		"day": today(), "replay": not challenge and level == _last_attempt_level,
		"specials": [] as Array[String], "special_left": [] as Array[String], "pieces": 0,
	}
	if not challenge and lb_open():
		lb_refresh()
		var sp := Leaderboard.pick_specials(board.block_ids(), Leaderboard.pieces_for(difficulty_of(level)), level)
		attempt["specials"] = sp
		attempt["special_left"] = sp.duplicate()
	if not challenge:
		_last_attempt_level = level
	var params := {"level": level, "runs": int(s.runs), "moves": board.moves_left(),
		"lives": Lives.count(s, now())}
	if challenge:
		params["day"] = today()
		log_event("challenge_start", params)
	else:
		log_event("level_start", params)
	return attempt


## Chạm khối qua Game để đếm lượt chạm (restart từ L10 tính theo số chạm).
## Khối đặc biệt rời bàn thì res.piece = true (+1 mảnh leaderboard, cộng khi thắng).
func tap(attempt: Dictionary, block_id: String) -> Dictionary:
	var res: Dictionary = (attempt.board as BoardState).tap(block_id)
	if res.kind != "rejected":
		attempt["taps"] = int(attempt.taps) + 1
		ftue("first_tap")
	res["piece"] = res.kind == "exit" and _take_piece(attempt, block_id)
	return res


## Phá khối bằng Smash (UI đã trừ booster qua use_booster). Trả {ok, piece}: khối đặc biệt vẫn cho mảnh.
func smash_block(attempt: Dictionary, block_id: String) -> Dictionary:
	var ok := (attempt.board as BoardState).smash(block_id)
	return {"ok": ok, "piece": ok and _take_piece(attempt, block_id)}


func _take_piece(attempt: Dictionary, block_id: String) -> bool:
	var left: Array = attempt.get("special_left", [])
	if not left.has(block_id):
		return false
	left.erase(block_id)
	attempt["pieces"] = int(attempt.get("pieces", 0)) + 1
	return true


func _touched(attempt: Dictionary) -> bool:
	var b: BoardState = attempt.board
	return int(attempt.taps) > 0 or b.moves_left() < int(attempt.moves0) \
		or b.remaining_count() < int(attempt.count0)


func _finish_attempt(attempt: Dictionary, won: bool, coins: int) -> void:
	attempt["ended"] = true
	var ms := Time.get_ticks_msec() - int(attempt.start_ms)
	s["play_ms"] = int(s.play_ms) + ms
	s["runs"] = int(s.runs) + 1
	_ftue_runs()
	log_event("challenge_end" if bool(attempt.get("challenge", false)) else "level_end",
		{"level": int(attempt.level), "won": 1 if won else 0,
		"taps": int(attempt.taps), "moves_left": (attempt.board as BoardState).moves_left(),
		"ms": ms, "coins": coins, "runs": int(s.runs),
		"blocks_left": (attempt.board as BoardState).remaining_count(),
		"rescues": (attempt.rescue as RescueFlow).used(),
		"replay": 1 if bool(attempt.get("replay", false)) else 0})


## {coins, x2_available, x2_free, rate_prompt, progress, unlocked}. Cộng gold, tăng level, tăng s.runs, lưu ngay.
func on_level_won(attempt: Dictionary) -> Dictionary:
	if bool(attempt.get("ended", false)):
		return {"coins": 0, "x2_available": false, "x2_free": false, "rate_prompt": false,
			"progress": {}, "unlocked": [] as Array[String]}
	var level := int(attempt.level)
	var is_challenge := bool(attempt.get("challenge", false))
	var coins := int(Config.ECON.win_coins)
	if is_challenge:
		# +challenge_coins chỉ cho lần thắng đầu tiên trong ngày của bàn; thắng lại thì 0.
		var day := int(attempt.get("day", today()))
		var done: bool = int(s.challenge.get("day", -1)) == day and bool(s.challenge.get("won", false))
		coins = 0 if done else int(Config.ECON.challenge_coins)
		s["challenge"] = {"day": day, "won": true}
	_finish_attempt(attempt, true, coins)
	if not is_challenge:
		Offers.note_win(s, level)
	_earn(coins, "challenge_win" if is_challenge else "level_win")
	var weekly_pts := 0
	if not is_challenge:
		weekly_pts = WeeklyPass.add_points(s, weekly_state(), difficulty_of(level))
		if weekly_pts > 0:
			log_event("weekly_points", {"level": level, "points": weekly_pts, "total": WeeklyPass.points(s)})
	var lb: Dictionary = {}
	if not is_challenge:
		lb = _lb_award(attempt)
	if not is_challenge and level >= int(s.level):
		s["level"] = level + 1
	lb_refresh()
	_last_win_level = level
	_x2_pending = coins
	_x2_free = level == 1
	ftue("first_win")
	if int(s.level) >= 10:
		ftue("level_10")
	var rate := not is_challenge and Unlocks.is_open("review", level) and not bool(s.meta.rated)
	if rate:
		s.meta["rated"] = true
	if not is_challenge:
		_chain_check(false, level)
	save_now()
	var avail := coins > 0 and (_x2_free or Platform.ready_rewarded())
	if avail:
		log_event("rv_offer", {"pl": "x2_coins"})
		_offered["x2_coins"] = true
	var progress: Dictionary = {}
	if not is_challenge:
		progress = Unlocks.feature_progress(level, _content_cap())
	return {"coins": coins, "x2_available": avail, "x2_free": _x2_free, "rate_prompt": rate,
		"progress": progress, "unlocked": progress.get("unlocked", [] as Array[String]),
		"weekly_points": weekly_pts, "lb": lb}


func _content_cap() -> int:
	return int(Config.CONTENT.demo_max_level) if Config.is_demo() else 0


## Màn sau thẻ thắng: "home" khi vừa mở tính năng ở Home hoặc vừa thắng Daily Challenge, còn lại "level".
func next_after_win(res: Dictionary, challenge: bool) -> String:
	if challenge or Unlocks.opens_home(res.get("unlocked", [])):
		return "home"
	return "level"


## Thua (hết đường cứu). Từ L10 mất 1 mạng, trừ khi restart đã trừ.
func on_level_lost(attempt: Dictionary) -> void:
	_end_lost(attempt, true)


## Restart: từ L10 trừ 1 mạng nếu đã chạm ít nhất một lần. Trả true nếu đã trừ.
## Restart khi chưa chạm là miễn phí và không tính lượt. UI phải hỏi xác nhận trước.
func restart_cost_life(attempt: Dictionary) -> bool:
	if bool(attempt.get("ended", false)) or not _touched(attempt):
		return false
	return _end_lost(attempt, false)


func _end_lost(attempt: Dictionary, show_offer: bool) -> bool:
	if bool(attempt.get("ended", false)):
		return false
	var level := int(attempt.level)
	_finish_attempt(attempt, false, 0)
	if not bool(attempt.get("challenge", false)):
		Offers.note_fail(s, level)
		if show_offer:
			_chain_check(true, level)
	var charged := Lives.lose(s, now(), level)
	if charged:
		attempt["life_charged"] = true
		Sfx.play("life_lost")
		lives_changed.emit()
	save_now()
	if show_offer:
		check_offer(true)
	return charged


## x2 gold của level vừa thắng. L1 miễn phí (không quảng cáo). Chưa xem hết thì vẫn thử lại được.
func claim_x2() -> bool:
	if _x2_pending <= 0:
		return false
	if not _x2_free:
		if not await watch("x2_coins", {"coins": _x2_pending}):
			return false
	if _x2_pending <= 0:
		return false
	var n := _x2_pending
	_x2_pending = 0
	_earn(n, "x2_coins")
	ftue("first_x2")
	save_now()
	return true


## Rời thẻ thắng: chạy luật interstitial (result_exit), rồi offer, rồi xin quyền thông báo.
func leave_win_card(x2_offered: bool, x2_taken: bool) -> void:
	var t := now()
	var ctx := {
		"now": t, "session_start": _session_start, "first_session": _first_session,
		"level": _last_win_level, "x2_offered": x2_offered, "x2_taken": x2_taken, "day": today(),
	}
	_x2_pending = 0
	if AdPacing.inter_due(s, ctx) and Platform.ready_inter():
		var shown := await _show_inter("result_exit")
		if shown:
			AdPacing.note_inter(s, now(), today())
			log_event("inter_show", {"pl": "result_exit", "level": _last_win_level, "runs": int(s.runs)})
			save_now()
	check_offer(false)
	await _maybe_ask_notifications()


func _show_inter(placement: String) -> bool:
	_in_ad = true
	Sfx.pause_for_ad()
	save_now()
	var r: Dictionary = await Platform.inter(placement)
	Sfx.resume_after_ad()
	_in_ad = false
	return bool(r.get("shown", false))


func _maybe_ask_notifications() -> void:
	if bool(s.notify.asked) or int(s.runs) < int(Config.NOTIF.ask_after_run):
		return
	s.notify["asked"] = true
	save_now()
	await Platform.ask()
	_replan_notifications()


## Gọi sau khi hiện popup đánh giá; hiện hộp đánh giá của store.
func rate_now() -> void:
	Platform.review()


# --- ví ---

func _earn(n: int, source: String) -> void:
	if n <= 0:
		return
	Wallet.earn(s, n)
	Platform.earn("gold", n, source)
	coins_changed.emit(int(s.coins))


func spend_coins(n: int, sink: String) -> bool:
	if not Wallet.spend(s, n):
		return false
	Platform.spend("gold", n, sink)
	coins_changed.emit(int(s.coins))
	_queue_save()
	return true


## Chỉ lấy một booster khỏi kho; hiệu ứng lên bàn do UI làm (hint: board.hint(),
## move: board.add_moves(Config.ECON.rescue_moves), smash: board.smash(id)).
func use_booster(kind: String) -> bool:
	if not Wallet.inv_use(s, kind):
		return false
	log_event("booster_use", {"kind": kind, "level": int(s.level)})
	ftue("first_booster")
	inv_changed.emit()
	_queue_save()
	return true


func buy_booster(kind: String) -> bool:
	if not Wallet.KINDS.has(kind):
		return false
	var price := int(Config.ECON.booster_price.get(kind, 0))
	if price <= 0 or not spend_coins(price, "booster_" + kind):
		return false
	Wallet.inv_add(s, kind, 1)
	inv_changed.emit()
	save_now()
	return true


## Booster miễn phí bằng video (`booster_free`), 1 lần mỗi lượt chơi. Thành công thì kho +1.
func booster_video(attempt: Dictionary, kind: String) -> bool:
	if not Wallet.KINDS.has(kind) or bool((attempt.free_used as Dictionary).get("any", false)):
		return false
	if not await watch("booster_free", {"kind": kind}):
		return false
	(attempt.free_used as Dictionary)["any"] = true
	Wallet.inv_add(s, kind, 1)
	inv_changed.emit()
	save_now()
	return true


# --- quảng cáo rewarded ---

## Gọi khi nút mời xem quảng cáo hiện ra (log rv_offer một lần cho tới lần xem kế).
func offer_video(placement: String) -> void:
	if _offered.has(placement):
		return
	_offered[placement] = true
	log_event("rv_offer", {"pl": placement})


## Luồng rewarded thô: không tự thưởng, trả true khi xem hết (hoặc dùng tín dụng quảng cáo mất).
## Ghi s.ad_pend và lưu trước khi hiện, dừng nhạc khi hiện.
func watch(placement: String, ctx: Dictionary = {}) -> bool:
	last_ad_reason = ""
	offer_video(placement)
	var credit: Dictionary = s.ad_credit
	if int(credit.get(placement, 0)) > 0:
		credit[placement] = int(credit[placement]) - 1
		_offered.erase(placement)
		log_event("rv_done", {"pl": placement, "credit": 1})
		save_now()
		return true
	if not Platform.ready_rewarded():
		Platform.load_ads()
		var waited := 0.0
		var wait_max := float(Config.ADS.get("rv_wait_sec", 3.0))
		while not Platform.ready_rewarded() and waited < wait_max:
			await get_tree().create_timer(0.1).timeout
			waited += 0.1
		if not Platform.ready_rewarded():
			last_ad_reason = "not_ready"
			log_event("rv_unavailable", {"pl": placement})
			return false
	s["ad_pend"] = {"pl": placement, "coins": int(ctx.get("coins", 0)), "at": now()}
	save_now()
	log_event("rv_start", {"pl": placement})
	_in_ad = true
	Sfx.pause_for_ad()
	var r: Dictionary = await Platform.rewarded(placement)
	Sfx.resume_after_ad()
	_in_ad = false
	s["ad_pend"] = {}
	if not bool(r.get("ok", false)):
		var why := str(r.get("reason", "error"))
		last_ad_reason = why if why != "" else "error"
		log_event("rv_cancel" if why == "closed" else "rv_fail", {"pl": placement, "why": why})
		save_now()
		return false
	AdPacing.note_rewarded(s, now())
	_offered.erase(placement)
	log_event("rv_done", {"pl": placement})
	return true


func _recover_lost_ads() -> void:
	var pend: Dictionary = s.ad_pend
	s["ad_pend"] = {}
	var ads: Object = Platform.ads
	var lost: Variant = ads.get("lost") if ads != null else null
	if not (lost is Array) or (lost as Array).is_empty():
		return
	for e in lost:
		var pl := str(e.get("pl", "")) if e is Dictionary else str(e)
		match pl:
			"x2_coins":
				var n := int(pend.get("coins", 0)) if str(pend.get("pl", "")) == pl else 0
				_earn(n, "ad_recovered")
			"shop_coins":
				var g := ShopVideos.note_watch(s, today())
				_earn(g, "ad_recovered")
			"":
				continue
			_:
				var credit: Dictionary = s.ad_credit
				credit[pl] = int(credit.get(pl, 0)) + 1
		log_event("ad_reward_recovered", {"pl": pl})
	if ads.has_method("lost_done"):
		ads.call("lost_done")


# --- hết MOVES ---

func _rescue_raw(attempt: Dictionary) -> Dictionary:
	var b: BoardState = attempt.board
	return (attempt.rescue as RescueFlow).offer(Wallet.inv_count(s, "move"), int(s.coins),
		b.remaining_count(), int(attempt.level))


## Popup cần hiện khi hết MOVES: dict của RescueFlow.offer + `lost` (index < 0). Log rescue_show.
func rescue_offer(attempt: Dictionary) -> Dictionary:
	var o := _rescue_raw(attempt)
	o["lost"] = int(o.index) < 0
	o["coins"] = int(s.coins)
	o["inv_move"] = Wallet.inv_count(s, "move")
	if not o.lost:
		log_event("rescue_show", {"level": int(attempt.level), "price": o.price,
			"remaining": o.remaining, "index": o.index})
	return o


## method: "inventory" | "gold" | "video". Thành công thì board +3 MOVES.
func rescue_accept(attempt: Dictionary, method: String) -> bool:
	var o := _rescue_raw(attempt)
	if int(o.index) < 0:
		return false
	match method:
		"inventory":
			if not o.use_inventory:
				return false
		"gold":
			if int(s.coins) < int(o.price):
				return false
		"video":
			if not o.video:
				return false
			if not await watch("continue_moves"):
				return false
			o = _rescue_raw(attempt)
			if int(o.index) < 0:
				return false
		_:
			return false
	var res: Dictionary = (attempt.rescue as RescueFlow).accept(method)
	if res.is_empty():
		return false
	var price := int(res.price)
	if price > 0 and not spend_coins(price, "rescue"):
		return false
	if method == "inventory":
		Wallet.inv_use(s, "move")
		inv_changed.emit()
	(attempt.board as BoardState).add_moves(int(res.moves))
	log_event("rescue_use", {"level": int(attempt.level), "method": method, "price": price, "index": o.index})
	save_now()
	return true


func rescue_skip(attempt: Dictionary) -> void:
	_rescue_raw(attempt)
	(attempt.rescue as RescueFlow).skip()


# --- quà 28 ngày ---

func daily_view() -> Dictionary:
	return DailyCalendar.view(s, today(), int(s.level))


func _give(reward: Dictionary, source: String) -> void:
	_earn(int(reward.get("coins", 0)), source)
	var items: Dictionary = reward.get("items", {})
	for k in items:
		Wallet.inv_add(s, str(k), int(items[k]))
	if not items.is_empty():
		inv_changed.emit()
	var inf_min := int(reward.get("inf_min", 0))
	if inf_min > 0:
		Lives.grant_infinite(s, inf_min * 60, now())
		lives_changed.emit()


func daily_claim() -> Dictionary:
	if not bool(daily_view().open):
		return {}
	var reward := DailyCalendar.claim(s, today())
	if reward.is_empty():
		return {}
	_give(reward, "daily")
	log_event("daily_claim", {"idx": int(s.daily.idx), "coins": int(reward.get("coins", 0)), "next": 0})
	save_now()
	return reward


## Xem video nhận trước ô kế tiếp, 1 lần mỗi ngày, sau khi đã nhận ô hiện tại.
func daily_claim_next() -> Dictionary:
	var v := daily_view()
	if not bool(v.open) or not bool(v.can_ad_next):
		return {}
	if not await watch("daily_next"):
		return {}
	var reward := DailyCalendar.claim_next_ad(s, today())
	if reward.is_empty():
		return {}
	_give(reward, "daily_next")
	log_event("daily_claim", {"idx": int(s.daily.idx), "coins": int(reward.get("coins", 0)), "next": 1})
	save_now()
	return reward


## Tặng booster hướng dẫn tới hạn ("" nếu không có). Gọi lặp tới khi hết.
func claim_gift() -> String:
	var k := Unlocks.pending_gift(s, int(s.level))
	if k == "":
		return ""
	Unlocks.mark_gifted(s, k)
	Wallet.inv_add(s, k, 1)
	inv_changed.emit()
	save_now()
	return k


# --- cosmetic ---

func cos_buy(id: String) -> bool:
	var price := Config.cosmetic_price(id)
	if not Cosmetics.buy(s, id):
		return false
	if price > 0:
		Platform.spend("gold", price, "cosmetic")
	coins_changed.emit(int(s.coins))
	cos_changed.emit()
	log_event("cos_buy", {"id": id, "price": price, "how": "gold"})
	save_now()
	return true


func cos_unlock_video(id: String) -> bool:
	if Cosmetics.kind_of(id) == "" or Cosmetics.is_owned(s, id):
		return false
	if not await watch("cosmetic_unlock"):
		return false
	if not Cosmetics.unlock(s, id):
		return false
	cos_changed.emit()
	log_event("cos_buy", {"id": id, "price": 0, "how": "video"})
	save_now()
	return true


func cos_equip(id: String) -> bool:
	if not Cosmetics.equip(s, id):
		return false
	cos_changed.emit()
	_queue_save()
	return true


# --- shop và mua hàng ---

func shop_watch_video() -> bool:
	if ShopVideos.remaining(s, today()) <= 0:
		return false
	if not await watch("shop_coins"):
		return false
	var g := ShopVideos.note_watch(s, today())
	if g <= 0:
		return false
	_earn(g, "shop_coins")
	save_now()
	return true


func shop_videos_left() -> int:
	return ShopVideos.remaining(s, today())


func shop_opened(source: String = "") -> void:
	log_event("shop_open", {"source": source, "level": int(s.level)})


## Người chơi đã từng mua gói nào chưa (mode 2 của weekend sale).
func has_purchased() -> bool:
	return not s.buys.is_empty()


## Weekend sale đang bật cho người chơi này không (mode Remote Config, ngày, lịch sử mua).
func is_sale_active() -> bool:
	return Offers.is_sale(now(), _tz(), has_purchased())


## Gói gold theo giá sale hôm nay, thêm `price_text` từ store. Lúc sale có thêm
## `base_price_text` (giá gói thường để gạch) và `sale_percent`.
func shop_catalog() -> Array:
	var out := Offers.catalog(now(), _tz(), has_purchased())
	for e in out:
		e["price_text"] = Platform.price(str(e.sku))
		if bool(e.sale):
			e["base_price_text"] = Platform.price(str(e.base_sku))
			e["sale_percent"] = Config.SALE_PERCENT
	return out


## {status, granted}. Cộng hàng và lưu rồi mới `finish`. `invalid`, `cancel`, `pending`: không thưởng.
func buy_sku(sku: String) -> Dictionary:
	if not Config.SKUS.has(sku):
		return {"status": "error", "sku": sku, "granted": false}
	_buying += 1
	var r: Dictionary = await Platform.buy(sku)
	_buying -= 1
	var granted := false
	if str(r.get("status", "")) == "ok":
		granted = grant_purchase(r)
	return {"status": str(r.get("status", "error")), "sku": sku, "granted": granted}


## Giao một đơn (mỗi token một lần; món mua một lần không giao lại khi restore).
## Luôn `finish` đơn đã xử lý xong. Trả true nếu đã cộng hàng.
func grant_purchase(p: Dictionary) -> bool:
	var token := str(p.get("token", ""))
	var sku := str(p.get("sku", ""))
	if token == "" or str(p.get("status", "ok")) != "ok":
		return false
	var info: Dictionary = Config.SKUS.get(sku, {})
	var consumable := bool(info.get("consumable", true))
	var dup := false
	for e in s.buys:
		if e is Dictionary and (str(e.get("token", "")) == token \
				or (not consumable and str(e.get("sku", "")) == sku)):
			dup = true
	if dup or info.is_empty():
		if not info.is_empty():
			Platform.finish(p, consumable)
		return false
	_give({"coins": int(info.get("gold", 0)), "items": info.get("inv", {})}, "iap_" + sku)
	if bool(info.get("no_ads", false)):
		s["no_ads"] = true
	if bool(info.get("weekly_vip", false)):
		weekly_refresh()
		WeeklyPass.on_vip_purchased(s)
		_apply_weekly_hearts()
		log_event("weekly_vip", {"points": WeeklyPass.points(s)})
	(s.buys as Array).append({"token": token, "sku": sku, "order_id": str(p.get("order_id", "")), "at": now()})
	for id in Offers.ORDER:
		if str(Config.OFFERS.get(id, {}).get("sku", "")) == sku:
			Offers.bought(s, id, now())
			log_event("offer_buy", {"id": id, "sku": sku})
	save_now()
	Platform.finish(p, consumable)
	return true


func restore_purchases() -> bool:
	var ok: bool = await Platform.restore()
	for p in Platform.pending():
		if p is Dictionary:
			grant_purchase(p)
	return ok


# --- offer ---

## Offer cần hiện bây giờ ("" nếu không). Có thì ghi `shown`, log offer_show, phát offer_ready.
func check_offer(on_lose: bool = false) -> String:
	var t := now()
	var ctx := {
		"now": t, "day": today(), "level": int(s.level), "runs": int(s.runs),
		"session_start": _session_start, "first_session": _first_session,
		"inter_today": AdPacing.inter_count_today(s, today()), "on_lose": on_lose,
	}
	var id := Offers.due(s, ctx)
	if id == "":
		return ""
	Offers.shown(s, id, ctx)
	log_event("offer_show", {"id": id, "level": int(s.level)})
	save_now()
	offer_ready.emit(id)
	return id


## Mua offer qua SKU của nó (Offers.bought được ghi trong grant_purchase).
func offer_buy(id: String) -> Dictionary:
	var sku := offer_sku(id)
	if sku == "":
		return {"status": "error", "sku": "", "granted": false}
	return await buy_sku(sku)


func offers_open() -> Array:
	return Offers.open_offers(s, now())


## SKU bán của offer hoặc gói (Config.OFFERS, rồi Config.PACKS). Lúc weekend sale đổi sang `<sku>_sale`
## nếu SKU đó tồn tại. "" nếu id lạ.
func offer_sku(id: String) -> String:
	var sku := str(Config.OFFERS.get(id, {}).get("sku", ""))
	if sku == "":
		sku = str(Config.PACKS.get(id, {}).get("sku", ""))
	if sku != "" and is_sale_active() and Config.SKUS.has(sku + PackConditions.SALE_SUFFIX):
		return sku + PackConditions.SALE_SUFFIX
	return sku


# --- Special Pack ---

## Gói cần hiện icon ở Main Menu bây giờ ("" nếu không). Mỗi lần chỉ một gói.
func special_pack_id() -> String:
	return PackConditions.first_visible(s, int(s.level))


# --- Weekly Pass ---

## Level mở Weekly Pass: level HARD thứ `unlock_hard_index` (người chơi phải qua level đó). 0 nếu không có.
func weekly_unlock_level() -> int:
	var want := maxi(int(Config.WEEKLY.get("unlock_hard_index", 2)), 1)
	var seen := 0
	var cap := 400
	for lv in range(1, cap + 1):
		if not level_exists(lv):
			break
		if difficulty_of(lv) != "":
			seen += 1
			if seen >= want:
				return lv
	return 0


func weekly_unlocked() -> bool:
	var u := weekly_unlock_level()
	return u > 0 and int(s.level) > u


func weekly_state() -> String:
	return WeeklyPass.state(now(), _tz(), weekly_unlocked())


## Sang mùa nếu cần (VIP tự nhận thưởng tồn), cập nhật max mạng. Trả reward đã cộng.
func weekly_refresh() -> Dictionary:
	var r := WeeklyPass.refresh(s, now(), _tz())
	if bool(r.settled):
		_give(r.reward, "weekly_settle")
		log_event("weekly_end", {"coins": int(r.reward.coins)})
	_apply_weekly_hearts()
	if bool(r.settled):
		save_now()
	return r


## Đặt s.lives.bonus theo state; tăng thì cộng luôn vào số mạng hiện có.
func _apply_weekly_hearts() -> void:
	var bonus := WeeklyPass.heart_bonus(s, weekly_state())
	var l: Dictionary = s.lives
	var old := int(l.get("bonus", 0))
	if bonus == old:
		return
	l["bonus"] = bonus
	if bonus > old:
		l["count"] = int(l.count) + (bonus - old)
	Lives.tick(s, now())
	lives_changed.emit()


## Mọi thứ Home và layer cần: {state, unlocked, seconds_left, points, vip, badge, dot, main, bank, ...}.
func weekly_view() -> Dictionary:
	var st := weekly_state()
	var w: Dictionary = s.weekly
	var main_rows: Array = []
	var ms := WeeklyPass.main_milestones()
	for i in ms.size():
		main_rows.append({
			"index": i, "points": int(ms[i].points), "free": ms[i].free, "vip": ms[i].vip,
			"free_claimed": WeeklyPass._has(w.claimed_free, i), "vip_claimed": WeeklyPass._has(w.claimed_vip, i),
			"free_claimable": WeeklyPass.free_claimable(s, i), "vip_claimable": WeeklyPass.vip_claimable(s, i),
		})
	var bank_rows: Array = []
	for i in int(Config.WEEKLY.get("bank_max", 10)):
		bank_rows.append({
			"index": i, "reached": i < WeeklyPass.bank_slots(s),
			"claimed": WeeklyPass._has(w.claimed_bank, i), "claimable": WeeklyPass.bank_claimable(s, i),
			"coins": int(Config.WEEKLY.get("bank_reward_coins", 0)),
		})
	var pending := not (w.pending_end as Dictionary).is_empty()
	return {
		"state": st, "unlocked": st != WeeklyPass.LOCKED,
		"seconds_left": WeeklyPass.seconds_left(now(), _tz(), st),
		"points": WeeklyPass.points(s), "last_points": WeeklyPass.last_points(),
		"vip": WeeklyPass.is_vip(s), "vip_price": Platform.price(str(Config.WEEKLY.sku)),
		"badge": WeeklyPass.claimable_count(s) if st == WeeklyPass.ACTIVE else 0,
		"dot": pending or (st == WeeklyPass.ACTIVE and not bool(w.opened)),
		"pending_end": pending, "main": main_rows, "bank": bank_rows,
		"bank_unlocked": WeeklyPass.bank_unlocked(s), "bank_slots": WeeklyPass.bank_slots(s),
		"bonus_hearts": int(Config.WEEKLY.get("vip_bonus_hearts", 3)),
		"tut_seen": WeeklyPass.tutorial_seen(s), "tut_row": WeeklyPass.tutorial_row(s),
		"progress": WeeklyPass.progress_ratio(s),
	}


## Đã xem tutorial Weekly Pass chưa. Chưa xem thì thắng level không cộng key.
func weekly_tutorial_seen() -> bool:
	return WeeklyPass.tutorial_seen(s)


## Xong tutorial (bước cuối): lưu cờ để key bắt đầu được cộng.
func weekly_mark_tutorial_seen() -> void:
	if WeeklyPass.tutorial_seen(s):
		return
	WeeklyPass.mark_tutorial_seen(s)
	log_event("weekly_tutorial", {"points": WeeklyPass.points(s)})
	save_now()


## Người chơi mở layer. Ghi đã mở chu kỳ này, End popup nếu đã đủ điểm.
func weekly_opened() -> void:
	WeeklyPass.mark_opened(s)
	WeeklyPass.mark_end_seen(s)
	log_event("weekly_open", {"points": WeeklyPass.points(s), "vip": 1 if WeeklyPass.is_vip(s) else 0})
	_queue_save()


func weekly_take_end() -> Dictionary:
	var p := WeeklyPass.take_pending_end(s)
	if not p.is_empty():
		_queue_save()
	return p


func _weekly_give(reward: Dictionary, kind: String) -> Dictionary:
	if reward.is_empty():
		return {}
	_give(reward, "weekly_" + kind)
	log_event("weekly_claim", {"kind": kind, "coins": int(reward.get("coins", 0)), "points": WeeklyPass.points(s)})
	save_now()
	return reward


func weekly_claim_free(i: int) -> Dictionary:
	if weekly_state() != WeeklyPass.ACTIVE:
		return {}
	return _weekly_give(WeeklyPass.claim_free(s, i), "free")


func weekly_claim_vip(i: int) -> Dictionary:
	if weekly_state() != WeeklyPass.ACTIVE:
		return {}
	return _weekly_give(WeeklyPass.claim_vip(s, i), "vip")


## Nhận hết Main Tree và Bonus Bank đang nhận được. Trả thưởng gộp ({} nếu không có gì).
func weekly_claim_all() -> Dictionary:
	if weekly_state() != WeeklyPass.ACTIVE:
		return {}
	var total := WeeklyPass.claim_all_main(s)
	var r: Dictionary = total.reward
	var bank := WeeklyPass.claim_all_bank(s)
	r = WeeklyPass.merge(r, bank.reward)
	if int(total.count) + int(bank.count) == 0:
		return {}
	return _weekly_give(r, "all")


func weekly_claim_bank(i: int) -> Dictionary:
	if weekly_state() != WeeklyPass.ACTIVE:
		return {}
	return _weekly_give(WeeklyPass.claim_bank(s, i), "bank")


## Mua VIP của chu kỳ này (chỉ khi Active và chưa VIP). Kết quả như buy_sku.
func weekly_buy_vip() -> Dictionary:
	var sku := str(Config.WEEKLY.sku)
	if weekly_state() != WeeklyPass.ACTIVE or WeeklyPass.is_vip(s):
		return {"status": "error", "sku": sku, "granted": false}
	return await buy_sku(sku)


# --- Leaderboard ---

## Mở từ Config.UNLOCK.leaderboard (và Config.LEADERBOARD.enabled).
func lb_open() -> bool:
	return Leaderboard.enabled() and Unlocks.is_open("leaderboard", int(s.level))


## Vào BXH khi vừa mở khoá, bù điểm bot theo ngày BXH. Gọi lúc boot, resume, bắt đầu level, trước khi đọc view.
func lb_refresh() -> void:
	if not lb_open():
		return
	var t := now()
	if Leaderboard.join(s, t):
		log_event("lb_join", {"level": int(s.level), "league": Leaderboard.league_id(Leaderboard.league(s))})
		_queue_save()
	if Leaderboard.grow(s, t) > 0:
		_queue_save()


## Cộng mảnh của level vừa thắng. Trả kết quả Leaderboard.add_points thêm league_id, league_min, next_min,
## next_league ({} nếu không có mảnh). Người gọi lưu.
func _lb_award(attempt: Dictionary) -> Dictionary:
	var n := int(attempt.get("pieces", 0))
	if n <= 0 or not lb_open():
		return {}
	lb_refresh()
	var r := Leaderboard.add_points(s, n)
	if r.is_empty():
		return {}
	var li := int(r.league_after)
	r["league_id"] = Leaderboard.league_id(li)
	r["league_min"] = Leaderboard.league_min(li)
	r["next_min"] = Leaderboard.next_min(li)
	r["next_league"] = "" if Leaderboard.is_top(li) else Leaderboard.league_id(li + 1)
	log_event("lb_points", {"level": int(attempt.level), "points": n, "total": int(r.after), "rank": int(r.rank_after)})
	for k in r.promoted:
		log_event("lb_promote", {"league": Leaderboard.league_id(int(k)), "points": int(r.after)})
	return r


## Mọi thứ màn Leaderboard (tab League) cần: {open, unlock_level, league, league_index, league_count, points,
## league_min, next_min, next_league, progress, rank, size, delta, top_percent, refresh_in, podium, rows, pending}.
## podium: 3 hàng đầu; rows: tối đa view_size hàng quanh người chơi. Hàng như Leaderboard.standings.
func lb_view() -> Dictionary:
	lb_refresh()
	var li := Leaderboard.league(s)
	var rows := Leaderboard.standings(s)
	var rank := Leaderboard.rank(s)
	var seen := Leaderboard.seen_rank(s)
	var pts := Leaderboard.points(s)
	var lo := Leaderboard.league_min(li)
	var nxt := Leaderboard.next_min(li)
	return {
		"open": lb_open(), "unlock_level": int(Config.UNLOCK.get("leaderboard", 0)),
		"league": Leaderboard.league_id(li), "league_index": li, "league_count": Leaderboard.leagues().size(),
		"points": pts, "league_min": lo, "next_min": nxt,
		"next_league": "" if nxt < 0 else Leaderboard.league_id(li + 1),
		"progress": 1.0 if nxt < 0 else clampf(float(pts - lo) / float(maxi(nxt - lo, 1)), 0.0, 1.0),
		"rank": rank, "size": rows.size(), "delta": seen - rank if seen > 0 else 0,
		"top_percent": Leaderboard.top_percent(s), "refresh_in": Leaderboard.seconds_to_grow(now()),
		"podium": rows.slice(0, 3), "rows": Leaderboard.window(rows, rank),
		"pending": not Leaderboard.pending(s).is_empty(),
	}


## Tab World Ranking: Leaderboard.world thêm points và league (id) của người chơi.
func lb_world_view() -> Dictionary:
	lb_refresh()
	var w := Leaderboard.world(s, now())
	w["points"] = Leaderboard.points(s)
	w["league"] = Leaderboard.league_id(Leaderboard.league(s))
	return w


## Popup Leagues: {current, points, rows: [{id, min, max (-1 ở league cuối), reward, reached, current}]}.
func lb_leagues_view() -> Dictionary:
	var cur := Leaderboard.league(s)
	var rows: Array = []
	for i in Leaderboard.leagues().size():
		var nxt := Leaderboard.next_min(i)
		rows.append({"id": Leaderboard.league_id(i), "min": Leaderboard.league_min(i),
			"max": nxt - 1 if nxt >= 0 else -1, "reward": Leaderboard.reward_of(i),
			"reached": i <= cur and Leaderboard.joined(s), "current": i == cur})
	return {"current": Leaderboard.league_id(cur), "points": Leaderboard.points(s), "rows": rows}


## Người chơi mở màn Leaderboard: ghi hạng đang thấy (lần sau hiện ▲/▼ so với hạng này).
func lb_opened() -> void:
	if not lb_open():
		return
	Leaderboard.mark_seen(s)
	log_event("lb_open", {"league": Leaderboard.league_id(Leaderboard.league(s)), "rank": Leaderboard.rank(s),
		"points": Leaderboard.points(s)})
	_queue_save()


## Popup lên league đang chờ: {leagues: [id...], league (league cao nhất vừa vào), reward} hoặc {} nếu không có.
func lb_pending_view() -> Dictionary:
	var p := Leaderboard.pending(s)
	if p.is_empty():
		return {}
	var ids: Array = []
	for li in p:
		ids.append(Leaderboard.league_id(int(li)))
	return {"leagues": ids, "league": ids[ids.size() - 1], "reward": Leaderboard.pending_reward(s)}


## Nhận thưởng các league đang chờ. Trả thưởng đã cộng ({} nếu không có).
func lb_claim() -> Dictionary:
	var r := Leaderboard.claim(s)
	if r.is_empty():
		return {}
	_give(r, "lb_league")
	log_event("lb_claim", {"league": Leaderboard.league_id(Leaderboard.league(s)), "coins": int(r.get("coins", 0))})
	save_now()
	return r


# --- Chain Offer ---

## Xét bật chuỗi sau một ván. Gọi trước save_now của người gọi.
func _chain_check(lost: bool, level: int) -> void:
	var t := now()
	ChainOffer.update(s, t)
	if not ChainOffer.should_trigger(lost, difficulty_of(level) != ""):
		return
	if ChainOffer.try_activate(s, t, int(s.level)):
		log_event("chain_start", {"id": str(s.chain.id), "level": int(s.level)})


## {id, steps, step, count, expires, seconds_left} hoặc {} khi không có chuỗi.
func chain_view() -> Dictionary:
	return ChainOffer.current(s, now())


## Popup tự mở đúng một lần mỗi chuỗi: true thì gọi chain_view và mở layer.
func chain_take_autoshow() -> bool:
	if not ChainOffer.should_autoshow(s, now()):
		return false
	ChainOffer.mark_shown(s)
	save_now()
	return true


## Nhận bước hiện tại. free: nhận luôn; ad: xem hết quảng cáo; pay: mua SKU của bước.
## Trả {ok, type, reward, status}.
func chain_claim() -> Dictionary:
	var st := ChainOffer.current_step(s, now())
	if st.is_empty():
		return {"ok": false, "type": "", "reward": {}, "status": "none"}
	var type := str(st.get("type", "free"))
	var cid := str(s.chain.id)
	var idx := int(s.chain.step)
	if type == "ad":
		if not await watch("chain_offer"):
			return {"ok": false, "type": type, "reward": {}, "status": last_ad_reason}
	elif type == "pay":
		var r: Dictionary = await buy_sku(str(st.get("sku", "")))
		if not bool(r.get("granted", false)):
			return {"ok": false, "type": type, "reward": {}, "status": str(r.get("status", "error"))}
	# Có thể hết hạn trong lúc xem quảng cáo hoặc thanh toán: vẫn trao phần đã làm xong.
	if not (bool(s.chain.active) and str(s.chain.id) == cid and int(s.chain.step) == idx):
		if type == "pay":
			return {"ok": true, "type": type, "reward": {}, "status": "ok"}
		var late := {"coins": int(st.get("coins", 0)), "items": (st.get("items", {}) as Dictionary).duplicate()}
		_give(late, "chain_" + type)
		save_now()
		return {"ok": true, "type": type, "reward": late, "status": "ok"}
	var adv := ChainOffer.advance(s, now())
	if adv.is_empty():
		return {"ok": false, "type": type, "reward": {}, "status": "none"}
	if type != "pay":
		_give(adv.reward, "chain_" + type)
	log_event("chain_claim", {"id": cid, "step": idx, "type": type})
	save_now()
	return {"ok": true, "type": type, "reward": adv.reward, "status": "ok"}


# --- mạng ---

func lives_view() -> Dictionary:
	var t := now()
	var c := Lives.count(s, t)
	var level := int(s.level)
	var inf := Lives.infinite(s, t)
	return {
		"count": c, "max": Lives.max_for(s), "seconds_to_next": Lives.seconds_to_next(s, t),
		"open": Unlocks.is_open("lives", level),
		"infinite": inf, "infinite_left": Lives.infinite_left(s, t),
		"can_play": c > 0 or inf or level < int(Config.LIVES.from_level),
		"refill_price": int(Config.ECON.refill_coins), "refill_lives": int(Config.ECON.refill_lives),
		"can_refill_gold": c < Lives.max_for(s) and int(s.coins) >= int(Config.ECON.refill_coins),
		"video_ready": Platform.ready_rewarded(),
	}


func refill_gold() -> bool:
	var before := int(s.coins)
	if not Lives.refill_coins(s, now()):
		return false
	Platform.spend("gold", before - int(s.coins), "refill")
	coins_changed.emit(int(s.coins))
	lives_changed.emit()
	save_now()
	return true


func refill_video() -> bool:
	if Lives.count(s, now()) >= Lives.max_for(s):
		return false
	if not await watch("refill_life"):
		return false
	Lives.add(s, 1, now())
	lives_changed.emit()
	save_now()
	return true


# --- Daily Challenge (mở từ L50, không phải demo) ---

## Level id của thử thách hôm nay: level đã thắng gần nhất của người chơi (s.level - 1), kẹp vào [50, 300].
## Dùng level đã qua để cơ chế trên bàn luôn là cơ chế người chơi đã được dạy.
func challenge_level_id() -> int:
	return clampi(int(s.level) - 1, CHALLENGE_MIN_ID, int(Config.CONTENT.release_pregen_level))


## Bàn của ngày `day`: LevelGenerator.generate(id, seed) với id = challenge_level_id() và seed cơ sở =
## today() * 1000 (sinh lại seed kế tiếp nếu Solver không đạt). Cùng ngày + cùng level = cùng bàn.
func challenge_data(day: int = -1) -> Dictionary:
	var d := today() if day < 0 else day
	var id := challenge_level_id()
	return _generated("C%d:%d" % [d, id], id, d * SEED_STRIDE)


## {open, locked, unlock_level, available, won, coins, level}. Demo luôn khoá.
## `won`: đã thắng hôm nay. `available`: mở và chưa thắng hôm nay.
func challenge_view() -> Dictionary:
	var open := Unlocks.is_open("challenge", int(s.level)) and not Config.is_demo()
	var won: bool = int(s.challenge.get("day", -1)) == today() and bool(s.challenge.get("won", false))
	return {"open": open, "locked": not open, "unlock_level": int(Config.UNLOCK.challenge),
		"available": open and not won, "won": open and won,
		"coins": int(Config.ECON.challenge_coins), "level": challenge_level_id()}


## Attempt của thử thách hôm nay ({} nếu khoá, đã thắng hôm nay hoặc không sinh được). Cùng dạng
## start_attempt, thêm challenge = true; thắng/thua đi qua on_level_won / on_level_lost.
func start_challenge() -> Dictionary:
	if not bool(challenge_view().available):
		return {}
	var data := challenge_data()
	if data.is_empty():
		return {}
	return _begin_attempt(data, challenge_level_id(), true)


## Chưa có trong cache nên start_challenge sẽ phải sinh: UI hiện màn chờ.
func challenge_needs_generation() -> bool:
	return not _gen_cache.has("C%d:%d" % [today(), challenge_level_id()])


# --- cài đặt, rung, thông báo ---

func set_setting(key: String, value: Variant) -> void:
	s.settings[key] = value
	match key:
		"sfx", "music", "haptics":
			Sfx.apply_settings(s.settings)
		"lang":
			_apply_language()
		"notif":
			if bool(value):
				_replan_notifications()
			else:
				Platform.cancel_all()
	_queue_save()


func haptic(ms: int) -> void:
	if bool(s.settings.get("haptics", true)):
		Platform.haptic(ms)


# --- tester menu (Config.account_tool: debug builds only) ---

## Sets account values straight from the tester menu: any of {coins, level, inv: {hint, move, smash}}. Not
## logged as earn/spend. Gold and boosters stay >= 0, level >= 1 (past the last level Home shows "coming soon").
## Returns false (nothing changed) when the build has no account tool.
func tester_edit(edits: Dictionary) -> bool:
	if not Config.account_tool():
		return false
	if edits.has("coins"):
		s["coins"] = maxi(int(edits.coins), 0)
	var inv: Dictionary = edits.get("inv", {})
	for k in inv:
		if Wallet.KINDS.has(k):
			s.inv[k] = maxi(int(inv[k]), 0)
	if edits.has("level"):
		s["level"] = maxi(int(edits.level), 1)
		# Weekly Pass hearts and the leaderboard depend on the level.
		weekly_refresh()
		lb_refresh()
	save_now()
	coins_changed.emit(int(s.coins))
	inv_changed.emit()
	lives_changed.emit()
	return true


## Deletes the account: save file and .bak, the platform's cloud backup and mock purchases, then boots again as
## a fresh install. The fresh save is pushed over the cloud copy right away (Platform.flush).
func tester_wipe() -> bool:
	if not Config.account_tool():
		return false
	_remove_save_files()
	Platform.wipe()
	_clear_session()
	await boot()
	Platform.flush()
	return true


func _notif_candidates() -> Array:
	var out: Array = []
	var t := now()
	var level := int(s.level)
	if Unlocks.is_open("daily_gift", level):
		out.append("daily_gift")
	if Unlocks.is_open("lives", level):
		var c := Lives.count(s, t)
		var mx := Lives.max_for(s)
		if c < mx:
			var full_at := int(s.lives.next_at) + (mx - c - 1) * int(Config.LIVES.regen_sec)
			out.append({"kind": "lives_full", "at": full_at})
	for o in Offers.open_offers(s, t):
		out.append({"kind": "offer_open", "until": int(o.until)})
		break
	out.append("come_back")
	return out


func _replan_notifications() -> void:
	if not bool(s.settings.get("notif", true)) or not Platform.enabled():
		Platform.cancel_all()
		return
	var plan := NotifPlan.plan(s, now(), _tz(), _notif_candidates())
	var items: Array = []
	for e in plan:
		var kind := str(e.kind)
		items.append({"at": int(e.at), "kind": kind,
			"title": tr("notif_%s_title" % kind), "body": tr("notif_%s_body" % kind)})
	Platform.schedule(items)
	_queue_save()
