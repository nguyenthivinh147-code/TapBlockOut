extends RefCounted
const T := preload("res://tests/t.gd")
const Config := preload("res://src/config.gd")

const DIR := "user://test_ui_profile"
const SCENE := "res://scenes/profile.tscn"


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _g() -> Node:
	var g: Node = _root().get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	g.s.level = 5
	g.test_now = 1_800_000_000
	_root().get_node("Platform").ads.calls.clear()
	return g


func _profile() -> Control:
	var p := (load(SCENE) as PackedScene).instantiate() as Control
	_root().add_child(p)
	p.setup({})
	return p


func test_grid_counts_and_defaults(t: T) -> void:
	_g()
	var p := _profile()
	var av := 0
	var fr := 0
	for id in p.cells:
		if str(id).begins_with("avatar_"):
			av += 1
		else:
			fr += 1
	t.eq(av, 13, "12 avatar + mặc định")
	t.eq(fr, 13, "12 frame + mặc định")
	t.ok(p.cells["avatar_00"].equip.disabled, "avatar mặc định đang đeo")
	t.eq(p.cells["avatar_00"].equip.text, "Equipped", "chữ đang đeo")
	t.ok(p.cells["avatar_01"].buy != null and p.cells["avatar_01"].video != null, "món chưa có: giá và video")
	t.eq(p.cells["avatar_01"].buy.text, "Buy for 50", "giá avatar_01")
	t.eq(p.cells["avatar_02"].buy.text, "Buy for 75", "giá avatar_02")
	t.eq(p.cells["frame_03"].buy.text, "Buy for 100", "giá frame_03")
	p.queue_free()


func test_equip_owned(t: T) -> void:
	var g := _g()
	g.s.cos.owned.append("avatar_04")
	var p := _profile()
	t.eq(p.cells["avatar_04"].equip.text, "Equip", "đã có, chưa đeo")
	p.cells["avatar_04"].equip.pressed.emit()
	t.eq(g.s.cos.avatar, "avatar_04", "đã đeo")
	t.ok(p.cells["avatar_04"].equip.disabled, "UI cập nhật: đang đeo")
	t.ok(not p.cells["avatar_00"].equip.disabled, "avatar cũ đeo lại được")
	p.cells["avatar_00"].equip.pressed.emit()
	t.eq(g.s.cos.avatar, "avatar_00", "đeo lại mặc định")
	p.queue_free()


func test_buy_with_gold(t: T) -> void:
	var g := _g()
	g.s.coins = 120
	var p := _profile()
	p.cells["avatar_02"].buy.pressed.emit()  # 75
	t.eq(int(g.s.coins), 45, "trừ 75 gold")
	t.ok((g.s.cos.owned as Array).has("avatar_02"), "đã sở hữu")
	t.eq(g.s.cos.avatar, "avatar_02", "mua xong đeo luôn")
	t.eq(p.gold_label.text, "45", "ví cập nhật")
	t.ok(p.cells["avatar_02"].buy == null, "không còn nút mua")
	p.queue_free()


func test_buy_not_enough_gold(t: T) -> void:
	var g := _g()
	g.s.coins = 10
	var p := _profile()
	p.cells["frame_01"].buy.pressed.emit()
	t.eq(int(g.s.coins), 10, "không trừ gold")
	t.ok(not (g.s.cos.owned as Array).has("frame_01"), "chưa có")
	t.eq(p.status_label.text, "Not enough gold", "báo thiếu gold")
	p.queue_free()


func test_video_unlock(t: T) -> void:
	var g := _g()
	g.s.coins = 0
	var p := _profile()
	p.cells["frame_05"].video.pressed.emit()
	for i in 10:
		await (Engine.get_main_loop() as SceneTree).process_frame
	t.ok((g.s.cos.owned as Array).has("frame_05"), "mở bằng video")
	t.eq(int(g.s.coins), 0, "không tốn gold")
	t.eq(g.s.cos.frame, "frame_05", "đeo luôn")
	var calls: Array = _root().get_node("Platform").ads.calls
	t.eq(calls.size(), 1, "một lần xem")
	t.eq(str(calls[0].placement), "cosmetic_unlock", "placement")
	p.queue_free()


func test_video_closed_no_reward(t: T) -> void:
	var g := _g()
	_root().get_node("Platform").ads.simulate({"ok": false, "reason": "closed"})
	var p := _profile()
	p.cells["avatar_07"].video.pressed.emit()
	for i in 10:
		await (Engine.get_main_loop() as SceneTree).process_frame
	t.ok(not (g.s.cos.owned as Array).has("avatar_07"), "đóng sớm thì không mở")
	t.eq(p.status_label.text, "Watch the whole video to get the reward.", "báo xem hết video")
	p.queue_free()


func test_back_emits_closed(t: T) -> void:
	_g()
	var p := _profile()
	var got := {"r": null}
	p.closed.connect(func(r: Variant) -> void: got["r"] = r)
	p.back_btn.pressed.emit()
	t.eq((got["r"] as Dictionary).get("action", ""), "back", "Back")
	t.ok(Config.cosmetic_ids("avatar").size() == 13, "config 13 avatar")
	p.queue_free()
