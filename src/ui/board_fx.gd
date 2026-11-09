extends RefCounted
## Vẽ khối và hiệu ứng cho BoardView: hình khối bo góc, thùng sắt, xích, sương, hạt, rung.
## Hàm tĩnh; chỉ giữ cache tĩnh (ảnh cơ chế, texture hạt, hình xích theo hình khối và cỡ ô).

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const Pudding := preload("res://src/ui/pudding.gd")
const FLASH_SHADER := preload("res://src/ui/impact_flash.gdshader")

const FOG_COLOR := Color("6B7390")
const NEIGHBORS := [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]
const KEY_COLOR := Color("F5C518")
const CHAIN_STEEL := Color("C9D1E3")
const CHAIN_DARK := Color("3B4260")
const CHAIN_SHINE := Color(1, 1, 1, 0.9)
const CHAIN_LINK := 0.15  # khoảng cách hai mắt xích (ô)
const CHAIN_IN := 0.24  # hai đầu đường xích lùi vào trong mép khung khối chừng này (ô), mắt đầu nằm gọn trên góc bo
const CHAIN_RX := 0.105  # bán trục dọc của mắt xích mặt tròn (ô)
const CHAIN_RY := 0.06  # bán trục ngang của mắt xích mặt tròn (ô)
const CHAIN_BAR := 0.078  # nửa chiều dài mắt xích mặt nghiêng (ô)
const CHAIN_W := 0.03  # bề dày nét thép (ô)
const CHAIN_MESH_MAX := 64  # số hình xích giữ trong cache (mỗi hình khối và cỡ ô một hình)
const KEY_SIZE := 0.8  # ảnh chìa giữa một ô của khối chìa, cạnh theo ô
const FOG_MARK := 0.7  # ảnh `mech_fog` giữa một ô của khối còn trong sương, cạnh theo ô
const RIBBON_BOW := 1.3  # nơ satin (`ribbon_bow`, xám, tô theo tông khối) giữa khối ruy băng, cạnh ảnh theo ô
const RIBBON_BOW_DARK := 0.4  # phần tối nhất của nơ (phân vị độ sáng) đậm dần về tông đáy
const RIBBON_BOW_LIGHT := 0.78  # phần sáng nhất (trên phân vị này) sáng dần thành vệt bóng
const RIBBON_BOW_SMOOTH := 4  # độ sáng của nơ làm mịn bằng cách thu nhỏ chừng này lần rồi phóng lại
const RIBBON_BOW_RIM := 0.035  # viền tối quanh nơ, theo cạnh ảnh
const RIBBON_BOW_RIM_DARK := 0.45  # viền tối hơn tông đáy của khối chừng này
const RIBBON_BOW_DROP := 0.04  # bóng đổ lệch xuống, theo cạnh ảnh
const RIBBON_BOW_SHADOW := Color("2A1838")
const RIBBON_BOW_SHADOW_A := 0.35
const RIBBON_BOW_SHINE := 0.35  # vệt sáng sáng hơn tông sọc nhạt chừng này
const LOCK_GOLD := Color("FFC93C")
const LOCK_GOLD_DARK := Color("C9781A")
const CRATE_GROW := 0.06  # ảnh thùng sắt vẽ to hơn ô chừng này mỗi phía (ô), bù lề trong suốt của ảnh
const CRATE_BOLTS := [Vector2(0.19, 0.18), Vector2(0.81, 0.18), Vector2(0.19, 0.79), Vector2(0.81, 0.79)]  # tâm 4 đinh trên nắp (phần ô), khớp ảnh
const CRATE_BOLT_R := 0.07  # bán kính đinh (ô)
const IRON := Color("718CA6")
const IRON_LIGHT := Color("A3B8D0")
const IRON_DARK := Color("3F546B")
const BOLT := Color("E6EBF3")

static var _real_icon: Dictionary = {}  # tên -> có file thật?
static var _sparkle_tex: Texture2D = null
static var _shrink_curve: Curve = null
static var _chain_mesh: Dictionary = {}  # "hình|cỡ ô" -> Strokes của cả lớp xích
static var _bow_parts: Dictionary = {}  # các lớp trắng của nơ ruy băng (bow_parts)


## Ảnh cơ chế thật (`assets/ui/mech_*.png`); null nếu chưa có để nơi gọi vẽ bằng code.
static func mech_tex(mech_name: String) -> Texture2D:
	if not _real_icon.has(mech_name):
		_real_icon[mech_name] = ThemeKit.has_real_icon(mech_name)
	if not _real_icon[mech_name]:
		return null
	return ThemeKit.icon(mech_name)


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


