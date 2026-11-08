extends Control
## Bản đồ Road Trip (wireframe Road Trip mục 1, 2): đường kẹo uốn qua mọi mốc, level 1 ở đáy, tăng dần lên trên.
## Bố cục theo RoadTrip.layout: hàng chạy 6 ô đổi chiều qua lại, hàng nối một mốc ở rìa; hộp quà rộng hai ô.
## Cả đường vẽ bằng _draw của một node (không tạo node theo mốc). Mốc: lục giác xám (khoá), xanh dương có dấu tích
## (đã qua), mốc hiện tại to hơn theo độ khó (xanh lá, đỏ Hard, tím Super Hard) với quầng sáng thở và mũi tên nhún
## (node con Glow, Arrow). Hộp: chưa tới nguyên màu, hộp đang nhắm có quầng sáng, đã mở mờ đi kèm dấu tích.
## Chạm (không kéo) một mốc hay hộp thì phát tapped(n, is_box). Toạ độ là px thiết kế khung rộng DESIGN_W, nhân k.
## Nằm trong ScrollContainer: mouse_filter PASS để kéo vẫn cuộn.

signal tapped(n: int, is_box: bool)

const RoadTrip := preload("res://src/meta/road_trip.gd")
const UiAtlas := preload("res://src/ui/ui_atlas.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")
const UiMotion := preload("res://src/ui/ui_motion.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")

const DESIGN_W := 886.0
## Tâm 6 cột, cao một hàng, lề trên/dưới của đường.
const COL_X := [109.0, 242.0, 375.0, 508.0, 641.0, 774.0]
const ROW_H := 150.0
const PAD_TOP := 200.0
const PAD_BOTTOM := 170.0
## Cỡ mốc thường, mốc hiện tại, hộp; cỡ chữ số; dấu tích.
const NODE := 112.0
const NODE_CUR := 140.0
const BOX := 180.0
const NUM_FONT := 48.0
const NUM_FONT_CUR := 60.0
const CHECK := 48.0
## Đường kẹo: viền tím, lòng kem, vạch hồng đứt khúc.
const ROAD_W := 44.0
const ROAD_EDGE_W := 12.0
const ROAD_EDGE := Color("B58AE6")
const ROAD := Color("FFF4FA")
const ROAD_DASH := Color("F7A8CB")
const DASH := 22.0
## Hộp thứ i dùng BOX_ICONS[i % 3]: vùng UiAtlas của atlas UI_Winstreak_Atlas (lấy texture qua box_tex).
const BOX_ICONS := ["gift_red", "gift_blue", "gift_purple"]
const CUR_SPRITE := {"": "hex_green", "hard": "hex_red", "very_hard": "hex_purple"}
const OUTLINE := {"locked": Color("787878"), "done": Color("076F87"), "": Color("4F7F10"), "hard": Color("911B35"),
	"very_hard": Color("4B1073")}
const GLOW_TEX := "res://assets/ui/figma/home_glow.png"
## Quầng sáng so với mốc; mũi tên: cỡ, phần đè lên đỉnh mốc (mốc hàng trên chỉ cách ROW_H nên mũi tên cắm vào đỉnh
## mốc như một cái ghim, không lấn sang mốc hàng trên), biên độ nhún.
const GLOW_K := 1.9
const ARROW := Vector2(58, 44)
const ARROW_OVERLAP := 24.0
const ARROW_BOB := 8.0
## Kéo quá chừng này (px màn) thì không tính là chạm.
const TAP_SLOP := 24.0

## Level đang chơi (levels + 1: đã đi hết), độ khó của nó, hệ số px thiết kế -> px màn.
var cur: int = 1
var tier: String = ""
var k: float = 1.0
## RoadTrip.layout(levels): [{n, row, col, box}].
var items: Array[Dictionary] = []

var _rows: int = 1
var _by_n: Dictionary = {}
var _press: Vector2 = Vector2.INF
var _glow: TextureRect = null
var _arrow_holder: Control = null
var _arrow: TextureRect = null
var _arrow_tw: Tween = null
var _glow_tex: Texture2D = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


func _ready() -> void:
	_ensure_markers()


## Dựng bố cục (một lần) và trạng thái hiện tại. k: px màn / px thiết kế.
func setup(current: int, current_tier: String, scale_k: float) -> void:
	if items.is_empty():
		items = RoadTrip.layout(RoadTrip.levels())
		_by_n.clear()
		for it in items:
			_by_n[int(it.n)] = it
			_rows = maxi(_rows, int(it.row) + 1)
	cur = current
	tier = current_tier if CUR_SPRITE.has(current_tier) else ""
	k = maxf(scale_k, 0.01)
	custom_minimum_size = Vector2(DESIGN_W, content_height()) * k
	size = custom_minimum_size
	_ensure_markers()
	_place_markers(cur)
	queue_redraw()


