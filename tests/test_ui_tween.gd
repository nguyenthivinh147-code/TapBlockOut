extends RefCounted
## UI motion added on 2026-11-10 (design.md mục 2 "Chuyển động UI"): popups close with a shrink and fade, screens
## outside the hub tabs cross-fade, popup content and Home's columns pop in one after another, counters roll and
## bump, Home's side icons nudge (wobble with a notice) and its red dots beat.
const T := preload("res://tests/t.gd")
const UiTween := preload("res://src/ui/ui_tween.gd")
const UiMotion := preload("res://src/ui/ui_motion.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")
const HubTop := preload("res://src/ui/hub_top.gd")

const DIR := "user://test_ui_tween"


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _g() -> Node:
	var g: Node = _tree().root.get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	g.test_now = 1_800_000_000
	return g


func _box(parent: Node, rect: Rect2) -> Control:
	var c := Control.new()
	c.position = rect.position
	c.size = rect.size
	parent.add_child(c)
	return c


func _wait(sec: float) -> void:
	await _tree().create_timer(sec).timeout


## A popup root with a dim and a panel, its reveal recorded like UnityUI.build does.
func _popup() -> Dictionary:
	var root := _box(_tree().root, Rect2(0, 0, 720, 1280))
	var dim := _box(root, Rect2(0, 0, 720, 1280))
	var panel := _box(root, Rect2(100, 300, 520, 600))
	var btn := Button.new()
	btn.size = Vector2(200, 80)
	panel.add_child(btn)
	root.set_meta(UiTween.META_REVEAL, {"panel": panel, "dim": dim})
	return {"root": root, "dim": dim, "panel": panel, "btn": btn}


func test_close_popup_shrinks_fades_then_frees(t: T) -> void:
	# First test of the file: let the start-up hitch pass, or one long frame fires the timer before the tween steps.
	for i in 3:
		await _tree().process_frame
	var p := _popup()
	var root: Control = p.root
	UiTween.close_popup(root)
	t.ok(UiTween.closing(root), "đang đóng")
	t.ok(not root.is_queued_for_deletion(), "chưa gỡ ngay")
	t.eq((p.btn as Button).mouse_filter, Control.MOUSE_FILTER_IGNORE, "nút không nhận chạm nữa")
	t.eq(root.mouse_filter, Control.MOUSE_FILTER_IGNORE, "gốc không chặn chạm")
	UiTween.close_popup(root)
	await _wait(UiTween.CLOSE_SEC * 0.6)
	t.ok(is_instance_valid(root), "đang thu lại")
	t.ok((p.panel as Control).scale.x < 1.0, "panel thu nhỏ")
	t.ok((p.panel as Control).modulate.a < 1.0, "panel mờ dần")
	t.ok((p.dim as Control).modulate.a < 1.0, "nền tối mờ dần")
	await _wait(UiTween.CLOSE_SEC)
	t.ok(not is_instance_valid(root) or root.is_queued_for_deletion(), "xong thì gỡ")


func test_close_without_reveal_fades_root_and_hidden_frees_at_once(t: T) -> void:
	var root := _box(_tree().root, Rect2(0, 0, 720, 1280))
	UiTween.close_popup(root)
	await _wait(UiTween.CLOSE_SEC * 0.6)
	t.ok(is_instance_valid(root) and root.modulate.a < 1.0, "không có panel thì mờ cả popup")
	await _wait(UiTween.CLOSE_SEC)
	t.ok(not is_instance_valid(root) or root.is_queued_for_deletion(), "rồi gỡ")
	var hidden := _box(_tree().root, Rect2(0, 0, 10, 10))
	hidden.visible = false
	UiTween.close_popup(hidden)
	t.ok(hidden.is_queued_for_deletion(), "popup ẩn gỡ ngay")


