extends Node
## Bom của Màn đặc biệt trên bàn (design.md mục 7 "Màn đặc biệt"). Mỗi quả là một node con của khối mang bom
## (BoardView.block_node), đặt ở ô gần trọng tâm khối, cỡ Config.SPECIAL.bomb_scale ô, nên đi theo khối khi trượt,
## nảy, qua thanh và vỡ cùng khối khi bị búa đập. Bom chưa đếm cho tới start(). Màn level gọi tick(delta) ở những
## khung được đếm (đang chơi, không popup, không búa hay sao Gợi ý đang bay, app không ở nền).
## Số trên bom = làm tròn lên số giây còn lại, chỉ đổi khi sang số nguyên khác. Còn warn_sec giây: ngòi toé lửa, bom
## phồng nhịp và đỏ dần, tiếng tích tắc mỗi giây. Gỡ (khối mang bom rời bàn): quả đó tắt hẳn, số ẩn, tiếng tách và
## lấp lánh. Nổ: explode(id) ẩn bom, mặt kính màn hình nứt vỡ (glass_crack.gd), toé mảnh kẹo, loé sáng, rung bàn và
## rung máy.

const Config := preload("res://src/config.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")
const GlassCrack := preload("res://src/ui/glass_crack.gd")

const BOMB_TEX := "res://assets/ui/special_bomb.png"
## Đầu ngòi (ngôi sao) trong ảnh bom, theo tỉ lệ khung ảnh.
const FUSE_TIP := Vector2(0.8, 0.1)
## Khung số trên thân bom (tỉ lệ khung ảnh): phần dưới cổ bom.
const LABEL_RECT := Rect2(0.04, 0.36, 0.84, 0.6)
const LABEL_SIZE := 0.34
const PULSE_HZ := 3.0
const PULSE_AMP := 0.07
const WARN_SWELL := 0.12
const WARN_RED := 0.45
const DEFUSE_DIM := 0.55
## Màu mảnh kẹo khi nổ (tông bom và các màu kẹo).
const BURST_COLORS: Array[Color] = [Color("3b2f8f"), Color("ff6fae"), Color("ffd23f"), Color("ffffff"), Color("6ee7ff")]

var started: bool = false
var _bombs: Dictionary = {}  # id -> {root, sprite, label, sparks, left, live, shown, warn}
var _order: Array[String] = []
var _tex: Texture2D = null


## Gắn bom theo kế hoạch [{id, cell: Vector2i, seconds}] lên `view` (BoardView vừa setup). Xoá bom cũ.
func setup(view: Control, plan: Array) -> void:
	clear()
	if _tex == null and ResourceLoader.exists(BOMB_TEX):
		_tex = load(BOMB_TEX)
	var cell: float = view.call("cell_size")
	var side := cell * float(Config.SPECIAL.bomb_scale)
	for b in plan:
		var id := str(b.id)
		var host: Control = view.call("block_node", id)
		if host == null:
			continue
		var root := Control.new()
		root.name = "Bomb"
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.size = Vector2(side, side)
		root.pivot_offset = root.size * 0.5
		var local := Vector2(b.cell as Vector2i) - Vector2(host.get("origin_cell") as Vector2i)
		root.position = (local + Vector2(0.5, 0.5)) * cell - root.size * 0.5
		var sprite := TextureRect.new()
		sprite.name = "Sprite"
		sprite.texture = _tex
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.add_child(sprite)
		var label := Label.new()
		label.name = "Count"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_override("font", ThemeKit.FONT)
		label.add_theme_font_size_override("font_size", maxi(12, roundi(side * LABEL_SIZE)))
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color("2a0f33"))
		label.add_theme_constant_override("outline_size", maxi(4, roundi(side / 11.0)))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.position = LABEL_RECT.position * side
		label.size = LABEL_RECT.size * side
		label.text = str(int(b.seconds))
		root.add_child(label)
		var sparks := _make_sparks(side)
		sparks.position = FUSE_TIP * side
		root.add_child(sparks)
		host.add_child(root)
		# The bomb is wider than its cell: draw its block after the other blocks so the bomb is not covered by a
		# neighbour (no z_index, which would also put it over popups).
		var parent := host.get_parent()
		if parent != null:
			parent.move_child(host, -1)
		_bombs[id] = {"root": root, "sprite": sprite, "label": label, "sparks": sparks, "left": float(b.seconds),
			"live": true, "shown": int(b.seconds), "warn": false}
		_order.append(id)


