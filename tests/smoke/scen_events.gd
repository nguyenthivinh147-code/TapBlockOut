extends RefCounted
## Kịch bản smoke cho sự kiện mua hàng (design.md mục 7 "Sự kiện: Weekly Pass, Chain Offer, Special Pack").
## Gọi qua scenarios.gd SCEN_FILES. Mỗi hàm nhận runner `r` (tests/smoke/smoke.gd) như kịch bản trong scenarios.gd.
## Mua qua store giả (r.plat.iap là MockIap: headless trả ngay `ok`, có màn hình thì Scen.settle bấm "Mua" trên lớp
## phủ), video qua ads giả; số mong đợi của CO, SP đọc từ Config, của WP ghi thẳng từ tests/cases/WP.csv. Giờ chỉ
## đổi bằng r.game.test_now: smoke.gd đặt giờ cố định NOW (thứ Sáu 08:00 giờ máy giả lập), lúc đó mùa Weekly Pass đang
## Active và đang weekend sale.

const Scen := preload("res://tests/smoke/scenarios.gd")
const Saves := preload("res://tests/smoke/smoke_saves.gd")
const Config := preload("res://src/config.gd")
const WeeklyPass := preload("res://src/meta/weekly_pass.gd")

const DAY := 86400
const BOOSTERS := ["hint", "move", "smash"]


static func run(r, scen: String) -> bool:
	match scen:
		"WP":
			return await scen_wp(r)
		"CO":
			return await scen_co(r)
		"SP":
			return await scen_sp(r)
	return r.fail("không có kịch bản %s" % scen)


# ================================================================ Weekly Pass

## WP. Weekly Pass theo test case tests/cases/WP.csv (design.md mục 7 "Weekly Pass"; docs/TESTING.md "Test case"):
## mỗi case AUTO `smoke:WP` có chỗ chấm r.tc / r.tc_look với đúng ID, đặt lúc kết quả thấy được; số kỳ
## vọng ghi thẳng từ cột EXPECTED RESULT cạnh ID. Config và hàm của game chỉ dùng để dựng save và điều khiển.
## Kịch bản là chuỗi phần (WP_PARTS: các luồng, rồi bố cục nhiều tỉ lệ màn và 14 ngôn ngữ). Mỗi phần mở game với
## save dựng theo PRE COND (_wp_open) nên độc lập: phần dừng giữa chừng thì case chưa chấm của nó là blocked, các phần
## sau vẫn chạy, kịch bản vẫn fail. Tắt app (TC_CA_WP_018, 077, 078, 098) là Platform.paused rồi bỏ mọi trạng thái trong
## bộ nhớ của Game và mở lại main trên cùng save (_wp_relaunch, cùng tiến trình). SMOKE_ARGS="parts=bank,drag" chỉ
## chạy các phần đó (lúc viết kịch bản; case của phần khác sẽ missing).

const RewardFly := preload("res://src/ui/reward_fly.gd")

## [tên phần, ID các case chấm trong phần], theo thứ tự chạy.
const WP_PARTS := [
	["unlock", ["TC_CA_WP_004", "TC_CA_WP_001", "TC_CA_WP_015"]],
	["locked", ["TC_CA_WP_002"]],
	["active", ["TC_CA_WP_005"]],
	["waiting", ["TC_CA_WP_006"]],
	["open_0600", ["TC_CA_WP_009"]],
	["badge", ["TC_CA_WP_013"]],
	["tutorial", ["TC_CA_WP_016"]],
	["back_tut", ["TC_CA_WP_017"]],
	["kill_tut", ["TC_CA_WP_018"]],
	["howto", ["TC_CA_WP_019", "TC_CA_WP_093"]],
	["spam_tut", ["TC_CA_WP_022"]],
	["key_normal", ["TC_CA_WP_024"]],
	["key_hard", ["TC_CA_WP_025"]],
	["key_vhard", ["TC_CA_WP_026"]],
	["no_tut_win", ["TC_CA_WP_027"]],
	["waiting_win", ["TC_CA_WP_028"]],
	["lose", ["TC_CA_WP_029"]],
	["x2", ["TC_CA_WP_031"]],
	["cross_week", ["TC_CA_WP_033"]],
	["claim_free0", ["TC_CA_WP_035"]],
	["claim_free1", ["TC_CA_WP_036"]],
	["claim_free2", ["TC_CA_WP_037"]],
	["tap_locked", ["TC_CA_WP_040", "TC_CA_WP_041"]],
	["tap_claimed", ["TC_CA_WP_042"]],
	["spam_card", ["TC_CA_WP_043"]],
	["card_states", ["TC_CA_WP_044"]],
	["claim_vip1", ["TC_CA_WP_045"]],
	["use_rewards", ["TC_CA_WP_047"]],
	["claim_all", ["TC_CA_WP_048"]],
	["claim_all_vip", ["TC_CA_WP_049"]],
	["spam_all", ["TC_CA_WP_050"]],
	["bank", ["TC_CA_WP_051"]],
	["bank_locked", ["TC_CA_WP_052"]],
	["buy_vip", ["TC_CA_WP_056"]],
	["buy_fail", ["TC_CA_WP_057", "TC_CA_WP_061", "TC_CA_WP_058", "TC_CA_WP_059"]],
	["buy_wait", ["TC_CA_WP_095", "TC_CA_WP_062"]],
	["waiting_open", ["TC_CA_WP_069"]],
	["upsell", ["TC_CA_WP_070", "TC_CA_WP_072"]],
	["upsell_buy", ["TC_CA_WP_071"]],
	["upsell_cancel", ["TC_CA_WP_074"]],
	["upsell_spam", ["TC_CA_WP_075"]],
	["season_vip", ["TC_CA_WP_077"]],
	["season_free", ["TC_CA_WP_078"]],
	["season_none", ["TC_CA_WP_079"]],
	["resume_settle", ["TC_CA_WP_082"]],
	["layer_cross", ["TC_CA_WP_083"]],
	["layer_content", ["TC_CA_WP_090"]],
	["drag", ["TC_CA_WP_094"]],
	["kill_save", ["TC_CA_WP_098"]],
	["offline", ["TC_CA_WP_099"]],
	["analytics", ["TC_CA_WP_103"]],
	["perf", ["TC_CA_WP_104"]],
	["cells", ["TC_CA_WP_034"]],
	["res", ["TC_CA_WP_014", "TC_CA_WP_021", "TC_CA_WP_020", "TC_CA_WP_091", "TC_CA_WP_076"]],
	["lang_ui", ["TC_CA_WP_020", "TC_CA_WP_076", "TC_CA_WP_096"]],
	["langs", ["TC_CA_WP_092"]],
]
## Cỡ cửa sổ của case nhiều tỉ lệ màn (SMOKE_RES): 886×1920, 20:9, 21:9, 4:3.
const WP_RES_STD := Vector2i(443, 960)
const WP_RES_20_9 := Vector2i(540, 1200)
const WP_RES_21_9 := Vector2i(432, 1008)
const WP_RES_4_3 := Vector2i(768, 1024)
const WP_RAW_KEY := "^[a-z][a-z0-9]*(_[a-z0-9]+)+$"


## Store giả giữ giao dịch tới khi smoke thả (`hold` = false), để thấy lúc "đang chờ store" cả khi headless (TC_CA_WP_062,
## 095). Kết quả lấy từ simulate() như MockIap; có kết quả trong hàng đợi thì không hiện lớp phủ.
class SlowIap extends "res://src/platform/mock_iap.gd":
	var hold := true
	var entered := 0

	func buy(sku: String) -> Dictionary:
		entered += 1
		while hold:
			await (Engine.get_main_loop() as SceneTree).process_frame
		return await super(sku)


static func scen_wp(r) -> bool:
	var parts: Array = WP_PARTS
	var only: PackedStringArray = str(r.args.get("parts", "")).split(",", false)
	# Headless bỏ qua --resolution (cửa sổ 64x64, canvas vuông 1920x1920): đặt tỉ lệ máy 886x1920 như SMOKE_RES mặc định,
	# để chạm dồn và hit-test rơi đúng chỗ như trên điện thoại.
	if DisplayServer.get_name() == "headless":
		r.root.size = WP_RES_STD
		await r.wait_frames(3)
	var keep_size: Vector2i = r.root.size
	var broken: Array[String] = []
	for part: Array in parts:
		var name := str(part[0])
		if not only.is_empty() and not only.has(name):
			continue
		var t0 := Time.get_ticks_msec()
		r.step("== phần %s: %s" % [name, ", ".join(PackedStringArray(part[1]))])
		var ok: bool = await _wp_part(r, name)
		if r.root.size != keep_size:
			r.root.size = keep_size
		var why := str(r.failed_reason)
		if not ok or not why.is_empty():
			if why.is_empty():
				why = "dừng"
			broken.append("%s (%s)" % [name, why])
			var graded: Dictionary = r._cases
			for id: String in part[1]:
				if not graded.has(id):
					r.tc_blocked(id, "phần %s dừng: %s" % [name, why])
			r.failed_reason = ""
		r.step("== phần %s xong sau %.1f giây" % [name, (Time.get_ticks_msec() - t0) / 1000.0])
	if not broken.is_empty():
		return r.fail("Weekly Pass: %d phần dừng giữa chừng: %s" % [broken.size(), "; ".join(broken)])
	return await Scen.verify_saved(r)


static func _wp_part(r, name: String) -> bool:
	match name:
		"unlock":
			return await _wpp_unlock(r)
		"locked":
			return await _wpp_locked(r)
		"active":
			return await _wpp_active(r)
		"waiting":
			return await _wpp_waiting(r)
		"open_0600":
			return await _wpp_open_0600(r)
		"badge":
			return await _wpp_badge(r)
		"tutorial":
			return await _wpp_tutorial(r)
		"back_tut":
			return await _wpp_back_tut(r)
		"kill_tut":
			return await _wpp_kill_tut(r)
		"howto":
			return await _wpp_howto(r)
		"spam_tut":
			return await _wpp_spam_tut(r)
		"key_normal":
			return await _wpp_key_normal(r)
		"key_hard":
			return await _wpp_key_hard(r)
		"key_vhard":
			return await _wpp_key_vhard(r)
		"no_tut_win":
			return await _wpp_no_tut_win(r)
		"waiting_win":
			return await _wpp_waiting_win(r)
		"lose":
			return await _wpp_lose(r)
		"x2":
			return await _wpp_x2(r)
		"cross_week":
			return await _wpp_cross_week(r)
		"claim_free0":
			return await _wpp_claim_free0(r)
		"claim_free1":
			return await _wpp_claim_free1(r)
		"claim_free2":
			return await _wpp_claim_free2(r)
		"tap_locked":
			return await _wpp_tap_locked(r)
		"tap_claimed":
			return await _wpp_tap_claimed(r)
		"spam_card":
			return await _wpp_spam_card(r)
		"card_states":
			return await _wpp_card_states(r)
		"claim_vip1":
			return await _wpp_claim_vip1(r)
		"use_rewards":
			return await _wpp_use_rewards(r)
		"claim_all":
			return await _wpp_claim_all(r)
		"claim_all_vip":
			return await _wpp_claim_all_vip(r)
		"spam_all":
			return await _wpp_spam_all(r)
		"bank":
			return await _wpp_bank(r)
		"bank_locked":
			return await _wpp_bank_locked(r)
		"buy_vip":
			return await _wpp_buy_vip(r)
		"buy_fail":
			return await _wpp_buy_fail(r)
		"buy_wait":
			return await _wpp_buy_wait(r)
		"waiting_open":
			return await _wpp_waiting_open(r)
		"upsell":
			return await _wpp_upsell(r)
		"upsell_buy":
			return await _wpp_upsell_buy(r)
		"upsell_cancel":
			return await _wpp_upsell_cancel(r)
		"upsell_spam":
			return await _wpp_upsell_spam(r)
		"season_vip":
			return await _wpp_season_vip(r)
		"season_free":
			return await _wpp_season_free(r)
		"season_none":
			return await _wpp_season_none(r)
		"resume_settle":
			return await _wpp_resume_settle(r)
		"layer_cross":
			return await _wpp_layer_cross(r)
		"layer_content":
			return await _wpp_layer_content(r)
		"drag":
			return await _wpp_drag(r)
		"kill_save":
			return await _wpp_kill_save(r)
		"offline":
			return await _wpp_offline(r)
		"analytics":
			return await _wpp_analytics(r)
		"perf":
			return await _wpp_perf(r)
		"cells":
			return await _wpp_cells(r)
		"res":
			return await _wpp_res(r)
		"lang_ui":
			return await _wpp_lang_ui(r)
		"langs":
			return await _wpp_langs(r)
	return r.fail("không có phần %s" % name)


# ---------------------------------------------------------------- WP: mở khoá, chu kỳ, nút ở Home

## TC_CA_WP_004, 001, 015. Save L25, s.weekly mặc định, ts 1800000000: thắng L25 (mốc kế là Weekly Pass), thắng L26
## (HARD thứ 2), Tiếp tục vào thẳng L27, về Home, bấm dồn nút Weekly Pass.
static func _wpp_unlock(r) -> bool:
	if not await _wp_open(r, {"level": 25}):
		return false
	if (await _wp_win(r, 25)).is_empty():
		return false
	var f := await _wp_feature(r)
	# TC_CA_WP_004: "Next unlock: Weekly Pass"; thanh 80% → 90% ((25−17)/(27−17) → (26−17)/(27−17)).
	r.tc("TC_CA_WP_004", f.label == "Next unlock: Weekly Pass" and absf(float(f.before) - 0.8) < 0.001
		and absf(float(f.after) - 0.9) < 0.001 and f.pct == "90%",
		"thẻ thắng L25: dòng \"%s\", thanh %.2f → %.2f (\"%s\"); mong đợi \"Next unlock: Weekly Pass\", 0.80 → 0.90 (90%%)"
		% [f.label, float(f.before), float(f.after), f.pct])
	await r.tc_look("TC_CA_WP_004", "wp004_win_card_L25")
	if not await Scen.after_win(r, 25):
		return false
	if (await _wp_win(r, 26)).is_empty():
		return false
	f = await _wp_feature(r)
	var key := _cell(r, "WeeklyKeyReward")
	# TC_CA_WP_001: thẻ thắng L26 đầy 100%, "Weekly Pass unlocked!", không có ô chìa, points 0.
	r.tc("TC_CA_WP_001", f.label == "Weekly Pass unlocked!" and f.pct == "100%",
		"thẻ thắng L26: dòng \"%s\", \"%s\"; mong đợi \"Weekly Pass unlocked!\", 100%%" % [f.label, f.pct])
	r.tc("TC_CA_WP_001", key == null and WeeklyPass.points(r.game.s) == 0,
		"thẻ thắng L26: ô WeeklyKeyReward %s, points %d; mong đợi không có, 0" % [_shown(key),
		WeeklyPass.points(r.game.s)])
	r.tc("TC_CA_WP_001", int(r.game.s.level) == 27 and str(r.game.weekly_state()) == "active",
		"s.level %d, weekly_state %s; mong đợi 27, active" % [int(r.game.s.level), str(r.game.weekly_state())])
	var cont := await _wp_continue(r, 26)
	r.tc("TC_CA_WP_001", bool(cont.ok) and not bool(cont.home) and Scen._playing(r) == 27,
		"sau Tiếp tục: %s, level %d; mong đợi vào thẳng L27, không qua Home" % ["qua Home" if bool(cont.home)
		else r.screen_name(), Scen._playing(r)])
	if not await _wp_home(r):
		return false
	await r.wait_sec(1.2)
	var h := _home_wp(r)
	r.tc("TC_CA_WP_001", bool(h.visible) and h.caption == "Weekly Pass (1)" and bool(h.dot),
		"Home: WeeklyPassItem %s, Caption \"%s\", WeeklyDot %s; mong đợi hiện, \"Weekly Pass (1)\", hiện" % [
		_yes(h.visible), h.caption, _yes(h.dot)])
	# TC_CA_WP_015: 20 lần chạm WeeklyPassButton trong 1 giây.
	var btn := Scen.find_visible(r.main.current_screen, "WeeklyPassButton") as Control
	if btn == null:
		return r.fail("Home không có WeeklyPassButton")
	var errs := _errs(r)
	await r._wait_still(btn, Time.get_ticks_msec() + 2000)
	# Các cú chạm sau khi layer mở rơi vào overlay tutorial và đưa nó qua từng bước (như TC_CA_WP_022), nên đếm số
	# overlay Tutorial được tạo trong lúc bấm dồn và 2 giây sau, không chỉ số node còn lại lúc cuối.
	var seen := {}
	var hits := PackedStringArray()
	var p: Vector2 = r.to_viewport(btn, btn.size * 0.5)
	r.step("bấm dồn WeeklyPassButton 20 lần trong 1 giây")
	for i in 40:
		if i < 20:
			var under: Control = await r.hovered_at(p)
			var hit := str(r.node_label(under))
			if hits.is_empty() or hits[hits.size() - 1] != hit:
				hits.append(hit)
			await r.click_at(p)
		for t in r.main.popup_layer.find_children("Tutorial", "", true, false):
			seen[t.get_instance_id()] = true
		await r.wait_sec(0.05 if i < 20 else 0.1)
	var layers := _count_script(r, "weekly_pass.gd")
	var left: int = r.main.popup_layer.find_children("Tutorial", "", true, false).size()
	var opens := _ev(r, "weekly_open").size()
	r.tc("TC_CA_WP_015", r.main.popup_count() == 1 and layers == 1 and opens == 1 and seen.size() == 1
		and _errs(r) == errs,
		"chồng popup %d (weekly_pass %d), weekly_open %d lần, overlay Tutorial tạo %d (còn %d sau 2 giây), lỗi mới %d; mong đợi 1, 1, 1, 1 node Tutorial, 0. Node dưới ngón tay lần lượt: %s"
		% [r.main.popup_count(), layers, opens, seen.size(), left, _errs(r) - errs, " → ".join(hits)])
	return true


## TC_CA_WP_002. Save L26, tut_seen true, points 0, ts 1800000000: Home chưa có nút; thắng L26 không cộng key.
static func _wpp_locked(r) -> bool:
	if not await _wp_open(r, {"level": 26, "tut_seen": true, "points": 0}):
		return false
	if not await _wp_home(r):
		return false
	await r.wait_sec(1.2)
	var h := _home_wp(r)
	r.tc("TC_CA_WP_002", not bool(h.visible) and str(r.game.weekly_state()) == "locked",
		"L26: WeeklyPassItem %s, weekly_state %s; mong đợi ẩn, locked" % [_yes(h.visible), str(r.game.weekly_state())])
	var c := await _wp_win(r, 26)
	if c.is_empty():
		return false
	var want := int(c.before) + 40 + 10 * int(c.moves)
	var key := _cell(r, "WeeklyKeyReward")
	var evs := _ev(r, "weekly_points")
	r.tc("TC_CA_WP_002", WeeklyPass.points(r.game.s) == 0 and key == null and evs.is_empty()
		and int(r.game.s.coins) == want,
		"thắng L26: points %d, ô WeeklyKeyReward %s, weekly_points %d lần, gold %d (trước %d, MOVES còn %d); mong đợi 0, không có, 0, %d (+40 + 10 × MOVES)"
		% [WeeklyPass.points(r.game.s), _shown(key), evs.size(), int(r.game.s.coins), int(c.before), int(c.moves), want])
	return true


## TC_CA_WP_005. Save L27, tut_seen true, points 0, ts 1800000000: layer giữa tuần.
static func _wpp_active(r) -> bool:
	if not await _wp_open(r, {"level": 27, "tut_seen": true, "points": 0}):
		return false
	if not await _wp_home(r):
		return false
	var wp := await _wp_layer(r)
	if wp == null:
		return false
	r.tc("TC_CA_WP_005", str(r.game.weekly_state()) == "active" and str(r.game.s.weekly.cycle) == "W20829",
		"weekly_state %s, cycle %s; mong đợi active, W20829" % [str(r.game.weekly_state()), str(r.game.s.weekly.cycle)])
	r.tc("TC_CA_WP_005", _txt(wp, "TimeLabel") == "2d 16h left" and _txt(wp, "KeysLabel") == "0 / 130 keys",
		"TimeLabel \"%s\", KeysLabel \"%s\"; mong đợi \"2d 16h left\", \"0 / 130 keys\"" % [_txt(wp, "TimeLabel"),
		_txt(wp, "KeysLabel")])
	var missing := PackedStringArray()
	for i in 11:
		for kind in ["Free", "Vip"]:
			if wp.find_child("%s%d" % [kind, i], true, false) == null:
				missing.append("%s%d" % [kind, i])
	for n in ["BuyVipButton", "ClaimAllButton"]:
		if Scen.find_visible(wp, n) == null:
			missing.append(n)
	r.tc("TC_CA_WP_005", missing.is_empty(), "thiếu: %s; mong đợi Free0..Free10, Vip0..Vip10, BuyVipButton, ClaimAllButton"
		% (", ".join(missing) if not missing.is_empty() else "không"))
	return true


## TC_CA_WP_006. Save L27, s.weekly mặc định, ts 1800230401 (T2 00:00:01): Waiting.
static func _wpp_waiting(r) -> bool:
	if not await _wp_open(r, {"level": 27, "t": 1800230401}):
		return false
	if not await _wp_home(r):
		return false
	await r.wait_sec(1.2)
	var h := _home_wp(r)
	r.tc("TC_CA_WP_006", str(r.game.weekly_state()) == "waiting" and bool(h.visible) and h.caption == "Weekly Pass"
		and not bool(h.dot),
		"weekly_state %s, WeeklyPassItem %s, Caption \"%s\", WeeklyDot %s; mong đợi waiting, hiện, \"Weekly Pass\", ẩn" % [
		str(r.game.weekly_state()), _yes(h.visible), h.caption, _yes(h.dot)])
	var wp := await _wp_layer(r)
	if wp == null:
		return false
	await r.wait_sec(1.0)
	var wl := _txt(wp, "WaitingLabel")
	r.tc("TC_CA_WP_006", wl.contains("Next season starts soon")
		and wl.contains("The Weekly Pass opens in 5:59:59. See you then!"),
		"WaitingLabel \"%s\"; mong đợi \"Next season starts soon\" và \"The Weekly Pass opens in 5:59:59. See you then!\""
		% wl.replace("\n", " | "))
	var shown := PackedStringArray()
	for n in ["Free0", "BuyVipButton", "ClaimAllButton"]:
		if Scen.find_visible(wp, n) != null:
			shown.append(n)
	var tut := wp.find_child("Tutorial", true, false) != null
	r.tc("TC_CA_WP_006", shown.is_empty() and not tut and not r.game.weekly_tutorial_seen(),
		"đang hiện: %s; node Tutorial %s; tut_seen %s; mong đợi không có Free0, BuyVipButton, ClaimAllButton, Tutorial, tut_seen false"
		% [", ".join(shown), _yes(tut), r.game.weekly_tutorial_seen()])
	if not await Scen.tap_named(r, "Ok", wp):
		return false
	var closed: bool = await Scen.wait_for(r, func() -> bool: return r.popup_script("weekly_pass.gd") == null, 4000)
	r.tc("TC_CA_WP_006", closed and r.screen_name() == "home", "OK: layer %s, màn %s; mong đợi đóng, home" % [
		"đóng" if closed else "còn", r.screen_name()])
	return true


## TC_CA_WP_009. Save L27, s.weekly mặc định, ts 1800251998 (T2 05:59:58): layer đang mở khi tới 06:00.
static func _wpp_open_0600(r) -> bool:
	if not await _wp_open(r, {"level": 27, "t": 1800251998}):
		return false
	if not await _wp_home(r):
		return false
	var wp := await _wp_layer(r)
	if wp == null:
		return false
	var before := _txt(wp, "WaitingLabel")
	r.game.test_now = 1800252000
	r.step("giờ giả 1800251998 → 1800252000 (T2 06:00), layer vẫn mở")
	await r.wait_sec(2.0)
	r.tc("TC_CA_WP_009", before.contains("opens in 0:00:02") and Scen.find_visible(wp, "WaitingLabel") == null
		and Scen.find_visible(wp, "Free0") != null and _txt(wp, "TimeLabel") == "6d 18h left"
		and _txt(wp, "KeysLabel") == "0 / 130 keys",
		"trước: \"%s\"; sau 2 giây: WaitingLabel %s, Free0 %s, TimeLabel \"%s\", KeysLabel \"%s\"; mong đợi opens in 0:00:02 rồi không còn WaitingLabel, có Free0, \"6d 18h left\", \"0 / 130 keys\""
		% [before.replace("\n", " | "), _yes(Scen.find_visible(wp, "WaitingLabel") != null),
		_yes(Scen.find_visible(wp, "Free0") != null), _txt(wp, "TimeLabel"), _txt(wp, "KeysLabel")])
	var tut := await _tut_ready(r, wp, 0)
	var st := _tut_step(tut)
	r.tc("TC_CA_WP_009", tut != null and st.target == "Free0", "Tutorial %s, bước 1 trỏ %s; mong đợi hiện, Free0" % [
		_yes(tut != null), st.target])
	return true


## TC_CA_WP_013. Save L27, tut_seen true, points 2, claimed_free [], opened false, ts 1800000000.
static func _wpp_badge(r) -> bool:
	if not await _wp_open(r, {"level": 27, "tut_seen": true, "points": 2, "claimed_free": [], "opened": false}):
		return false
	if not await _wp_home(r):
		return false
	await r.wait_sec(1.2)
	var h := _home_wp(r)
	r.tc("TC_CA_WP_013", h.caption == "Weekly Pass (1)" and bool(h.dot),
		"bước 1: Caption \"%s\", WeeklyDot %s; mong đợi \"Weekly Pass (1)\", hiện" % [h.caption, _yes(h.dot)])
	var wp := await _wp_layer(r)
	if wp == null:
		return false
	if not await _wp_tap(r, wp, "free", 0):
		return false
	if not await _wp_close(r, wp):
		return false
	h = _home_wp(r)
	r.tc("TC_CA_WP_013", h.caption == "Weekly Pass" and not bool(h.dot) and bool(r.game.s.weekly.get("opened", false)),
		"bước 2: Caption \"%s\", WeeklyDot %s, opened %s; mong đợi \"Weekly Pass\", ẩn, true" % [h.caption, _yes(h.dot),
		str(r.game.s.weekly.get("opened"))])
	if (await _wp_win(r, 27)).is_empty():
		return false
	if not await Scen.after_win(r, 27):
		return false
	if not await _wp_home(r):
		return false
	await r.wait_sec(1.2)
	h = _home_wp(r)
	r.tc("TC_CA_WP_013", WeeklyPass.points(r.game.s) == 3 and h.caption == "Weekly Pass (1)" and bool(h.dot),
		"bước 4: points %d, Caption \"%s\", WeeklyDot %s; mong đợi 3, \"Weekly Pass (1)\", hiện" % [
		WeeklyPass.points(r.game.s), h.caption, _yes(h.dot)])
	return true


