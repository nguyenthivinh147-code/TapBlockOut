extends RefCounted
## Vẽ khối và hiệu ứng cho BoardView: hình khối bo góc, mũi tên, băng, xích, hạt, rung.
## Hàm tĩnh, không giữ trạng thái.

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const LevelData := preload("res://src/core/level_data.gd")
const Pudding := preload("res://src/ui/pudding.gd")

const FOG_COLOR := Color("6B7390")
const ICE_TINT := Color(0.62, 0.86, 1.0, 0.55)
const NEIGHBORS := [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]
const KEY_COLOR := Color("F5C518")
const CHAIN_COLOR := Color(0.88, 0.9, 0.96)

static var _real_icon: Dictionary = {}  # tên -> có file thật?


## Ảnh cơ chế thật (`assets/ui/mech_*.png`); null nếu chưa có để nơi gọi vẽ bằng code.
static func mech_tex(mech_name: String) -> Texture2D:
	if not _real_icon.has(mech_name):
		_real_icon[mech_name] = ThemeKit.has_real_icon(mech_name)
	if not _real_icon[mech_name]:
		return null
	return ThemeKit.icon(mech_name)


## Mũi tên hỗ trợ mù màu có hiện không: tắt theo cài đặt, và ẩn khi khối còn trong sương mù.
static func arrow_shown(view: Dictionary, show_arrow: bool) -> bool:
	return show_arrow and not bool(view.get("is_fog_hidden", false))


static func _box(fill: Color, radii: Array, _margins: Array, border: Color, borders: Array) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.corner_radius_top_left = radii[0]
	s.corner_radius_top_right = radii[1]
	s.corner_radius_bottom_right = radii[2]
	s.corner_radius_bottom_left = radii[3]
	s.border_color = border
	s.border_width_top = borders[0]
	s.border_width_left = borders[1]
	s.border_width_right = borders[2]
	s.border_width_bottom = borders[3]
	s.anti_aliasing = true
	return s


## Màu viền hoặc thành kẹo: tối đi `amount` nhưng vẫn đậm màu, không xám.
static func _candy_edge(base: Color, amount: float = 0.30) -> Color:
	var e := base.darkened(amount)
	e.s = minf(1.0, e.s + 0.15)
	return e


