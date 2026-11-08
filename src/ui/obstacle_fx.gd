extends RefCounted
## Hiệu ứng va chạm và mất vật cản theo chất liệu: thùng sắt, pudding, xích, hộp giấy, khối crystal.
## Mọi hạt nằm trên mọi thứ (`top_level`), toạ độ canvas, tự xoá khi xong. Cỡ và tốc độ theo cỡ ô (`cell / 42`).

const BoardFx := preload("res://src/ui/board_fx.gd")

const JELLY := Color(1.0, 0.86, 0.92)
const JELLY_DEEP := Color("F07AA8")
const STEEL := Color("DDE3F0")
const SPARK_HOT := Color("FFE27A")
const KRAFT := Color("C99A63")
const TAPE := Color("FFF2D6")
const LOCK_POP_TIME := 0.55
const CRYSTAL_HIT_SIZE := 0.6  # cỡ và tầm bay hiệu ứng khối crystal va, so với mảnh kính lúc qua thanh hay bị búa gõ

static var _tex: Dictionary = {}  # tên -> Texture2D dựng bằng code


## Thùng sắt bị va: tia lửa thép toé ngược về phía khối va rồi rơi, vài tia đỏ cam nặng rơi sớm,
## loé trắng xanh với vòng sóng rõ (tiếng "keng"), sao bạc nhỏ.
static func iron_hit(parent: Node, pos: Vector2, out_dir: Vector2, cell: float, strength: float = 1.0) -> void:
	var k := cell / 42.0 * strength
	_emit(parent, pos, "streak", {"name": "IronSparks", "amount": int(round(12 * strength)), "lifetime": 0.4,
		"dir": out_dir, "spread": 75.0, "v": Vector2(260, 640) * k, "gravity": 1500.0 * k, "damping": Vector2(200, 450),
		"scale": Vector2(0.45, 0.95) * k, "align": true, "add": true,
		"ramp": [Color.WHITE, SPARK_HOT, Color(1.0, 0.45, 0.1, 0.0)], "box": cell * 0.08})
	_emit(parent, pos, "streak", {"amount": int(round(5 * strength)), "lifetime": 0.55, "dir": out_dir, "spread": 50.0,
		"v": Vector2(140, 320) * k, "gravity": 1800.0 * k, "scale": Vector2(0.35, 0.6) * k, "align": true, "add": true,
		"ramp": [SPARK_HOT, Color(1.0, 0.4, 0.12), Color(0.8, 0.2, 0.05, 0.0)], "box": cell * 0.06})
	BoardFx.impact_flash(parent, pos, STEEL, cell * 1.9 * strength, 0.24, 0.95)
	BoardFx.sparkles(parent, pos, {"stripe": BoardFx.IRON_LIGHT}, out_dir, cell / 130.0, 3)


## Khối crystal va hoặc bị va (tiếng "ting" thuỷ tinh): mảnh kính lấp lánh toé ngược ra rồi rơi, loé trắng lạnh pha màu
## khối với vòng sóng rõ, sao lấp lánh. `ramp` là bốn tông của khối crystal.
static func crystal_hit(parent: Node, pos: Vector2, out_dir: Vector2, cell: float, ramp: Dictionary, strength: float = 1.0) -> void:
	crystal_glints(parent, pos, out_dir, cell, ramp, strength, 80.0, CRYSTAL_HIT_SIZE)
	var icy: Color = (ramp["stripe"] as Color).lerp(Color.WHITE, 0.55)
	BoardFx.impact_flash(parent, pos, icy, cell * 2.1 * CRYSTAL_HIT_SIZE * strength, 0.3, 1.0)
	BoardFx.sparkles(parent, pos, {"stripe": icy}, out_dir, cell / 100.0 * CRYSTAL_HIT_SIZE * strength, int(round(6 * strength)))