func test_pop_in_waits_shrunk_then_settles(t: T) -> void:
	var host := _box(_tree().root, Rect2(0, 0, 720, 1280))
	var a := _box(host, Rect2(0, 0, 100, 100))
	var b := _box(host, Rect2(0, 200, 100, 100))
	b.scale = Vector2(2, 2)
	var hidden := _box(host, Rect2(0, 400, 100, 100))
	hidden.visible = false
	UiTween.stagger([a, b, hidden])
	t.near(a.scale.x, UiTween.POP_FROM, 0.0001, "chờ ở cỡ nhỏ")
	t.eq(a.modulate.a, 0.0, "chờ trong suốt")
	t.near(b.scale.x, 2.0 * UiTween.POP_FROM, 0.0001, "nhỏ theo cỡ riêng")
	t.eq(a.pivot_offset_ratio, Vector2(0.5, 0.5), "phóng từ giữa")
	t.eq(hidden.scale, Vector2.ONE, "node ẩn không bật")
	await _wait(UiTween.POP_STEP + UiTween.POP_SEC + 0.15)
	t.near(a.scale.x, 1.0, 0.001, "về cỡ thật")
	t.near(b.scale.x, 2.0, 0.001, "về cỡ riêng")
	t.near(b.modulate.a, 1.0, 0.001, "rõ hẳn")
	t.ok(not a.has_meta(UiTween.META_POP), "xong thì hết cờ")
	host.free()


func test_stagger_spreads_long_lists(t: T) -> void:
	var host := _box(_tree().root, Rect2(0, 0, 720, 1280))
	var many: Array = []
	for i in UiTween.POP_MAX + 5:
		many.append(_box(host, Rect2(0, i * 10, 10, 10)))
	var looped := _box(host, Rect2(0, 0, 10, 10))
	looped.set_meta("u_scale_loop", true)
	UiTween.stagger(many + [looped])
	t.ok((many[0] as Control).has_meta(UiTween.META_POP), "mục đầu bật")
	t.ok((many[UiTween.POP_MAX - 1] as Control).has_meta(UiTween.META_POP), "tới POP_MAX mục")
	t.eq((many[UiTween.POP_MAX] as Control).scale, Vector2.ONE, "quá POP_MAX thì hiện ngay")
	t.eq(looped.scale, Vector2.ONE, "node có anim scale riêng không bật")
	host.free()


func test_panel_items_buttons_and_layout_children_top_down(t: T) -> void:
	var panel := _box(_tree().root, Rect2(0, 0, 600, 800))
	var bg := _box(panel, Rect2(0, 0, 600, 800))
	var list := VBoxContainer.new()
	list.position = Vector2(0, 100)
	list.size = Vector2(600, 300)
	panel.add_child(list)
	var row1 := _box(list, Rect2(0, 0, 600, 50))
	var row2 := _box(list, Rect2(0, 60, 600, 50))
	var inner := Button.new()
	row1.add_child(inner)
	var deco := _box(panel, Rect2(0, 600, 600, 100))
	var ok := Button.new()
	ok.position = Vector2(200, 650)
	ok.size = Vector2(200, 80)
	deco.add_child(ok)
	var close := Button.new()
	close.position = Vector2(540, 0)
	close.size = Vector2(60, 60)
	panel.add_child(close)
	var off := Button.new()
	off.visible = false
	panel.add_child(off)
	var items := UiTween.panel_items(panel)
	t.eq(items, [close, row1, row2, ok], "nút và mục danh sách, từ trên xuống, không lấy nút trong mục")
	t.ok(not items.has(bg), "nền không bật")
	panel.free()


func test_roll_counts_to_the_new_number(t: T) -> void:
	var l := Label.new()
	_tree().root.add_child(l)
	UiTween.roll(l, 100)
	t.eq(l.text, "100", "lần đầu hiện ngay")
	UiTween.roll(l, 400)
	t.eq(l.text, "100", "chưa nhảy ngay")
	t.eq(UiTween.roll_target(l), 400, "đang đếm tới 400")
	await _wait(UiTween.ROLL_SEC * 0.5)
	var mid := l.text.to_int()
	t.ok(mid > 100 and mid < 400, "đang đếm: %d" % mid)
	UiTween.roll(l, 300)
	t.eq(UiTween.roll_target(l), 300, "đổi đích giữa chừng")
	await _wait(UiTween.ROLL_SEC + 0.1)
	t.eq(l.text, "300", "tới đích")
	l.visible = false
	UiTween.roll(l, 50)
	t.eq(l.text, "50", "ẩn thì hiện ngay")
	l.free()