## Quad Bezier qua `n + 1` điểm.
static func _bez(p0: Vector2, p1: Vector2, p2: Vector2, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / float(n)
		out.append(p0 * (1.0 - t) * (1.0 - t) + p1 * 2.0 * (1.0 - t) * t + p2 * t * t)
	return out


## Vệt sáng của kẹo cứng trong khung `size` (px) có góc trên trái ở `origin`: một thấu kính cong ôm góc
## (đậm ở mép ngoài, mờ dần vào trong, đầu trên phải tròn, đuôi thon xuống trái), một vạch ngắn bên dưới
## và một vệt mờ ngang ở mép trên. Toạ độ chuẩn hoá theo khung, đo từ viên kẹo đơn trong concept.
static func draw_glare(ci: CanvasItem, origin: Vector2, size: float) -> void:
	var a := Vector2(0.09, 0.33)
	var e := Vector2(0.35, 0.125)
	var outer := _bez(a, Vector2(0.06, 0.12), e, 14)
	var inner := _bez(a, Vector2(0.27, 0.28), e, 14)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for p in outer:
		pts.append(origin + p * size)
		cols.append(Color(1, 1, 1, 0.95))
	for i in range(inner.size() - 1, -1, -1):
		pts.append(origin + inner[i] * size)
		cols.append(Color(1, 1, 1, 0.50))
	ci.draw_polygon(pts, cols)
	var edge := PackedVector2Array()
	for p in outer:
		edge.append(origin + p * size)
	ci.draw_polyline(edge, Color(1, 1, 1, 0.9), maxf(1.0, size * 0.012), true)
	# vạch ngắn dưới đuôi và vệt mờ ngang ở mép trên
	var dash := Rect2(origin + Vector2(0.085, 0.325) * size, Vector2(0.022, 0.04) * size)
	ci.draw_style_box(_box(Color(1, 1, 1, 0.9), [3, 3, 3, 3], [], Color(0, 0, 0, 0), [0, 0, 0, 0]), dash)
	var streak := Rect2(origin + Vector2(0.50, 0.095) * size, Vector2(0.16, 0.022) * size)
	ci.draw_style_box(_box(Color(1, 1, 1, 0.28), [3, 3, 3, 3], [], Color(0, 0, 0, 0), [0, 0, 0, 0]), streak)


## Ô gần trọng tâm nhất: nơi đặt mũi tên và biểu tượng.
static func anchor_cell(cells: Array) -> Vector2i:
	var sum := Vector2.ZERO
	for c: Vector2i in cells:
		sum += Vector2(c)
	var centroid := sum / maxf(1.0, float(cells.size()))
	var best: Vector2i = cells[0]
	var best_d := INF
	for c: Vector2i in cells:
		var d := (Vector2(c) - centroid).length_squared()
		if d < best_d:
			best_d = d
			best = c
	return best


## Màu gốc của khối: xám sương mù khi còn trong sương, tối đi khi bị xích.
static func block_base_color(view: Dictionary) -> Color:
	var base: Color = FOG_COLOR if bool(view.get("is_fog_hidden", false)) else ThemeKit.block_color(str(view.get("color", "")))
	if bool(view.get("chained", false)):
		base = base.darkened(0.22)
	return base


## Vẽ phần nằm trên thân kẹo của một khối đa ô: vệt sáng, viên trong của khối hai lớp, rồi băng, xích,
## sương, mũi tên. Thân (viền, bevel, vệt chéo, bóng đổ) do `Pudding.Body` vẽ bằng shader nằm sau BlockNode,
## theo ảnh tham chiếu kẹo cứng (design.md, mục Concept theme).
## `cells` tính theo toạ độ ô gốc của chính CanvasItem này.
static func draw_block(ci: CanvasItem, cells: Array, cell: float, view: Dictionary, show_arrow: bool) -> void:
	var fog_hidden: bool = view.get("is_fog_hidden", false)
	var chained: bool = view.get("chained", false)
	var inner_color := str(view.get("inner_color", ""))
	var inner_col := ThemeKit.block_color(inner_color) if inner_color != "" and not fog_hidden else Color(0, 0, 0, 0)
	var bw := maxi(2, int(cell * 0.035))
	var top_left: Vector2i = cells[0]
	for c: Vector2i in cells:
		if c.y < top_left.y or (c.y == top_left.y and c.x < top_left.x):
			top_left = c
	# vệt sáng ở góc trên trái của cả khối (khung bằng ô, lùi theo khe giữa các khối)
	var g := cell * 0.0625
	draw_glare(ci, Vector2(top_left) * cell + Vector2(g, g), cell - 2.0 * g)
	if inner_col.a > 0.0:
		for c: Vector2i in cells:
			var m := cell * 0.27
			var ir := Rect2(c.x * cell + m, c.y * cell + m, cell - 2.0 * m, cell - 2.0 * m)
			var ri := int(cell * 0.14)
			var lip := maxi(bw + 2, int(cell * 0.08))
			ci.draw_style_box(_box(inner_col.lerp(Color.WHITE, 0.06), [ri, ri, ri, ri], [], _candy_edge(inner_col, 0.45), [bw, bw, bw, lip]), ir)
			draw_glare(ci, ir.position, ir.size.x)
	var anchor := anchor_cell(cells)
	var center := (Vector2(anchor) + Vector2(0.5, 0.5)) * cell
	if fog_hidden:
		draw_fog_cover(ci, cells, cell)
	var ice := int(view.get("ice", 0))
	if ice > 0:
		draw_ice(ci, cells, cell, ice)
	if arrow_shown(view, show_arrow):
		if inner_col.a > 0.0:
			# khối hai lớp: mũi tên của lớp ngoài nằm lệch lên trên tâm ô
			draw_arrow(ci, center + Vector2(0, -cell * 0.3), LevelData.dir_of(str(view.get("color", ""))), cell * 0.6)
		elif chained:
			draw_arrow(ci, center + Vector2(0, -cell * 0.2), LevelData.dir_of(str(view.get("color", ""))), cell * 0.7)
		else:
			# hạ nhẹ xuống để không chạm vệt sáng ở góc trên trái
			draw_arrow(ci, center + Vector2(0, cell * 0.05), LevelData.dir_of(str(view.get("color", ""))), cell)
	if chained:
		draw_chain(ci, cells, cell)
		draw_lock(ci, center + Vector2(0, cell * 0.14), cell)
	if bool(view.get("is_key", false)):
		draw_key(ci, Vector2(anchor) * cell + Vector2(cell * 0.24, cell * 0.24), cell)


static func draw_arrow(ci: CanvasItem, center: Vector2, dir: Vector2i, cell: float) -> void:
	var d := Vector2(dir)
	if d == Vector2.ZERO:
		return
	var n := Vector2(-d.y, d.x)
	var s := cell * 0.2
	var tip := center + d * s
	var pts := PackedVector2Array([tip, center - d * s * 0.7 + n * s * 0.95, center - d * s * 0.7 - n * s * 0.95])
	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(0, cell * 0.025))
	ci.draw_colored_polygon(shadow, Color(0, 0, 0, 0.3))
	ci.draw_colored_polygon(pts, Color(1, 1, 1, 0.92))


