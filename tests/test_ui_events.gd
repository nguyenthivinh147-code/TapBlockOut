extends RefCounted
## Layer Weekly Pass, layer Chain Offer, nút sự kiện ở Home.
const T := preload("res://tests/t.gd")
const MockIap := preload("res://src/platform/mock_iap.gd")

const DIR := "user://test_ui_events"
const MON := 1699833600  # thứ Hai 00:00 UTC
const D := 86400


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _game(level: int) -> Node:
	var g: Node = _root().get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	g.test_tz = 0
	g.test_now = MON + 2 * D
	g.s.level = level
	_root().get_node("Platform").iap = MockIap.new()
	return g


func _open(path: String) -> Control:
	var node := (load(path) as PackedScene).instantiate() as Control
	_root().add_child(node)
	node.setup({})
	return node


func test_weekly_locked_and_waiting(t: T) -> void:
	var g := _game(5)
	var node := _open("res://scenes/weekly_pass.tscn")
	t.eq(node.main_buttons.size(), 0, "Locked không có Main Tree")
	node.queue_free()
	g.s.level = 30
	g.test_now = MON + 3 * 3600
	var w := _open("res://scenes/weekly_pass.tscn")
	t.eq(w.main_buttons.size(), 0, "Waiting không có Main Tree")
	t.ok(w.close_button != null, "có nút đóng")
	w.queue_free()


func test_weekly_active_claim_and_buy(t: T) -> void:
	var g := _game(30)
	g.weekly_refresh()
	g.s.weekly.points = 8
	g.s.weekly.tut_seen = true
	var node := _open("res://scenes/weekly_pass.tscn")
	t.eq(node.main_buttons.size(), 22, "mốc khởi đầu + 10 mốc, mỗi mốc free + VIP")
	t.eq(node.main_buttons["free_0"].disabled, false, "free mốc khởi đầu nhận được")
	t.eq(node.main_buttons["free_3"].disabled, true, "mốc 15 key chưa đủ điểm")
	t.eq(node.main_buttons["vip_0"].disabled, true, "VIP khoá")
	# Prefab cards keep their Unity size; u_button.gd grows only the hit area.
	t.ok(node.main_buttons["free_0"].hit_size().y >= 96, "nút đủ lớn")
	var c0 := int(g.s.coins)
	node.main_buttons["free_0"].pressed.emit()
	t.eq(int(g.s.coins), c0, "mốc khởi đầu không cộng gold")
	t.eq(g.lives_view().infinite, true, "nhận mốc khởi đầu: mạng vô hạn")
	t.eq(node.main_buttons["free_0"].disabled, true, "đã nhận thì khoá")
	t.ok(node.buy_vip_button != null, "có nút mua VIP")
	node.buy_vip_button.pressed.emit()
	await (Engine.get_main_loop() as SceneTree).process_frame
	await (Engine.get_main_loop() as SceneTree).process_frame
	t.eq(bool(g.s.weekly.vip), true, "đã mua VIP")
	t.ok(node.buy_vip_button == null, "ẩn nút mua sau khi có VIP")
	t.eq(node.main_buttons["vip_0"].disabled, false, "VIP mở khoá")
	t.eq(node.claim_all_button.disabled, false, "còn thưởng để nhận hết")
	node.claim_all_button.pressed.emit()
	t.eq(node.claim_all_button.disabled, true, "nhận hết")
	node.queue_free()


func _frame() -> void:
	await (Engine.get_main_loop() as SceneTree).process_frame


## Chờ overlay tutorial xong chuyển bước (tween thu/phóng bong bóng + một frame bố cục).
func _settle(ov: Control) -> void:
	var guard := 0
	while is_instance_valid(ov) and ov.busy and guard < 300:
		await _frame()
		guard += 1


func _wait(sec: float) -> void:
	await (Engine.get_main_loop() as SceneTree).create_timer(sec).timeout


