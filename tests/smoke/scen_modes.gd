extends RefCounted
## Kịch bản smoke cho chế độ chơi ngoài level chính: Road Trip, Leaderboard, Màn đặc biệt (design.md mục 7).
## Gọi qua scenarios.gd SCEN_FILES. Mỗi hàm nhận runner `r` (tests/smoke/smoke.gd) như kịch bản trong scenarios.gd.
## Chơi bằng chạm thật (khối do solver chọn, bấm nút bằng push_input); số mong đợi đọc từ Config (UNLOCK, ROAD_TRIP,
## ROAD_TRIP_REWARDS, ROAD_TRIP_COSMETICS, LEADERBOARD, SPECIAL) qua module meta, không ghi cứng. Giờ máy giả đi qua
## Game.test_now như code game đọc (Game.now()). Không gọi OS, không rời app: chạy được trên máy Android thật.

const Scen := preload("res://tests/smoke/scenarios.gd")
const Saves := preload("res://tests/smoke/smoke_saves.gd")
const Config := preload("res://src/config.gd")
const Solver := preload("res://src/core/solver.gd")
const RoadTrip := preload("res://src/meta/road_trip.gd")
const Leaderboard := preload("res://src/meta/leaderboard.gd")
const SpecialBomb := preload("res://src/meta/special_bomb.gd")
const SpecialBoard := preload("res://src/core/special_board.gd")
const Cosmetics := preload("res://src/meta/cosmetics.gd")
const BOOSTERS := ["hint", "move", "smash"]
## LB: giây còn lại trên đồng hồ popup Leaderboard lúc mở, trước khi giờ máy qua mốc hết tuần.
const LB_COUNTDOWN_SEC := 4
## Meta trên runner: lỗi game đã ghi (_bug), báo ở cuối kịch bản (_finish).
const BUGS := "scen_modes_bugs"
## SB: cửa sổ mất focus (app ở nền, bom dừng) lâu hơn chừng này ms thì dừng kịch bản với lý do môi trường.
const SB_UNFOCUSED_MS := 60000


static func run(r, scen: String) -> bool:
	r.set_meta(BUGS, [])
	var ok := false
	match scen:
		"RT":
			ok = await scen_rt(r)
		"LB":
			ok = await scen_lb(r)
		"SB":
			ok = await scen_sb(r)
		_:
			return r.fail("không có kịch bản %s" % scen)
	return _finish(r, ok)


## Lỗi game (trái design.md, hoặc lỗi engine do code game) thấy giữa kịch bản mà vẫn đi tiếp được: ghi SMOKE WARN
## ngay, kịch bản chạy hết rồi _finish báo fail. (r.fail ngay thì Scen.wait_for dừng mọi bước sau.)
static func _bug(r, text: String) -> void:
	print("SMOKE WARN lỗi game: %s" % text)
	var list: Array = r.get_meta(BUGS, [])
	if not list.has(text):
		list.append(text)
		r.set_meta(BUGS, list)


static func _finish(r, ok: bool) -> bool:
	var list: Array = r.get_meta(BUGS, [])
	if not ok or list.is_empty():
		return ok
	return r.fail("lỗi game (%d): %s" % [list.size(), " | ".join(PackedStringArray(list))])


# ================================================================ Road Trip

## RT. Road Trip (design.md mục 7 "Road Trip"):
## - [NEG] Ở L(UNLOCK.road_trip − 1): tab Road Trip của thanh dưới khoá (ghi "Level N"), chạm không mở gì.
## - [HP] Thắng level đó vào thẳng level kế (Road Trip không kéo về Home); lần đầu về Home có lớp hướng dẫn chỉ vào tab,
##   chạm tab thì tắt hướng dẫn và mở bản đồ ở level 1 (chip 0/khoảng tới hộp đầu). Nút Level 1 → chơi bằng chạm thật
##   → popup thắng (thanh chạy tới 1/khoảng, không x2) → Tiếp tục → bản đồ ở level 2. Không tốn mạng, không cộng gold,
##   không tăng level chính, không điểm Leaderboard hay Weekly Pass.
## - [EDGE] Chạm mốc hiện tại trên bản đồ vào level 2, chạm khối bị chặn tới hết bước: hộp thoại mời xem video
##   rt_revive +ROAD_TRIP.revive_moves bước, đúng ROAD_TRIP.revive_max lần; lần hết bước sau đó ra thẻ thua, không mất
##   mạng; Chơi lại miễn phí; rời level (Cài đặt → Home) không hỏi mất mạng, về bản đồ vẫn ở level 2. Về Home lần nữa:
##   hướng dẫn không hiện lại.
## - [HP] Hộp quà có avatar/frame (hộp đầu tiên trong ROAD_TRIP_COSMETICS): chạm hộp trên bản đồ hiện bong bóng thưởng;
##   [EDGE] bấm Level ngay lúc bong bóng chưa tự tắt (không được có lỗi engine); thắng level của hộp thì kho cộng đúng
##   ROAD_TRIP_REWARDS, món vào bộ sưu tập và được đeo, chip sang khoảng hộp kế.
## - [EDGE] Hộp có avatar/frame người chơi đã có (hộp thứ hai trong ROAD_TRIP_COSMETICS): chỉ trao booster, không đổi
##   món đang đeo, popup không có ô avatar/frame.
static func scen_rt(r) -> bool:
	if not await _rt_unlock(r):
		return false
	if not await _rt_revive(r):
		return false
	if not await Scen.back_home(r):
		return r.fail("bản đồ Road Trip không về Home")
	if r.main.current_screen.get("road_trip_guide") != null:
		return r.fail("[EDGE] hướng dẫn Road Trip hiện lại lần hai, design.md: chạm đâu cũng tắt, không hiện lại")
	r.step("[EDGE] về Home lần nữa: không còn lớp hướng dẫn Road Trip")
	if not await Scen.verify_saved(r):
		return false
	var cos_boxes := _cos_boxes()
	if cos_boxes.size() < 2:
		return r.fail("Config.ROAD_TRIP_COSMETICS cần ít nhất 2 hộp có avatar/frame cho kịch bản RT")
	if not await _rt_box(r, "RT_box", cos_boxes[0], false):
		return false
	return await _rt_box(r, "RT_owned", cos_boxes[1], true)


## Save ở level ngay trước mốc mở: tab khoá; thắng thì vào thẳng level mở; về Home có hướng dẫn; chạm tab mở bản đồ;
## chơi và thắng level Road Trip 1.
static func _rt_unlock(r) -> bool:
	var unlock := int(Config.UNLOCK.road_trip)
	var prep := func(g: Node) -> void:
		_prep(g, unlock - 1)
		g.s.road_trip["guide"] = false
	if not await r.open_game("RT", prep):
		return false
	if not await Scen.go_home_from_level(r):
		return false
	await Scen.settle_all(r)
	var tab := Scen.find_visible(r.main.current_screen, "RoadTripTab") as BaseButton
	if tab == null:
		return r.fail("Home không có tab Road Trip ở thanh dưới")
	var cap := tab.get_node("Caption") as Label
	if not tab.disabled or bool(r.game.road_trip_view().open):
		return r.fail("[NEG] L%d: tab Road Trip không khoá (mở từ L%d)" % [unlock - 1, unlock])
	if not cap.is_visible_in_tree() or not cap.text.contains(str(unlock)):
		return r.fail("[NEG] tab Road Trip khoá ghi \"%s\", mong đợi ghi Level %d" % [cap.text, unlock])
	await r.shot("rt_locked")
	await r.tap(tab, "tab Road Trip (đang khoá)")
	await r.wait_sec(1.0)
	if r.screen_name() != "home" or r.main.popup_count() > 0:
		return r.fail("[NEG] chạm tab Road Trip đang khoá mà màn đổi (%s)" % r.describe())
	r.step("[NEG] L%d: tab Road Trip khoá, ghi \"%s\", chạm không mở gì" % [unlock - 1, cap.text])
	if not await Scen.tap_named(r, "PlayButton", r.main.current_screen):
		return false
	if not await Scen.wait_for(r, func() -> bool: return Scen._playing(r) == unlock - 1, 20000):
		return r.fail("bấm Chơi không vào L%d" % (unlock - 1))
	if not await Scen.win_level(r):
		return false
	if not await Scen.after_win(r, unlock - 1):
		return false
	if r.screen_name() == "home":
		return r.fail("thắng L%d bị đưa về Home, design.md: Road Trip không kéo về Home" % (unlock - 1))
	if not await Scen.wait_for(r, func() -> bool: return Scen._playing(r) == unlock, 20000):
		return r.fail("thắng L%d không vào L%d (%s)" % [unlock - 1, unlock, r.describe()])
	if not bool(r.game.road_trip_view().open):
		return r.fail("đang ở L%d mà Road Trip chưa mở" % unlock)
	r.step("[HP] thắng L%d vào thẳng L%d, Road Trip mở" % [unlock - 1, unlock])
	if not await Scen.go_home_from_level(r):
		return false
	var home: Node = r.main.current_screen
	if home.get("road_trip_guide") == null:
		return r.fail("lần đầu về Home sau khi mở Road Trip mà không có lớp hướng dẫn chỉ vào tab")
	# Popup tự mở ở Home (nếu có, vd Weekly Pass) nằm trên lớp hướng dẫn: đóng nó, không chạm lớp hướng dẫn.
	await r.wait_sec(0.5)
	await Scen.close_to(r, 0)
	if home.get("road_trip_guide") == null:
		return r.fail("đóng popup ở Home mà lớp hướng dẫn Road Trip cũng tắt")
	await r.shot("rt_guide")
	tab = Scen.find_visible(home, "RoadTripTab") as BaseButton
	if tab == null or tab.disabled:
		return r.fail("Road Trip đã mở mà tab vẫn khoá")
	if not await r.tap(tab, "tab Road Trip (theo bàn tay hướng dẫn)"):
		return r.fail("không chạm được tab Road Trip khi lớp hướng dẫn đang hiện")
	if not await Scen.wait_for(r, func() -> bool: return r.screen_name() == "road_trip", 8000, "*"):
		return r.fail("chạm tab Road Trip không mở bản đồ (%s)" % r.describe())
	if not bool(r.game.s.road_trip.get("guide", false)):
		return r.fail("đã chạm tab mà hướng dẫn Road Trip chưa ghi là đã xem")
	await r.quiet()
	await r.wait_sec(1.0)
	if RoadTrip.current(r.game.s) != 1:
		return r.fail("Road Trip vừa mở mà không ở level 1 (đang %d)" % RoadTrip.current(r.game.s))
	if not _rt_chip(r, 1):
		return false
	await r.shot("rt_map")
	r.step("[HP] chạm tab: hướng dẫn tắt, bản đồ Road Trip ở level 1")
	return await _rt_play(r, "rt_win_1")