## Chiều cao bản đồ (px thiết kế).
func content_height() -> float:
	return PAD_TOP + PAD_BOTTOM + float(_rows - 1) * ROW_H


## Tâm mốc hoặc hộp `n` (px màn, toạ độ của node này). Ngoài đường thì tâm mốc gần nhất.
func center_of(n: int) -> Vector2:
	if items.is_empty():
		return Vector2.ZERO
	var it: Dictionary = _by_n.get(clampi(n, 1, items.size()), items[0])
	return _center(it)


func _center(it: Dictionary) -> Vector2:
	var col := int(it.col)
	var x: float = COL_X[col]
	if bool(it.box):
		x = (float(COL_X[col]) + float(COL_X[mini(col + 1, COL_X.size() - 1)])) * 0.5
	var y := content_height() - PAD_BOTTOM - float(it.row) * ROW_H
	return Vector2(x, y) * k


func _size_of(it: Dictionary) -> float:
	if bool(it.box):
		return BOX
	return NODE_CUR if int(it.n) == cur else NODE


# --- vẽ ---

func _draw() -> void:
	if items.is_empty():
		return
	var pts := PackedVector2Array()
	for it in items:
		pts.append(_center(it))
	_draw_road(pts)
	if _glow_tex == null and ResourceLoader.exists(GLOW_TEX):
		_glow_tex = load(GLOW_TEX) as Texture2D
	for it in items:
		if bool(it.box):
			_draw_box(it)
		else:
			_draw_node(it)


## Đường kẹo: viền, lòng, vạch đứt khúc dọc giữa; khớp nối là hình tròn để góc rẽ không hở.
func _draw_road(pts: PackedVector2Array) -> void:
	var outer := (ROAD_W + ROAD_EDGE_W) * k
	var inner := ROAD_W * k
	draw_polyline(pts, ROAD_EDGE, outer, true)
	for p in pts:
		draw_circle(p, outer * 0.5, ROAD_EDGE)
	draw_polyline(pts, ROAD, inner, true)
	for p in pts:
		draw_circle(p, inner * 0.5, ROAD)
	for i in range(pts.size() - 1):
		draw_dashed_line(pts[i], pts[i + 1], ROAD_DASH, 6.0 * k, DASH * k, true)


func _draw_node(it: Dictionary) -> void:
	var n := int(it.n)
	var st := RoadTrip.node_state(n, cur, false)
	var px := _size_of(it) * k
	var c := _center(it)
	var r := Rect2(c - Vector2(px, px) * 0.5, Vector2(px, px))
	var sprite := "hex_gray"
	var outline: Color = OUTLINE.locked
	match st:
		"done":
			sprite = "hex_blue"
			outline = OUTLINE.done
		"current":
			sprite = str(CUR_SPRITE[tier])
			outline = OUTLINE[tier]
	var tex := UiAtlas.tex(sprite)
	if tex != null:
		draw_texture_rect(tex, r, false)
	var fs := roundi((NUM_FONT_CUR if st == "current" else NUM_FONT) * k)
	_draw_number(str(n), c + Vector2(0, 3.0 * k), fs, outline)
	if st == "done":
		var ck := CHECK * k
		draw_texture_rect(ThemeKit.icon("ui_check"), Rect2(r.end - Vector2(ck, ck) * 0.85, Vector2(ck, ck)), false)


func _draw_box(it: Dictionary) -> void:
	var n := int(it.n)
	var st := RoadTrip.node_state(n, cur, true)
	var px := BOX * k
	var c := _center(it)
	var r := Rect2(c - Vector2(px, px) * 0.5, Vector2(px, px))
	if st == "target" and _glow_tex != null:
		var g := px * 1.6
		draw_texture_rect(_glow_tex, Rect2(c - Vector2(g, g) * 0.5, Vector2(g, g)), false, Color(1, 1, 1, 0.85))
	var tex := box_tex(RoadTrip.box_index(n))
	draw_texture_rect(tex, r, false, Color(1, 1, 1, 0.5) if st == "open" else Color.WHITE)
	if st == "open":
		var ck := CHECK * 1.3 * k
		draw_texture_rect(ThemeKit.icon("ui_check"), Rect2(c - Vector2(ck, ck) * 0.5, Vector2(ck, ck)), false)
	# Số level của hộp, nhỏ dưới đáy hộp.
	_draw_number(str(n), Vector2(c.x, r.end.y - 6.0 * k), roundi(NUM_FONT * 0.75 * k), OUTLINE.locked if st != "open" else OUTLINE.done)


