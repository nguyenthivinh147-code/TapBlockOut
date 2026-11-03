extends Control
## Thanh dưới dùng chung Home, Shop, Leaderboard (Figma "main menu" > Frame 1893566628, component BottomBar): Shop · Home · Ranking.
## Khung Figma 886x248: tab đang mở 338 rộng, nền vàng cao 182, icon 168 nhô lên trên và chữ dưới icon;
## hai tab còn lại 274x146, nền tím, chỉ có icon 96 (tab khoá thêm chữ mở ở level nào).
## Bấm phát tab("shop" | "home" | "ranking"). Ranking mở từ Config.UNLOCK.leaderboard (Game.lb_open).
## Node nằm trong scenes/hub_nav.tscn (lưu với tab Home đang mở); script đặt cỡ, nền, chữ từng tab theo tab đang mở
## (active), khoá tab, nối nút. Tạo bằng HubNav.create(active).

signal tab(tab_name: String)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const UiAtlas := preload("res://src/ui/ui_atlas.gd")
const Unlocks := preload("res://src/meta/unlocks.gd")
const Config := preload("res://src/config.gd")
const FigmaBox := preload("res://src/ui/figma_box.gd")

const SCENE_PATH := "res://scenes/hub_nav.tscn"
const DESIGN_W := 886.0
const DESIGN_H := 248.0
## [tab, icon, chữ, node trong scene]
const TABS := [["shop", "ui_shop", "home_shop", "ShopButton"], ["home", "ui_home", "home_home", "HomeTab"],
	["ranking", "ui_leaderboard", "home_ranking", "RankingTab"]]
const ACTIVE_W := 338.0
const IDLE_W := 274.0
const CAPTION_STROKE := Color("8A201F")

## Tab đang mở: "shop" | "home" | "ranking". Đọc một lần khi nối node.
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
var ranking_btn: Button = null:
	get:
		_bind()
		return ranking_btn
var ranking_caption: Label = null:
	get:
		_bind()
		return ranking_caption

var _fb := FigmaBox.new()
var _icons: Dictionary = {}
var _bound: bool = false


# Only the name (the scene's root has the same one) and the script's own state: built-in properties come from the scene.
func _init(active_tab: String = "home") -> void:
	name = "NavBar"
	active = active_tab


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
	ranking_btn = $RankingTab
	ranking_caption = $RankingTab/Caption
	_fb.adopt(self)
	var x := 0.0
	for t in TABS:
		var b: Button = get_node(str(t[3]))
		_icons[str(t[0])] = b.get_node("Icon")
		_set_tab(b, str(t[0]) == active, str(t[1]), tr(str(t[2])), x)
		x += ACTIVE_W if str(t[0]) == active else IDLE_W
		b.pressed.connect(_on_tab.bind(str(t[0])))
		b.button_down.connect(func() -> void: b.self_modulate = Color(0.85, 0.85, 0.85))
		b.button_up.connect(func() -> void: b.self_modulate = Color.WHITE)
	if size.x > 0.0:
		_apply()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _bound and size.x > 0.0:
		_apply()


func _apply() -> void:
	var s := size.x / DESIGN_W
	if not is_equal_approx(custom_minimum_size.y, DESIGN_H * s):
		custom_minimum_size.y = DESIGN_H * s
	_fb.apply(s)


## Một tab theo tab đang mở: ô, nền sao 9-slice, icon, chữ (tab đang mở: nền vàng, icon lớn, chữ hoa luôn hiện).
func _set_tab(b: Button, on: bool, icon_name: String, caption: String, x: float) -> void:
	var panel := b.get_node("Panel") as Panel
	var ic := b.get_node("Icon") as TextureRect
	var l := b.get_node("Caption") as Label
	panel.add_theme_stylebox_override("panel", UiAtlas.box("panel_yellow_star" if on else "panel_purple_star", Vector4(30, 30, 30, 24)))
	ic.texture = ThemeKit.icon(icon_name)
	l.text = caption
	l.uppercase = on
	l.add_theme_color_override("font_outline_color", CAPTION_STROKE if on else ThemeKit.TEXT_OUTLINE)
	l.visible = on
	if on:
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


func refresh() -> void:
	_bind()
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
	cap.visible = tab_name == active or not open
	if tab_name != active:
		# tab khoá đẩy icon lên để chừa chỗ cho chữ
		_fb.move(ic, Vector2(89, 32 if open else 10))


func _on_tab(tab_name: String) -> void:
	tab.emit(tab_name)