## Level Road Trip đang tới, vào bằng chạm mốc hiện tại trên bản đồ: hết bước → hồi sinh bằng video đúng revive_max lần
## → thẻ thua (không mất mạng) → Chơi lại → rời level về bản đồ.
static func _rt_revive(r) -> bool:
	var cur := RoadTrip.current(r.game.s)
	var lives := int(r.game.s.lives["count"])
	if not await _tap_map(r, cur, "mốc hiện tại (level %d)" % cur):
		return false
	if not await Scen.wait_for(r, func() -> bool: return _rt_playing(r), 20000):
		return r.fail("chạm mốc hiện tại trên bản đồ không vào level Road Trip %d (%s)" % [cur, r.describe()])
	var lv := _rt_level(r)
	if int(lv.attempt.level) != cur:
		return r.fail("chạm mốc level %d mà mở level Road Trip %d" % [cur, int(lv.attempt.level)])
	var blocked := _blocked_id(lv.board)
	if blocked == "":
		return r.fail("level Road Trip %d không có khối bị chặn từ đầu" % cur)
	var moves0: int = lv.board.moves_left()
	r.step("[EDGE] level Road Trip %d: chạm khối bị chặn %s tới hết %d bước" % [cur, blocked, moves0])
	var max_rev := int(Config.ROAD_TRIP.revive_max)
	var gain := int(Config.ROAD_TRIP.revive_moves)
	for i in max_rev + 1:
		var got := await _rt_burn(r, blocked)
		if got == "":
			return false
		if i == max_rev:
			if got != "lose":
				return r.fail("[EDGE] đã hồi sinh %d lần mà hết bước vẫn mời xem video, design.md: tối đa %d lần" % [
					max_rev, max_rev])
			break
		if got != "revive":
			return r.fail("[EDGE] hết bước lần %d ra thẻ thua, design.md: mời xem video +%d bước, tối đa %d lần" % [
				i + 1, gain, max_rev])
		if i == 0:
			await r.shot("rt_revive")
		var btn := r.popup_node("ReviveButton") as Control
		if not await Scen._ad_tap(r, btn, "rt_revive", "", "xem video +%d bước (lần %d)" % [gain, i + 1]):
			return false
		if not await Scen.wait_for(r, func() -> bool:
				return _rt_playing(r) and _rt_level(r).board.moves_left() == gain, 10000, "*"):
			return r.fail("xem hết video rt_revive mà level không có %d bước" % gain)
		r.step("[EDGE] hồi sinh lần %d: +%d bước" % [i + 1, gain])
	var lose: Node = r.popup_script("lose_card.gd")
	if Scen.find_visible(lose, "LifeLabel") != null:
		return r.fail("thẻ thua Road Trip ghi mất mạng, design.md: thua không mất mạng")
	await r.shot("rt_lose")
	if int(r.game.s.lives["count"]) != lives:
		return r.fail("thua level Road Trip mà mạng %d → %d, design.md: không mất mạng" % [lives,
			int(r.game.s.lives["count"])])
	if RoadTrip.current(r.game.s) != cur:
		return r.fail("thua level Road Trip %d mà đường đổi sang level %d" % [cur, RoadTrip.current(r.game.s)])
	r.step("[EDGE] lần hết bước thứ %d ra thẻ thua, mạng vẫn %d" % [max_rev + 1, lives])
	if not await Scen.tap_named(r, "RetryButton", lose):
		return false
	if not await Scen.wait_for(r, func() -> bool:
			return _rt_playing(r) and int(_rt_level(r).attempt.revives) == 0, 15000):
		return r.fail("Chơi lại ở thẻ thua Road Trip không vào lại level %d (%s)" % [cur, r.describe()])
	lv = _rt_level(r)
	if lv.board.moves_left() != moves0 or int(lv.attempt.level) != cur or int(r.game.s.lives["count"]) != lives:
		return r.fail("Chơi lại level Road Trip %d: %d bước, mạng %d; mong đợi %d bước, mạng %d" % [cur,
			lv.board.moves_left(), int(r.game.s.lives["count"]), moves0, lives])
	r.step("[EDGE] Chơi lại miễn phí: level %d lại %d bước, mạng vẫn %d" % [cur, moves0, lives])
	if not await _rt_leave(r):
		return false
	if RoadTrip.current(r.game.s) != cur or int(r.game.s.lives["count"]) != lives:
		return r.fail("bỏ level Road Trip %d giữa chừng: đường ở %d, mạng %d (trước %d)" % [cur,
			RoadTrip.current(r.game.s), int(r.game.s.lives["count"]), lives])
	await r.shot("rt_map_after_quit")
	r.step("[EDGE] bỏ level Road Trip giữa chừng về bản đồ, vẫn ở level %d, mạng vẫn %d" % [cur, lives])
	return true


## Hộp thứ `bi` (đếm từ 0) có avatar/frame: save đứng ở level của hộp; `owned` thì người chơi đã có món đó.
static func _rt_box(r, save_name: String, bi: int, owned: bool) -> bool:
	var box_level: int = RoadTrip.boxes()[bi]
	var cos := RoadTrip.cosmetic(bi)
	var kind := Cosmetics.kind_of(cos)
	var reward := RoadTrip.reward(bi)
	var tag := save_name.to_lower()
	var prep := func(g: Node) -> void:
		_prep(g, int(Config.UNLOCK.road_trip) + 1)
		g.s.road_trip["level"] = box_level
		g.s.road_trip["boxes"] = bi
		if owned:
			(g.s.cos.owned as Array).append(cos)
	if not await r.open_game(save_name, prep):
		return false
	if not await Scen.go_home_from_level(r):
		return false
	await Scen.settle_all(r)
	if not await Scen.tap_named(r, "RoadTripTab", r.main.current_screen):
		return false
	if not await Scen.wait_for(r, func() -> bool: return r.screen_name() == "road_trip", 8000):
		return r.fail("tab Road Trip không mở bản đồ (%s)" % r.describe())
	await r.quiet()
	await r.wait_sec(1.0)
	if not _rt_chip(r, box_level):
		return false
	var rt: Node = r.main.current_screen
	if not await _tap_map(r, box_level, "hộp quà thứ %d (level %d)" % [bi + 1, box_level]):
		return false
	if not await Scen.wait_for(r, func() -> bool: return is_instance_valid(rt.get("bubble")), 3000):
		return r.fail("chạm hộp quà trên bản đồ không hiện bong bóng thưởng")
	var bubble := rt.get("bubble") as Control
	var cells := bubble.find_children("*", "Label", true, false).size()
	var want_cells := reward.size() + (1 if cos != "" else 0)
	if cells != want_cells or (bubble.find_child("CosIcon", true, false) != null) != (cos != ""):
		return r.fail("bong bóng hộp %d có %d ô, mong đợi %d (thưởng %s, %s)" % [bi + 1, cells, want_cells,
			JSON.stringify(reward), cos])
	r.step("bong bóng hộp quà %d: %s và %s" % [bi + 1, JSON.stringify(reward), cos])
	await r.shot("%s_bubble" % tag)
	var cos_before := str(r.game.s.cos.get(kind, ""))
	var before := _snap(r)
	# Người chơi xem bong bóng rồi bấm Level ngay, lúc bong bóng chưa tự tắt (BUBBLE_SEC của màn Road Trip).
	var errs := int(r.get("_engine_errors"))
	r.step("bấm Level %d khi bong bóng hộp quà %s" % [box_level, "còn hiện" if is_instance_valid(rt.get("bubble")) \
		else "đã tắt"])
	if not await _rt_play(r, "%s_open" % tag, 0 if owned else 1):
		return false
	if int(r.get("_engine_errors")) > errs:
		_bug(r, "[ERR] bấm Level khi bong bóng hộp quà còn hiện: lỗi engine \"Lambda capture at index 1 was freed\" lúc bong bóng hết giờ (src/ui/road_trip.gd _show_box_bubble: lambda của timer BUBBLE_SEC giữ `panel` mà _open_level → _hide_bubble đã giải phóng)")
	var s: Dictionary = r.game.s
	var problem := _reward_diff(r, before, {"coins": 0, "items": reward})
	if problem != "":
		return r.fail("mở hộp quà %d (ROAD_TRIP_REWARDS): %s" % [bi + 1, problem])
	if int(s.road_trip.get("boxes", 0)) != bi + 1:
		return r.fail("mở hộp quà %d mà số hộp đã nhận là %d" % [bi + 1, int(s.road_trip.get("boxes", 0))])
	if owned:
		if str(s.cos.get(kind, "")) != cos_before:
			return r.fail("[EDGE] hộp %d có %s đã có sẵn mà đổi món đang đeo %s → %s, design.md: không đổi món đang đeo" % [
				bi + 1, cos, cos_before, str(s.cos.get(kind, ""))])
		r.step("[EDGE] hộp %d: %s đã có sẵn, chỉ nhận %s, vẫn đeo %s" % [bi + 1, cos, JSON.stringify(reward), cos_before])
	else:
		if not Cosmetics.is_owned(s, cos) or str(s.cos.get(kind, "")) != cos:
			return r.fail("mở hộp %d mà %s chưa vào bộ sưu tập hoặc chưa được đeo (đang đeo %s)" % [bi + 1, cos,
				str(s.cos.get(kind, ""))])
		r.step("[HP] hộp %d: nhận %s, %s vào bộ sưu tập và được đeo" % [bi + 1, JSON.stringify(reward), cos])
	var ev := _last_event(r, "rt_box")
	if not ev.is_empty() and int((ev.params as Dictionary).get("box", 0)) != bi + 1:
		return r.fail("analytics rt_box ghi hộp %s, mong đợi %d" % [str(ev.params.get("box")), bi + 1])
	await r.shot("%s_map" % tag)
	if not await Scen.back_home(r):
		return r.fail("bản đồ Road Trip không về Home")
	return await Scen.verify_saved(r)


## Từ bản đồ: nút Level (ghi đúng level đang tới) → chơi tới khi thắng → popup thắng → về bản đồ (_rt_finish).
## `cos_tile`: -1 không kiểm, 0 popup không có ô avatar/frame, 1 có.
static func _rt_play(r, tag: String, cos_tile: int = -1) -> bool:
	var rt: Node = r.main.current_screen
	var cur := RoadTrip.current(r.game.s)
	var before := _snap(r)
	var play_label := rt.get("play_label") as Label
	if play_label == null or not play_label.text.contains(str(cur)):
		return r.fail("nút Level trên bản đồ ghi \"%s\", mong đợi level %d" % [
			play_label.text if play_label != null else "", cur])
	if not await Scen.tap_named(r, "PlayButton", rt):
		return false
	return await _rt_finish(r, cur, before, tag, cos_tile)


