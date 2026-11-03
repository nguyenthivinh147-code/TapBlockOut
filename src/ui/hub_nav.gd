extends Control
## Thanh dưới dùng chung Home, Shop, Leaderboard (Figma "main menu" > Frame 1893566628, component BottomBar): Shop · Home · Ranking.
## Khung Figma 886x248: tab đang mở 338 rộng, nền vàng cao 182, icon 168 nhô lên trên và chữ dưới icon;
## hai tab còn lại 274x146, nền tím, chỉ có icon 96 (tab khoá thêm chữ mở ở level nào).
## Bấm phát tab("shop" | "home" | "ranking"). Ranking mở từ Config.UNLOCK.leaderboard (Game.lb_open).

signal tab(tab_name: String)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const UiAtlas := preload("res://src/ui/ui_atlas.gd")
const Unlocks := preload("res://src/meta/unlocks.gd")
const Config := preload("res://src/config.gd")
const FigmaBox := preload("res://src/ui/figma_box.gd")

const DESIGN_W := 886.0
const DESIGN_H := 248.0
const TABS := [["shop", "ui_shop", "home_shop"], ["home", "ui_home", "home_home"], ["ranking", "ui_leaderboard", "home_ranking"]]
const ACTIVE_W := 338.0
const IDLE_W := 274.0
const CAPTION_STROKE := Color("8A201F")

var shop_btn: Button = null
var shop_caption: Label = null
var home_btn: Button = null
var ranking_btn: Button = null
var ranking_caption: Label = null

var _active: String = "home"
var _fb := FigmaBox.new()
var _icons: Dictionary = {}


func _init(active: String = "home") -> void:
	name = "NavBar"
	_active = active
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var x := 0.0
	for t in TABS:
		var w := ACTIVE_W if t[0] == _active else IDLE_W
		var res := _tab(str(t[0]), str(t[1]), tr(str(t[2])), x)
		x += w
		match str(t[0]):
			"shop":
				shop_btn = res[0]
				shop_btn.name = "ShopButton"
				shop_caption = res[1]
			"home":
				home_btn = res[0]
				home_btn.name = "HomeTab"
			"ranking":
				ranking_btn = res[0]
				ranking_btn.name = "RankingTab"
				ranking_caption = res[1]


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and size.x > 0.0:
		var s := size.x / DESIGN_W
		if not is_equal_approx(custom_minimum_size.y, DESIGN_H * s):
			custom_minimum_size.y = DESIGN_H * s
		_fb.apply(s)


## Một tab: nút trong suốt phủ cả ô, nền sao 9-slice, icon, chữ. Trả [nút, nhãn].
func _tab(tab_name: String, icon_name: String, caption: String, x: float) -> Array:
	var on := tab_name == _active
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = ThemeKit.MIN_BUTTON
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.pressed.connect(_on_tab.bind(tab_name))
	b.button_down.connect(func() -> void: b.self_modulate = Color(0.85, 0.85, 0.85))
	b.button_up.connect(func() -> void: b.self_modulate = Color.WHITE)
	add_child(b)
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UiAtlas.box("panel_yellow_star" if on else "panel_purple_star", Vector4(30, 30, 30, 24)))
	b.add_child(panel)
	var ic := TextureRect.new()
	ic.texture = ThemeKit.icon(icon_name)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	_icons[tab_name] = ic
	var l := ThemeKit.make_label(caption)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(l)
	if on:
		l.uppercase = true
		l.add_theme_color_override("font_outline_color", CAPTION_STROKE)
		_fb.put(b, Rect2(x, 0, ACTIVE_W, DESIGN_H))
		_fb.put(panel, Rect2(6, 67, 326, 182))
		_fb.put(ic, Rect2(85, -1, 168, 168))
		_fb.put(l, Rect2(19, 167, 300, 68))
		_fb.font(l, 60, 3, 290)
	else:
		_fb.put(b, Rect2(x, 102, IDLE_W, 146))
		_fb.put(panel, Rect2(6, 6, 262, 140))
		_fb.put(ic, Rect2(89, 32, 96, 96))
		_fb.put(l, Rect2(10, 98, 254, 40))
		_fb.font(l, 26, 3, 250)
		l.visible = false
	return [b, l]


func refresh() -> void:
	var open := Unlocks.is_open("shop", int(Game.s.level))
	_set_open(shop_btn, "shop", "ui_shop", open)
	shop_caption.text = tr("home_shop") if open else tr("home_shop_locked") % int(Config.UNLOCK.shop)
	var ranking_open: bool = Game.lb_open()
	_set_open(ranking_btn, "ranking", "ui_leaderboard", ranking_open)
	ranking_caption.text = tr("home_ranking") if ranking_open else tr("common_locked_level") % int(Config.UNLOCK.get("leaderboard", 0))
	if size.x > 0.0:
		_fb.apply(size.x / DESIGN_W)


## Tab khoá: icon khoá, nền tối, hiện chữ mở ở level nào (tab đang mở luôn hiện chữ).
func _set_open(b: Button, tab_name: String, icon_name: String, open: bool) -> void:
	b.disabled = not open
	b.modulate = Color.WHITE if open else Color(0.7, 0.7, 0.78)
	var ic := _icons[tab_name] as TextureRect
	ic.texture = ThemeKit.icon(icon_name if open else "ui_lock")
	var cap := (shop_caption if tab_name == "shop" else ranking_caption)
	cap.visible = tab_name == _active or not open
	if tab_name != _active:
		# tab khoá đẩy icon lên để chừa chỗ cho chữ
		_fb.move(ic, Vector2(89, 32 if open else 10))


func _on_tab(tab_name: String) -> void:
	tab.emit(tab_name)
