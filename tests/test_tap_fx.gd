extends RefCounted
## Chạm màn hình: vòng tròn và sao nhỏ ở điểm chạm, mỗi lần chạm đếm một lần, tự tắt, không chặn chạm.
const T := preload("res://tests/t.gd")
const TapFx := preload("res://src/ui/tap_fx.gd")
const Config := preload("res://src/config.gd")


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _wait_until(cond: Callable, ms: int = 3000) -> bool:
	var deadline := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await _tree().process_frame
	return cond.call()


func _touch(pressed: bool, at: Vector2, device: int = 0) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.pressed = pressed
	e.position = at
	e.device = device
	return e


func _click(pressed: bool, at: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT, device: int = 0) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.pressed = pressed
	e.position = at
	e.button_index = button
	e.device = device
	return e


func test_tap_point_counts_each_touch_once(t: T) -> void:
	var at := Vector2(120, 340)
	t.eq(TapFx.tap_point(_touch(true, at)), at, "chạm xuống")
	t.eq(TapFx.tap_point(_touch(false, at)), null, "nhấc tay")
	t.eq(TapFx.tap_point(_click(true, at)), at, "click trái")
	t.eq(TapFx.tap_point(_click(false, at)), null, "nhả chuột")
	t.eq(TapFx.tap_point(_click(true, at, MOUSE_BUTTON_RIGHT)), null, "chuột phải")
	t.eq(TapFx.tap_point(_click(true, at, MOUSE_BUTTON_LEFT, InputEvent.DEVICE_ID_EMULATION)), null,
		"click giả lập từ chạm")
	t.eq(TapFx.tap_point(_touch(true, at, InputEvent.DEVICE_ID_EMULATION)), null, "chạm giả lập từ chuột")
	var key := InputEventKey.new()
	key.pressed = true
	t.eq(TapFx.tap_point(key), null, "phím")


func test_spawn_runs_then_stops(t: T) -> void:
	var fx := TapFx.new()
	_tree().root.add_child(fx)
	t.eq(fx.active_count(), 0, "chưa có")
	t.ok(not fx.is_processing(), "không chạy khi trống")
	fx.spawn(Vector2(200, 400))
	t.eq(fx.active_count(), 1, "một hiệu ứng")
	t.ok(fx.is_processing(), "đang chạy")
	var ms := int(float(Config.CONTENT.tap_fx_sec) * 1000.0) + 1000
	t.ok(await _wait_until(func() -> bool: return fx.active_count() == 0, ms), "tự tắt sau tap_fx_sec")
	t.ok(not fx.is_processing(), "ngừng chạy khi hết")
	for i in TapFx.MAX_TAPS + 3:
		fx.spawn(Vector2(10 * i, 10 * i))
	t.eq(fx.active_count(), TapFx.MAX_TAPS, "chạm dồn dập giữ tối đa MAX_TAPS")
	fx.free()


func test_input_spawns_without_consuming(t: T) -> void:
	var vp := _tree().root
	var pad := Control.new()
	pad.position = Vector2.ZERO  # input is mapped through the 886×1920 stretch, so cover far past the window
	pad.size = Vector2(4000, 4000)
	var got: Array[InputEvent] = []
	pad.gui_input.connect(func(e: InputEvent) -> void: got.append(e))
	vp.add_child(pad)
	var fx := TapFx.new()
	vp.add_child(fx)
	vp.push_input(_touch(true, Vector2(20, 20)))
	t.eq(fx.active_count(), 1, "chạm tạo hiệu ứng")
	vp.push_input(_click(true, Vector2(20, 20)))
	t.eq(fx.active_count(), 2, "click tạo hiệu ứng")
	t.ok(got.any(func(e: InputEvent) -> bool: return e is InputEventMouseButton and e.pressed),
		"Control dưới điểm chạm vẫn nhận click")
	vp.push_input(_click(true, Vector2(20, 20), MOUSE_BUTTON_LEFT, InputEvent.DEVICE_ID_EMULATION))
	t.eq(fx.active_count(), 2, "click giả lập không tạo thêm")
	fx.free()
	pad.free()


func test_main_has_tap_fx_on_top(t: T) -> void:
	var m := (load("res://scenes/main.tscn") as PackedScene).instantiate() as Control
	_tree().root.add_child(m)
	var fx := m.get_node_or_null("TapFx") as CanvasLayer
	t.ok(fx != null, "main có lớp TapFx")
	if fx != null:
		t.ok(fx.layer > 0, "nằm trên lớp UI")
		t.eq(fx.process_mode, Node.PROCESS_MODE_ALWAYS, "chạy cả khi tạm dừng")
	await _wait_until(func() -> bool: return m.is_booted, 6000)
	m.free()
