extends RefCounted
## Cracked screen glass of a Special Bomb blast (src/ui/glass_crack.gd, design.md section 7 "Màn đặc biệt").

const T := preload("res://tests/t.gd")
const GlassCrack := preload("res://src/ui/glass_crack.gd")

const AREA := Vector2(886, 1920)


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _wait_until(cond: Callable, ms: int = 4000) -> bool:
	var deadline := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await _tree().process_frame
	return cond.call()


## Cracks that run off the screen (each ray ends with one, forks may add more).
func _off_screen(g: Control) -> int:
	var screen := Rect2(Vector2.ZERO, AREA)
	var n := 0
	for s in g.segments:
		if not screen.has_point(s[1]):
			n += 1
	return n


func test_web_reaches_edges(t: T) -> void:
	for seed_value in [1, 7, 42, 99, 1234]:
		for at in [AREA * 0.5, Vector2(120, 1500), Vector2(800, 300)]:
			var g := GlassCrack.new()
			g.setup(AREA, at, 1.0, seed_value)
			t.ok(g.segments.size() > 150, "nhiều vết nứt (seed %d)" % seed_value)
			t.ok(_off_screen(g) >= GlassCrack.RAYS_MIN, "mọi tia nứt chạy ra tới mép màn (seed %d)" % seed_value)
			t.ok(g.shards.size() >= 2, "có mảnh kính lệch (seed %d)" % seed_value)
			for s in g.shards:
				t.ok((s.indices as PackedInt32Array).size() >= 3 and (s.indices as PackedInt32Array).size() % 3 == 0,
					"mảnh kính chia tam giác được")
				t.eq((s.colors as PackedColorArray).size(), (s.points as PackedVector2Array).size(), "màu theo đỉnh")
			g.free()


func test_same_seed_same_web(t: T) -> void:
	var a := GlassCrack.new()
	var b := GlassCrack.new()
	a.setup(AREA, AREA * 0.5, 1.0, 5)
	b.setup(AREA, AREA * 0.5, 1.0, 5)
	t.eq(a.segments.size(), b.segments.size(), "cùng seed cùng số vết")
	t.eq(a.segments[40][1], b.segments[40][1], "cùng seed cùng hình")
	a.free()
	b.free()


func test_spreads_holds_fades(t: T) -> void:
	var host := Control.new()
	host.size = AREA
	_tree().root.add_child(host)
	var g := GlassCrack.new()
	g.setup(host.size, Vector2(400, 1200), 0.4, 3)
	host.add_child(g)
	t.eq(g.mouse_filter, Control.MOUSE_FILTER_IGNORE, "không nhận chạm")
	t.ok(await _wait_until(func() -> bool: return g.reveal() >= 1.0, 1000), "nứt lan hết trong chốc lát")
	t.near(g.modulate.a, 1.0, 0.001, "đang giữ: chưa mờ")
	t.ok(await _wait_until(func() -> bool: return host.get_child_count() == 0, 2000), "mờ dần rồi tự xoá")
	host.free()