# ---------------------------------------------------------------- WP: tutorial và How to earn rewards

## TC_CA_WP_016. Save L27, s.weekly mặc định (chưa mở layer mùa này), inf_until 0, ts 1800000000.
static func _wpp_tutorial(r) -> bool:
	if not await _wp_open(r, {"level": 27, "inf_until": 0}):
		return false
	if not await _wp_home(r):
		return false
	var btn := Scen.find_visible(r.main.current_screen, "WeeklyPassButton") as Control
	if btn == null or not await r.tap(btn, "WeeklyPassButton"):
		return r.fail("không bấm được WeeklyPassButton")
	if not await Scen.wait_for(r, func() -> bool: return r.popup_script("weekly_pass.gd") != null, 6000, "weekly_pass.gd"):
		return r.fail("bấm WeeklyPassButton không mở layer")
	var wp: Node = r.popup_script("weekly_pass.gd")
	var t0 := Time.get_ticks_msec()
	await Scen.wait_for(r, func() -> bool: return is_instance_valid(wp) and is_instance_valid(wp.get("tutorial")), 6000,
		"weekly_pass.gd")
	var sec := (Time.get_ticks_msec() - t0) / 1000.0 * Engine.time_scale
	r.tc("TC_CA_WP_016", is_instance_valid(wp.get("tutorial")) and sec <= 1.0,
		"node Tutorial hiện sau %.2f giây (giờ game) kể từ lúc layer mở; mong đợi ≤ 1 giây (đề xuất)" % sec)
	var want := [["Free0", "Welcome to Weekly Pass! Claim your first reward!"],
		["Vip0", "Activating VIP gives you access to unique rewards!"],
		["ProgressRow", "This is your progress. Tap this icon to learn how to earn rewards!"]]
	for k in 3:
		var tut := await _tut_ready(r, wp, k)
		if tut == null:
			return r.fail("tutorial không tới bước %d" % (k + 1))
		var st := _tut_step(tut)
		r.tc("TC_CA_WP_016", st.target == want[k][0] and bool(st.hole) and st.text == want[k][1],
			"bước %d: lỗ quanh %s (%s), BubbleLabel \"%s\"; mong đợi lỗ quanh %s, \"%s\"" % [k + 1, st.target,
			"khớp" if bool(st.hole) else "không khớp", st.text, want[k][0], want[k][1]])
		await _tap_bg(r, tut)
	await Scen.wait_for(r, func() -> bool:
		return not is_instance_valid(wp.get("tutorial")) and is_instance_valid(wp.get("howto")), 5000, "weekly_pass.gd")
	var disk := _disk_weekly(r)
	var howto: Node = wp.get("howto")
	var title := _txt(howto, "txtHeader") if is_instance_valid(howto) else ""
	r.tc("TC_CA_WP_016", not is_instance_valid(wp.get("tutorial")) and r.game.weekly_tutorial_seen()
		and bool(disk.get("tut_seen", false)) and title == "How to earn rewards",
		"sau chạm 3: Tutorial %s, tut_seen %s, trên đĩa %s, popup \"%s\"; mong đợi mất, true, true, \"How to earn rewards\""
		% [_yes(is_instance_valid(wp.get("tutorial"))), r.game.weekly_tutorial_seen(), str(disk.get("tut_seen")), title])
	r.tc("TC_CA_WP_016", int(r.game.s.coins) == 3000 and int(r.game.s.lives.get("inf_until", 0)) == 0
		and _wl(r, "claimed_free") == "[]",
		"gold %d, inf_until %d, claimed_free %s; mong đợi 3000, 0 (không đổi), []" % [int(r.game.s.coins),
		int(r.game.s.lives.get("inf_until", 0)), _wl(r, "claimed_free")])
	return true


## TC_CA_WP_017. Save L27, tut_seen false, ts 1800000000: Back ở bước 2.
static func _wpp_back_tut(r) -> bool:
	if not await _wp_open(r, {"level": 27}):
		return false
	if not await _wp_home(r):
		return false
	var wp := await _wp_layer(r)
	if wp == null:
		return false
	var tut := await _tut_ready(r, wp, 0)
	if tut == null:
		return r.fail("mở layer lần đầu mà không có tutorial")
	await _tap_bg(r, tut)
	if await _tut_ready(r, wp, 1) == null:
		return r.fail("tutorial không sang bước 2")
	await r.back()
	var closed: bool = await Scen.wait_for(r, func() -> bool: return r.popup_script("weekly_pass.gd") == null, 4000)
	await r.wait_sec(0.5)
	var howto: bool = r.main.find_children("PopupWeeklyTutorial", "", true, false).size() > 0
	r.tc("TC_CA_WP_017", closed and r.screen_name() == "home" and not r.game.weekly_tutorial_seen() and not howto,
		"sau Back: layer %s, màn %s, tut_seen %s, popup How to earn rewards %s; mong đợi đóng, home, false, không có" % [
		"đóng" if closed else "còn", r.screen_name(), r.game.weekly_tutorial_seen(), _yes(howto)])
	if (await _wp_win(r, 27)).is_empty():
		return false
	var key := _cell(r, "WeeklyKeyReward")
	r.tc("TC_CA_WP_017", WeeklyPass.points(r.game.s) == 0 and key == null,
		"thắng L27: points %d, ô WeeklyKeyReward %s; mong đợi 0, không có" % [WeeklyPass.points(r.game.s), _shown(key)])
	if not await Scen.after_win(r, 27):
		return false
	if not await _wp_home(r):
		return false
	wp = await _wp_layer(r)
	if wp == null:
		return false
	var st := _tut_step(await _tut_ready(r, wp, 0))
	r.tc("TC_CA_WP_017", st.target == "Free0" and bool(st.hole)
		and st.text == "Welcome to Weekly Pass! Claim your first reward!",
		"mở lại: bước %d, lỗ quanh %s, \"%s\"; mong đợi bước 1, Free0, weekly_tut_free_claim" % [int(st.index) + 1,
		st.target, st.text])
	return true


## TC_CA_WP_018. Save L27, tut_seen false, ts 1800000000: tắt app ở bước 2, mở lại lúc ts 1800000060.
static func _wpp_kill_tut(r) -> bool:
	if not await _wp_open(r, {"level": 27}):
		return false
	if not await _wp_home(r):
		return false
	var wp := await _wp_layer(r)
	if wp == null:
		return false
	var tut := await _tut_ready(r, wp, 0)
	if tut == null:
		return r.fail("mở layer lần đầu mà không có tutorial")
	await _tap_bg(r, tut)
	if await _tut_ready(r, wp, 1) == null:
		return r.fail("tutorial không sang bước 2")
	if not await _wp_relaunch(r, 1800000060):
		return false
	r.tc("TC_CA_WP_018", not bool(r.game.s.weekly.get("tut_seen", true)),
		"save đọc lại: tut_seen %s; mong đợi false" % str(r.game.s.weekly.get("tut_seen")))
	if not await _wp_home(r):
		return false
	wp = await _wp_layer(r)
	if wp == null:
		return false
	var st := _tut_step(await _tut_ready(r, wp, 0))
	r.tc("TC_CA_WP_018", st.target == "Free0" and int(st.index) == 0, "mở lại layer: bước %d, lỗ quanh %s; mong đợi bước 1, Free0"
		% [int(st.index) + 1, st.target])
	return true


## TC_CA_WP_019, 093. Save L27, tut_seen true, ts 1800000000: nút "i", biểu tượng chìa; thứ tự lớp và Back.
static func _wpp_howto(r) -> bool:
	if not await _wp_open(r, {"level": 27, "tut_seen": true}):
		return false
	if not await _wp_home(r):
		return false
	var wp := await _wp_layer(r)
	if wp == null:
		return false
	for via in ["InfoButton", "KeyButton"]:
		var b := Scen.find_visible(wp, via) as Control
		if b == null or not await r.tap(b, via):
			return r.fail("không bấm được %s" % via)
		if not await Scen.wait_for(r, func() -> bool: return is_instance_valid(wp.get("howto")), 4000, "weekly_pass.gd"):
			r.tc("TC_CA_WP_019", false, "bấm %s không mở How to earn rewards" % via)
			continue
		await r.wait_sec(0.6)
		var h: Node = wp.get("howto")
		var n := _count_howto(wp)
		r.tc("TC_CA_WP_019", n == 1 and _txt(h, "txtHeader") == "How to earn rewards",
			"%s: %d popup \"%s\"; mong đợi đúng 1 popup \"How to earn rewards\"" % [via, n, _txt(h, "txtHeader")])
		if via == "InfoButton":
			var rows := PackedStringArray()
			for row in ["KeyRowNormal", "KeyRowHard", "KeyRowVeryHard"]:
				var node: Node = h.find_child(row, true, false)
				rows.append("%s|%s" % [_txt(node, "DescText"), _txt(node, "Points")])
			var want_rows := "Win a level|+1, Win a HARD level|+3, Win a VERY HARD level|+5"
			r.tc("TC_CA_WP_019", ", ".join(rows) == want_rows, "hàng key: %s; mong đợi %s" % [", ".join(rows), want_rows])
			var note2 := "VIP unlocks the VIP reward of every milestone and +3 max hearts this week. It also opens the Bonus Bank."
			var note1 := TranslationServer.translate("weekly_howto_claim")
			var note3 := TranslationServer.translate("weekly_howto_season")
			r.tc("TC_CA_WP_019", _txt(h, "Note2") == note2 and _txt(h, "Note1") == note1 and _txt(h, "Note3") == note3,
				"Note1 \"%s\", Note2 \"%s\", Note3 \"%s\"; mong đợi weekly_howto_claim, \"%s\", weekly_howto_season" % [
				_txt(h, "Note1"), _txt(h, "Note2"), _txt(h, "Note3"), note2])
		var close_name := "OkButton" if via == "InfoButton" else "btnTurnOff"
		if not await Scen.tap_named(r, close_name, h):
			return false
		var gone: bool = await Scen.wait_for(r, func() -> bool: return not is_instance_valid(wp.get("howto")), 4000,
			"weekly_pass.gd")
		r.tc("TC_CA_WP_019", gone and is_instance_valid(wp) and r.popup_script("weekly_pass.gd") == wp,
			"%s đóng popup: %s, layer %s; mong đợi đóng, layer vẫn mở" % ["OK" if via == "InfoButton" else "X",
			"đóng" if gone else "còn", "còn" if r.popup_script("weekly_pass.gd") == wp else "đóng"])
	# TC_CA_WP_093: How to earn rewards trên layer; Back 1 chỉ đóng nó (giả định OQ-10), Back 2 đóng layer.
	var info := Scen.find_visible(wp, "InfoButton") as Control
	if info == null or not await r.tap(info, "InfoButton"):
		return r.fail("không bấm được InfoButton")
	if not await Scen.wait_for(r, func() -> bool: return is_instance_valid(wp.get("howto")), 4000, "weekly_pass.gd"):
		return r.fail("InfoButton không mở How to earn rewards")
	await r.wait_sec(0.6)
	var hw: Node = wp.get("howto")
	var on_top := hw.get_index() == wp.get_child_count() - 1
	var ok_reach: bool = await r.reachable(Scen.find_visible(hw, "OkButton") as Control)
	var x_reach: bool = await r.reachable(Scen.find_visible(hw, "btnTurnOff") as Control)
	r.tc("TC_CA_WP_093", on_top and ok_reach and x_reach,
		"How to earn rewards là lớp trên cùng của layer %s, OkButton bấm được %s, X bấm được %s; mong đợi có, có, có" % [
		_yes(on_top), _yes(ok_reach), _yes(x_reach)])
	await r.back()
	await r.wait_sec(0.8)
	var layer_on: bool = is_instance_valid(wp) and r.popup_script("weekly_pass.gd") == wp
	r.tc("TC_CA_WP_093", not is_instance_valid(wp.get("howto")) if layer_on else false,
		"Back 1: How to earn rewards %s, layer %s; mong đợi chỉ đóng How to earn rewards, layer còn (giả định OQ-10)" % [
		"còn" if layer_on and is_instance_valid(wp.get("howto")) else "đóng", "còn" if layer_on else "đóng"])
	if layer_on:
		await r.back()
		var closed: bool = await Scen.wait_for(r, func() -> bool: return r.popup_script("weekly_pass.gd") == null, 4000)
		r.tc("TC_CA_WP_093", closed and r.screen_name() == "home", "Back 2: layer %s, màn %s; mong đợi đóng, home" % [
			"đóng" if closed else "còn", r.screen_name()])
	return true


## TC_CA_WP_022. Save L27, tut_seen false, ts 1800000000: 20 lần chạm nền trong 1 giây.
static func _wpp_spam_tut(r) -> bool:
	if not await _wp_open(r, {"level": 27}):
		return false
	if not await _wp_home(r):
		return false
	var wp := await _wp_layer(r)
	if wp == null:
		return false
	var tut := await _tut_ready(r, wp, 0)
	if tut == null:
		return r.fail("mở layer lần đầu mà không có tutorial")
	var seen := {"seq": [], "howto": {}}
	var p: Vector2 = r.to_viewport(tut, Vector2(30, 30))
	_track_tut(wp, seen)
	r.step("chạm nền 20 lần trong 1 giây")
	for i in 20:
		await r.click_at(p)
		_track_tut(wp, seen)
		await r.wait_sec(0.05)
		_track_tut(wp, seen)
	for i in 20:
		await r.wait_sec(0.1)
		_track_tut(wp, seen)
	var seq := ", ".join(PackedStringArray(seen.seq))
	var tuts := _ev(r, "weekly_tutorial").size()
	var howtos := (seen.howto as Dictionary).size()
	r.tc("TC_CA_WP_022", seq == "Free0, Vip0, ProgressRow", "thứ tự bước: %s; mong đợi Free0, Vip0, ProgressRow" % seq)
	r.tc("TC_CA_WP_022", r.game.weekly_tutorial_seen() and tuts == 1 and howtos == 1,
		"tut_seen %s, weekly_tutorial %d lần, popup How to earn rewards mở %d lần; mong đợi true, 1, 1" % [
		r.game.weekly_tutorial_seen(), tuts, howtos])
	r.tc("TC_CA_WP_022", int(r.game.s.coins) == 3000 and _wl(r, "claimed_free") == "[]",
		"gold %d, claimed_free %s; mong đợi 3000, []" % [int(r.game.s.coins), _wl(r, "claimed_free")])
	return true


## Ghi bước tutorial đang hiện (tên target, bỏ trùng liền nhau) và popup How to earn rewards đã mở vào `seen`.
static func _track_tut(wp: Variant, seen: Dictionary) -> void:
	if not is_instance_valid(wp):
		return
	var t: Variant = (wp as Node).get("tutorial")
	if is_instance_valid(t):
		var st := _tut_step(t as Control)
		var seq: Array = seen.seq
		if seq.is_empty() or str(seq.back()) != str(st.target):
			seq.append(str(st.target))
	var h: Variant = (wp as Node).get("howto")
	if is_instance_valid(h):
		(seen.howto as Dictionary)[(h as Object).get_instance_id()] = true


# ---------------------------------------------------------------- WP: cộng key khi thắng

## TC_CA_WP_024. Save L27, tut_seen true, points 0, ts 1800000000.
static func _wpp_key_normal(r) -> bool:
	if not await _wp_open(r, {"level": 27, "tut_seen": true, "points": 0}):
		return false
	if (await _wp_win(r, 27)).is_empty():
		return false
	var evs := _ev(r, "weekly_points")
	r.tc("TC_CA_WP_024", WeeklyPass.points(r.game.s) == 1 and _ev_one(evs, {"level": 27, "points": 1, "total": 1}),
		"points %d, weekly_points %s; mong đợi 1, một lần {level 27, points 1, total 1}" % [WeeklyPass.points(r.game.s),
		_ev_txt(evs)])
	var key := _cell(r, "WeeklyKeyReward")
	var gold := _cell(r, "GoldReward")
	var after_gold := key != null and gold != null and key.get_index() == gold.get_index() + 1
	r.tc("TC_CA_WP_024", _cell_txt(key) == "+1 key" and after_gold,
		"ô WeeklyKeyReward \"%s\", ngay sau ô gold %s; mong đợi \"+1 key\", có" % [_cell_txt(key), _yes(after_gold)])
	if not await Scen.after_win(r, 27):
		return false
	if not await _wp_home(r):
		return false
	var wp := await _wp_layer(r)
	if wp == null:
		return false
	var bar := wp.find_child("ProgressBar", true, false) as ProgressBar
	var v := bar.value if bar != null else -1.0
	r.tc("TC_CA_WP_024", _txt(wp, "KeysLabel") == "1 / 130 keys" and absf(v - 0.333) < 0.002,
		"KeysLabel \"%s\", ProgressBar %.3f; mong đợi \"1 / 130 keys\", 0.333" % [_txt(wp, "KeysLabel"), v])
	return true


## TC_CA_WP_025. Save L29 (HARD), tut_seen true, points 0, claimed_free [], ts 1800000000.
static func _wpp_key_hard(r) -> bool:
	if not await _wp_open(r, {"level": 29, "tut_seen": true, "points": 0, "claimed_free": []}):
		return false
	if (await _wp_win(r, 29)).is_empty():
		return false
	var evs := _ev(r, "weekly_points")
	var key := _cell(r, "WeeklyKeyReward")
	r.tc("TC_CA_WP_025", WeeklyPass.points(r.game.s) == 3 and _ev_one(evs, {"level": 29, "points": 3, "total": 3})
		and _cell_txt(key) == "+3 keys",
		"points %d, weekly_points %s, ô WeeklyKeyReward \"%s\"; mong đợi 3, {level 29, points 3, total 3}, \"+3 keys\"" % [
		WeeklyPass.points(r.game.s), _ev_txt(evs), _cell_txt(key)])
	if not await Scen.after_win(r, 29):
		return false
	if not await _wp_home(r):
		return false
	await r.wait_sec(1.2)
	var h := _home_wp(r)
	r.tc("TC_CA_WP_025", h.caption == "Weekly Pass (2)", "Home: Caption \"%s\"; mong đợi \"Weekly Pass (2)\"" % h.caption)
	return true


## TC_CA_WP_026. Save L33 (VeryHard đầu tiên), tut_seen true, points 0, ts 1800000000.
static func _wpp_key_vhard(r) -> bool:
	if not await _wp_open(r, {"level": 33, "tut_seen": true, "points": 0}):
		return false
	if (await _wp_win(r, 33)).is_empty():
		return false
	var evs := _ev(r, "weekly_points")
	var key := _cell(r, "WeeklyKeyReward")
	r.tc("TC_CA_WP_026", WeeklyPass.points(r.game.s) == 5 and _ev_one(evs, {"level": 33, "points": 5, "total": 5})
		and _cell_txt(key) == "+5 keys",
		"points %d, weekly_points %s, ô WeeklyKeyReward \"%s\"; mong đợi 5, {level 33, points 5, total 5}, \"+5 keys\"" % [
		WeeklyPass.points(r.game.s), _ev_txt(evs), _cell_txt(key)])
	return true


## TC_CA_WP_027. Save L27, tut_seen false, points 0, chưa mở layer, ts 1800000000: thắng L27, L28.
static func _wpp_no_tut_win(r) -> bool:
	if not await _wp_open(r, {"level": 27, "points": 0, "opened": false}):
		return false
	for lvl in [27, 28]:
		var c := await _wp_win(r, lvl)
		if c.is_empty():
			return false
		var want := int(c.before) + 40 + 10 * int(c.moves)
		var key := _cell(r, "WeeklyKeyReward")
		var evs := _ev(r, "weekly_points")
		r.tc("TC_CA_WP_027", WeeklyPass.points(r.game.s) == 0 and key == null and evs.is_empty()
			and int(r.game.s.coins) == want,
			"thắng L%d: points %d, ô WeeklyKeyReward %s, weekly_points %d lần, gold %d (trước %d, MOVES còn %d); mong đợi 0, không có, 0, %d"
			% [lvl, WeeklyPass.points(r.game.s), _shown(key), evs.size(), int(r.game.s.coins), int(c.before), int(c.moves),
			want])
		if not await Scen.after_win(r, lvl):
			return false
	if not await _wp_home(r):
		return false
	await r.wait_sec(1.2)
	var h := _home_wp(r)
	r.tc("TC_CA_WP_027", h.caption == "Weekly Pass (1)" and bool(h.dot),
		"Home: Caption \"%s\", WeeklyDot %s; mong đợi \"Weekly Pass (1)\", hiện" % [h.caption, _yes(h.dot)])
	return true


## TC_CA_WP_028. Save L27, tut_seen true, cycle W20836, points 0, ts 1800230401 (Waiting).
static func _wpp_waiting_win(r) -> bool:
	if not await _wp_open(r, {"level": 27, "tut_seen": true, "cycle": "W20836", "points": 0, "t": 1800230401}):
		return false
	var c := await _wp_win(r, 27)
	if c.is_empty():
		return false
	var want := int(c.before) + 40 + 10 * int(c.moves)
	var key := _cell(r, "WeeklyKeyReward")
	var evs := _ev(r, "weekly_points")
	r.tc("TC_CA_WP_028", WeeklyPass.points(r.game.s) == 0 and key == null and evs.is_empty()
		and int(r.game.s.coins) == want,
		"thắng L27 lúc Waiting: points %d, ô WeeklyKeyReward %s, weekly_points %d lần, gold %d; mong đợi 0, không có, 0, %d"
		% [WeeklyPass.points(r.game.s), _shown(key), evs.size(), int(r.game.s.coins), want])
	return true


## TC_CA_WP_029. Save L27, tut_seen true, points 1, mạng 10/10, ts 1800000000: hết MOVES, Bỏ cuộc.
static func _wpp_lose(r) -> bool:
	if not await _wp_open(r, {"level": 27, "tut_seen": true, "points": 1}):
		return false
	if not await _ensure_playing(r, 27):
		return false
	var id := await _wp_blocked_id(r)
	if id == "":
		return r.fail("L27 không có khối bị chặn để làm hết MOVES")
	if not await Scen.burn_to_rescue(r, id):
		return false
	if not await Scen.give_up(r, "wp029_lose_card"):
		return false
	var evs := _ev(r, "weekly_points")
	var lives := int(r.game.lives_view().count)
	r.tc("TC_CA_WP_029", WeeklyPass.points(r.game.s) == 1 and evs.is_empty() and lives == 9,
		"thua L27: points %d, weekly_points %d lần, mạng %d; mong đợi 1, 0, 9" % [WeeklyPass.points(r.game.s), evs.size(),
		lives])
	return true


## TC_CA_WP_031. Save L29 (HARD), tut_seen true, points 0, ts 1800000000, ads giả xem hết.
static func _wpp_x2(r) -> bool:
	if not await _wp_open(r, {"level": 29, "tut_seen": true, "points": 0}):
		return false
	var c := await _wp_win(r, 29)
	if c.is_empty():
		return false
	if not await Scen.wait_for(r, func() -> bool: return r.popup_node("X2Button") != null, 8000, "X2Button"):
		return r.fail("thẻ thắng L29 không có nút x2")
	var shown := int(r.game.s.coins)
	if not await Scen._ad_tap(r, r.popup_node("X2Button") as Control, "x2_coins", "", "x2 (xem hết video giả)"):
		return false
	await Scen.wait_for(r, func() -> bool: return int(r.game.s.coins) != shown, 10000, "*")
	var key_txt := _cell_txt(_cell(r, "WeeklyKeyReward"))
	var want := int(c.before) + 2 * (40 + 10 * int(c.moves))
	r.tc("TC_CA_WP_031", int(r.game.s.coins) == want and WeeklyPass.points(r.game.s) == 3 and key_txt == "+3 keys",
		"sau x2: gold %d (trước khi thắng %d, MOVES còn %d), points %d, ô WeeklyKeyReward \"%s\"; mong đợi %d (+2 × (40 + 10 × MOVES)), 3, \"+3 keys\""
		% [int(r.game.s.coins), int(c.before), int(c.moves), WeeklyPass.points(r.game.s), key_txt, want])
	return true


## TC_CA_WP_033. Save L27, tut_seen true, cycle W20829, points 3, không VIP, claimed [], ts 1800230300 (CN 23:58:20):
## đổi giờ giả trước lần thắng L27 (1800230390), L28 (1800230460, T2 00:01), L29 HARD (1800252060, T2 06:01).
static func _wpp_cross_week(r) -> bool:
	if not await _wp_open(r, {"level": 27, "tut_seen": true, "cycle": "W20829", "points": 3, "vip": false,
			"claimed_free": [], "claimed_vip": [], "t": 1800230300}):
		return false
	var steps := [[27, 1800230390], [28, 1800230460], [29, 1800252060]]
	for k in 3:
		var lvl := int(steps[k][0])
		if not await _ensure_playing(r, lvl):
			return false
		r.game.test_now = int(steps[k][1])
		r.step("giờ giả %d trước khi thắng L%d" % [int(steps[k][1]), lvl])
		if (await _wp_win(r, lvl)).is_empty():
			return false
		var w: Dictionary = r.game.s.weekly
		var key := _cell(r, "WeeklyKeyReward")
		match k:
			0:
				r.tc("TC_CA_WP_033", int(w.points) == 4 and str(w.cycle) == "W20829" and _cell_txt(key) == "+1 key",
					"bước 1: points %d, cycle %s, ô \"%s\"; mong đợi 4, W20829, \"+1 key\"" % [int(w.points), str(w.cycle),
					_cell_txt(key)])
			1:
				r.tc("TC_CA_WP_033", key == null, "bước 2 (Waiting): ô WeeklyKeyReward %s (\"%s\"); mong đợi không có" % [
					_shown(key), _cell_txt(key)])
			2:
				r.tc("TC_CA_WP_033", str(w.cycle) == "W20836" and int(w.points) == 3 and _cell_txt(key) == "+3 keys",
					"bước 3: cycle %s, points %d, ô \"%s\"; mong đợi W20836, 3 (chỉ key của L29), \"+3 keys\"" % [
					str(w.cycle), int(w.points), _cell_txt(key)])
		if not await Scen.after_win(r, lvl):
			return false
	if not await _wp_home(r):
		return false
	var wp := await _wp_layer(r)
	if wp == null:
		return false
	await Scen.wait_for(r, func() -> bool: return Scen.find_visible(wp, "EndLabel") != null, 3000, "weekly_pass.gd")
	var end := _txt(wp, "EndLabel")
	var keys := ""
	if Scen.find_visible(wp, "EndOkButton") != null and await Scen.tap_named(r, "EndOkButton", wp):
		await Scen.wait_for(r, func() -> bool: return Scen.find_visible(wp, "KeysLabel") != null, 3000, "weekly_pass.gd")
		keys = _txt(wp, "KeysLabel")
	r.tc("TC_CA_WP_033", end == "You earned 4 keys this season. A new season is coming!" and keys == "3 / 130 keys",
		"layer: popup cuối mùa \"%s\", rồi KeysLabel \"%s\"; mong đợi \"You earned 4 keys this season. A new season is coming!\", \"3 / 130 keys\""
		% [end, keys])
	return true