## Vệt bóng của khối crystal: lưỡi liềm trắng ôm góc lồi trên trái của mỗi mép hướng lên, dày ở góc, thon về hai đầu,
## theo `art/concepts/concept_candy_board_v4_crystal_semi.png`. Đo theo ô; `at` là góc ô gốc.
static func draw_crystal_gloss(ci: CanvasItem, cells: Array, cell: float, at: Vector2 = Vector2.ZERO) -> void:
	var feather := maxf(0.8, cell * 0.022)
	for r: Dictionary in top_runs(cells):
		if bool(r["wall_left"]):
			continue
		var x0 := float(r["x0"])
		var y := float(r["y"])
		var ctrl: Array[Vector4] = [
			Vector4(x0 + 0.13, y + 0.46, 0.004, 0.0),
			Vector4(x0 + 0.12, y + 0.33, 0.028, 0.8),
			Vector4(x0 + 0.135, y + 0.19, 0.046, 0.97),
			Vector4(x0 + 0.19, y + 0.135, 0.054, 1.0),
			Vector4(x0 + 0.33, y + 0.12, 0.042, 0.95),
			Vector4(x0 + 0.5, y + 0.125, 0.02, 0.6),
			Vector4(x0 + 0.64, y + 0.13, 0.004, 0.0),
		]
		_ribbon(ci, ctrl, cell, at, feather)


## Ô gần trọng tâm nhất: nơi đặt biểu tượng. Bỏ qua các ô trong `skip` (đã có biểu tượng khác); mọi ô đều bị bỏ qua
## thì trả ô gần trọng tâm nhất, nơi gọi tự kiểm `skip.has()` nếu cần biết.
static func anchor_cell(cells: Array, skip: Array = []) -> Vector2i:
	var sum := Vector2.ZERO
	for c: Vector2i in cells:
		sum += Vector2(c)
	var centroid := sum / maxf(1.0, float(cells.size()))
	var best: Vector2i = cells[0]
	var best_d := INF
	for use_skip in [true, false]:
		for c: Vector2i in cells:
			if use_skip and skip.has(c):
				continue
			var d := (Vector2(c) - centroid).length_squared()
			if d < best_d:
				best_d = d
				best = c
		if best_d < INF:
			break
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


## Lớp do shader thân khối vẽ: {"jelly": lớp phủ khối (pudding hoặc băng), "thick": lớp phủ 2 lớp, "frost": lớp phủ là
## băng, "paper": hộp giấy (khối hai lớp), "crystal": chất liệu crystal, "ribbons": số ruy băng còn quấn}.
static func block_layers(view: Dictionary) -> Dictionary:
	return {
		"jelly": 1.0 if int(view.get("ice", 0)) > 0 else 0.0,
		"thick": 1.0 if int(view.get("ice", 0)) > 1 else 0.0,
		"frost": 1.0 if str(view.get("cover", "")) == "frost" else 0.0,
		"paper": 1.0 if str(view.get("inner_color", "")) != "" else 0.0,
		"crystal": 1.0 if is_crystal(view) else 0.0,
		"ribbons": float(int(view.get("ribbons", 0))),
	}


## Khối crystal (khối đặc biệt của leaderboard, rời bàn cho 1 mảnh): thân và mảnh vỡ tô chất liệu crystal.
## Còn trong sương mù thì vẫn là kẹo xám để không lộ.
static func is_crystal(view: Dictionary) -> bool:
	return bool(view.get("special", false)) and not bool(view.get("is_fog_hidden", false))


## Tâm băng dán chữ thập của hộp giấy: giữa khung khối, theo toạ độ ô của khối.
static func tape_center(cells: Array) -> Vector2:
	var lo := Vector2(INF, INF)
	var hi := -lo
	for c: Vector2i in cells:
		lo = lo.min(Vector2(c))
		hi = hi.max(Vector2(c) + Vector2.ONE)
	return (lo + hi) * 0.5


## Vẽ phần nằm trên thân kẹo của một khối đa ô: vệt bóng, dấu sương mù, xích và ổ khoá, ảnh chìa. Thân (mép gối, sọc,
## bóng đổ, hoặc chất liệu crystal của khối đặc biệt), lớp pudding, hộp giấy và lớp sương phủ do `Pudding.Body` vẽ bằng
## shader nằm sau BlockNode, theo concept `art/concepts/concept_candy_board_v5_stripe.png` và
## `concept_candy_board_v3_crystal.png`. `cells` tính theo toạ độ ô gốc của chính CanvasItem này.
## Mỗi biểu tượng một ô: ổ khoá nằm trên đường xích, chìa ở ô gần tâm nhất còn trống, dấu sương ở ô kế tiếp còn trống
## (không còn ô thì bỏ dấu sương, lớp sương phủ đã cho biết khối còn trong sương).
static func draw_block(ci: CanvasItem, cells: Array, cell: float, view: Dictionary) -> void:
	var fog_hidden: bool = view.get("is_fog_hidden", false)
	var chained: bool = view.get("chained", false)
	var is_key: bool = view.get("is_key", false)
	var ribbons := int(view.get("ribbons", 0))
	# hộp giấy mờ không bóng, ruy băng có bóng satin riêng; khối trong sương thì vệt bóng chìm dưới lớp sương
	if str(view.get("inner_color", "")) == "" and ribbons == 0 and not fog_hidden:
		if is_crystal(view):
			draw_crystal_gloss(ci, cells, cell)
		else:
			draw_gloss(ci, cells, cell)
	var taken: Array = []
	var bow_at := ribbon_center(cells)
	if ribbons > 0:
		taken.append(Vector2i(bow_at.floor()))
	var lock_at := Vector2.ZERO
	if chained:
		lock_at = chain_center(cells)
		taken.append(Vector2i(lock_at.floor()))
	var key_cell := Vector2i.ZERO
	if is_key:
		key_cell = anchor_cell(cells, taken)
		taken.append(key_cell)
	if fog_hidden:
		var mark := anchor_cell(cells, taken)
		if not taken.has(mark):
			draw_fog_mark(ci, mark, cell)
	if chained:
		draw_chain(ci, cells, cell)
		draw_lock(ci, lock_at * cell, cell)
	if is_key:
		draw_key(ci, (Vector2(key_cell) + Vector2(0.5, 0.5)) * cell, cell)
	# nơ không vẽ khi khối còn trong sương (nơ nằm trên lớp sương sẽ lộ khối ruy băng)
	if ribbons > 0 and not fog_hidden:
		draw_bow(ci, bow_at * cell, cell, block_ramp(view))