func clear() -> void:
	for id in _order:
		# The bomb is a child of its block: a block that left the board took it along, so it may be freed already.
		var root: Variant = _bombs[id].root
		if is_instance_valid(root):
			(root as Node).queue_free()
	_bombs.clear()
	_order.clear()
	started = false


func has_bomb(id: String) -> bool:
	return _bombs.has(id)


func is_live(id: String) -> bool:
	return _bombs.has(id) and bool(_bombs[id].live)


func seconds_left(id: String) -> float:
	return float(_bombs[id].left) if _bombs.has(id) else 0.0


## Bom còn đếm, gấp nhất trước.
func live_ids() -> Array[String]:
	var out: Array[String] = []
	for id in _order:
		if bool(_bombs[id].live):
			out.append(id)
	out.sort_custom(func(a: String, b: String) -> bool: return float(_bombs[a].left) < float(_bombs[b].left))
	return out


func live_count() -> int:
	return live_ids().size()


## Lần chạm hợp lệ đầu tiên: mọi bom cùng bắt đầu đếm.
func start() -> void:
	started = true


## Trừ `delta` giây ở mọi bom còn đếm. Trả id quả vừa về 0 (quả đầu theo thứ tự), "" nếu chưa quả nào.
func tick(delta: float) -> String:
	if not started:
		return ""
	var warn_sec := float(Config.SPECIAL.warn_sec)
	var t := Time.get_ticks_msec() / 1000.0
	for id in _order:
		var b: Dictionary = _bombs[id]
		if not bool(b.live):
			continue
		if not is_instance_valid(b.root):
			b.live = false
			continue
		b.left = maxf(0.0, float(b.left) - delta)
		var shown := ceili(float(b.left))
		if shown != int(b.shown):
			b.shown = shown
			(b.label as Label).text = str(shown)
			if float(b.left) <= warn_sec and shown > 0:
				Sfx.play_or("bomb_tick", "tap")
		if float(b.left) <= warn_sec:
			if not bool(b.warn):
				b.warn = true
				(b.sparks as CPUParticles2D).emitting = true
			# Phồng và đỏ dần theo (warn_sec - còn lại) / warn_sec, kèm nhịp đập.
			var k := clampf((warn_sec - float(b.left)) / warn_sec, 0.0, 1.0)
			var root: Control = b.root
			root.scale = Vector2.ONE * (1.0 + WARN_SWELL * k + PULSE_AMP * sin(t * TAU * PULSE_HZ * (1.0 + k)))
			(b.sprite as TextureRect).self_modulate = Color(1.0, 1.0 - WARN_RED * k, 1.0 - WARN_RED * k)
		if float(b.left) <= 0.0:
			return id
	return ""


## Khối mang bom rời bàn (thoát hoặc bị búa): quả đó ngừng đếm hẳn.
func defuse(id: String) -> void:
	if not is_live(id):
		return
	var b: Dictionary = _bombs[id]
	b.live = false
	(b.label as Label).visible = false
	(b.sparks as CPUParticles2D).emitting = false
	var root: Control = b.root
	root.scale = Vector2.ONE
	(b.sprite as TextureRect).self_modulate = Color(DEFUSE_DIM + 0.2, DEFUSE_DIM + 0.2, DEFUSE_DIM + 0.3)
	Sfx.play_or("bomb_defuse", "hint")
	var burst := _make_burst(root.size.x * 0.5, [Color.WHITE, Color("ffe066"), Color("ff9ad5")], 14, 0.45)
	burst.position = root.size * 0.5
	root.add_child(burst)
	burst.emitting = true


## Dừng mọi quả (thua): không đếm, không toé lửa.
func stop_all() -> void:
	for id in _order:
		var b: Dictionary = _bombs[id]
		b.live = false
		if is_instance_valid(b.sparks):
			(b.sparks as CPUParticles2D).emitting = false