func test_weekly_progress_row_and_howto(t: T) -> void:
	var g := _game(30)
	g.weekly_refresh()
	g.s.weekly.points = 1
	g.s.weekly.tut_seen = true
	var node := _open("res://scenes/weekly_pass.tscn")
	t.ok(node.progress_row != null, "có hàng tiến độ")
	t.ok(node.info_button != null and node.key_button != null, "có nút i và chìa")
	var bar := node.progress_row.find_child("ProgressBar", true, false) as ProgressBar
	t.near(bar.value, 1.0 / 3.0, 0.001, "thanh tới mốc 3 key")
	t.eq(node.howto, null, "chưa mở popup")
	node.info_button.pressed.emit()
	t.ok(node.howto != null, "nút i mở popup cách kiếm thưởng")
	t.eq(node.howto.rows.size(), 3, "3 hàng key theo độ khó")
	var first: Control = node.howto
	node.key_button.pressed.emit()
	t.ok(node.howto == first, "mở lần nữa vẫn là popup đó")
	node.howto.ok_button.pressed.emit()
	t.eq(node.howto, null, "OK đóng popup")
	node.queue_free()


func test_weekly_tutorial_flow(t: T) -> void:
	var g := _game(30)
	g.weekly_refresh()
	var node := _open("res://scenes/weekly_pass.tscn")
	t.eq(g.weekly_tutorial_seen(), false, "chưa xem tutorial")
	t.ok(node.start_tutorial(), "bắt đầu tutorial")
	t.eq(node.start_tutorial(), false, "đang chạy thì không bắt đầu lại")
	var ov: Control = node.tutorial
	await _settle(ov)
	t.eq(ov.index, 0, "bước 1")
	t.eq(ov.label.text, node.tr("weekly_tut_free_claim"), "bước 1: nhận thưởng đầu tiên")
	var hole1: Rect2 = ov.hole_rect()
	var free_rect: Rect2 = node.main_buttons["free_0"].get_global_rect()
	t.ok(hole1.size.x >= free_rect.size.x and hole1.size.y >= free_rect.size.y, "lỗ bao quanh thưởng free")
	t.ok(ov.bubble.visible and ov.bubble.scale.x > 0.99, "bong bóng đã hiện")
	ov.advance()
	await _settle(ov)
	t.eq(ov.index, 1, "bước 2")
	t.eq(ov.label.text, node.tr("weekly_tut_vip"), "bước 2: thưởng VIP")
	t.ok(ov.hole_rect().position.x > hole1.position.x, "lỗ chuyển sang cột VIP")
	ov.advance()
	await _settle(ov)
	t.eq(ov.index, 2, "bước 3")
	t.eq(ov.label.text, node.tr("weekly_tut_progress"), "bước 3: thanh tiến độ")
	t.eq(g.weekly_tutorial_seen(), false, "chưa xong thì chưa lưu cờ")
	ov.advance()
	await _frame()
	t.eq(g.weekly_tutorial_seen(), true, "xong bước cuối: lưu cờ")
	t.eq(node.tutorial, null, "overlay đã gỡ")
	t.ok(node.howto != null, "mở popup cách kiếm thưởng")
	node.queue_free()


func test_weekly_tutorial_ignores_tap_while_busy_and_aborts_on_rebuild(t: T) -> void:
	var g := _game(30)
	g.weekly_refresh()
	var node := _open("res://scenes/weekly_pass.tscn")
	node.start_tutorial()
	var ov: Control = node.tutorial
	ov.advance()  # bước 1 chưa hiện xong: bỏ qua
	await _settle(ov)
	t.eq(ov.index, 0, "chạm khi đang chuyển bước bị bỏ qua")
	node._rebuild()  # layer dựng lại: target cũ mất
	await _frame()
	t.eq(node.tutorial, null, "overlay bị gỡ")
	t.eq(g.weekly_tutorial_seen(), false, "bỏ giữa chừng không tính là đã xem")
	node.queue_free()


func test_weekly_tutorial_auto_start_once(t: T) -> void:
	var g := _game(30)
	g.weekly_refresh()
	var node := _open("res://scenes/weekly_pass.tscn")
	t.eq(node.tutorial, null, "chưa chạy ngay khi mở (chờ popup_in)")
	await _wait(0.6)
	t.ok(node.tutorial != null, "lần đầu mở: tự chạy tutorial")
	node.queue_free()
	g.s.weekly.tut_seen = true
	var seen := _open("res://scenes/weekly_pass.tscn")
	await _wait(0.6)
	t.eq(seen.tutorial, null, "đã xem rồi thì không chạy")
	t.eq(seen.start_tutorial(), true, "vẫn gọi tay được")
	seen.queue_free()