## Tâm nơ của khối ruy băng (toạ độ ô của khối): trọng tâm các ô, kéo vào ô gần trọng tâm nhất (khối L, T có trọng tâm
## nằm ngoài khối).
static func ribbon_center(cells: Array) -> Vector2:
	var sum := Vector2.ZERO
	for c: Vector2i in cells:
		sum += Vector2(c) + Vector2(0.5, 0.5)
	var mid := sum / maxf(1.0, float(cells.size()))
	var near: Vector2i = cells[0]
	for c: Vector2i in cells:
		if (Vector2(c) + Vector2(0.5, 0.5)).distance_squared_to(mid) < (Vector2(near) + Vector2(0.5, 0.5)).distance_squared_to(mid):
			near = c
	return Vector2(clampf(mid.x, near.x, near.x + 1.0), clampf(mid.y, near.y, near.y + 1.0))


## Nơ satin to (ảnh `ribbon_bow` rộng RIBBON_BOW ô) ở `center`, tô theo bốn tông `ramp` của khối: bóng đổ, viền tối,
## thân màu mặt khối, nếp gấp màu đáy, vệt bóng sáng (`bow_parts`). Thiếu ảnh thì không vẽ (dải chéo vẫn còn).
static func draw_bow(ci: CanvasItem, center: Vector2, cell: float, ramp: Dictionary) -> void:
	var parts := bow_parts()
	if parts.is_empty():
		return
	var side := cell * RIBBON_BOW * float(parts["scale"])
	var rect := Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side))
	var deep: Color = ramp["deep"]
	ci.draw_texture_rect(parts["drop"], rect, false, Color(RIBBON_BOW_SHADOW, RIBBON_BOW_SHADOW_A))
	ci.draw_texture_rect(parts["rim"], rect, false, deep.darkened(RIBBON_BOW_RIM_DARK))
	ci.draw_texture_rect(parts["base"], rect, false, ramp["face"])
	ci.draw_texture_rect(parts["dark"], rect, false, deep)
	ci.draw_texture_rect(parts["light"], rect, false, (ramp["stripe"] as Color).lightened(RIBBON_BOW_SHINE))


## Các lớp trắng (chỉ khác alpha) của nơ, dựng một lần từ `ribbon_bow` rồi tô bằng modulate theo từng khối:
## {"drop", "rim", "base", "dark", "light": Texture2D, "scale": cạnh ảnh lớp / cạnh ảnh gốc}. Ảnh gốc gần như toàn màu
## sáng nên độ sáng đổi thành phân vị trong thân nơ: dưới RIBBON_BOW_DARK là nếp tối, trên RIBBON_BOW_LIGHT là vệt
## sáng, giữa là màu mặt khối. Mép alpha mềm
## của ảnh tách nền được làm cứng lại; viền là thân nơ nở thêm RIBBON_BOW_RIM, bóng đổ là viền dời xuống RIBBON_BOW_DROP
## (theo cạnh ảnh gốc). {} nếu chưa có ảnh.
static func bow_parts() -> Dictionary:
	if not _bow_parts.is_empty():
		return _bow_parts
	var tex := mech_tex("ribbon_bow")
	if tex == null:
		return {}
	var src := tex.get_image()
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	var n := src.get_width()
	var rim_px := maxi(1, roundi(n * RIBBON_BOW_RIM))
	var drop_px := roundi(n * RIBBON_BOW_DROP)
	var pad := rim_px + drop_px
	var size := n + pad * 2
	# Độ sáng làm mịn trước (thu nhỏ rồi phóng lại) để phân vị không phóng to hạt nhiễu của ảnh gốc thành lấm tấm.
	var soft := src.duplicate() as Image
	soft.resize(maxi(1, n / RIBBON_BOW_SMOOTH), maxi(1, src.get_height() / RIBBON_BOW_SMOOTH), Image.INTERPOLATE_LANCZOS)
	soft.resize(n, src.get_height(), Image.INTERPOLATE_BILINEAR)
	# Độ sáng đổi thành phân vị trong thân nơ (CDF), nên tỉ lệ nếp tối, thân, vệt sáng không phụ thuộc ảnh gốc sáng hay tối.
	var hist := PackedInt32Array()
	hist.resize(256)
	var total := 0
	for y in src.get_height():
		for x in n:
			if src.get_pixel(x, y).a > 0.6:
				hist[clampi(int(soft.get_pixel(x, y).get_luminance() * 255.0), 0, 255)] += 1
				total += 1
	var cdf := PackedFloat32Array()
	cdf.resize(256)
	var run := 0
	for k in 256:
		run += hist[k]
		cdf[k] = float(run) / float(maxi(total, 1))
	var base := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var dark := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var light := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in src.get_height():
		for x in n:
			var c := src.get_pixel(x, y)
			var a := clampf((c.a - 0.15) / 0.55, 0.0, 1.0)
			if a <= 0.0:
				continue
			var t := cdf[clampi(int(soft.get_pixel(x, y).get_luminance() * 255.0), 0, 255)]
			base.set_pixel(x + pad, y + pad, Color(1, 1, 1, a))
			dark.set_pixel(x + pad, y + pad, Color(1, 1, 1, a * clampf((RIBBON_BOW_DARK - t) / RIBBON_BOW_DARK, 0.0, 1.0)))
			light.set_pixel(x + pad, y + pad, Color(1, 1, 1,
				a * clampf((t - RIBBON_BOW_LIGHT) / (1.0 - RIBBON_BOW_LIGHT), 0.0, 1.0)))
	var all := Rect2i(0, 0, size, size)
	var rim := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for dy in range(-rim_px, rim_px + 1):
		for dx in range(-rim_px, rim_px + 1):
			if dx * dx + dy * dy <= rim_px * rim_px:
				rim.blend_rect(base, all, Vector2i(dx, dy))
	var drop := Image.create(size, size, false, Image.FORMAT_RGBA8)
	drop.blend_rect(rim, all, Vector2i(0, drop_px))
	_bow_parts = {"scale": float(size) / float(n)}
	for k: String in ["drop", "rim", "base", "dark", "light"]:
		var img: Image = {"drop": drop, "rim": rim, "base": base, "dark": dark, "light": light}[k]
		_bow_parts[k] = ImageTexture.create_from_image(img)
	return _bow_parts