# ---------------------------------------------------------------- WP: nhận thưởng Main Tree

## TC_CA_WP_035. Save L27, tut_seen true, points 0, inf_until 0, ts 1800000000: Free0.
static func _wpp_claim_free0(r) -> bool:
	if not await _wp_open(r, {"level": 27, "tut_seen": true, "points": 0, "inf_until": 0}):
		return false
	if not await _wp_home(r):
		return false
	var wp := await _wp_layer(r)
	if wp == null or not await _wp_tap(r, wp, "free", 0):
		return false
	var f0 := _wp_card(wp, "free", 0)
	var v0 := _wp_card(wp, "vip", 0)
	r.tc("TC_CA_WP_035", int(r.game.s.lives.get("inf_until", 0)) == 1800000900 and _wl(r, "claimed_free") == "[0]"
		and int(r.game.s.coins) == 3000,
		"inf_until %d, claimed_free %s, gold %d; mong đợi 1800000900, [0], 3000" % [int(r.game.s.lives.get("inf_until", 0)),
		_wl(r, "claimed_free"), int(r.game.s.coins)])
	r.tc("TC_CA_WP_035", _wp_has(f0, "Claimed") and f0 != null and (f0 as BaseButton).disabled and _wp_has(v0, "Lock"),
		"Free0 có tích %s, disabled %s; Vip0 có Lock %s; mong đợi có, true, có" % [_yes(_wp_has(f0, "Claimed")),
		str(f0 != null and (f0 as BaseButton).disabled), _yes(_wp_has(v0, "Lock"))])
	var all_btn: BaseButton = wp.get("claim_all_button")
	var evs := _ev(r, "weekly_claim")
	r.tc("TC_CA_WP_035", all_btn != null and all_btn.disabled and _ev_one(evs, {"kind": "free", "coins": 0, "points": 0}),
		"ClaimAllButton tương tác %s, weekly_claim %s; mong đợi không, một lần {kind free, coins 0, points 0}" % [
		_yes(all_btn != null and not all_btn.disabled), _ev_txt(evs)])
	if not await _wp_close(r, wp):
		return false
	var h := _home_wp(r)
	var hud := _hud(r)
	r.tc("TC_CA_WP_035", h.caption == "Weekly Pass" and hud.lives == "" and hud.timer == "15:00",
		"Home: Caption \"%s\", chip mạng số \"%s\" giờ \"%s\"; mong đợi \"Weekly Pass\", vô hạn (không số), \"15:00\"" % [
		h.caption, hud.lives, hud.timer])
	return true


## TC_CA_WP_036. Save L27, tut_seen true, points 3, claimed_free [0], ts 1800000000: Free1 (+100 gold).
static func _wpp_claim_free1(r) -> bool:
	if not await _wp_open(r, {"level": 27, "tut_seen": true, "points": 3, "claimed_free": [0]}):
		return false
	if not await _wp_home(r):
		return false
	var wp := await _wp_layer(r)
	if wp == null or not await _wp_tap(r, wp, "free", 1):
		return false
	r.tc("TC_CA_WP_036", int(r.game.s.coins) == 3100 and _wl(r, "claimed_free") == "[0, 1]"
		and _wp_has(_wp_card(wp, "free", 1), "Claimed"),
		"gold %d, claimed_free %s, Free1 có tích %s; mong đợi 3100, [0, 1], có" % [int(r.game.s.coins),
		_wl(r, "claimed_free"), _yes(_wp_has(_wp_card(wp, "free", 1), "Claimed"))])
	await Scen.wait_for(r, func() -> bool: return RewardFly.held("gold") == 0 and _hud(r).gold == "3100", 5000,
		"weekly_pass.gd")
	var evs := _ev(r, "weekly_claim")
	r.tc("TC_CA_WP_036", _hud(r).gold == "3100" and _ev_one(evs, {"kind": "free", "coins": 100, "points": 3}),
		"chip gold \"%s\" sau khi đồng cuối chạm, weekly_claim %s; mong đợi \"3100\", {kind free, coins 100, points 3}" % [
		_hud(r).gold, _ev_txt(evs)])
	return true


## TC_CA_WP_037. Save L27, tut_seen true, points 8, claimed_free [0, 1], ts 1800000000: Free2 (+1 Gợi ý).
static func _wpp_claim_free2(r) -> bool:
	if not await _wp_open(r, {"level": 27, "tut_seen": true, "points": 8, "claimed_free": [0, 1]}):
		return false
	if not await _wp_home(r):
		return false
	var wp := await _wp_layer(r)
	if wp == null or not await _wp_tap(r, wp, "free", 2):
		return false
	r.tc("TC_CA_WP_037", int(r.game.s.inv.hint) == 4 and int(r.game.s.coins) == 3000
		and _wl(r, "claimed_free") == "[0, 1, 2]" and _wp_has(_wp_card(wp, "free", 2), "Claimed"),
		"hint %d, gold %d, claimed_free %s, Free2 có tích %s; mong đợi 4, 3000, [0, 1, 2], có" % [int(r.game.s.inv.hint),
		int(r.game.s.coins), _wl(r, "claimed_free"), _yes(_wp_has(_wp_card(wp, "free", 2), "Claimed"))])
	return true


## TC_CA_WP_040, 041. Save L27, tut_seen true, points 4, claimed_free [0, 1], không VIP, ts 1800000000.
static func _wpp_tap_locked(r) -> bool:
	if not await _wp_open(r, {"level": 27, "tut_seen": true, "points": 4, "claimed_free": [0, 1]}):
		return false
	if not await _wp_home(r):
		return false
	var wp := await _wp_layer(r)
	if wp == null:
		return false
	var inf := int(r.game.s.lives.get("inf_until", 0))
	var f2 := _wp_card(wp, "free", 2)
	var f2_off := f2 != null and (f2 as BaseButton).disabled and not _wp_has(f2, "Claim")
	if not await _wp_tap(r, wp, "free", 2):
		return false
	r.tc("TC_CA_WP_040", f2_off and int(r.game.s.inv.hint) == 3 and int(r.game.s.coins) == 3000
		and _wl(r, "claimed_free") == "[0, 1]" and _ev(r, "weekly_claim").is_empty(),
		"Free2 disabled, không pill %s; hint %d, gold %d, claimed_free %s, weekly_claim %d lần; mong đợi có, 3, 3000, [0, 1], 0"
		% [_yes(f2_off), int(r.game.s.inv.hint), int(r.game.s.coins), _wl(r, "claimed_free"), _ev(r, "weekly_claim").size()])
	var locks := PackedStringArray()
	for i in 2:
		var v := _wp_card(wp, "vip", i)
		if not (_wp_has(v, "Lock") and (v as BaseButton).disabled):
			locks.append("Vip%d" % i)
		if not await _wp_tap(r, wp, "vip", i):
			return false
	r.tc("TC_CA_WP_041", locks.is_empty() and int(r.game.s.coins) == 3000 and _wl(r, "claimed_vip") == "[]"
		and int(r.game.s.lives.get("inf_until", 0)) == inf and _ev(r, "weekly_claim").is_empty(),
		"thẻ thiếu Lock/disabled: %s; gold %d, claimed_vip %s, inf_until %d → %d, weekly_claim %d lần; mong đợi không, 3000, [], không đổi, 0"
		% [", ".join(locks), int(r.game.s.coins), _wl(r, "claimed_vip"), inf, int(r.game.s.lives.get("inf_until", 0)),
		_ev(r, "weekly_claim").size()])
	return true


## TC_CA_WP_042. Save L27, tut_seen true, points 3, claimed_free [0, 1], ts 1800000000: Free1 ba lần, cách 1 giây.
static func _wpp_tap_claimed(r) -> bool:
	if not await _wp_open(r, {"level": 27, "tut_seen": true, "points": 3, "claimed_free": [0, 1]}):
		return false
	if not await _wp_home(r):
		return false
	var wp := await _wp_layer(r)
	if wp == null:
		return false
	for i in 3:
		if not await _wp_tap(r, wp, "free", 1):
			return false
		await r.wait_sec(0.2)
	var f1 := _wp_card(wp, "free", 1)
	r.tc("TC_CA_WP_042", _wp_has(f1, "Claimed") and (f1 as BaseButton).disabled and int(r.game.s.coins) == 3000
		and _wl(r, "claimed_free") == "[0, 1]",
		"Free1 có tích %s, disabled %s; gold %d, claimed_free %s; mong đợi có, true, 3000, [0, 1]" % [
		_yes(_wp_has(f1, "Claimed")), str(f1 != null and (f1 as BaseButton).disabled), int(r.game.s.coins),
		_wl(r, "claimed_free")])
	return true


## TC_CA_WP_043. Save L27, tut_seen true, points 3, claimed_free [0], ts 1800000000: 20 lần chạm Free1 trong 1 giây.
static func _wpp_spam_card(r) -> bool:
	if not await _wp_open(r, {"level": 27, "tut_seen": true, "points": 3, "claimed_free": [0]}):
		return false
	if not await _wp_home(r):
		return false
	var wp := await _wp_layer(r)
	if wp == null:
		return false
	var f1 := _wp_card(wp, "free", 1)
	if f1 == null or not await Scen.scroll_into_view(r, f1):
		return r.fail("không tới được ô Free1")
	var errs := _errs(r)
	await _spam(r, f1)
	await r.wait_sec(1.0)
	var ones := 0
	for v in r.game.s.weekly.claimed_free:
		if int(v) == 1:
			ones += 1
	var evs := _ev(r, "weekly_claim")
	r.tc("TC_CA_WP_043", int(r.game.s.coins) == 3100 and _wl(r, "claimed_free") == "[0, 1]" and ones == 1
		and evs.size() == 1 and _errs(r) == errs,
		"gold %d, claimed_free %s (mốc 1 có %d lần), weekly_claim %d lần, lỗi mới %d; mong đợi 3100, [0, 1], 1, 1, 0" % [
		int(r.game.s.coins), _wl(r, "claimed_free"), ones, evs.size(), _errs(r) - errs])
	return true


## TC_CA_WP_044. Save L27, tut_seen true, VIP, points 10, claimed_free [0, 1], claimed_vip [0], ts 1800000000.
static func _wpp_card_states(r) -> bool:
	if not await _wp_open(r, {"level": 27, "tut_seen": true, "vip": true, "points": 10, "claimed_free": [0, 1],
			"claimed_vip": [0]}):
		return false
	if not await _wp_home(r):
		return false
	var wp := await _wp_layer(r)
	if wp == null:
		return false
	var bad := PackedStringArray()
	for n in [["free", 0, "Claimed"], ["free", 1, "Claimed"], ["vip", 0, "Claimed"], ["vip", 1, "Claim"],
			["free", 2, "Claim"], ["vip", 2, "Claim"]]:
		if not _wp_has(_wp_card(wp, str(n[0]), int(n[1])), str(n[2])):
			bad.append("%s%d thiếu %s" % [str(n[0]).capitalize(), int(n[1]), str(n[2])])
	for i in range(3, 11):
		for kind in ["free", "vip"]:
			var c := _wp_card(wp, kind, i)
			if _wp_has(c, "Claim") or _wp_has(c, "Lock"):
				bad.append("%s%d có pill hoặc Lock" % [kind.capitalize(), i])
	r.tc("TC_CA_WP_044", bad.is_empty(), "trạng thái thẻ: %s; mong đợi Free0, Free1, Vip0 tích; Vip1, Free2, Vip2 pill Claim; Free3 trở đi không pill, không Lock"
		% ("; ".join(bad) if not bad.is_empty() else "đúng"))
	var bar := wp.find_child("ProgressBar", true, false) as ProgressBar
	var v := bar.value if bar != null else -1.0
	var fill := _track_fill(wp)
	r.tc("TC_CA_WP_044", _txt(wp, "KeysLabel") == "10 / 130 keys" and absf(v - 0.286) < 0.002 and absf(fill - 0.229) < 0.002,
		"KeysLabel \"%s\", ProgressBar %.3f, thanh dọc %.3f; mong đợi \"10 / 130 keys\", 0.286, 0.229" % [
		_txt(wp, "KeysLabel"), v, fill])
	var v1 := _wp_card_texts(_wp_card(wp, "vip", 1))
	var v2 := _wp_card_texts(_wp_card(wp, "vip", 2))
	r.tc("TC_CA_WP_044", v1.has("200") and v1.has("30m") and v2.has("300") and v2.has("x1"),
		"Vip1 %s, Vip2 %s; mong đợi \"200\" và \"30m\", \"300\" và \"x1\"" % [str(v1), str(v2)])
	await r.tc_look("TC_CA_WP_044", "wp044_cards_top")
	await Scen.scroll_into_view(r, _wp_card(wp, "free", 10))
	await r.tc_look("TC_CA_WP_044", "wp044_cards_bottom")
	return true


## TC_CA_WP_045. Save L27, tut_seen true, VIP, points 3, claimed [], ts 1800000000: Vip1 (200 gold + 30 phút).
static func _wpp_claim_vip1(r) -> bool:
	if not await _wp_open(r, {"level": 27, "tut_seen": true, "vip": true, "points": 3, "claimed_free": [],
			"claimed_vip": []}):
		return false
	if not await _wp_home(r):
		return false
	var wp := await _wp_layer(r)
	if wp == null:
		return false
	var v1 := _wp_card(wp, "vip", 1)
	if v1 == null or not await Scen.scroll_into_view(r, v1):
		return r.fail("không tới được ô Vip1")
	var top: Node = r.main.current_screen.find_child("HubTop", true, false)
	var gl := top.get_node_or_null("GoldPanel/GoldLabel") as Label if top != null else null
	if gl == null:
		return r.fail("Home không có chip gold")
	var seq: Array[int] = [gl.text.to_int()]
	await r.tap(v1, "Weekly Pass: ô Vip1")
	var until := Time.get_ticks_msec() + int(2500.0 / maxf(Engine.time_scale, 0.1))
	while Time.get_ticks_msec() < until:
		var n := gl.text.to_int()
		if n != seq.back():
			seq.append(n)
		await r.wait_frames(1)
	var mono := true
	for i in range(1, seq.size()):
		mono = mono and seq[i] >= seq[i - 1]
	var steps := seq.filter(func(x: int) -> bool: return x > 3000 and x < 3200).size()
	r.tc("TC_CA_WP_045", seq[0] == 3000 and seq.back() == 3200 and int(r.game.s.coins) == 3200 and mono and steps >= 1,
		"chip gold %s (s.coins %d); mong đợi chạy từ 3000 lên 3200 theo từng đồng, cuối bằng s.coins 3200" % [str(seq),
		int(r.game.s.coins)])
	var hud := _hud(r)
	r.tc("TC_CA_WP_045", hud.lives == "" and hud.timer != "" and int(r.game.s.lives.get("inf_until", 0)) == 1800001800,
		"chip mạng số \"%s\" giờ \"%s\", inf_until %d; mong đợi vô hạn (không số), 1800001800" % [hud.lives, hud.timer,
		int(r.game.s.lives.get("inf_until", 0))])
	return true


## TC_CA_WP_047. Save L27, tut_seen true, points 8, claimed [], ts 1800000000: Nhận tất cả, rồi dùng Gợi ý và bỏ cuộc ở
## L27 trong 15 phút mạng vô hạn.
static func _wpp_use_rewards(r) -> bool:
	if not await _wp_open(r, {"level": 27, "tut_seen": true, "points": 8, "claimed_free": [], "claimed_vip": []}):
		return false
	if not await _wp_home(r):
		return false
	var wp := await _wp_layer(r)
	if wp == null:
		return false
	if not await Scen.tap_named(r, "ClaimAllButton", wp):
		return false
	await r.wait_sec(0.8)
	r.tc("TC_CA_WP_047", int(r.game.s.coins) == 3100 and int(r.game.s.inv.hint) == 4
		and int(r.game.s.lives.get("inf_until", 0)) == 1800000900,
		"sau Nhận tất cả: gold %d, hint %d, inf_until %d; mong đợi 3100, 4, 1800000900" % [int(r.game.s.coins),
		int(r.game.s.inv.hint), int(r.game.s.lives.get("inf_until", 0))])
	if not await _wp_close(r, wp):
		return false
	if not await _ensure_playing(r, 27):
		return false
	await Scen.settle_all(r)
	if not await Scen._tap_booster(r, "hint"):
		return false
	var lv: Control = r.level_screen()
	var fx: bool = await Scen.wait_for(r, func() -> bool: return is_instance_valid(lv.get("_hint_fx")), 4000, "*")
	await Scen.wait_for(r, func() -> bool: return int(r.game.s.inv.hint) == 3, 3000, "*")
	r.tc("TC_CA_WP_047", fx and int(r.game.s.inv.hint) == 3, "dùng Gợi ý: hiệu ứng %s, hint %d; mong đợi có, 4 → 3" % [
		_yes(fx), int(r.game.s.inv.hint)])
	await r.wait_sec(1.5)
	var id := await _wp_blocked_id(r)
	if id == "":
		return r.fail("L27 không có khối bị chặn để làm hết MOVES")
	if not await Scen.burn_to_rescue(r, id):
		return false
	if not await Scen.tap_named(r, "SkipButton", r.popup_script("popup_rescue.gd")):
		return false
	var seen := {"keep": false}
	await Scen.wait_for(r, func() -> bool:
		if r.popup_script("popup_keep_playing.gd") != null:
			seen["keep"] = true
		return r.popup_script("lose_card.gd") != null or bool(seen.keep), 8000, "*")
	var keep := bool(seen.keep)
	if keep:
		await Scen.tap_named(r, "ConfirmButton", r.popup_script("popup_keep_playing.gd"))
		await Scen.wait_for(r, func() -> bool: return r.popup_script("lose_card.gd") != null, 8000, "lose_card.gd")
	var lives := int(r.game.lives_view().count)
	r.tc("TC_CA_WP_047", not keep and lives == 10, "bỏ cuộc trong 15 phút mạng vô hạn: cảnh báo mất mạng %s, mạng %d; mong đợi không, 10"
		% [_yes(keep), lives])
	return true


## TC_CA_WP_048. Save L27, tut_seen true, points 8, claimed [], không VIP, ts 1800000000.
static func _wpp_claim_all(r) -> bool:
	if not await _wp_open(r, {"level": 27, "tut_seen": true, "points": 8, "claimed_free": [], "claimed_vip": []}):
		return false
	if not await _wp_home(r):
		return false
	var wp := await _wp_layer(r)
	if wp == null:
		return false
	if not await Scen.tap_named(r, "ClaimAllButton", wp):
		return false
	await r.wait_sec(0.8)
	r.tc("TC_CA_WP_048", int(r.game.s.coins) == 3100 and int(r.game.s.inv.hint) == 4
		and int(r.game.s.lives.get("inf_until", 0)) == 1800000900,
		"gold %d, hint %d, inf_until %d; mong đợi 3100, 4, 1800000900" % [int(r.game.s.coins), int(r.game.s.inv.hint),
		int(r.game.s.lives.get("inf_until", 0))])
	var locks := PackedStringArray()
	for i in 3:
		if not _wp_has(_wp_card(wp, "vip", i), "Lock"):
			locks.append("Vip%d" % i)
	r.tc("TC_CA_WP_048", _wl(r, "claimed_free") == "[0, 1, 2]" and _wl(r, "claimed_vip") == "[]" and locks.is_empty(),
		"claimed_free %s, claimed_vip %s, thiếu Lock: %s; mong đợi [0, 1, 2], [], Vip0..Vip2 còn Lock" % [
		_wl(r, "claimed_free"), _wl(r, "claimed_vip"), ", ".join(locks)])
	var all_btn: BaseButton = wp.get("claim_all_button")
	var off := all_btn != null and all_btn.disabled
	var before := _bal(r)
	await Scen.tap_named(r, "ClaimAllButton", wp)
	await r.wait_sec(0.8)
	var evs := _ev(r, "weekly_claim")
	r.tc("TC_CA_WP_048", off and _bal(r) == before and _ev_one(evs, {"kind": "all", "coins": 100, "points": 8}),
		"ClaimAllButton không tương tác %s, lần bấm hai đổi số dư %s, weekly_claim %s; mong đợi có, không, một lần {kind all, coins 100, points 8}"
		% [_yes(off), _yes(_bal(r) != before), _ev_txt(evs)])
	return true


## TC_CA_WP_049. Save L27, tut_seen true, VIP, bonus 3, mạng 13/13, points 15, claimed [], ts 1800000000.
static func _wpp_claim_all_vip(r) -> bool:
	if not await _wp_open(r, {"level": 27, "tut_seen": true, "vip": true, "bonus": 3, "count": 13, "points": 15,
			"claimed_free": [], "claimed_vip": []}):
		return false
	if not await _wp_home(r):
		return false
	var wp := await _wp_layer(r)
	if wp == null or not await Scen.tap_named(r, "ClaimAllButton", wp):
		return false
	await r.wait_sec(0.8)
	var evs := _ev(r, "weekly_claim")
	r.tc("TC_CA_WP_049", int(r.game.s.coins) == 4300 and int(r.game.s.inv.hint) == 5
		and int(r.game.s.lives.get("inf_until", 0)) == 1800002700,
		"gold %d, hint %d, inf_until %d; mong đợi 4300 (free 250 + VIP 1.050), 5, 1800002700 (15 + 30 phút)" % [
		int(r.game.s.coins), int(r.game.s.inv.hint), int(r.game.s.lives.get("inf_until", 0))])
	r.tc("TC_CA_WP_049", _wl(r, "claimed_free") == "[0, 1, 2, 3]" and _wl(r, "claimed_vip") == "[0, 1, 2, 3]"
		and _ev_one(evs, {"kind": "all", "coins": 1300, "points": 15}),
		"claimed_free %s, claimed_vip %s, weekly_claim %s; mong đợi [0, 1, 2, 3], [0, 1, 2, 3], {kind all, coins 1300, points 15}"
		% [_wl(r, "claimed_free"), _wl(r, "claimed_vip"), _ev_txt(evs)])
	return true


## TC_CA_WP_050. Save L27, tut_seen true, VIP, points 15, claimed [], ts 1800000000: 20 lần chạm Nhận tất cả.
static func _wpp_spam_all(r) -> bool:
	if not await _wp_open(r, {"level": 27, "tut_seen": true, "vip": true, "points": 15, "claimed_free": [],
			"claimed_vip": []}):
		return false
	if not await _wp_home(r):
		return false
	var wp := await _wp_layer(r)
	if wp == null:
		return false
	var b := Scen.find_visible(wp, "ClaimAllButton") as Control
	if b == null:
		return r.fail("layer không có ClaimAllButton")
	await r._wait_still(b, Time.get_ticks_msec() + 2000)
	await _spam(r, b)
	await r.wait_sec(1.0)
	var all_n := _ev(r, "weekly_claim").filter(func(e: Dictionary) -> bool:
		return str(e.params.get("kind", "")) == "all").size()
	r.tc("TC_CA_WP_050", int(r.game.s.coins) == 4300 and int(r.game.s.inv.hint) == 5 and all_n == 1,
		"gold %d, hint %d, weekly_claim kind all %d lần; mong đợi 4300, 5, 1" % [int(r.game.s.coins), int(r.game.s.inv.hint),
		all_n])
	return true


## TC_CA_WP_051. Save L27, tut_seen true, VIP, points 160, mọi ô Main Tree đã nhận, end_seen false, ts 1800000000.
static func _wpp_bank(r) -> bool:
	var all11 := range(11)
	if not await _wp_open(r, {"level": 27, "tut_seen": true, "vip": true, "points": 160, "claimed_free": all11,
			"claimed_vip": all11, "end_seen": false}):
		return false
	if not await _wp_home(r):
		return false
	var wp := await _wp_layer(r)
	if wp == null:
		return false
	r.tc("TC_CA_WP_051", bool(r.game.s.weekly.get("end_seen", false)),
		"sau khi mở layer: end_seen %s; mong đợi true (giả định OQ-02)" % str(r.game.s.weekly.get("end_seen")))
	var banks: Array = wp.get("bank_buttons")
	if banks.size() < 10:
		r.tc("TC_CA_WP_051", false, "Bonus Bank có %d ô; mong đợi Bank0..Bank9" % banks.size())
		return true
	await Scen.scroll_into_view(r, banks[0] as Control)
	var step := _find_label(wp, "Every 15 extra keys")
	var bad := PackedStringArray()
	for i in 10:
		var want := "Claim" if i < 2 else "Lock"
		if not _wp_has(banks[i] as Node, want):
			bad.append("Bank%d thiếu %s" % [i, want])
	r.tc("TC_CA_WP_051", step != null and bad.is_empty(), "dòng \"Every 15 extra keys\" %s; %s; mong đợi có, Bank0 và Bank1 pill Claim, Bank2..Bank9 Lock"
		% [_yes(step != null), "; ".join(bad) if not bad.is_empty() else "trạng thái ô đúng"])
	await r.tap(banks[0] as Control, "Bonus Bank: Bank0")
	await r.wait_sec(0.8)
	var b0: Node = (wp.get("bank_buttons") as Array)[0] if (wp.get("bank_buttons") as Array).size() > 0 else null
	r.tc("TC_CA_WP_051", int(r.game.s.coins) == 3400 and _wl(r, "claimed_bank") == "[0]" and _wp_has(b0, "Claimed"),
		"bấm Bank0: gold %d, claimed_bank %s, Bank0 tích %s; mong đợi 3400, [0], có" % [int(r.game.s.coins),
		_wl(r, "claimed_bank"), _yes(_wp_has(b0, "Claimed"))])
	return true