## Ảnh hộp quà thứ box_i (RoadTrip.box_index; âm thì như hộp đầu). Dùng chung cho bản đồ, chip, popup thắng.
static func box_tex(box_i: int) -> Texture2D:
	return UiAtlas.tex(str(BOX_ICONS[maxi(box_i, 0) % BOX_ICONS.size()]))


## Số giữa tại tâm c: chữ trắng viền màu outline.
func _draw_number(text: String, c: Vector2, fs: int, outline: Color) -> void:
	var font: Font = ThemeKit.FONT
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base := Vector2(c.x - w * 0.5, c.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5)
	var ol := maxi(roundi(fs * 0.16), 2)
	draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ol, outline)
	draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


# --- mốc hiện tại: quầng sáng và mũi tên ---

func _ensure_markers() -> void:
	if _glow != null:
		return
	_glow = TextureRect.new()
	_glow.name = "Glow"
	_glow.texture = load(GLOW_TEX) as Texture2D if ResourceLoader.exists(GLOW_TEX) else null
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.show_behind_parent = true
	add_child(_glow)
	_glow.pivot_offset_ratio = Vector2(0.5, 0.5)
	if not UnityUI.baking:
		UiMotion.attach(_glow, UiMotion.PULSE)
	_arrow_holder = Control.new()
	_arrow_holder.name = "Arrow"
	_arrow_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_arrow_holder)
	_arrow = TextureRect.new()
	_arrow.name = "ArrowIcon"
	_arrow.texture = ThemeKit.icon("ic_arrow")
	_arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arrow_holder.add_child(_arrow)


## Quầng sáng và mũi tên ở mốc `n` (ẩn khi đã đi hết đường).
func _place_markers(n: int) -> void:
	var done := n > items.size()
	_glow.visible = not done
	_arrow_holder.visible = not done
	if done:
		return
	var it: Dictionary = _by_n[n]
	var c := _center(it)
	var px := _size_of(it) * k
	var g := px * GLOW_K
	_glow.size = Vector2(g, g)
	_glow.position = c - _glow.size * 0.5
	_arrow_holder.size = ARROW * k
	_arrow_holder.position = Vector2(c.x - ARROW.x * k * 0.5, c.y - px * 0.5 - (ARROW.y - ARROW_OVERLAP) * k)
	if _arrow_tw != null:
		_arrow_tw.kill()
	_arrow.position = Vector2.ZERO
	if UnityUI.baking or not is_inside_tree():
		return
	_arrow_tw = _arrow.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_arrow_tw.tween_property(_arrow, "position:y", -ARROW_BOB * k, 0.45)
	_arrow_tw.tween_property(_arrow, "position:y", 0.0, 0.45)


## Mũi tên và quầng sáng trượt từ mốc `from` tới mốc hiện tại (sau khi thắng). Trả tween (null khi không chạy).
func slide_markers(from: int) -> Tween:
	if from == cur or from < 1 or cur > items.size() or from > items.size() or not is_inside_tree():
		return null
	var glow_to := _glow.position
	var arrow_to := _arrow_holder.position
	var d := center_of(from) - center_of(cur)
	_glow.position += d
	_arrow_holder.position += d
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_glow, "position", glow_to, 0.6)
	tw.tween_property(_arrow_holder, "position", arrow_to, 0.6)
	return tw


# --- chạm ---

func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_press = mb.position
		elif _press != Vector2.INF:
			var moved := mb.position.distance_to(_press)
			_press = Vector2.INF
			if moved <= TAP_SLOP:
				_tap_at(mb.position)
		return
	var mm := event as InputEventMouseMotion
	if mm != null and _press != Vector2.INF and mm.position.distance_to(_press) > TAP_SLOP:
		_press = Vector2.INF


## Mốc hay hộp dưới điểm p (toạ độ node); phát tapped. Trả n, 0 khi trượt.
func _tap_at(p: Vector2) -> int:
	for it in items:
		var px := _size_of(it) * k
		var c := _center(it)
		if Rect2(c - Vector2(px, px) * 0.5, Vector2(px, px)).has_point(p):
			tapped.emit(int(it.n), bool(it.box))
			return int(it.n)
	return 0