## Lớp sương phủ của thân khối (`pudding.gdshader`): `fog` 0..1; `origin` là ô gốc của khối trên bàn để các khối sương
## cạnh nhau chung một đám sương liền.
static func set_fog(body: Control, fog: float, origin: Vector2) -> void:
	var m := body.material as ShaderMaterial
	m.set_shader_parameter("fog", fog)
	m.set_shader_parameter("fog_origin", origin)


## Ổ khoá vàng có quai thép; `center` là tâm thân khoá. `open` 0..1 nhấc quai lên (lúc xích đứt).
static func draw_lock(ci: CanvasItem, center: Vector2, cell: float, open: float = 0.0) -> void:
	var w := cell * 0.38
	var h := cell * 0.3
	var body := Rect2(center.x - w * 0.5, center.y - h * 0.32, w, h)
	var line := maxf(2.0, cell * 0.075)
	var shackle := Vector2(center.x + w * 0.16 * open, body.position.y - cell * 0.1 * open)
	var sr := w * 0.3
	ci.draw_arc(shackle + Vector2(0, cell * 0.02), sr, PI, TAU, 16, CHAIN_DARK, line + 2.0)
	ci.draw_line(shackle + Vector2(-sr, cell * 0.02), shackle + Vector2(-sr, cell * 0.09), CHAIN_DARK, line + 2.0)
	ci.draw_line(shackle + Vector2(sr, cell * 0.02), shackle + Vector2(sr, cell * 0.09), CHAIN_DARK, line + 2.0)
	ci.draw_arc(shackle + Vector2(0, cell * 0.02), sr, PI, TAU, 16, CHAIN_STEEL, line)
	ci.draw_line(shackle + Vector2(-sr, cell * 0.02), shackle + Vector2(-sr, cell * 0.09), CHAIN_STEEL, line)
	ci.draw_line(shackle + Vector2(sr, cell * 0.02), shackle + Vector2(sr, cell * 0.09), CHAIN_STEEL, line)
	var rad := int(cell * 0.07)
	var s := StyleBoxFlat.new()
	s.anti_aliasing = true
	s.set_corner_radius_all(rad)
	s.bg_color = CHAIN_DARK
	ci.draw_style_box(s, body.grow(1.5).grow_side(SIDE_BOTTOM, cell * 0.03))
	s.bg_color = LOCK_GOLD_DARK
	ci.draw_style_box(s, body)
	s.bg_color = LOCK_GOLD
	ci.draw_style_box(s, body.grow_side(SIDE_BOTTOM, -h * 0.22))
	s.bg_color = Color(1, 1, 1, 0.55)
	s.set_corner_radius_all(int(rad * 0.5))
	ci.draw_style_box(s, Rect2(body.position + Vector2(w * 0.14, h * 0.1), Vector2(w * 0.3, h * 0.13)))
	var hole := body.get_center() + Vector2(0, -h * 0.04)
	ci.draw_circle(hole, cell * 0.045, CHAIN_DARK)
	ci.draw_line(hole, hole + Vector2(0, h * 0.28), CHAIN_DARK, maxf(1.5, cell * 0.04))