## TC_CA_WP_052. Save L27, tut_seen true, không VIP, points 200, mọi ô free đã nhận, ts 1800000000.
static func _wpp_bank_locked(r) -> bool:
	if not await _wp_open(r, {"level": 27, "tut_seen": true, "points": 200, "claimed_free": range(11)}):
		return false
	if not await _wp_home(r):
		return false
	var wp := await _wp_layer(r)
	if wp == null:
		return false
	await _scroll_bottom(r, wp)
	var msg := _find_label(wp, "Reach the last milestone with VIP to unlock the Bonus Bank.")
	var in_view := msg != null and _in_list_view(r, msg)
	var banks := wp.find_children("Bank*", "", true, false).size()
	var claim: Dictionary = r.game.weekly_claim_bank(0)
	r.tc("TC_CA_WP_052", in_view and banks == 0 and int(r.game.s.coins) == 3000 and _wl(r, "claimed_bank") == "[]"
		and claim.is_empty(),
		"dòng khoá Bonus Bank hiện %s, nút Bank* %d, gold %d, claimed_bank %s, weekly_claim_bank(0) %s; mong đợi có, 0, 3000, [], {}"
		% [_yes(in_view), banks, int(r.game.s.coins), _wl(r, "claimed_bank"), str(claim)])
	return true


# ---------------------------------------------------------------- WP: mua VIP

## TC_CA_WP_056. Save L27, tut_seen true, points 3, claimed_free [0], ts 1800000000, store giả trả ok.
static func _wpp_buy_vip(r) -> bool:
	if not await _wp_open(r, {"level": 27, "tut_seen": true, "points": 3, "claimed_free": [0]}):
		return false
	if not await _wp_home(r):
		return false
	var wp := await _wp_layer(r)
	if wp == null:
		return false
	var label := _txt(Scen.find_visible(wp, "BuyVipButton"), "Out")
	var buys0 := (r.game.s.buys as Array).size()
	if not await Scen.tap_named(r, "BuyVipButton", wp):
		return false
	await Scen.wait_for(r, func() -> bool: return WeeklyPass.is_vip(r.game.s), 10000, "weekly_pass.gd")
	await r.wait_sec(1.0)
	var buys: Array = r.game.s.buys
	var last_sku := str((buys.back() as Dictionary).get("sku", "")) if not buys.is_empty() else ""
	var calls := _buy_calls(r, "weekly_pass")
	r.tc("TC_CA_WP_056", label == "Get VIP for $4.99" and WeeklyPass.is_vip(r.game.s) and buys.size() == buys0 + 1
		and last_sku == "weekly_pass" and calls == 1,
		"nút \"%s\"; vip %s, đơn %d → %d (%s), Platform.iap buy weekly_pass %d lần; mong đợi \"Get VIP for $4.99\", true, +1 weekly_pass, 1"
		% [label, WeeklyPass.is_vip(r.game.s), buys0, buys.size(), last_sku, calls])
	var lv: Dictionary = r.game.lives_view()
	r.tc("TC_CA_WP_056", int(r.game.s.lives.get("bonus", 0)) == 3 and int(lv.count) == 13 and int(lv.max) == 13
		and _hud(r).lives == "13",
		"bonus %d, mạng %d, Lives.max_for %d, chip mạng \"%s\"; mong đợi 3, 13, 13, \"13\"" % [
		int(r.game.s.lives.get("bonus", 0)), int(lv.count), int(lv.max), _hud(r).lives])
	var vip_label := _txt(wp, "VipLabel")
	r.tc("TC_CA_WP_056", Scen.find_visible(wp, "BuyVipButton") == null
		and vip_label == "VIP active - +3 max hearts this week",
		"BuyVipButton %s, VipLabel \"%s\"; mong đợi ẩn, \"VIP active - +3 max hearts this week\"" % [
		_yes(Scen.find_visible(wp, "BuyVipButton") != null), vip_label])
	var cards := PackedStringArray()
	for i in 2:
		var v := _wp_card(wp, "vip", i)
		if not _wp_has(v, "Claim") or _wp_has(v, "Lock"):
			cards.append("Vip%d" % i)
	var evs := _ev(r, "weekly_vip")
	r.tc("TC_CA_WP_056", cards.is_empty() and _ev_one(evs, {"points": 3}),
		"thẻ chưa có pill hoặc còn Lock: %s; weekly_vip %s; mong đợi không, {points 3}" % [", ".join(cards), _ev_txt(evs)])
	if not await _wp_close(r, wp):
		return false
	var h := _home_wp(r)
	r.tc("TC_CA_WP_056", h.caption == "Weekly Pass (3)", "Home: Caption \"%s\"; mong đợi \"Weekly Pass (3)\"" % h.caption)
	return true


## TC_CA_WP_057 (huỷ), 061 (lỗi khi mất mạng), 058 (lỗi khi có mạng), 059 (pending), cùng một layer. Save L27, tut_seen
## true, points 3, ts 1800000000. Thứ tự này để dòng báo lỗi của lần trước không còn khi chấm case cần layer không có
## ToastLabel.
static func _wpp_buy_fail(r) -> bool:
	if not await _wp_open(r, {"level": 27, "tut_seen": true, "points": 3}):
		return false
	if not await _wp_home(r):
		return false
	var wp := await _wp_layer(r)
	if wp == null:
		return false
	var buys0 := (r.game.s.buys as Array).size()
	# TC_CA_WP_057: store giả trả cancel.
	if not await _wp_buy_try(r, wp, "cancel"):
		return false
	var lv: Dictionary = r.game.lives_view()
	var buy := Scen.find_visible(wp, "BuyVipButton") as BaseButton
	r.tc("TC_CA_WP_057", not WeeklyPass.is_vip(r.game.s) and (r.game.s.buys as Array).size() == buys0
		and int(lv.count) == 10 and int(lv.max) == 10,
		"huỷ: vip %s, đơn %d → %d, mạng %d/%d; mong đợi false, không đổi, 10/10" % [WeeklyPass.is_vip(r.game.s), buys0,
		(r.game.s.buys as Array).size(), int(lv.count), int(lv.max)])
	r.tc("TC_CA_WP_057", buy != null and not buy.disabled and Scen.find_visible(wp, "ToastLabel") == null
		and _wp_has(_wp_card(wp, "vip", 0), "Lock"),
		"BuyVipButton hiện và bấm được %s, ToastLabel %s, Vip0 Lock %s; mong đợi có, không, có" % [
		_yes(buy != null and not buy.disabled), _yes(Scen.find_visible(wp, "ToastLabel") != null),
		_yes(_wp_has(_wp_card(wp, "vip", 0), "Lock"))])
	# TC_CA_WP_061: store giả trả error, game.test_online = 0.
	r.game.test_online = 0
	if not await _wp_buy_try(r, wp, "error"):
		return false
	var net: bool = await Scen.wait_for(r, func() -> bool: return r.popup_script("popup_no_internet.gd") != null, 4000,
		"popup_no_internet.gd")
	lv = r.game.lives_view()
	r.tc("TC_CA_WP_061", net and Scen.find_visible(wp, "ToastLabel") == null and not WeeklyPass.is_vip(r.game.s)
		and (r.game.s.buys as Array).size() == buys0 and int(lv.max) == 10,
		"mất mạng: popup Mất kết nối %s, ToastLabel %s, vip %s, đơn %d → %d, mạng tối đa %d; mong đợi có, không, false, không đổi, 10"
		% [_yes(net), _yes(Scen.find_visible(wp, "ToastLabel") != null), WeeklyPass.is_vip(r.game.s), buys0,
		(r.game.s.buys as Array).size(), int(lv.max)])
	if net:
		var pop: Node = r.popup_script("popup_no_internet.gd")
		await Scen.tap_named(r, "Ok", pop)
		await r.wait_sec(1.0)
		var held := r.popup_script("popup_no_internet.gd") != null
		r.game.test_online = 1
		await Scen.tap_named(r, "Ok", pop)
		var gone: bool = await Scen.wait_for(r, func() -> bool: return r.popup_script("popup_no_internet.gd") == null,
			4000, "weekly_pass.gd")
		r.tc("TC_CA_WP_061", held and gone and is_instance_valid(wp) and r.popup_script("weekly_pass.gd") == wp,
			"Thử lại khi vẫn mất mạng: popup %s; có mạng: popup %s, layer %s; mong đợi giữ, đóng, còn mở" % [
			"giữ" if held else "đóng", "đóng" if gone else "còn", "còn" if r.popup_script("weekly_pass.gd") == wp else "đóng"])
	r.game.test_online = 1
	# TC_CA_WP_058: store giả trả error, có mạng.
	if not await _wp_buy_try(r, wp, "error"):
		return false
	await r.wait_sec(0.5)
	buy = Scen.find_visible(wp, "BuyVipButton") as BaseButton
	r.tc("TC_CA_WP_058", _txt(wp, "ToastLabel") == "The purchase didn't go through."
		and r.popup_script("popup_no_internet.gd") == null and buy != null and not buy.disabled
		and not WeeklyPass.is_vip(r.game.s) and (r.game.s.buys as Array).size() == buys0,
		"ToastLabel \"%s\", popup Mất kết nối %s, BuyVipButton bấm được %s, vip %s, đơn %d → %d; mong đợi \"The purchase didn't go through.\", không, có, false, không đổi"
		% [_txt(wp, "ToastLabel"), _yes(r.popup_script("popup_no_internet.gd") != null),
		_yes(buy != null and not buy.disabled), WeeklyPass.is_vip(r.game.s), buys0, (r.game.s.buys as Array).size()])
	# TC_CA_WP_059: store giả trả pending.
	if not await _wp_buy_try(r, wp, "pending"):
		return false
	await r.wait_sec(0.5)
	lv = r.game.lives_view()
	r.tc("TC_CA_WP_059", _txt(wp, "ToastLabel") == "Your purchase is pending." and not WeeklyPass.is_vip(r.game.s)
		and (r.game.s.buys as Array).size() == buys0 and int(lv.max) == 10,
		"ToastLabel \"%s\", vip %s, đơn %d → %d, Lives.max_for %d; mong đợi \"Your purchase is pending.\", false, không đổi, 10"
		% [_txt(wp, "ToastLabel"), WeeklyPass.is_vip(r.game.s), buys0, (r.game.s.buys as Array).size(), int(lv.max)])
	return true


## TC_CA_WP_095 rồi 062: store giả giữ giao dịch (SlowIap). Save L27, tut_seen true, points 3, claimed_free [0].
static func _wpp_buy_wait(r) -> bool:
	if not await _wp_open(r, {"level": 27, "tut_seen": true, "points": 3, "claimed_free": [0]}):
		return false
	var slow := SlowIap.new()
	r.plat.iap = slow
	if not await _wp_home(r):
		return false
	var wp := await _wp_layer(r)
	if wp == null:
		return false
	# TC_CA_WP_095: trong lúc chờ store nút mờ và khoá; Free1 không nhận; Huỷ thì bấm lại được.
	if not await Scen.tap_named(r, "BuyVipButton", wp):
		return false
	await r.wait_until(func() -> bool: return slow.entered >= 1, 3000)
	await r.wait_frames(3)
	var buy := Scen.find_visible(wp, "BuyVipButton") as BaseButton
	var off := buy != null and buy.disabled
	await r.tc_look("TC_CA_WP_095", "wp095_buy_waiting")
	await _wp_tap(r, wp, "free", 1)
	r.tc("TC_CA_WP_095", off and int(r.game.s.coins) == 3000 and _wl(r, "claimed_free") == "[0]",
		"đang chờ store: BuyVipButton.disabled %s; bấm Free1: gold %d, claimed_free %s; mong đợi true, 3000, [0]" % [
		str(off), int(r.game.s.coins), _wl(r, "claimed_free")])
	slow.simulate("cancel")
	slow.hold = false
	await Scen.wait_for(r, func() -> bool: return not bool(wp.get("_busy")), 4000, "weekly_pass.gd")
	await r.wait_sec(0.4)
	buy = Scen.find_visible(wp, "BuyVipButton") as BaseButton
	r.tc("TC_CA_WP_095", buy != null and not buy.disabled, "sau Huỷ: BuyVipButton bấm được %s; mong đợi có" % _yes(
		buy != null and not buy.disabled))
	# TC_CA_WP_062: 20 lần chạm BuyVipButton trong 1 giây, store giả trả ok.
	slow.hold = true
	slow.entered = 0
	var buys0 := (r.game.s.buys as Array).size()
	var calls0 := _buy_calls(r, "weekly_pass")
	if buy == null:
		return r.fail("layer không có BuyVipButton")
	await _spam(r, buy)
	var during := slow.entered
	var off2 := buy.disabled if is_instance_valid(buy) else false
	slow.simulate("ok")
	slow.hold = false
	await Scen.wait_for(r, func() -> bool: return WeeklyPass.is_vip(r.game.s), 6000, "weekly_pass.gd")
	await r.wait_sec(1.0)
	var calls := _buy_calls(r, "weekly_pass") - calls0
	r.tc("TC_CA_WP_062", during == 1 and calls == 1 and (r.game.s.buys as Array).size() == buys0 + 1
		and int(r.game.s.lives.get("bonus", 0)) == 3 and int(r.game.lives_view().count) == 13 and off2,
		"lần gọi store khi bấm dồn %d, iap buy weekly_pass %d, đơn %d → %d, bonus %d, mạng %d, nút khoá lúc chờ %s; mong đợi 1, 1, +1, 3, 13 (không phải 16), true"
		% [during, calls, buys0, (r.game.s.buys as Array).size(), int(r.game.s.lives.get("bonus", 0)),
		int(r.game.lives_view().count), str(off2)])
	return true


## TC_CA_WP_069. Save L27, tut_seen true, VIP, mốc 0 đã nhận, bonus 3, mạng 13/13, ts 1800230390: đổi giờ sang T2 00:01
## lúc ở Home. Mốc 0 chưa nhận thì lúc chốt mùa VIP tự nhận 15 phút mạng vô hạn và chip mạng hiện đồng hồ, không hiện số.
static func _wpp_waiting_open(r) -> bool:
	if not await _wp_open(r, {"level": 27, "tut_seen": true, "vip": true, "claimed_free": [0], "claimed_vip": [0],
			"bonus": 3, "count": 13, "t": 1800230390}):
		return false
	if not await _wp_home(r):
		return false
	r.game.test_now = 1800230460
	r.step("giờ giả 1800230390 → 1800230460 (T2 00:01) lúc ở Home")
	await r.wait_sec(2.0)
	var lv: Dictionary = r.game.lives_view()
	r.tc("TC_CA_WP_069", int(lv.max) == 10 and int(lv.count) == 10 and _hud(r).lives == "10",
		"Lives.max_for %d, mạng %d, chip mạng \"%s\"; mong đợi 10, 10, \"10\"" % [int(lv.max), int(lv.count), _hud(r).lives])
	r.tc("TC_CA_WP_069", str(r.game.weekly_state()) == "waiting" and not WeeklyPass.is_vip(r.game.s),
		"weekly_state %s, s.weekly.vip %s; mong đợi waiting, false (mùa đã chốt)" % [str(r.game.weekly_state()),
		WeeklyPass.is_vip(r.game.s)])
	return true


# ---------------------------------------------------------------- WP: Upsell

## TC_CA_WP_070, 072. Save L28, tut_seen true, points 1, không VIP, upsell "", ts 1800000000.
static func _wpp_upsell(r) -> bool:
	if not await _wp_open(r, {"level": 28, "tut_seen": true, "points": 1, "upsell": ""}):
		return false
	var up := await _wp_upsell_wait(r)
	if up == null:
		r.tc("TC_CA_WP_070", false, "về Home mà không có popup_weekly_upsell")
		return true
	var perks := PackedStringArray([_txt(up, "Perk1"), _txt(up, "Perk2"), _txt(up, "Perk3")])
	var want_perks := "VIP rewards at every milestone | Bonus Bank: extra gold for extra keys | +3 max lives all season"
	var price := _txt(Scen.find_visible(up, "BuyButton"), "Out")
	var time := _txt(Scen.find_visible(up, "TimePill"), "Text (TMP)")
	r.tc("TC_CA_WP_070", time == "2d 16h left" and " | ".join(perks) == want_perks and price == "$4.99",
		"TimePill \"%s\", %s, BuyButton \"%s\"; mong đợi \"2d 16h left\", %s, \"$4.99\"" % [time, " | ".join(perks), price,
		want_perks])
	var evs := _ev(r, "weekly_upsell")
	r.tc("TC_CA_WP_070", str(r.game.s.weekly.get("upsell", "")) == "W20829" and _ev_one(evs, {"points": 1}),
		"s.weekly.upsell \"%s\", weekly_upsell %s; mong đợi \"W20829\", {points 1}" % [str(r.game.s.weekly.get("upsell")),
		_ev_txt(evs)])
	# TC_CA_WP_072: X, về Home lần hai, rồi mùa sau.
	var x := Scen.find_close(up)
	if x == null or not await r.tap(x, "Upsell: X"):
		return r.fail("Upsell không có nút X")
	var closed: bool = await Scen.wait_for(r, func() -> bool: return r.popup_script("popup_weekly_upsell.gd") == null,
		4000, "*")
	r.tc("TC_CA_WP_072", closed and not WeeklyPass.is_vip(r.game.s) and int(r.game.s.coins) == 3000,
		"X: Upsell %s, vip %s, gold %d; mong đợi đóng, false, 3000" % ["đóng" if closed else "còn",
		WeeklyPass.is_vip(r.game.s), int(r.game.s.coins)])
	if not await _ensure_playing(r, 28):
		return false
	if not await _to_home(r, "popup_weekly_upsell.gd"):
		return false
	var again: bool = await Scen.wait_for(r, func() -> bool: return r.popup_script("popup_weekly_upsell.gd") != null,
		2500, "popup_weekly_upsell.gd")
	r.tc("TC_CA_WP_072", not again and str(r.game.s.weekly.get("upsell", "")) == "W20829",
		"Home lần 2: Upsell %s, upsell \"%s\"; mong đợi không, \"W20829\"" % [_yes(again), str(r.game.s.weekly.get("upsell"))])
	if again:
		await Scen.settle_all(r)
	r.plat.emit_signal("paused")
	r.game.test_now = 1800252001
	r.plat.emit_signal("resumed")
	r.step("paused, giờ giả 1800252001 (mùa W20836), resumed")
	await r.wait_sec(0.5)
	if (await _wp_win(r, 28)).is_empty():
		return false
	if not await Scen.after_win(r, 28):
		return false
	up = await _wp_upsell_wait(r)
	r.tc("TC_CA_WP_072", up != null and WeeklyPass.points(r.game.s) == 1
		and str(r.game.s.weekly.get("upsell", "")) == "W20836",
		"mùa W20836 có %d key: Upsell %s, upsell \"%s\"; mong đợi 1, hiện lại, \"W20836\"" % [WeeklyPass.points(r.game.s),
		_yes(up != null), str(r.game.s.weekly.get("upsell"))])
	return true


## TC_CA_WP_071. Save L28, tut_seen true, points 1, không VIP, upsell "", ts 1800000000, store giả trả ok.
static func _wpp_upsell_buy(r) -> bool:
	if not await _wp_open(r, {"level": 28, "tut_seen": true, "points": 1, "upsell": ""}):
		return false
	var up := await _wp_upsell_wait(r)
	if up == null:
		return r.fail("về Home mà không có popup_weekly_upsell")
	var buys0 := (r.game.s.buys as Array).size()
	if not await Scen.tap_named(r, "BuyButton", up):
		return false
	var wp := await _wait_popup(r, "weekly_pass.gd", 10000, "weekly_pass.gd")
	await r.wait_sec(1.0)
	var up_gone := r.popup_script("popup_weekly_upsell.gd") == null
	r.tc("TC_CA_WP_071", up_gone and wp != null and Scen.find_visible(wp, "BuyVipButton") == null
		and Scen.find_visible(wp, "VipLabel") != null and _wp_has(_wp_card(wp, "vip", 0), "Claim"),
		"Upsell %s, layer %s, BuyVipButton %s, VipLabel %s, Vip0 pill Claim %s; mong đợi đóng, mở, ẩn, hiện, có" % [
		"đóng" if up_gone else "còn", _yes(wp != null), _yes(wp != null and Scen.find_visible(wp, "BuyVipButton") != null),
		_yes(wp != null and Scen.find_visible(wp, "VipLabel") != null), _yes(wp != null and _wp_has(_wp_card(wp, "vip", 0),
		"Claim"))])
	var buys: Array = r.game.s.buys
	r.tc("TC_CA_WP_071", WeeklyPass.is_vip(r.game.s) and int(r.game.s.lives.get("bonus", 0)) == 3
		and int(r.game.lives_view().count) == 13 and buys.size() == buys0 + 1
		and str((buys.back() as Dictionary).get("sku", "")) == "weekly_pass",
		"vip %s, bonus %d, mạng %d, đơn %d → %d; mong đợi true, 3, 13, +1 weekly_pass" % [WeeklyPass.is_vip(r.game.s),
		int(r.game.s.lives.get("bonus", 0)), int(r.game.lives_view().count), buys0, buys.size()])
	return true


## TC_CA_WP_074. Save L28, tut_seen true, points 1, không VIP, upsell "", ts 1800000000, store giả trả cancel.
static func _wpp_upsell_cancel(r) -> bool:
	if not await _wp_open(r, {"level": 28, "tut_seen": true, "points": 1, "upsell": ""}):
		return false
	var up := await _wp_upsell_wait(r)
	if up == null:
		return r.fail("về Home mà không có popup_weekly_upsell")
	var buys0 := (r.game.s.buys as Array).size()
	var calls0: int = r.plat.iap.calls.size()
	r.plat.iap.simulate("cancel")
	if not await Scen.tap_named(r, "BuyButton", up):
		return false
	await Scen.wait_for(r, func() -> bool: return r.plat.iap.calls.size() > calls0, 6000, "popup_weekly_upsell.gd")
	await r.wait_sec(1.0)
	var still: bool = is_instance_valid(up) and r.popup_script("popup_weekly_upsell.gd") == up
	var again: bool = still and await r.reachable(Scen.find_visible(up, "BuyButton") as Control)
	r.tc("TC_CA_WP_074", still and again, "sau Huỷ: Upsell %s, BuyButton bấm lại được %s; mong đợi vẫn mở, có (giả định OQ-11)"
		% ["còn" if still else "đóng", _yes(again)])
	r.tc("TC_CA_WP_074", not WeeklyPass.is_vip(r.game.s) and (r.game.s.buys as Array).size() == buys0
		and int(r.game.lives_view().max) == 10 and r.popup_script("weekly_pass.gd") == null,
		"vip %s, đơn %d → %d, mạng tối đa %d, layer Weekly Pass %s; mong đợi false, không đổi, 10, không mở" % [
		WeeklyPass.is_vip(r.game.s), buys0, (r.game.s.buys as Array).size(), int(r.game.lives_view().max),
		_yes(r.popup_script("weekly_pass.gd") != null)])
	return true


## TC_CA_WP_075. Save L28, tut_seen true, points 1, không VIP, upsell "", ts 1800000000, store giả trả ok: 20 lần chạm
## nút giá trong 1 giây. Store giả giữ giao dịch suốt lúc bấm dồn (như hộp thoại Play che màn) rồi mới trả ok, không có
## lớp phủ Mua / Huỷ chen vào khi chạy window.
static func _wpp_upsell_spam(r) -> bool:
	if not await _wp_open(r, {"level": 28, "tut_seen": true, "points": 1, "upsell": ""}):
		return false
	var up := await _wp_upsell_wait(r)
	if up == null:
		return r.fail("về Home mà không có popup_weekly_upsell")
	var buys0 := (r.game.s.buys as Array).size()
	var b := Scen.find_visible(up, "BuyButton") as Control
	await r._wait_still(b, Time.get_ticks_msec() + 2000)
	var slow := SlowIap.new()
	r.plat.iap = slow
	await _spam(r, b)
	slow.simulate("ok")
	slow.hold = false
	await Scen.wait_for(r, func() -> bool: return WeeklyPass.is_vip(r.game.s), 6000, "weekly_pass.gd")
	await r.wait_sec(2.0)
	r.tc("TC_CA_WP_075", slow.entered == 1 and _buy_calls(r, "weekly_pass") == 1
		and (r.game.s.buys as Array).size() == buys0 + 1
		and int(r.game.lives_view().count) == 13 and _count_script(r, "weekly_pass.gd") == 1,
		"iap buy weekly_pass %d lần, đơn %d → %d, mạng %d, layer Weekly Pass %d; mong đợi 1, +1, 13, đúng 1" % [
		_buy_calls(r, "weekly_pass"), buys0, (r.game.s.buys as Array).size(), int(r.game.lives_view().count),
		_count_script(r, "weekly_pass.gd")])
	return true


# ---------------------------------------------------------------- WP: sang mùa