## Đợi level Road Trip `cur` vào chơi, thắng bằng chạm thật, kiểm popup thắng (không x2, thanh tiến độ chạy tới "sau",
## hộp quà thì đợi vật phẩm nảy ra), bấm Tiếp tục/Nhận, về bản đồ ở level kế. Không tốn mạng, không cộng gold, không
## tăng level chính, không điểm Leaderboard hay Weekly Pass (design.md mục 7 "Mạng và kinh tế").
static func _rt_finish(r, cur: int, before: Dictionary, tag: String, cos_tile: int) -> bool:
	if not await Scen.wait_for(r, func() -> bool: return _rt_playing(r), 20000):
		return r.fail("không vào được level Road Trip %d (%s)" % [cur, r.describe()])
	var lv := _rt_level(r)
	if int(lv.attempt.level) != cur:
		return r.fail("mở level Road Trip %d, mong đợi %d" % [int(lv.attempt.level), cur])
	if int(r.game.s.lives["count"]) != int(before.lives):
		return r.fail("vào level Road Trip mà mạng %d → %d, design.md: chơi không tốn mạng" % [int(before.lives),
			int(r.game.s.lives["count"])])
	if not await _win_rt(r):
		return false
	if not await Scen.wait_for(r, func() -> bool: return r.popup_script("popup_road_trip_win.gd") != null, 20000,
			"popup_road_trip_win.gd"):
		return r.fail("thắng level Road Trip %d mà không có popup thắng (%s)" % [cur, r.describe()])
	var pop: Node = r.popup_script("popup_road_trip_win.gd")
	if pop.find_child("X2Button", true, false) != null:
		return r.fail("popup thắng Road Trip có nút x2, design.md: không x2")
	var p0 := RoadTrip.progress(cur)
	var want := "%d/%d" % [mini(p0.x + 1, p0.y), p0.y]
	var bar := pop.get("bar_label") as Label
	if p0.y > 0 and not await Scen.wait_for(r, func() -> bool: return bar.text == want, 6000, "popup_road_trip_win.gd"):
		return r.fail("popup thắng Road Trip: thanh \"%s\", mong đợi %s" % [bar.text, want])
	var bi := RoadTrip.box_index(cur)
	if bi >= 0:
		var first := "Reward_%s" % str(RoadTrip.reward(bi).keys()[0])
		if not await Scen.wait_for(r, func() -> bool: return Scen.find_visible(pop, first) != null, 6000,
				"popup_road_trip_win.gd"):
			return r.fail("level %d có hộp quà mà popup thắng không mở hộp ra vật phẩm" % cur)
		var has_cos := pop.find_child("Reward_cos", true, false) != null
		if cos_tile >= 0 and has_cos != (cos_tile == 1):
			return r.fail("popup mở hộp %d %s ô avatar/frame, mong đợi %s" % [bi + 1, "có" if has_cos else "không có",
				"có" if cos_tile == 1 else "không có"])
	await r.wait_sec(0.6)
	await r.shot(tag)
	var ok := Scen.find_visible(pop, "OkButton") as Control
	if ok == null:
		return r.fail("popup thắng Road Trip không có nút Tiếp tục/Nhận")
	if not await r.tap(ok, "Nhận" if bi >= 0 else "Tiếp tục"):
		return r.fail("không bấm được nút của popup thắng Road Trip")
	if not await _back_to_map(r, "đóng popup thắng Road Trip"):
		return false
	var now_level := RoadTrip.current(r.game.s)
	if now_level != cur + 1:
		return r.fail("thắng level Road Trip %d mà đường ở level %d, mong đợi %d" % [cur, now_level, cur + 1])
	var changed := _changed(r, before, ["coins", "lives", "level", "lb", "weekly"])
	if changed != "":
		return r.fail("thắng level Road Trip %d mà đổi %s, design.md: không gold, không mạng, không level chính, không điểm Leaderboard hay Weekly Pass" % [
			cur, changed])
	if not _rt_chip(r, now_level):
		return false
	r.step("[HP] thắng level Road Trip %d (thanh %s), về bản đồ ở level %d; gold, mạng, level chính không đổi" % [
		cur, want, now_level])
	return true


## Chơi level Road Trip đang mở tới khi thắng: mỗi nước do solver chọn, chạm bằng input thật (như Scen.win_level, nhưng
## màn level là con của màn Road Trip nên runner.level_screen() không thấy nó).
static func _win_rt(r) -> bool:
	var lv := _rt_level(r)
	var lvl := int(lv.attempt.level)
	r.begin_phase("RT%d" % lvl)
	var misses := 0
	for i in 600:
		if not r.failed_reason.is_empty():
			return false
		lv = _rt_level(r)
		if lv == null or lv.board.is_won():
			break
		if str(lv.state) != "playing":
			await Scen.settle(r)
			await r.wait_frames(1)
			continue
		var sol: Dictionary = Solver.solve_state(lv.board)
		var hit := false
		if bool(sol.ok) and not (sol.order as Array).is_empty():
			hit = await _tap_block_in(r, lv, str(sol.order[0]))
		if not hit:
			misses += 1
			if misses > 5:
				r.end_phase()
				return r.fail("level Road Trip %d: 5 lần chạm khối theo solver không trúng" % lvl)
		await r.wait_frames(2)
	r.end_phase()
	lv = _rt_level(r)
	if lv != null and not lv.board.is_won():
		return r.fail("level Road Trip %d chưa thắng sau 600 vòng" % lvl)
	r.step("thắng level Road Trip %d" % lvl)
	return true


## Chạm khối `id` tới khi hết bước: "revive" khi hộp thoại hồi sinh hiện, "lose" khi thẻ thua hiện, "" khi lỗi.
## Hộp thoại đang đóng (vừa hồi sinh xong) không tính: r.popup_node bỏ qua popup đang đóng.
static func _rt_burn(r, id: String) -> String:
	for i in 400:
		if not r.failed_reason.is_empty():
			return ""
		var rb := r.popup_node("ReviveButton") as Control
		if rb != null and rb.is_visible_in_tree():
			await r.wait_sec(0.4)
			return "revive"
		if r.popup_script("lose_card.gd") != null:
			await r.wait_sec(0.6)
			return "lose"
		var lv := _rt_level(r)
		if lv != null and str(lv.state) == "playing" and lv.board.moves_left() > 0:
			await _tap_block_in(r, lv, id)
		else:
			await Scen.settle(r)
		await r.wait_frames(3)
	r.fail("chạm khối bị chặn %s không làm hết bước" % id)
	return ""


## Rời level Road Trip giữa chừng: Cài đặt trong màn → Home; không hỏi mất mạng; về bản đồ.
static func _rt_leave(r) -> bool:
	var lv := _rt_level(r)
	if lv == null:
		return r.fail("không ở level Road Trip để rời")
	await r.tap(lv.settings_button, "Cài đặt trong level Road Trip")
	if not await Scen.wait_for(r, func() -> bool: return r.popup_script("popup_ingame_settings.gd") != null, 6000,
			"popup_ingame_settings.gd"):
		return r.fail("Cài đặt trong level Road Trip không mở")
	await r.wait_sec(0.4)
	if not await Scen.tap_named(r, "HomeButton", r.popup_script("popup_ingame_settings.gd")):
		return false
	if not await Scen.wait_for(r, func() -> bool:
			return r.popup_script("popup_keep_playing.gd") != null or (r.screen_name() == "road_trip" \
				and _rt_level(r) == null and r.main.curtain == null), 20000, "popup_keep_playing.gd"):
		return r.fail("rời level Road Trip không về bản đồ (%s)" % r.describe())
	if r.popup_script("popup_keep_playing.gd") != null:
		return r.fail("rời level Road Trip mà hỏi xác nhận mất mạng, design.md: bỏ giữa chừng không mất mạng")
	return true


static func _back_to_map(r, why: String) -> bool:
	var ok: bool = await Scen.wait_for(r, func() -> bool:
		return r.screen_name() == "road_trip" and _rt_level(r) == null and r.main.curtain == null, 20000)
	return ok or r.fail("%s không về bản đồ Road Trip (%s)" % [why, r.describe()])


## Chip tiến độ trên bản đồ khớp RoadTrip.progress của level `cur` ("đã qua/khoảng").
static func _rt_chip(r, cur: int) -> bool:
	var rt: Node = r.main.current_screen
	var p := RoadTrip.progress(cur)
	if p.y <= 0:
		return true
	var chip := rt.get("chip") as Control
	var label := rt.get("chip_label") as Label
	var want := "%d/%d" % [p.x, p.y]
	if chip == null or label == null or not chip.visible or label.text != want:
		return r.fail("chip tiến độ ở level %d ghi \"%s\", mong đợi %s" % [cur, label.text if label != null else "", want])
	r.step("chip tiến độ hộp quà ở level %d: %s" % [cur, want])
	return true


## Chạm mốc (hoặc hộp) `n` trên bản đồ Road Trip bằng input thật; báo lỗi khi điểm chạm bị node khác che.
static func _tap_map(r, n: int, label: String) -> bool:
	var map := r.main.current_screen.get("map") as Control
	if map == null:
		return r.fail("màn Road Trip không có bản đồ")
	var p: Vector2 = r.to_viewport(map, map.call("center_of", n))
	var h: Control = await r.hovered_at(p)
	if h == null or (h != map and not map.is_ancestor_of(h)):
		return r.fail("chạm %s: điểm trên bản đồ bị %s che" % [label, r.node_label(h)])
	r.step("chạm %s trên bản đồ" % label)
	await r.click_at(p)
	return true


## Màn level Road Trip đang mở (con của màn Road Trip), null khi không có.
static func _rt_level(r) -> Control:
	if r.main == null or r.screen_name() != "road_trip" or r.main.current_screen == null:
		return null
	var lv: Variant = r.main.current_screen.get("level_node")
	if not is_instance_valid(lv):
		return null
	return lv as Control


static func _rt_playing(r) -> bool:
	var lv := _rt_level(r)
	return lv != null and str(lv.state) == "playing"


