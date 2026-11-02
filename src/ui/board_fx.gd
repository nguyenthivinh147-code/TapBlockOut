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
const INNER_INSET := 0.25  # viên trong của khối hai lớp lùi vào chừng này (ô)

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


## Các đoạn mép hướng lên của khối: {"x0", "x1", "y", "wall_left", "wall_right"} theo đơn vị ô.
## `wall_*` true nghĩa là đầu đoạn đó chạm một thành khối đi lên (góc lõm), false là góc lồi.
static func top_runs(cells: Array) -> Array:
	var occ := {}
	for c: Vector2i in cells:
		occ[c] = true
	var out: Array = []
	for c: Vector2i in cells:
		if occ.has(c + Vector2i(0, -1)):
			continue
		var left := c + Vector2i(-1, 0)
		if occ.has(left) and not occ.has(left + Vector2i(0, -1)):
			continue  # không phải đầu trái của đoạn
		var end := c
		while occ.has(end + Vector2i(1, 0)) and not occ.has(end + Vector2i(1, -1)):
			end += Vector2i(1, 0)
		out.append({"x0": c.x, "x1": end.x + 1, "y": c.y,
			"wall_left": occ.has(left + Vector2i(0, -1)),
			"wall_right": occ.has(end + Vector2i(1, -1))})
	return out


## Bo nét bằng cắt góc Chaikin; mỗi điểm là (x, y, nửa bề dày, độ đậm) nên bề dày và độ đậm cũng mượt theo.
static func _chaikin(ctrl: Array[Vector4], passes: int = 2) -> Array[Vector4]:
	var p := ctrl
	for _i in passes:
		var q: Array[Vector4] = [p[0]]
		for i in p.size() - 1:
			q.append(p[i].lerp(p[i + 1], 0.25))
			q.append(p[i].lerp(p[i + 1], 0.75))
		q.append(p[-1])
		p = q
	return p


## Dải sáng thon qua các điểm (toạ độ theo ô); mép ngoài mờ về 0 nên không cần khử răng cưa.
static func _ribbon(ci: CanvasItem, ctrl: Array[Vector4], cell: float, at: Vector2, feather: float) -> void:
	var pts := _chaikin(ctrl)
	var n := pts.size()
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for i in n:
		var pos := Vector2(pts[i].x, pts[i].y)
		var prev := Vector2(pts[maxi(i - 1, 0)].x, pts[maxi(i - 1, 0)].y)
		var next := Vector2(pts[mini(i + 1, n - 1)].x, pts[mini(i + 1, n - 1)].y)
		var t := (next - prev).normalized()
		var nor := Vector2(-t.y, t.x)
		var solid := pts[i].z * cell
		for k: float in [-solid - feather, -solid, solid, solid + feather]:
			verts.append(at + pos * cell + nor * k)
		var hi := Color(1, 1, 1, pts[i].w)
		var lo := Color(1, 1, 1, 0)
		cols.append_array(PackedColorArray([lo, hi, hi, lo]))
		if i < n - 1:
			var b := i * 4
			for s in 3:
				idx.append_array(PackedInt32Array([b + s, b + s + 1, b + s + 4, b + s + 1, b + s + 5, b + s + 4]))
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, verts, cols)


## Vệt bóng của khối: mỗi mép hướng lên một vạch mảnh, đầu vạch ở góc lồi là đốm trắng móc nhẹ xuống, đầu vạch
## ở góc lõm là lưỡi liềm cong lên theo thành. Đo từ concept, theo ô; `at` là góc ô gốc.
static func draw_gloss(ci: CanvasItem, cells: Array, cell: float, at: Vector2 = Vector2.ZERO) -> void:
	var feather := maxf(0.8, cell * 0.022)
	for r: Dictionary in top_runs(cells):
		var x0 := float(r["x0"])
		var x1 := float(r["x1"])
		var y := float(r["y"])
		var ctrl: Array[Vector4] = []
		if bool(r["wall_left"]):
			ctrl.append(Vector4(x0 + 0.03, y + 0.14, 0.004, 0.0))
			ctrl.append(Vector4(x0 + 0.22, y + 0.14, 0.016, 0.5))
		else:
			ctrl.append(Vector4(x0 + 0.225, y + 0.235, 0.012, 0.55))
			ctrl.append(Vector4(x0 + 0.245, y + 0.175, 0.036, 0.95))
			ctrl.append(Vector4(x0 + 0.33, y + 0.15, 0.042, 1.0))
			ctrl.append(Vector4(x0 + 0.46, y + 0.145, 0.018, 0.6))
		if bool(r["wall_right"]):
			ctrl.append(Vector4(x1 - 0.42, y + 0.14, 0.018, 0.55))
			ctrl.append(Vector4(x1 - 0.2, y + 0.135, 0.026, 0.9))
			ctrl.append(Vector4(x1 - 0.06, y + 0.105, 0.026, 0.95))
			ctrl.append(Vector4(x1 + 0.012, y + 0.035, 0.006, 0.5))
		else:
			ctrl.append(Vector4(x1 - 0.48, y + 0.135, 0.018, 0.6))
			ctrl.append(Vector4(x1 - 0.33, y + 0.125, 0.034, 0.98))
			ctrl.append(Vector4(x1 - 0.255, y + 0.145, 0.03, 0.95))
			ctrl.append(Vector4(x1 - 0.225, y + 0.215, 0.01, 0.5))
		_ribbon(ci, ctrl, cell, at, feather)


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