static func draw_lock(ci: CanvasItem, center: Vector2, cell: float) -> void:
	var tex := mech_tex("mech_chain")
	if tex != null:
		var sz := cell * 0.5
		ci.draw_texture_rect(tex, Rect2(center - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false)
		return
	var w := cell * 0.34
	var h := cell * 0.26
	var body := Rect2(center.x - w * 0.5, center.y - h * 0.15, w, h)
	ci.draw_arc(Vector2(center.x, body.position.y), w * 0.3, PI, TAU, 14, Color(0.92, 0.94, 0.98), maxf(2.0, cell * 0.05))
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.92, 0.94, 0.98)
	s.set_corner_radius_all(int(cell * 0.05))
	ci.draw_style_box(s, body)
	ci.draw_circle(body.get_center(), cell * 0.03, Color(0.25, 0.28, 0.4))


## Xích: mỗi ô một đường chéo gồm các mắt xích nhỏ.
static func draw_chain(ci: CanvasItem, cells: Array, cell: float) -> void:
	var r := cell * 0.065
	for c: Vector2i in cells:
		var o := Vector2(c) * cell
		for i in 5:
			var k := 0.18 + 0.16 * i
			var p := o + Vector2(cell * k, cell * k)
			var q := o + Vector2(cell * (1.0 - k), cell * k)
			ci.draw_arc(p, r, 0.0, TAU, 10, Color(CHAIN_COLOR, 0.7), maxf(1.5, cell * 0.025))
			ci.draw_arc(q, r, 0.0, TAU, 10, Color(CHAIN_COLOR, 0.7), maxf(1.5, cell * 0.025))


## Chìa: huy hiệu tròn vàng có hình chìa ở góc ô; `pos` là tâm huy hiệu.
static func draw_key(ci: CanvasItem, pos: Vector2, cell: float) -> void:
	var rad := cell * 0.19
	var tex := mech_tex("mech_key")
	if tex != null:
		ci.draw_texture_rect(tex, Rect2(pos - Vector2(rad, rad) * 1.1, Vector2(rad, rad) * 2.2), false)
		return
	ci.draw_circle(pos, rad, Color(0.1, 0.12, 0.2, 0.85))
	ci.draw_arc(pos, rad, 0.0, TAU, 20, KEY_COLOR, maxf(1.5, cell * 0.03))
	var w := maxf(2.0, cell * 0.035)
	var head := pos + Vector2(-rad * 0.4, 0.0)
	ci.draw_arc(head, rad * 0.28, 0.0, TAU, 12, KEY_COLOR, w)
	ci.draw_line(head + Vector2(rad * 0.28, 0), pos + Vector2(rad * 0.55, 0), KEY_COLOR, w)
	ci.draw_line(pos + Vector2(rad * 0.3, 0), pos + Vector2(rad * 0.3, rad * 0.3), KEY_COLOR, w)
	ci.draw_line(pos + Vector2(rad * 0.55, 0), pos + Vector2(rad * 0.55, rad * 0.3), KEY_COLOR, w)