func test_weekly_tutorial_not_in_waiting(t: T) -> void:
	var g := _game(30)
	g.test_now = MON + 3 * 3600
	var node := _open("res://scenes/weekly_pass.tscn")
	t.eq(node.start_tutorial(), false, "Waiting không có tutorial")
	node.queue_free()


func test_weekly_end_popup(t: T) -> void:
	var g := _game(30)
	g.weekly_refresh()
	g.s.weekly.points = 4
	g.test_now = MON + 9 * D
	var node := _open("res://scenes/weekly_pass.tscn")
	t.ok(not node.end_info.is_empty(), "hiện popup cuối mùa")
	t.eq(bool(node.end_info.vip), false, "người không VIP")
	t.eq(node.main_buttons.size(), 0, "popup cuối mùa che Main Tree")
	node.queue_free()


func test_chain_layer(t: T) -> void:
	var g := _game(24)
	g.s.chain = {"active": true, "id": "chain_a", "step": 0, "expires": g.test_now + D,
		"cooldown_until": 0, "shown": true, "rotation": 1}
	var node := _open("res://scenes/chain_offer.tscn")
	t.eq(node.node_states, ["claimable", "locked", "locked", "locked", "locked", "locked"], "cửa sổ 6 bước")
	var title: Control = node.ui.node(node.TITLE_IMAGE)
	t.eq((title.get("tex") as Texture2D).resource_path, "res://assets/ui/art_chain_offer.png",
		"ảnh tiêu đề có booster của game")
	# Sprite arrow points left at rotation 0. Path: top row left -> right, down the right edge, middle row right ->
	# left, down the left edge, bottom row left -> right.
	var ray: Control = node.ui.node("Panel/Content/UIRay")
	for p in [["Image", Vector2.RIGHT], ["Image (8)", Vector2.DOWN], ["Image (12)", Vector2.LEFT],
			["Image (16)", Vector2.DOWN], ["Image (19)", Vector2.RIGHT], ["Image (22)", Vector2.RIGHT]]:
		var dir := Vector2.LEFT.rotated((ray.get_node(str(p[0])) as Control).rotation)
		t.ok(dir.is_equal_approx(p[1]), "mũi tên %s chỉ theo chiều tiến" % p[0])
	t.ok(node.claim_button != null, "có nút nhận")
	var c0 := int(g.s.coins)
	node.claim_button.pressed.emit()
	await (Engine.get_main_loop() as SceneTree).process_frame
	t.eq(int(g.s.coins), c0 + 300, "nhận bước free")
	t.eq(node.node_states[0], "claimed", "bước 1 đã nhận")
	t.eq(node.node_states[1], "claimable", "bước 2 nhận được")
	node.queue_free()


func test_chain_ad_step(t: T) -> void:
	var g := _game(24)
	g.s.chain = {"active": true, "id": "chain_a", "step": 1, "expires": g.test_now + D,
		"cooldown_until": 0, "shown": true, "rotation": 1}
	var node := _open("res://scenes/chain_offer.tscn")
	t.eq(node.node_states, ["claimed", "claimable", "locked", "locked", "locked", "locked"], "bước 2 (video) nhận được")
	var hint0 := int(g.s.inv.get("hint", 0))
	_root().get_node("Platform").ads.simulate("ok")
	node.claim_button.pressed.emit()
	for i in 5:
		await (Engine.get_main_loop() as SceneTree).process_frame
	t.eq(int(g.s.chain.step), 2, "sang bước 3")
	t.eq(int(g.s.inv.get("hint", 0)), hint0 + 1, "nhận thưởng bước video")
	# The window stays put: the tick lands on the pack that was tapped.
	t.eq(node.node_states, ["claimed", "claimed", "claimable", "locked", "locked", "locked"], "tích ngay ô bước 2")
	var bg := func(slot: String) -> Rect2:
		return node.ui.node("Panel/Content/ListPack/%s/BG (1)" % slot).region
	t.eq(bg.call("ChainOfferPack (1)"), bg.call("ChainOfferPack"), "ô đã nhận nền thường")
	t.ok(bg.call("ChainOfferPack (2)") != bg.call("ChainOfferPack"), "nền vàng theo bước nhận được")
	t.ok(node.toast_text.begins_with(node.tr("ads_reward_ok")), "báo đã nhận thưởng")
	t.ok(node.toast_text.contains(node.tr("booster_hint")), "báo tên thưởng")
	t.eq(node.claimed_count, 1, "đếm một lần nhận")
	node.queue_free()