## Chỉ số (từ 0) các hộp Road Trip có avatar/frame (Config.ROAD_TRIP_COSMETICS).
static func _cos_boxes() -> Array[int]:
	var out: Array[int] = []
	for i in RoadTrip.boxes().size():
		if RoadTrip.cosmetic(i) != "":
			out.append(i)
	return out


## Bấm khối `id` của màn level `lv` như runner.tap_block (tâm một ô của khối mà board_view.block_at trả đúng khối đó).
static func _tap_block_in(r, lv: Control, id: String) -> bool:
	var bv: Control = lv.board_view
	var node: Control = bv.block_node(id)
	if node == null:
		return r.fail("bấm khối %s: không có node" % id)
	for c in node.get("cells"):
		var local: Vector2 = bv.cell_center(c)
		if str(bv.block_at(local)) != id:
			continue
		var p: Vector2 = r.to_viewport(bv, local)
		var h: Control = await r.hovered_at(p)
		var deadline := Time.get_ticks_msec() + 2000
		while Time.get_ticks_msec() < deadline and not _on_board(bv, h):
			await r.wait_frames(2)
			if not is_instance_valid(bv):
				return r.fail("bấm khối %s: bàn biến mất" % id)
			h = await r.hovered_at(p)
		if not _on_board(bv, h):
			r.step("chạm khối %s (NOT the target: trúng %s)" % [id, r.node_label(h)])
			await r.click_at(p)
			return false
		await r.click_at(p)
		return true
	return r.fail("bấm khối %s: không ô nào của khối nhận chạm" % id)


static func _on_board(bv: Control, h: Control) -> bool:
	return h != null and is_instance_valid(bv) and (h == bv or bv.is_ancestor_of(h))


## Khối đầu tiên bị chặn ngay từ đầu trên bàn `board` (BoardState), "" nếu không có.
static func _blocked_id(board: Object) -> String:
	for id in board.call("block_ids"):
		if str(board.call("peek", id)) == "blocked":
			return str(id)
	return ""


# ================================================================ Leaderboard

## LB. Leaderboard theo league (design.md mục 7 "Leaderboard theo league"):
## - [NEG] Ở L(UNLOCK.leaderboard − 1): icon Bảng xếp hạng ở Home tối, có ổ khoá, ghi "Level N"; chạm không mở gì,
##   chưa vào BXH.
## - [HP] Thắng level đó về Home (tính năng mới ở Home) và vào BXH lúc đó (tuần đầu bắt đầu lúc mở khoá); icon mở popup
##   Leaderboard: giải đầu, 0 điểm, BXH LEADERBOARD.board_size người có hàng của người chơi, đồng hồ hết tuần. Vào level
##   mở: popup Cách hoạt động trước khi chơi (một lần); thắng thì điểm tuần cộng đúng số khối crystal
##   (LEADERBOARD.pieces_* theo độ khó), thẻ thắng có thẻ người chơi.
## - [HP] Save đã vào BXH, thiếu 1 điểm tới giải thứ hai: thắng level có crystal → lên giải, sau thẻ thắng popup Lên
##   giải; chạm để nhận thì gold và booster cộng đúng thưởng của giải trong Config.LEADERBOARD.
## - [EDGE] Thưởng giải nhận một lần: về Home không còn chấm đỏ, mở lại Leaderboard không hiện popup thưởng, gold không
##   đổi.
## - [EDGE] Hết tuần khi popup đang mở: giờ máy qua mốc hết tuần, đồng hồ trên popup về 0 thì chốt tuần và mở popup Kết
##   quả tuần (giải và điểm của tuần vừa hết, không cộng lại thưởng đã nhận); tuần mới 0 điểm, giải đầu, thưởng các giải
##   nhận lại được.
static func scen_lb(r) -> bool:
	if not await _lb_unlock(r):
		return false
	if not await Scen.verify_saved(r):
		return false
	if not await _lb_promote(r):
		return false
	if not await _lb_week_end(r):
		return false
	return await Scen.verify_saved(r)


static func _lb_unlock(r) -> bool:
	var unlock := int(Config.UNLOCK.leaderboard)
	var prep := func(g: Node) -> void:
		_prep(g, unlock - 1)
		g.s.lb["guide"] = false
	if not await r.open_game("LB", prep):
		return false
	if not await Scen.go_home_from_level(r):
		return false
	await Scen.settle_all(r)
	var home: Node = r.main.current_screen
	var btn := Scen.find_visible(home, "LeaderboardButton") as BaseButton
	if btn == null:
		return r.fail("Home không có icon Bảng xếp hạng")
	var cap := home.get("leaderboard_caption") as Label
	if not btn.disabled or r.game.lb_open() or Scen.find_visible(home, "LeaderboardLock") == null:
		return r.fail("[NEG] L%d: icon Bảng xếp hạng không khoá (mở từ L%d)" % [unlock - 1, unlock])
	if cap == null or not cap.text.contains(str(unlock)):
		return r.fail("[NEG] icon Bảng xếp hạng khoá ghi \"%s\", mong đợi ghi Level %d" % [
			cap.text if cap != null else "", unlock])
	await r.shot("lb_locked")
	await r.tap(btn, "icon Bảng xếp hạng (đang khoá)")
	await r.wait_sec(1.0)
	if r.main.popup_count() > 0 or bool(r.game.s.lb.get("joined", false)):
		return r.fail("[NEG] chạm icon Bảng xếp hạng đang khoá mà mở popup hoặc vào BXH (%s)" % r.describe())
	r.step("[NEG] L%d: icon Bảng xếp hạng khoá, ghi \"%s\", chạm không mở gì" % [unlock - 1, cap.text])
	if not await Scen.tap_named(r, "PlayButton", home):
		return false
	if not await Scen.wait_for(r, func() -> bool: return Scen._playing(r) == unlock - 1, 20000):
		return r.fail("bấm Chơi không vào L%d" % (unlock - 1))
	if not await Scen.win_level(r):
		return false
	if not await Scen.wait_for(r, func() -> bool: return r.popup_node("ContinueButton") != null, 20000,
			"ContinueButton"):
		return r.fail("thắng L%d mà không thấy thẻ thắng" % (unlock - 1))
	await r.wait_sec(0.8)
	await r.shot("lb_unlock_card")
	if not await _tap_continue(r, "thẻ thắng L%d" % (unlock - 1)):
		return false
	if not await Scen.wait_for(r, func() -> bool: return r.screen_name() == "home" and r.main.curtain == null, 20000):
		return r.fail("thắng L%d không về Home, design.md: mở Leaderboard thì về Home (%s)" % [unlock - 1, r.describe()])
	var lb: Dictionary = r.game.s.lb
	if not bool(lb.get("joined", false)) or int(lb.get("t0", 0)) != int(r.game.now()):
		return r.fail("thắng L%d mà chưa vào BXH, hoặc tuần đầu không bắt đầu lúc mở khoá (t0 %d, giờ %d)" % [
			unlock - 1, int(lb.get("t0", 0)), int(r.game.now())])
	r.step("[HP] thắng L%d về Home, vào BXH, tuần đầu bắt đầu lúc mở khoá" % (unlock - 1))
	await Scen.settle_all(r)
	if not await _lb_open_popup(r):
		return false
	var pop: Node = r.popup_script("leaderboard.gd")
	var v: Dictionary = r.game.lb_view()
	var size := int(Config.LEADERBOARD.board_size)
	if str(v.league) != Leaderboard.league_id(0) or int(v.points) != 0 or int(v.size) != size:
		return r.fail("BXH vừa mở: giải %s, %d điểm, %d người; mong đợi %s, 0 điểm, %d người" % [str(v.league),
			int(v.points), int(v.size), Leaderboard.league_id(0), size])
	if pop.find_child("Me", true, false) == null:
		return r.fail("BXH không có hàng của người chơi")
	var cd := pop.get("countdown_label") as Label
	if cd == null or cd.text.strip_edges() == "":
		return r.fail("PromoBox của Leaderboard không có đồng hồ hết tuần")
	await r.shot("lb_popup")
	r.step("[HP] popup Leaderboard: giải %s, hạng %d/%d, \"%s\"" % [str(v.league), int(v.rank), size, cd.text])
	if not await Scen.close_to(r, 0):
		return r.fail("không đóng được popup Leaderboard")
	if not await Scen.tap_named(r, "PlayButton", r.main.current_screen):
		return false
	if not await Scen.wait_for(r, func() -> bool:
			return r.popup_script("popup_lb_howto.gd") != null or Scen._playing(r) == unlock, 20000, "popup_lb_howto.gd"):
		return r.fail("bấm Chơi không vào L%d (%s)" % [unlock, r.describe()])
	var howto: Node = r.popup_script("popup_lb_howto.gd")
	if howto == null:
		return r.fail("vào L%d (level có khối crystal đầu tiên) mà không có popup Cách hoạt động" % unlock)
	await r.wait_sec(0.6)
	await r.shot("lb_howto")
	if not await Scen.tap_named(r, "OkButton", howto):
		return false
	if not await Scen.wait_for(r, func() -> bool: return Scen._playing(r) == unlock, 15000):
		return r.fail("đóng popup Cách hoạt động không vào chơi L%d" % unlock)
	if not bool(r.game.s.lb.get("guide", false)):
		return r.fail("đã hiện popup Cách hoạt động mà chưa ghi là đã xem")
	r.step("[HP] L%d: popup Cách hoạt động hiện trước khi chơi" % unlock)
	if not await _lb_win_points(r, "lb_win_card"):
		return false
	if not await _tap_continue(r, "thẻ thắng L%d" % unlock):
		return false
	var moved: bool = await Scen.wait_for(r, func() -> bool:
		return Scen._playing(r) > unlock or r.screen_name() == "home", 20000)
	return moved or r.fail("sau thẻ thắng L%d không sang level kế hay Home" % unlock)