## Mảnh kính crystal nhỏ hình thoi, cộng sáng, vừa bay vừa lật và loé theo màu khối; không loé quầng (dùng cả lúc
## khối crystal thoát qua thanh, vốn không loé). `size` thu cỡ mảnh và tầm bay, không đổi số mảnh.
static func crystal_glints(parent: Node, pos: Vector2, out_dir: Vector2, cell: float, ramp: Dictionary, strength: float = 1.0, spread: float = 80.0, size: float = 1.0) -> void:
	var k := cell / 42.0 * strength * size
	var p := _emit(parent, pos, "gem", {"name": "CrystalGlints", "amount": int(round(10 * strength)), "lifetime": 0.5,
		"dir": out_dir, "spread": spread, "v": Vector2(200, 560) * k, "gravity": 1100.0 * k, "damping": Vector2(120, 320),
		"scale": Vector2(0.45, 1.0) * k, "add": true,
		"ramp": [Color.WHITE, (ramp["stripe"] as Color).lerp(Color.WHITE, 0.3), Color(ramp["face"], 0.0)], "box": cell * 0.1 * size})
	p.angular_velocity_min = -900.0
	p.angular_velocity_max = 900.0


## Khối phủ pudding bị va: vài giọt pudding bắn ra, loé hồng.
static func jelly_hit(parent: Node, pos: Vector2, out_dir: Vector2, cell: float) -> void:
	var k := cell / 42.0
	_emit(parent, pos, "blob", {"name": "JellyDrops", "amount": 6, "lifetime": 0.5, "dir": out_dir, "spread": 70.0,
		"v": Vector2(140, 320) * k, "gravity": 1000.0 * k, "scale": Vector2(0.22, 0.42) * k,
		"ramp": [JELLY, Color(JELLY_DEEP, 0.0)], "box": cell * 0.1})
	BoardFx.impact_flash(parent, pos, JELLY_DEEP, cell * 1.5, 0.3, 0.85)


## Lớp pudding vỡ: bọt pudding toả tròn, giọt nhỏ bắn xa, loé hồng lớn với vòng sóng, sao lấp lánh.
## `span` là cỡ khung khối (px).
static func jelly_burst(parent: Node, center: Vector2, cell: float, span: Vector2) -> void:
	var k := cell / 42.0
	_emit(parent, center, "blob", {"name": "JellyBurst", "amount": 16, "lifetime": 0.75, "dir": Vector2.UP, "spread": 180.0,
		"v": Vector2(160, 420) * k, "gravity": 900.0 * k, "damping": Vector2(40, 120), "scale": Vector2(0.35, 0.8) * k,
		"ramp": [Color.WHITE, JELLY, Color(JELLY_DEEP, 0.0)], "box": span * 0.4})
	_emit(parent, center, "blob", {"amount": 14, "lifetime": 0.55, "dir": Vector2.UP, "spread": 180.0,
		"v": Vector2(380, 720) * k, "gravity": 1300.0 * k, "damping": Vector2(200, 400), "scale": Vector2(0.12, 0.22) * k,
		"ramp": [Color.WHITE, Color(JELLY_DEEP, 0.0)], "box": span * 0.3, "add": true})
	BoardFx.impact_flash(parent, center, JELLY_DEEP, maxf(span.x, span.y) + cell * 2.2, 0.42, 0.95)
	BoardFx.sparkles(parent, center, {"stripe": JELLY_DEEP}, Vector2.UP, cell / 95.0, 8)


## Xích bị va hay bị giật: tia lửa thép toả nhanh, loé trắng nhỏ.
static func chain_rattle(parent: Node, pos: Vector2, cell: float) -> void:
	var k := cell / 42.0
	_emit(parent, pos, "streak", {"name": "ChainSparks", "amount": 9, "lifetime": 0.32, "dir": Vector2.UP, "spread": 180.0,
		"v": Vector2(260, 620) * k, "gravity": 800.0 * k, "damping": Vector2(200, 500), "scale": Vector2(0.5, 0.9) * k,
		"align": true, "add": true, "ramp": [Color.WHITE, SPARK_HOT, Color(1.0, 0.5, 0.1, 0.0)], "box": cell * 0.15})
	BoardFx.impact_flash(parent, pos, STEEL, cell * 1.3, 0.2, 0.5)