## Bốn tông của khối: xám sương mù khi còn trong sương, tối đi khi bị xích.
static func block_ramp(view: Dictionary) -> Dictionary:
	var ramp: Dictionary = ThemeKit.block_ramp("", FOG_COLOR) if bool(view.get("is_fog_hidden", false)) else ThemeKit.block_ramp(str(view.get("color", "")))
	if bool(view.get("chained", false)):
		var dark := {}
		for tone in ramp:
			dark[tone] = (ramp[tone] as Color).darkened(0.22)
		return dark
	return ramp


## Lớp băng tô trong hình khối (shader), trong suốt nếu không có băng.
static func block_overlay(view: Dictionary) -> Color:
	var ice := int(view.get("ice", 0))
	if ice <= 0:
		return Color(0, 0, 0, 0)
	return Color(ICE_TINT, 0.72) if ice >= 2 else ICE_TINT


## Khung (toạ độ ô gốc của khối) của viên trong ở ô `c` của khối hai lớp.
static func inner_rect(c: Vector2i, cell: float) -> Rect2:
	var m := cell * INNER_INSET
	return Rect2(Vector2(c) * cell + Vector2(m, m), Vector2(cell, cell) - Vector2(m, m) * 2.0)


## Vẽ phần nằm trên thân kẹo của một khối đa ô: vệt bóng (của khối và của viên trong khối hai lớp), rồi băng,
## xích, sương, mũi tên. Thân (mép gối, sọc, bóng đổ) do `Pudding.Body` vẽ bằng shader nằm sau BlockNode,
## theo concept `art/concepts/concept_candy_board_v5_stripe.png`.
## `cells` tính theo toạ độ ô gốc của chính CanvasItem này.
static func draw_block(ci: CanvasItem, cells: Array, cell: float, view: Dictionary, show_arrow: bool) -> void:
	var fog_hidden: bool = view.get("is_fog_hidden", false)
	var chained: bool = view.get("chained", false)
	var has_inner := str(view.get("inner_color", "")) != "" and not fog_hidden
	draw_gloss(ci, cells, cell)
	if has_inner:
		for c: Vector2i in cells:
			var ir := inner_rect(c, cell)
			draw_gloss(ci, [Vector2i.ZERO], ir.size.x, ir.position)
	var anchor := anchor_cell(cells)
	var center := (Vector2(anchor) + Vector2(0.5, 0.5)) * cell
	if fog_hidden:
		draw_fog_cover(ci, cells, cell)
	var ice := int(view.get("ice", 0))
	if ice > 0:
		draw_ice(ci, cells, cell)
	if arrow_shown(view, show_arrow):
		if has_inner:
			# khối hai lớp: mũi tên của lớp ngoài nằm lệch lên trên tâm ô
			draw_arrow(ci, center + Vector2(0, -cell * 0.3), LevelData.dir_of(str(view.get("color", ""))), cell * 0.6)
		elif chained:
			draw_arrow(ci, center + Vector2(0, -cell * 0.2), LevelData.dir_of(str(view.get("color", ""))), cell * 0.7)
		else:
			# hạ nhẹ xuống để không chạm vệt bóng ở mép trên
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


## Băng phủ khối: vệt sáng, vết nứt; lớp xanh nhạt do shader tô trong hình khối (`block_overlay`).
static func draw_ice(ci: CanvasItem, cells: Array, cell: float) -> void:
	for c: Vector2i in cells:
		ci.draw_rect(Rect2(Vector2(c) * cell + Vector2(cell * 0.14, cell * 0.14), Vector2(cell * 0.3, cell * 0.05)), Color(1, 1, 1, 0.5))
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