## Save đã vào BXH, thiếu 1 điểm tới giải thứ hai: thắng level có crystal → popup Lên giải → nhận; về Home, mở lại
## Leaderboard không có thưởng lần hai.
static func _lb_promote(r) -> bool:
	var lvl := int(Config.UNLOCK.leaderboard) + 2
	var up := 1
	var up_min := Leaderboard.league_min(up)
	var prep := func(g: Node) -> void:
		_prep(g, lvl)
		Leaderboard.join(g.s, int(g.now()))
		g.s.lb["points"] = up_min - 1
	if not await r.open_game("LB_promote", prep):
		return false
	if not await Scen.wait_for(r, func() -> bool: return Scen._playing(r) == lvl, 20000):
		return r.fail("không vào được L%d" % lvl)
	var s: Dictionary = r.game.s
	if Leaderboard.league(s) != 0 or not Leaderboard.pending(s).is_empty():
		return r.fail("save %d điểm mà giải %s, thưởng chờ %s" % [up_min - 1, Leaderboard.league_id(Leaderboard.league(s)),
			str(Leaderboard.pending(s))])
	r.step("BXH: %d điểm, thiếu 1 điểm tới giải %s" % [up_min - 1, Leaderboard.league_id(up)])
	if not await _lb_win_points(r, "lb_promote_card"):
		return false
	var li := Leaderboard.league_for(Leaderboard.points(s))
	if li != up or Leaderboard.league(s) != up or Leaderboard.pending(s) != [up]:
		return r.fail("đủ %d điểm mà giải %s, thưởng chờ %s; mong đợi giải %s chờ nhận" % [Leaderboard.points(s),
			Leaderboard.league_id(Leaderboard.league(s)), str(Leaderboard.pending(s)), Leaderboard.league_id(up)])
	var reward := Leaderboard.reward_of(up)
	if not await _tap_continue(r, "thẻ thắng L%d" % lvl):
		return false
	if not await Scen.wait_for(r, func() -> bool: return r.popup_script("popup_lb_result.gd") != null, 20000,
			"popup_lb_result.gd"):
		return r.fail("lên giải %s mà sau thẻ thắng không có popup Lên giải (%s)" % [Leaderboard.league_id(up),
			r.describe()])
	var pop: Node = r.popup_script("popup_lb_result.gd")
	if not (pop.get("week") as Dictionary).is_empty():
		return r.fail("popup sau thẻ thắng là Kết quả tuần, mong đợi Lên giải")
	await r.wait_sec(0.8)
	await r.shot("lb_promoted")
	var before := _snap(r)
	if not await _claim_lb_result(r, pop, "Lên giải"):
		return false
	var problem := _reward_diff(r, before, reward)
	if problem != "":
		return r.fail("nhận thưởng giải %s (Config.LEADERBOARD): %s" % [Leaderboard.league_id(up), problem])
	if not Leaderboard.pending(s).is_empty():
		return r.fail("đã nhận mà thưởng giải %s vẫn chờ" % Leaderboard.league_id(up))
	r.step("[HP] lên giải %s, nhận %d gold, %s" % [Leaderboard.league_id(up), int(reward.coins),
		JSON.stringify(reward.items)])
	if not await Scen.wait_for(r, func() -> bool: return Scen._playing(r) > lvl or r.screen_name() == "home", 20000):
		return r.fail("sau popup Lên giải không sang level kế hay Home (%s)" % r.describe())
	if not await Scen.go_home_from_level(r):
		return false
	await Scen.settle_all(r)
	var home: Node = r.main.current_screen
	if Scen.find_visible(home, "LeaderboardDot") != null:
		return r.fail("[EDGE] đã nhận thưởng giải mà icon Bảng xếp hạng vẫn có chấm đỏ")
	var coins := int(s.coins)
	if not await _lb_open_popup(r):
		return false
	if await Scen.wait_for(r, func() -> bool: return r.popup_script("popup_lb_result.gd") != null, 2000,
			"popup_lb_result.gd"):
		return r.fail("[EDGE] mở lại Leaderboard mà popup thưởng giải hiện lần nữa")
	if int(s.coins) != coins:
		return r.fail("[EDGE] mở lại Leaderboard mà gold %d → %d" % [coins, int(s.coins)])
	await r.shot("lb_after_claim")
	r.step("[EDGE] thưởng giải nhận một lần: không chấm đỏ, mở lại Leaderboard không có popup thưởng, gold không đổi")
	var closed: bool = await Scen.close_to(r, 0)
	return closed or r.fail("không đóng được popup Leaderboard")


## Ở Home, tuần đang có điểm: mở popup khi còn LB_COUNTDOWN_SEC giây, giờ máy qua mốc hết tuần, đợi đồng hồ về 0.
static func _lb_week_end(r) -> bool:
	var s: Dictionary = r.game.s
	var pts := Leaderboard.points(s)
	var li := Leaderboard.league(s)
	var week := Leaderboard.week(s)
	var end := Leaderboard.week_end(s)
	var coins := int(s.coins)
	if pts <= 0:
		return r.fail("tuần không có điểm, không kiểm được Kết quả tuần")
	r.game.test_now = end - LB_COUNTDOWN_SEC
	if not await _lb_open_popup(r):
		return false
	var pop: Node = r.popup_script("leaderboard.gd")
	var cd := pop.get("countdown_label") as Label
	if int(r.game.lb_ends_in()) != LB_COUNTDOWN_SEC:
		return r.fail("còn %d giây tới hết tuần, mong đợi %d" % [int(r.game.lb_ends_in()), LB_COUNTDOWN_SEC])
	await r.shot("lb_countdown")
	r.step("[EDGE] popup Leaderboard mở, đồng hồ \"%s\"; giờ máy qua mốc hết tuần" % (cd.text if cd != null else ""))
	r.game.test_now = end + 60
	if not await Scen.wait_for(r, func() -> bool: return r.popup_script("popup_lb_result.gd") != null,
			(LB_COUNTDOWN_SEC + 15) * 1000, "popup_lb_result.gd"):
		return r.fail("[EDGE] đồng hồ Leaderboard về 0 mà không chốt tuần (không có popup Kết quả tuần; %s)" % r.describe())
	var res_pop: Node = r.popup_script("popup_lb_result.gd")
	var wk: Dictionary = res_pop.get("week")
	if wk.is_empty():
		return r.fail("[EDGE] hết tuần mà popup là Lên giải, mong đợi Kết quả tuần")
	if int(wk.get("points", -1)) != pts or str(wk.get("league", "")) != Leaderboard.league_id(li):
		return r.fail("[EDGE] Kết quả tuần: giải %s, %d điểm; mong đợi giải %s, %d điểm" % [str(wk.get("league", "")),
			int(wk.get("points", -1)), Leaderboard.league_id(li), pts])
	if Leaderboard.week(s) != week + 1 or Leaderboard.points(s) != 0 or Leaderboard.league(s) != 0:
		return r.fail("[EDGE] hết tuần mà tuần %d, %d điểm, giải %s; mong đợi tuần %d, 0 điểm, giải %s" % [
			Leaderboard.week(s), Leaderboard.points(s), Leaderboard.league_id(Leaderboard.league(s)), week + 1,
			Leaderboard.league_id(0)])
	await r.wait_sec(0.8)
	var over := _drawn_over(pop, res_pop.find_child("ClaimButton", true, false) as CanvasItem)
	if over != "":
		_bug(r, "[UI] popup Kết quả tuần mở trên popup Leaderboard mà %s của Leaderboard vẽ đè lên nền tối và tiêu đề của nó (z_index cao hơn; cúp và hộp quà của PromoBox sáng rõ trên popup)" % over)
	await r.shot("lb_week_result")
	if not await _claim_lb_result(r, res_pop, "Kết quả tuần"):
		return false
	if int(s.coins) != coins:
		return r.fail("[EDGE] Kết quả tuần cộng gold %d → %d, thưởng giải đã nhận trong tuần" % [coins, int(s.coins)])
	if not Leaderboard.result(s).is_empty():
		return r.fail("đã xem Kết quả tuần mà kết quả vẫn chờ")
	var rows: Array = r.game.lb_leagues_view().rows
	if bool((rows[li] as Dictionary).get("reached", true)):
		return r.fail("[EDGE] tuần mới mà giải %s vẫn ghi đã nhận, design.md: thưởng các giải nhận lại được từ đầu" % [
			Leaderboard.league_id(li)])
	await r.wait_sec(0.5)
	await r.shot("lb_new_week")
	r.step("[EDGE] hết tuần: Kết quả tuần giải %s, %d điểm, hạng %d; tuần mới 0 điểm, giải %s, thưởng nhận lại được" % [
		str(wk.league), pts, int(wk.get("rank", 0)), Leaderboard.league_id(0)])
	var closed: bool = await Scen.close_to(r, 0)
	return closed or r.fail("không đóng được popup Leaderboard")


## Thắng level chính đang chơi (có khối crystal): số khối crystal đúng LEADERBOARD.pieces_* theo độ khó (không quá số
## khối), có chip đếm mảnh; thắng thì điểm tuần cộng đúng số đó, thẻ thắng có thẻ người chơi. Dừng ở thẻ thắng.
static func _lb_win_points(r, tag: String) -> bool:
	var lv: Control = r.level_screen()
	var lvl := int(lv.attempt.level)
	var crystals := (lv.attempt.specials as Array).size()
	var want := mini(Leaderboard.pieces_for(str(r.game.difficulty_of(lvl))), (lv.board.block_ids() as Array).size())
	if crystals != want:
		return r.fail("L%d có %d khối crystal, mong đợi %d (LEADERBOARD.pieces_*)" % [lvl, crystals, want])
	if not (lv.piece_chip as Control).is_visible_in_tree():
		return r.fail("L%d có khối crystal mà không có chip đếm mảnh" % lvl)
	var pts := int(r.game.s.lb.points)
	if not await Scen.win_level(r):
		return false
	if not await Scen.wait_for(r, func() -> bool: return r.popup_node("ContinueButton") != null, 20000,
			"ContinueButton"):
		return r.fail("thắng L%d mà không thấy thẻ thắng" % lvl)
	if int(r.game.s.lb.points) != pts + crystals:
		return r.fail("thắng L%d với %d khối crystal: điểm tuần %d → %d" % [lvl, crystals, pts, int(r.game.s.lb.points)])
	var row := r.popup_node("LbRow") as Control
	if row == null or not row.is_visible_in_tree():
		return r.fail("thẻ thắng L%d (có khối crystal) không có thẻ người chơi" % lvl)
	await r.wait_sec(1.0)
	await r.shot(tag)
	r.step("[HP] thắng L%d: %d khối crystal, điểm tuần %d → %d" % [lvl, crystals, pts, pts + crystals])
	return true


