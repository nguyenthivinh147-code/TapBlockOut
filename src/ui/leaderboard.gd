extends Control
## Leaderboard (wireframe Leaderboard, 2026-11-05): mở từ icon Ranking ở Home, có HubTop và HubNav (không tab nào sáng).
## Banner dưới HubTop (ảnh kẹo, huy hiệu và tên giải hiện tại), phần thân theo tab, thanh hai tab ngay trên HubNav.
## - Tab League: khung thưởng thăng hạng (thưởng của giải kế, ẩn ở giải cao nhất), BXH 100 người của giải (podium top 3
##   rồi tối đa 50 người quanh người chơi, chỉ xem), hàng người chơi ghim trên hoặc dưới khi cuộn ra ngoài. Banner có
##   đếm ngược tới lần bot tăng điểm và nút "i" (Cách hoạt động).
## - Tab World: thẻ người chơi (giải, avatar, điểm, Top %, hạng thế giới) và thang 7 giải từ cao xuống thấp, mỗi giải
##   ghi số người chơi mô phỏng; giải hiện tại sáng và có avatar. Nút trên banner đổi thang sang thưởng của từng giải.
## setup({tab}): "league" (mặc định) | "world". Có thưởng league chờ nhận thì tự mở popup lên giải.
## closed({"action": ...}): "home", "shop" và các action của HubTop / HubNav; Main điều hướng.
## Layout: LeaderboardLayer (color-cube-match-puzzle) gives the panel, the two toggles, the league list
## (PlayerScrollParent with its sticky anchors, PlayerLeaderboardItem rows) and the world ScrollRect that holds the
## ladder. Banner, tab strip, promotion box, player card and the Tick timer are nodes of scenes/leaderboard.tscn made
## from copies of prefab nodes; list rows, rewards and ladder steps are built at runtime.

signal closed(result: Variant)

const Config := preload("res://src/config.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")
const LbKit := preload("res://src/ui/lb_kit.gd")
const HubTop := preload("res://src/ui/hub_top.gd")
const HubNav := preload("res://src/ui/hub_nav.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")

const POPUP_HOWTO := "res://scenes/popup_lb_howto.tscn"
const POPUP_RESULT := "res://scenes/popup_lb_result.tscn"

const LAYER := "LeaderboardLayer"
const ITEM := "PlayerLeaderboardItem"
const TABS := "BG/Panel/ToggleGroup/"
const LC := "BG/Panel/ToggleGroup/LeaguesContent/"
const RC := "BG/Panel/ToggleGroup/RankingContent/"
const LIST := LC + "PlayerScrollParent/"
const WLIST := RC + "WeekResults/RankingScrollParent/"
const PLATE := LC + "TimeRemainBG/TimeRemain"
const BANNER_TEX := "res://assets/ui/lb_banner.png"
const OUTLINE := "Baloo Outline - Blue 1"
## Canvas units. Banner under HubTop (wireframe: 120 of 880 px on a 360 px screen).
const BANNER_H := 260.0
const ROW_W := 800.0
const ROW_H := 150.0
const LIST_PAD := 20.0
const GAP := 14.0
## Promotion box (League) and player card (World) under the banner.
const BOX_H := 210.0
## Tab strip: the two toggles (prefab 369 x 108) above HubNav's buttons. NAV_TOP is in HubNav design units: with no tab
## open, its buttons and purple slots start 102 below the bar's top.
const TAB_H := 108.0
const TAB_PAD := 10.0
const NAV_TOP := 102.0
## Ladder steps (World): height, gap, left of the info (count or rewards), league icon.
const STEP_H := 150.0
const STEP_GAP := 12.0
const STEP_INFO_X := 400.0
const STEP_ICON := 120.0
## Reward prefab item (150 x 200, amount below the icon) scaled into the promotion box and the ladder steps.
## Icon centre y from the holder's top: the amount sits 146.5 x scale below it.
const PROMO_REWARD := 0.5
const PROMO_REWARD_STEP := 130.0
const PROMO_REWARD_Y := 46.0
const STEP_REWARD := 0.48
const STEP_REWARD_STEP := 84.0
const STEP_REWARD_Y := 50.0
## UI_Leaderboard_Atlas row backgrounds (LbKit.ROW_BG): my row (green), others (cream); ladder arrow.
const BG_ME := 29
const BG_OTHER := 28
const ARROW := "UI_Leaderboard_Atlas:UI_Leaderboard_Atlas_7"
## Ladder steps above the player's league: alpha (wireframe: locked frames at 60%).
const LOCKED_ALPHA := 0.6