func test_chain_slide_after_last_slot(t: T) -> void:
	var g := _game(24)
	g.s.chain = {"active": true, "id": "chain_a", "step": 5, "expires": g.test_now + D,
		"cooldown_until": 0, "shown": true, "rotation": 1}
	var node := _open("res://scenes/chain_offer.tscn")
	t.eq(node.node_states[5], "claimable", "bước 6 ở ô cuối")
	node.claim_button.pressed.emit()
	await (Engine.get_main_loop() as SceneTree).process_frame
	t.eq(node.node_states, ["claimed", "claimed", "claimed", "claimed", "claimed", "claimed"], "tích tại chỗ trước khi trượt")
	t.ok(node.claim_button == null, "chưa có nút nhận lúc giữ")
	await (Engine.get_main_loop() as SceneTree).create_timer(node.SLIDE_DELAY + 0.2).timeout
	t.eq(node.node_states, ["claimed", "claimed", "claimed", "claimed", "claimed", "claimable"], "trượt một ô, bước 7 ở ô cuối")
	t.ok(node.claim_button != null, "có nút nhận bước 7")
	node.queue_free()


func test_chain_window_slides(t: T) -> void:
	var cls := preload("res://src/ui/chain_offer.gd")
	t.eq(cls.window_start(0, 8, 6), 0, "đầu chuỗi")
	t.eq(cls.window_start(3, 8, 6), 0, "đứng yên khi bước hiện tại còn trong cửa sổ")
	t.eq(cls.window_start(5, 8, 6), 0, "bước hiện tại ở ô cuối")
	t.eq(cls.window_start(6, 8, 6), 1, "trượt để bước hiện tại ở ô cuối")
	t.eq(cls.window_start(7, 8, 6), 2, "kẹp ở cuối")
	t.eq(cls.window_start(8, 8, 6), 2, "xong hết")


func test_home_event_buttons(t: T) -> void:
	var g := _game(10)
	var home := _open("res://scenes/home.tscn")
	t.eq(home._weekly_col.visible, false, "Weekly ẩn khi Locked")
	t.eq(home._chain_col.visible, false, "Chain ẩn khi chưa có")
	t.eq(home._special_col.visible, false, "Special Pack ẩn khi chưa đủ điều kiện")
	g.s.level = 30
	g.s.buys.append({"token": "x", "sku": "starter_pack"})
	g.s.chain = {"active": true, "id": "chain_a", "step": 0, "expires": g.test_now + D,
		"cooldown_until": 0, "shown": true, "rotation": 1}
	home.refresh()
	t.eq(home._weekly_col.visible, true, "Weekly hiện khi Active")
	t.eq(home.weekly_dot.visible, true, "chấm đỏ khi chưa mở chu kỳ")
	t.eq(home._chain_col.visible, true, "Chain hiện")
	t.eq(home._special_col.visible, true, "Special Pack hiện")
	var got := []
	home.closed.connect(func(r: Variant) -> void: got.append(r))
	home.special_btn.pressed.emit()
	t.eq(got[0], {"action": "offer", "id": "special_pack"}, "bấm mở popup offer")
	home.weekly_btn.pressed.emit()
	t.eq(got[1], {"action": "weekly"}, "bấm mở Weekly Pass")
	home.chain_btn.pressed.emit()
	t.eq(got[2], {"action": "chain"}, "bấm mở Chain Offer")
	home.queue_free()