## Xích đứt: mắt xích văng tung rồi rơi xoay, tia lửa vàng, loé vàng lớn, ổ khoá bật quai bay lên.
## `span` là cỡ khung khối (px), `lock_at` tâm ổ khoá.
static func chain_break(parent: Node, center: Vector2, cell: float, span: Vector2, lock_at: Vector2) -> void:
	var k := cell / 42.0
	var links := _emit(parent, center, "link", {"name": "ChainLinks", "amount": 12, "lifetime": 0.85, "dir": Vector2.UP,
		"spread": 180.0, "v": Vector2(140, 400) * k, "gravity": 1300.0 * k, "scale": Vector2(0.5, 0.7) * k,
		"ramp": [Color.WHITE, STEEL, Color(STEEL, 0.0)], "box": span * 0.45})
	links.angular_velocity_min = -720.0
	links.angular_velocity_max = 720.0
	_emit(parent, lock_at, "streak", {"amount": 12, "lifetime": 0.4, "dir": Vector2.UP, "spread": 180.0,
		"v": Vector2(300, 760) * k, "gravity": 900.0 * k, "damping": Vector2(200, 500), "scale": Vector2(0.6, 1.0) * k,
		"align": true, "add": true, "ramp": [Color.WHITE, BoardFx.LOCK_GOLD, Color(1.0, 0.55, 0.1, 0.0)]})
	BoardFx.impact_flash(parent, lock_at, BoardFx.LOCK_GOLD, maxf(span.x, span.y) + cell * 2.2, 0.4, 0.9)
	BoardFx.sparkles(parent, lock_at, {"stripe": BoardFx.LOCK_GOLD}, Vector2.UP, cell / 95.0, 8)
	_lock_pop(parent, lock_at, cell)


## Hộp giấy bị va: bụi giấy và hai ba mẩu giấy bay lả.
static func paper_hit(parent: Node, pos: Vector2, out_dir: Vector2, cell: float, tint: Color) -> void:
	var k := cell / 42.0
	_emit(parent, pos, "puff", {"name": "PaperDust", "amount": 5, "lifetime": 0.45, "dir": out_dir, "spread": 110.0,
		"v": Vector2(30, 90) * k, "gravity": -30.0 * k, "damping": Vector2(60, 120), "scale": Vector2(0.4, 0.8) * k,
		"grow": true, "ramp": [Color(KRAFT.lightened(0.3), 0.6), Color(KRAFT, 0.0)], "box": cell * 0.15})
	_confetti(parent, pos, out_dir, cell, tint, 3, 0.6)
	BoardFx.impact_flash(parent, pos, KRAFT.lightened(0.35), cell * 1.3, 0.24, 0.5)


## Hộp giấy rách tung ở thanh cổng: giấy vụn bay lả theo `dir`, bụi giấy, loé theo màu hộp, sao lấp lánh.
static func paper_burst(parent: Node, pos: Vector2, dir: Vector2, cell: float, tint: Color, span: float) -> void:
	_confetti(parent, pos, dir, cell, tint, 22, 1.0, span)
	var k := cell / 42.0
	_emit(parent, pos, "puff", {"amount": 6, "lifetime": 0.5, "dir": dir, "spread": 80.0,
		"v": Vector2(60, 160) * k, "damping": Vector2(100, 200), "scale": Vector2(0.6, 1.0) * k, "grow": true,
		"ramp": [Color(TAPE, 0.65), Color(KRAFT, 0.0)], "box": Vector2(span, span) * 0.35})
	BoardFx.impact_flash(parent, pos, tint.lightened(0.3), span + cell * 1.6, 0.34, 0.8)
	BoardFx.sparkles(parent, pos, {"stripe": tint.lightened(0.3)}, dir, cell / 100.0, 6)


