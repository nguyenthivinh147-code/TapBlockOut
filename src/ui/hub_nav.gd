extends Control
## Thanh dưới dùng chung Home, Shop, Road Trip, Leaderboard (Figma "main menu" > Frame 1893566628, component BottomBar):
## Shop · Home · Road Trip.
## Khung Figma 886x248 chia ba ô bằng nhau (295, như video ref chuyển tab), mỗi ô một nền tím (PANEL_H). Ô của tab đang
## mở có ô sáng vàng (Highlight, HIGHLIGHT_H), icon 168 nhô lên trên và chữ dưới icon; hai tab còn lại chỉ có icon 96
## (tab khoá thêm chữ mở ở level nào). active "" (màn Leaderboard, mở từ icon ở Home): không tab nào sáng.
## Bấm phát tab("shop" | "home" | "road_trip"). Road Trip mở từ Config.UNLOCK.road_trip.
## Node nằm trong scenes/hub_nav.tscn (lưu với tab Home đang mở); script đặt cỡ, chữ từng tab theo tab đang mở
## (active), khoá tab, nối nút. Tạo bằng HubNav.create(active).
## Switching tabs: on the new screen's bar the highlight slides over from the previous tab and the icons trade sizes
## (_morph), while main.gd slides the screens; a pressed tab dips (_press).

signal tab(tab_name: String)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const UiAtlas := preload("res://src/ui/ui_atlas.gd")
const Unlocks := preload("res://src/meta/unlocks.gd")
const Config := preload("res://src/config.gd")
const FigmaBox := preload("res://src/ui/figma_box.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")
const RewardFly := preload("res://src/ui/reward_fly.gd")

const SCENE_PATH := "res://scenes/hub_nav.tscn"
const DESIGN_W := 886.0
const DESIGN_H := 248.0
## [tab, icon, chữ, nút trong scene, nền tím trong scene], trái sang phải
const TABS := [["shop", "ui_shop", "home_shop", "ShopButton", "ShopPanel"], ["home", "ui_home", "home_home", "HomeTab", "HomePanel"],
	["road_trip", "ui_road_trip", "home_road_trip", "RoadTripTab", "RoadTripPanel"]]
const SLOT_W := DESIGN_W / 3.0
const STAR_BORDER := Vector4(30, 30, 30, 24)
## Inset of the purple slots and the highlight from each slot's sides (gap between slots: twice this); 0 = flush.
const SLOT_INSET := 0.0
## Purple slot and highlight heights: the textures end in 11 and 7 transparent rows, so both run past the bar's bottom
## by that much and no background shows under them.
const PANEL_H := 151.0
const HIGHLIGHT_H := 189.0
const CAPTION_STROKE := Color("8A201F")
## Caption font px and fit width: open tab, other tabs.
const CAPTION_FONT_ON := Vector2(60, 265)
const CAPTION_FONT_OFF := Vector2(26, 271)
## Tab switch, timed on the reference video: the highlight slides SLIDE_SEC (quart ease-out; main.gd slides the
## screens the same way), the icons trade sizes from ICON_DELAY for ICON_SEC, the new one overshooting (TRANS_BACK)
## and its caption fading in.
const SLIDE_SEC := 0.33
const ICON_DELAY := 0.12
const ICON_SEC := 0.2
## Pressed tab: scale and time to reach it (release springs back in the same time).
const PRESS_SCALE := 0.92
const PRESS_SEC := 0.1

## Tab of the bar shown last, on any screen: the next bar slides from its layout.
static var last_tab := ""

## Tab đang mở: "shop" | "home" | "road_trip" | "" (không tab nào). Đọc một lần khi nối node.
@export var active: String = "home"

# Getters bind the scene's nodes on first use (callers read them before adding the bar to the tree).
var shop_btn: Button = null:
	get:
		_bind()
		return shop_btn
var shop_caption: Label = null:
	get:
		_bind()
		return shop_caption
var home_btn: Button = null:
	get:
		_bind()
		return home_btn
var road_trip_btn: Button = null:
	get:
		_bind()
		return road_trip_btn
var road_trip_caption: Label = null:
	get:
		_bind()
		return road_trip_caption

var _fb := FigmaBox.new()
var _icons: Dictionary = {}
## tab name -> purple slot panel (outside the button, so the highlight draws between it and the icon)
var _panels: Dictionary = {}
var _highlight: Panel = null
var _bound: bool = false
## tab name -> unlocked (refresh); a locked tab's icon sits higher.
var _open: Dictionary = {}
## Tab whose layout the bar slides from once shown ("" = none).
var _morph_from := ""
var _press_tw: Dictionary = {}


