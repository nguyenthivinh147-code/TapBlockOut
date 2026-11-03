extends Control
## Màn Home theo Figma "main menu" (section Meta, 3 khung: thường, Hard, Super Hard; khung 886x1920, bỏ dải ADS 120 ở đáy).
## Mọi node đặt theo toạ độ Figma, co theo rộng màn (s = rộng / 886). Phần trên neo đỉnh, nút Chơi và thanh dưới neo đáy;
## đường level co lại khi màn thấp hơn khung Figma.
## Chỉ đọc Game; không tự mở popup. Điều hướng qua closed({"action": ...}):
## play, no_lives, lives, profile, gift, shop, ranking, settings, challenge, offer (kèm "id"),
## preview (kèm "scene": màn đã dựng UI, chưa nối logic; chỉ hiện khi Config.ui_preview).

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const Unlocks := preload("res://src/meta/unlocks.gd")
const Config := preload("res://src/config.gd")
const UiAtlas := preload("res://src/ui/ui_atlas.gd")
const HubTop := preload("res://src/ui/hub_top.gd")
const HubNav := preload("res://src/ui/hub_nav.gd")
const FigmaBox := preload("res://src/ui/figma_box.gd")
const HomeSparkles := preload("res://src/ui/home_sparkles.gd")

const DESIGN_W := 886.0
## Khung Figma 1920 trừ dải ADS 120.
const DESIGN_H := 1800.0
const PATH_X := 443.0
## Cột icon hai bên: x, đỉnh mục đầu, bước dọc, cỡ mục.
const LEFT_X := 12.0
const RIGHT_X := 682.0
const COL_TOP := 221.0
const COL_STEP := 213.0
const ITEM := Vector2(194, 176)
## Nút Chơi (pill 387x165 trong btn_play 412x188 ở 243,1262).
const PLAY_RECT := Rect2(256, 1274, 387, 165)
const NAV_TOP := 1552.0
## Tab bên của thanh dưới (cao 146, đỉnh 1654): đáy của cột icon không chạm xuống đây.
const NAV_SIDE_TOP := 1654.0

const BG_NORMAL := Color("FFEEF4")
## Hoạ tiết kẹo chìm xuống: lòng hình đậm hơn nền, viền sáng lộ ra ở mép dưới (lớp sáng lệch xuống, nằm dưới).
const CANDY_SHADOW := Color("F2C2D2")
const CANDY_LIGHT := Color("FFFFFF")
const CANDY_OFFSET := 2.0
const BG_HARD_TOP := Color("3454AC")
const BG_HARD_BOTTOM := Color("DEE1F2")
const RIBBON_STROKE := Color("9E4D0F")
## Theo độ khó: kiểu nút, viền chữ nút, sprite mốc hiện tại, viền số, icon đầu lâu.
const TIERS := {
	"": {"button": "primary", "stroke": Color("5A9016"), "node": "node_green", "num": Color("4F7F10"), "skull": ""},
	"hard": {"button": "danger", "stroke": Color("B1343C"), "node": "hex_red", "num": Color("911B35"), "skull": "ui_hard"},
	"very_hard": {"button": "purple", "stroke": Color("4C0B78"), "node": "hex_purple", "num": Color("4B1073"), "skull": "ui_superhard"},
}
const LOCKED_STROKE := Color("787878")
const SOLVED_STROKE := Color("076F87")

var gold_label: Label = null
var lives_panel: Control = null
var lives_label: Label = null
var lives_timer_label: Label = null
var profile_btn: Button = null
var play_btn: Button = null
var play_label: Label = null
## Chữ độ khó trên nút Chơi ("HARD", "VERY HARD").
var hard_tag: Label = null
var gift_btn: Button = null
var gift_badge: Control = null
var shop_btn: Button = null
var shop_caption: Label = null
var sale_btn: Button = null
var settings_btn: Button = null
var challenge_btn: Button = null
var challenge_caption: Label = null
var offer_chip: Button = null
var offer_caption: Label = null
var coming_soon_label: Label = null
var weekly_btn: Button = null
var weekly_caption: Label = null
var weekly_dot: Control = null
var chain_btn: Button = null
var chain_dot: Control = null
var special_btn: Button = null
## Ba mốc trên đường level, từ trên xuống. Mỗi mốc: {"root", "sprite", "num", "badge", "skull"}.
var path_nodes: Array[Dictionary] = []

