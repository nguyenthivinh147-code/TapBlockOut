extends RefCounted
const T := preload("res://tests/t.gd")
const Config := preload("res://src/config.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")
const UiTween := preload("res://src/ui/ui_tween.gd")

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
	t.ok(p.video_button != null and p.video_button.visible, "món chưa có: chỉ có nút video")
	t.eq(p.use_button, null, "không có nút đeo")
	t.ok(not (p.find_child("AvatarButtonGroup", true, false).get_node("BuyButton") as Control).visible, "không có nút mua gold")
	p.select("frame_03")
	t.ok(p.video_button != null, "frame_03: nút video")
	t.ok(p.find_child("Grid_frame", true, false).visible, "chọn frame thì sang tab Frame")
	t.ok(not p.find_child("Grid_avatar", true, false).visible, "ẩn lưới avatar")
	p.queue_free()


func test_tabs_keep_selection(t: T) -> void:
	_g()
	var p := _profile()
	p.select("avatar_03")
	p.tab_buttons["frame"].pressed.emit()
	t.ok(p.find_child("Grid_frame", true, false).visible, "tab Frame")
	t.eq(_txt(p.use_button), "Equipped", "frame mặc định đang đeo")
	p.tab_buttons["avatar"].pressed.emit()
	t.ok(p.cells["avatar_03"].ring.visible, "quay lại tab Avatar vẫn giữ ô đã chọn")
	t.ok(p.video_button != null, "nút video avatar_03")
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


## Scrolled to the end, the top avatar rows sit above the Viewport (masked out) over the tab row: they must not take
## the tap meant for the Frame tab.
func test_tab_tap_after_scroll_to_end(t: T) -> void:
	_g()
	var p := _profile()
	await (Engine.get_main_loop() as SceneTree).process_frame
	var host: Control = p.find_child("Grid_avatar", true, false)
	host.get_node("ScrollRect").call("set_vertical_normalized", 0.0)
	await (Engine.get_main_loop() as SceneTree).process_frame
	var tab: Control = p.tab_buttons["frame"]
	var hidden := 0
	var vp_rect: Rect2 = (host.get_node("Viewport") as Control).get_global_rect()
	for id in p.cells:
		var b: Control = p.cells[id].panel
		if str(id).begins_with("avatar_") and b.get_global_rect().intersects(tab.get_global_rect()) \
				and not vp_rect.encloses(b.get_global_rect()):
			hidden += 1
	t.ok(hidden > 0, "cuộn hết: có ô avatar nằm dưới tab Frame, ngoài khung cuộn")
	await _mouse(tab, tab.size * 0.5, true)
	await _mouse(tab, tab.size * 0.5, false)
	t.ok(p.find_child("Grid_frame", true, false).visible, "cuộn hết lưới avatar vẫn chạm được tab Frame")
	t.ok(p.cells["avatar_00"].ring.visible, "ô avatar khuất không bị chọn")
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


## Texture on the big avatar ("Preview", prefab CurrentAvt) or frame (CurrentFrame).
func _big(p: Control, node_name: String) -> Texture2D:
	var img: Control = UnityUI.image_of(p.find_child(node_name, true, false) as Control)
	return img.get("tex") as Texture2D


func test_preview_on_click(t: T) -> void:
	var g := _g()
	var p := _profile()
	t.eq(_big(p, "Preview"), ThemeKit.icon("avatar_00"), "mở màn: avatar đang đeo")
	t.eq(_big(p, "CurrentFrame"), ThemeKit.icon("frame_00"), "mở màn: frame đang đeo")
	p.cells["avatar_06"].panel.pressed.emit()
	t.eq(_big(p, "Preview"), ThemeKit.icon("avatar_06"), "bấm avatar chưa có: xem trước ngay")
	t.eq(g.s.cos.avatar, "avatar_00", "xem trước không đổi món đang đeo")
	p.cells["frame_04"].panel.pressed.emit()
	t.eq(_big(p, "CurrentFrame"), ThemeKit.icon("frame_04"), "bấm frame: xem trước khung")
	t.eq(_big(p, "Preview"), ThemeKit.icon("avatar_06"), "sang tab Frame vẫn giữ avatar đang xem")
	t.eq(g.s.cos.frame, "frame_00", "frame đang đeo giữ nguyên")
	p.queue_free()
	var p2 := _profile()
	t.eq(_big(p2, "Preview"), ThemeKit.icon("avatar_00"), "đóng không mua: mở lại thấy món đang đeo")
	p2.queue_free()


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
	p.select("avatar_03")
	p.video_button.pressed.emit()
	for i in 10:
		await (Engine.get_main_loop() as SceneTree).process_frame
	t.ok(not (g.s.cos.owned as Array).has("avatar_03"), "đóng sớm thì không mở")
	t.eq(p.status_label.text, "Watch the whole video to get the reward.", "báo xem hết video")
	p.queue_free()