## Tâm ổ khoá (toạ độ ô của khối): giữa khung khối, nơi đường chéo đi qua; khung lõm (tâm rơi vào ô trống, khối hình
## L, T) thì mắt xích gần tâm nhất.
static func chain_center(cells: Array) -> Vector2:
	var mid := tape_center(cells)
	if cells.has(Vector2i(mid.floor())):
		return mid
	var best := mid
	var best_d := INF
	for l: Array in chain_links(cells):
		var d := (l[0] as Vector2).distance_squared_to(mid)
		if d < best_d:
			best_d = d
			best = l[0]
	return best


## Đường xích của khối (toạ độ ô của khối): một đường chéo trong khung khối, hai đầu lùi vào trong mép CHAIN_IN nên
## xích nằm gọn trên thân khối. Chọn đường chéo có nhiều mắt nằm trên ô của khối hơn (khối hình L, T); bằng nhau thì
## đường từ góc trên trái xuống góc dưới phải. Trả [đầu, cuối].
static func chain_path(cells: Array) -> Array:
	var box := _cell_box(cells)
	var lo: Vector2 = box[0]
	var hi: Vector2 = box[1]
	var o := Vector2(CHAIN_IN, CHAIN_IN)
	var down := [lo + o, hi - o]
	var up := [Vector2(hi.x - o.x, lo.y + o.y), Vector2(lo.x + o.x, hi.y - o.y)]
	return up if _links_on(cells, up).size() > _links_on(cells, down).size() else down


## Mắt xích của khối theo `chain_path` (toạ độ ô của khối): mỗi phần tử [tâm, hướng, mặt tròn?]. Chỉ giữ mắt mà tâm
## và bốn đầu mút đều nằm trên ô của khối, nên ở góc lõm (khối hình L, T) xích không chìa sang ô trống.
static func chain_links(cells: Array) -> Array:
	return _links_on(cells, chain_path(cells))


static func _links_on(cells: Array, seg: Array) -> Array:
	var occ := {}
	for c: Vector2i in cells:
		occ[c] = true
	var a: Vector2 = seg[0]
	var b: Vector2 = seg[1]
	var n := maxi(2, 2 * int(round(a.distance_to(b) / (2.0 * CHAIN_LINK))))  # số khoảng chẵn: hai đầu là mắt tròn
	var t := (b - a).normalized()
	var along := t * (CHAIN_RX + CHAIN_W)
	var across := Vector2(-t.y, t.x) * (CHAIN_RY + CHAIN_W)
	var out: Array = []
	for i in n + 1:
		var p: Vector2 = a.lerp(b, float(i) / n)
		var fits := true
		for q: Vector2 in [p, p - along, p + along, p - across, p + across]:
			fits = fits and occ.has(Vector2i(q.floor()))
		if fits:
			out.append([p, t, i % 2 == 0])
	return out


## Khung ô của khối: [góc nhỏ, góc lớn] theo toạ độ ô.
static func _cell_box(cells: Array) -> Array:
	var lo := Vector2(INF, INF)
	var hi := -lo
	for c: Vector2i in cells:
		lo = lo.min(Vector2(c))
		hi = hi.max(Vector2(c) + Vector2.ONE)
	return [lo, hi]


## Xích thép quấn khối theo một đường chéo: mắt xích xen kẽ mặt tròn và mặt nghiêng, có bóng đổ và viền tối. Cả lớp
## xích là một triangle array (một draw call), dựng một lần cho mỗi hình khối và cỡ ô rồi giữ trong cache.
static func draw_chain(ci: CanvasItem, cells: Array, cell: float) -> void:
	var key := "%s|%.2f" % [_cells_key(cells), cell]
	if not _chain_mesh.has(key):
		if _chain_mesh.size() >= CHAIN_MESH_MAX:
			_chain_mesh.clear()
		_chain_mesh[key] = _chain_strokes(cells, cell)
	var m: Strokes = _chain_mesh[key]
	if not m.idx.is_empty():
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), m.idx, m.verts, m.cols)


static func _cells_key(cells: Array) -> String:
	var parts := PackedStringArray()
	for c: Vector2i in cells:
		parts.append("%d,%d" % [c.x, c.y])
	parts.sort()
	return ";".join(parts)


## Hình cả lớp xích theo thứ tự vẽ: bóng đổ mọi mắt, rồi mắt nghiêng, rồi mắt tròn đè lên.
static func _chain_strokes(cells: Array, cell: float) -> Strokes:
	var links := chain_links(cells)
	var w := maxf(1.2, cell * CHAIN_W)
	var s := Strokes.new()
	for l: Array in links:
		_chain_link(s, (l[0] as Vector2) * cell + Vector2(0, cell * 0.035), l[1], cell, w, Color(0.05, 0.04, 0.2, 0.35), Color(0, 0, 0, 0), l[2])
	for l: Array in links:
		if not l[2]:
			_chain_link(s, (l[0] as Vector2) * cell, l[1], cell, w, CHAIN_DARK, CHAIN_STEEL, false)
	for l: Array in links:
		if l[2]:
			_chain_link(s, (l[0] as Vector2) * cell, l[1], cell, w, CHAIN_DARK, CHAIN_STEEL, true)
	return s