func test_bump_swells_and_settles(t: T) -> void:
	var c := _box(_tree().root, Rect2(0, 0, 80, 80))
	UiTween.bump(c)
	t.near(c.scale.x, UiTween.BUMP, 0.0001, "nở ra")
	t.eq(c.pivot_offset, Vector2(40, 40), "quanh tâm")
	await _wait(UiTween.BUMP_SEC + 0.1)
	t.near(c.scale.x, 1.0, 0.001, "về cỡ cũ")
	c.free()


func test_nudge_and_badge_poses(t: T) -> void:
	t.eq(UiMotion.nudge_pose(0.0), [0.0, 0.0], "bắt đầu đứng yên")
	t.eq(UiMotion.nudge_pose(UiMotion.NUDGE_PERIOD - 0.01), [0.0, 0.0], "cuối chu kỳ đứng yên")
	for edge in [UiMotion.NUDGE_AIR, UiMotion.NUDGE_LAND]:
		var a: Array = UiMotion.nudge_pose(edge - 0.0001)
		var b: Array = UiMotion.nudge_pose(edge + 0.0001)
		for i in 2:
			t.near(float(a[i]), float(b[i]), 0.01, "liền mạch ở %.2f [%d]" % [edge, i])
	var apex: Array = UiMotion.nudge_pose(UiMotion.NUDGE_AIR * 0.5)
	t.near(float(apex[0]), UiMotion.NUDGE_LIFT, 0.0001, "đỉnh nhún")
	t.ok(float(apex[1]) < 0.0, "trên không thì giãn dọc")
	t.ok(UiMotion.NUDGE_LIFT <= 0.08, "nhún nhẹ")
	t.near(UiMotion.badge_swell(UiMotion.BADGE_BEAT * 0.5), UiMotion.BADGE_SCALE, 0.0001, "chấm đỏ nở nhất giữa nhịp")
	t.eq(UiMotion.badge_swell(UiMotion.BADGE_BEAT + 0.01), 0.0, "rồi nghỉ")


func test_nudge_rests_on_a_locked_button_and_switches_kind(t: T) -> void:
	var b := Button.new()
	b.size = Vector2(100, 100)
	_tree().root.add_child(b)
	var icon := _box(b, Rect2(10, 10, 80, 80))
	icon.pivot_offset_ratio = Vector2(0.5, 0.5)
	var m := UiMotion.attach(icon, UiMotion.NUDGE)
	m.call("_process", UiMotion.NUDGE_AIR * 0.5)
	t.ok(icon.position.y < 10.0, "nhún lên")
	b.disabled = true
	m.call("_process", 0.01)
	t.eq(icon.position, Vector2(10, 10), "nút khoá thì về chỗ, không nhún")
	b.disabled = false
	m.call("_process", 0.01)
	m.call("set_kind", UiMotion.WOBBLE)
	t.eq(icon.position, Vector2(10, 10), "đổi kiểu thì về gốc trước")
	t.eq(m.kind, UiMotion.WOBBLE, "giờ lắc")
	m.time = UiMotion.WOBBLE_BURST * 0.1
	m.call("_process", 0.01)
	t.ok(absf(icon.rotation) > 0.0, "lắc nghiêng")
	b.free()


func test_hub_top_rolls_gold_and_bumps_heart(t: T) -> void:
	var g := _g()
	g.s.level = 30
	g.s.coins = 500
	var top: Control = HubTop.create()
	_tree().root.add_child(top)
	top.size = Vector2(886, 124)
	var label: Label = top.get("gold_label")
	t.eq(label.text, "500", "lần đầu hiện ngay")
	g.s.coins = 320
	g.coins_changed.emit(320)
	t.eq(label.text, "500", "tiêu gold: chưa nhảy")
	t.eq(UiTween.roll_target(label), 320, "đếm lùi tới 320")
	await _wait(UiTween.ROLL_SEC + 0.1)
	t.eq(label.text, "320", "tới số trong ví")
	var heart: Control = top.get("_lives_icon")
	if top.get("lives_panel").visible and top.get("lives_label").text.is_valid_int():
		g.s.lives.count = int(g.s.lives.count) - 1
		g.lives_changed.emit()
		t.ok(heart.scale.x > 1.0, "mất mạng thì tim nảy")
	top.free()