var view: Dictionary = {}
var tab: String = "league"
var ui: RefCounted = null
var tab_buttons: Dictionary = {}
var content: Control = null
var countdown_label: Label = null
## Sticky card of the player (UILeaguePanel._stickyPlayerCard) and the player's row in the list.
var _pinned_row: Control = null
var _me_in_list: Control = null
## World ladder shows each league's rewards instead of its players.
var rewards_mode := false

var _built: bool = false
var _refresh_at_ms: int = 0
var _tick: Timer = null
var _top: HubTop = null
var _nav: HubNav = null
var _scroll_host: Control = null
var _scroll_y := INF
var _ladder: Control = null


func setup(args: Dictionary = {}) -> void:
	if _built:
		return
	_built = true
	tab = str(args.get("tab", "league"))
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	# Not while tools/bake_screen.gd saves the scene: the popup would be saved with it.
	if not UnityUI.baking:
		_show_pending.call_deferred()


func _ready() -> void:
	setup.call_deferred()


func _build() -> void:
	ui = UnityUI.build(self, LAYER)
	for p in [LIST + "Viewport/Content/PlayerLeaderboardItem", LIST + "Viewport/Content/ArrowIndicator",
			WLIST + "Viewport/Content/PlayerLeaderboardItem"]:
		# Pool templates (inactive in the prefab); rows are built from PlayerLeaderboardItem.json.
		var tpl: Control = ui.node(p)
		tpl.get_parent().remove_child(tpl)
		tpl.queue_free()
	# Prefab parts the wireframe drops: tab line, league card (now banner + promotion box), league badge row,
	# last week's podium and the world title; the world list's sticky row (the ladder has the player's step).
	for p in ["BG/Line", LC + "Line (1)", LC + "TimeRemainBG", LC + "RankProgressBG", RC + "LastWeekLeaders",
			RC + "WeekResults/Title", WLIST + "Viewport/PlayerLeaderboardItem"]:
		ui.show(p, false)
	# The lists' Mask (clip_children) clips drawing only: rows scrolled below a list still took the taps meant for the
	# tab strip under it. clip_contents also clips input, like a Unity Mask clips raycasts.
	for p in [LIST + "Viewport", WLIST + "Viewport"]:
		ui.node(p).clip_contents = true
	if not UnityUI.baking:
		# Renaming an instanced node while baking would break the scene's paths to it.
		ui.node(LIST + "Viewport/Content").name = "Rows"
		ui.node(WLIST + "Viewport/Content").name = "Ladder"
		ui.node(LIST + "Viewport/PlayerLeaderboardItem").name = "MeRow"
	countdown_label = %CountdownLabel
	(%InfoButton as Button).connect("clicked", _open.bind(POPUP_HOWTO, {}))
	(%RewardToggle as Button).connect("clicked", _toggle_rewards)
	var art := %BannerArt as TextureRect
	art.texture = load(BANNER_TEX) as Texture2D if ResourceLoader.exists(BANNER_TEX) else null

	for id in ["league", "world"]:
		var b: Button = ui.button(TABS + ("Leagues" if id == "league" else "Ranking"))
		if not UnityUI.baking:
			b.name = "Tab_" + id
		b.connect("clicked", _set_tab.bind(id))
		tab_buttons[id] = b
	ui.text(TABS + "Ranking/Text (TMP)", tr("lb_tab_world"))

	_top = HubTop.create()
	_top.set_meta("u_rt", true)
	_top.hide_side_buttons()
	_top.action.connect(_act)
	add_child(_top)
	# Opened from Home's Ranking icon: no tab of the bar is this screen.
	_nav = HubNav.create("")
	_nav.set_meta("u_rt", true)
	_nav.tab.connect(_on_tab)
	add_child(_nav)
	_nav.refresh()

	_tick = %Tick
	_tick.timeout.connect(_on_tick)
	_tick.start()
	resized.connect(_layout)
	_layout()
	if tab == "world":
		(tab_buttons.world as Button).button_pressed = true
	_fill()


