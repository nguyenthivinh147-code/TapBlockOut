extends RefCounted
## Wireframe screens wired to logic on 2026-11-09 (docs/UI_FIGMA.md): Rate us, first-time intro, Helper Pack rescue,
## update check, Remove Ads, Weekly Upsell, ad notices.
const T := preload("res://tests/t.gd")
const MockIap := preload("res://src/platform/mock_iap.gd")
const Config := preload("res://src/config.gd")
const AppVersion := preload("res://src/meta/app_version.gd")

const DIR := "user://test_ui_wired"
const NOW := 1800000000


## Mock ads that never finish loading (the stock mock loads at once).
class NoLoadAds extends "res://src/platform/mock_ads.gd":
	func load_ads() -> void:
		pass


class FakePlugin extends RefCounted:
	var reviews: int = 0

	func review() -> void:
		reviews += 1


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _plat() -> Node:
	return _tree().root.get_node("Platform")


func _g(level: int = 1) -> Node:
	DirAccess.make_dir_recursive_absolute(DIR)
	var g: Node = _tree().root.get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	g.test_now = NOW
	g.test_tz = 0
	_plat().ads.set_ready(true, true)
	_plat().iap = MockIap.new()
	g.s.level = level
	for k in ["hint", "move", "smash"]:
		g.s.gifted[k] = true
	return g


func _mount_level() -> Control:
	var lv := (load("res://scenes/level.tscn") as PackedScene).instantiate() as Control
	_tree().root.add_child(lv)
	lv.setup({})
	return lv


func _open(scene: String, args: Dictionary = {}) -> Control:
	var node := (load("res://scenes/%s.tscn" % scene) as PackedScene).instantiate() as Control
	_tree().root.add_child(node)
	node.call("setup", args)
	return node


func _wait_until(cond: Callable, ms: int = 8000) -> bool:
	var deadline := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await _tree().process_frame
	return cond.call()


## The popup of `scene` open over the level (its own layer when run alone), or null.
func _popup(lv: Control, scene: String) -> Control:
	for c in lv.get_node("LocalPopups").get_children():
		if not c.is_queued_for_deletion() and c.scene_file_path == "res://scenes/%s.tscn" % scene:
			return c
	return null


func _solve(lv: Control) -> void:
	var guard := 0
	while lv.board.remaining_count() > 0 and guard < 400:
		guard += 1
		var id: String = lv.board.hint()
		if id == "":
			break
		lv.call("_on_block_tapped", id)
		await _tree().process_frame


func test_rate_popup_before_store_review(t: T) -> void:
	var g := _g(10)
	g.s.meta.rated = false
	var plugin := FakePlugin.new()
	_plat()._plugin = plugin
	var lv := _mount_level()
	t.ok(await _wait_until(func() -> bool: return lv.state == "playing"), "vào chơi")
	await _solve(lv)
	t.ok(await _wait_until(func() -> bool: return lv.find_child("ContinueButton", true, false) != null), "thẻ thắng")
	(lv.find_child("ContinueButton", true, false) as Button).pressed.emit()
	t.ok(await _wait_until(func() -> bool:
		# Offers (starter pack from L11) come first: say later.
		for c in lv.get_node("LocalPopups").get_children():
			if not c.is_queued_for_deletion() and "later_button" in c and c.later_button != null:
				(c.later_button as Button).pressed.emit()
		return _popup(lv, "popup_rate") != null), "popup Rate us sau thẻ thắng")
	t.eq(plugin.reviews, 0, "chưa mở hộp đánh giá của store")
	_popup(lv, "popup_rate").call("_send", "rate")
	t.ok(await _wait_until(func() -> bool: return plugin.reviews == 1), "Có thì mở hộp đánh giá")
	t.ok(bool(g.s.meta.rated), "chỉ hỏi một lần")
	_plat()._plugin = null
	lv.free()


func test_intro_before_first_l1(t: T) -> void:
	var g := _g(1)
	g.s.meta.intro_seen = false
	var lv := _mount_level()
	t.ok(await _wait_until(func() -> bool: return _popup(lv, "tutorial_intro") != null), "hướng dẫn lần đầu")
	t.eq(lv.state, "dialog", "chưa chơi")
	var ev := InputEventMouseButton.new()
	ev.pressed = true
	ev.button_index = MOUSE_BUTTON_LEFT
	_popup(lv, "tutorial_intro").call("_gui_input", ev)
	t.ok(await _wait_until(func() -> bool: return lv.state == "playing"), "chạm thì vào chơi")
	t.ok(bool(g.s.meta.intro_seen), "ghi đã xem")
	lv.free()
	lv = _mount_level()
	t.ok(await _wait_until(func() -> bool: return lv.state == "playing"), "lần sau vào chơi ngay")
	t.eq(_popup(lv, "tutorial_intro"), null, "không hiện lại")
	lv.free()


func test_helper_pack_due(t: T) -> void:
	var g := _g(25)
	var attempt: Dictionary = g.start_attempt()
	var offer: Dictionary = g.rescue_offer(attempt)
	g.s.fail_streak = {"level": 25, "count": 1}
	t.ok(not g.helper_pack_due(attempt, offer), "lần hết MOVES thứ 2: popup thường")
	g.s.fail_streak = {"level": 25, "count": 2}
	t.ok(g.helper_pack_due(attempt, offer), "lần thứ 3 liên tiếp: kèm Helper Pack")
	g.s.inv.move = 1
	t.ok(not g.helper_pack_due(attempt, g.rescue_offer(attempt)), "còn +3 Move trong kho: popup thường")
	g.s.inv.move = 0
	g.s.fail_streak = {"level": 24, "count": 5}
	t.ok(not g.helper_pack_due(attempt, offer), "chuỗi thua ở level khác")