var _args: Dictionary = {}
var _built: bool = false
var _tick: Timer = null
var _offer_id: String = ""
var _top: HubTop = null
var _nav: HubNav = null
var _fb := FigmaBox.new()
var _tier: String = ""
## Bố cục đường level: "first" (level 1: hai mốc khoá ở trên, mốc hiện tại ở dưới) hoặc "mid".
var _path_mode: String = "mid"
var _bg: ColorRect = null
var _bg_grad: TextureRect = null
var _pattern: Control = null
var _sparkles: Control = null
var _top_shade: TextureRect = null
var _rail: TextureRect = null
var _glow: TextureRect = null
var _challenge_lock: TextureRect = null
var _offer_icon: TextureRect = null
var _gift_col: Control = null
var _challenge_col: Control = null
var _sale_col: Control = null
var _offer_col: Control = null
var _weekly_col: Control = null
var _chain_col: Control = null
var _special_col: Control = null
var _left_items: Array[Control] = []
var _right_items: Array[Control] = []
var _special_id: String = ""


## 75 -> "1:15", 3725 -> "1:02:05", từ 1 ngày: "1d 3h".
static func fmt_time(sec: int) -> String:
	return HubTop.fmt_time(sec)


func _ready() -> void:
	_build()
	_connect_game()
	refresh()


func _exit_tree() -> void:
	for sig in [Game.coins_changed, Game.lives_changed, Game.cos_changed, Game.inv_changed, Game.offer_ready]:
		if (sig as Signal).is_connected(_on_game_changed):
			(sig as Signal).disconnect(_on_game_changed)


func setup(args: Dictionary) -> void:
	_args = args
	_build()
	_connect_game()
	refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _built:
		_layout()


func _connect_game() -> void:
	for sig in [Game.coins_changed, Game.lives_changed, Game.cos_changed, Game.inv_changed, Game.offer_ready]:
		if not (sig as Signal).is_connected(_on_game_changed):
			(sig as Signal).connect(_on_game_changed)


func _on_game_changed(_v: Variant = null) -> void:
	refresh()


## Chấm đỏ thông báo ở góc trên phải của nút.
func _make_dot(btn: Button, node_name: String) -> Control:
	var dot := Panel.new()
	dot.name = node_name
	dot.custom_minimum_size = Vector2(32, 32)
	dot.size = Vector2(32, 32)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bs := StyleBoxFlat.new()
	bs.bg_color = ThemeKit.DANGER
	bs.set_corner_radius_all(16)
	bs.set_border_width_all(3)
	bs.border_color = ThemeKit.TEXT
	dot.add_theme_stylebox_override("panel", bs)
	btn.add_child(dot)
	dot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	dot.offset_left = -38
	dot.offset_right = -6
	dot.offset_top = 4
	dot.offset_bottom = 36
	dot.visible = false
	return dot