## Một mắt xích tại `p` (px) theo hướng `t`: mặt tròn là vòng bầu dục, mặt nghiêng là thanh ngắn.
## `steel` trong suốt thì chỉ có một lượt màu `dark` (bóng đổ).
static func _chain_link(s: Strokes, p: Vector2, t: Vector2, cell: float, w: float, dark: Color, steel: Color, face_on: bool) -> void:
	var nrm := Vector2(-t.y, t.x)
	if face_on:
		var pts := PackedVector2Array()
		for k in 17:
			var ang := TAU * k / 16.0
			pts.append(p + t * cos(ang) * cell * CHAIN_RX + nrm * sin(ang) * cell * CHAIN_RY)
		s.stroke(pts, w + 2.0, dark)
		if steel.a > 0.0:
			s.stroke(pts, w, steel)
			var hi := PackedVector2Array()
			for k in range(9, 13):
				var ang := TAU * k / 16.0
				hi.append(p + t * cos(ang) * cell * CHAIN_RX + nrm * sin(ang) * cell * CHAIN_RY)
			s.stroke(hi, maxf(1.0, w * 0.45), CHAIN_SHINE)
	else:
		var half := t * cell * CHAIN_BAR
		s.stroke(PackedVector2Array([p - half, p + half]), w * 1.5 + 2.0, dark)
		if steel.a > 0.0:
			s.stroke(PackedVector2Array([p - half, p + half]), w * 1.5, steel.darkened(0.12))
			var off := nrm * w * 0.25
			s.stroke(PackedVector2Array([p - half * 0.6 - off, p + half * 0.6 - off]), maxf(1.0, w * 0.4), CHAIN_SHINE)


## Nét có bề dày dựng thành tam giác cho `canvas_item_add_triangle_array`. Mỗi điểm bốn đỉnh ngang nét: mép mờ ngoài,
## mép đặc, mép đặc, mép mờ ngoài; mép mờ dày FEATHER px đặt giữa mép nét (khớp `draw_polyline` có antialiased), hai
## đầu nét hở cũng mờ dần. Nét có điểm đầu trùng điểm cuối là vòng kín.
class Strokes extends RefCounted:
	const FEATHER := 1.5
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()

	func stroke(pts: PackedVector2Array, width: float, col: Color) -> void:
		var n := pts.size()
		if n < 2:
			return
		var closed := n > 2 and pts[0].is_equal_approx(pts[n - 1])
		var a_in := maxf(width * 0.5 - FEATHER * 0.5, 0.0)
		var a_out := width * 0.5 + FEATHER * 0.5
		var clear := Color(col, 0.0)
		var base := verts.size()
		var rows := 0
		if not closed:
			var t0 := (pts[1] - pts[0]).normalized()
			_row(pts[0] - t0 * FEATHER, t0, a_in, a_out, clear, clear)
			rows += 1
		for i in n:
			var prev: Vector2
			var next: Vector2
			if closed:
				prev = pts[n - 2] if i == 0 else pts[i - 1]
				next = pts[1] if i == n - 1 else pts[i + 1]
			else:
				prev = pts[maxi(i - 1, 0)]
				next = pts[mini(i + 1, n - 1)]
			_row(pts[i], (next - prev).normalized(), a_in, a_out, col, clear)
			rows += 1
		if not closed:
			var t1 := (pts[n - 1] - pts[n - 2]).normalized()
			_row(pts[n - 1] + t1 * FEATHER, t1, a_in, a_out, clear, clear)
			rows += 1
		for r in rows - 1:
			var b := base + r * 4
			for k in 3:
				idx.append_array(PackedInt32Array([b + k, b + k + 1, b + k + 4, b + k + 1, b + k + 5, b + k + 4]))

	func _row(p: Vector2, t: Vector2, a_in: float, a_out: float, col: Color, clear: Color) -> void:
		var nrm := Vector2(-t.y, t.x)
		verts.append_array(PackedVector2Array([p - nrm * a_out, p - nrm * a_in, p + nrm * a_in, p + nrm * a_out]))
		cols.append_array(PackedColorArray([clear, col, col, clear]))


## Chìa: ảnh chìa vàng to (`mech_key`, cạnh KEY_SIZE ô) giữa ô `center` của khối chìa; không có đường nối tới khối bị
## xích. Thiếu ảnh thì vẽ chìa bằng nét cùng cỡ.
static func draw_key(ci: CanvasItem, center: Vector2, cell: float) -> void:
	var side := cell * KEY_SIZE
	var tex := mech_tex("mech_key")
	if tex != null:
		ci.draw_texture_rect(tex, Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side)), false)
		return
	var rad := side * 0.5
	var w := maxf(2.0, cell * 0.06)
	var head := center + Vector2(-rad * 0.45, 0.0)
	ci.draw_arc(head, rad * 0.32, 0.0, TAU, 20, KEY_COLOR, w)
	ci.draw_line(head + Vector2(rad * 0.32, 0), center + Vector2(rad * 0.8, 0), KEY_COLOR, w)
	ci.draw_line(center + Vector2(rad * 0.4, 0), center + Vector2(rad * 0.4, rad * 0.35), KEY_COLOR, w)
	ci.draw_line(center + Vector2(rad * 0.7, 0), center + Vector2(rad * 0.7, rad * 0.35), KEY_COLOR, w)