## "Chạm để tiếp tục" của popup_lb_result (Lên giải, Kết quả tuần; design.md mục 7: chạm là nhận): người chơi chạm
## vào cúp ở giữa popup trước. Chạm đó không đóng popup thì ghi lỗi game (_bug) rồi chạm vào nền (ClaimButton, cả
## popup) như lần chạm thứ hai của người chơi. Đạt khi popup đã đóng.
static func _claim_lb_result(r, pop: Node, what: String) -> bool:
	var badge := Scen.find_visible(pop, "LeagueBadge") as Control
	if badge != null:
		var p: Vector2 = r.to_viewport(badge, badge.size * 0.5)
		var h: Control = await r.hovered_at(p)
		r.step("chạm cúp giữa popup %s (trúng %s)" % [what, r.node_label(h)])
		await r.click_at(p)
		if await Scen.wait_for(r, func() -> bool: return r.popup_script("popup_lb_result.gd") == null, 1500, "*"):
			return true
		_bug(r, "[UI] chạm cúp giữa popup %s không nhận, popup vẫn mở: %s nằm trên ClaimButton (nền cả popup) và chặn chạm; design.md mục 7: \"Chạm để tiếp tục\", chạm là nhận" % [
			what, r.node_label(h)])
	if not await Scen.tap_named(r, "ClaimButton", pop):
		return false
	if not await Scen.wait_for(r, func() -> bool: return r.popup_script("popup_lb_result.gd") == null, 6000, "*"):
		return r.fail("chạm để tiếp tục không đóng popup %s" % what)
	return true


## Popup `under` (mở trước, cùng lớp popup) có node đang hiện vẽ trên nền tối `dim` của popup mở sau: z_index hiệu
## dụng (cộng dồn khi z_as_relative) lớn hơn của `dim`. Trả "<đường dẫn> (z <n>)" của node đầu tiên như vậy, "" nếu
## không có.
static func _drawn_over(under: Node, dim: CanvasItem) -> String:
	if dim == null:
		return ""
	var top := _z_of(dim)
	for n in under.find_children("*", "CanvasItem", true, false):
		var ci := n as CanvasItem
		if ci.is_visible_in_tree() and _z_of(ci) > top:
			return "%s (z %d)" % [str(under.get_path_to(ci)), _z_of(ci)]
	return ""


static func _z_of(ci: CanvasItem) -> int:
	var z := 0
	var n: Node = ci
	while n is CanvasItem:
		z += (n as CanvasItem).z_index
		if not (n as CanvasItem).z_as_relative:
			break
		n = n.get_parent()
	return z


## Ở Home: chạm icon Bảng xếp hạng, đợi popup Leaderboard (không đóng popup nào trong lúc đợi).
static func _lb_open_popup(r) -> bool:
	var btn := Scen.find_visible(r.main.current_screen, "LeaderboardButton") as BaseButton
	if btn == null or btn.disabled:
		return r.fail("icon Bảng xếp hạng ở Home không bấm được")
	if not await r.tap(btn, "icon Bảng xếp hạng"):
		return r.fail("icon Bảng xếp hạng bị che")
	if not await Scen.wait_for(r, func() -> bool: return r.popup_script("leaderboard.gd") != null, 8000, "*"):
		return r.fail("chạm icon Bảng xếp hạng không mở popup Leaderboard")
	await r.wait_sec(0.6)
	return true


# ================================================================ Màn đặc biệt

## SB. Màn đặc biệt (design.md mục 7 "Màn đặc biệt (Special Bomb)"):
## - [NEG] Ở L(UNLOCK.special_bomb − 1): Home chưa có icon quả bom.
## - [HP] Thắng level đó về Home, popup mời tự mở một lần với 1 vé (lúc mở đã có sẵn 1 vé ngăn chờ). Bắt đầu: màn mưa
##   bom, vé trừ ngay, vé chờ kế sau SPECIAL.timer_sec; lần đầu có hướng dẫn quả bom; số bom theo SpecialBoard.bomb_count.
## - [EDGE] Bom chưa đếm trước lần chạm hợp lệ đầu; đang đếm thì dừng khi có popup (cài đặt trong màn, không có Chơi
##   lại); không gỡ kịp thì nổ: popup "Bùm!", không mất mạng, không đổi gold, level chính, bàn và số trận; X về Home.
## - [NEG] Hết vé: icon không có chấm số vé, chạm mở popup báo thời gian chờ (nút OK, không có Bắt đầu).
## - [EDGE] Giờ máy tới mốc vé chờ − 1 giây: 0 vé; đúng mốc: 1 vé, icon có chấm.
## - [HP] Vào lại từ icon ở Home: đúng bàn và bom cũ (thua không sang bàn kế), không hướng dẫn lần hai; gỡ hết bằng chạm
##   thật → thẻ thắng không có thẻ BXH: 1 booster trong SPECIAL.reward_kinds đã vào kho, +1 trận, sang bàn kế; không
##   gold, không level chính. x2 lần đầu miễn phí (không quảng cáo) thêm 1 booster cùng loại; [EDGE] bấm lần nữa không
##   thêm. Trang chủ về Home, không interstitial vì đã lấy x2.
static func scen_sb(r) -> bool:
	var unlock := int(Config.UNLOCK.special_bomb)
	var prep := func(g: Node) -> void:
		_prep(g, unlock - 1)
		g.s.special["invited"] = false
		g.s.special["guide"] = false
	if not await r.open_game("SB", prep):
		return false
	if not await Scen.go_home_from_level(r):
		return false
	await Scen.settle_all(r)
	if Scen.find_visible(r.main.current_screen, "BombButton") != null or bool(r.game.special_view().open):
		return r.fail("[NEG] L%d: Home đã có icon Màn đặc biệt (mở từ L%d)" % [unlock - 1, unlock])
	await r.shot("sb_locked")
	r.step("[NEG] L%d: Home chưa có icon Màn đặc biệt" % (unlock - 1))
	if not await Scen.tap_named(r, "PlayButton", r.main.current_screen):
		return false
	if not await Scen.wait_for(r, func() -> bool: return Scen._playing(r) == unlock - 1, 20000):
		return r.fail("bấm Chơi không vào L%d" % (unlock - 1))
	if not await Scen.win_level(r):
		return false
	if not await Scen.wait_for(r, func() -> bool: return r.popup_node("ContinueButton") != null, 20000,
			"ContinueButton"):
		return r.fail("thắng L%d mà không thấy thẻ thắng" % (unlock - 1))
	await r.wait_sec(0.8)
	await r.shot("sb_unlock_card")
	if not await _tap_continue(r, "thẻ thắng L%d" % (unlock - 1)):
		return false
	if not await Scen.wait_for(r, func() -> bool:
			return r.screen_name() == "home" and r.popup_script("popup_special.gd") != null, 25000, "popup_special.gd"):
		return r.fail("thắng L%d mà Home không tự mở popup mời Màn đặc biệt (%s)" % [unlock - 1, r.describe()])
	var invite: Node = r.popup_script("popup_special.gd")
	await r.wait_sec(0.6)
	var v: Dictionary = r.game.special_view()
	if int(v.tickets) != 1 or not bool(v.timer_ready) or int(v.bonus) != 0:
		return r.fail("vừa mở Màn đặc biệt: %d vé (ngăn chờ %s, thưởng %d), design.md: có sẵn 1 vé ngăn chờ" % [
			int(v.tickets), str(v.timer_ready), int(v.bonus)])
	if not bool(r.game.s.special.get("invited", false)):
		return r.fail("popup mời đã tự mở mà chưa ghi là đã mời")
	var start := Scen.find_visible(invite, "StartButton") as Control
	if start == null:
		return r.fail("popup mời có vé mà không có nút Bắt đầu")
	await r.shot("sb_invite")
	r.step("[HP] thắng L%d về Home, popup mời tự mở, 1 vé" % (unlock - 1))
	var t0 := int(r.game.now())
	if not await r.tap(start, "Bắt đầu"):
		return r.fail("không bấm được Bắt đầu ở popup mời")
	if not await Scen.wait_for(r, func() -> bool: return r.popup_script("booster_unlocked.gd") != null, 20000,
			"booster_unlocked.gd"):
		return r.fail("lần đầu vào Màn đặc biệt mà không có hướng dẫn quả bom (%s)" % r.describe())
	await r.wait_sec(0.6)
	await r.shot("sb_guide")
	await r.tap(r.popup_script("booster_unlocked.gd") as Control, "hướng dẫn quả bom (chạm để tiếp tục)")
	if not await Scen.wait_for(r, func() -> bool: return _sp_playing(r), 15000):
		return r.fail("đóng hướng dẫn không vào chơi Màn đặc biệt (%s)" % r.describe())
	var s: Dictionary = r.game.s
	var lv: Control = r.level_screen()
	var timer := int(Config.SPECIAL.timer_sec)
	if int(r.game.special_view().tickets) != 0 or int(s.special.slot_at) != t0 + timer:
		return r.fail("Bắt đầu: còn %d vé, vé chờ lúc %d; mong đợi 0 vé, vé chờ lúc %d (+%d giây)" % [
			int(r.game.special_view().tickets), int(s.special.slot_at), t0 + timer, timer])
	if not bool(s.special.get("guide", false)):
		return r.fail("đã hiện hướng dẫn Màn đặc biệt mà chưa ghi là đã xem")
	var plan: Array = (lv.attempt.bombs as Array).duplicate(true)
	var want := SpecialBoard.bomb_count(SpecialBomb.wins(s))
	if plan.size() != want:
		return r.fail("Màn đặc biệt trận %d có %d bom, mong đợi %d" % [SpecialBomb.wins(s) + 1, plan.size(), want])
	await r.wait_sec(0.5)
	await r.shot("sb_level")
	r.step("[HP] vào Màn đặc biệt bàn %d: vé trừ lúc Bắt đầu, vé chờ kế sau %d giây, bom %s" % [SpecialBomb.board(s),
		timer, _plan_key(plan)])
	if not await _sb_boom(r):
		return false
	if not await _sb_no_ticket(r):
		return false
	if not await _sb_win(r, plan):
		return false
	return await Scen.verify_saved(r)


