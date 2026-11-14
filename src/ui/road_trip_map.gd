extends Control
## Bản đồ Road Trip (wireframe Road Trip mục 1, 2): đường kẹo uốn qua mọi mốc, level 1 ở đáy, tăng dần lên trên.
## Bố cục theo RoadTrip.layout: hàng chạy 6 ô đổi chiều qua lại, hàng nối một mốc ở rìa; hộp quà rộng hai ô.
## Cả đường vẽ bằng _draw của một node (không tạo node theo mốc). Mốc: lục giác xám (khoá), xanh dương có dấu tích
## (đã qua), mốc hiện tại to hơn theo độ khó (xanh lá, đỏ Hard, tím Super Hard) với quầng sáng thở và mũi tên nhún
## (node con Glow, Arrow). Hộp: chưa tới nguyên màu, đã mở mờ đi kèm dấu tích. Hộp đang nhắm (2026-11-10) là node con
## TargetBox (vẽ hộp và số một lần, bản đồ không vẽ nó), sau nó là tia kẹo hồng tím TargetRays (candy_rays.gdshader,
## vẽ sau bản đồ) xoay chậm, quầng giữa thở; appear() cho hộp bật vào và tia nở ra. Không vẽ lại bản đồ mỗi khung.
## Chạm (không kéo) một mốc hay hộp thì phát tapped(n, is_box). Toạ độ là px thiết kế khung rộng DESIGN_W, nhân k.
## Nằm trong ScrollContainer: mouse_filter PASS để kéo vẫn cuộn. ScrollContainer chỉ tự kéo khi có cảm ứng; không có
## (desktop, chạy từ editor) thì bản đồ tự cuộn cha theo chuột kéo (_gui_input).

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
## Viền số theo mốc, cùng màu số trên mốc ở Home (home.gd TIERS, LOCKED_STROKE); mốc đã qua chỉ có ở Road Trip.
const OUTLINE := {"locked": Color("A57BBE"), "done": Color("366869"), "": Color("2D5E12"), "hard": Color("6C133F"),
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
## Tia kẹo sau hộp đang nhắm: đường kính so với hộp.
const RAYS_SHADER := "res://src/ui/candy_rays.gdshader"
const RAYS_K := 1.7
## appear(): hộp bật từ cỡ 0 (nảy) trong APPEAR_SEC, rồi lắc APPEAR_WOBBLE_DEG giảm dần (2 lượt) trong APPEAR_WOBBLE_SEC,
## quanh điểm APPEAR_PIVOT của hộp (gần đáy); tia nở từ cỡ 0 trong APPEAR_RAYS_SEC, trễ APPEAR_RAYS_AT s so với hộp.
const APPEAR_SEC := 0.45
const APPEAR_WOBBLE_DEG := 10.0
const APPEAR_WOBBLE_SEC := 0.5
const APPEAR_PIVOT := Vector2(0.5, 0.8)
const APPEAR_RAYS_SEC := 0.6
const APPEAR_RAYS_AT := 0.1

## Level đang chơi (levels + 1: đã đi hết), độ khó của nó, hệ số px thiết kế -> px màn.
var cur: int = 1
var tier: String = ""
var k: float = 1.0
## RoadTrip.layout(levels): [{n, row, col, box}].
var items: Array[Dictionary] = []

var _rows: int = 1
var _by_n: Dictionary = {}
var _press: Vector2 = Vector2.INF
## Kéo bằng chuột (không cảm ứng): đang kéo, y viewport và scroll_vertical lúc bắt đầu kéo.
var _mouse_drag: bool = false
var _drag_y: float = 0.0
var _drag_scroll: int = 0
var _glow: TextureRect = null
var _arrow_holder: Control = null
var _arrow: TextureRect = null
var _arrow_tw: Tween = null
## Hộp đang nhắm (n, 0 khi không còn hộp), node vẽ nó, tia sau nó, tween của appear().
var _target_n: int = 0
var _target_box: Control = null
var _target_rays: ColorRect = null
var _appear_tw: Tween = null


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
	_place_target()
	queue_redraw()


## Hộp đang nhắm: n của nó (0 khi đã mở hết hộp).
func target_box() -> int:
	for it in items:
		if bool(it.box) and RoadTrip.node_state(int(it.n), cur, true) == "target":
			return int(it.n)
	return 0


## Node hộp đang nhắm và tia sau nó ở chỗ của hộp; ẩn khi không còn hộp.
func _place_target() -> void:
	_target_n = target_box()
	_target_box.visible = _target_n > 0
	_target_rays.visible = _target_n > 0
	if _target_n == 0:
		return
	var c := center_of(_target_n)
	var px := BOX * k
	_target_box.size = Vector2(px, px)
	_target_box.position = c - _target_box.size * 0.5
	_target_box.pivot_offset_ratio = APPEAR_PIVOT
	var rs := px * RAYS_K
	_target_rays.size = Vector2(rs, rs)
	_target_rays.position = c - _target_rays.size * 0.5
	_target_rays.pivot_offset_ratio = Vector2(0.5, 0.5)
	_target_box.queue_redraw()


## Hộp đang nhắm bật vào sau `delay` s: từ cỡ 0 nảy lên, lắc nhẹ hai lượt; tia sau nó nở ra theo. Trước lúc bật thì hộp
## và tia ẩn (cỡ 0).
func appear(delay: float = 0.0) -> void:
	if _target_n == 0 or not is_inside_tree() or UnityUI.baking:
		return
	if _appear_tw != null:
		_appear_tw.kill()
	_target_box.scale = Vector2.ZERO
	_target_box.rotation = 0.0
	_target_rays.scale = Vector2.ZERO
	_appear_tw = create_tween().set_parallel(true)
	_appear_tw.tween_property(_target_box, "scale", Vector2.ONE, APPEAR_SEC).set_delay(delay) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_appear_tw.tween_method(_wobble_target, 0.0, 1.0, APPEAR_WOBBLE_SEC).set_delay(delay + APPEAR_SEC * 0.6)
	_appear_tw.tween_property(_target_rays, "scale", Vector2.ONE, APPEAR_RAYS_SEC).set_delay(delay + APPEAR_RAYS_AT) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _wobble_target(u: float) -> void:
	_target_box.rotation = deg_to_rad(APPEAR_WOBBLE_DEG * sin(TAU * 2.0 * u) * (1.0 - u))


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


## Hộp chưa tới hoặc đã mở; hộp đang nhắm là node TargetBox (_draw_target_box).
func _draw_box(it: Dictionary) -> void:
	var n := int(it.n)
	var st := RoadTrip.node_state(n, cur, true)
	if st == "target":
		return
	var px := BOX * k
	var c := _center(it)
	var r := Rect2(c - Vector2(px, px) * 0.5, Vector2(px, px))
	var tex := box_tex(RoadTrip.box_index(n))
	draw_texture_rect(tex, r, false, Color(1, 1, 1, 0.5) if st == "open" else Color.WHITE)
	if st == "open":
		var ck := CHECK * 1.3 * k
		draw_texture_rect(ThemeKit.icon("ui_check"), Rect2(c - Vector2(ck, ck) * 0.5, Vector2(ck, ck)), false)
	# Số level của hộp, nhỏ dưới đáy hộp.
	_draw_number(str(n), Vector2(c.x, r.end.y - 6.0 * k), roundi(NUM_FONT * 0.75 * k), OUTLINE.locked if st != "open" else OUTLINE.done)


## Hộp đang nhắm lên node TargetBox (toạ độ của node): ảnh hộp và số level dưới đáy, như _draw_box. Chỉ vẽ lại khi
## hộp hay cỡ đổi; bật vào, lắc là transform của node.
func _draw_target_box() -> void:
	if _target_n == 0:
		return
	var px := BOX * k
	_target_box.draw_texture_rect(box_tex(RoadTrip.box_index(_target_n)), Rect2(0, 0, px, px), false)
	_draw_number(str(_target_n), Vector2(px * 0.5, px - 6.0 * k), roundi(NUM_FONT * 0.75 * k), OUTLINE.locked, _target_box)


## Ảnh hộp quà thứ box_i (RoadTrip.box_index; âm thì như hộp đầu). Dùng chung cho bản đồ, chip, popup thắng.
static func box_tex(box_i: int) -> Texture2D:
	return UiAtlas.tex(str(BOX_ICONS[maxi(box_i, 0) % BOX_ICONS.size()]))


## Số giữa tại tâm c: chữ trắng viền màu outline, lên ci (mặc định bản đồ).
func _draw_number(text: String, c: Vector2, fs: int, outline: Color, ci: CanvasItem = null) -> void:
	var on: CanvasItem = ci if ci != null else self
	var font: Font = ThemeKit.FONT
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base := Vector2(c.x - w * 0.5, c.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5)
	var ol := maxi(roundi(fs * 0.16), 2)
	on.draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ol, outline)
	on.draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