## TC_CA_WP_077. Save L27, VIP, points 40, claimed [], tut_seen true, bonus 3, mạng 13/13, ghi lúc ts 1800000000; tắt app,
## mở lại lúc ts 1800252001 (T2 06:00:01).
static func _wpp_season_vip(r) -> bool:
	if not await _wp_open(r, {"level": 27, "cycle": "W20829", "vip": true, "points": 40, "claimed_free": [],
			"claimed_vip": [], "tut_seen": true, "bonus": 3, "count": 13}):
		return false
	var ends0 := _ev(r, "weekly_end").size()
	if not await _wp_relaunch(r, 1800252001):
		return false
	var s: Dictionary = r.game.s
	r.tc("TC_CA_WP_077", int(s.coins) == 5100 and int(s.inv.hint) == 5 and int(s.inv.move) == 6 and int(s.inv.smash) == 3
		and int(s.lives.get("inf_until", 0)) == 1800254701,
		"gold %d, hint %d, move %d, smash %d, inf_until %d; mong đợi 5100 (free 450 + VIP 1.650), 5, 6, 3, 1800254701 (+45 phút)"
		% [int(s.coins), int(s.inv.hint), int(s.inv.move), int(s.inv.smash), int(s.lives.get("inf_until", 0))])
	var w: Dictionary = s.weekly
	r.tc("TC_CA_WP_077", str(w.cycle) == "W20836" and int(w.points) == 0 and not bool(w.vip)
		and _ints(w.claimed_free).is_empty() and _ints(w.claimed_vip).is_empty() and _ints(w.claimed_bank).is_empty()
		and not bool(w.end_seen) and bool(w.tut_seen),
		"s.weekly: cycle %s, points %d, vip %s, claimed %s/%s/%s, end_seen %s, tut_seen %s; mong đợi W20836, 0, false, [] [] [], false, true"
		% [str(w.cycle), int(w.points), str(w.vip), str(w.claimed_free), str(w.claimed_vip), str(w.claimed_bank),
		str(w.end_seen), str(w.tut_seen)])
	var ends := _ev(r, "weekly_end").slice(ends0)
	r.tc("TC_CA_WP_077", int(s.lives.get("bonus", 0)) == 0 and int(r.game.lives_view().count) == 10
		and _ev_one(ends, {"coins": 2100}),
		"bonus %d, mạng %d, weekly_end %s; mong đợi 0, 10, đúng một lần {coins 2100}" % [int(s.lives.get("bonus", 0)),
		int(r.game.lives_view().count), _ev_txt(ends)])
	if not await _wp_home(r):
		return false
	var wp := await _wp_layer(r)
	if wp == null:
		return false
	var title := _txt(wp, "txtHeader")
	var end := _txt(wp, "EndLabel")
	var want := "Your unclaimed rewards were collected for you: 2100 gold, Hint x2, +3 Move x3, Unlimited lives 45 min"
	var keys := ""
	var buy := false
	var pill := false
	if Scen.find_visible(wp, "EndOkButton") != null and await Scen.tap_named(r, "EndOkButton", wp):
		await r.wait_sec(0.8)
		keys = _txt(wp, "KeysLabel")
		buy = Scen.find_visible(wp, "BuyVipButton") != null
		pill = _wp_has(_wp_card(wp, "free", 0), "Claim")
	r.tc("TC_CA_WP_077", title == "Season ended" and end == want, "popup cuối mùa \"%s\": \"%s\"; mong đợi \"Season ended\": \"%s\""
		% [title, end, want])
	r.tc("TC_CA_WP_077", keys == "0 / 130 keys" and buy and pill,
		"OK: KeysLabel \"%s\", BuyVipButton %s, Free0 pill Claim %s; mong đợi \"0 / 130 keys\", hiện, có" % [keys, _yes(buy),
		_yes(pill)])
	return true


## TC_CA_WP_078. Save L27, không VIP, points 12, claimed_free [0], tut_seen true; tắt app, mở lại lúc ts 1800252001.
static func _wpp_season_free(r) -> bool:
	if not await _wp_open(r, {"level": 27, "cycle": "W20829", "points": 12, "claimed_free": [0], "tut_seen": true}):
		return false
	var inf := int(r.game.s.lives.get("inf_until", 0))
	var ends0 := _ev(r, "weekly_end").size()
	if not await _wp_relaunch(r, 1800252001):
		return false
	var s: Dictionary = r.game.s
	r.tc("TC_CA_WP_078", int(s.coins) == 3000 and int(s.inv.hint) == 3 and int(s.inv.move) == 3 and int(s.inv.smash) == 3
		and int(s.lives.get("inf_until", 0)) == inf,
		"gold %d, booster %d/%d/%d, inf_until %d → %d; mong đợi 3000, 3/3/3, không đổi" % [int(s.coins), int(s.inv.hint),
		int(s.inv.move), int(s.inv.smash), inf, int(s.lives.get("inf_until", 0))])
	var w: Dictionary = s.weekly
	var ends := _ev(r, "weekly_end").slice(ends0)
	r.tc("TC_CA_WP_078", str(w.cycle) == "W20836" and int(w.points) == 0 and _ints(w.claimed_free).is_empty()
		and _ev_one(ends, {"coins": 0}),
		"cycle %s, points %d, claimed_free %s, weekly_end %s; mong đợi W20836, 0, [], {coins 0}" % [str(w.cycle),
		int(w.points), str(w.claimed_free), _ev_txt(ends)])
	if not await _wp_home(r):
		return false
	var wp := await _wp_layer(r)
	if wp == null:
		return false
	var end := _txt(wp, "EndLabel")
	var ticked := true
	if Scen.find_visible(wp, "EndOkButton") != null and await Scen.tap_named(r, "EndOkButton", wp):
		await r.wait_sec(0.8)
		ticked = _wp_has(_wp_card(wp, "free", 1), "Claimed")
	r.tc("TC_CA_WP_078", end == "You earned 12 keys this season. A new season is coming!" and not ticked,
		"EndLabel \"%s\", sau OK Free1 có tích %s; mong đợi \"You earned 12 keys this season. A new season is coming!\", không"
		% [end, _yes(ticked)])
	return true


## TC_CA_WP_079. Save L27, cycle W20829, points 0, không VIP, claimed_free [0], tut_seen true; mở app lúc ts 1800252001.
static func _wpp_season_none(r) -> bool:
	if not await _wp_open(r, {"level": 27, "cycle": "W20829", "points": 0, "claimed_free": [0], "tut_seen": true,
			"t": 1800252001}):
		return false
	var pending: Dictionary = r.game.s.weekly.get("pending_end", {})
	var ends := _ev(r, "weekly_end")
	r.tc("TC_CA_WP_079", pending.is_empty() and ends.is_empty(), "pending_end %s, weekly_end %d lần; mong đợi {}, 0" % [
		str(pending), ends.size()])
	if not await _wp_home(r):
		return false
	var wp := await _wp_layer(r)
	if wp == null:
		return false
	r.tc("TC_CA_WP_079", Scen.find_visible(wp, "EndLabel") == null and Scen.find_visible(wp, "KeysLabel") != null,
		"layer: EndLabel %s, pass mùa mới %s; mong đợi không có, vào thẳng pass" % [
		_yes(Scen.find_visible(wp, "EndLabel") != null), _yes(Scen.find_visible(wp, "KeysLabel") != null)])
	return true


## TC_CA_WP_082. Save L27, tut_seen true, VIP, points 5, claimed [], bonus 3, mạng 13/13, ts 1800230300: paused, giờ sang
## 1800230700 (T2 00:05), resumed.
static func _wpp_resume_settle(r) -> bool:
	if not await _wp_open(r, {"level": 27, "tut_seen": true, "vip": true, "points": 5, "claimed_free": [],
			"claimed_vip": [], "bonus": 3, "count": 13, "t": 1800230300}):
		return false
	if not await _wp_home(r):
		return false
	var gold := int(r.game.s.coins)
	r.plat.emit_signal("paused")
	r.game.test_now = 1800230700
	r.plat.emit_signal("resumed")
	r.step("paused, giờ giả 1800230300 → 1800230700, resumed")
	await r.wait_sec(1.2)
	var w: Dictionary = r.game.s.weekly
	r.tc("TC_CA_WP_082", str(w.cycle) == "W20836" and not bool(w.vip) and int(w.points) == 0,
		"cycle %s, vip %s, points %d; mong đợi W20836, false, 0" % [str(w.cycle), str(w.vip), int(w.points)])
	r.tc("TC_CA_WP_082", int(r.game.s.coins) == gold + 450 and int(r.game.s.lives.get("inf_until", 0)) == 1800233400
		and int(r.game.s.lives.get("bonus", 0)) == 0 and int(r.game.lives_view().count) == 10,
		"gold %d → %d, inf_until %d, bonus %d, mạng %d; mong đợi +450 (free 100 + VIP 350), 1800233400 (+45 phút), 0, 10" % [
		gold, int(r.game.s.coins), int(r.game.s.lives.get("inf_until", 0)), int(r.game.s.lives.get("bonus", 0)),
		int(r.game.lives_view().count)])
	var h := _home_wp(r)
	r.tc("TC_CA_WP_082", h.caption == "Weekly Pass" and bool(h.dot),
		"Home: Caption \"%s\", WeeklyDot %s; mong đợi \"Weekly Pass\", hiện (popup cuối mùa đang chờ)" % [h.caption,
		_yes(h.dot)])
	return true


## TC_CA_WP_083. Save L27, tut_seen true, không VIP, points 5, claimed_free [0], ts 1800230395: layer mở khi qua T2 00:00.
static func _wpp_layer_cross(r) -> bool:
	if not await _wp_open(r, {"level": 27, "tut_seen": true, "points": 5, "claimed_free": [0], "t": 1800230395}):
		return false
	if not await _wp_home(r):
		return false
	var wp := await _wp_layer(r)
	if wp == null:
		return false
	var pill := _wp_has(_wp_card(wp, "free", 1), "Claim")
	r.game.test_now = 1800230401
	r.step("giờ giả 1800230395 → 1800230401 lúc layer mở")
	await r.wait_sec(2.0)
	var wl := _txt(wp, "WaitingLabel")
	var cards := Scen.find_visible(wp, "Free0") != null or Scen.find_visible(wp, "Free1") != null
	r.tc("TC_CA_WP_083", pill and wl.contains("opens in 5:59:59") and not cards and int(r.game.s.coins) == 3000,
		"trước: Free1 pill %s; sau 2 giây: WaitingLabel \"%s\", còn thẻ %s, gold %d; mong đợi có, \"... opens in 5:59:59 ...\", không, 3000"
		% [_yes(pill), wl.replace("\n", " | "), _yes(cards), int(r.game.s.coins)])
	var close := Scen.find_visible(wp, "Ok") as Control
	if close == null:
		close = Scen.find_close(wp)
	await r.tap(close, "đóng layer")
	await Scen.wait_for(r, func() -> bool: return r.popup_script("weekly_pass.gd") == null, 4000)
	await r.wait_sec(0.5)
	wp = await _wp_layer(r)
	if wp == null:
		return false
	var end := _txt(wp, "EndLabel")
	var after := ""
	if Scen.find_visible(wp, "EndOkButton") != null and await Scen.tap_named(r, "EndOkButton", wp):
		await r.wait_sec(0.6)
		after = _txt(wp, "WaitingLabel")
	r.tc("TC_CA_WP_083", end == "You earned 5 keys this season. A new season is coming!" and after != "",
		"mở lại: popup cuối mùa \"%s\", OK → WaitingLabel %s; mong đợi \"You earned 5 keys this season. A new season is coming!\", có"
		% [end, _yes(after != "")])
	return true


# ---------------------------------------------------------------- WP: giao diện, dữ liệu, analytics, hiệu năng

## TC_CA_WP_090. Save L27, tut_seen true, points 4, claimed_free [0], không VIP, ts 1800000000, tiếng Anh.
static func _wpp_layer_content(r) -> bool:
	if not await _wp_open(r, {"level": 27, "tut_seen": true, "points": 4, "claimed_free": [0]}):
		return false
	if not await _wp_home(r):
		return false
	var wp := await _wp_layer(r)
	if wp == null:
		return false
	r.tc("TC_CA_WP_090", _txt(wp, "txtHeader") == "Weekly Pass" and _txt(wp, "TimeLabel") == "2d 16h left"
		and _txt(wp, "KeysLabel") == "4 / 130 keys",
		"tiêu đề \"%s\", TimeLabel \"%s\", KeysLabel \"%s\"; mong đợi \"Weekly Pass\", \"2d 16h left\", \"4 / 130 keys\"" % [
		_txt(wp, "txtHeader"), _txt(wp, "TimeLabel"), _txt(wp, "KeysLabel")])
	var marks := PackedStringArray()
	for i in 11:
		marks.append(_txt(wp.find_child("Milestone%d" % i, true, false), "Text (TMP)"))
	var want_marks := "0, 3, 8, 15, 25, 38, 52, 68, 85, 105, 130"
	r.tc("TC_CA_WP_090", _txt(wp.find_child("FreeTab", true, false), "Text") == "Free"
		and _txt(wp.find_child("VipTab", true, false), "Text") == "VIP" and ", ".join(marks) == want_marks,
		"FreeTab \"%s\", VipTab \"%s\", kim cương %s; mong đợi \"Free\", \"VIP\", %s" % [
		_txt(wp.find_child("FreeTab", true, false), "Text"), _txt(wp.find_child("VipTab", true, false), "Text"),
		", ".join(marks), want_marks])
	var cards := {"Free0": ["15m"], "Vip0": ["150"], "Free1": ["100"], "Vip1": ["200", "30m"], "Free2": ["x1"],
		"Vip2": ["300", "x1"]}
	var bad := PackedStringArray()
	for n: String in cards:
		var texts := _wp_card_texts(wp.find_child(n, true, false))
		for t: String in cards[n]:
			if not texts.has(t):
				bad.append("%s %s thiếu \"%s\"" % [n, str(texts), t])
	r.tc("TC_CA_WP_090", bad.is_empty(), "số trên thẻ: %s; mong đợi Free0 \"15m\", Vip0 \"150\", Free1 \"100\", Vip1 \"200\" \"30m\", Free2 \"x1\", Vip2 \"300\" \"x1\""
		% ("; ".join(bad) if not bad.is_empty() else "đúng"))
	var buy := _txt(Scen.find_visible(wp, "BuyVipButton"), "Out")
	var hint := _txt(wp, "VipHint")
	var want_hint := TranslationServer.translate("weekly_vip_hint") + " +3 max hearts this week"
	var all_btn: BaseButton = wp.get("claim_all_button")
	var all_txt := _txt(all_btn, "Out")
	r.tc("TC_CA_WP_090", buy == "Get VIP for $4.99" and hint == want_hint and all_txt == "Claim all" and all_btn != null
		and not all_btn.disabled,
		"BuyVipButton \"%s\", VipHint \"%s\", ClaimAllButton \"%s\" tương tác %s; mong đợi \"Get VIP for $4.99\", weekly_vip_hint + \"+3 max hearts this week\", \"Claim all\", có"
		% [buy, hint, all_txt, _yes(all_btn != null and not all_btn.disabled)])
	await r.tc_look("TC_CA_WP_090", "wp090_layer_top")
	await _scroll_bottom(r, wp)
	var bank_t := _find_label(wp, "Bonus Bank")
	var bank_m := _find_label(wp, "Reach the last milestone with VIP to unlock the Bonus Bank.")
	r.tc("TC_CA_WP_090", bank_t != null and bank_m != null and _in_list_view(r, bank_m),
		"cuối danh sách: \"Bonus Bank\" %s, dòng khoá %s; mong đợi có, có" % [_yes(bank_t != null),
		_yes(bank_m != null and _in_list_view(r, bank_m))])
	var probs := _text_problems(r, wp)
	r.tc("TC_CA_WP_090", probs.is_empty(), "chữ trong layer: %s" % ("; ".join(probs) if not probs.is_empty() else "không tràn, không ra ngoài"))
	await r.tc_look("TC_CA_WP_090", "wp090_layer_bottom")
	return true


## TC_CA_WP_094. Save L27, tut_seen true, không VIP, points 130, claimed [], ts 1800000000.
static func _wpp_drag(r) -> bool:
	if not await _wp_open(r, {"level": 27, "tut_seen": true, "points": 130, "claimed_free": [], "claimed_vip": []}):
		return false
	if not await _wp_home(r):
		return false
	var wp := await _wp_layer(r)
	if wp == null:
		return false
	var list: Control = wp.get("_list")
	var f1 := _wp_card(wp, "free", 1)
	if list == null or f1 == null:
		return r.fail("layer không có danh sách hoặc ô Free1")
	var y0 := list.position.y
	var from: Vector2 = r.to_viewport(f1, f1.size * 0.5)
	var up := 600.0 * (r.view_rect() as Rect2).size.y / 1920.0
	r.step("kéo từ Free1 lên 600 px (màn chuẩn)")
	await r.drag(from, from - Vector2(0, up), 12)
	await r.wait_sec(0.8)
	list = wp.get("_list")
	r.tc("TC_CA_WP_094", absf(list.position.y - y0) > 1.0 and int(r.game.s.coins) == 3000
		and _wl(r, "claimed_free") == "[]",
		"sau kéo: content y %.0f → %.0f, gold %d, claimed_free %s; mong đợi đổi, 3000, []" % [y0, list.position.y,
		int(r.game.s.coins), _wl(r, "claimed_free")])
	var f10 := _wp_card(wp, "free", 10)
	if f10 == null or not await Scen.scroll_into_view(r, f10):
		return r.fail("không cuộn tới được Free10")
	await r.tap(f10, "Weekly Pass: ô Free10 (chạm, không kéo)")
	await r.wait_sec(0.8)
	r.tc("TC_CA_WP_094", int(r.game.s.coins) == 3500 and int(r.game.s.inv.smash) == 4 and _wl(r, "claimed_free") == "[10]",
		"chạm Free10: gold %d, smash %d, claimed_free %s; mong đợi 3500, 4, [10]" % [int(r.game.s.coins),
		int(r.game.s.inv.smash), _wl(r, "claimed_free")])
	return true


## TC_CA_WP_098. Save L27, tut_seen true, points 2, claimed_free [0], ts 1800000000, store giả trả ok: thắng L27, Free1, mua
## VIP, Vip0, tắt app, mở lại lúc ts 1800000060.
static func _wpp_kill_save(r) -> bool:
	if not await _wp_open(r, {"level": 27, "tut_seen": true, "points": 2, "claimed_free": [0]}):
		return false
	var c := await _wp_win(r, 27)
	if c.is_empty():
		return false
	if not await Scen.after_win(r, 27):
		return false
	if not await _wp_home(r):
		return false
	var wp := await _wp_layer(r)
	if wp == null or not await _wp_tap(r, wp, "free", 1):
		return false
	if not await Scen.tap_named(r, "BuyVipButton", wp):
		return false
	if not await Scen.wait_for(r, func() -> bool: return WeeklyPass.is_vip(r.game.s), 10000, "weekly_pass.gd"):
		return r.fail("mua VIP mà chưa có VIP")
	await r.wait_sec(0.6)
	if not await _wp_tap(r, wp, "vip", 0):
		return false
	var gold := int(r.game.s.coins)
	var want_gold := 3000 + 40 + 10 * int(c.moves) + 100 + 150
	if not await _wp_relaunch(r, 1800000060):
		return false
	var s: Dictionary = r.game.s
	var w: Dictionary = s.weekly
	r.tc("TC_CA_WP_098", int(s.coins) == gold and int(s.coins) == want_gold and int(w.points) == 3
		and _ints(w.claimed_free) == [0, 1] and _ints(w.claimed_vip) == [0] and bool(w.vip) and bool(w.tut_seen),
		"mở lại: gold %d (trước khi tắt %d), points %d, claimed_free %s, claimed_vip %s, vip %s, tut_seen %s; mong đợi %d (3.000 + thắng L27 với MOVES %d + 100 + 150), 3, [0, 1], [0], true, true"
		% [int(s.coins), gold, int(w.points), str(_ints(w.claimed_free)), str(_ints(w.claimed_vip)), str(w.vip),
		str(w.tut_seen), want_gold, int(c.moves)])
	var wp_buys := (s.buys as Array).filter(func(e: Variant) -> bool:
		return e is Dictionary and str((e as Dictionary).get("sku", "")) == "weekly_pass").size()
	r.tc("TC_CA_WP_098", int(s.lives.get("bonus", 0)) == 3 and int(r.game.lives_view().count) == 13 and wp_buys == 1,
		"bonus %d, mạng %d, đơn weekly_pass %d; mong đợi 3, 13, 1" % [int(s.lives.get("bonus", 0)),
		int(r.game.lives_view().count), wp_buys])
	if not await _wp_home(r):
		return false
	wp = await _wp_layer(r)
	if wp == null:
		return false
	await r.wait_sec(1.0)
	r.tc("TC_CA_WP_098", _wp_has(_wp_card(wp, "free", 1), "Claimed") and _wp_has(_wp_card(wp, "vip", 0), "Claimed")
		and Scen.find_visible(wp, "BuyVipButton") == null and not is_instance_valid(wp.get("tutorial")),
		"layer: Free1 tích %s, Vip0 tích %s, BuyVipButton %s, tutorial %s; mong đợi có, có, ẩn, không" % [
		_yes(_wp_has(_wp_card(wp, "free", 1), "Claimed")), _yes(_wp_has(_wp_card(wp, "vip", 0), "Claimed")),
		_yes(Scen.find_visible(wp, "BuyVipButton") != null), _yes(is_instance_valid(wp.get("tutorial")))])
	return true


## TC_CA_WP_099. Save L27, s.weekly mặc định, ts 1800000000, game.test_online = 0.
static func _wpp_offline(r) -> bool:
	if not await _wp_open(r, {"level": 27, "online": 0}):
		return false
	var net := {"seen": false}
	var watch := func() -> void:
		if r.popup_script("popup_no_internet.gd") != null:
			net["seen"] = true
	if not await _wp_home(r):
		return false
	var wp := await _wp_layer(r)
	if wp == null:
		return false
	for k in 3:
		var tut := await _tut_ready(r, wp, k)
		if tut == null:
			return r.fail("tutorial không tới bước %d" % (k + 1))
		watch.call()
		await _tap_bg(r, tut)
	await Scen.wait_for(r, func() -> bool: return is_instance_valid(wp.get("howto")), 5000, "weekly_pass.gd")
	var tut_ok: bool = r.game.weekly_tutorial_seen()
	if is_instance_valid(wp.get("howto")):
		await Scen.tap_named(r, "OkButton", wp.get("howto"))
		await r.wait_sec(0.6)
	watch.call()
	if not await _wp_tap(r, wp, "free", 0):
		return false
	watch.call()
	var inf := int(r.game.s.lives.get("inf_until", 0))
	if not await _wp_close(r, wp):
		return false
	if (await _wp_win(r, 27)).is_empty():
		return false
	watch.call()
	r.tc("TC_CA_WP_099", tut_ok and inf == 1800000900 and WeeklyPass.points(r.game.s) == 1 and not bool(net.seen),
		"không mạng: tutorial xong %s, Free0 inf_until %d, thắng L27 points %d, popup Mất kết nối %s; mong đợi có, 1800000900, 1, không"
		% [_yes(tut_ok), inf, WeeklyPass.points(r.game.s), _yes(bool(net.seen))])
	return true


## TC_CA_WP_103. Save L27, s.weekly mặc định, ts 1800000000, store giả trả ok: mở layer → tutorial → Free0 → thắng L27 →
## mở lại layer, mua VIP.
static func _wpp_analytics(r) -> bool:
	if not await _wp_open(r, {"level": 27}):
		return false
	if not await _wp_home(r):
		return false
	var wp := await _wp_layer(r)
	if wp == null:
		return false
	for k in 3:
		var tut := await _tut_ready(r, wp, k)
		if tut == null:
			return r.fail("tutorial không tới bước %d" % (k + 1))
		await _tap_bg(r, tut)
	await Scen.wait_for(r, func() -> bool: return is_instance_valid(wp.get("howto")), 5000, "weekly_pass.gd")
	if is_instance_valid(wp.get("howto")):
		await Scen.tap_named(r, "OkButton", wp.get("howto"))
		await r.wait_sec(0.6)
	if not await _wp_tap(r, wp, "free", 0):
		return false
	if not await _wp_close(r, wp):
		return false
	if (await _wp_win(r, 27)).is_empty():
		return false
	if not await Scen.after_win(r, 27):
		return false
	if not await _wp_home(r):
		return false
	wp = await _wp_layer(r)
	if wp == null or not await Scen.tap_named(r, "BuyVipButton", wp):
		return false
	await Scen.wait_for(r, func() -> bool: return WeeklyPass.is_vip(r.game.s), 10000, "weekly_pass.gd")
	await r.wait_sec(0.6)
	var opens := _ev(r, "weekly_open")
	var opens_ok := opens.size() == 2 and _ev_one(opens.slice(0, 1), {"points": 0, "vip": 0}) \
		and _ev_one(opens.slice(1, 2), {"points": 1, "vip": 0})
	r.tc("TC_CA_WP_103", opens_ok, "weekly_open %s; mong đợi {points 0, vip 0} rồi {points 1, vip 0}" % _ev_txt(opens))
	var checks := [["weekly_tutorial", {"points": 0}], ["weekly_claim", {"kind": "free", "coins": 0, "points": 0}],
		["weekly_points", {"level": 27, "points": 1, "total": 1}], ["weekly_vip", {"points": 1}]]
	for c: Array in checks:
		var evs := _ev(r, str(c[0]))
		r.tc("TC_CA_WP_103", _ev_one(evs, c[1]), "%s %s; mong đợi một lần %s" % [str(c[0]), _ev_txt(evs),
			JSON.stringify(c[1])])
	return true


## TC_CA_WP_104. Save L27, tut_seen true, VIP, points 160, end_seen true, ts 1800000000: mở, cuộn tới Bank9 và về đầu,
## đóng; lặp 5 lần. Ngưỡng desktop là đề xuất của case.
static func _wpp_perf(r) -> bool:
	if not await _wp_open(r, {"level": 27, "tut_seen": true, "vip": true, "points": 160, "end_seen": true}):
		return false
	if not await _wp_home(r):
		return false
	var p95 := 0.0
	var worst := 0.0
	var slow_open := 0.0
	var nodes: Array[int] = []
	var orphans := 0
	for i in 5:
		var btn := Scen.find_visible(r.main.current_screen, "WeeklyPassButton") as Control
		if btn == null:
			return r.fail("Home không có WeeklyPassButton")
		await Scen.settle_all(r)
		r.begin_phase("weekly_open")
		var t0 := Time.get_ticks_msec()
		await r.tap(btn, "WeeklyPassButton (lần %d)" % (i + 1))
		var wp := await _wait_popup(r, "weekly_pass.gd", 6000, "weekly_pass.gd")
		if wp == null:
			return r.fail("bấm WeeklyPassButton không mở layer")
		var until := Time.get_ticks_msec() + 4000
		while Time.get_ticks_msec() < until and not await r.reachable(_wp_card(wp, "free", 0)):
			await r.wait_frames(1)
		slow_open = maxf(slow_open, (Time.get_ticks_msec() - t0) / 1000.0 * Engine.time_scale)
		var a := _p95_max(r._phase_times)
		r.end_phase()
		r.begin_phase("weekly_scroll")
		var banks: Array = wp.get("bank_buttons")
		if not banks.is_empty():
			await Scen.scroll_into_view(r, banks.back() as Control)
		await Scen.scroll_into_view(r, _wp_card(wp, "free", 0))
		var b := _p95_max(r._phase_times)
		r.end_phase()
		p95 = maxf(p95, maxf(a[0], b[0]))
		worst = maxf(worst, maxf(a[1], b[1]))
		if not await _wp_close(r, wp):
			return false
		r.mem("weekly lần %d" % (i + 1))
		nodes.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		orphans = maxi(orphans, int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)))
	r.tc("TC_CA_WP_104", p95 <= 33.0 and worst <= 99.0,
		"FRAMES weekly_open/weekly_scroll p95 lớn nhất %.1f ms, khung chậm nhất %.1f ms; mong đợi ≤ 33 ms, không khung > 99 ms (đề xuất)"
		% [p95, worst])
	r.tc("TC_CA_WP_104", slow_open <= 1.0, "Free0 bấm được sau %.2f giây (giờ game) kể từ lúc bấm nút; mong đợi ≤ 1 giây (đề xuất)"
		% slow_open)
	r.tc("TC_CA_WP_104", nodes.back() <= nodes[0] + 20 and orphans == 0,
		"số node sau mỗi lần mở/đóng %s, orphan lớn nhất %d; mong đợi không tăng dần, 0" % [str(nodes), orphans])
	return true