## Bom chưa đếm trước lần chạm hợp lệ đầu; đếm thì dừng khi có popup cài đặt; không chạm nữa thì nổ → popup "Bùm!" →
## X về Home. Không mất mạng, gold, level chính; bàn và số trận giữ nguyên.
static func _sb_boom(r) -> bool:
	var lv: Control = r.level_screen()
	var bombs: Node = lv.bombs
	var s: Dictionary = r.game.s
	var before := _snap(r)
	var board0 := SpecialBomb.board(s)
	var wins0 := SpecialBomb.wins(s)
	var first := str((bombs.call("live_ids") as Array)[0])
	var left0 := float(bombs.call("seconds_left", first))
	await r.wait_sec(1.0)
	if bool(bombs.get("started")) or float(bombs.call("seconds_left", first)) != left0:
		return r.fail("[EDGE] bom đếm trước lần chạm đầu, design.md: chỉ đếm từ lần chạm hợp lệ đầu tiên")
	var tap_id := ""
	for id in lv.board.block_ids():
		if lv.board.can_exit(str(id)) and not bool(bombs.call("has_bomb", str(id))):
			tap_id = str(id)
			break
	if tap_id == "":
		return r.fail("bàn Màn đặc biệt không có khối thoát được ngay")
	if not await r.tap_block(tap_id):
		return r.fail("không chạm được khối %s" % tap_id)
	if not await Scen.wait_for(r, func() -> bool: return bool(bombs.get("started")), 4000, "*"):
		return r.fail("[EDGE] chạm khối đầu tiên mà bom không bắt đầu đếm")
	var t1 := float(bombs.call("seconds_left", first))
	await r.wait_sec(1.0)
	var t2 := float(bombs.call("seconds_left", first))
	if t2 >= t1:
		return r.fail("bom không đếm sau lần chạm đầu (%.2f → %.2f giây)%s" % [t1, t2, _sb_env(lv)])
	r.step("[EDGE] bom đứng ở %.0f giây trước lần chạm đầu, đếm từ lần chạm khối %s (%.1f → %.1f)" % [left0, tap_id,
		t1, t2])
	await r.tap(lv.settings_button, "Cài đặt trong Màn đặc biệt")
	if not await Scen.wait_for(r, func() -> bool: return r.popup_script("popup_ingame_settings.gd") != null, 6000,
			"popup_ingame_settings.gd"):
		return r.fail("Cài đặt trong Màn đặc biệt không mở")
	var set_pop: Node = r.popup_script("popup_ingame_settings.gd")
	await r.wait_sec(0.5)
	if Scen.find_visible(set_pop, "RetryButton") != null:
		return r.fail("[NEG] cài đặt trong Màn đặc biệt có Chơi lại, design.md: ẩn Chơi lại")
	var paused := float(bombs.call("seconds_left", first))
	await r.wait_sec(1.5)
	if float(bombs.call("seconds_left", first)) != paused:
		return r.fail("[EDGE] bom vẫn đếm khi popup cài đặt đang mở (%.2f → %.2f)" % [paused,
			float(bombs.call("seconds_left", first))])
	await r.shot("sb_settings_paused")
	r.step("[EDGE] popup cài đặt: không có Chơi lại, bom dừng ở %.1f giây" % paused)
	var x := Scen.find_close(set_pop)
	if x == null:
		return r.fail("popup cài đặt trong màn không có nút đóng")
	await r.tap(x, "đóng Cài đặt")
	if not await Scen.wait_for(r, func() -> bool: return r.popup_script("popup_ingame_settings.gd") == null, 6000, "*"):
		return r.fail("không đóng được Cài đặt trong Màn đặc biệt")
	var urgent := str((bombs.call("live_ids") as Array)[0])
	var left := float(bombs.call("seconds_left", urgent))
	var ms := int((left + float(Config.SPECIAL.boom_popup_sec)) / maxf(Engine.time_scale, 0.01) * 1000.0) + 15000
	r.step("không chạm nữa, đợi bom %s nổ (còn %.1f giây)" % [urgent, left])
	if not await _sb_wait_boom(r, lv, ms):
		return false
	var end_pop: Node = r.popup_script("popup_special_end.gd")
	if str(end_pop.get("_mode")) != "boom":
		return r.fail("[EDGE] bom nổ mà popup thua là \"%s\", mong đợi Bùm!" % str(end_pop.get("_mode")))
	await r.wait_sec(0.6)
	await r.shot("sb_boom")
	var changed := _changed(r, before, ["coins", "lives", "level", "lb", "weekly"])
	if changed != "":
		return r.fail("[EDGE] bom nổ mà đổi %s, design.md: thua không mất mạng, không gold, không level chính" % changed)
	if SpecialBomb.board(s) != board0 or SpecialBomb.wins(s) != wins0:
		return r.fail("[EDGE] thua mà bàn %d → %d, trận %d → %d, design.md: thua thì lần sau gặp lại đúng bàn" % [
			board0, SpecialBomb.board(s), wins0, SpecialBomb.wins(s)])
	var ev := _last_event(r, "sp_end")
	if not ev.is_empty() and str((ev.params as Dictionary).get("reason", "")) != "bomb":
		return r.fail("analytics sp_end ghi reason %s, mong đợi bomb" % str(ev.params.get("reason")))
	r.step("[EDGE] bom nổ: popup Bùm!, mạng, gold, level chính, bàn %d giữ nguyên" % board0)
	var close := Scen.find_close(end_pop)
	if close == null:
		return r.fail("popup Bùm! không có nút X")
	await r.tap(close, "X ở popup Bùm!")
	if not await Scen.wait_for(r, func() -> bool: return r.screen_name() == "home" and r.main.curtain == null, 15000):
		return r.fail("X ở popup Bùm! không về Home (%s)" % r.describe())
	r.step("X ở popup Bùm! về Home")
	return true


## Hết vé: icon không có chấm, chạm mở popup chờ (OK). Rồi giờ máy tới mốc vé chờ − 1 giây (0 vé) và đúng mốc (1 vé).
static func _sb_no_ticket(r) -> bool:
	await Scen.settle_all(r)
	var home: Node = r.main.current_screen
	var bomb_btn := Scen.find_visible(home, "BombButton") as Control
	if bomb_btn == null:
		return r.fail("Màn đặc biệt đã mở mà Home không có icon quả bom")
	if int(r.game.special_view().tickets) != 0:
		return r.fail("đã dùng vé duy nhất mà còn %d vé" % int(r.game.special_view().tickets))
	if Scen.find_visible(home, "BombBadge") != null:
		return r.fail("[NEG] hết vé mà icon quả bom vẫn có chấm số vé")
	await r.tap(bomb_btn, "icon Màn đặc biệt (hết vé)")
	if not await Scen.wait_for(r, func() -> bool: return r.popup_script("popup_special.gd") != null, 6000,
			"popup_special.gd"):
		return r.fail("chạm icon quả bom không mở popup")
	var pop: Node = r.popup_script("popup_special.gd")
	await r.wait_sec(0.5)
	if Scen.find_visible(pop, "StartButton") != null or Scen.find_visible(pop, "OkButton") == null:
		return r.fail("[NEG] hết vé mà popup có nút Bắt đầu, design.md: popup báo thời gian chờ, nút OK")
	var tl := pop.get("tickets_label") as Label
	await r.shot("sb_no_ticket")
	r.step("[NEG] hết vé: popup báo \"%s\", nút OK" % (tl.text if tl != null else ""))
	if not await Scen.tap_named(r, "OkButton", pop):
		return false
	if not await Scen.wait_for(r, func() -> bool: return r.popup_script("popup_special.gd") == null, 6000, "*"):
		return r.fail("OK không đóng popup hết vé")
	await r.wait_sec(0.5)
	if r.screen_name() != "home" or int(r.game.special_view().tickets) != 0:
		return r.fail("[NEG] OK ở popup hết vé mà vào màn hoặc có vé (%s)" % r.describe())
	var slot := int(r.game.s.special.slot_at)
	r.game.test_now = slot - 1
	if int(r.game.special_view().tickets) != 0:
		return r.fail("[EDGE] còn 1 giây tới mốc vé chờ mà đã có vé")
	r.game.test_now = slot
	var v: Dictionary = r.game.special_view()
	if int(v.tickets) != 1 or not bool(v.timer_ready):
		return r.fail("[EDGE] đủ %d giây sau lúc dùng vé mà ngăn chờ chưa có vé (%d vé)" % [
			int(Config.SPECIAL.timer_sec), int(v.tickets)])
	if not await Scen.wait_for(r, func() -> bool:
			return Scen.find_visible(r.main.current_screen, "BombBadge") != null, 6000):
		return r.fail("[EDGE] có vé lại mà icon quả bom không có chấm số vé")
	await r.shot("sb_ticket_back")
	r.step("[EDGE] vé chờ: mốc − 1 giây 0 vé; đúng mốc (%d giây sau lúc dùng) 1 vé, icon có chấm" % [
		int(Config.SPECIAL.timer_sec)])
	return true