## Dấu sương mù giữa ô `at` của khối còn trong sương: ảnh `mech_fog` (thiếu ảnh thì dấu "?"). Lớp sương phủ do
## `pudding.gdshader` vẽ (`set_fog`).
static func draw_fog_mark(ci: CanvasItem, at: Vector2i, cell: float) -> void:
	var center := (Vector2(at) + Vector2(0.5, 0.5)) * cell
	var tex := mech_tex("mech_fog")
	if tex != null:
		var side := cell * FOG_MARK
		ci.draw_texture_rect(tex, Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side)), false)
		return
	var font := ThemeDB.fallback_font
	var fs := int(cell * 0.55)
	ci.draw_string(font, center + Vector2(-cell * 0.5, fs * 0.35), "?", HORIZONTAL_ALIGNMENT_CENTER, cell, fs, Color(1, 1, 1, 0.75))


## Thùng sắt: nắp thép xanh xám phủ kín ô, viền nổi, bốn đinh tán to ở bốn góc nắp; `r` là hình chữ nhật của ô.
## `squash` co giãn quanh tâm ô (thùng bị gõ rung). Ảnh `mech_stone` (thùng sắt) có lề trong suốt nên vẽ to hơn ô một chút.
static func draw_crate(ci: CanvasItem, r: Rect2, cell: float, squash: Vector2 = Vector2.ONE) -> void:
	r = _squashed(r, squash)
	var tex := mech_tex("mech_stone")
	if tex != null:
		ci.draw_texture_rect(tex, r.grow(cell * CRATE_GROW), false)
		return
	var g := r.grow(-cell * 0.03)
	var s := StyleBoxFlat.new()
	s.anti_aliasing = true
	s.set_corner_radius_all(int(cell * 0.14))
	s.bg_color = Color(0.09, 0.08, 0.26, 0.34)
	ci.draw_style_box(s, Rect2(g.position + Vector2(0, cell * 0.07), g.size))
	# viền thép nổi: mép trên sáng, mép dưới tối
	s.bg_color = IRON_DARK
	ci.draw_style_box(s, g)
	s.bg_color = IRON_LIGHT
	ci.draw_style_box(s, g.grow_side(SIDE_BOTTOM, -cell * 0.06))
	s.bg_color = IRON
	ci.draw_style_box(s, g.grow(-cell * 0.035))
	# nắp phẳng lõm trong viền, một vệt sáng chéo
	var lid := g.grow(-cell * 0.065)
	s.set_corner_radius_all(int(cell * 0.05))
	s.bg_color = IRON_DARK
	ci.draw_style_box(s, lid.grow(maxf(1.0, cell * 0.02)))
	s.bg_color = IRON
	ci.draw_style_box(s, lid)
	_draw_band(ci, lid, 0.38, cell * 0.16, Color(1, 1, 1, 0.12))
	# bốn đinh tán to: viền tối, thân bạc, chỏm sáng, chấm bóng
	for b: Vector2 in CRATE_BOLTS:
		var at := r.position + r.size * b
		var br := cell * CRATE_BOLT_R
		ci.draw_circle(at + Vector2(br * 0.2, br * 0.35), br * 1.05, Color(0.09, 0.08, 0.26, 0.4))
		ci.draw_circle(at, br, IRON_DARK)
		ci.draw_circle(at, br * 0.82, IRON_LIGHT)
		ci.draw_circle(at - Vector2(br, br) * 0.12, br * 0.6, BOLT)
		ci.draw_circle(at - Vector2(br, br) * 0.32, br * 0.24, Color.WHITE)


## Thùng sắt bị va: loé trắng cả nắp, vệt sáng quét chéo từ góc trên trái xuống, đinh loé sao khi vệt sáng đi qua.
## `t` 0..1 theo thời gian rung; `r`, `squash` như draw_crate.
static func draw_crate_glint(ci: CanvasItem, r: Rect2, cell: float, t: float, squash: Vector2 = Vector2.ONE) -> void:
	r = _squashed(r, squash)
	var face := r.grow(-cell * 0.05)
	var hit := 1.0 - clampf(t / 0.3, 0.0, 1.0)
	if hit > 0.0:
		var s := StyleBoxFlat.new()
		s.anti_aliasing = true
		s.set_corner_radius_all(int(cell * 0.12))
		s.bg_color = Color(1, 1, 1, 0.4 * hit * hit)
		ci.draw_style_box(s, face)
	var sweep := clampf(t / 0.65, 0.0, 1.0)
	if sweep >= 1.0:
		return
	_draw_band(ci, face, sweep, cell * 0.24, Color(1, 1, 1, 0.5 * (1.0 - sweep * 0.6)))
	var star := _sparkle_texture()
	for b: Vector2 in CRATE_BOLTS:
		var lit := clampf(1.0 - absf(sweep - (b.x + b.y) * 0.5) / 0.25, 0.0, 1.0)
		if lit <= 0.0:
			continue
		var at := r.position + r.size * b
		var sz := Vector2(cell, cell) * 0.8 * lit
		ci.draw_circle(at, cell * CRATE_BOLT_R * 1.1, Color(1, 1, 1, 0.7 * lit))
		ci.draw_texture_rect(star, Rect2(at - sz * 0.5, sz), false, Color(1, 1, 1, lit))