# ---------------------------------------------------------------- WP: bố cục nhiều tỉ lệ màn và ngôn ngữ

## TC_CA_WP_034. Cửa sổ 443x960. Save L29 (HARD), tut_seen true: hai ô; save L51 (HARD, Màn đặc biệt đã mở, ngăn vé
## trống): ba ô, tiếng Anh rồi de, ru.
static func _wpp_cells(r) -> bool:
	r.root.size = WP_RES_STD
	await r.wait_frames(3)
	if not await _wp_open(r, {"level": 29, "tut_seen": true}):
		return false
	if (await _wp_win(r, 29)).is_empty():
		return false
	var gold := _cell(r, "GoldReward")
	var key := _cell(r, "WeeklyKeyReward")
	if gold == null or key == null:
		r.tc("TC_CA_WP_034", false, "thẻ thắng L29: ô gold %s, ô chìa %s; mong đợi có, có" % [_yes(gold != null),
			_yes(key != null)])
		return true
	var gx := _cx(r, gold)
	var kx := _cx(r, key)
	var row := _cx(r, gold.get_parent() as Control)
	var d2 := kx - gx
	r.tc("TC_CA_WP_034", key.get_index() == gold.get_index() + 1 and d2 > 0.0 and _cell_txt(key) == "+3 keys"
		and absf((gx + kx) * 0.5 - row) <= 3.0,
		"L29: ô chìa sau ô gold %s, chữ \"%s\", tâm hai ô %.0f và %.0f quanh tâm dải %.0f; mong đợi có, \"+3 keys\", cách đều (lệch ≤ 3 px)"
		% [_yes(key.get_index() == gold.get_index() + 1), _cell_txt(key), gx, kx, row])
	await r.tc_look("TC_CA_WP_034", "wp034_two_cells_en")
	for lang in ["en", "de", "ru"]:
		if not await _wp_open(r, {"level": 51, "tut_seen": true, "lang": lang}):
			return false
		if (await _wp_win(r, 51)).is_empty():
			return false
		gold = _cell(r, "GoldReward")
		key = _cell(r, "WeeklyKeyReward")
		var tix := _cell(r, "SpecialTicketReward")
		if gold == null or key == null or tix == null:
			r.tc("TC_CA_WP_034", false, "%s L51: ô gold %s, chìa %s, vé %s; mong đợi ba ô" % [lang, _yes(gold != null),
				_yes(key != null), _yes(tix != null)])
			continue
		var labels: Array[Control] = []
		for c: Control in [gold, key, tix]:
			labels.append(c.get_node("RewardLabel") as Control)
		var overlap := false
		for i in 3:
			for j in range(i + 1, 3):
				var a: Rect2 = r._canvas_rect(labels[i])
				var b: Rect2 = r._canvas_rect(labels[j])
				overlap = overlap or a.grow(-1.0).intersects(b.grow(-1.0))
		var probs := _text_problems(r, key) + _text_problems(r, tix)
		var d_a := _cx(r, key) - _cx(r, gold)
		var d_b := _cx(r, tix) - _cx(r, key)
		if lang == "en":
			r.tc("TC_CA_WP_034", absf(d_a - d2) <= 3.0 and absf(d_b - d2) <= 3.0 and _cell_txt(key) == "+3 keys"
				and _cell_txt(tix) == "+1 ticket" and not overlap,
				"L51 ba ô: khoảng tâm %.0f, %.0f (hai ô %.0f), chữ \"%s\", \"%s\", chồng nhau %s; mong đợi bằng khoảng hai ô, \"+3 keys\", \"+1 ticket\" (special_ticket_reward), không"
				% [d_a, d_b, d2, _cell_txt(key), _cell_txt(tix), _yes(overlap)])
		else:
			r.tc("TC_CA_WP_034", probs.is_empty() and not overlap, "%s L51: %s, chồng nhau %s; mong đợi chữ ô chìa không tràn nhãn, không chồng"
				% [lang, "; ".join(probs) if not probs.is_empty() else "chữ vừa nhãn", _yes(overlap)])
		await r.tc_look("TC_CA_WP_034", "wp034_three_cells_%s" % lang)
	return true


## TC_CA_WP_014, 021, 020, 091 (mỗi cỡ cửa sổ một lần mở game, save L27 chưa xem tutorial, ts 1800000000) và 076 (save
## L28, tut_seen true, 1 key, không VIP). Cỡ đặt bằng r.root.size trước khi mở game; 020, 021, 076 chỉ liệt kê
## 443x960, 540x1200, 768x1024.
static func _wpp_res(r) -> bool:
	for res: Vector2i in [WP_RES_STD, WP_RES_20_9, WP_RES_21_9, WP_RES_4_3]:
		var tag := "%dx%d" % [res.x, res.y]
		var three := res != WP_RES_21_9
		r.root.size = res
		await r.wait_frames(3)
		if not await _wp_open(r, {"level": 27}):
			return false
		if not await _wp_home(r):
			return false
		await r.wait_sec(1.2)
		# TC_CA_WP_014
		var home: Node = r.main.current_screen
		var btn := Scen.find_visible(home, "WeeklyPassButton") as Control
		var item := home.find_child("WeeklyPassItem", true, false) as Control
		var dot := Scen.find_visible(home, "WeeklyDot") as Control
		var cap := item.get_node_or_null("Caption") as Label if item != null else null
		var ribbon := item.get_node_or_null("Ribbon") as Control if item != null else null
		var cap_w := _text_px(cap)
		var rib_w: float = (r._canvas_rect(ribbon) as Rect2).size.x if ribbon != null else 0.0
		var fits := cap != null and ribbon != null and cap_w <= rib_w + 2.0
		var corner := false
		if btn != null and dot != null:
			var br: Rect2 = r._canvas_rect(btn)
			var dc: Vector2 = (r._canvas_rect(dot) as Rect2).get_center()
			corner = dc.x >= br.get_center().x and dc.y <= br.get_center().y
		var reach: bool = await r.reachable(btn)
		var probs := _text_problems(r, item)
		r.tc("TC_CA_WP_014", cap != null and cap.text == "Weekly Pass (1)" and fits and corner and reach and probs.is_empty(),
			"%s: chữ ribbon \"%s\" rộng %.0f px (ribbon %.0f px), chấm đỏ ở góc trên phải %s, nút bấm được %s, %s; mong đợi \"Weekly Pass (1)\" không tràn, có, có, nhãn trong màn"
			% [tag, cap.text if cap != null else "", cap_w, rib_w, _yes(corner), _yes(reach), "; ".join(probs)
			if not probs.is_empty() else "nhãn trong màn"])
		await r.tc_look("TC_CA_WP_014", "wp014_home_%s" % tag)
		# TC_CA_WP_021
		var wp := await _wp_layer(r)
		if wp == null:
			return false
		for k in 3:
			var tut := await _tut_ready(r, wp, k)
			if tut == null:
				return r.fail("%s: tutorial không tới bước %d" % [tag, k + 1])
			if three:
				var st := _tut_step(tut)
				var spot := _spot_problems(tut)
				r.tc("TC_CA_WP_021", bool(st.hole) and spot.is_empty(), "%s bước %d (%s): lỗ %s; %s; mong đợi lỗ chứa target nới 10 px, BubbleLabel trong màn (lề ≥ 16) và không đè lỗ"
					% [tag, k + 1, st.target, "khớp" if bool(st.hole) else "không chứa target", "; ".join(spot)
					if not spot.is_empty() else "bảng thoại đúng chỗ"])
				if k == 0 or res == WP_RES_STD:
					await r.tc_look("TC_CA_WP_021", "wp021_%s_step%d" % [tag, k + 1])
			await _tap_bg(r, tut)
		await Scen.wait_for(r, func() -> bool: return is_instance_valid(wp.get("howto")), 5000, "weekly_pass.gd")
		if is_instance_valid(wp.get("howto")):
			await Scen.tap_named(r, "OkButton", wp.get("howto"))
			await Scen.wait_for(r, func() -> bool: return not is_instance_valid(wp.get("howto")), 3000, "weekly_pass.gd")
		# TC_CA_WP_020
		if three:
			if not await _wp_howto_layout(r, wp, tag):
				return false
		# TC_CA_WP_091
		var panel: Control = wp.get("ui").call("node", "Panel")
		var ribbon_w: Control = wp.get("ui").call("node", "Panel/Image")
		var x := Scen.find_visible(wp, "CloseButton") as Control
		var view: Rect2 = r.view_rect()
		var in_view := view.grow(2.0).encloses(r._canvas_rect(panel)) and view.grow(2.0).encloses(r._canvas_rect(ribbon_w))
		var gap := _gap(r, x)
		var buy_ok: bool = await r.reachable(Scen.find_visible(wp, "BuyVipButton") as Control)
		var all_ok: bool = await r.reachable(Scen.find_visible(wp, "ClaimAllButton") as Control)
		var lprobs := _text_problems(r, wp)
		r.tc("TC_CA_WP_091", in_view and gap >= 8.0 and buy_ok and all_ok and lprobs.is_empty(),
			"%s: panel và ruy băng trong màn %s, X cách mép %.0f, BuyVipButton bấm được %s, ClaimAllButton bấm được %s, %s; mong đợi có, ≥ 8, có, có, nhãn trong màn"
			% [tag, _yes(in_view), gap, _yes(buy_ok), _yes(all_ok), "; ".join(lprobs) if not lprobs.is_empty()
			else "nhãn trong màn"])
		await r.tc_look("TC_CA_WP_091", "wp091_layer_%s" % tag)
		await _scroll_bottom(r, wp)
		var last := _find_label(wp, "Reach the last milestone with VIP to unlock the Bonus Bank.")
		var bank9 := wp.find_child("Bank9", true, false) as Control
		var end_ok: bool = (bank9 != null and await r.reachable(bank9)) or (bank9 == null and last != null
			and _in_list_view(r, last))
		r.tc("TC_CA_WP_091", end_ok, "%s: cuối danh sách %s (%s); mong đợi cuộn tới được ô cuối" % [tag, _yes(end_ok),
			"Bank9" if bank9 != null else "chưa VIP nên không có Bank9, ô cuối là dòng khoá Bonus Bank"])
		if res == WP_RES_STD:
			await r.tc_look("TC_CA_WP_091", "wp091_layer_bottom_%s" % tag)
	for res: Vector2i in [WP_RES_STD, WP_RES_20_9, WP_RES_4_3]:
		r.root.size = res
		await r.wait_frames(3)
		if not await _wp_upsell_layout(r, "%dx%d" % [res.x, res.y], "en"):
			return false
	return true


## TC_CA_WP_020 (de, ru), 076 (de, ru, hi), 096 (en, de, ru) ở cửa sổ 443x960.
static func _wpp_lang_ui(r) -> bool:
	r.root.size = WP_RES_STD
	await r.wait_frames(3)
	for lang in ["de", "ru"]:
		if not await _wp_open(r, {"level": 27, "tut_seen": true, "lang": lang}):
			return false
		if not await _wp_home(r):
			return false
		var wp := await _wp_layer(r)
		if wp == null or not await _wp_howto_layout(r, wp, lang):
			return false
	for lang in ["de", "ru", "hi"]:
		if not await _wp_upsell_layout(r, lang, lang):
			return false
	for lang in ["en", "de", "ru"]:
		if not await _wp_open(r, {"level": 27, "cycle": "W20829", "vip": true, "points": 130, "claimed_free": [],
				"claimed_vip": [], "tut_seen": true, "t": 1800230401, "lang": lang}):
			return false
		if not await _wp_home(r):
			return false
		var wp := await _wp_layer(r)
		if wp == null:
			return false
		var el := Scen.find_visible(wp, "EndLabel") as Label
		if el == null:
			r.tc("TC_CA_WP_096", false, "%s: mở layer sau khi sang mùa mà không có popup cuối mùa" % lang)
			continue
		var well := el.get_parent().get_node_or_null("Image") as Control
		var inside := well != null and (r._canvas_rect(well) as Rect2).grow(2.0).encloses(r._canvas_rect(el))
		var probs := _text_problems(r, el)
		var ok_btn: bool = await r.reachable(Scen.find_visible(wp, "EndOkButton") as Control)
		r.tc("TC_CA_WP_096", inside and probs.is_empty() and ok_btn,
			"%s: EndLabel trong giếng kem %s, %s, EndOkButton bấm được %s; mong đợi có, không tràn, có" % [lang, _yes(inside),
			"; ".join(probs) if not probs.is_empty() else "chữ vừa", _yes(ok_btn)])
		await r.tc_look("TC_CA_WP_096", "wp096_end_%s" % lang)
		if not await Scen.tap_named(r, "EndOkButton", wp):
			return false
		await r.wait_sec(0.6)
		var w1 := _txt(wp, "WaitingLabel")
		await r.tc_look("TC_CA_WP_096", "wp096_waiting_%s" % lang)
		r.game.test_now = 1800230402
		await r.wait_sec(1.5)
		var w2 := _txt(wp, "WaitingLabel")
		r.tc("TC_CA_WP_096", w1.contains("5:59:59") and w2.contains("5:59:58"),
			"%s: WaitingLabel \"%s\" rồi \"%s\"; mong đợi ... 5:59:59 ... rồi 5:59:58 sau khi giờ tăng 1 giây" % [lang,
			w1.replace("\n", " | "), w2.replace("\n", " | ")])
	return true


## TC_CA_WP_092. Mỗi ngôn ngữ của Game.LANGS (save L27, chưa xem tutorial, ts 1800000000): tutorial 3 bước, How to earn
## rewards, pass Active; Waiting với popup cuối mùa VIP và không VIP; Upsell; thẻ thắng có ô chìa. Trạng thái mùa đổi
## bằng cách sửa s.weekly và giờ giả giữa các màn (điều khiển, không phải kỳ vọng).
static func _wpp_langs(r) -> bool:
	var langs: Array = (r.game.get_script() as Script).get_script_constant_map()["LANGS"]
	for lang: String in langs:
		if not await _wp_open(r, {"level": 27, "lang": lang}):
			return false
		var bad := PackedStringArray()
		if not await _wp_home(r):
			return false
		var wp := await _wp_layer(r)
		if wp == null:
			return false
		for k in 3:
			var tut := await _tut_ready(r, wp, k)
			if tut == null:
				return r.fail("%s: tutorial không tới bước %d" % [lang, k + 1])
			bad.append_array(_tag("tutorial %d" % (k + 1), _text_problems(r, tut)))
			await _tap_bg(r, tut)
		await Scen.wait_for(r, func() -> bool: return is_instance_valid(wp.get("howto")), 5000, "weekly_pass.gd")
		await r.wait_sec(0.5)
		if is_instance_valid(wp.get("howto")):
			bad.append_array(_tag("How to earn rewards", _text_problems(r, wp.get("howto"))))
			await Scen.tap_named(r, "OkButton", wp.get("howto"))
			await r.wait_sec(0.5)
		bad.append_array(_tag("pass Active", _text_problems(r, wp)))
		if not await _wp_close(r, wp):
			return false
		for vip in [true, false]:
			_wp_set_week(r, {"cycle": "W20829", "vip": vip, "points": 130 if vip else 12})
			r.game.test_now = 1800230401
			wp = await _wp_layer(r)
			if wp == null:
				return false
			await Scen.wait_for(r, func() -> bool: return Scen.find_visible(wp, "EndLabel") != null, 3000, "weekly_pass.gd")
			bad.append_array(_tag("cuối mùa %s" % ("VIP" if vip else "không VIP"), _text_problems(r, wp)))
			if Scen.find_visible(wp, "EndOkButton") != null:
				await Scen.tap_named(r, "EndOkButton", wp)
				await r.wait_sec(0.6)
			bad.append_array(_tag("Waiting", _text_problems(r, wp)))
			if not await _wp_close(r, wp):
				return false
		r.game.test_now = 1800000000
		_wp_set_week(r, {"cycle": "W20829", "vip": false, "points": 1, "upsell": ""})
		r.main.go("home")
		var up := await _wait_popup(r, "popup_weekly_upsell.gd", 5000, "popup_weekly_upsell.gd")
		if up != null:
			await r.wait_sec(0.6)
			bad.append_array(_tag("Upsell", _text_problems(r, up)))
			var x := Scen.find_close(up)
			if x != null:
				await r.tap(x, "Upsell: X")
			await Scen.wait_for(r, func() -> bool: return r.popup_script("popup_weekly_upsell.gd") == null, 3000, "*")
		else:
			bad.append("Upsell không hiện")
		if (await _wp_win(r, 27)).is_empty():
			return false
		var key := _cell(r, "WeeklyKeyReward")
		if key == null:
			bad.append("thẻ thắng không có ô chìa")
		else:
			bad.append_array(_tag("ô chìa", _text_problems(r, key)))
		r.tc("TC_CA_WP_092", bad.is_empty(), "%s: %s" % [lang, "; ".join(bad) if not bad.is_empty() else
			"không key chưa dịch, không tràn, không thiếu glyph, không còn %d/%s"])
	return true


# ---------------------------------------------------------------- WP: dùng chung

## Mở game với save dựng theo PRE COND của case: veteran (gold 3.000, mỗi booster 3, mạng 10/10) ở level `cfg.level`,
## ngôn ngữ `cfg.lang` (mặc định en), giờ giả `cfg.t` (mặc định 1800000000, tz 0), s.weekly thuộc chu kỳ của giờ đó (hoặc
## `cfg.cycle`) với các trường cfg có; `cfg.online` = game.test_online. Đã xem hướng dẫn và lời mời Màn đặc biệt.
static func _wp_open(r, cfg: Dictionary) -> bool:
	if not await r.open_game("WP", func(g: Node) -> void: _wp_prep(g, cfg)):
		return false
	r.step("save: %s" % JSON.stringify(cfg))
	return true


static func _wp_prep(g: Node, cfg: Dictionary) -> void:
	Saves.veteran(g)
	Saves._at_level(g, int(cfg.get("level", 27)), false)
	g.s.settings["lang"] = str(cfg.get("lang", "en"))
	g.s.special["guide"] = true
	g.s.special["invited"] = true
	var t := int(cfg.get("t", 1800000000))
	g.test_now = t
	g.test_tz = 0
	if cfg.has("online"):
		g.test_online = int(cfg.online)
	var w: Dictionary = g.s.weekly
	w["cycle"] = str(cfg.get("cycle", WeeklyPass.window(t, 0).cycle))
	for k in ["points", "vip", "tut_seen", "opened", "end_seen", "upsell"]:
		if cfg.has(k):
			w[k] = cfg[k]
	for k in ["claimed_free", "claimed_vip", "claimed_bank"]:
		if cfg.has(k):
			w[k] = (cfg[k] as Array).duplicate()
	var lives: Dictionary = g.s.lives
	for k in ["count", "bonus", "inf_until"]:
		if cfg.has(k):
			lives[k] = int(cfg[k])


## Sửa mùa của save đang chơi (điều khiển giữa các màn của TC_CA_WP_092): tut_seen true, chưa nhận ô nào, không có
## popup cuối mùa đang chờ, cộng các trường của `fields`.
static func _wp_set_week(r, fields: Dictionary) -> void:
	var w: Dictionary = r.game.s.weekly
	w["tut_seen"] = true
	w["claimed_free"] = []
	w["claimed_vip"] = []
	w["claimed_bank"] = []
	w["pending_end"] = {}
	w["end_seen"] = false
	for k in fields:
		w[k] = fields[k]


## Tắt app như Android: Platform.paused (Game lưu ngay) rồi bỏ mọi trạng thái trong bộ nhớ của Game (s, store, phiên)
## như tiến trình bị giết, rồi mở lại main trên cùng save lúc giờ giả `t`.
static func _wp_relaunch(r, t: int) -> bool:
	r.plat.emit_signal("paused")
	r.close_game()
	r.game.call("_clear_session")
	r.game.test_now = t
	r.game.test_tz = 0
	r.game.test_online = 1
	r.step("tắt app sau Platform.paused, mở lại trên cùng save lúc ts %d" % t)
	return await r._boot_main("WP", false)


## Từ màn level (game mở thẳng vào level) → Cài đặt → Home; đợi popup tự mở và đóng popup lạc (trừ `keep`).
static func _wp_home(r, keep: String = "") -> bool:
	if not await _to_home(r, keep):
		return false
	await r.wait_sec(0.6)
	if keep == "":
		await Scen.settle_all(r)
		await r.wait_sec(0.3)
		await Scen.settle_all(r)
	return true


## Về Home giữ popup Upsell; trả popup đó (null nếu không hiện trong 6 giây).
static func _wp_upsell_wait(r) -> Node:
	if not await _to_home(r, "popup_weekly_upsell.gd"):
		return null
	var up := await _wait_popup(r, "popup_weekly_upsell.gd", 6000, "popup_weekly_upsell.gd")
	if up != null:
		await r.wait_sec(0.8)
	return up


## Nút Weekly Pass ở Home: {visible, caption, dot}.
static func _home_wp(r) -> Dictionary:
	var home: Node = r.main.current_screen
	var item := home.find_child("WeeklyPassItem", true, false) as Control if home != null else null
	var cap := item.get_node_or_null("Caption") as Label if item != null else null
	var dot := home.find_child("WeeklyDot", true, false) as Control if home != null else null
	return {"visible": item != null and item.is_visible_in_tree(), "caption": cap.text if cap != null else "",
		"dot": dot != null and dot.is_visible_in_tree()}


## Chữ trên thanh trên của màn hiện tại: {lives (số trên tim, trống khi vô hạn), timer, gold}.
static func _hud(r) -> Dictionary:
	var out := {"lives": "", "timer": "", "gold": ""}
	var scr: Node = r.main.current_screen
	var top: Node = scr.find_child("HubTop", true, false) if scr != null else null
	if top == null:
		return out
	for k in [["lives", "LivesPanel/LivesLabel"], ["timer", "LivesPanel/LivesTimerLabel"], ["gold", "GoldPanel/GoldLabel"]]:
		var l := top.get_node_or_null(str(k[1])) as Label
		if l != null:
			out[k[0]] = l.text
	return out


## Bấm nút Weekly Pass ở Home, đợi layer mở xong. Smoke vừa đổi giờ qua thứ Hai 00:00 thì đợi Game chốt mùa trước
## (Timer mỗi giây, design.md mục 7): chốt xong Home làm mới và xếp lại cột bên, bấm giữa chừng thì trượt sang nút khác.
static func _wp_layer(r) -> Node:
	await Scen.wait_for(r, func() -> bool: return not _wp_season_due(r), 3000, "*")
	await Scen.settle_all(r)
	var wp := await _open_from_home(r, "WeeklyPassButton", "weekly_pass.gd")
	if wp != null:
		await r.wait_sec(0.7)
	return wp


## Mùa đã lưu cũ hơn tuần của giờ hiện tại: Game sắp chốt mùa. Giờ lùi (mùa đã lưu mới hơn) thì không chốt (OQ-05).
static func _wp_season_due(r) -> bool:
	var saved := WeeklyPass.cycle_day(str(r.game.s.weekly.get("cycle", "")))
	var cur := WeeklyPass.cycle_day(str(WeeklyPass.window(r.game.now(), int(r.game.call("_tz"))).cycle))
	return saved >= 0 and cur > saved


## Đóng layer bằng X, đợi Home làm mới nút (mỗi giây).
static func _wp_close(r, wp: Node) -> bool:
	if not await _close_popup(r, wp, "Weekly Pass"):
		return false
	await r.wait_sec(1.2)
	return true


## Chạm ô `kind` (free | vip) mốc `i` như ngón tay (cuộn tới nếu cần), đợi layer dựng lại.
static func _wp_tap(r, wp: Node, kind: String, i: int) -> bool:
	var b := _wp_card(wp, kind, i)
	if b == null:
		return r.fail("Weekly Pass không có ô %s%d" % [kind.capitalize(), i])
	if not await Scen.scroll_into_view(r, b):
		return r.fail("không cuộn được tới ô %s%d" % [kind.capitalize(), i])
	await r.tap(b, "Weekly Pass: ô %s%d" % [kind.capitalize(), i])
	await r.wait_sec(0.8)
	return true


## Ô thưởng Main Tree `kind` ("free" | "vip") của mốc `i` đang hiện (layer dựng lại ô sau mỗi lần nhận).
static func _wp_card(wp: Node, kind: String, i: int) -> Control:
	if not is_instance_valid(wp):
		return null
	var b: Variant = (wp.get("main_buttons") as Dictionary).get("%s_%d" % [kind, i])
	if b == null or not is_instance_valid(b):
		return null
	return b as Control


## `c` có node con tên `name` đang hiện (Claimed: tích, Claim: pill, Lock).
static func _wp_has(c: Node, name: String) -> bool:
	return c != null and is_instance_valid(c) and Scen.find_visible(c, name) != null


static func _wp_card_texts(c: Node) -> PackedStringArray:
	var out := PackedStringArray()
	if c == null:
		return out
	for l in c.find_children("*", "Label", true, false):
		if (l as Label).is_visible_in_tree() and (l as Label).text != "":
			out.append((l as Label).text)
	return out


## Trạng thái mua giả lập: đặt kết quả, bấm BuyVipButton, đợi store được gọi và layer thôi chờ.
static func _wp_buy_try(r, wp: Node, result: String) -> bool:
	var n: int = r.plat.iap.calls.size()
	r.plat.iap.simulate(result)
	if not await Scen.tap_named(r, "BuyVipButton", wp):
		return false
	await Scen.wait_for(r, func() -> bool: return r.plat.iap.calls.size() > n, 6000, "popup_no_internet.gd")
	await Scen.wait_for(r, func() -> bool: return not bool(wp.get("_busy")), 4000, "popup_no_internet.gd")
	await r.wait_frames(3)
	return true


static func _buy_calls(r, sku: String) -> int:
	return (r.plat.iap.calls as Array).filter(func(c: Dictionary) -> bool: return str(c.get("sku", "")) == sku).size()