## Vào lại từ icon ở Home với vé vừa hồi: đúng bàn và bom cũ, không hướng dẫn lần hai; thắng; x2 miễn phí một lần;
## Trang chủ về Home.
static func _sb_win(r, plan: Array) -> bool:
	var bomb_btn := Scen.find_visible(r.main.current_screen, "BombButton") as Control
	if bomb_btn == null:
		return r.fail("Home không có icon quả bom")
	await r.tap(bomb_btn, "icon Màn đặc biệt (có vé)")
	if not await Scen.wait_for(r, func() -> bool: return r.popup_script("popup_special.gd") != null, 6000,
			"popup_special.gd"):
		return r.fail("chạm icon quả bom không mở popup mời")
	await r.wait_sec(0.5)
	var start := Scen.find_visible(r.popup_script("popup_special.gd"), "StartButton") as Control
	if start == null:
		return r.fail("có vé mà popup mời không có nút Bắt đầu")
	var s: Dictionary = r.game.s
	var before := _snap(r)
	var board0 := SpecialBomb.board(s)
	var wins0 := SpecialBomb.wins(s)
	if not await r.tap(start, "Bắt đầu"):
		return r.fail("không bấm được Bắt đầu")
	var seen := {"guide": false}
	if not await Scen.wait_for(r, func() -> bool:
			if r.popup_script("booster_unlocked.gd") != null:
				seen["guide"] = true
			return bool(seen["guide"]) or _sp_playing(r), 20000, "booster_unlocked.gd"):
		return r.fail("Bắt đầu không vào chơi Màn đặc biệt (%s)" % r.describe())
	if bool(seen["guide"]):
		return r.fail("[NEG] hướng dẫn Màn đặc biệt hiện lần hai, design.md: một lần")
	var lv: Control = r.level_screen()
	var plan2: Array = lv.attempt.bombs
	if _plan_key(plan2) != _plan_key(plan) or int(lv.attempt.level) != board0:
		return r.fail("[EDGE] thua rồi vào lại mà bàn %d, bom %s; mong đợi bàn %d, bom %s" % [int(lv.attempt.level),
			_plan_key(plan2), board0, _plan_key(plan)])
	r.step("[EDGE] vào lại sau khi thua: đúng bàn %d và bom %s, không hướng dẫn lần hai" % [board0, _plan_key(plan)])
	if not await Scen.win_level(r):
		return false
	if not await Scen.wait_for(r, func() -> bool: return r.popup_node("ContinueButton") != null, 20000,
			"ContinueButton"):
		return r.fail("thắng Màn đặc biệt mà không có thẻ thắng (%s)" % r.describe())
	var kind := str(r.game.get("_sp_reward"))
	var kinds: Array = Config.SPECIAL.reward_kinds
	var gained := _inv_gain(before.inv, s.inv)
	if not kinds.has(kind) or gained.size() != 1 or int(gained.get(kind, 0)) != 1:
		return r.fail("thắng Màn đặc biệt: kho đổi %s, thưởng %s; mong đợi +1 một booster trong SPECIAL.reward_kinds" % [
			JSON.stringify(gained), kind])
	if SpecialBomb.wins(s) != wins0 + 1 or SpecialBomb.board(s) != board0 + 1:
		return r.fail("thắng Màn đặc biệt mà trận %d → %d, bàn %d → %d" % [wins0, SpecialBomb.wins(s), board0,
			SpecialBomb.board(s)])
	var changed := _changed(r, before, ["coins", "lives", "level", "lb", "weekly"])
	if changed != "":
		return r.fail("thắng Màn đặc biệt mà đổi %s, design.md: không gold, không level chính, không Weekly Pass, Leaderboard" % changed)
	if r.popup_node("LbRow") != null:
		return r.fail("thẻ thắng Màn đặc biệt có thẻ bảng xếp hạng, design.md: không có")
	await r.wait_sec(1.0)
	await r.shot("sb_win")
	r.step("[HP] thắng Màn đặc biệt: +1 %s, trận %d → %d, bàn %d → %d; gold, level chính không đổi" % [kind, wins0,
		wins0 + 1, board0, board0 + 1])
	var x2 := r.popup_node("X2Button") as Control
	if x2 == null or not x2.is_visible_in_tree():
		return r.fail("thẻ thắng Màn đặc biệt không có nút x2")
	if bool(s.meta.get("special_x2_used", false)):
		return r.fail("save chưa dùng x2 Màn đặc biệt mà đã ghi đã dùng")
	var calls := (r.plat.ads.calls as Array).size()
	var have := int(s.inv[kind])
	if not await r.tap(x2, "x2 (lần đầu miễn phí)"):
		return r.fail("không bấm được x2 ở thẻ thắng Màn đặc biệt")
	if not await Scen.wait_for(r, func() -> bool: return int(s.inv[kind]) == have + 1, 6000, "*"):
		return r.fail("x2 Màn đặc biệt không thêm 1 %s (%d → %d)" % [kind, have, int(s.inv[kind])])
	if (r.plat.ads.calls as Array).size() != calls:
		return r.fail("x2 Màn đặc biệt lần đầu vẫn gọi quảng cáo, design.md: lần đầu miễn phí")
	if not bool(s.meta.get("special_x2_used", false)):
		return r.fail("đã lấy x2 Màn đặc biệt miễn phí mà chưa ghi đã dùng")
	await r.wait_sec(0.6)
	await r.shot("sb_x2")
	r.step("[HP] x2 lần đầu miễn phí, không quảng cáo: %s %d → %d" % [kind, have, have + 1])
	x2 = r.popup_node("X2Button") as Control
	if x2 != null and x2.is_visible_in_tree():
		await r.tap(x2, "x2 lần nữa")
		await r.wait_sec(1.0)
	if int(s.inv[kind]) != have + 1:
		return r.fail("[EDGE] bấm x2 lần nữa mà %s %d → %d, design.md: x2 một lần mỗi trận thắng" % [kind, have + 1,
			int(s.inv[kind])])
	r.step("[EDGE] bấm x2 lần nữa không thêm gì")
	calls = (r.plat.ads.calls as Array).size()
	if not await _tap_continue(r, "thẻ thắng Màn đặc biệt (Trang chủ)"):
		return false
	if not await Scen.wait_for(r, func() -> bool:
			return r.screen_name() == "home" and r.level_screen() == null and r.main.curtain == null, 20000):
		return r.fail("Trang chủ ở thẻ thắng Màn đặc biệt không về Home (%s)" % r.describe())
	for c in (r.plat.ads.calls as Array).slice(calls):
		if str((c as Dictionary).get("kind", "")) == "inter":
			return r.fail("đã lấy x2 mà Trang chủ vẫn hiện interstitial, design.md: đã lấy x2 thì không")
	await Scen.settle_all(r)
	await r.shot("sb_home_end")
	r.step("[HP] Trang chủ về Home, không interstitial (đã lấy x2)")
	return true


## Đợi popup "Bùm!" tối đa `ms` (giờ thật) tính lúc app không ở nền. Bom đúng design dừng khi app ở nền (level.gd
## _app_paused, theo NOTIFICATION_APPLICATION_FOCUS_OUT): chạy `window` trên desktop, cửa sổ smoke cho chuột đi xuyên
## nên một cú bấm của người ngồi máy làm nó mất focus. Lúc đó không trừ thời gian đợi; mất focus quá
## SB_UNFOCUSED_MS thì dừng với lý do môi trường, không phải lỗi game.
static func _sb_wait_boom(r, lv: Control, ms: int) -> bool:
	var budget := ms
	var unfocused := 0
	var last := Time.get_ticks_msec()
	var warned := false
	while r.popup_script("popup_special_end.gd") == null:
		if not r.failed_reason.is_empty():
			return false
		var now_ms := Time.get_ticks_msec()
		if is_instance_valid(lv) and bool(lv.get("_app_paused")):
			unfocused += now_ms - last
			if not warned:
				warned = true
				print("SMOKE WARN cửa sổ game mất focus: bom dừng (đúng design.md, app ở nền), đợi focus quay lại")
			if unfocused > SB_UNFOCUSED_MS:
				return r.fail("không kiểm được bom nổ: cửa sổ game mất focus %.0f giây%s" % [unfocused / 1000.0, _sb_env(lv)])
		else:
			budget -= now_ms - last
			if budget <= 0:
				return r.fail("[EDGE] bom về 0 mà không có popup Bùm! (%s)%s" % [r.describe(), _sb_env(lv)])
		last = now_ms
		await Scen.settle(r, "popup_special_end.gd")
		await r.wait_frames(1)
	return true


## Ghi chú môi trường cho lý do lỗi: level đang coi app ở nền (cửa sổ mất focus) thì bom dừng là đúng design.
static func _sb_env(lv: Control) -> String:
	if is_instance_valid(lv) and bool(lv.get("_app_paused")):
		return "; app đang ở nền (cửa sổ mất focus), bom dừng là đúng design.md, không phải lỗi game: chạy lại headless hoặc giữ focus cửa sổ"
	return ""


static func _sp_playing(r) -> bool:
	var lv: Control = r.level_screen()
	return lv != null and bool(lv.get("_special")) and str(lv.state) == "playing"


## "id:giây, ..." của kế hoạch bom (SpecialBoard.bomb_plan) để so hai lần vào cùng bàn.
static func _plan_key(plan: Array) -> String:
	var parts: PackedStringArray = []
	for b in plan:
		parts.append("%s:%ds" % [str((b as Dictionary).get("id", "")), int((b as Dictionary).get("seconds", 0))])
	return ", ".join(parts)


# ================================================================ dùng chung

## Save ở level chính `level` như người chơi đã qua các level trước (Saves._at_level: quà booster, giới thiệu cơ chế),
## đủ gold và booster; đã thấy lời mời và hướng dẫn Màn đặc biệt, hướng dẫn Road Trip, hướng dẫn Weekly Pass. Kịch bản
## tự bật lại cờ nó cần kiểm.
static func _prep(g: Node, level: int) -> void:
	Saves._at_level(g, level, false)
	g.s.coins = 3000
	for k in BOOSTERS:
		g.s.inv[k] = 3
	g.s.special["invited"] = true
	g.s.special["guide"] = true
	g.s.road_trip["guide"] = true
	g.s.weekly["tut_seen"] = true


## Số người chơi để ý, để so trước và sau một lượt chơi.
static func _snap(r) -> Dictionary:
	var s: Dictionary = r.game.s
	return {"coins": int(s.coins), "lives": int(s.lives["count"]), "level": int(s.level),
		"lb": int((s.lb as Dictionary).get("points", 0)), "weekly": int((s.weekly as Dictionary).get("points", 0)),
		"inv": (s.inv as Dictionary).duplicate()}


## Mô tả các khoá trong `keys` đã đổi so với `before` (_snap); "" khi không đổi.
static func _changed(r, before: Dictionary, keys: Array) -> String:
	var after := _snap(r)
	var out: PackedStringArray = []
	for k in keys:
		if after[k] != before[k]:
			out.append("%s %s → %s" % [k, str(before[k]), str(after[k])])
	return ", ".join(out)


## "" khi gold và booster tăng đúng `reward` ({coins, items}) so với `before` (_snap); không thì mô tả chỗ lệch.
static func _reward_diff(r, before: Dictionary, reward: Dictionary) -> String:
	var s: Dictionary = r.game.s
	var out: PackedStringArray = []
	var coins := int(s.coins) - int(before.coins)
	if coins != int(reward.get("coins", 0)):
		out.append("gold +%d, mong đợi +%d" % [coins, int(reward.get("coins", 0))])
	var items: Dictionary = reward.get("items", {})
	for k in BOOSTERS:
		var got := int(s.inv[k]) - int(before.inv[k])
		if got != int(items.get(k, 0)):
			out.append("%s +%d, mong đợi +%d" % [k, got, int(items.get(k, 0))])
	return ", ".join(out)


## Booster đổi giữa hai kho: {loại: chênh} (bỏ loại không đổi).
static func _inv_gain(before: Dictionary, after: Dictionary) -> Dictionary:
	var out := {}
	for k in BOOSTERS:
		var d := int(after.get(k, 0)) - int(before.get(k, 0))
		if d != 0:
			out[k] = d
	return out


## Bấm Tiếp tục (hoặc Trang chủ của thẻ Màn đặc biệt, cùng node) ở thẻ thắng đang mở.
static func _tap_continue(r, what: String) -> bool:
	var cont := r.popup_node("ContinueButton") as Control
	if cont == null:
		return r.fail("%s: không có nút Tiếp tục" % what)
	var hit: bool = await r.tap(cont, "Tiếp tục (%s)" % what)
	return hit or r.fail("%s: không bấm được Tiếp tục" % what)


## Sự kiện analytics cuối cùng tên `event_name` khi Platform dùng analytics giả (có danh sách sự kiện); {} khi không
## có hoặc analytics thật (máy Android không dùng mock).
static func _last_event(r, event_name: String) -> Dictionary:
	var an: Object = r.plat.an
	if an == null or not an.has_method("named"):
		return {}
	var list: Array = an.call("named", event_name)
	return list.back() if not list.is_empty() else {}
