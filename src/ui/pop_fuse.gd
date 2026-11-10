extends Control
## Ngòi bom kẹo (design.md mục 4 dòng Bom kẹo, mục 8 "Bom kẹo nổ"): ảnh ngòi cam thảo dáng đứng (`assets/ui/pop_fuse.png`)
## xoay Config.POP_FUSE_ANGLE độ ngược chiều kim đồng hồ, cao Config.POP_FUSE_SIZE ô sau khi xoay; tâm cách góc trên trái
## của ô trái nhất hàng trên cùng của khối vào Config.POP_FUSE_INSET ô theo cả hai trục; bóng đổ lệch
## Config.POP_FUSE_SHADOW ô. Đầu ngòi có quầng sáng và chùm tia lách tách vàng trắng vẽ bằng code, luôn toả lên trên dù
## ngòi nghiêng, đổi chùm mỗi SPARK_EVERY giây (cháy đều mãi, không ngắn dần). Là con của khối (BoardView.BlockNode) nên đi
## theo khối; BoardView vẽ khối bom kẹo sau mọi khối nên nửa đầu ngòi đè lên khối bên cạnh.
## `Wave` (lớp trong): sóng nổ, mỗi ô của vùng nổ loé một ô vuông, lần lượt từ gần ra xa.

const Config := preload("res://src/config.gd")
const TEX_PATH := "res://assets/ui/pop_fuse.png"
## Đầu ngòi trong ảnh (theo tỉ lệ cạnh ảnh), đo trên assets/ui/pop_fuse.png.
const TIP := Vector2(0.675, 0.02)
const SPARKS := 9  # số tia mỗi chùm
const SPARK_LEN := Vector2(0.12, 0.34)  # tia dài từ .. tới, theo ô
const SPARK_WIDTH := 0.022  # bề dày tia, theo ô
const SPARK_SPREAD := 80.0  # tia toả lệch tối đa chừng này độ quanh hướng lên
const SPARK_EVERY := 0.06  # giây đổi chùm tia
const GLOW := 0.17  # quầng sáng đầu ngòi, bán kính theo ô
const GLOW_COLOR := Color(1.0, 0.82, 0.38, 0.38)
const CORE_COLOR := Color(1.0, 0.97, 0.86, 0.9)
const SPARK_COLORS := [Color(1.0, 0.98, 0.86), Color(1.0, 0.87, 0.4), Color(1.0, 0.72, 0.28)]
const SHADOW_TINT := Color(0.22, 0.06, 0.14, 0.32)

static var _tex: Texture2D = null

## false: ngòi đã nổ (không vẽ tia nữa).
var burning: bool = true

var _rng := RandomNumberGenerator.new()
var _clock := 0.0
var _sparks: Array = []  # [góc lệch (độ), dài (ô), chỉ số màu]


func _init() -> void:
	name = "PopFuse"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	_reroll()


func _process(delta: float) -> void:
	if not burning or not is_visible_in_tree():
		return
	_clock += delta
	if _clock >= SPARK_EVERY:
		_clock = 0.0
		_reroll()
		queue_redraw()


static func texture() -> Texture2D:
	if _tex == null and ResourceLoader.exists(TEX_PATH):
		_tex = load(TEX_PATH)
	return _tex


## Cỡ ô của khối cha (BlockNode.cell_size).
func cell() -> float:
	var p := get_parent()
	return float(p.get("cell_size")) if p != null and p.get("cell_size") != null else 64.0


## Tâm ngòi, toạ độ của khối cha: góc trên trái của ô trái nhất hàng trên cùng, lùi vào POP_FUSE_INSET ô.
func center() -> Vector2:
	var p := get_parent()
	var best := Vector2i(1 << 20, 1 << 20)
	if p != null and p.has_method("local_cells"):
		for c: Vector2i in p.local_cells():
			if c.y < best.y or (c.y == best.y and c.x < best.x):
				best = c
	if best.x == 1 << 20:
		best = Vector2i.ZERO
	return (Vector2(best) + Vector2.ONE * Config.POP_FUSE_INSET) * cell()


