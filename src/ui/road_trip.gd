extends Control
## Màn Road Trip (wireframe Road Trip mục 1, design.md mục 7 "Road Trip"): tab phải của thanh dưới, mở từ UNLOCK.road_trip.
## Thanh trên, bản đồ cuộn dọc ngay dưới thanh (RoadTripMap, level 1 ở đáy; không ribbon tiêu đề), chip tiến độ hộp quà dính mép phải
## (icon hộp kế tiếp, thanh "đã qua/khoảng"), nút "Level N" trên thanh dưới. Chạm hộp: bong bóng thưởng của hộp.
## Chạm mốc hiện tại hoặc nút Level: chơi trong màn level (chế độ road_trip) nhúng làm con của màn này như Daily
## Challenge, sau màn chuyển cảnh; xong thì về bản đồ, mũi tên trượt tới mốc mới.
## setup(args): không cần khoá nào; dữ liệu từ Game.road_trip_view().
## closed({"action": "home" | "shop" | action của HubTop}); Main điều hướng.
## Node tĩnh nằm trong scenes/road_trip.tscn (toạ độ Figma trong meta fb_rect, fb_bottom, fb_font; khung 886 x 1800 như
## Home); script tìm node, điền chữ, dữ liệu, nối nút. Bản đồ, bong bóng thưởng và màn level sinh lúc chạy.

signal closed(result: Variant)

const Config := preload("res://src/config.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")
const UiAtlas := preload("res://src/ui/ui_atlas.gd")
const FigmaBox := preload("res://src/ui/figma_box.gd")
const HubTop := preload("res://src/ui/hub_top.gd")
const HubNav := preload("res://src/ui/hub_nav.gd")
const RoadTrip := preload("res://src/meta/road_trip.gd")
const RoadTripMap := preload("res://src/ui/road_trip_map.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")
const LevelScene := preload("res://scenes/level.tscn")
## Màn chuyển cảnh nắp hộp quà khi vào level và về bản đồ (main.gd curtain_swap).
const GiftCurtain := preload("res://src/ui/gift_curtain.gd")

const DESIGN_W := 886.0
const DESIGN_H := 1800.0
## Bản đồ nằm giữa đáy thanh trên (HubTop fb_rect y 35 + 124) và đỉnh nút Level, cách mỗi bên MAP_GAP (px thiết kế;
## đỉnh nút theo đáy khung).
const MAP_TOP := 173.0
const MAP_GAP := 14.0
## Mốc hiện tại nằm ở chừng này chiều cao vùng bản đồ tính từ trên khi cuộn tới.
const FOCUS := 0.62
## Nút Level theo độ khó của level đang chơi: kiểu nút, viền chữ.
const TIERS := {
	"": {"button": "primary", "stroke": Color("5A9016")},
	"hard": {"button": "danger", "stroke": Color("B1343C")},
	"very_hard": {"button": "purple", "stroke": Color("4C0B78")},
}
const CHIP_FILL := Color("7BD43A")
const CHIP_TRACK := Color("4A2C7A")
## Bong bóng thưởng của hộp: tự ẩn sau BUBBLE_SEC.
const BUBBLE_SEC := 2.5
const BOOSTER_ICON := {"hint": "booster_hint", "smash": "booster_smash", "move": "booster_move"}

var map: Control = null
var map_scroll: ScrollContainer = null
var play_button: Button = null
var play_label: Label = null
var done_label: Label = null
var chip: Control = null
var chip_icon: TextureRect = null
var chip_label: Label = null
var level_node: Control = null
## Bong bóng thưởng đang hiện (null khi không có).
var bubble: Control = null

var _built: bool = false
var _left: bool = false
var _fb := FigmaBox.new()
var _top: HubTop = null
var _nav: HubNav = null
var _content: Control = null
var _chip_fill: Control = null
var _view: Dictionary = {}
var _bubble_token: int = 0
## Level đang chơi lúc mở level (để mũi tên trượt khi quay về).
var _from_level: int = 0


func setup(_args: Dictionary = {}) -> void:
	_build()
	refresh()
	_scroll_to_current.call_deferred()


func _ready() -> void:
	_build()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _built:
		_layout()