## Băng phủ khối: lớp xanh nhạt, vệt sáng, vết nứt; `level` >= 2 dày hơn.
static func draw_ice(ci: CanvasItem, cells: Array, cell: float, level: int = 1) -> void:
	var tint := ICE_TINT
	if level >= 2:
		tint.a = 0.72
	for c: Vector2i in cells:
		var r := Rect2(c.x * cell + 2, c.y * cell + 2, cell - 4, cell - 4)
		ci.draw_rect(r, tint)
		ci.draw_rect(Rect2(r.position + Vector2(cell * 0.08, cell * 0.08), Vector2(cell * 0.3, cell * 0.05)), Color(1, 1, 1, 0.5))
	var a: Vector2i = cells[0]
	var o := Vector2(a.x * cell, a.y * cell)
	var tex := mech_tex("mech_ice")
	if tex != null:
		ci.draw_texture_rect(tex, Rect2(o + Vector2(cell * 0.15, cell * 0.15), Vector2(cell, cell) * 0.7), false)
		return
	var w := Color(1, 1, 1, 0.8)
	ci.draw_line(o + Vector2(cell * 0.2, cell * 0.15), o + Vector2(cell * 0.45, cell * 0.4), w, 2.0)
	ci.draw_line(o + Vector2(cell * 0.45, cell * 0.4), o + Vector2(cell * 0.38, cell * 0.65), w, 2.0)
	ci.draw_line(o + Vector2(cell * 0.45, cell * 0.4), o + Vector2(cell * 0.75, cell * 0.5), w, 2.0)


## Sương mù: vài vệt mờ trong mỗi ô và dấu "?" ở ô giữa (hoặc ảnh `mech_fog`).
static func draw_fog_cover(ci: CanvasItem, cells: Array, cell: float) -> void:
	for c: Vector2i in cells:
		var o := Vector2(c) * cell
		var seed_v := absi(c.x * 31 + c.y * 17)
		for i in 3:
			var ang := float((seed_v + i * 7) % 11) * 0.57
			var p := o + Vector2(cell * (0.28 + 0.22 * i), cell * (0.3 + 0.2 * ((seed_v + i) % 3)))
			ci.draw_circle(p, cell * (0.2 - 0.02 * i), Color(1, 1, 1, 0.1))
			ci.draw_arc(p + Vector2(cos(ang), sin(ang)) * cell * 0.05, cell * 0.16, ang, ang + 2.2, 10, Color(1, 1, 1, 0.22), maxf(1.5, cell * 0.03))
	var anchor := anchor_cell(cells)
	var center := (Vector2(anchor) + Vector2(0.5, 0.5)) * cell
	var tex := mech_tex("mech_fog")
	if tex != null:
		ci.draw_texture_rect(tex, Rect2(center - Vector2(cell, cell) * 0.35, Vector2(cell, cell) * 0.7), false)
		return
	var font := ThemeDB.fallback_font
	var fs := int(cell * 0.55)
	ci.draw_string(font, center + Vector2(-cell * 0.5, fs * 0.35), "?", HORIZONTAL_ALIGNMENT_CENTER, cell, fs, Color(1, 1, 1, 0.75))