## Cỡ ảnh ngòi trên màn để sau khi xoay cao POP_FUSE_SIZE ô.
func sprite_size() -> Vector2:
	var tex := texture()
	if tex == null:
		return Vector2.ZERO
	var a := deg_to_rad(Config.POP_FUSE_ANGLE)
	var w := float(tex.get_width())
	var h := float(tex.get_height())
	var k := Config.POP_FUSE_SIZE * cell() / (w * sin(a) + h * cos(a))
	return Vector2(w, h) * k


## Đầu ngòi, toạ độ của khối cha.
func tip() -> Vector2:
	return center() + ((TIP - Vector2(0.5, 0.5)) * sprite_size()).rotated(-deg_to_rad(Config.POP_FUSE_ANGLE))


func _reroll() -> void:
	_sparks.clear()
	for _i in SPARKS:
		_sparks.append([_rng.randf_range(-SPARK_SPREAD, SPARK_SPREAD), _rng.randf_range(SPARK_LEN.x, SPARK_LEN.y),
			_rng.randi_range(0, SPARK_COLORS.size() - 1)])


func _draw() -> void:
	var tex := texture()
	var cs := cell()
	if tex != null:
		var s := sprite_size()
		var a := -deg_to_rad(Config.POP_FUSE_ANGLE)
		var c := center()
		draw_set_transform(c + Config.POP_FUSE_SHADOW * cs, a, Vector2.ONE)
		draw_texture_rect(tex, Rect2(-s * 0.5, s), false, SHADOW_TINT)
		draw_set_transform(c, a, Vector2.ONE)
		draw_texture_rect(tex, Rect2(-s * 0.5, s), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not burning:
		return
	var p := tip()
	draw_circle(p, GLOW * cs, GLOW_COLOR)
	for sp: Array in _sparks:
		var dir := Vector2.UP.rotated(deg_to_rad(float(sp[0])))
		var col: Color = SPARK_COLORS[int(sp[2])]
		var end := p + dir * float(sp[1]) * cs
		draw_line(p + dir * cs * 0.04, end, col, maxf(1.0, SPARK_WIDTH * cs), true)
		draw_circle(end, maxf(0.8, SPARK_WIDTH * cs * 0.9), col)
	draw_circle(p, GLOW * 0.45 * cs, CORE_COLOR)


## Sóng nổ: mỗi ô của vùng nổ loé một ô vuông vàng trắng rồi mờ, ô ở bậc khoảng cách k trễ k * Config.POP_STAGGER
## giây. Toạ độ canvas (top_level), tự xoá khi xong.
class Wave extends Control:
	const Config := preload("res://src/config.gd")
	const LIFE := 0.32  # giây một ô loé rồi tắt
	const FILL := Color(1.0, 0.93, 0.62, 0.55)
	const EDGE := Color(1.0, 0.99, 0.9, 0.85)
	var _cells: Array = []  # [Rect2 canvas, trễ (giây)]
	var _t := 0.0
	var _cell := 64.0

	## `cells`: [[Rect2 toạ độ canvas, bậc khoảng cách], ...]; `cell` cỡ ô trên màn.
	func setup(cells: Array, cell: float) -> void:
		name = "PopWave"
		top_level = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cell = cell
		for c: Array in cells:
			_cells.append([c[0], float(c[1]) * Config.POP_STAGGER])

	func _process(delta: float) -> void:
		_t += delta
		var last := 0.0
		for c: Array in _cells:
			last = maxf(last, float(c[1]))
		if _t > last + LIFE:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		for c: Array in _cells:
			var u := (_t - float(c[1])) / LIFE
			if u < 0.0 or u > 1.0:
				continue
			var k := (1.0 - u) * (1.0 - u)
			var r: Rect2 = (c[0] as Rect2).grow(_cell * (0.06 * u - 0.08))
			draw_rect(r, Color(FILL, FILL.a * k))
			draw_rect(r, Color(EDGE, EDGE.a * k), false, maxf(1.0, _cell * 0.05))
