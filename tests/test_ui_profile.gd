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


## Text of a prefab button (its TMP label child).
func _txt(b: Node) -> String:
	var l := b.find_children("*", "Label", true, false)
	return (l[0] as Label).text if not l.is_empty() else ""


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
	t.ok(p.cells["avatar_00"].check.visible, "dấu tích trên avatar đang đeo")
	t.ok(not p.cells["avatar_01"].check.visible and p.cells["avatar_01"].lock.visible, "món chưa có: khoá")
	t.ok(p.cells["avatar_00"].ring.visible, "mở màn chọn sẵn món đang đeo")
	t.ok(p.use_button.disabled, "nút đang đeo")
	t.eq(_txt(p.use_button), "Equipped", "chữ đang đeo")
	p.select("avatar_01")
	t.ok(p.buy_button != null and p.video_button != null, "món chưa có: giá và video")
	t.eq(p.use_button, null, "không có nút đeo")
	t.eq(_txt(p.buy_button), "50", "giá avatar_01")
	p.select("avatar_02")
	t.eq(_txt(p.buy_button), "75", "giá avatar_02")
	p.select("frame_03")
	t.eq(_txt(p.buy_button), "100", "giá frame_03")
	t.ok(p.find_child("Grid_frame", true, false).visible, "chọn frame thì sang tab Frame")
	t.ok(not p.find_child("Grid_avatar", true, false).visible, "ẩn lưới avatar")
	p.queue_free()


func test_tabs_keep_selection(t: T) -> void:
	_g()
	var p := _profile()
	p.select("avatar_05")
	p.tab_buttons["frame"].pressed.emit()
	t.ok(p.find_child("Grid_frame", true, false).visible, "tab Frame")
	t.eq(_txt(p.use_button), "Equipped", "frame mặc định đang đeo")
	p.tab_buttons["avatar"].pressed.emit()
	t.ok(p.cells["avatar_05"].ring.visible, "quay lại tab Avatar vẫn giữ ô đã chọn")
	t.ok(p.buy_button != null, "nút mua avatar_05")
	p.queue_free()


## Mouse event at a control-local point, through the viewport like a real tap (pressed.emit() skips hit testing).
func _mouse(c: Control, local: Vector2, down: Variant) -> void:
	var at: Vector2 = c.get_global_transform_with_canvas() * local
	var e: InputEvent
	if down == null:
		e = InputEventMouseMotion.new()
		(e as InputEventMouseMotion).button_mask = MOUSE_BUTTON_MASK_LEFT
	else:
		e = InputEventMouseButton.new()
		(e as InputEventMouseButton).button_index = MOUSE_BUTTON_LEFT
		(e as InputEventMouseButton).pressed = down
	e.position = at
	e.global_position = at
	_root().push_input(e, true)
	await (Engine.get_main_loop() as SceneTree).process_frame


func test_tab_tap_through_viewport(t: T) -> void:
	_g()
	var p := _profile()
	await (Engine.get_main_loop() as SceneTree).process_frame
	var tab: Control = p.tab_buttons["frame"]
	await _mouse(tab, tab.size * 0.5, true)
	await _mouse(tab, tab.size * 0.5, false)
	t.ok(p.find_child("Grid_frame", true, false).visible, "chạm tab Frame thì sang lưới Frame (khung cuộn không che tab)")
	tab = p.tab_buttons["avatar"]
	await _mouse(tab, tab.size * 0.5, true)
	await _mouse(tab, tab.size * 0.5, false)
	t.ok(p.find_child("Grid_avatar", true, false).visible, "chạm tab Avatar thì quay lại")
	var vp: Control = p.find_child("Grid_avatar", true, false).get_node("Viewport")
	var content: Control = vp.get_node("Content")
	var y0 := content.position.y
	var at := Vector2(vp.size.x * 0.5, vp.size.y * 0.8)
	await _mouse(vp, at, true)
	for i in 6:
		await _mouse(vp, at - Vector2(0, 30 * (i + 1)), null)
	t.ok(content.position.y < y0 - 1.0, "kéo trên lưới vẫn cuộn")
	await _mouse(vp, at - Vector2(0, 180), false)
	p.queue_free()


func test_prefab_size_and_touch(t: T) -> void:
	_g()
	var p := _profile()
	var card: Control = p.find_child("ProfileMenu", true, false)
	t.ok(absf(card.size.x - 724.0) < 0.5, "rộng popup theo prefab ProfileLayer (724)")
	var px: float = card.get_global_transform_with_canvas().get_scale().y
	t.ok(card.size.y * px <= 1280.0, "vừa màn 1280")
	for b in [p.back_btn, p.use_button, p.tab_buttons["avatar"], p.cells["avatar_00"].panel]:
		var s: Vector2 = b.hit_size()
		t.ok(s.x >= 95.9 and s.y >= 95.9, "%s chạm được ít nhất 96 px" % (b as Node).name)
	p.queue_free()


func test_equip_owned(t: T) -> void:
	var g := _g()
	g.s.cos.owned.append("avatar_04")
	var p := _profile()
	p.cells["avatar_04"].panel.pressed.emit()
	t.eq(_txt(p.use_button), "Equip", "đã có, chưa đeo")
	p.use_button.pressed.emit()
	t.eq(g.s.cos.avatar, "avatar_04", "đã đeo")
	t.ok(p.use_button.disabled, "UI cập nhật: đang đeo")
	t.ok(p.cells["avatar_04"].check.visible and not p.cells["avatar_00"].check.visible, "dấu tích chuyển sang món mới")
	p.select("avatar_00")
	t.ok(not p.use_button.disabled, "avatar cũ đeo lại được")
	p.use_button.pressed.emit()
	t.eq(g.s.cos.avatar, "avatar_00", "đeo lại mặc định")
	p.queue_free()


func test_buy_with_gold(t: T) -> void:
	var g := _g()
	g.s.coins = 120
	var p := _profile()
	p.select("avatar_02")
	p.buy_button.pressed.emit()  # 75
	t.eq(int(g.s.coins), 45, "trừ 75 gold")
	t.ok((g.s.cos.owned as Array).has("avatar_02"), "đã sở hữu")
	t.eq(g.s.cos.avatar, "avatar_02", "mua xong đeo luôn")
	t.eq(p.gold_label.text, "45", "ví cập nhật")
	t.ok(p.buy_button == null, "không còn nút mua")
	t.ok(p.use_button != null and p.use_button.disabled, "nút đang đeo")
	p.queue_free()


func test_buy_not_enough_gold(t: T) -> void:
	var g := _g()
	g.s.coins = 10
	var p := _profile()
	p.select("frame_01")
	p.buy_button.pressed.emit()
	t.eq(int(g.s.coins), 10, "không trừ gold")
	t.ok(not (g.s.cos.owned as Array).has("frame_01"), "chưa có")
	t.eq(p.status_label.text, "Not enough gold", "báo thiếu gold")
	p.queue_free()


func test_video_unlock(t: T) -> void:
	var g := _g()
	g.s.coins = 0
	var p := _profile()
	p.select("frame_05")
	p.video_button.pressed.emit()
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
	p.select("avatar_07")
	p.video_button.pressed.emit()
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