static func _squashed(r: Rect2, squash: Vector2) -> Rect2:
	var c := r.get_center()
	return Rect2(c - r.size * squash * 0.5, r.size * squash)


## Dải sáng chéo "/" cắt theo `r`: `at` 0..1 đưa tâm dải từ góc trên trái tới góc dưới phải, `w` bề rộng dải (px).
static func _draw_band(ci: CanvasItem, r: Rect2, at: float, w: float, col: Color) -> void:
	var far := r.size.x + r.size.y
	var u := lerpf(-w * 0.5, far + w * 0.5, at)  # dải là các điểm có x + y (tính từ góc trên trái) trong u ± w/2
	var a := u - w * 0.5
	var b := u + w * 0.5
	var band := Transform2D(0.0, r.position) * PackedVector2Array([
		Vector2(a + far, -far), Vector2(a - far, far), Vector2(b - far, far), Vector2(b + far, -far)])
	var box := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	for poly: PackedVector2Array in Geometry2D.intersect_polygons(band, box):
		ci.draw_colored_polygon(poly, col)


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


## Loé sáng tại `pos` (toạ độ canvas): quầng tròn, sao bốn cánh, vòng sóng. Nằm trên mọi thứ, tự xoá khi xong.
static func impact_flash(parent: Node, pos: Vector2, tint: Color, size: float, dur: float = 0.34, ring: float = 0.7) -> ColorRect:
	var r := ColorRect.new()
	r.name = "Flash"
	r.top_level = true
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = FLASH_SHADER
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("ring_a", ring)
	r.material = m
	parent.add_child(r)
	r.size = Vector2(size, size)
	r.global_position = pos - r.size * 0.5
	var tw := r.create_tween()
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("t", v), 0.0, 1.0, dur)
	tw.finished.connect(r.queue_free)
	return r


## Biên dịch sẵn shader loé sáng: `t` = 1 nên không hiện gì.
static func prewarm_flash(parent: Node) -> void:
	var flash := impact_flash(parent, Vector2(4, 4), Color.WHITE, 4.0, 0.05)
	(flash.material as ShaderMaterial).set_shader_parameter("t", 1.0)


## Sao lấp lánh bắn theo `dir` từ `pos` (toạ độ canvas), màu theo tông sáng của khối. Nằm trên mọi thứ, tự xoá khi xong.
static func sparkles(parent: Node, pos: Vector2, ramp: Dictionary, dir: Vector2, strength: float, amount: int) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "Sparkles"
	p.top_level = true
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.75
	p.explosiveness = 0.92
	p.randomness = 0.5
	p.texture = _sparkle_texture()
	p.direction = dir
	p.spread = 72.0
	p.gravity = Vector2(0.0, 900.0 * strength)
	p.initial_velocity_min = 240.0 * strength
	p.initial_velocity_max = 860.0 * strength
	p.damping_min = 260.0 * strength
	p.damping_max = 620.0 * strength
	p.angular_velocity_min = -420.0
	p.angular_velocity_max = 420.0
	p.scale_amount_min = 0.35 * strength
	p.scale_amount_max = 1.0 * strength
	p.scale_amount_curve = _shrink()
	var g := Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color(ramp["stripe"], 0.0))
	g.add_point(0.45, ramp["stripe"].lerp(Color.WHITE, 0.45))
	p.color_ramp = g
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	p.finished.connect(p.queue_free)
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	return p


## Hình sao bốn cánh trắng (48 px) cho hiệu ứng ngoài bàn, như sao Gợi ý.
static func sparkle_texture() -> Texture2D:
	return _sparkle_texture()


## Hình sao bốn cánh dựng một lần bằng code.
static func _sparkle_texture() -> Texture2D:
	if _sparkle_tex == null:
		var n := 48
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var mid := (float(n) - 1.0) * 0.5
		for y in n:
			for x in n:
				var px := absf(float(x) - mid) / mid
				var py := absf(float(y) - mid) / mid
				var r := sqrt(px * px + py * py)
				var core := exp(-r * r * 22.0)
				var rays := exp(-px * 22.0) * (1.0 - py) + exp(-py * 22.0) * (1.0 - px)
				img.set_pixel(x, y, Color(1, 1, 1, clampf(core + rays * rays, 0.0, 1.0)))
		_sparkle_tex = ImageTexture.create_from_image(img)
	return _sparkle_tex


## Đường cong co nhỏ dần về 0 cho cỡ hạt.
static func shrink_curve() -> Curve:
	return _shrink()


static func _shrink() -> Curve:
	if _shrink_curve == null:
		_shrink_curve = Curve.new()
		_shrink_curve.add_point(Vector2(0.0, 1.0))
		_shrink_curve.add_point(Vector2(0.35, 0.8))
		_shrink_curve.add_point(Vector2(1.0, 0.0))
	return _shrink_curve


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