func _build() -> void:
	if _built:
		return
	_built = true
	_fb.adopt(self)
	_content = %Content
	map_scroll = %MapScroll
	map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	map_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	map_scroll.scroll_deadzone = 12
	map = RoadTripMap.new()
	map.name = "Map"
	map.set_meta("u_rt", true)
	map_scroll.add_child(map)
	map.connect("tapped", _on_map_tapped)
	map_scroll.get_v_scroll_bar().value_changed.connect(func(_v: float) -> void: _hide_bubble())
	chip = %Chip
	chip_icon = %ChipIcon
	chip_label = %ChipLabel
	_chip_fill = %ChipFill
	(%ChipTrack as Panel).add_theme_stylebox_override("panel", _round_box(CHIP_TRACK, 20))
	_chip_fill.add_theme_stylebox_override("panel", _round_box(CHIP_FILL, 20))
	(chip as Panel).add_theme_stylebox_override("panel", UiAtlas.box("panel_purple_star", Vector4(30, 30, 30, 24)))
	play_button = %PlayButton
	play_button.pressed.connect(_on_play)
	play_label = %PlayLabel
	done_label = %DoneLabel
	done_label.text = tr("rt_done")
	_top = %HubTop as HubTop
	_top.action.connect(_act)
	_nav = %NavBar as HubNav
	_nav.tab.connect(_on_tab)
	for sig in [Game.coins_changed, Game.lives_changed, Game.inv_changed]:
		(sig as Signal).connect(_on_game_changed)


func _exit_tree() -> void:
	for sig in [Game.coins_changed, Game.lives_changed, Game.inv_changed]:
		if (sig as Signal).is_connected(_on_game_changed):
			(sig as Signal).disconnect(_on_game_changed)
	if level_node != null:
		Game.set_in_level(false)


func _on_game_changed(_v: Variant = null) -> void:
	if level_node == null:
		_top.refresh()


static func _round_box(c: Color, r: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = c
	b.set_corner_radius_all(r)
	return b


func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var s := size.x / DESIGN_W
	var shift := size.y / s - DESIGN_H
	_fb.apply(s, shift)
	var play_top: float = (_fb.rect_of(play_button) as Rect2).position.y + shift
	map_scroll.position = Vector2(0, MAP_TOP * s)
	map_scroll.size = Vector2(size.x, maxf((play_top - MAP_GAP - MAP_TOP) * s, 100.0))
	var v := _view if not _view.is_empty() else Game.road_trip_view()
	map.call("setup", int(v.level), str(v.tier), s)
	_layout_chip()


func refresh() -> void:
	if not _built:
		return
	_view = Game.road_trip_view()
	_top.refresh()
	_nav.refresh()
	var lv := int(_view.level)
	var done := bool(_view.done)
	var t: Dictionary = TIERS.get(str(_view.tier), TIERS[""])
	_style_play(str(t.button))
	play_label.text = tr("level_title") % lv
	play_label.add_theme_color_override("font_outline_color", t.stroke)
	play_label.add_theme_color_override("font_shadow_color", t.stroke)
	play_button.visible = not done
	done_label.visible = done
	var p: Vector2i = _view.progress
	chip.visible = not done and p.y > 0
	if chip.visible:
		chip_label.text = "%d/%d" % [p.x, p.y]
		chip_icon.texture = RoadTripMap.box_tex(RoadTrip.box_index(int(_view.next_box)))
	_layout()


## Thanh trong chip theo tỉ lệ đã qua / khoảng.
func _layout_chip() -> void:
	var p: Vector2i = _view.get("progress", Vector2i.ZERO)
	var track := %ChipTrack as Control
	var f := clampf(float(p.x) / float(p.y), 0.0, 1.0) if p.y > 0 else 0.0
	_chip_fill.position = Vector2.ZERO
	_chip_fill.size = Vector2(maxf(track.size.x * f, track.size.y if f > 0.0 else 0.0), track.size.y)
	_chip_fill.visible = f > 0.0


## Pill btn_play như Home: cả sprite co theo nút.
func _style_play(kind: String) -> void:
	var art: String = ThemeKit.BUTTON_ART[kind]
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		if st == "focus":
			play_button.add_theme_stylebox_override(st, StyleBoxEmpty.new())
			continue
		var box := UiAtlas.box(art, Vector4.ZERO)
		match st:
			"hover":
				box.modulate_color = Color(1.08, 1.08, 1.08)
			"pressed":
				box.modulate_color = Color(0.82, 0.82, 0.82)
			"disabled":
				box.modulate_color = Color(0.55, 0.55, 0.6, 0.9)
		play_button.add_theme_stylebox_override(st, box)


## Cuộn để mốc hiện tại nằm ở FOCUS chiều cao vùng bản đồ.
func _scroll_to_current() -> void:
	if not is_inside_tree() or map == null:
		return
	var c: Vector2 = map.call("center_of", int(Game.road_trip_view().level))
	map_scroll.scroll_vertical = maxi(int(c.y - map_scroll.size.y * FOCUS), 0)


# --- chạm ---

func _on_map_tapped(n: int, is_box: bool) -> void:
	if level_node != null:
		return
	if is_box:
		_show_box_bubble(n)
		return
	if n == int(Game.road_trip_view().level):
		_on_play()


## Bong bóng trên hộp ở level n: icon và số của từng vật phẩm, tự ẩn sau BUBBLE_SEC (wireframe S3).
func _show_box_bubble(n: int) -> void:
	Sfx.play("button")
	if bubble != null and is_instance_valid(bubble):
		bubble.queue_free()
	var reward := RoadTrip.reward(RoadTrip.box_index(n))
	var k: float = map.get("k")
	var panel := PanelContainer.new()
	panel.name = "BoxBubble"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UiAtlas.box("bubble_cream", Vector4(40, 40, 40, 40), Vector4(24, 16, 24, 28) * k))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", roundi(16 * k))
	panel.add_child(row)
	for kind in reward:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		var ic := TextureRect.new()
		ic.texture = ThemeKit.icon(str(BOOSTER_ICON.get(kind, "ui_gift")))
		ic.custom_minimum_size = Vector2(84, 84) * k
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cell.add_child(ic)
		var l := Label.new()
		l.text = "x%d" % int(reward[kind])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", roundi(34 * k))
		l.add_theme_color_override("font_color", ThemeKit.INK)
		cell.add_child(l)
		row.add_child(cell)
	# On the screen, not in the scroll: above the box, or below it when the top of the map would clip it.
	_content.add_child(panel)
	bubble = panel
	var to_content := _content.get_global_transform().affine_inverse() * map.get_global_transform()
	var c: Vector2 = to_content * (map.call("center_of", n) as Vector2)
	var half := RoadTripMap.BOX * k * 0.5
	var sz := panel.get_combined_minimum_size()
	panel.size = sz
	var x := clampf(c.x - sz.x * 0.5, 8.0, _content.size.x - sz.x - 8.0)
	var y := c.y - half - sz.y
	if y < map_scroll.position.y:
		y = c.y + half
	panel.position = Vector2(x, y)
	_bubble_token += 1
	var token := _bubble_token
	get_tree().create_timer(BUBBLE_SEC).timeout.connect(func() -> void:
		if token == _bubble_token and is_instance_valid(panel):
			panel.queue_free()
			if bubble == panel:
				bubble = null)