## Avatar 05-07, frame 06-07 chỉ có từ hộp Road Trip: không nút mua hay video. Road Trip chưa mở: dòng "Unlocked at
## Level 95"; đã mở: nút Road Trip (đóng Profile với action road_trip). Có rồi thì đeo được.
func test_road_trip_only(t: T) -> void:
	var g := _g()  # level 5: Road Trip còn khoá
	var p := _profile()
	p.select("avatar_06")
	t.eq(p.video_button, null, "không nút video")
	t.eq(p.use_button, null, "không nút đeo")
	t.eq(p.road_trip_button, null, "Road Trip khoá: không nút")
	var l: Label = p.find_child("AvatarButtonGroup", true, false).find_child("RoadTripLocked", true, false)
	t.ok(l != null and l.visible, "dòng mở khoá")
	t.eq(l.text, "Unlocked at Level 95", "mở ở Level 95")
	t.ok(p.cells["avatar_06"].lock.visible, "ô vẫn khoá")
	p.select("avatar_04")
	t.ok(not l.visible, "món thường: ẩn dòng mở khoá")
	t.ok(p.video_button != null, "món thường: có nút video")
	p.queue_free()
	g.s.level = 95
	p = _profile()
	p.select("frame_07")
	t.ok(p.road_trip_button != null and p.road_trip_button.visible, "Road Trip mở: nút Road Trip")
	t.eq(_txt(p.road_trip_button), "Road Trip", "chữ nút")
	t.ok(not (p.find_child("FrameButtonGroup", true, false).find_child("RoadTripLocked", true, false) as Label).visible,
		"ẩn dòng mở khoá")
	var got := {"r": null}
	p.closed.connect(func(r: Variant) -> void: got["r"] = r)
	p.road_trip_button.pressed.emit()
	t.eq((got["r"] as Dictionary).get("action", ""), "road_trip", "bấm nút: sang Road Trip")
	p.queue_free()
	(g.s.cos.owned as Array).append("avatar_06")
	p = _profile()
	p.select("avatar_06")
	t.eq(_txt(p.use_button), "Equip", "đã nhận từ hộp: đeo được")
	t.eq(p.road_trip_button, null, "đã có: không nút Road Trip")
	p.queue_free()


## Avatar, frame 08-12 chỉ có từ thưởng league: không nút mua hay video, dòng "Reach Platinum League ..." trên nút
## Leaderboard (đóng Profile với action ranking). Leaderboard chưa mở (L70): dòng "Unlocked at Level 70" thay nút.
func test_league_only(t: T) -> void:
	var g := _g()  # level 5: Leaderboard còn khoá
	var p := _profile()
	p.select("avatar_10")
	t.eq(p.video_button, null, "không nút video")
	t.eq(p.use_button, null, "không nút đeo")
	t.eq(p.league_button, null, "Leaderboard khoá: không nút")
	var grp: Node = p.find_child("AvatarButtonGroup", true, false)
	var locked: Label = grp.find_child("LeagueLocked", true, false)
	var note: Label = grp.find_child("LeagueNote", true, false)
	t.ok(locked != null and locked.visible, "dòng mở khoá")
	t.eq(locked.text, "Unlocked at Level 70", "mở ở Level 70")
	t.ok(note != null and note.visible, "dòng nhận ở Bảng xếp hạng")
	t.eq(note.text, "Reach Platinum League or higher in the Leaderboard to get it", "chữ dòng nhận")
	t.ok(p.cells["avatar_10"].lock.visible, "ô vẫn khoá")
	p.select("avatar_04")
	t.ok(not locked.visible and not note.visible, "món thường: ẩn hai dòng")
	t.ok(p.video_button != null, "món thường: có nút video")
	p.queue_free()
	g.s.level = 70
	p = _profile()
	p.select("frame_12")
	t.ok(p.league_button != null and p.league_button.visible, "Leaderboard mở: nút Bảng xếp hạng")
	t.eq(_txt(p.league_button), "Leaderboard", "chữ nút")
	grp = p.find_child("FrameButtonGroup", true, false)
	t.ok(not (grp.find_child("LeagueLocked", true, false) as Label).visible, "ẩn dòng mở khoá")
	t.ok((grp.find_child("LeagueNote", true, false) as Label).visible, "vẫn có dòng nhận")
	t.ok(not (grp.find_child("RoadTripLocked", true, false) as Label).visible, "không lẫn dòng Road Trip")
	var got := {"r": null}
	p.closed.connect(func(r: Variant) -> void: got["r"] = r)
	p.league_button.pressed.emit()
	t.eq((got["r"] as Dictionary).get("action", ""), "ranking", "bấm nút: sang Bảng xếp hạng")
	p.queue_free()
	(g.s.cos.owned as Array).append("frame_12")
	p = _profile()
	p.select("frame_12")
	t.eq(_txt(p.use_button), "Equip", "đã nhận từ thưởng league: đeo được")
	t.eq(p.league_button, null, "đã có: không nút Bảng xếp hạng")
	t.ok(not (p.find_child("FrameButtonGroup", true, false).find_child("LeagueNote", true, false) as Label).visible,
		"đã có: ẩn dòng nhận")
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