func _tex_rect(tex: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _flat_button(node_name: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.custom_minimum_size = ThemeKit.MIN_BUTTON
	b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.button_down.connect(func() -> void:
		b.pivot_offset = b.size * 0.5
		b.scale = Vector2(0.95, 0.95))
	b.button_up.connect(func() -> void: b.scale = Vector2.ONE)
	return b


## Mục cột bên (Figma Frame 194x176): icon 152, ribbon vàng 194x56, chữ trắng viền nâu. Trả [cột, nút, nhãn].
func _side_item(icon_name: String, caption: String, node_name: String, right: bool) -> Array:
	var col := Control.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fb.put(col, Rect2(Vector2(RIGHT_X if right else LEFT_X, COL_TOP), ITEM))
	add_child(col)
	var b := _flat_button(node_name)
	_fb.put(b, Rect2(21, 0, 152, 152))
	col.add_child(b)
	var ic := _tex_rect(ThemeKit.icon(icon_name))
	ic.name = "Icon"
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(ic)
	var rib := _tex_rect(UiAtlas.file_tex("home_banner.png"))
	rib.stretch_mode = TextureRect.STRETCH_SCALE
	_fb.put(rib, Rect2(0, 120, 194, 56))
	col.add_child(rib)
	var l := ThemeKit.make_label(caption)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", RIBBON_STROKE)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fb.put(l, Rect2(0, 118, 194, 50))
	_fb.font(l, 36, 3, 166)
	col.add_child(l)
	(_right_items if right else _left_items).append(col)
	return [col, b, l]


## Mốc trên đường level: sprite, số ở giữa, huy hiệu (khoá/tích) góc dưới phải, đầu lâu trên đỉnh.
func _path_node(node_name: String) -> Dictionary:
	var root := Control.new()
	root.name = node_name
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var sprite := _tex_rect(null)
	sprite.stretch_mode = TextureRect.STRETCH_SCALE
	root.add_child(sprite)
	var num := ThemeKit.make_label("")
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(num)
	var badge := _tex_rect(null)
	root.add_child(badge)
	var skull := _tex_rect(null)
	root.add_child(skull)
	return {"root": root, "sprite": sprite, "num": num, "badge": badge, "skull": skull}


func _build() -> void:
	if _built:
		return
	_built = true
	theme = ThemeKit.make_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# nền: thường hồng #FFEEF4; Hard/Super Hard dải #3454AC -> #DEE1F2; hoạ tiết kẹo chìm và sao lấp lánh ở mọi độ khó
	_bg = ColorRect.new()
	_bg.name = "Background"
	_bg.color = BG_NORMAL
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_bg_grad = _gradient_rect([[0.0, BG_HARD_TOP], [0.844, BG_HARD_BOTTOM]])
	_bg_grad.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.add_child(_bg_grad)
	_pattern = Control.new()
	_pattern.name = "CandyPattern"
	_pattern.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pattern.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.add_child(_pattern)
	for layer in [[CANDY_LIGHT, CANDY_OFFSET], [CANDY_SHADOW, 0.0]]:
		var tile := _tex_rect(UiAtlas.file_tex("home_candy_pattern.png"))
		tile.stretch_mode = TextureRect.STRETCH_TILE
		tile.set_anchors_preset(Control.PRESET_FULL_RECT)
		tile.offset_top = layer[1]
		tile.offset_bottom = layer[1]
		tile.self_modulate = layer[0]
		_pattern.add_child(tile)
	_sparkles = HomeSparkles.new()
	_sparkles.name = "Sparkles"
	_sparkles.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.add_child(_sparkles)

	# đường ray dọc, mờ dần ở hai đầu
	_rail = _tex_rect(UiAtlas.file_tex("home_rail.png"))
	_rail.name = "Rail"
	_rail.stretch_mode = TextureRect.STRETCH_SCALE
	_rail.material = _fade_material()
	_fb.put(_rail, Rect2(414, -22, 63, 1769))
	add_child(_rail)
	_glow = _tex_rect(UiAtlas.file_tex("home_glow.png"))
	_glow.name = "Glow"
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_glow)
	for n in ["NextNode", "CurrentNode", "PrevNode"]:
		var pn := _path_node(n)
		_fb.put(pn.root, Rect2(0, 0, 220, 220))
		path_nodes.append(pn)
	# Hard: phủ #3454AC mờ dần trên 566 px đầu
	_top_shade = _gradient_rect([[0.0, BG_HARD_TOP], [0.494, Color(BG_HARD_TOP, 0.77)], [1.0, Color(BG_HARD_TOP, 0.0)]])
	_top_shade.name = "TopShade"
	_fb.put(_top_shade, Rect2(0, 0, DESIGN_W, 566))
	add_child(_top_shade)

	# cột trái: quà ngày, Daily Challenge
	var gf := _side_item("ui_gift", tr("home_gift"), "GiftButton", false)
	_gift_col = gf[0]
	gift_btn = gf[1]
	gift_btn.pressed.connect(_emit.bind("gift"))
	gift_badge = _make_dot(gift_btn, "GiftBadge")
	var ch := _side_item("ui_clock", tr("home_challenge"), "ChallengeButton", false)
	_challenge_col = ch[0]
	challenge_btn = ch[1]
	challenge_caption = ch[2]
	challenge_btn.pressed.connect(_on_challenge)
	_challenge_lock = _tex_rect(ThemeKit.icon("ui_lock"))
	_challenge_lock.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_challenge_lock.offset_left = -56
	_challenge_lock.offset_top = -64
	_challenge_lock.offset_right = 0
	_challenge_lock.offset_bottom = 0
	challenge_btn.add_child(_challenge_lock)

	# cột phải: ưu đãi có hạn, Special Pack, Weekend Sale, Weekly Pass, Chain Offer (ẩn khi chưa đủ điều kiện)
	var of := _side_item("ui_gift", "", "OfferChip", true)
	_offer_col = of[0]
	offer_chip = of[1]
	offer_caption = of[2]
	_offer_icon = offer_chip.get_node("Icon")
	offer_chip.pressed.connect(_on_offer)
	var sp := _side_item("shop_special_pack", tr("home_special_pack"), "SpecialPackButton", true)
	_special_col = sp[0]
	special_btn = sp[1]
	special_btn.pressed.connect(_on_special)
	var sl := _side_item("ui_shop", tr("home_weekend_sale"), "WeekendSaleButton", true)
	_sale_col = sl[0]
	sale_btn = sl[1]
	sale_btn.pressed.connect(_emit.bind("shop"))
	var wk := _side_item("ui_gold", tr("home_weekly"), "WeeklyPassButton", true)
	_weekly_col = wk[0]
	weekly_btn = wk[1]
	weekly_caption = wk[2]
	weekly_btn.pressed.connect(_emit.bind("weekly"))
	weekly_dot = _make_dot(weekly_btn, "WeeklyDot")
	var cn := _side_item("ui_gift", tr("home_chain"), "ChainOfferButton", true)
	_chain_col = cn[0]
	chain_btn = cn[1]
	chain_btn.pressed.connect(_emit.bind("chain"))
	chain_dot = _make_dot(chain_btn, "ChainDot")
	if Config.ui_preview():
		_preview_item("ui_noads", tr("shop_remove_ads"), "popup_remove_ads")
		_preview_item("ui_star", tr("streak_title"), "streak_main")

	# nút Chơi: chữ PLAY, trên đó là độ khó (Hard/Super Hard)
	play_btn = Button.new()
	play_btn.name = "PlayButton"
	play_btn.custom_minimum_size = ThemeKit.MIN_BUTTON
	play_btn.focus_mode = Control.FOCUS_NONE
	play_btn.pressed.connect(_on_play)
	_fb.put(play_btn, PLAY_RECT, true)
	add_child(play_btn)
	hard_tag = ThemeKit.make_label("")
	hard_tag.name = "HardTag"
	hard_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hard_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hard_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fb.put(hard_tag, Rect2(0, 20, PLAY_RECT.size.x, 46))
	_fb.font(hard_tag, 36, 3, 330)
	play_btn.add_child(hard_tag)
	play_label = ThemeKit.make_label("")
	play_label.name = "PlayLabel"
	play_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	play_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	play_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fb.put(play_label, Rect2(0, 26, PLAY_RECT.size.x, 116))
	_fb.font(play_label, 102, 4, 340)
	play_btn.add_child(play_label)
	coming_soon_label = ThemeKit.make_label(tr("home_coming_soon"))
	coming_soon_label.name = "ComingSoonLabel"
	coming_soon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coming_soon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fb.put(coming_soon_label, Rect2(0, 1196, DESIGN_W, 60), true)
	_fb.font(coming_soon_label, 40, 3, 700)
	add_child(coming_soon_label)

	# hàng trên: avatar, mạng, vàng, settings
	_top = HubTop.new()
	_top.action.connect(_emit)
	_fb.put(_top, Rect2(0, 35, DESIGN_W, 124))
	add_child(_top)
	profile_btn = _top.profile_btn
	lives_panel = _top.lives_panel
	lives_label = _top.lives_label
	lives_timer_label = _top.lives_timer_label
	gold_label = _top.gold_label
	settings_btn = _top.settings_btn

	# thanh dưới: Shop · Home · Ranking
	_nav = HubNav.new("home")
	_nav.tab.connect(_on_tab)
	_fb.put(_nav, Rect2(0, NAV_TOP, DESIGN_W, DESIGN_H - NAV_TOP), true)
	add_child(_nav)
	shop_btn = _nav.shop_btn
	shop_caption = _nav.shop_caption

	_tick = Timer.new()
	_tick.wait_time = 1.0
	_tick.one_shot = false
	_tick.timeout.connect(_refresh_timers)
	add_child(_tick)
	_tick.start()


## Dải màu dọc. stops: [[vị trí 0..1, màu], ...].
func _gradient_rect(stops: Array) -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(stops.map(func(st: Array) -> float: return float(st[0])))
	g.colors = PackedColorArray(stops.map(func(st: Array) -> Color: return st[1] as Color))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 4
	gt.height = 256
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	var r := _tex_rect(gt)
	r.stretch_mode = TextureRect.STRETCH_SCALE
	return r


## Ray mờ dần ở đầu trên và đầu dưới (mask gradient trong Figma).
func _fade_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
void fragment() {
	COLOR.a *= smoothstep(0.0, 0.14, UV.y) * (1.0 - smoothstep(0.86, 0.93, UV.y));
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


## Nút mở một màn chưa nối logic (chỉ dựng khi Config.ui_preview).
func _preview_item(icon_name: String, caption: String, scene: String) -> void:
	var res := _side_item(icon_name, caption, "Preview_" + scene, true)
	(res[1] as Button).pressed.connect(func() -> void:
		Sfx.play("button")
		closed.emit({"action": "preview", "scene": scene}))


func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var s := size.x / DESIGN_W
	var shift := size.y / s - DESIGN_H
	_layout_path(shift)
	var side_limit := NAV_SIDE_TOP + shift - 8.0
	_stack(_left_items, LEFT_X, side_limit)
	_stack(_right_items, RIGHT_X, side_limit)
	_fb.apply(s, shift)


## Xếp các mục đang hiện từ COL_TOP xuống; không đủ chỗ thì rút bước dọc.
func _stack(items: Array[Control], x: float, limit: float) -> void:
	var shown: Array[Control] = []
	for c in items:
		if c.visible:
			shown.append(c)
	var step := COL_STEP
	if shown.size() > 1:
		step = minf(COL_STEP, (limit - COL_TOP - ITEM.y) / float(shown.size() - 1))
	for i in shown.size():
		_fb.move(shown[i], Vector2(x, COL_TOP + i * step))


## Ba mốc theo khung Figma; màn thấp hơn khung thì co cả cụm (cỡ và khoảng cách) quanh đỉnh cụm.
## first (level 1): khoá 220 ở 211, khoá 220 ở 525, hiện tại 290 ở 868.
## mid: khoá 220 ở 149, hiện tại 290 ở 513, vừa qua 220 ở 941.
func _layout_path(shift: float) -> void:
	var slots: Array = [[211.0, 220.0], [525.0, 220.0], [868.0, 290.0]] if _path_mode == "first" else [[149.0, 220.0], [513.0, 290.0], [941.0, 220.0]]
	var top: float = slots[0][0]
	var span: float = float(slots[2][0]) + float(slots[2][1]) - top
	# chừa khoảng 101 trên nút Chơi như Figma
	var avail := PLAY_RECT.position.y - 12.0 + shift - 101.0 - top
	var f := clampf(avail / span, 0.55, 1.0)
	var off := maxf(avail - span, 0.0) * 0.5
	var cur_idx := 2 if _path_mode == "first" else 1
	for i in 3:
		var y: float = top + off + (float(slots[i][0]) - top) * f
		var px: float = float(slots[i][1]) * f
		var pn: Dictionary = path_nodes[i]
		_fb.put(pn.root, Rect2(PATH_X - px * 0.5, y, px, px))
		_layout_node(pn, px, i == cur_idx)
	var cur: Rect2 = _fb.rect_of(path_nodes[cur_idx].root)
	var hard := _tier != ""
	# fx 1: thường 359 quanh mốc 290 (tâm lệch xuống 5); Hard 518 (tâm lệch lên 16)
	var gs := cur.size.x * (518.0 / 290.0 if hard else 359.0 / 290.0)
	var gy := cur.get_center().y + cur.size.x * (-16.0 / 290.0 if hard else 5.0 / 290.0)
	_fb.put(_glow, Rect2(PATH_X - gs * 0.5, gy - gs * 0.5, gs, gs))


## Vị trí con trong mốc theo cỡ px (thiết kế). Kim cương: sprite phủ cả mốc. Lục giác: sprite thụt 5/220.
func _layout_node(pn: Dictionary, px: float, current: bool) -> void:
	var k := px / (290.0 if current else 220.0)
	var hex := str(pn.get("shape", "")) == "hex"
	var inset := (6.0 if current else 5.0) * k if hex else 0.0
	_fb.put(pn.sprite, Rect2(inset, inset, px - inset * 2.0, px - inset * 2.0))
	_fb.put(pn.num, Rect2(0, 4 * k, px, px))
	var fs := (107.6 if hex else 95.7) if current else (81.6 if hex else 72.6)
	_fb.font(pn.num, fs * k, 3.5 * k)
	if hex:
		_fb.put(pn.badge, Rect2(116 * k, 132 * k, 104 * k, 104 * k))
	else:
		_fb.put(pn.badge, Rect2(129 * k, 122 * k, 90 * k, 90 * k))
	_fb.put(pn.skull, Rect2(79 * k, -34 * k, 131 * k, 131 * k))


## Gán hình cho một mốc. kind: "current", "locked", "solved".
func _set_node(pn: Dictionary, level: int, kind: String, hex: bool) -> void:
	pn["shape"] = "hex" if hex else "diamond"
	var t: Dictionary = TIERS[_tier]
	var num := pn.num as Label
	num.text = str(level)
	(pn.skull as TextureRect).texture = null
	(pn.badge as TextureRect).texture = null
	match kind:
		"current":
			(pn.sprite as TextureRect).texture = UiAtlas.tex(str(t.node))
			num.add_theme_color_override("font_outline_color", t.num)
			if str(t.skull) != "":
				(pn.skull as TextureRect).texture = ThemeKit.icon(str(t.skull))
		"locked":
			(pn.sprite as TextureRect).texture = UiAtlas.tex("hex_gray" if hex else "node_gray")
			num.add_theme_color_override("font_outline_color", LOCKED_STROKE)
			(pn.badge as TextureRect).texture = ThemeKit.icon("ui_lock")
		"solved":
			(pn.sprite as TextureRect).texture = UiAtlas.tex("hex_blue")
			num.add_theme_color_override("font_outline_color", SOLVED_STROKE)
			(pn.badge as TextureRect).texture = ThemeKit.icon("ui_check")


## Đường level, nền và nút Chơi theo độ khó của level hiện tại.
func _refresh_path(level: int, ended: bool) -> void:
	_tier = "" if ended else Game.difficulty_of(level)
	if not TIERS.has(_tier):
		_tier = ""
	var hard := _tier != ""
	_bg_grad.visible = hard
	_top_shade.visible = hard
	_pattern.modulate = Color(1, 1, 1, 0.12) if hard else Color(1, 1, 1, 0.35)
	_rail.modulate = Color(1, 1, 1, 0.75) if hard else Color(1, 0.8, 0.9, 0.55)
	_path_mode = "first" if level <= 1 else "mid"
	if _path_mode == "first":
		_set_node(path_nodes[0], level + 2, "locked", hard)
		_set_node(path_nodes[1], level + 1, "locked", hard)
		_set_node(path_nodes[2], level, "current", hard)
	else:
		_set_node(path_nodes[0], level + 1, "locked", hard)
		_set_node(path_nodes[1], level, "current", hard)
		_set_node(path_nodes[2], level - 1, "solved", true)


## Pill btn_play (387x165) gần đúng tỉ lệ sprite atlas (380x168) nên vẽ cả sprite co theo nút, không 9-slice.
func _style_play(kind: String) -> void:
	var art: String = ThemeKit.BUTTON_ART[kind]
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := UiAtlas.box(art, Vector4.ZERO)
		match st:
			"hover":
				box.modulate_color = Color(1.08, 1.08, 1.08)
			"pressed":
				box.modulate_color = Color(0.82, 0.82, 0.82)
			"disabled":
				box.modulate_color = Color(0.55, 0.55, 0.6, 0.9)
			"focus":
				box = null
		if box == null:
			play_btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		else:
			play_btn.add_theme_stylebox_override(st, box)


func refresh() -> void:
	if not _built:
		return
	var level := int(Game.s.level)
	_top.refresh()
	_nav.refresh()

	# nút Chơi
	var ended := not Game.level_exists(level)
	_refresh_path(level, ended)
	coming_soon_label.visible = ended
	var t: Dictionary = TIERS[_tier]
	_style_play(str(t.button))
	play_label.text = tr("home_play").to_upper()
	play_label.add_theme_color_override("font_outline_color", t.stroke)
	hard_tag.add_theme_color_override("font_outline_color", t.stroke)
	play_btn.disabled = ended
	play_btn.modulate = Color(1, 1, 1, 0.7) if ended else Color.WHITE
	hard_tag.visible = _tier != ""
	hard_tag.text = tr("level_very_hard") if _tier == "very_hard" else (tr("level_hard") if _tier == "hard" else "")
	_fb.move(play_label, Vector2(0, 44 if hard_tag.visible else 26))

	# quà
	var daily: Dictionary = Game.daily_view()
	_gift_col.visible = bool(daily.get("open", false))
	gift_badge.visible = bool(daily.get("badge", false))

	# weekend sale: chỉ hiện khi sale bật và Shop đã mở
	_sale_col.visible = Unlocks.is_open("shop", level) and Game.is_sale_active()

	# challenge: khoá thì icon tối, có khoá và ghi level mở
	var ch: Dictionary = Game.challenge_view()
	var ch_open := bool(ch.get("open", false))
	challenge_btn.disabled = not ch_open
	challenge_btn.modulate = Color.WHITE if ch_open else Color(0.75, 0.75, 0.82)
	_challenge_lock.visible = not ch_open
	challenge_caption.text = tr("home_challenge") if ch_open else tr("home_play_level") % int(ch.get("unlock_level", Config.UNLOCK.challenge))

	_refresh_timers()


## Weekly Pass, Chain Offer, Special Pack: hiện/ẩn theo điều kiện. Gọi cả mỗi giây vì hết hạn theo giờ.
func _refresh_events() -> void:
	if not _built:
		return
	var wv: Dictionary = Game.weekly_view()
	_weekly_col.visible = bool(wv.unlocked)
	if bool(wv.unlocked):
		var badge := int(wv.badge)
		weekly_caption.text = tr("home_weekly") if badge <= 0 else "%s (%d)" % [tr("home_weekly"), badge]
		weekly_dot.visible = bool(wv.dot) or badge > 0
	var cv: Dictionary = Game.chain_view()
	_chain_col.visible = not cv.is_empty()
	chain_dot.visible = not cv.is_empty() and int(cv.step) < int(cv.count)
	_special_id = Game.special_pack_id()
	_special_col.visible = _special_id != ""


## Đếm hồi mạng và hạn offer; gọi mỗi giây.
func _refresh_timers() -> void:
	if not _built:
		return
	_refresh_events()
	var offers: Array = Game.offers_open()
	if offers.is_empty():
		_offer_col.visible = false
		_offer_id = ""
	else:
		var o: Dictionary = offers[0]
		_offer_id = str(o.id)
		_offer_col.visible = true
		_offer_icon.texture = ThemeKit.icon("shop_" + _offer_id)
		offer_chip.tooltip_text = tr("offer_%s_title" % _offer_id)
		offer_caption.text = fmt_time(int(o.until) - Game.now())
	_layout()


func _emit(action: String) -> void:
	Sfx.play("button")
	closed.emit({"action": action})


## Daily Challenge: chỉ phát closed; Main chuyển sang màn challenge.
func _on_challenge() -> void:
	if not bool(Game.challenge_view().get("open", false)):
		return
	_emit("challenge")


## Tab dưới: Home đang ở đây nên không làm gì.
func _on_tab(tab_name: String) -> void:
	match tab_name:
		"shop":
			_emit("shop")
		"ranking":
			_emit("ranking")


func _on_play() -> void:
	Sfx.play("button")
	if bool(Game.lives_view().get("can_play", true)):
		closed.emit({"action": "play"})
	else:
		closed.emit({"action": "no_lives"})


func _on_special() -> void:
	Sfx.play("button")
	if _special_id != "":
		closed.emit({"action": "offer", "id": _special_id})


func _on_offer() -> void:
	Sfx.play("button")
	if _offer_id != "":
		closed.emit({"action": "offer", "id": _offer_id})