func _hide_bubble() -> void:
	if bubble != null and is_instance_valid(bubble):
		bubble.queue_free()
	bubble = null


func _on_play() -> void:
	if level_node != null or _left:
		return
	var v := Game.road_trip_view()
	if not bool(v.open) or bool(v.done):
		return
	Sfx.play("button")
	_from_level = int(v.level)
	var h := _host()
	if h != null and h.has_method("curtain_swap"):
		h.call("curtain_swap", _open_level, GiftCurtain)
	else:
		_open_level()


func _host() -> Node:
	var n := get_parent()
	while n != null:
		if n.has_method("go") and n.has_method("open_popup"):
			return n
		n = n.get_parent()
	return null


func _open_level() -> void:
	if _left or level_node != null:
		return
	_hide_bubble()
	_content.visible = false
	Game.set_in_level(true)
	level_node = LevelScene.instantiate() as Control
	add_child(level_node)
	level_node.connect("closed", _on_level_closed)
	level_node.call("setup", {"road_trip": true})


## Màn level xong (thắng, thua rồi về, hoặc bấm Home trong level): về bản đồ sau màn chuyển cảnh.
func _on_level_closed(_result: Variant) -> void:
	var h := _host()
	if h != null and h.has_method("curtain_swap"):
		h.call("curtain_swap", _close_level, GiftCurtain)
	else:
		_close_level()


func _close_level() -> void:
	if level_node != null and is_instance_valid(level_node):
		level_node.queue_free()
	level_node = null
	Game.set_in_level(false)
	Sfx.music(Sfx.MUSIC_HOME)
	_content.visible = true
	refresh()
	_scroll_to_current()
	map.call("slide_markers", _from_level)


# --- điều hướng ---

## Back của Android: đang chơi thì như bấm Home trong level, không thì về Home.
func on_back() -> void:
	if level_node != null and is_instance_valid(level_node) and level_node.has_method("on_back"):
		level_node.call("on_back")
	elif level_node == null:
		_act("home")


func _on_tab(tab_name: String) -> void:
	if tab_name != "road_trip":
		_act(tab_name)


## HubTop / HubNav: nút của game, tự phát tiếng bấm.
func _act(action: String) -> void:
	if _left or level_node != null:
		return
	Sfx.play("button")
	if action == "home" or action == "shop":
		_left = true
	closed.emit({"action": action})