static func _confetti(parent: Node, pos: Vector2, dir: Vector2, cell: float, tint: Color, amount: int, power: float, span: float = 0.0) -> void:
	var k := cell / 42.0 * power
	var p := _emit(parent, pos, "paper", {"name": "PaperBits", "amount": amount, "lifetime": 0.9, "dir": dir, "spread": 75.0,
		"v": Vector2(200, 520) * k, "gravity": 380.0 * cell / 42.0, "damping": Vector2(300, 520),
		"scale": Vector2(0.6, 1.1) * cell / 42.0, "ramp": [Color.WHITE, Color.WHITE, Color(1, 1, 1, 0.0)],
		"box": Vector2(span, span) * 0.3})
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	var g := Gradient.new()
	g.set_color(0, tint)
	g.set_color(1, TAPE)
	g.add_point(0.5, KRAFT)
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	p.color_initial_ramp = g


## Ổ khoá bật quai, phóng to, xoay và bay lên rồi mờ đi.
static func _lock_pop(parent: Node, at: Vector2, cell: float) -> void:
	var lock := LockPop.new()
	lock.cell = cell
	parent.add_child(lock)
	lock.global_position = at
	var tw := lock.create_tween().set_parallel(true)
	tw.tween_property(lock, "open", 1.0, 0.12)
	tw.tween_property(lock, "scale", Vector2(1.6, 1.6), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lock, "global_position", at + Vector2(cell * 0.3, -cell * 0.9), LOCK_POP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lock, "rotation", 0.5, LOCK_POP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lock, "modulate:a", 0.0, 0.22).set_delay(LOCK_POP_TIME - 0.22)
	tw.chain().tween_callback(lock.queue_free)


class LockPop extends Node2D:
	const BoardFx := preload("res://src/ui/board_fx.gd")
	var cell: float = 42.0
	var open: float = 0.0:
		set(v):
			open = v
			queue_redraw()

	func _init() -> void:
		name = "LockPop"
		top_level = true

	func _draw() -> void:
		BoardFx.draw_lock(self, Vector2.ZERO, cell, open)


## Dựng một bộ hạt một lượt từ bảng tham số: name, amount, lifetime, dir, spread, v (min, max), gravity (hướng xuống),
## damping (min, max), scale (min, max), grow (cỡ to dần thay vì nhỏ dần), align (xoay theo hướng bay), add (cộng sáng),
## ramp (dải màu theo tuổi hạt), box (nửa cỡ vùng phát, số hoặc Vector2).
static func _emit(parent: Node, pos: Vector2, tex_name: String, o: Dictionary) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = str(o.get("name", "ObstacleFx"))
	p.top_level = true
	p.one_shot = true
	p.amount = maxi(1, int(o.get("amount", 8)))
	p.lifetime = float(o.get("lifetime", 0.5))
	p.explosiveness = 1.0
	p.randomness = 0.4
	p.texture = texture(tex_name)
	p.direction = o.get("dir", Vector2.UP)
	p.spread = float(o.get("spread", 60.0))
	var v: Vector2 = o.get("v", Vector2(100, 200))
	p.initial_velocity_min = v.x
	p.initial_velocity_max = v.y
	p.gravity = Vector2(0.0, float(o.get("gravity", 0.0)))
	var damp: Vector2 = o.get("damping", Vector2.ZERO)
	p.damping_min = damp.x
	p.damping_max = damp.y
	var sc: Vector2 = o.get("scale", Vector2(0.5, 1.0))
	p.scale_amount_min = sc.x
	p.scale_amount_max = sc.y
	p.scale_amount_curve = _grow_curve() if bool(o.get("grow", false)) else BoardFx.shrink_curve()
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.particle_flag_align_y = bool(o.get("align", false))
	var box: Variant = o.get("box", 0.0)
	var ext: Vector2 = box if box is Vector2 else Vector2(float(box), float(box))
	if ext.x > 0.5 or ext.y > 0.5:
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = ext
	var cols: Array = o.get("ramp", [Color.WHITE, Color(1, 1, 1, 0)])
	var g := Gradient.new()
	g.set_color(0, cols[0])
	g.set_color(1, cols[-1])
	for i in range(1, cols.size() - 1):
		g.add_point(float(i) / (cols.size() - 1), cols[i])
	p.color_ramp = g
	if bool(o.get("add", false)):
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		p.material = mat
	p.finished.connect(p.queue_free)
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	return p