func test_slide_in_follows_layout_and_lands(t: T) -> void:
	var host := _box(_tree().root, Rect2(0, 0, 720, 1280))
	var c := _box(host, Rect2(100, 50, 200, 80))
	UiTween.slide_in(c, Vector2(0, -300), 0.2, 0.05)
	t.eq(c.position, Vector2(100, -250), "chờ ngoài chỗ")
	await _tree().process_frame
	# Layout puts it somewhere else meanwhile: that is its new place.
	c.position = Vector2(120, 60)
	await _tree().process_frame
	t.ok(c.position.y < 60.0, "vẫn đang trượt từ trên xuống")
	t.near(c.position.x, 120.0, 0.001, "theo chỗ mới")
	await _wait(0.4)
	t.eq(c.position, Vector2(120, 60), "về chỗ layout đặt")
	t.ok(not c.has_meta(UiTween.META_SLIDE), "xong thì hết cờ")
	host.free()


func test_bars_in_from_the_edges(t: T) -> void:
	var host := _box(_tree().root, Rect2(0, 0, 720, 1280))
	var top := _box(host, Rect2(0, 30, 720, 100))
	var chips: Array[Control] = []
	for x in [600, 0, 300]:
		chips.append(_box(top, Rect2(x, 10, 100, 80)))
	var nav := _box(host, Rect2(0, 1100, 720, 180))
	var vh := nav.get_viewport_rect().size.y
	UiTween.bars_in(top, nav)
	for c in chips:
		t.ok(c.get_global_rect().end.y < 0.0, "chip ở trên mép màn")
	t.ok(nav.get_global_rect().position.y > vh, "thanh dưới ở dưới mép màn")
	await _wait(UiTween.BAR_SEC * 0.5)
	t.ok(chips[1].position.y > chips[0].position.y, "chip bên trái đi trước")
	await _wait(UiTween.BAR_SEC + 3 * UiTween.BAR_STAGGER)
	for c in chips:
		t.near(c.position.y, 10.0, 0.001, "chip về chỗ")
	t.near(nav.position.y, 1100.0, 0.001, "thanh dưới về chỗ")
	host.free()


func test_road_trip_enter_runs_chip_and_scroll(t: T) -> void:
	var g := _g()
	g.s.level = 80
	g.s.road_trip.level = 13
	g.s.road_trip.guide = true
	var rt := (load("res://scenes/road_trip.tscn") as PackedScene).instantiate() as Control
	_tree().root.add_child(rt)
	rt.call("setup", {})
	await _tree().process_frame
	var chip: Control = rt.get("chip")
	t.ok(chip.has_meta(UiTween.META_SLIDE), "chip trượt vào")
	t.ok(chip.get_global_rect().position.x >= chip.get_viewport_rect().size.x, "chip chờ ngoài mép phải")
	t.ok(float(rt.get("_chip_shown")) >= 0.0, "thanh chip chạy sau khi chip vào")
	t.ok((rt.get("play_button") as Control).has_meta(UiTween.META_POP), "nút Level bật vào")
	var map: Control = rt.get("map")
	var box: Control = map.get_node("TargetBox")
	var rays: Control = map.get_node("TargetRays")
	t.eq(int(map.call("target_box")), 15, "hộp đang nhắm là hộp 15")
	# Godot keeps a scale of 0 at 0.00001.
	t.ok(box.scale.x < 0.01, "hộp chờ bật vào")
	t.ok(rays.scale.x < 0.01, "tia chờ nở")
	t.ok(((rays as CanvasItem).material as ShaderMaterial).shader.resource_path.ends_with("candy_rays.gdshader"), "tia kẹo")
	t.ok(rays.show_behind_parent, "tia nằm sau đường và mốc")
	await _wait(2.0)
	t.eq(box.scale, Vector2.ONE, "hộp bật vào xong")
	t.near(box.rotation, 0.0, 0.0001, "lắc xong thì đứng thẳng")
	t.eq(rays.scale, Vector2.ONE, "tia nở xong")
	t.eq(chip.scale, Vector2.ONE, "chip về cỡ sau cú dẹt")
	t.eq(float(rt.get("_chip_shown")), -1.0, "thanh chip chạy xong")
	var track: Control = rt.find_child("ChipTrack", true, false)
	var fill: Control = rt.find_child("ChipFill", true, false)
	t.near(fill.size.x, track.size.x * 12.0 / 15.0, 0.5, "thanh đúng 12/15")
	var sc: ScrollContainer = rt.get("map_scroll")
	var v := sc.scroll_vertical
	rt.call("_scroll_to_current")
	t.eq(sc.scroll_vertical, v, "cuộn xong đúng chỗ mốc hiện tại")
	rt.free()


