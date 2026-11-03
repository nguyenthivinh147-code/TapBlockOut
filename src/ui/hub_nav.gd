extends PanelContainer
## Thanh dưới dùng chung Home, Shop, Leaderboard (component BottomBar): Shop · Home · Ranking.
## Bấm phát tab("shop" | "home" | "ranking"). Ranking chỉ mở ở bản xem trước UI (Config.ui_preview).

signal tab(tab_name: String)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const UiAtlas := preload("res://src/ui/ui_atlas.gd")
const Unlocks := preload("res://src/meta/unlocks.gd")
const Config := preload("res://src/config.gd")

const TAB_H := 124
const CAPTION_H := 36

var shop_btn: Button = null
var shop_caption: Label = null
var home_btn: Button = null
var ranking_btn: Button = null
var ranking_caption: Label = null

var _active: String = "home"


func _init(active: String = "home") -> void:
	name = "NavBar"
	_active = active
	var s := StyleBoxFlat.new()
	s.bg_color = ThemeKit.NAV_BOTTOM
	s.border_width_top = 6
	s.border_color = ThemeKit.NAV_TOP
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 10
	add_theme_stylebox_override("panel", s)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var sh := _tab("shop", "ui_shop", tr("home_shop"))
	shop_btn = sh[0]
	shop_btn.name = "ShopButton"
	shop_caption = sh[1]
	row.add_child(shop_btn)
	var hm := _tab("home", "ui_home", tr("home_home"))
	home_btn = hm[0]
	home_btn.name = "HomeTab"
	row.add_child(home_btn)
	var rk := _tab("ranking", "ui_leaderboard", tr("home_ranking"))
	ranking_btn = rk[0]
	ranking_btn.name = "RankingTab"
	ranking_caption = rk[1]
	row.add_child(ranking_btn)


## Nút tab: nền sao tím (vàng khi đang ở tab này), icon, chữ dưới. Trả [nút, nhãn].
func _tab(tab_name: String, icon_name: String, caption: String) -> Array:
	var art := "panel_yellow_star" if tab_name == _active else "panel_purple_star"
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(ThemeKit.MIN_BUTTON.x, TAB_H)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var box := UiAtlas.box(art, Vector4(30, 30, 30, 24), Vector4(8, 6, 8, CAPTION_H))
		match st:
			"pressed":
				box.modulate_color = Color(0.85, 0.85, 0.85)
			"disabled":
				box.modulate_color = Color(0.6, 0.6, 0.65)
		b.add_theme_stylebox_override(st, box)
	b.icon = ThemeKit.icon(icon_name)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.pressed.connect(_on_tab.bind(tab_name))
	var l := ThemeKit.make_label(caption, ThemeKit.FS_SMALL - 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	b.add_child(l)
	l.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	l.offset_top = -CAPTION_H - 2
	l.offset_bottom = -2
	return [b, l]


func refresh() -> void:
	var open := Unlocks.is_open("shop", int(Game.s.level))
	shop_btn.disabled = not open
	shop_btn.icon = ThemeKit.icon("ui_shop" if open else "ui_lock")
	shop_caption.text = tr("home_shop") if open else tr("home_shop_locked") % int(Config.UNLOCK.shop)
	var ranking_open := Config.ui_preview()
	ranking_btn.disabled = not ranking_open
	ranking_caption.text = tr("home_ranking") if ranking_open else tr("home_ranking_soon")


func _on_tab(tab_name: String) -> void:
	tab.emit(tab_name)