# Only the name (the scene's root has the same one) and the script's own state: built-in properties come from the scene.
func _init(active_tab: String = "home") -> void:
	name = "NavBar"
	active = active_tab
	add_to_group(RewardFly.GROUP)


## RewardFly: boosters received outside a level fly into the Home tab's icon (Unity's HomeTabPosition).
func reward_target(kind: String) -> Control:
	_bind()
	return _icons.get("home") if RewardFly.BOOSTERS.has(kind) else null


## The bar as an instance of its scene, with active_tab open.
static func create(active_tab: String = "home") -> Control:
	var nav: Control = (load(SCENE_PATH) as PackedScene).instantiate()
	nav.set("active", active_tab)
	return nav


## Finds the scene's nodes, lays the tabs out for the active one and wires them. Called on first use, not in _init():
## a scene adds the children after the script starts.
func _bind() -> void:
	if _bound:
		return
	_bound = true
	shop_btn = $ShopButton
	shop_caption = $ShopButton/Caption
	home_btn = $HomeTab
	road_trip_btn = $RoadTripTab
	road_trip_caption = $RoadTripTab/Caption
	_highlight = $Highlight
	_fb.adopt(self)
	_highlight.add_theme_stylebox_override("panel", UiAtlas.box("panel_yellow_star", STAR_BORDER))
	for i in TABS.size():
		var t: Array = TABS[i]
		var p: Panel = get_node(str(t[4]))
		p.add_theme_stylebox_override("panel", UiAtlas.box("panel_purple_star", STAR_BORDER))
		_fb.put(p, Rect2(i * SLOT_W + SLOT_INSET, 108, SLOT_W - SLOT_INSET * 2, PANEL_H))
		_panels[str(t[0])] = p
		var b: Button = get_node(str(t[3]))
		_icons[str(t[0])] = b.get_node("Icon")
		_set_tab(b, str(t[0]) == active, str(t[1]), tr(str(t[2])))
		b.pressed.connect(_on_tab.bind(str(t[0])))
		b.pivot_offset_ratio = Vector2(0.5, 0.5)
		b.button_down.connect(_press.bind(b, true))
		b.button_up.connect(_press.bind(b, false))
	_place(_layout(active), 1.0)
	_highlight.visible = _is_tab(active)
	if last_tab != active and _is_tab(active) and _is_tab(last_tab):
		_morph_from = last_tab
	last_tab = active
	if size.x > 0.0:
		_apply()


static func _is_tab(tab_name: String) -> bool:
	return TABS.any(func(t: Array) -> bool: return str(t[0]) == tab_name)


func _ready() -> void:
	_bind()
	if _morph_from != "" and not UnityUI.baking:
		_morph.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _bound and size.x > 0.0:
		_apply()


func _apply() -> void:
	var s := size.x / DESIGN_W
	if not is_equal_approx(custom_minimum_size.y, DESIGN_H * s):
		custom_minimum_size.y = DESIGN_H * s
	_fb.apply(s)


## Một tab theo tab đang mở: icon, chữ (tab đang mở: chữ hoa luôn hiện). Cỡ, chỗ: _layout.
func _set_tab(b: Button, on: bool, icon_name: String, caption: String) -> void:
	var ic := b.get_node("Icon") as TextureRect
	var l := b.get_node("Caption") as Label
	ic.texture = ThemeKit.icon(icon_name)
	l.text = caption
	l.uppercase = on
	l.add_theme_color_override("font_outline_color", CAPTION_STROKE if on else ThemeKit.TEXT_OUTLINE)
	l.visible = on


## Design rects with open_tab open: the highlight HIGHLIGHT_H high over that tab's slot, its button the full bar height with
## icon 168 above the caption; the other buttons 146 high with icon 96 (higher on a locked tab, to leave room for its
## caption). The purple slot panels never move.
func _layout(open_tab: String) -> Dictionary:
	var out := {}
	for i in TABS.size():
		var t: Array = TABS[i]
		var b: Button = get_node(str(t[3]))
		var x := i * SLOT_W
		if str(t[0]) == open_tab:
			out[_highlight] = Rect2(x + SLOT_INSET, 67, SLOT_W - SLOT_INSET * 2, HIGHLIGHT_H)
			out[b] = Rect2(x, 0, SLOT_W, DESIGN_H)
			out[b.get_node("Icon")] = Rect2((SLOT_W - 168) * 0.5, -1, 168, 168)
			out[b.get_node("Caption")] = Rect2(10, 167, SLOT_W - 20, 68)
		else:
			out[b] = Rect2(x, 102, SLOT_W, 146)
			out[b.get_node("Icon")] = Rect2(_idle_icon_pos(str(t[0])), Vector2(96, 96))
			out[b.get_node("Caption")] = Rect2(10, 98, SLOT_W - 20, 40)
	return out