## Thắng level `lvl` (đang chơi, hoặc bấm Chơi ở Home), đợi thẻ thắng. {moves (MOVES còn lúc thắng), before (gold trước
## khi thắng)}; {} khi hỏng (đã r.fail).
static func _wp_win(r, lvl: int) -> Dictionary:
	if not await _ensure_playing(r, lvl):
		return {}
	var before := int(r.game.s.coins)
	if not await Scen.win_level(r):
		return {}
	var lv: Control = r.level_screen()
	var moves: int = lv.board.moves_left() if lv != null else -1
	if not await Scen.wait_for(r, func() -> bool: return r.popup_node("ContinueButton") != null, 20000,
			"ContinueButton"):
		r.fail("thắng L%d mà không có thẻ thắng" % lvl)
		return {}
	await r.wait_sec(0.8)
	r.step("thắng L%d: MOVES còn %d, gold %d → %d" % [lvl, moves, before, int(r.game.s.coins)])
	return {"moves": moves, "before": before}


## Bấm Tiếp tục ở thẻ thắng L`lvl`, đợi level kế hoặc Home: {ok, home} (home: đã qua Home).
static func _wp_continue(r, lvl: int) -> Dictionary:
	var cont := r.popup_node("ContinueButton") as Control
	if cont == null:
		r.fail("không có nút Tiếp tục")
		return {"ok": false, "home": false}
	await r.tap(cont, "Tiếp tục")
	var seen := {"home": false}
	var ok: bool = await Scen.wait_for(r, func() -> bool:
		if r.screen_name() == "home":
			seen["home"] = true
		return bool(seen.home) or Scen._playing(r) > lvl, 20000)
	return {"ok": ok, "home": bool(seen.home)}


## Thanh tính năng của thẻ thắng sau khi chạy xong: {label, pct, before, after}.
static func _wp_feature(r) -> Dictionary:
	await r.wait_sec(2.0)
	var card: Node = r.popup_script("win_card.gd")
	if card == null:
		return {"label": "", "pct": "", "before": -1.0, "after": -1.0}
	var b: Variant = card.get("_prog_before")
	var a: Variant = card.get("_prog_after")
	return {"label": _txt(card, "FeatureLabel"), "pct": _txt(card, "FeaturePercent"),
		"before": float(b) if b != null else -1.0, "after": float(a) if a != null else -1.0}


## Ô `name` đang hiện trên thẻ thắng (GoldReward, WeeklyKeyReward, SpecialTicketReward), null nếu không có.
static func _cell(r, name: String) -> Control:
	var c := r.popup_node(name) as Control
	return c if c != null and c.is_visible_in_tree() else null


static func _cell_txt(c: Control) -> String:
	var l := c.get_node_or_null("RewardLabel") as Label if c != null else null
	return l.text if l != null else ""


## Overlay tutorial ở bước `k`, xong hiệu ứng chuyển bước; null nếu không tới trong 6 giây.
static func _tut_ready(r, wp: Node, k: int) -> Control:
	var ok: bool = await Scen.wait_for(r, func() -> bool: return _tut_at(wp, k), 6000, "weekly_pass.gd")
	if not ok:
		return null
	return wp.get("tutorial") as Control


static func _tut_at(wp: Node, k: int) -> bool:
	if not is_instance_valid(wp):
		return false
	var t: Variant = wp.get("tutorial")
	return is_instance_valid(t) and int((t as Object).get("index")) == k and not bool((t as Object).get("busy"))


## {index, target (tên node), text (BubbleLabel), hole (lỗ chứa khung target nới 10 px, không rộng hơn nhiều)}.
static func _tut_step(tut: Control) -> Dictionary:
	if tut == null or not is_instance_valid(tut):
		return {"index": -1, "target": "", "text": "", "hole": false}
	var k := int(tut.get("index"))
	var steps: Array = tut.get("steps")
	var target: Variant = (steps[k] as Dictionary).get("target") if k >= 0 and k < steps.size() else null
	var label := tut.get("label") as Label
	var hole := false
	if is_instance_valid(target):
		var h: Rect2 = tut.call("hole_rect")
		var at := Rect2(h.position + tut.global_position, h.size)
		var want := (target as Control).get_global_rect().grow(10.0)
		hole = at.grow(1.0).encloses(want) and want.grow(3.0).encloses(at)
	return {"index": k, "target": str((target as Node).name) if is_instance_valid(target) else "",
		"text": label.text if label != null else "", "hole": hole}


## Bảng thoại của bước đang hiện: trong màn với lề ≥ 16 đơn vị canvas, không đè lên lỗ.
static func _spot_problems(tut: Control) -> PackedStringArray:
	var out := PackedStringArray()
	var bubble := tut.get("bubble") as Control
	if bubble == null:
		out.append("không có bảng thoại")
		return out
	var br := bubble.get_global_rect()
	var screen := tut.get_global_rect()
	var k: float = tut.call("_scale")
	var edge := 16.0 * k
	if br.position.x < screen.position.x + edge - 1.0 or br.position.y < screen.position.y + edge - 1.0 \
			or br.end.x > screen.end.x - edge + 1.0 or br.end.y > screen.end.y - edge + 1.0:
		out.append("bảng thoại sát hoặc ra ngoài màn (%s trong %s)" % [str(br), str(screen)])
	var h: Rect2 = tut.call("hole_rect")
	if br.grow(-1.0).intersects(Rect2(h.position + tut.global_position, h.size)):
		out.append("bảng thoại đè lên lỗ")
	return out


## Chạm nền của overlay tutorial (góc trên trái, ngoài lỗ).
static func _tap_bg(r, tut: Control) -> void:
	r.step("chạm nền tutorial (góc trên trái)")
	await r.click_at(r.to_viewport(tut, Vector2(30, 30)))


## TC_CA_WP_020 trên layer `wp` đang mở: bấm "i", đo popup How to earn rewards, chụp, OK.
static func _wp_howto_layout(r, wp: Node, tag: String) -> bool:
	var info := Scen.find_visible(wp, "InfoButton") as Control
	if info == null or not await r.tap(info, "InfoButton"):
		return r.fail("%s: không bấm được InfoButton" % tag)
	if not await Scen.wait_for(r, func() -> bool: return is_instance_valid(wp.get("howto")), 4000, "weekly_pass.gd"):
		return r.fail("%s: InfoButton không mở How to earn rewards" % tag)
	await r.wait_sec(0.6)
	var h: Node = wp.get("howto")
	var base := "Canvas/PopupOkLayer/Panel"
	var panel := h.get_node_or_null(base) as Control
	var x := h.get_node_or_null(base + "/Top/btnTurnOff") as Control
	var view: Rect2 = r.view_rect()
	var bad := PackedStringArray()
	if panel == null or not view.grow(2.0).encloses(r._canvas_rect(panel)):
		bad.append("panel ra ngoài màn")
	# Vùng kem là một phần ảnh khung panel (Content/Image của PopupOkLayer ẩn): đo hàng và ghi chú nằm trong panel,
	# lùi vào 8 đơn vị, và không đè lên nhau; vùng kem nhìn bằng ảnh.
	var inner: Rect2 = (r._canvas_rect(panel) as Rect2).grow(-8.0 * _px(r)) if panel != null else Rect2()
	var parts: Array[Control] = []
	for n in ["KeyRowNormal", "KeyRowHard", "KeyRowVeryHard", "Note1", "Note2", "Note3", "OkButton"]:
		var c := h.find_child(n, true, false) as Control
		if c == null or not inner.encloses(r._canvas_rect(c)):
			bad.append("%s ra ngoài panel" % n)
		else:
			parts.append(c)
	for i in parts.size():
		for j in range(i + 1, parts.size()):
			if (r._canvas_rect(parts[i]) as Rect2).grow(-1.0).intersects((r._canvas_rect(parts[j]) as Rect2).grow(-1.0)):
				bad.append("%s đè %s" % [parts[i].name, parts[j].name])
	var ok_reach: bool = await r.reachable(Scen.find_visible(h, "OkButton") as Control)
	var x_reach: bool = await r.reachable(x)
	if not ok_reach:
		bad.append("OkButton không bấm được")
	if not x_reach:
		bad.append("X không bấm được")
	var gap := _gap(r, x)
	if gap < 8.0:
		bad.append("X cách mép %.0f" % gap)
	bad.append_array(_text_problems(r, h))
	r.tc("TC_CA_WP_020", bad.is_empty(), "%s: %s; mong đợi panel trong màn, 3 hàng key và 3 dòng ghi chú trong panel không đè nhau (giếng kem xem ảnh), OkButton và X bấm được, X cách mép ≥ 8, không tràn, không key thô"
		% [tag, "; ".join(bad) if not bad.is_empty() else "đúng"])
	await r.tc_look("TC_CA_WP_020", "wp020_howto_%s" % tag)
	await Scen.tap_named(r, "OkButton", h)
	await Scen.wait_for(r, func() -> bool: return not is_instance_valid(wp.get("howto")), 3000, "weekly_pass.gd")
	return true


## TC_CA_WP_076: save L28, tut_seen true, 1 key, không VIP, upsell "", ngôn ngữ `lang`; đo popup Upsell, chụp, X.
static func _wp_upsell_layout(r, tag: String, lang: String) -> bool:
	if not await _wp_open(r, {"level": 28, "tut_seen": true, "points": 1, "upsell": "", "lang": lang}):
		return false
	var up := await _wp_upsell_wait(r)
	if up == null:
		r.tc("TC_CA_WP_076", false, "%s: về Home mà không có Upsell" % tag)
		return true
	var x := Scen.find_visible(up, "btnTurnOff") as Control
	var panel := x.get_parent().get_parent() as Control if x != null else null
	var well := Scen.find_visible(up, "PerkWell") as Control
	var buy := Scen.find_visible(up, "BuyButton") as Control
	var view: Rect2 = r.view_rect()
	var bad := PackedStringArray()
	if panel == null or not view.grow(2.0).encloses(r._canvas_rect(panel)):
		bad.append("panel ra ngoài màn")
	var gap := _gap(r, x)
	if gap < 8.0:
		bad.append("X cách mép %.0f" % gap)
	if not await r.reachable(buy):
		bad.append("BuyButton không bấm được")
	for n in ["Perk1", "Perk2", "Perk3"]:
		var c := Scen.find_visible(up, n) as Control
		if c == null or well == null or not (r._canvas_rect(well) as Rect2).grow(2.0).encloses(r._canvas_rect(c)):
			bad.append("%s ngoài giếng kem" % n)
	var price := buy.get_node_or_null("Out") as Control if buy != null else null
	if price != null:
		for l in up.find_children("*", "Label", true, false):
			if l != price and (l as Label).is_visible_in_tree() and not buy.is_ancestor_of(l) and (l as Label).text != "" \
					and (r._canvas_rect(price) as Rect2).grow(-1.0).intersects(r._canvas_rect(l)):
				bad.append("giá đè %s" % l.name)
	bad.append_array(_text_problems(r, up))
	r.tc("TC_CA_WP_076", bad.is_empty(), "%s: %s; mong đợi panel trong màn, X cách mép ≥ 8, BuyButton bấm được, ba dòng quyền lợi trong giếng kem, không tràn, không ô vuông, giá không đè chữ"
		% [tag, "; ".join(bad) if not bad.is_empty() else "đúng"])
	await r.tc_look("TC_CA_WP_076", "wp076_upsell_%s" % tag)
	if x != null:
		await r.tap(x, "Upsell: X")
	return true


## Lỗi chữ của mọi Label đang hiện dưới `root` (như census): giống key tr() chưa dịch, còn %d / %s, ra ngoài màn, chữ một
## dòng rộng hơn nhãn, font thiếu glyph (ô vuông). Nhãn trong khung cắt chỉ tính phần trong khung.
static func _text_problems(r, root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	if root == null or not is_instance_valid(root):
		return out
	var re := RegEx.create_from_string(WP_RAW_KEY)
	var view: Rect2 = r.view_rect()
	var nodes: Array = root.find_children("*", "Label", true, false)
	if root is Label:
		nodes.append(root)
	for n in nodes:
		var l := n as Label
		if not l.is_visible_in_tree() or l.text.strip_edges().is_empty():
			continue
		var rect: Rect2 = r._canvas_rect(l)
		var clip: Variant = r._clip_of(l)
		if clip != null:
			if not (clip as Rect2).intersects(rect):
				continue
			rect = rect.intersection(clip as Rect2)
		var where := "%s \"%s\"" % [l.name, l.text.substr(0, 28).replace("\n", " ")]
		if re.search(l.text.strip_edges()) != null:
			out.append("%s: giống key chưa dịch" % where)
		if l.text.contains("%d") or l.text.contains("%s"):
			out.append("%s: còn %%d/%%s" % where)
		if rect.size.x > 1.0 and not view.grow(2.0).encloses(rect):
			out.append("%s: ra ngoài màn" % where)
		var font := _font(l)
		if font == null:
			continue
		var w := _text_w(l)
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF and not l.clip_text \
				and l.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING and w > l.size.x + 2.0:
			out.append("%s: chữ rộng %d, nhãn rộng %d" % [where, int(w), int(l.size.x)])
		var missing := ""
		for i in l.text.length():
			var ch := l.text.unicode_at(i)
			if ch > 32 and ch != 0xA0 and not font.has_char(ch):
				missing += char(ch)
		if missing != "":
			out.append("%s: font thiếu glyph \"%s\"" % [where, missing.substr(0, 8)])
	return out


static func _font(l: Label) -> Font:
	if l.label_settings != null and l.label_settings.font != null:
		return l.label_settings.font
	return l.get_theme_font("font")


static func _font_size(l: Label) -> int:
	return l.label_settings.font_size if l.label_settings != null else l.get_theme_font_size("font_size")


## Bề rộng chữ một dòng (đơn vị của nhãn).
static func _text_w(l: Label) -> float:
	var font := _font(l) if l != null else null
	if font == null:
		return 0.0
	return font.get_multiline_string_size(l.text, l.horizontal_alignment, -1, _font_size(l)).x


## Bề rộng chữ một dòng trên viewport (px).
static func _text_px(l: Label) -> float:
	if l == null:
		return 0.0
	return _text_w(l) * l.get_global_transform_with_canvas().get_scale().x


static func _tag(where: String, probs: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for p in probs:
		out.append("%s: %s" % [where, p])
	return out


## Label đang hiện dưới `root` có đúng chữ `text`.
static func _find_label(root: Node, text: String) -> Label:
	for l in root.find_children("*", "Label", true, false):
		if (l as Label).text == text and (l as Label).is_visible_in_tree():
			return l as Label
	return null


## `c` nằm (ít nhất một nửa) trong khung nhìn của danh sách cuộn.
static func _in_list_view(r, c: Control) -> bool:
	var rect: Rect2 = r._canvas_rect(c)
	var clip: Variant = r._clip_of(c)
	if clip == null:
		return (r.view_rect() as Rect2).encloses(rect)
	var shown := rect.intersection(clip as Rect2)
	return shown.get_area() >= rect.get_area() * 0.5


## Kéo danh sách của layer lên tới khi không cuộn thêm được.
static func _scroll_bottom(r, wp: Node) -> void:
	var view: Rect2 = r.view_rect()
	for i in 12:
		var list: Control = wp.get("_list")
		if list == null:
			return
		var y := list.position.y
		var x := view.position.x + view.size.x * 0.5
		await r.drag(Vector2(x, view.position.y + view.size.y * 0.7), Vector2(x, view.position.y + view.size.y * 0.3))
		await r.wait_sec(0.5)
		if absf((wp.get("_list") as Control).position.y - y) < 1.0:
			return


## Độ đầy thanh dọc nối các kim cương mốc (0..1), -1 nếu không thấy.
static func _track_fill(wp: Node) -> float:
	var list: Node = wp.get("_list")
	if list == null:
		return -1.0
	for n in list.find_children("*", "", true, false):
		if "fill_amount" in n and "fill_origin" in n and int(n.get("fill_origin")) == 1:
			return float(n.get("fill_amount"))
	return -1.0


static func _count_script(r, file: String) -> int:
	var n := 0
	for p in r.popups():
		if Scen.script_file(p) == file:
			n += 1
	return n


static func _count_howto(wp: Node) -> int:
	var n := 0
	for c in wp.get_children():
		if Scen.script_file(c) == "popup_weekly_tutorial.gd" and not c.is_queued_for_deletion():
			n += 1
	return n


## s.weekly của save trên đĩa.
static func _disk_weekly(r) -> Dictionary:
	var disk: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(r.game.save_path)))
	if disk is Dictionary and (disk as Dictionary).get("weekly") is Dictionary:
		return (disk as Dictionary).weekly
	return {}


## Khối đang bị chặn trên bàn (chơi thêm nước theo solver nếu chưa có); "" nếu không tìm được.
static func _wp_blocked_id(r) -> String:
	for i in 30:
		var lv: Control = r.level_screen()
		if lv == null:
			return ""
		for id in lv.board.block_ids():
			if str(lv.board.peek(id)) == "blocked":
				return str(id)
		if not await r.tap_next_move():
			await r.wait_frames(6)
		await r.wait_frames(8)
	return ""


## 20 lần nhấn vào tâm `c` (chỗ cố định như ngón tay) trong `sec` giây.
static func _spam(r, c: Control, n: int = 20, sec: float = 1.0) -> void:
	var p: Vector2 = r.to_viewport(c, c.size * 0.5)
	r.step("bấm dồn %s %d lần trong %.1f giây" % [c.name, n, sec])
	for i in n:
		await r.click_at(p)
		await r.wait_sec(sec / float(n))


## Lỗi script và engine tới giờ (sau khi lấy hết log).
static func _errs(r) -> int:
	r._count_errors()
	return int(r._script_errors) + int(r._engine_errors)


static func _ev(r, name: String) -> Array:
	return r.plat.an.named(name)


## Đúng một sự kiện trong `evs` và params có mọi khoá của `want` với cùng giá trị.
static func _ev_one(evs: Array, want: Dictionary) -> bool:
	if evs.size() != 1:
		return false
	var p: Dictionary = (evs[0] as Dictionary).get("params", {})
	for k in want:
		if not p.has(k):
			return false
		if want[k] is String:
			if str(p[k]) != str(want[k]):
				return false
		elif int(p[k]) != int(want[k]):
			return false
	return true


static func _ev_txt(evs: Array) -> String:
	var parts := PackedStringArray()
	for e in evs:
		var p: Dictionary = ((e as Dictionary).get("params", {}) as Dictionary).duplicate()
		p.erase("build")
		parts.append(JSON.stringify(p))
	return "[%s]" % ", ".join(parts)


## Mảng số (JSON trả float) thành mảng int đã sắp.
static func _ints(v: Variant) -> Array:
	var out: Array = []
	if v is Array:
		for x in v:
			out.append(int(x))
	out.sort()
	return out


static func _wl(r, key: String) -> String:
	return str(_ints(r.game.s.weekly.get(key, [])))


static func _txt(root: Variant, name: String) -> String:
	if root == null or not is_instance_valid(root):
		return ""
	var l := Scen.find_visible(root as Node, name) as Label
	return l.text if l != null else ""


static func _yes(v: Variant) -> String:
	return "có" if bool(v) else "không"


static func _shown(c: Variant) -> String:
	return "có" if c != null else "không có"


## Tâm ngang của `c` trên viewport.
static func _cx(r, c: Control) -> float:
	return (r._canvas_rect(c) as Rect2).get_center().x


## Số px viewport của một đơn vị canvas.
static func _px(r) -> float:
	return maxf((r.view_rect() as Rect2).size.x / maxf(float(r.main.size.x), 1.0), 0.0001)


## Khoảng cách nhỏ nhất (đơn vị canvas) từ `c` tới mép màn; âm khi ra ngoài.
static func _gap(r, c: Control) -> float:
	if c == null:
		return -1.0
	var v: Rect2 = r.view_rect()
	var b: Rect2 = r._canvas_rect(c)
	var px := minf(minf(b.position.x - v.position.x, b.position.y - v.position.y), minf(v.end.x - b.end.x,
		v.end.y - b.end.y))
	return px / _px(r)


## [p95, max] (ms) của thời gian khung đo được.
static func _p95_max(times: PackedFloat32Array) -> Array:
	if times.is_empty():
		return [0.0, 0.0]
	var t := times.duplicate()
	t.sort()
	return [t[mini(t.size() - 1, int(t.size() * 0.95))], t[-1]]


# ================================================================ Chain Offer

## CO. Chain Offer (design.md mục 7 "Chain Offer"): save ở L(level_unlock − 2) = L128. [NEG] Thắng L128: level đang tới
## (129) dưới `CHAIN.level_unlock`, không bật chuỗi. [HP] Thắng L129: bật chuỗi đầu (`sequences[0]`), sống
## `days_to_existence` ngày. Về Home: layer tự mở một lần. [NEG] Chạm gói đang khoá: chỉ hiện dòng "nhận gói phía trước",
## không nhận gì. Nhận lần lượt mọi bước (free; ad qua ads giả; pay qua store giả, thưởng lấy từ chính gói, không cộng
## hai lần), mỗi bước một popup Reward, gói kế chỉ mở khi popup đóng. [NEG] Bước ad đóng video sớm, bước pay huỷ mua:
## không nhận, bước giữ nguyên. [EDGE] Cửa sổ `CHAIN.window` ô đứng ở đầu chuỗi, gói vừa nhận tích tại chỗ, chỉ trượt
## sau popup khi bước kế nằm ngoài cửa sổ; làm hết bước chuỗi vẫn sống. [EDGE] Hết hạn lúc layer đang mở: layer tự đóng,
## nút ở Home ẩn, cooldown `days_to_reset` ngày tính từ lúc hết hạn. [NEG] Thắng trong cooldown: không bật chuỗi.
## [HP] Thắng sau cooldown: bật chuỗi kế (xoay vòng), layer tự mở lại khi về Home.
static func scen_co(r) -> bool:
	if not await r.open_game("CO", func(g: Node) -> void: _co_save(g)):
		return false
	var lu := int(Config.CHAIN.level_unlock)
	var seqs: Array = Config.CHAIN.sequences
	if not await _ensure_playing(r, lu - 2):
		return false
	if not await _win_recorded(r, lu - 2):
		return false
	if bool(r.game.s.chain.get("active", false)) or not (r.game.chain_view() as Dictionary).is_empty():
		return r.fail("[NEG] thắng L%d (level đang tới %d < %d) mà đã bật Chain Offer" % [lu - 2, int(r.game.s.level), lu])
	r.step("[NEG] thắng L%d: level đang tới %d < %d, chưa bật Chain Offer" % [lu - 2, int(r.game.s.level), lu])
	if not await Scen.after_win(r, lu - 2):
		return false
	if not await _ensure_playing(r, lu - 1):
		return false
	if not await _co_win_starts(r, lu - 1, str(seqs[0].id)):
		return false
	if not await Scen.after_win(r, lu - 1):
		return false
	var co := await _co_autoshow(r, "chain_open")
	if co == null:
		return false
	if not await _co_locked_tap(r, co, 1):
		return false
	var id := str(r.game.s.chain.id)
	var steps: Array = _co_steps(id)
	var refused := {}
	for i in steps.size():
		var st: Dictionary = steps[i]
		var type := str(st.get("type", "free"))
		if not await _co_ready(r, co, i, steps.size()):
			return false
		if type in ["ad", "pay"] and not refused.has(type):
			refused[type] = true
			if not await _co_refuse(r, co, i, type):
				return false
		if not await _co_claim(r, co, i, st, steps.size()):
			return false
	if not await Scen.wait_for(r, func() -> bool: return Scen.find_visible(co, "DoneLabel") != null, 6000, "*"):
		return r.fail("nhận hết %d bước mà layer không báo xong" % steps.size())
	var c: Dictionary = r.game.s.chain
	if not bool(c.active) or int(c.step) != steps.size():
		return r.fail("[EDGE] nhận hết bước mà chuỗi %s (bước %d)" % ["còn" if bool(c.active) else "tắt", int(c.step)])
	r.step("[EDGE] nhận hết %d bước: chuỗi vẫn sống tới hết hạn" % steps.size())
	await r.shot("chain_done")
	if not await _co_expire(r):
		return false
	# Trong cooldown: thắng không bật chuỗi.
	var cool := int(r.game.s.chain.cooldown_until)
	var expired_at := int(r.game.s.chain.get("expires", 0))
	@warning_ignore("integer_division")
	r.game.test_now = expired_at + (cool - expired_at) / 2
	if not await _ensure_playing(r, lu):
		return false
	if not await _win_recorded(r, lu):
		return false
	if bool(r.game.s.chain.get("active", false)):
		return r.fail("[NEG] thắng L%d trong cooldown (còn %d giây) mà bật Chain Offer" % [lu, cool - int(r.game.now())])
	r.step("[NEG] thắng L%d trong cooldown: không bật chuỗi" % lu)
	if not await Scen.after_win(r, lu):
		return false
	# Hết cooldown: chuỗi kế theo vòng.
	r.game.test_now = cool + 60
	if not await _ensure_playing(r, lu + 1):
		return false
	if not await _co_win_starts(r, lu + 1, str(seqs[1 % seqs.size()].id)):
		return false
	if not await Scen.after_win(r, lu + 1):
		return false
	co = await _co_autoshow(r, "chain_next")
	if co == null:
		return false
	if not await _close_popup(r, co, "Chain Offer"):
		return false
	return await Scen.verify_saved(r)


## Save của CO: người chơi lâu ở L(level_unlock − 2), đã xem giới thiệu cơ chế trước đó, đã xem hướng dẫn và lời mời
## của Màn đặc biệt và Road Trip (mở trước L128) để Home chỉ tự mở Chain Offer.
static func _co_save(g: Node) -> void:
	Saves.veteran(g)
	Saves._at_level(g, int(Config.CHAIN.level_unlock) - 2, false)
	g.s.special["guide"] = true
	g.s.special["invited"] = true
	g.s.road_trip["guide"] = true


static func _co_steps(id: String) -> Array:
	for q in Config.CHAIN.sequences:
		if str(q.get("id", "")) == id:
			return q.get("steps", [])
	return []