## Quả `id` nổ: ẩn bom và số; trên `fx_parent` (lớp phủ của màn) mặt kính nứt toả ra từ chỗ bom, giữ tới lúc popup
## "Bùm!" hiện (boom_popup_sec) rồi mờ dần, toé mảnh kẹo và loé sáng; rung `shake` (khung bàn) và rung máy.
func explode(id: String, fx_parent: Control, shake: Control) -> void:
	if not _bombs.has(id):
		return
	var b: Dictionary = _bombs[id]
	var root: Control = b.root
	var center := root.get_global_rect().get_center()
	var side := root.get_global_rect().size.x
	stop_all()
	root.visible = false
	Sfx.play_or("bomb_explode", "smash")
	Game.haptic(int(Config.SPECIAL.boom_haptic_ms))
	if fx_parent == null:
		return
	var local := fx_parent.get_global_transform().affine_inverse() * center
	# Under the flash and debris, so the blast shines over the cracked glass.
	var crack := GlassCrack.new()
	crack.setup(fx_parent.size, local, float(Config.SPECIAL.boom_popup_sec))
	fx_parent.add_child(crack)
	var flash := BoomFlash.new()
	flash.position = local
	flash.radius = side * 2.4
	fx_parent.add_child(flash)
	var burst := _make_burst(side * 1.6, BURST_COLORS, 46, 0.9)
	burst.position = local
	fx_parent.add_child(burst)
	burst.emitting = true
	burst.finished.connect(burst.queue_free)
	if shake != null:
		var home := shake.position
		var tw := shake.create_tween()
		for i in 8:
			var amp := side * 0.18 * (1.0 - i / 8.0)
			tw.tween_property(shake, "position", home + Vector2(randf_range(-amp, amp), randf_range(-amp, amp)), 0.04)
		tw.tween_property(shake, "position", home, 0.05)


func _make_sparks(side: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "Sparks"
	p.emitting = false
	p.amount = 18
	p.lifetime = 0.35
	p.direction = Vector2(0.4, -1.0)
	p.spread = 70.0
	p.gravity = Vector2(0, side * 2.0)
	p.initial_velocity_min = side * 0.6
	p.initial_velocity_max = side * 1.3
	p.scale_amount_min = side * 0.025
	p.scale_amount_max = side * 0.05
	var g := Gradient.new()
	g.set_color(0, Color("fff6b0"))
	g.set_color(1, Color(1.0, 0.45, 0.1, 0.0))
	p.color_ramp = g
	return p


func _make_burst(radius: float, colors: Array[Color], n: int, life: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "Burst"
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = n
	p.lifetime = life
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2(0, radius * 2.2)
	p.initial_velocity_min = radius * 1.2
	p.initial_velocity_max = radius * 2.6
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = radius * 0.06
	p.scale_amount_max = radius * 0.14
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in colors.size():
		offs.append(float(i) / maxf(colors.size() - 1, 1))
		cols.append(colors[i])
	var g := Gradient.new()
	g.offsets = offs
	g.colors = cols
	p.color_initial_ramp = g
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	return p


## Loé sáng tròn: nở ra và mờ đi trong 0,35 giây rồi tự xoá.
class BoomFlash extends Control:
	var radius: float = 100.0
	var _k: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tw := create_tween()
		tw.tween_method(func(v: float) -> void:
			_k = v
			queue_redraw(), 0.0, 1.0, 0.35)
		tw.tween_callback(queue_free)

	func _draw() -> void:
		var r := radius * (0.35 + 0.65 * _k)
		var a := 1.0 - _k
		draw_circle(Vector2.ZERO, r, Color(1.0, 0.95, 0.75, 0.55 * a))
		draw_circle(Vector2.ZERO, r * 0.55, Color(1.0, 1.0, 1.0, 0.85 * a))
		draw_arc(Vector2.ZERO, r * 1.15, 0.0, TAU, 48, Color(1.0, 0.6, 0.85, 0.8 * a), maxf(3.0, radius * 0.06))
