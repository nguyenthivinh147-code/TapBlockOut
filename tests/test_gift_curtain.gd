extends RefCounted
## Màn chuyển cảnh nắp hộp quà của Road Trip (gift_curtain.gd, design.md mục 2): phủ kín màn ở mọi tỉ lệ, logo nằm
## trên nắp phía trên nơ, mở xong tự giải phóng; Road Trip dùng nó khi vào level và khi về bản đồ.
const T := preload("res://tests/t.gd")
const MockIap := preload("res://src/platform/mock_iap.gd")
const GiftCurtain := preload("res://src/ui/gift_curtain.gd")

const DIR := "user://test_gift_curtain"
const NOW := 1800000000


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _wait_until(cond: Callable, ms: int = 8000) -> bool:
	var deadline := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await _tree().process_frame
	return cond.call()


## Curtain inside a host of size s. The curtain fills its parent; its size follows the anchors after _ready, and
## resized lays it out again.
func _make(s: Vector2) -> Array:
	var host := Control.new()
	host.size = s
	_tree().root.add_child(host)
	var c := GiftCurtain.new()
	host.add_child(c)
	await _tree().process_frame
	return [host, c]


## Rect of a child of the lid, in curtain coordinates, with the lid at y.
func _in_curtain(c: Control, n: Control, lid_y: float) -> Rect2:
	return Rect2(c._lid.position.x + n.position.x, lid_y + n.position.y, n.size.x, n.size.y)


func _check_cover(t: T, c: Control, s: Vector2, tag: String) -> void:
	var lid := Rect2(Vector2(c._lid.position.x, c._lid_y.x), c._lid.size)
	var body := Rect2(Vector2(c._body.position.x, c._body_y.x), c._body.size)
	t.ok(lid.position.x <= 0.0 and lid.end.x >= s.x, tag + ": nắp phủ hết bề ngang")
	t.ok(body.position.x <= 0.0 and body.end.x >= s.x, tag + ": thân phủ hết bề ngang")
	t.ok(lid.position.y <= -float(GiftCurtain.LID_BUMP) * c._k, tag + ": nắp phủ mép trên, cả lúc nhún")
	t.ok(body.end.y >= s.y, tag + ": thân phủ mép dưới")
	t.ok(lid.end.y > body.position.y, tag + ": nắp đè lên mép thân, không hở")
	t.ok(c._lid_y.y + c._lid.size.y < 0.0, tag + ": nắp ẩn trên mép trên")
	var bow := _in_curtain(c, c._bow, c._lid_y.y)
	t.ok(bow.end.y <= 0.0, tag + ": nơ ẩn cùng nắp")
	t.ok(c._body_y.y >= s.y, tag + ": thân ẩn dưới mép dưới")
	bow = _in_curtain(c, c._bow, c._lid_y.x)
	t.near(bow.get_center().x, s.x * 0.5, 1.0, tag + ": nơ ở giữa")
	t.ok(bow.position.y < lid.end.y and bow.end.y > lid.end.y, tag + ": nơ đè lên mép nối")
	t.ok(c._logo.get_parent() == c._lid, tag + ": logo nằm trên nắp, đi theo nắp")
	var logo := _in_curtain(c, c._logo, c._lid_y.x)
	t.ok(logo.position.x >= 0.0 and logo.end.x <= s.x and logo.position.y >= 0.0, tag + ": logo trong màn")
	t.ok(logo.end.y <= bow.position.y, tag + ": logo trên nắp, phía trên nơ")
	t.ok(logo.size.x >= s.x * 0.25, tag + ": logo đủ to")


func test_layout_covers_every_aspect(t: T) -> void:
	for s: Vector2 in [Vector2(886, 1920), Vector2(886, 2200), Vector2(1440, 1920), Vector2(886, 1500)]:
		var made: Array = await _make(s)
		t.eq((made[1] as Control).size, s, "cỡ theo node cha")
		_check_cover(t, made[1], s, "%dx%d" % [int(s.x), int(s.y)])
		(made[0] as Node).free()