func test_helper_pack_buy_rescues(t: T) -> void:
	var g := _g(25)
	var attempt: Dictionary = g.start_attempt()
	var moves0: int = attempt.board.moves_left()
	var offer: Dictionary = g.rescue_offer(attempt).duplicate()
	offer["attempt"] = attempt
	var p := _open("popup_helper_pack", offer)
	var got: Array = []
	p.closed.connect(func(r: Variant) -> void: got.append(r))
	(p.find_child("BuyPackButton", true, false) as Button).pressed.emit()
	t.ok(await _wait_until(func() -> bool: return not got.is_empty()), "mua gói thì đóng")
	t.eq(got[0], "inventory", "cứu bằng +3 Move của gói")
	t.eq(attempt.board.moves_left(), moves0 + int(Config.ECON.rescue_moves), "+3 MOVES")
	t.eq(int(g.s.inv.hint), 2, "phần còn lại vào kho: 2 Gợi ý")
	t.eq(int(g.s.inv.smash), 1, "1 Phá khối")
	p.free()


func test_update_state(t: T) -> void:
	var g := _g()
	t.ok(AppVersion.older("0.1.0", "0.2.0"), "0.1.0 < 0.2.0")
	t.ok(AppVersion.older("1.2.9", "1.2.10"), "so từng số")
	t.ok(not AppVersion.older("1.0", "1.0.0"), "bằng nhau")
	t.ok(not AppVersion.older("", "1.0"), "thiếu phiên bản thì không cũ")
	t.eq(g.update_state(), "", "mặc định tắt")
	Config.CONTENT["latest_version"] = "99.0.0"
	t.eq(g.update_state(), "optional", "có bản mới")
	g.mark_update_asked()
	t.eq(g.update_state(), "", "Để sau: một lần mỗi lần mở game")
	Config.CONTENT["min_version"] = "99.0.0"
	t.eq(g.update_state(), "force", "dưới min: bắt buộc")
	var p := _open("popup_update", {"view": {"force": true}})
	t.ok(not (p.find_child("LaterButton", true, false) as Control).visible, "bắt buộc: không có Để sau")
	t.ok(p.call("blocks_back"), "Back không đóng")
	p.free()
	Config.reset()


func test_remove_ads_bundle(t: T) -> void:
	var g := _g(20)
	var coins := int(g.s.coins)
	var p := _open("popup_remove_ads")
	var got: Array = []
	p.closed.connect(func(r: Variant) -> void: got.append(r))
	(p.ui.button("Panel_Pack/Shop_RemoveAdsBundle/Button_Purchase") as Button).pressed.emit()
	t.ok(await _wait_until(func() -> bool: return not got.is_empty()), "mua xong thì đóng")
	t.eq(got[0], {"action": "bought"}, "kết quả")
	t.ok(bool(g.s.no_ads), "bỏ quảng cáo")
	t.eq(int(g.s.coins), coins + int(Config.SKUS.remove_ads_bundle.gold), "cộng gold của bundle")
	for k in ["hint", "move", "smash"]:
		t.eq(int(g.s.inv[k]), int(Config.SKUS.remove_ads_bundle.inv[k]), "+3 booster " + k)
	for c in _tree().root.get_children():
		if c.scene_file_path == "res://scenes/popup_reward.tscn":
			c.queue_free()
	p.free()


func test_weekly_upsell_once_per_season(t: T) -> void:
	var g := _g(60)
	g.weekly_refresh()
	if g.weekly_state() != "active":
		t.ok(true, "Weekly Pass chưa mở ở cấu hình này")
		return
	t.ok(not g.weekly_take_upsell(), "chưa xem tutorial: không mời")
	g.s.weekly.tut_seen = true
	g.s.weekly.points = 3
	t.ok(g.weekly_take_upsell(), "mời một lần")
	t.ok(not g.weekly_take_upsell(), "không mời lại trong mùa")


func test_ad_unavailable_notice(t: T) -> void:
	var g := _g(5)
	var stock: Variant = _plat().ads
	_plat().ads = NoLoadAds.new()
	_plat().ads.set_ready(false, false)
	Config.ADS["rv_wait_sec"] = 0.2
	var waits: Array = []
	var notices: Array = []
	g.ad_wait.connect(func(on: bool) -> void: waits.append(on))
	g.notice.connect(func(k: String) -> void: notices.append(k))
	t.ok(not await g.watch("shop_coins"), "không có video")
	t.eq(waits, [true, false], "lớp chờ video bật rồi tắt")
	t.eq(notices, ["not_ready"], "báo không có video")
	g.test_online = 0
	notices.clear()
	t.ok(not await g.watch("shop_coins"), "mất mạng")
	t.eq(notices, ["offline"], "báo mất mạng")
	t.ok(g.notice_shown(g.last_ad_reason), "màn gọi không báo thêm")
	_plat().ads = stock
	Config.reset()