## Sets a node's Unity rect: [anchorMin.x, anchorMin.y, anchorMax.x, anchorMax.y, pos.x, pos.y, size.x, size.y, pivot.x,
## pivot.y].
static func _rect(c: Control, r: Array) -> void:
	c.set_meta("u_rect", {"amin": Vector2(r[0], r[1]), "amax": Vector2(r[2], r[3]), "pos": Vector2(r[4], r[5]),
		"size": Vector2(r[6], r[7]), "pivot": Vector2(r[8], r[9])})
	UnityUI.apply_rect(c)


## Places HubTop / HubNav like Home; banner under HubTop, tab strip above HubNav's buttons, the tab's box and list
## between them (canvas units).
func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or ui == null:
		return
	var s := size.x / HubTop.DESIGN_W
	_top.position = Vector2(0, 35.0 * s)
	_top.size = Vector2(size.x, HubTop.DESIGN_H * s)
	_nav.size = Vector2(size.x, HubNav.DESIGN_H * s)
	_nav.position = Vector2(0, size.y - HubNav.DESIGN_H * s)
	var cs := UnityUI.canvas_scale(size)
	var top_u := (35.0 + HubTop.DESIGN_H) * s / cs
	var nav_u := (HubNav.DESIGN_H - NAV_TOP) * s / cs
	_set_rect(%Banner, -top_u)
	var panel_top := top_u + BANNER_H
	_set_rect(ui.node("BG/Panel"), -panel_top, -panel_top)
	_set_rect(%TabStrip, nav_u)
	for id in tab_buttons:
		var r: Dictionary = (tab_buttons[id] as Control).get_meta("u_rect")
		r.amin = Vector2(0.5, 0)
		r.amax = Vector2(0.5, 0)
		r.pivot = Vector2((r.pivot as Vector2).x, 0)
		r.pos = Vector2((r.pos as Vector2).x, nav_u + TAB_PAD)
		UnityUI.apply_rect(tab_buttons[id])
	var bottom := nav_u + TAB_H + TAB_PAD * 2.0 + GAP
	var top := GAP + (BOX_H + GAP if (%PromoBox as Control).visible else 0.0)
	_set_rect(ui.node(LIST.trim_suffix("/")), -top, -(top + bottom))
	var wtop := GAP + BOX_H + GAP
	_set_rect(ui.node(RC + "WeekResults"), -wtop, -(wtop + bottom))
	_rect(ui.node(WLIST.trim_suffix("/")), [0, 0, 1, 1, 0, 0, 0, 0, 0.5, 0.5])


## Sets a RectTransform's anchoredPosition.y (and sizeDelta.y when given).
static func _set_rect(c: Control, pos_y: float, size_y: float = NAN) -> void:
	var r: Dictionary = c.get_meta("u_rect")
	r.pos = Vector2((r.pos as Vector2).x, pos_y)
	if not is_nan(size_y):
		r.size = Vector2((r.size as Vector2).x, size_y)
	UnityUI.apply_rect(c)


func _set_tab(id: String) -> void:
	if id == tab:
		return
	tab = id
	# ToggleGroup: pressing one tab releases the other; ToggleAnimator swaps sprites and the two contents.
	(tab_buttons[id] as Button).button_pressed = true
	_fill()


## Dựng lại phần theo tab đang chọn; banner và nhãn tab theo giải hiện tại.
func _fill() -> void:
	_pinned_row = null
	_me_in_list = null
	_scroll_host = null
	_scroll_y = INF
	content = null
	var open := Game.lb_open()
	var locked: Node = ui.node("BG/Panel").get_node_or_null("LockedLabel")
	for n in [%BannerGlow, %BannerIcon, %BannerLeague]:
		(n as Control).visible = open
	(%CountdownPill as Control).visible = open and tab == "league"
	(%InfoButton as Control).visible = open and tab == "league"
	(%RewardToggle as Control).visible = open and tab == "world"
	if not open:
		# The toggles' ToggleAnimator shows one content; locked, neither.
		ui.show(LC.trim_suffix("/"), false)
		ui.show(RC.trim_suffix("/"), false)
		if locked == null:
			var l := UnityKit.label(ui.node("BG/Panel"), tr("lb_locked") % int(Config.UNLOCK.get("leaderboard", 0)),
				Rect2(140, 300, 800, 200), 50.0, "ffffffff", "Baloo Outline - Blue 1")
			l.name = "LockedLabel"
			l.set_meta("u_rt", true)
		return
	var league := str(Game.lb_leagues_view().get("current", "silver"))
	LbKit.set_league_icon(%BannerIcon, league)
	UnityUI.set_text(%BannerLeague as Label, LbKit.league_name(league))
	LbKit.set_league_icon(%TabLeagueIcon, league)
	ui.text(TABS + "Leagues/Text (TMP)", LbKit.league_name(league))
	if tab == "world":
		_fill_world()
	else:
		_fill_league()


# --- tab League ---

func _fill_league() -> void:
	view = Game.lb_view()
	_refresh_at_ms = Time.get_ticks_msec() + int(view.refresh_in) * 1000
	_on_tick()
	_fill_promo()
	_layout()

	content = ui.node(LIST + "Viewport/Content")
	_clear(content)
	var y := LIST_PAD
	var me_row: Control = null
	var podium := Control.new()
	podium.name = "Podium"
	podium.mouse_filter = Control.MOUSE_FILTER_IGNORE
	podium.set_meta("u_rt", true)
	podium.set_meta("u_rect", {"amin": Vector2(0, 1), "amax": Vector2(0, 1), "pos": Vector2.ZERO, "size": Vector2.ZERO,
		"pivot": Vector2(0.5, 0.5)})
	content.add_child(podium)
	UnityKit.place(podium, Rect2(0, y, ROW_W, ROW_H * (view.podium as Array).size()))
	_center_x(podium)
	for i in (view.podium as Array).size():
		var r: Dictionary = view.podium[i]
		var c := _row(podium, r, Rect2(0, ROW_H * i, ROW_W, ROW_H))
		if bool(r.me):
			me_row = c
	y += ROW_H * (view.podium as Array).size()
	for r in view.rows:
		if int(r.rank) <= 3:
			continue
		var c := _row(content, r, Rect2(0, y, ROW_W, ROW_H))
		_center_x(c)
		if bool(r.me):
			me_row = c
		y += ROW_H
	_set_height(content, y)
	var delta := int(view.delta)
	var sub := tr("lb_rank") % [int(view.rank), ("▲ %d" % delta) if delta > 0 else (("▼ %d" % -delta) if delta < 0 else "")]
	_pinned_row = ui.node(LIST + "Viewport/PlayerLeaderboardItem")
	LbKit.fill_card(_pinned_row, _me_view(), sub.strip_edges())
	_caption(_pinned_row)
	_pinned_row.visible = false
	_me_in_list = me_row
	_scroll_host = ui.node(LIST.trim_suffix("/"))
	_scroll_to(me_row)
	Game.lb_opened()


## One list row (PlayerLeaderboardItem) with the "Rank points" caption over its points pill.
func _row(parent: Control, r: Dictionary, rect: Rect2) -> Control:
	var c: Control = LbKit.card(parent, r, rect).root
	c.name = "Me" if bool(r.me) else "Row_%d" % int(r.rank)
	c.set_meta("u_rt", true)
	_caption(c)
	return c


## Small "Rank points" caption above a row's points pill (wireframe: label over the score).
func _caption(row: Control) -> void:
	if row.get_node_or_null("PointsCaption") != null:
		return
	var l := UnityKit.label(row, tr("lb_points_caption"), Rect2(0, 0, 10, 10), 24.0, "ffffffff", OUTLINE)
	l.name = "PointsCaption"
	l.set_meta("u_rt", true)
	# Over PointPanel (145 x 50 at -30 from the right, centred).
	_rect(l, [1, 0.5, 1, 0.5, -30, 27, 145, 32, 1, 0])


func _me_view() -> Dictionary:
	for r in view.rows:
		if bool(r.me):
			return r
	return {"rank": int(view.get("rank", 0)), "points": int(view.get("points", 0)), "me": true,
		"avatar": str(Game.s.cos.get("avatar", "")), "frame": str(Game.s.cos.get("frame", ""))}


## Promotion box: the next league's reward (wireframe: promotion rewards), hidden in the top league.
func _fill_promo() -> void:
	var nxt := str(view.next_league)
	var box := %PromoBox as Control
	box.visible = nxt != ""
	var holder := %PromoRewards as Control
	_clear(holder)
	if nxt == "":
		return
	UnityUI.set_text(%PromoTitle as Label, tr("lb_promo_title") % (tr("lb_league") % LbKit.league_name(nxt)))
	var reward: Dictionary = {}
	for r in Game.lb_leagues_view().get("rows", []):
		if str(r.id) == nxt:
			reward = r.reward
	_place_rewards(holder, reward, PROMO_REWARD, PROMO_REWARD_STEP, 740.0 * 0.5, PROMO_REWARD_Y)


## Reward prefab items for `reward` in a row centred on x = cx (holder's left), icons at y = cy from its top.
func _place_rewards(holder: Control, reward: Dictionary, k: float, step: float, cx: float, cy: float) -> void:
	var items := LbKit.reward_items(holder, reward)
	var x0 := cx - step * (items.size() - 1) * 0.5
	for i in items.size():
		var it: Control = items[i].root
		it.set_meta("u_rt", true)
		var r: Dictionary = it.get_meta("u_rect")
		r.pivot = Vector2(0.5, 0.5)
		UnityKit.place(it, Rect2(x0 + step * i - 75.0, cy - 100.0, 150.0, 200.0))
		it.scale = Vector2.ONE * k


# --- tab World ---

func _fill_world() -> void:
	var w := Game.lb_world_view()
	var league := str(w.league)
	LbKit.set_league_icon(%CardLeagueIcon, league)
	LbKit.set_avatar(%CardAvatar, str(Game.s.cos.get("avatar", "")), str(Game.s.cos.get("frame", "")))
	UnityUI.set_text(%CardName as Label, tr("lb_you"))
	var pts := %CardPoints as Control
	(UnityUI.image_of(pts.get_node("RankPointIcon"))).call("set_texture", ThemeKit.icon(LbKit.PIECE_ICON))
	UnityUI.set_text(pts.get_node("PointText") as Label, LbKit.fmt_int(int(w.points)))
	UnityUI.set_text(%CardTop as Label, tr("lb_top_percent") % int(w.top_percent))
	UnityUI.set_text(%CardRank as Label, tr("lb_world_rank") % LbKit.fmt_int(int(w.rank)))
	UnityUI.set_text(%RewardToggleLabel as Label, tr("lb_btn_info" if rewards_mode else "lb_btn_rewards"))
	_layout()
	_fill_ladder(true)


## Thang giải: giải cao nhất ở trên. Giải cao hơn giải hiện tại mờ (chưa tới), giải hiện tại nền xanh, quầng sáng và
## avatar "Bạn"; mỗi giải ghi số người chơi mô phỏng, hoặc thưởng khi đang ở chế độ Phần thưởng. jump: cuộn để giải
## hiện tại nằm giữa; không thì giữ chỗ cuộn (đổi chế độ).
func _fill_ladder(jump: bool) -> void:
	_ladder = ui.node(WLIST + "Viewport/Content")
	var keep_y := _ladder.position.y
	_clear(_ladder)
	var rows: Array = Game.lb_leagues_view().get("rows", [])
	var cur := 0
	for i in rows.size():
		if bool(rows[i].current):
			cur = i
	var line_top := LIST_PAD + STEP_H * 0.5
	var line: Control = UnityKit.add(_ladder, {"n": "LadderLine", "a": true, "r": [0, 1, 0, 1, 0, 0, 14, 10, 0.5, 0.5],
		"img": {"sp": null, "c": "8fb4ff59", "t": 0}},
		Rect2(0, line_top, 14, (STEP_H + STEP_GAP) * maxi(rows.size() - 1, 0))).root
	line.set_meta("u_rt", true)
	_center_x(line, _step_icon_x() + STEP_ICON * 0.5 - ROW_W * 0.5)
	var y := LIST_PAD
	var owner_step: Control = null
	for k in rows.size():
		var i := rows.size() - 1 - k
		var step := _step(_ladder, rows[i], i, cur, Rect2(0, y, ROW_W, STEP_H))
		if i == cur:
			owner_step = step
		y += STEP_H + STEP_GAP
	_set_height(_ladder, y - STEP_GAP + LIST_PAD)
	content = _ladder
	_scroll_host = ui.node(WLIST.trim_suffix("/"))
	if jump:
		_scroll_to(owner_step, STEP_H)
	else:
		var sc := _scroller()
		if sc != null:
			sc.call("set_content_position", Vector2(_ladder.position.x, keep_y))


## One league step: plate with its name, trophy, players (or rewards); the player's league gets the green row, a glow
## and the player's avatar.
func _step(parent: Control, r: Dictionary, i: int, cur: int, rect: Rect2) -> Control:
	var id := str(r.id)
	var owner_row := i == cur
	var root: Control = UnityKit.add(parent, {"n": "League_" + id, "a": true,
		"r": [0, 1, 0, 1, 0, 0, rect.size.x, rect.size.y, 0.5, 0.5]}, rect).root
	root.set_meta("u_rt", true)
	_center_x(root)
	var bg: Control = UnityKit.add(root, UnityKit.spec(ITEM, "BG")).root
	LbKit.set_atlas(bg, BG_ME if owner_row else BG_OTHER)
	var plate := UnityKit.spec(LAYER, PLATE)
	plate.n = "Plate"
	plate.ch = []
	var pl: Control = UnityKit.add(root, plate, Rect2(18, 33, 236, 84)).root
	var name_l := UnityKit.label(pl, LbKit.league_name(id), Rect2(14, 4, 208, 76), 42.0, "ffffffff", OUTLINE)
	name_l.name = "LeagueName"
	var icon_x := _step_icon_x()
	if owner_row:
		UnityKit.sprite(root, "light1", Rect2(icon_x - 60.0, 15.0 - 60.0, STEP_ICON + 120.0, STEP_ICON + 120.0)).name = "Glow"
	var ic := UnityKit.sprite(root, "ic_Silver", Rect2(icon_x, 15.0, STEP_ICON, STEP_ICON))
	ic.name = "LeagueIcon"
	LbKit.set_league_icon(ic, id)
	if rewards_mode:
		var holder: Control = UnityKit.add(root, {"n": "Rewards", "a": true, "r": [0, 1, 0, 1, 0, 0, 380, STEP_H, 0.5, 0.5]},
			Rect2(STEP_INFO_X, 0, 380, STEP_H)).root
		_place_rewards(holder, r.get("reward", {}), STEP_REWARD, STEP_REWARD_STEP, 190.0, STEP_REWARD_Y)
	else:
		var players := 0
		var lg: Array = Config.LEADERBOARD.get("leagues", [])
		if i < lg.size():
			players = int((lg[i] as Dictionary).get("players", 0))
		var n := UnityKit.label(root, LbKit.fmt_k(players), Rect2(STEP_INFO_X, 26, 190, 66), 54.0, "ffffffff", OUTLINE)
		n.name = "Players"
		var cap := UnityKit.label(root, tr("lb_players"), Rect2(STEP_INFO_X, 88, 190, 40), 28.0)
		cap.name = "PlayersCaption"
		if owner_row:
			var arrow := UnityKit.sprite(root, ARROW, Rect2(596, 50, 50, 50))
			arrow.name = "Arrow"
			arrow.scale = Vector2(-1, 1)
			var av: Control = UnityKit.add(root, UnityKit.spec(ITEM, "Avatar"), Rect2(660, 16, 84, 84)).root
			av.name = "Avatar"
			LbKit.set_avatar(av, str(Game.s.cos.get("avatar", "")), str(Game.s.cos.get("frame", "")))
			var you := UnityKit.label(root, tr("lb_you"), Rect2(632, 102, 140, 40), 30.0, "ffffffff", OUTLINE)
			you.name = "YouLabel"
	# Leagues above the player's: not reached yet.
	root.modulate.a = LOCKED_ALPHA if i > cur else 1.0
	return root


## Left of a step's league icon (row units), just before the info column.
static func _step_icon_x() -> float:
	return STEP_INFO_X - STEP_ICON - 14.0


func _toggle_rewards() -> void:
	rewards_mode = not rewards_mode
	UnityUI.set_text(%RewardToggleLabel as Label, tr("lb_btn_info" if rewards_mode else "lb_btn_rewards"))
	_fill_ladder(false)


# --- chung ---

func _clear(c: Control) -> void:
	for ch in c.get_children():
		c.remove_child(ch)
		ch.queue_free()


## DynamicScrollViewData content height (padding top 20, rows of 150, no spacing). The content spans the
## viewport width and rows are centred in it: u_scroll.gd pins content narrower than the viewport to the left
## edge even on the axis it does not scroll (Unity leaves that axis alone).
func _set_height(c: Control, h: float) -> void:
	var r: Dictionary = c.get_meta("u_rect")
	r.amin = Vector2(0, 1)
	r.amax = Vector2(1, 1)
	r.size = Vector2(0, h)
	UnityUI.apply_rect(c)
	c.position.y = 0.0


## Node anchored to the top centre of the full-width content (see _set_height), dx from the centre.
static func _center_x(c: Control, dx: float = 0.0) -> void:
	var r: Dictionary = c.get_meta("u_rect")
	r.amin = Vector2(0.5, (r.amin as Vector2).y)
	r.amax = Vector2(0.5, (r.amax as Vector2).y)
	r.pos = Vector2(dx, (r.pos as Vector2).y)
	UnityUI.apply_rect(c)


## Top of a row inside the list content (rows 1-3 sit in the Podium holder).
func _row_y(row: Control) -> float:
	var y := row.position.y
	var p := row.get_parent() as Control
	if p != null and p != content:
		y += p.position.y
	return y


func _scroller() -> Node:
	return _scroll_host.get_node_or_null("ScrollRect") if _scroll_host != null else null


## Cuộn để `target` (cao h) nằm giữa danh sách, sau khi danh sách xếp xong. Tween gắn với màn nên tự huỷ khi màn bị xoá.
func _scroll_to(target: Control, h: float = ROW_H) -> void:
	if target == null or content == null or not is_inside_tree():
		return
	var tw := create_tween()
	tw.tween_interval(0.05)
	tw.tween_callback(func() -> void:
		var sc := _scroller()
		if sc == null or not is_instance_valid(target) or not target.is_inside_tree():
			return
		var vp: Control = sc.get("viewport")
		var y := _row_y(target)
		var span := maxf(0.0, content.size.y - vp.size.y)
		sc.call("set_content_position", Vector2(content.position.x, -clampf(y + h * 0.5 - vp.size.y * 0.5, 0.0, span)))
		_update_pinned())


func _process(_delta: float) -> void:
	if content != null and is_instance_valid(content) and content.position.y != _scroll_y:
		_scroll_y = content.position.y
		_update_pinned()


## UILeaguePanel.UpdateStickyCardVisibility: the player's card sticks to the top or bottom of the list while their
## row is out of view (always at the bottom when the list does not have it).
func _update_pinned() -> void:
	if _pinned_row == null or not is_instance_valid(_pinned_row) or _scroll_host == null:
		return
	var vp: Control = _pinned_row.get_parent()
	var where := "bottom"
	if _me_in_list != null and is_instance_valid(_me_in_list) and content != null:
		var y := content.position.y + _row_y(_me_in_list)
		if y >= -0.5 and y + ROW_H <= vp.size.y + 0.5:
			where = ""
		elif y < 0.0:
			where = "top"
	_pinned_row.visible = where != ""
	if where != "":
		var anchor: Control = _scroll_host.find_child("StickyTopPosition" if where == "top" else "StickyBottomPosition", true, false)
		_pinned_row.set_meta("u_rect", (anchor.get_meta("u_rect") as Dictionary).duplicate())
		UnityUI.apply_rect(_pinned_row)


func _on_tick() -> void:
	if countdown_label == null or not is_instance_valid(countdown_label) or view.is_empty():
		return
	var left := maxi(0, int((_refresh_at_ms - Time.get_ticks_msec()) / 1000.0))
	UnityUI.set_text(countdown_label, tr("lb_updates_in") % LbKit.fmt_clock(left))
	if left <= 0 and tab == "league" and is_inside_tree():
		# bot vừa tăng điểm: đọc lại BXH
		_fill.call_deferred()


func _open(path: String, args: Dictionary) -> Node:
	var host := get_parent()
	var node: Node = null
	if host != null and host.has_method("open_popup"):
		node = host.call("open_popup", path, args)
	else:
		node = (load(path) as PackedScene).instantiate()
		add_child(node)
		node.connect("closed", func(_r: Variant) -> void: node.queue_free())
		node.call("setup", args)
	return node


## Thưởng league còn chờ (ví dụ thoát game trước khi nhận): mở popup lên giải, nhận xong thì dựng lại.
func _show_pending() -> void:
	var p := Game.lb_pending_view()
	if p.is_empty() or not is_inside_tree():
		return
	var node := _open(POPUP_RESULT, {"view": p})
	if node != null:
		node.connect("closed", _on_pending_closed)


func _on_pending_closed(_r: Variant) -> void:
	if is_inside_tree():
		_fill()


## HubTop / HubNav buttons are the game's own and need the click sound; prefab buttons play theirs.
func _act(action: String) -> void:
	Sfx.play("button")
	closed.emit({"action": action})


func _on_tab(tab_name: String) -> void:
	_act(tab_name)


func on_back() -> void:
	_act("home")