## A locked tab's icon sits higher, to leave room for its caption.
func _idle_icon_pos(tab_name: String) -> Vector2:
	return Vector2((SLOT_W - 96) * 0.5, 32 if bool(_open.get(tab_name, true)) else 10)


## Puts rects (from _layout) and the captions' fonts, k of the way from the other tabs' font to the open tab's.
func _place(rects: Dictionary, k: float) -> void:
	for n: Control in rects:
		_fb.put(n, rects[n])
	for t in TABS:
		var f := CAPTION_FONT_OFF.lerp(CAPTION_FONT_ON, k if str(t[0]) == active else 0.0)
		_fb.font(get_node(str(t[3]) + "/Caption") as Label, f.x, 3, f.y)


## Plays the switch from _morph_from to the open tab: the highlight slides across (over the slots between), then the
## old tab's icon shrinks and drops while the new one grows and rises with a little overshoot, its caption fading in.
## Styles and caption texts are already the open tab's.
func _morph() -> void:
	if not is_inside_tree() or _morph_from == "":
		return
	var from := _layout(_morph_from)
	var to := _layout(active)
	_morph_from = ""
	var total := maxf(SLIDE_SEC, ICON_DELAY + ICON_SEC)
	_morph_step(0.0, from, to)
	create_tween().tween_method(_morph_step.bind(from, to), 0.0, total, total)


## sec: time since the switch.
func _morph_step(sec: float, from: Dictionary, to: Dictionary) -> void:
	var ks := _eased(sec, 0.0, SLIDE_SEC, Tween.TRANS_QUART)
	var ki := _eased(sec, ICON_DELAY, ICON_SEC, Tween.TRANS_CUBIC)
	var kb := _eased(sec, ICON_DELAY, ICON_SEC, Tween.TRANS_BACK)
	var grow: Control = _icons[active]
	var rects := {}
	for n: Control in to:
		var a: Rect2 = from[n]
		var b: Rect2 = to[n]
		var e := ks if n == _highlight else (kb if n == grow else ki)
		rects[n] = Rect2(a.position.lerp(b.position, e), a.size.lerp(b.size, e))
	_place(rects, ki)
	(grow.get_parent().get_node("Caption") as Label).modulate.a = ki
	if size.x > 0.0:
		_fb.apply(size.x / DESIGN_W)


## Ease-out progress 0..1 of a phase starting at start and lasting dur, sec into the switch.
static func _eased(sec: float, start: float, dur: float, trans: Tween.TransitionType) -> float:
	return float(Tween.interpolate_value(0.0, 1.0, clampf(sec - start, 0.0, dur), dur, trans, Tween.EASE_OUT))


## Pressed tab dips to PRESS_SCALE and darkens; on release it springs back.
func _press(b: Button, down: bool) -> void:
	b.self_modulate = Color(0.85, 0.85, 0.85) if down else Color.WHITE
	if _press_tw.has(b):
		(_press_tw[b] as Tween).kill()
	if not b.is_inside_tree():
		return
	var tw := b.create_tween().set_trans(Tween.TRANS_QUAD if down else Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "scale", Vector2.ONE * (PRESS_SCALE if down else 1.0), PRESS_SEC)
	_press_tw[b] = tw


func refresh() -> void:
	_bind()
	var open := Unlocks.is_open("shop", int(Game.s.level))
	_set_open(shop_btn, "shop", "ui_shop", open)
	shop_caption.text = tr("home_shop") if open else tr("home_shop_locked") % int(Config.UNLOCK.shop)
	var rt_open := Unlocks.is_open("road_trip", int(Game.s.level))
	_set_open(road_trip_btn, "road_trip", "ui_road_trip", rt_open)
	road_trip_caption.text = tr("home_road_trip") if rt_open else tr("common_locked_level") % int(Config.UNLOCK.get("road_trip", 0))
	if size.x > 0.0:
		_fb.apply(size.x / DESIGN_W)


## Tab khoá: icon khoá, nền tối, hiện chữ mở ở level nào (tab đang mở luôn hiện chữ).
func _set_open(b: Button, tab_name: String, icon_name: String, open: bool) -> void:
	_open[tab_name] = open
	b.disabled = not open
	b.modulate = Color.WHITE if open else Color(0.7, 0.7, 0.78)
	(_panels[tab_name] as Control).modulate = b.modulate
	var ic := _icons[tab_name] as TextureRect
	ic.texture = ThemeKit.icon(icon_name if open else "ui_lock")
	var cap := (shop_caption if tab_name == "shop" else road_trip_caption)
	cap.visible = tab_name == active or not open
	if tab_name != active:
		_fb.move(ic, _idle_icon_pos(tab_name))


func _on_tab(tab_name: String) -> void:
	tab.emit(tab_name)