## Đá: ô bo góc xám, vài mặt cắt sáng/tối; `r` là hình chữ nhật của ô đá.
static func draw_stone(ci: CanvasItem, r: Rect2, cell: float) -> void:
	var st := StyleBoxFlat.new()
	st.bg_color = Color("5E667D")
	st.border_color = Color("3A4054")
	st.set_border_width_all(maxi(2, int(cell * 0.05)))
	st.set_corner_radius_all(int(cell * 0.2))
	st.anti_aliasing = true
	ci.draw_style_box(st, r)
	var tex := mech_tex("mech_stone")
	if tex != null:
		ci.draw_texture_rect(tex, r.grow(-cell * 0.05), false)
		return
	ci.draw_rect(Rect2(r.position + Vector2(cell * 0.15, cell * 0.12), Vector2(cell * 0.3, cell * 0.06)), Color(1, 1, 1, 0.2))
	var p := r.position
	var sz := r.size
	ci.draw_colored_polygon(PackedVector2Array([p + sz * Vector2(0.55, 0.55), p + sz * Vector2(0.85, 0.5), p + sz * Vector2(0.8, 0.82), p + sz * Vector2(0.5, 0.85)]), Color(0, 0, 0, 0.16))
	ci.draw_line(p + sz * Vector2(0.2, 0.7), p + sz * Vector2(0.42, 0.55), Color(0, 0, 0, 0.3), maxf(1.5, cell * 0.03))


## Một cạnh cổng nhịp: `open` 0 = đóng (thanh chắn), 1 = mở (vạch sáng). `mid_a`/`mid_b` là hai đầu đường giữa dải.
static func draw_gate_mark(ci: CanvasItem, side: String, mid_a: Vector2, mid_b: Vector2, g: float, col: Color, open: float) -> void:
	var line_w := maxf(2.0, g * 0.18)
	if open > 0.01:
		ci.draw_line(mid_a, mid_b, Color(col.lightened(0.35), open), line_w)
	var closed := 1.0 - open
	if closed <= 0.01:
		return
	var horizontal := side == "up" or side == "down"
	var length := (mid_b - mid_a).length()
	var count := maxi(3, int(length / (g * 0.9)))
	var half := g * 0.4 * closed
	for i in count:
		var t := (float(i) + 0.5) / float(count)
		var p := mid_a.lerp(mid_b, t)
		var d := Vector2(0, half) if horizontal else Vector2(half, 0)
		ci.draw_line(p - d, p + d, Color(1, 1, 1, 0.6 * closed), maxf(2.0, g * 0.16))


# --- hiệu ứng ---

## Hạt màu bắn ra theo `dir` từ điểm `pos` (toạ độ của `parent`). Tự xoá khi xong.
static func burst(parent: Node, pos: Vector2, color: Color, dir: Vector2, strength: float = 1.0, amount: int = 16) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.5
	p.explosiveness = 1.0
	p.direction = dir if dir != Vector2.ZERO else Vector2.UP
	p.spread = 70.0 if dir != Vector2.ZERO else 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 140.0 * strength
	p.initial_velocity_max = 320.0 * strength
	p.damping_min = 80.0
	p.damping_max = 160.0
	p.scale_amount_min = 5.0
	p.scale_amount_max = 10.0
	p.color = color
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	p.finished.connect(p.queue_free)
	parent.add_child(p)
	p.emitting = true
	return p


## Rung ngang nhẹ (khối bị xích, va chạm). Dùng offset từ vị trí hiện tại, trả về đúng vị trí cũ.
static func shake(node: CanvasItem, amplitude: float = 6.0, dur: float = 0.18, axis: Vector2 = Vector2.RIGHT) -> Tween:
	var home: Vector2 = node.position
	var tw := node.create_tween()
	var steps := 4
	for i in steps:
		var k := 1.0 - float(i) / steps
		var sgn := 1.0 if i % 2 == 0 else -1.0
		tw.tween_property(node, "position", home + axis * amplitude * k * sgn, dur / (steps + 1))
	tw.tween_property(node, "position", home, dur / (steps + 1))
	return tw


## Nhấp nháy to nhỏ liên tục cho Gợi ý. Gọi tween.kill() để dừng (rồi đặt lại scale).
static func pulse(node: Control) -> Tween:
	node.pivot_offset = node.size * 0.5
	var tw := node.create_tween().set_loops()
	tw.tween_property(node, "scale", Vector2(1.08, 1.08), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw
