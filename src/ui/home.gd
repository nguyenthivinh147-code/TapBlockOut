extends Control
## Màn Home theo Figma "main menu" (section Meta, 3 khung: thường, Hard, Super Hard; khung 886x1920, bỏ dải ADS 120 ở đáy).
## Mọi node đặt theo toạ độ Figma, co theo rộng màn (s = rộng / 886). Phần trên neo đỉnh, nút Chơi và thanh dưới neo đáy;
## đường level co lại khi màn thấp hơn khung Figma.
## Chỉ đọc Game; không tự mở popup. Điều hướng qua closed({"action": ...}):
## play, no_lives, lives, profile, gift, shop, ranking (icon Bảng xếp hạng ở cột trái), road_trip (tab dưới), settings,
## challenge, offer (kèm "id"), preview (kèm "scene": màn đã dựng UI, chưa nối logic; chỉ hiện khi Config.ui_preview).
## Road Trip vừa mở (Game.road_trip_view().guide): lớp hướng dẫn RoadTripGuide phủ tối Home trừ thanh dưới, bàn tay
## chỉ vào tab Road Trip; chạm đâu cũng tắt và không hiện lại.
## Mọi node tĩnh nằm trong scenes/home.tscn (toạ độ Figma trong meta fb_rect, fb_font của FigmaBox; thanh trên, thanh dưới
## là instance scenes/hub_top.tscn, scenes/hub_nav.tscn); script chỉ tìm node, điền chữ, dữ liệu và nối nút.

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const Unlocks := preload("res://src/meta/unlocks.gd")
const Config := preload("res://src/config.gd")
const UiAtlas := preload("res://src/ui/ui_atlas.gd")
const HubTop := preload("res://src/ui/hub_top.gd")
const HubNav := preload("res://src/ui/hub_nav.gd")
const FigmaBox := preload("res://src/ui/figma_box.gd")
const UiMotion := preload("res://src/ui/ui_motion.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")

const DESIGN_W := 886.0
## Khung Figma 1920 trừ dải ADS 120.
const DESIGN_H := 1800.0
## Trục co của cụm mốc khi màn thấp.
const PATH_X := 443.0
## Ray kẹo thẳng đứng (home_rail_straight.png 64x2008, duỗi từ "Progress line" 71:367 bằng tools/gen_home_rail.py) khi
## cụm mốc không co: tâm ở PATH_X, từ trên mốc trên cùng chạy xuống nút Chơi. Khung vẫn dài 2008 cho sọc không méo;
## shader của Rail cắt ray ở đỉnh nút (lấn RAIL_UNDER_PLAY vào sau viền nút), dưới nút không còn ray.
const RAIL_RECT := Rect2(PATH_X - 32.0, 98, 64, 2008)
const RAIL_UNDER_PLAY := 16.0
## Khoảng giữa mốc dưới cùng và nút Chơi (ref; Figma để 101).
const PATH_GAP := 70.0
## fx 1 quanh mốc hiện tại: 518 quanh mốc 290 (khung Hard) ở mọi độ khó, như ref.
const GLOW_K := 518.0 / 290.0
## Cột icon hai bên: x, đỉnh mục đầu, bước dọc, cỡ mục.
const LEFT_X := 12.0
const RIGHT_X := 682.0
const COL_TOP := 221.0
const COL_STEP := 213.0
const ITEM := Vector2(194, 176)
## Nút Chơi (pill 387x165), tâm ở PATH_X cho thẳng ray và mốc (Figma để btn_play 412x188 ở 243,1262: lệch phải 6.5).
const PLAY_RECT := Rect2(PATH_X - 193.5, 1274, 387, 165)
## Chữ PLAY theo nút (px thiết kế). Mặt nút trên gờ 3D là y 8..145 của sprite 168, tâm ~75 trên nút 165.
## Level thường: chữ giữa mặt nút; khung cao hơn cỡ tối thiểu của Label ở cỡ 102 (~140) nên Label không dãn xuống.
const PLAY_LABEL_RECT := Rect2(0, 0, 387, 150)
## Hard, Super Hard: HardTag ở trên, PLAY hạ xuống.
const PLAY_LABEL_HARD_RECT := Rect2(0, 44, 387, 116)
## Dải sáng quét dọc nút Chơi (UiMotion.SHINE): lượt đầu sau khi Home mở (s), qua hiệu ứng chuyển màn.
const PLAY_SHINE_DELAY := 0.8
const NAV_TOP := 1552.0
## Tab bên của thanh dưới (cao 146, đỉnh 1654): đáy của cột icon không chạm xuống đây.
const NAV_SIDE_TOP := 1654.0

# Nền (mọi độ khó như khung Hard: dải #3454AC -> #DEE1F2, phủ TopShade), hoạ tiết kẹo chìm (lớp sáng lệch 2 px xuống,
# lớp #F2C2D2 trên, độ mờ 7%), ray kẹo mờ hai đầu, viền chữ ribbon #9E4D0F: lưu trong scenes/home.tscn.
## Theo độ khó: kiểu nút, viền chữ nút, sprite mốc hiện tại, viền số, icon đầu lâu.
const TIERS := {
	"": {"button": "primary", "stroke": Color("5A9016"), "node": "node_green", "num": Color("4F7F10"), "skull": ""},
	"hard": {"button": "danger", "stroke": Color("B1343C"), "node": "hex_red", "num": Color("911B35"), "skull": "ui_hard"},
	"very_hard": {"button": "purple", "stroke": Color("4C0B78"), "node": "hex_purple", "num": Color("4B1073"), "skull": "ui_superhard"},
}
const LOCKED_STROKE := Color("787878")
## Mục mở màn chưa nối logic (chỉ khi Config.ui_preview): [chữ, scene]. Node PreviewItem_<scene> trong scene.
const PREVIEWS := [["shop_remove_ads", "popup_remove_ads"], ["streak_title", "streak_main"]]
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
var leaderboard_btn: Button = null
var leaderboard_caption: Label = null
## Lớp hướng dẫn Road Trip vừa mở (null khi không hiện).
var road_trip_guide: Control = null
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
var _sparkles: Control = null
var _rail: TextureRect = null
var _glow: TextureRect = null
var _challenge_lock: TextureRect = null
var _leaderboard_lock: TextureRect = null
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


## Mục cột bên (Figma Frame 194x176, node trong scene): chữ ribbon, bấm, nhún khi nhấn. Trả nút.
func _side_item(b: Button, caption: String, right: bool, on_press: Callable) -> Button:
	var col := b.get_parent() as Control
	(col.get_node("Caption") as Label).text = caption
	b.pressed.connect(on_press)
	b.button_down.connect(func() -> void:
		b.pivot_offset = b.size * 0.5
		b.scale = Vector2(0.95, 0.95))
	b.button_up.connect(func() -> void: b.scale = Vector2.ONE)
	(_right_items if right else _left_items).append(col)
	return b


## Mốc trên đường level (node trong scene): sprite, số ở giữa, huy hiệu (khoá/tích) góc dưới phải, đầu lâu trên đỉnh.
func _path_node(root: Control) -> Dictionary:
	return {"root": root, "sprite": root.get_node("Sprite"), "num": root.get_node("Number"),
		"badge": root.get_node("Badge"), "skull": root.get_node("Skull")}


## Every static node is in scenes/home.tscn (Figma rects in FigmaBox metas); this finds them, sets the texts and
## wires the buttons. The preview items are dropped when Config.ui_preview is off.
func _build() -> void:
	if _built:
		return
	_built = true
	for p in PREVIEWS:
		var item := get_node("%PreviewItem_" + str(p[1])) as Control
		if not Config.ui_preview():
			remove_child(item)
			item.free()
	_fb.adopt(self)

	_bg = %Background
	_sparkles = _bg.get_node("Sparkles")
	_rail = %Rail
	_glow = %Glow
	if not UnityUI.baking:
		# The glow behind the current node breathes around its center.
		_glow.pivot_offset_ratio = Vector2(0.5, 0.5)
		UiMotion.attach(_glow, UiMotion.PULSE)
	for n: Control in [%NextNode, %CurrentNode, %PrevNode]:
		path_nodes.append(_path_node(n))

	# cột trái: quà ngày, Daily Challenge
	gift_btn = _side_item(%GiftButton, tr("home_gift"), false, _emit.bind("gift"))
	_gift_col = %GiftItem
	gift_badge = %GiftBadge
	challenge_btn = _side_item(%ChallengeButton, tr("home_challenge"), false, _on_challenge)
	_challenge_col = %ChallengeItem
	challenge_caption = _challenge_col.get_node("Caption")
	_challenge_lock = %ChallengeLock
	leaderboard_btn = _side_item(%LeaderboardButton, tr("home_ranking"), false, _on_leaderboard)
	leaderboard_caption = (%LeaderboardItem as Control).get_node("Caption")
	_leaderboard_lock = %LeaderboardLock

	# cột phải: ưu đãi có hạn, Special Pack, Weekend Sale, Weekly Pass, Chain Offer (ẩn khi chưa đủ điều kiện)
	offer_chip = _side_item(%OfferChip, "", true, _on_offer)
	_offer_col = %OfferItem
	offer_caption = _offer_col.get_node("Caption")
	_offer_icon = offer_chip.get_node("Icon")
	special_btn = _side_item(%SpecialPackButton, tr("home_special_pack"), true, _on_special)
	_special_col = %SpecialPackItem
	sale_btn = _side_item(%WeekendSaleButton, tr("home_weekend_sale"), true, _emit.bind("shop"))
	_sale_col = %WeekendSaleItem
	weekly_btn = _side_item(%WeeklyPassButton, tr("home_weekly"), true, _emit.bind("weekly"))
	_weekly_col = %WeeklyPassItem
	weekly_caption = _weekly_col.get_node("Caption")
	weekly_dot = %WeeklyDot
	# _refresh_events() sets it only while Weekly Pass is open.
	weekly_dot.visible = false
	chain_btn = _side_item(%ChainOfferButton, tr("home_chain"), true, _emit.bind("chain"))
	_chain_col = %ChainOfferItem
	chain_dot = %ChainDot
	if Config.ui_preview():
		for p in PREVIEWS:
			var scene := str(p[1])
			_side_item(get_node("%PreviewItem_" + scene).get_node("Preview_" + scene), tr(str(p[0])), true,
				func() -> void:
					Sfx.play("button")
					closed.emit({"action": "preview", "scene": scene}))

	# nút Chơi: chữ PLAY, trên đó là độ khó (Hard/Super Hard)
	play_btn = %PlayButton
	play_btn.pressed.connect(_on_play)
	# shine.gdshader trên chính nút: dải sáng chỉ chạy trên viên thuốc, chữ ở trên không loé; nút tắt thì không loé.
	UiMotion.attach(play_btn, UiMotion.SHINE, PLAY_SHINE_DELAY)
	hard_tag = %HardTag
	play_label = %PlayLabel
	coming_soon_label = %ComingSoonLabel
	coming_soon_label.text = tr("home_coming_soon")

	# hàng trên: avatar, mạng, vàng, settings
	_top = %HubTop as HubTop
	_top.action.connect(_emit)
	profile_btn = _top.profile_btn
	lives_panel = _top.lives_panel
	lives_label = _top.lives_label
	lives_timer_label = _top.lives_timer_label
	gold_label = _top.gold_label
	settings_btn = _top.settings_btn

	# thanh dưới: Shop · Home · Ranking
	_nav = %NavBar as HubNav
	_nav.tab.connect(_on_tab)
	shop_btn = _nav.shop_btn
	shop_caption = _nav.shop_caption

	_tick = %Tick
	_tick.timeout.connect(_refresh_timers)
	_tick.start()


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
	_layout_guide()


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


## Ba mốc nằm trên ray kẹo: y theo khung Figma, tâm ở PATH_X (giữa ray).
## Màn thấp hơn khung thì co cả cụm (ray, cỡ và khoảng cách mốc) quanh (PATH_X, đỉnh cụm) nên mốc vẫn trên ray.
## first (level 1, khung thường): khoá 220 ở 211, khoá 220 ở 525, hiện tại 290 ở 868.
## mid (khung Hard, hạ hai mốc dưới như ref): khoá 220 ở 149, hiện tại 290 ở 548, vừa qua 220 ở 971.
func _layout_path(shift: float) -> void:
	var slots: Array = [[211.0, 220.0], [525.0, 220.0], [868.0, 290.0]] if _path_mode == "first" else [[149.0, 220.0], [548.0, 290.0], [971.0, 220.0]]
	var top: float = slots[0][0]
	var span: float = float(slots[2][0]) + float(slots[2][1]) - top
	var avail := PLAY_RECT.position.y - 12.0 + shift - PATH_GAP - top
	var f := clampf(avail / span, 0.55, 1.0)
	var origin := Vector2(PATH_X, top + maxf(avail - span, 0.0) * 0.5)
	var rail_pos := origin + (RAIL_RECT.position - Vector2(PATH_X, top)) * f
	_fb.put(_rail, Rect2(rail_pos, RAIL_RECT.size * f))
	var rail_end := PLAY_RECT.position.y + shift + RAIL_UNDER_PLAY
	(_rail.material as ShaderMaterial).set_shader_parameter("cut",
		clampf((rail_end - rail_pos.y) / (RAIL_RECT.size.y * f), 0.0, 1.0))
	var cur_idx := 2 if _path_mode == "first" else 1
	for i in 3:
		var px: float = float(slots[i][1]) * f
		var c := origin + Vector2(0.0, float(slots[i][0]) + float(slots[i][1]) * 0.5 - top) * f
		var pn: Dictionary = path_nodes[i]
		_fb.put(pn.root, Rect2(c.x - px * 0.5, c.y - px * 0.5, px, px))
		_layout_node(pn, px, i == cur_idx)
	var cur: Rect2 = _fb.rect_of(path_nodes[cur_idx].root)
	# tâm fx 1 lệch lên 16 khi mốc có đầu lâu (Hard), xuống 5 khi không
	var gs := cur.size.x * GLOW_K
	var gy := cur.get_center().y + cur.size.x * (-16.0 / 290.0 if _tier != "" else 5.0 / 290.0)
	_fb.put(_glow, Rect2(cur.get_center().x - gs * 0.5, gy - gs * 0.5, gs, gs))


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


## Đường level và nút Chơi theo độ khó của level hiện tại (nền giống nhau ở mọi độ khó).
func _refresh_path(level: int, ended: bool) -> void:
	_tier = "" if ended else Game.difficulty_of(level)
	if not TIERS.has(_tier):
		_tier = ""
	var hard := _tier != ""
	_path_mode = "first" if level <= 1 else "mid"
	# mốc khoá luôn là lục giác xám như ref; chỉ mốc hiện tại đổi hình theo độ khó
	if _path_mode == "first":
		_set_node(path_nodes[0], level + 2, "locked", true)
		_set_node(path_nodes[1], level + 1, "locked", true)
		_set_node(path_nodes[2], level, "current", hard)
	else:
		_set_node(path_nodes[0], level + 1, "locked", true)
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
	_fb.resize(play_label, PLAY_LABEL_HARD_RECT if hard_tag.visible else PLAY_LABEL_RECT)

	# quà
	var daily: Dictionary = Game.daily_view()
	_gift_col.visible = bool(daily.get("open", false))
	gift_badge.visible = bool(daily.get("badge", false))

	# weekend sale: chỉ hiện khi sale bật và Shop đã mở
	_sale_col.visible = Unlocks.is_open("shop", level) and Game.is_sale_active()

	# challenge: tắt (Config.FEATURES) thì ẩn hẳn; khoá thì icon tối, có khoá và ghi level mở
	var ch: Dictionary = Game.challenge_view()
	_challenge_col.visible = bool(ch.get("enabled", true))
	var ch_open := bool(ch.get("open", false))
	challenge_btn.disabled = not ch_open
	challenge_btn.modulate = Color.WHITE if ch_open else Color(0.75, 0.75, 0.82)
	_challenge_lock.visible = not ch_open
	challenge_caption.text = tr("home_challenge") if ch_open else tr("home_play_level") % int(ch.get("unlock_level", Config.UNLOCK.challenge))

	# bảng xếp hạng: khoá như challenge
	var lb_open: bool = Game.lb_open()
	leaderboard_btn.disabled = not lb_open
	leaderboard_btn.modulate = Color.WHITE if lb_open else Color(0.75, 0.75, 0.82)
	_leaderboard_lock.visible = not lb_open
	leaderboard_caption.text = tr("home_ranking") if lb_open else tr("home_play_level") % int(Config.UNLOCK.get("leaderboard", 0))

	_refresh_timers()
	_refresh_guide()


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
		"road_trip":
			if road_trip_guide != null:
				_close_guide()
			_emit("road_trip")


func _on_leaderboard() -> void:
	if not Game.lb_open():
		return
	_emit("ranking")


# --- hướng dẫn Road Trip vừa mở (wireframe Road Trip S6) ---

## Hiện lớp hướng dẫn một lần khi Road Trip vừa mở; tắt khi Road Trip khoá lại (tester hạ level).
func _refresh_guide() -> void:
	var want := bool(Game.road_trip_view().get("guide", false)) and not UnityUI.baking
	if want and road_trip_guide == null:
		_open_guide()
	elif not want and road_trip_guide != null:
		road_trip_guide.queue_free()
		road_trip_guide = null


## Phủ tối Home dưới thanh dưới (thanh vẫn sáng và bấm được), bong bóng chữ trên tab Road Trip, bàn tay nhún chỉ
## vào tab. Chạm vùng tối thì tắt.
func _open_guide() -> void:
	var g := Control.new()
	g.name = "RoadTripGuide"
	g.set_anchors_preset(Control.PRESET_FULL_RECT)
	g.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = ThemeKit.SCRIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.add_child(dim)
	var bubble := Label.new()
	bubble.name = "Bubble"
	bubble.text = tr("rt_guide")
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.add_theme_color_override("font_color", ThemeKit.INK)
	bubble.add_theme_stylebox_override("normal", UiAtlas.box("bubble_cream", Vector4(40, 40, 40, 40)))
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.add_child(bubble)
	# The holder is placed by _layout_guide; the hand bobs inside it. Drawn over the bottom bar, which sits above
	# this layer.
	var holder := Control.new()
	holder.name = "HandHolder"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.z_index = 5
	g.add_child(holder)
	var hand := TextureRect.new()
	hand.name = "Hand"
	hand.texture = UiAtlas.tex("hand_tap")
	hand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(hand)
	g.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			_close_guide())
	add_child(g)
	move_child(g, _nav.get_index())
	road_trip_guide = g
	_layout_guide()
	var tw := hand.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(hand, "position:y", -24.0, 0.45)
	tw.tween_property(hand, "position:y", 0.0, 0.45)


## Bong bóng và bàn tay theo tab Road Trip (ô phải của thanh dưới, toạ độ Figma theo đáy khung).
func _layout_guide() -> void:
	if road_trip_guide == null or size.x <= 0.0:
		return
	var s := size.x / DESIGN_W
	var nav_top := size.y - HubNav.DESIGN_H * s
	var bubble := road_trip_guide.get_node("Bubble") as Label
	bubble.add_theme_font_size_override("font_size", roundi(40.0 * s))
	bubble.size = Vector2(520, 170) * s
	bubble.position = Vector2(DESIGN_W - 540.0, 0) * s + Vector2(0, nav_top - 330.0 * s)
	var holder := road_trip_guide.get_node("HandHolder") as Control
	holder.size = Vector2(150, 150) * s
	holder.position = Vector2(DESIGN_W - HubNav.SLOT_W * 0.5 - 30.0, 0) * s + Vector2(0, nav_top - 110.0 * s)


func _close_guide() -> void:
	if road_trip_guide == null:
		return
	road_trip_guide.queue_free()
	road_trip_guide = null
	Game.road_trip_mark_guide()


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