# --- mốc hiện tại: quầng sáng và mũi tên ---

func _ensure_markers() -> void:
	if _glow != null:
		return
	# Target box: rays behind the map (under road and nodes), the box above it; both move by transform only.
	_target_rays = ColorRect.new()
	_target_rays.name = "TargetRays"
	_target_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_rays.show_behind_parent = true
	var mat := ShaderMaterial.new()
	mat.shader = load(RAYS_SHADER)
	_target_rays.material = mat
	add_child(_target_rays)
	_target_box = Control.new()
	_target_box.name = "TargetBox"
	_target_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_box.draw.connect(_draw_target_box)
	add_child(_target_box)
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
		_mouse_drag = false
		if mb.pressed:
			_press = mb.position
		elif _press != Vector2.INF:
			var moved := mb.position.distance_to(_press)
			_press = Vector2.INF
			if moved <= TAP_SLOP:
				_tap_at(mb.position)
		return
	var mm := event as InputEventMouseMotion
	if mm == null:
		return
	if _press != Vector2.INF and mm.position.distance_to(_press) > TAP_SLOP:
		_press = Vector2.INF
		# ScrollContainer only drags on a touchscreen; with a mouse (desktop, editor) the map follows the drag itself.
		var sc := get_parent() as ScrollContainer
		if sc != null and not DisplayServer.is_touchscreen_available():
			_mouse_drag = true
			_drag_y = mm.global_position.y
			_drag_scroll = sc.scroll_vertical
	if _mouse_drag and mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
		(get_parent() as ScrollContainer).scroll_vertical = _drag_scroll - roundi(mm.global_position.y - _drag_y)


## Mốc hay hộp dưới điểm p (toạ độ node); phát tapped. Trả n, 0 khi trượt.
func _tap_at(p: Vector2) -> int:
	for it in items:
		var px := _size_of(it) * k
		var c := _center(it)
		if Rect2(c - Vector2(px, px) * 0.5, Vector2(px, px)).has_point(p):
			tapped.emit(int(it.n), bool(it.box))
			return int(it.n)
	return 0