static func _grow_curve() -> Curve:
	if not _tex.has("_grow"):
		var c := Curve.new()
		c.add_point(Vector2(0.0, 0.4))
		c.add_point(Vector2(1.0, 1.0))
		_tex["_grow"] = c
	return _tex["_grow"]


## Hình hạt trắng dựng một lần bằng code, tô màu bằng `color` của hạt: puff (bụi mềm),
## blob (giọt pudding có vệt bóng), streak (tia lửa), link (mắt xích), paper (mẩu giấy có nếp gấp),
## gem (mảnh crystal hình thoi hai mặt sáng tối, tâm loé).
static func texture(tex_name: String) -> Texture2D:
	if _tex.has(tex_name):
		return _tex[tex_name]
	var sz: Vector2i = {"puff": Vector2i(32, 32), "blob": Vector2i(32, 32),
		"streak": Vector2i(6, 28), "link": Vector2i(28, 18), "paper": Vector2i(16, 12),
		"gem": Vector2i(16, 24)}.get(tex_name, Vector2i(16, 16))
	var img := Image.create(sz.x, sz.y, false, Image.FORMAT_RGBA8)
	for y in sz.y:
		for x in sz.x:
			var u := (Vector2(x, y) + Vector2(0.5, 0.5)) / Vector2(sz) * 2.0 - Vector2.ONE  # -1..1
			img.set_pixel(x, y, _texel(tex_name, u))
	var t := ImageTexture.create_from_image(img)
	_tex[tex_name] = t
	return t


static func _texel(tex_name: String, u: Vector2) -> Color:
	match tex_name:
		"puff":
			return Color(1, 1, 1, clampf(exp(-u.length_squared() * 3.0) * 1.2 - 0.05, 0.0, 1.0))
		"blob":
			var r := u.length()
			var a := clampf((0.92 - r) * 12.0, 0.0, 1.0)
			var shade := 0.82 + 0.18 * clampf(1.0 - r, 0.0, 1.0)
			var spec := exp(-(u - Vector2(-0.35, -0.38)).length_squared() * 30.0)
			var rim := clampf((r - 0.7) * 4.0, 0.0, 1.0) * 0.25
			var v := clampf(shade + spec + rim, 0.0, 1.0)
			return Color(v, v, v, a * (0.8 + 0.2 * spec))
		"streak":
			var a := clampf(1.0 - absf(u.x) * 1.4, 0.0, 1.0) * clampf(1.0 - absf(u.y), 0.0, 1.0)
			return Color(1, 1, 1, a)
		"link":
			var e := Vector2(u.x, u.y * 1.0).length()
			var ring := clampf(1.0 - absf(e - 0.72) * 6.0, 0.0, 1.0)
			var lit := 0.75 + 0.25 * clampf(-u.y - u.x * 0.3, -1.0, 1.0)
			return Color(lit, lit, lit, ring)
		"paper":
			var a := 1.0 if absf(u.x) < 0.94 and absf(u.y) < 0.9 else 0.0
			var fold := 0.85 if u.x > 0.1 else 1.0
			return Color(fold, fold, fold, a)
		"gem":
			var e := absf(u.x) + absf(u.y)
			var a := clampf((0.96 - e) * 10.0, 0.0, 1.0)
			var face := 1.0 if u.x < 0.0 else 0.62
			var core := exp(-(u - Vector2(-0.18, -0.2)).length_squared() * 18.0)
			var v := clampf(face * 0.8 + core * 0.6, 0.0, 1.0)
			return Color(v, v, v, a)
	return Color.WHITE