## Nắp xuất phát khi thân đi được gift_lid_at quãng đường, logo bật khi nắp rơi được gift_logo_at quãng đường: đổi
## quãng ra thời gian theo đường cong easing.
func test_time_at_way(t: T) -> void:
	t.near(GiftCurtain.time_at(0.3, Tween.TRANS_QUART, Tween.EASE_OUT), 1.0 - pow(0.7, 0.25), 0.0005, "thân 30% quãng")
	t.near(GiftCurtain.time_at(0.5, Tween.TRANS_QUAD, Tween.EASE_IN), sqrt(0.5), 0.0005, "nắp 50% quãng")
	t.near(GiftCurtain.time_at(0.0, Tween.TRANS_QUAD, Tween.EASE_IN), 0.0, 0.0005, "0")
	t.near(GiftCurtain.time_at(1.0, Tween.TRANS_QUAD, Tween.EASE_IN), 1.0, 0.0005, "1")


func test_close_then_open(t: T) -> void:
	var s := Vector2(886, 1920)
	var made: Array = await _make(s)
	var c: Control = made[1]
	t.eq(c.mouse_filter, Control.MOUSE_FILTER_STOP, "chặn chạm")
	t.ok(c._lid.position.y < 0.0, "bắt đầu: nắp ngoài màn")
	t.eq(c._logo.modulate.a, 0.0, "bắt đầu: logo ẩn")
	await c.close()
	t.near(c._body.position.y, c._body_y.x, 0.5, "thân vào chỗ")
	t.ok(c._lid.position.y >= c._lid_y.x - 0.5, "nắp chạm thân")
	# The lid lands before the body has eased its last pixels in, so the bump is already under way.
	t.ok(c._lid.position.y > c._lid_y.x + 0.5 or not c._bow.scale.is_equal_approx(Vector2.ONE), "chạm thân là nhún ngay")
	t.ok(c._logo.modulate.a > 0.0, "logo đã bắt đầu hiện khi nắp còn đang rơi")
	t.ok(await _wait_until(func() -> bool: return is_equal_approx(c._lid.position.y, c._lid_y.x) \
		and c._bow.scale.is_equal_approx(Vector2.ONE) and c._logo.modulate.a > 0.99, 3000), "nắp nhún xong, nơ hết bẹp, logo hiện")
	await c.open()
	t.ok(c.is_queued_for_deletion(), "mở xong tự giải phóng")
	t.ok(c._lid.position.y <= c._lid_y.y + 0.5 and c._body.position.y >= c._body_y.y - 0.5, "nắp và thân ra khỏi màn")
	(made[0] as Node).free()


func _g() -> Node:
	DirAccess.make_dir_recursive_absolute(DIR)
	var g: Node = _tree().root.get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	g.test_now = NOW
	g.test_tz = 0
	var p: Node = _tree().root.get_node("Platform")
	p.ads.calls.clear()
	p.ads.set_ready(true, true)
	p.iap = MockIap.new()
	g.s.level = 20
	g.s.road_trip.level = 15
	g.s.road_trip.guide = true
	for k in ["hint", "move", "smash"]:
		g.s.gifted[k] = true
	return g


func test_road_trip_uses_gift_curtain(t: T) -> void:
	var g := _g()
	var m := (load("res://scenes/main.tscn") as PackedScene).instantiate() as Control
	_tree().root.add_child(m)
	t.ok(await _wait_until(func() -> bool: return m.is_booted), "boot xong")
	g.s.level = 100  # Road Trip mở từ L95 (Config.UNLOCK.road_trip)
	g.s.road_trip.level = 15
	m.go("road_trip")
	await _wait_until(func() -> bool: return m.get("_slide_out") == null)
	var rt: Control = m.current_screen
	t.eq(m.current_name, "road_trip", "màn Road Trip")
	rt.play_button.pressed.emit()
	t.ok(m.curtain != null and m.curtain.get_script() == GiftCurtain, "Level: màn nắp hộp quà")
	t.ok(rt.level_node == null, "level dựng sau khi nắp đóng")
	t.ok(await _wait_until(func() -> bool: return rt.level_node != null and m.curtain == null), "vào level")
	(rt.level_node as Control).emit_signal("closed", {"action": "home"})
	t.ok(m.curtain != null and m.curtain.get_script() == GiftCurtain, "về bản đồ: màn nắp hộp quà")
	t.ok(await _wait_until(func() -> bool: return rt.level_node == null and m.curtain == null), "về bản đồ")
	m.free()