func test_main_closes_popups_and_fades_screens(t: T) -> void:
	var g: Node = _tree().root.get_node("Game")
	g.reset_for_test(DIR + "/main.json")
	var m := (load("res://scenes/main.tscn") as PackedScene).instantiate() as Control
	_tree().root.add_child(m)
	var deadline := Time.get_ticks_msec() + 6000
	while not m.is_booted and Time.get_ticks_msec() < deadline:
		await _tree().process_frame
	t.ok(m.is_booted, "boot xong")
	g.s.level = 30
	m.go("home")
	await _wait(UiTween.FADE_SEC + 0.1)
	for c in m.popup_layer.get_children():
		c.free()
	var home: Control = m.current_screen
	m.go("profile")
	var profile: Control = m.current_screen
	t.ok(is_instance_valid(home) and not home.is_queued_for_deletion(), "Home còn trong lúc mờ chéo")
	t.ok(profile.modulate.a < 0.5, "Profile hiện dần")
	t.ok(m.get_node_or_null("SlideBlock") != null, "chặn chạm lúc chuyển")
	await _wait(UiTween.FADE_SEC + 0.1)
	t.ok(not is_instance_valid(home) or home.is_queued_for_deletion(), "xong thì bỏ Home")
	t.eq(profile.modulate.a, 1.0, "Profile rõ hẳn")
	t.ok(m.get_node_or_null("SlideBlock") == null, "hết chặn chạm")
	m.go("home")
	await _wait(UiTween.FADE_SEC + 0.1)
	# Two popups: closing the top one leaves it in the layer for its close, but Main only counts the one below.
	var low: Node = m.open_popup("res://scenes/settings.tscn")
	var high: Node = m.open_popup("res://scenes/settings.tscn")
	t.eq(m.popup_count(), 2, "hai popup")
	await _wait(0.5)
	high.emit_signal("closed", null)
	t.ok(is_instance_valid(high) and UiTween.closing(high), "popup trên đang đóng")
	t.eq(m.popup_count(), 1, "chỉ còn popup dưới")
	t.eq(m.call("_top_popup"), low, "Back tới popup dưới")
	await _wait(UiTween.CLOSE_SEC + 0.1)
	t.ok(not is_instance_valid(high) or high.is_queued_for_deletion(), "đóng xong thì gỡ")
	low.emit_signal("closed", null)
	await _wait(UiTween.CLOSE_SEC + 0.1)
	t.eq(m.popup_count(), 0, "hết popup")
	m.free()


func test_home_icons_nudge_and_dots_beat(t: T) -> void:
	var g := _g()
	g.s.level = 30
	var home := (load("res://scenes/home.tscn") as PackedScene).instantiate() as Control
	_tree().root.add_child(home)
	home.call("setup", {})
	var gift_icon: Control = (home.get("gift_btn") as Node).get_node("Icon")
	var m: Node = gift_icon.get_node_or_null(UiMotion.NODE_NAME)
	t.ok(m != null, "icon cột có motion")
	var dot: Control = home.get("chain_dot")
	var dm: Node = dot.get_node_or_null(UiMotion.NODE_NAME)
	t.ok(dm != null and dm.kind == UiMotion.BADGE, "chấm đỏ đập")
	(home.get("gift_badge") as Control).visible = true
	home.call("_refresh_idle")
	t.eq(m.kind, UiMotion.WOBBLE, "có quà thì lắc")
	(home.get("gift_badge") as Control).visible = false
	home.call("_refresh_idle")
	t.eq(m.kind, UiMotion.NUDGE, "hết quà thì nhún")
	await _tree().process_frame
	var play: Control = home.get("play_btn")
	t.ok(play.has_meta(UiTween.META_POP), "vào Home thì nút Chơi bật vào")
	home.free()