## Thắng level `lvl` đang chơi; level đang tới >= level_unlock và hết cooldown nên bật chuỗi `want_id` ở bước 0, hạn
## `days_to_existence` ngày từ giờ thắng.
static func _co_win_starts(r, lvl: int, want_id: String) -> bool:
	var t0: int = r.game.now()
	if not await _win_recorded(r, lvl):
		return false
	if not await Scen.wait_for(r, func() -> bool: return bool(r.game.s.chain.get("active", false)), 6000, "*"):
		return r.fail("[HP] thắng L%d (level đang tới %d >= %d) mà không bật Chain Offer" % [lvl, int(r.game.s.level),
			int(Config.CHAIN.level_unlock)])
	var c: Dictionary = r.game.s.chain
	var want_exp := t0 + int(Config.CHAIN.days_to_existence) * DAY
	if str(c.id) != want_id or int(c.step) != 0 or int(c.expires) != want_exp or bool(c.shown):
		return r.fail("bật chuỗi %s bước %d hạn %d (đã mở %s), mong đợi %s bước 0 hạn %d" % [str(c.id), int(c.step),
			int(c.expires), bool(c.shown), want_id, want_exp])
	r.step("[HP] thắng L%d: bật Chain Offer %s, hạn %d giờ" % [lvl, want_id,
		int(Config.CHAIN.days_to_existence) * 24])
	return true


## Về Home sau khi chuỗi bật: layer tự mở đúng một lần (`s.chain.shown`).
static func _co_autoshow(r, shot_name: String) -> Node:
	if not await _to_home(r, "chain_offer.gd"):
		return null
	var co := await _wait_popup(r, "chain_offer.gd", 10000, "chain_offer.gd")
	if co == null:
		r.fail("[HP] về Home sau khi bật chuỗi mà layer Chain Offer không tự mở")
		return null
	if not bool(r.game.s.chain.get("shown", false)):
		r.fail("layer Chain Offer tự mở mà chưa ghi đã mở")
		return null
	r.step("[HP] về Home: layer Chain Offer tự mở")
	await r.wait_sec(0.8)
	await r.shot(shot_name)
	return co


## [NEG] Chạm gói đang khoá (bước `i`, sau bước hiện tại): dòng "nhận gói phía trước", không nhận gì.
static func _co_locked_tap(r, co: Node, i: int) -> bool:
	var slot: Node = co.find_child("Node%d" % i, true, false)
	var lock: Control = null
	if slot != null:
		for name in ["Button_Free_Lock", "Button_Purchase_Lock"]:
			lock = Scen.find_visible(slot, name) as Control
			if lock != null:
				break
	if lock == null:
		return r.fail("Chain Offer: gói bước %d không có nút khoá" % i)
	var before := _bal(r)
	var step := int(r.game.s.chain.step)
	await r.tap(lock, "Chain Offer: gói bước %d đang khoá" % i)
	var want := TranslationServer.translate("chain_unlock_first")
	if not await Scen.wait_for(r, func() -> bool:
			var t := Scen.find_visible(co, "ToastLabel") as Label
			return t != null and t.text == want, 3000, "*"):
		return r.fail("[NEG] chạm gói khoá mà không hiện dòng \"%s\"" % want)
	if _bal(r) != before or int(r.game.s.chain.step) != step or r.popup_script("popup_reward.gd") != null:
		return r.fail("[NEG] chạm gói khoá mà nhận được thưởng hoặc sang bước")
	r.step("[NEG] chạm gói khoá: chỉ nhắc nhận gói phía trước")
	await r.shot("chain_locked_tap")
	return true


## Đợi gói bước `i` mở để nhận: layer không bận, nút nhận nằm ở ô bước `i`, cửa sổ đứng ở đầu chuỗi và chỉ trượt khi
## bước hiện tại phải sang ô cuối (first = clamp(i − (window − 1), 0, count − window)).
static func _co_ready(r, co: Node, i: int, count: int) -> bool:
	var ok: bool = await Scen.wait_for(r, func() -> bool:
		return is_instance_valid(co) and not bool(co.get("_busy")) and is_instance_valid(co.get("claim_button")), 8000, "*")
	if not ok:
		return r.fail("Chain Offer: gói bước %d không mở để nhận" % i)
	var slot: Node = co.find_child("Node%d" % i, true, false)
	var b: Node = co.get("claim_button")
	if slot == null or not slot.is_ancestor_of(b):
		return r.fail("Chain Offer: nút nhận không nằm ở ô bước %d" % i)
	var size := mini(int(Config.CHAIN.window), count)
	var want_first := clampi(i - (size - 1), 0, maxi(0, count - size))
	if int(co.get("_first")) != want_first:
		return r.fail("[EDGE] bước %d: cửa sổ bắt đầu ở bước %d, mong đợi %d" % [i, int(co.get("_first")), want_first])
	return true


## Thưởng của một bước: free / ad lấy từ bước, pay lấy từ gói Config.SKUS của bước ({coins, items}).
static func _co_step_reward(st: Dictionary) -> Dictionary:
	if str(st.get("type", "")) == "pay":
		var info: Dictionary = Config.SKUS.get(str(st.get("sku", "")), {})
		return {"coins": int(info.get("gold", 0)), "items": info.get("inv", {})}
	return {"coins": int(st.get("coins", 0)), "items": st.get("items", {})}


## [NEG] Bước ad: đóng video sớm (ads giả "closed"); bước pay: huỷ trên store giả. Không nhận gì, bước giữ nguyên, không
## có popup Reward, gói vẫn nhận được.
static func _co_refuse(r, co: Node, i: int, type: String) -> bool:
	var before := _bal(r)
	var calls: Array = r.plat.ads.calls if type == "ad" else r.plat.iap.calls
	var n := calls.size()
	var how := "đóng video sớm" if type == "ad" else "huỷ mua"
	if type == "ad":
		r.plat.ads.simulate("closed")
	else:
		r.plat.iap.simulate("cancel")
	if not await r.tap(co.get("claim_button"), "Chain Offer bước %d (%s, %s)" % [i, type, how]):
		return r.fail("nút nhận bước %d bị che" % i)
	if not await Scen.wait_for(r, func() -> bool: return calls.size() > n, 8000, "*"):
		return r.fail("bước %d (%s) không gọi %s" % [i, type, "quảng cáo" if type == "ad" else "store"])
	if not await Scen.wait_for(r, func() -> bool:
			return not bool(co.get("_busy")) and is_instance_valid(co.get("claim_button")), 6000, "*"):
		return r.fail("[NEG] bước %d %s mà gói không mở lại" % [i, how])
	if _bal(r) != before or int(r.game.s.chain.step) != i or r.popup_script("popup_reward.gd") != null:
		return r.fail("[NEG] bước %d %s mà vẫn nhận thưởng hoặc sang bước (%s → %s)" % [i, how, JSON.stringify(before),
			JSON.stringify(_bal(r))])
	r.step("[NEG] Chain Offer bước %d (%s) %s: không nhận, bước giữ nguyên" % [i, type, how])
	return true


## Nhận bước `i`: số dư cộng đúng thưởng của bước (bước pay: đúng một lần gói), popup Reward hiện; gói vừa nhận tích
## tại ô đã chạm, cửa sổ chưa trượt; Claim đóng popup.
static func _co_claim(r, co: Node, i: int, st: Dictionary, count: int) -> bool:
	var type := str(st.get("type", "free"))
	var reward := _co_step_reward(st)
	var before := _bal(r)
	var first := int(co.get("_first"))
	if not await r.tap(co.get("claim_button"), "Chain Offer: nhận bước %d (%s)" % [i, type]):
		return r.fail("nút nhận bước %d bị che" % i)
	if not await Scen.wait_for(r, func() -> bool: return int(r.game.s.chain.step) == i + 1, 10000, "*"):
		return r.fail("chạm nhận bước %d (%s) mà chưa sang bước" % [i, type])
	var problem := _gain_problem(before, _bal(r), reward, int(r.game.now()))
	if problem != "":
		return r.fail("Chain Offer bước %d (%s): %s" % [i, type, problem])
	var pop := await _wait_popup(r, "popup_reward.gd", 6000, "*")
	if pop == null:
		return r.fail("nhận bước %d mà không có popup Reward" % i)
	var states: Array = co.get("node_states")
	if int(co.get("_first")) != first or i - first >= states.size() or str(states[i - first]) != "claimed":
		return r.fail("[EDGE] nhận bước %d: cửa sổ %d → %d, ô đã chạm %s" % [i, first, int(co.get("_first")),
			str(states[i - first]) if i - first < states.size() else "(ngoài cửa sổ)"])
	if i + 1 < count and i + 1 - first < states.size() and str(states[i + 1 - first]) != "locked":
		return r.fail("[EDGE] popup Reward bước %d còn mở mà gói kế đã mở" % i)
	r.step("[HP] Chain Offer bước %d (%s): %s" % [i, type, JSON.stringify(reward)])
	await r.wait_sec(0.5)
	if i == 0 or type == "pay":
		await r.shot("chain_reward_%d" % i)
	if not await Scen.tap_named(r, "ClaimBtn", pop):
		return false
	if not await Scen.wait_for(r, func() -> bool: return r.popup_script("popup_reward.gd") == null, 4000, "*"):
		return r.fail("Claim không đóng popup Reward")
	return true


## [EDGE] Hết hạn khi layer đang mở (giờ nhảy qua `expires`): layer tự đóng, nút Chain Offer ở Home ẩn, cooldown tính
## từ lúc hết hạn.
static func _co_expire(r) -> bool:
	var expires := int(r.game.s.chain.expires)
	r.game.test_now = expires + 1
	r.step("giờ nhảy qua hạn chuỗi (%d)" % expires)
	if not await Scen.wait_for(r, func() -> bool: return r.popup_script("chain_offer.gd") == null, 5000, "*"):
		return r.fail("[EDGE] chuỗi hết hạn mà layer Chain Offer không tự đóng")
	var c: Dictionary = r.game.s.chain
	var want := expires + int(Config.CHAIN.days_to_reset) * DAY
	if bool(c.active) or int(c.cooldown_until) != want:
		return r.fail("[EDGE] hết hạn: chuỗi %s, cooldown tới %d, mong đợi %d (hạn + %d ngày)" % [
			"còn" if bool(c.active) else "tắt", int(c.cooldown_until), want, int(Config.CHAIN.days_to_reset)])
	if not await Scen.wait_for(r, func() -> bool:
			return Scen.find_visible(r.main.current_screen, "ChainOfferButton") == null, 4000):
		return r.fail("[EDGE] chuỗi hết hạn mà Home còn nút Chain Offer")
	r.step("[EDGE] hết hạn: layer tự đóng, nút ở Home ẩn, cooldown %d ngày từ lúc hết hạn" %
		int(Config.CHAIN.days_to_reset))
	await r.shot("chain_expired")
	return true


# ================================================================ Special Pack

## SP. Special Pack (design.md mục 7 "Special Pack", Config.PACKS.special_pack): save ở L(level_appear − 1) = L15, offer
## Starter đang mở, chưa mua gì. [NEG] Home không có Special Pack (chưa mua gói `required`). Mua Starter qua icon offer ở
## Home (store giả, số dư theo Config.SKUS). [NEG] Vẫn không có: level đang tới dưới `level_appear`. Thắng L15 → Home:
## [HP] icon Special Pack hiện → popup offer chung; [EDGE] đang weekend sale nên bán SKU `<sku>_sale` với giá của nó.
## [NEG] Huỷ trên store: không nhận, popup còn mở. Mua: gold và booster đúng Config.SKUS, popup đóng; [EDGE] icon ẩn
## (`purchase_limit`). [EDGE] Hết sale: vẫn ẩn, bản thường cũng không bán (`buy_sku` trả `owned`, không gọi store).
static func scen_sp(r) -> bool:
	var cond: Dictionary = Config.PACKS.special_pack
	var appear := int(cond.level_appear)
	var base_sku := str(cond.sku)
	if not await r.open_game("SP", func(g: Node) -> void: _sp_save(g, appear - 1)):
		return false
	if not await _ensure_playing(r, appear - 1):
		return false
	if not await _to_home(r, ""):
		return false
	await Scen.settle_all(r)
	if Scen.find_visible(r.main.current_screen, "SpecialPackButton") != null or str(r.game.special_pack_id()) != "":
		return r.fail("[NEG] chưa mua %s mà Home có Special Pack" % str(cond.required))
	r.step("[NEG] chưa mua %s: Home không có Special Pack" % str(cond.required))
	await r.shot("home_no_special")
	var chip := Scen.find_visible(r.main.current_screen, "OfferChip") as Control
	if chip == null:
		return r.fail("Home không có icon offer Starter đang mở")
	var pop := await _tap_open(r, chip, "icon offer Starter", "popup_offer.gd")
	if pop == null:
		return false
	if str(pop.get("offer_id")) != "starter_pack":
		return r.fail("icon offer mở popup %s, mong đợi starter_pack" % str(pop.get("offer_id")))
	await r.wait_sec(0.6)
	await r.shot("starter_offer")
	if not await _offer_buy(r, pop, str(pop.get("sku"))):
		return false
	await Scen.settle_all(r)
	await r.wait_sec(1.2)
	if Scen.find_visible(r.main.current_screen, "SpecialPackButton") != null or str(r.game.special_pack_id()) != "":
		return r.fail("[NEG] level đang tới %d < %d mà Home có Special Pack" % [int(r.game.s.level), appear])
	r.step("[NEG] đã mua Starter, level đang tới %d < %d: chưa có Special Pack" % [int(r.game.s.level), appear])
	if not await _ensure_playing(r, appear - 1):
		return false
	if not await Scen.win_level(r):
		return false
	if not await Scen.after_win(r, appear - 1):
		return false
	if not await _to_home(r, ""):
		return false
	await Scen.settle_all(r)
	if not await Scen.wait_for(r, func() -> bool:
			return Scen.find_visible(r.main.current_screen, "SpecialPackButton") != null, 4000):
		return r.fail("[HP] L%d, đã mua Starter mà Home không có Special Pack" % appear)
	r.step("[HP] L%d, đã mua Starter: Home có Special Pack" % appear)
	await r.shot("home_special")
	pop = await _tap_open(r, Scen.find_visible(r.main.current_screen, "SpecialPackButton") as Control, "Special Pack",
		"popup_offer.gd")
	if pop == null:
		return false
	if str(pop.get("offer_id")) != "special_pack":
		return r.fail("icon Special Pack mở popup %s" % str(pop.get("offer_id")))
	var sale: bool = r.game.is_sale_active()
	var sale_sku := base_sku + "_sale"
	var want_sku := sale_sku if sale and Config.SKUS.has(sale_sku) else base_sku
	var sku := str(pop.get("sku"))
	if sku != want_sku:
		return r.fail("[EDGE] weekend sale %s mà popup bán %s, mong đợi %s" % [sale, sku, want_sku])
	var out := (pop.get("buy_button") as Node).find_child("Out", true, false) as Label
	if out == null or out.text != str(r.plat.price(sku)):
		return r.fail("nút mua Special Pack ghi \"%s\", mong đợi %s" % [out.text if out != null else "",
			str(r.plat.price(sku))])
	r.step("[EDGE] weekend sale %s: popup bán %s giá %s" % [sale, sku, out.text])
	await r.wait_sec(0.6)
	await r.shot("special_offer")
	if not await _offer_cancel(r, pop):
		return false
	if not await _offer_buy(r, pop, sku):
		return false
	await Scen.settle_all(r)
	if not await Scen.wait_for(r, func() -> bool:
			return Scen.find_visible(r.main.current_screen, "SpecialPackButton") == null, 4000):
		return r.fail("[EDGE] mua %s (giới hạn %d) mà Home còn Special Pack" % [sku, int(cond.purchase_limit)])
	r.step("[EDGE] đã mua %s: Special Pack ẩn (giới hạn %d lần)" % [sku, int(cond.purchase_limit)])
	await r.shot("home_after_special")
	# Hết weekend sale: bản thường cũng tính là đã mua.
	var t: int = r.game.now()
	for k in 7:
		if not r.game.is_sale_active():
			break
		t += DAY
		r.game.test_now = t
	if r.game.is_sale_active():
		return r.fail("không tìm được ngày hết weekend sale")
	await r.wait_sec(1.5)
	if Scen.find_visible(r.main.current_screen, "SpecialPackButton") != null or str(r.game.special_pack_id()) != "":
		return r.fail("[EDGE] hết sale mà Special Pack hiện lại")
	if str(r.game.offer_sku("special_pack")) != base_sku or not r.game.owns_once(base_sku):
		return r.fail("[EDGE] hết sale: offer bán %s, đã sở hữu %s" % [str(r.game.offer_sku("special_pack")),
			r.game.owns_once(base_sku)])
	var n: int = r.plat.iap.calls.size()
	var before := Scen._balance(r)
	var res: Dictionary = await r.game.buy_sku(base_sku)
	if str(res.get("status", "")) != "owned" or r.plat.iap.calls.size() != n or Scen._balance(r) != before:
		return r.fail("[EDGE] mua %s sau khi đã mua %s: %s, gọi store %d lần" % [base_sku, sku,
			str(res.get("status", "")), r.plat.iap.calls.size() - n])
	r.step("[EDGE] hết sale: %s vẫn ẩn, mua bản thường trả owned, không gọi store" % base_sku)
	return await Scen.verify_saved(r)


## Save của SP: người chơi lâu ở L`level`, offer Starter vừa hiện và còn hạn `OFFERS.starter_pack.hours` giờ (icon
## offer ở Home), chưa mua gói nào.
static func _sp_save(g: Node, level: int) -> void:
	Saves.veteran(g)
	Saves._at_level(g, level, false)
	var now: int = g.now()
	var hours := int(Config.OFFERS.starter_pack.hours)
	g.s.offers["last_run"] = int(g.s.runs)
	g.s.offers["items"]["starter_pack"] = {"shown": 1, "at": now, "until": now + hours * 3600}


## [NEG] Huỷ trên store giả ở popup offer: không nhận gì, không ghi đơn, popup còn mở và bấm mua lại được.
static func _offer_cancel(r, pop: Node) -> bool:
	var before := Scen._balance(r)
	var n: int = r.plat.iap.calls.size()
	r.plat.iap.simulate("cancel")
	if not await r.tap(pop.get("buy_button"), "mua %s (huỷ trên store)" % str(pop.get("sku"))):
		return r.fail("nút mua %s bị che" % str(pop.get("sku")))
	if not await Scen.wait_for(r, func() -> bool: return r.plat.iap.calls.size() > n, 8000, "popup_offer.gd"):
		return r.fail("bấm mua %s không gọi store" % str(pop.get("sku")))
	if not await Scen.wait_for(r, func() -> bool: return is_instance_valid(pop) and not bool(pop.get("_busy")), 4000,
			"popup_offer.gd"):
		return r.fail("[NEG] huỷ mua mà popup offer không thôi chờ")
	if Scen._balance(r) != before or r.popup_script("popup_offer.gd") != pop:
		return r.fail("[NEG] huỷ mua %s mà số dư đổi hoặc popup đóng" % str(pop.get("sku")))
	r.step("[NEG] huỷ mua %s trên store: không nhận gì, popup còn mở" % str(pop.get("sku")))
	return true


## Mua `sku` ở popup offer qua store giả: một đơn đúng SKU, số dư đúng Config.SKUS, popup đóng.
static func _offer_buy(r, pop: Node, sku: String) -> bool:
	var before := Scen._balance(r)
	var n := (r.game.s.buys as Array).size()
	if not await r.tap(pop.get("buy_button"), "mua %s" % sku):
		return r.fail("nút mua %s bị che" % sku)
	if not await Scen.wait_for(r, func() -> bool: return (r.game.s.buys as Array).size() > n, 10000, "popup_offer.gd"):
		return r.fail("mua %s mà không có đơn" % sku)
	var last: Dictionary = (r.game.s.buys as Array).back()
	if str(last.get("sku", "")) != sku:
		return r.fail("mua %s mà đơn ghi %s" % [sku, str(last.get("sku", ""))])
	var problem := Scen._check_purchase(before, Scen._balance(r), Config.SKUS.get(sku, {}))
	if problem != "":
		return r.fail("mua %s: %s" % [sku, problem])
	if not await Scen.wait_for(r, func() -> bool: return r.popup_script("popup_offer.gd") == null, 6000, "*"):
		return r.fail("mua %s xong mà popup offer không đóng" % sku)
	r.step("[HP] mua %s: gold %d → %d" % [sku, int(before.coins), int(r.game.s.coins)])
	return true


# ================================================================ dùng chung

## Level `lvl` đang chơi; đang ở Home thì bấm Chơi.
static func _ensure_playing(r, lvl: int) -> bool:
	if r.screen_name() == "home":
		await Scen.settle_all(r)
		if not await Scen.tap_named(r, "PlayButton", r.main.current_screen):
			return false
	if not await Scen.wait_for(r, func() -> bool: return Scen._playing(r) == lvl, 20000):
		return r.fail("không vào được L%d (đang %s, level %d)" % [lvl, r.screen_name(), Scen._playing(r)])
	return true


## Như Scen.go_home_from_level nhưng giữ popup `keep` (popup tự mở khi về Home: Upsell, Chain Offer) thay vì đóng nó
## như popup lạc.
static func _to_home(r, keep: String) -> bool:
	if r.screen_name() == "home":
		return true
	if not await Scen.wait_for(r, func() -> bool: return Scen._playing(r) > 0, 20000, keep):
		return r.fail("không ở màn level để về Home")
	var lv: Control = r.level_screen()
	await r.tap(lv.settings_button, "Cài đặt trong màn")
	if not await Scen.wait_for(r, func() -> bool: return r.popup_script("popup_ingame_settings.gd") != null, 6000,
			"popup_ingame_settings.gd"):
		return r.fail("Cài đặt trong màn không mở")
	await r.wait_sec(0.4)
	if not await Scen.tap_named(r, "HomeButton", r.popup_script("popup_ingame_settings.gd")):
		return false
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		if r.screen_name() == "home" and r.main.curtain == null:
			return true
		var confirm := Scen.find_visible(r.main, "ConfirmButton") as Control
		if confirm != null:
			await r.wait_sec(0.3)
			await r.tap(confirm, "xác nhận rời màn")
		else:
			await Scen.settle(r, keep)
		await r.wait_frames(2)
	return r.fail("Cài đặt → Home không về Home")


## Thắng level `lvl` đang chơi và đợi Game ghi lần thắng (level đang tới sang `lvl` + 1, Game.on_level_won chạy sau
## hiệu ứng bàn trống, trước thẻ thắng).
static func _win_recorded(r, lvl: int) -> bool:
	if not await Scen.win_level(r):
		return false
	if not await Scen.wait_for(r, func() -> bool: return int(r.game.s.level) > lvl, 15000, "ContinueButton"):
		return r.fail("thắng L%d mà Game chưa ghi lần thắng (level đang tới %d)" % [lvl, int(r.game.s.level)])
	return true


static func _wait_popup(r, file: String, ms: int, keep: String) -> Node:
	if not await Scen.wait_for(r, func() -> bool: return r.popup_script(file) != null, ms, keep):
		return null
	return r.popup_script(file)


## Bấm `btn` rồi đợi popup có script `file` (giữ nó, đóng popup lạc khác).
static func _tap_open(r, btn: Control, label: String, file: String) -> Node:
	if btn == null:
		r.fail("không có nút %s" % label)
		return null
	if not await r.tap(btn, label):
		r.fail("nút %s bị che" % label)
		return null
	var pop := await _wait_popup(r, file, 8000, file)
	if pop == null:
		r.fail("bấm %s không mở %s" % [label, file])
	return pop


static func _open_from_home(r, name: String, file: String) -> Node:
	var btn := Scen.find_visible(r.main.current_screen, name) as Control
	return await _tap_open(r, btn, name, file)


## Đóng popup bằng nút đóng của nó (X), đợi nó đi.
static func _close_popup(r, pop: Node, label: String) -> bool:
	var close := Scen.find_close(pop)
	if close == null:
		return r.fail("%s không có nút đóng" % label)
	await r.tap(close, "đóng %s" % label)
	if not await Scen.wait_for(r, func() -> bool: return r.popups().find(pop) < 0, 4000, "*"):
		return r.fail("không đóng được %s" % label)
	await Scen.settle_all(r)
	return true


## Số dư người chơi thấy: gold, từng booster, hạn mạng vô hạn, số mạng, mạng tối đa tạm của VIP, số đơn đã mua.
static func _bal(r) -> Dictionary:
	var s: Dictionary = r.game.s
	var lives: Dictionary = s.lives
	return {"coins": int(s.coins), "inv": (s.inv as Dictionary).duplicate(), "inf_until": int(lives.get("inf_until", 0)),
		"lives": int(lives.get("count", 0)), "bonus": int(lives.get("bonus", 0)), "buys": (s.buys as Array).size()}


## "" khi từ `before` tới `after` gold, booster, hạn mạng vô hạn cộng đúng `reward` ({coins, items, inf_min}; mạng vô hạn
## cộng dồn từ max(hạn cũ, `now`)); không thì mô tả chỗ lệch.
static func _gain_problem(before: Dictionary, after: Dictionary, reward: Dictionary, now: int) -> String:
	var coins := int(after.coins) - int(before.coins)
	if coins != int(reward.get("coins", 0)):
		return "gold +%d, mong đợi +%d" % [coins, int(reward.get("coins", 0))]
	var items: Dictionary = reward.get("items", {})
	for k in BOOSTERS:
		var got := int((after.inv as Dictionary).get(k, 0)) - int((before.inv as Dictionary).get(k, 0))
		if got != int(items.get(k, 0)):
			return "%s +%d, mong đợi +%d" % [k, got, int(items.get(k, 0))]
	var inf_min := int(reward.get("inf_min", 0))
	var want_inf := int(before.inf_until)
	if inf_min > 0:
		want_inf = maxi(int(before.inf_until), now) + inf_min * 60
	if int(after.inf_until) != want_inf:
		return "hạn mạng vô hạn %d, mong đợi %d (+%d phút)" % [int(after.inf_until), want_inf, inf_min]
	return ""


static func _add_reward(a: Dictionary, b: Dictionary) -> Dictionary:
	var items: Dictionary = (a.get("items", {}) as Dictionary).duplicate()
	var bi: Dictionary = b.get("items", {})
	for k in bi:
		items[k] = int(items.get(k, 0)) + int(bi[k])
	return {"coins": int(a.get("coins", 0)) + int(b.get("coins", 0)), "items": items,
		"inf_min": int(a.get("inf_min", 0)) + int(b.get("inf_min", 0))}


## Mảng số đọc từ save (JSON trả float) có `i`.
static func _has_int(arr: Variant, i: int) -> bool:
	if not (arr is Array):
		return false
	for v in arr:
		if int(v) == i:
			return true
	return false
