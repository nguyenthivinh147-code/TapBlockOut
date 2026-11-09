extends Control
## Leaderboard popup (design.md mục 7 "Leaderboard theo league", 2026-11-09): mở từ icon Bảng xếp hạng ở Home, đè lên
## Home. Khung PopupOkLayer (nền tối, Popup2, tiêu đề, X); X, chạm nền tối hoặc Back thì đóng. Nút "i" (Cách hoạt động)
## ở góc trái đầu khung, đối xứng với X. Lòng khung là LeaderboardLayer (nền BG_Winstreak), thanh hai tab ở đáy.
## - Tab League: PromoBox (huy hiệu giải hiện tại, tên giải, đếm ngược tới lúc hết tuần), BXH 100 người của giải
##   (podium top 3 rồi tối đa 50 người quanh người chơi, chỉ xem), hàng người chơi ghim trên hoặc dưới khi cuộn ra ngoài.
## - Tab World: thẻ người chơi (giải, avatar, điểm, Top %, hạng thế giới) và thang 7 giải từ cao xuống thấp, mỗi giải
##   ghi số người chơi mô phỏng; giải hiện tại sáng và có avatar.
## Chạm huy hiệu (PromoBox, hoặc một giải có thưởng trên thang) thì bong bóng thưởng như GiftPanelController: PromoBox
## hiện thưởng của giải kế (giải cao nhất: thưởng của chính nó, "Đã nhận"); thang hiện thưởng của giải đó, "Đã nhận" nếu
## đã vào trong tuần. Chạm lần nữa, chạm chỗ khác hay cuộn thì bong bóng đóng.
## setup({tab}): "league" (mặc định) | "world". Có kết quả tuần chờ xem thì tự mở popup kết quả tuần, rồi tới popup lên
## giải nếu còn thưởng league chờ. Đồng hồ về 0 khi đang mở: chốt tuần rồi dựng lại. closed(null).
## Layout: LeaderboardLayer (color-cube-match-puzzle) gives the panel, the two toggles, the league list
## (PlayerScrollParent with its sticky anchors, PlayerLeaderboardItem rows), the world ScrollRect that holds the ladder,
## the RankBadge (copied into PromoBox) and its reward bubble RewardsParent (one copy, shared by the badge and the
## ladder). Tab strip, promotion box, player card, info button and the Tick timer are nodes of scenes/leaderboard.tscn;
## the frame, list rows and ladder steps are built at runtime.

signal closed(result: Variant)

const Config := preload("res://src/config.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")
const LbKit := preload("res://src/ui/lb_kit.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")

const POPUP_HOWTO := "res://scenes/popup_lb_howto.tscn"
const POPUP_RESULT := "res://scenes/popup_lb_result.tscn"

const LAYER := "LeaderboardLayer"
const FRAME := "PopupOkLayer"
const ITEM := "PlayerLeaderboardItem"
const TABS := "BG/Panel/ToggleGroup/"
const LC := "BG/Panel/ToggleGroup/LeaguesContent/"
const RC := "BG/Panel/ToggleGroup/RankingContent/"
const LIST := LC + "PlayerScrollParent/"
const WLIST := RC + "WeekResults/RankingScrollParent/"
const PLATE := LC + "TimeRemainBG/TimeRemain"
const BADGE := LC + "RankProgressBG/RankProgress/RankBadge"
const BUBBLE := BADGE + "/RankImage/RewardImage/RewardsParent"
const OUTLINE := "Baloo Outline - Blue 1"
## Frame: margin from the screen edge (units at the 886-wide reference screen), height share of the screen, and the
## content area inside Popup2 (frame canvas units): under the header strip, at the sides and the bottom.
const REF_W := 886.0
const FRAME_MARGIN := 16.0
const FRAME_H := 0.85
const INSET_TOP := 112.0
const INSET_SIDE := 22.0
const INSET_BOTTOM := 26.0
## LeaderboardLayer's canvas scales down when the content area is narrower than a row and this padding.
const CONTENT_MIN_W := 840.0
## The info button mirrors the frame's X (Panel/Top/btnTurnOff); its art is smaller than the X's.
const INFO_SIZE := 96.0
## Canvas units of LeaderboardLayer.
const ROW_W := 800.0
const ROW_H := 150.0
const LIST_PAD := 20.0
const GAP := 14.0
## Promotion box (League) and player card (World) above the list.
const PROMO_H := 180.0
const BOX_H := 210.0
## RankBadge (134 x 137) in PromoBox, from the box's top-left.
const BADGE_RECT := Rect2(28, 21, 134, 137)
## Tab strip: the two toggles (prefab 369 x 108) at the bottom of the content area.
const TAB_H := 108.0
const TAB_PAD := 10.0
## Ladder steps (World): height, gap, left of the player count, league icon.
const STEP_H := 150.0
const STEP_GAP := 12.0
const STEP_INFO_X := 400.0
const STEP_ICON := 120.0
## Reward bubble: scale of the prefab bubble (60-unit items), caption row added above its items, a tap that moves less
## than this (px) still counts as a tap on a ladder icon.
const BUBBLE_SCALE := 1.6
const CAPTION_H := 30.0
const CAPTION_FS := 22.0
const TAP_SLOP := 16.0
## UI_Leaderboard_Atlas row backgrounds (LbKit.ROW_BG): my row (green), others (cream); ladder arrow.
const BG_ME := 29
const BG_OTHER := 28
const ARROW := "UI_Leaderboard_Atlas:UI_Leaderboard_Atlas_7"
## Ladder steps above the player's league: alpha (wireframe: locked frames at 60%).
const LOCKED_ALPHA := 0.6
## A week that should have ended but did not roll yet (device clock behind): try again this often.
const ROLL_RETRY_MS := 5000

var view: Dictionary = {}
var tab: String = "league"
var ui: RefCounted = null
var frame: RefCounted = null
var tab_buttons: Dictionary = {}
var content: Control = null
var countdown_label: Label = null
## Sticky card of the player (UILeaguePanel._stickyPlayerCard) and the player's row in the list.
var _pinned_row: Control = null
var _me_in_list: Control = null

var _built: bool = false
var _done: bool = false
var _ends_at_ms: int = 0
var _roll_at_ms: int = 0
var _tick: Timer = null
var _scroll_host: Control = null
var _scroll_y := INF
var _ladder: Control = null
## PromoBox's copy of RankBadge, the shared bubble and the icon it points at (null while hidden).
var _badge: RefCounted = null
var _bubble: RefCounted = null
var _bubble_caption: Label = null
var _bubble_for: Control = null
var _press_at := Vector2.INF


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
	_build_frame()
	ui = UnityUI.build(self, LAYER, {"reveal": false})
	for p in [LIST + "Viewport/Content/PlayerLeaderboardItem", LIST + "Viewport/Content/ArrowIndicator",
			WLIST + "Viewport/Content/PlayerLeaderboardItem"]:
		# Pool templates (inactive in the prefab); rows are built from PlayerLeaderboardItem.json.
		var tpl: Control = ui.node(p)
		tpl.get_parent().remove_child(tpl)
		tpl.queue_free()
	# Prefab parts the popup drops: the strip above the safe area (BG/Image, it would cover the frame's header), tab
	# line, league card (now the promotion box), league badge row (its RankBadge is copied into the promotion box),
	# last week's podium and the world title; the world list's sticky row (the ladder has the player's step).
	for p in ["BG/Image", "BG/Line", LC + "Line (1)", LC + "TimeRemainBG", LC + "RankProgressBG", RC + "LastWeekLeaders",
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
	_build_promo()
	_build_bubble()

	for id in ["league", "world"]:
		var b: Button = ui.button(TABS + ("Leagues" if id == "league" else "Ranking"))
		if not UnityUI.baking:
			b.name = "Tab_" + id
		b.connect("clicked", _set_tab.bind(id))
		tab_buttons[id] = b
	ui.text(TABS + "Ranking/Text (TMP)", tr("lb_tab_world"))

	_tick = %Tick
	_tick.timeout.connect(_on_tick)
	_tick.start()
	resized.connect(_layout)
	_layout()
	if tab == "world":
		(tab_buttons.world as Button).button_pressed = true
	_fill()


## PopupOkLayer frame without its description, well and buttons; X and the dim close (PopupOkUICoreLayer.closeButtons).
## Built without the reveal: the content is a canvas of its own and would stay put while the frame pops in.
func _build_frame() -> void:
	frame = UnityUI.build(self, FRAME, {"reveal": false})
	(frame.canvas as Control).name = "FrameCanvas"
	frame.text("Panel/Image/txtHeader", tr("lb_title"))
	for p in ["Panel/Content/Description", "Panel/Content/Image", "Panel/Content/Button"]:
		frame.show(p, false)
	for b in frame.field("closeButtons", "PopupOkUICoreLayer"):
		(b as Button).connect("clicked", _close)


## RankBadge (UILeaguePanel's badge row: glow, league icon, gift) copied into the promotion box; a tap toggles the
## bubble. The row's slot arrow and the copy's own bubble are not used.
func _build_promo() -> void:
	_badge = ui.clone(BADGE)
	var root: Control = _badge.root
	root.reparent(%PromoBox, false)
	root.name = "PromoBadge"
	root.set_meta("u_rt", true)
	_rect(root, [0, 1, 0, 1, BADGE_RECT.position.x + BADGE_RECT.size.x * 0.5,
		-(BADGE_RECT.position.y + BADGE_RECT.size.y * 0.5), BADGE_RECT.size.x, BADGE_RECT.size.y, 0.5, 0.5])
	_badge.show("Arrow", false)
	_badge.show("RankImage/RewardImage/RewardsParent", false)
	root.connect("clicked", _on_badge)


## One copy of the badge's RewardsParent over the whole layer, so it draws above the list; a caption row sits above
## the items inside RewardBG (the layout group skips RewardBG).
func _build_bubble() -> void:
	_bubble = ui.clone(BUBBLE)
	var root: Control = _bubble.root
	root.reparent(ui.root, false)
	root.name = "RewardBubble"
	root.set_meta("u_rt", true)
	root.scale = Vector2.ONE * BUBBLE_SCALE
	# Own copy of the spec: the padding changes per reward (_show_bubble).
	var u: Dictionary = (root.get_meta("u") as Dictionary).duplicate(true)
	root.set_meta("u", u)
	var pad: Array = u.lay.pad
	pad[2] = float(pad[2]) + CAPTION_H
	var r: Dictionary = root.get_meta("u_rect")
	r.size = Vector2((r.size as Vector2).x, (r.size as Vector2).y + CAPTION_H)
	UnityUI.apply_rect(root)
	var bg: Control = _bubble.node("RewardBG")
	var br: Dictionary = bg.get_meta("u_rect")
	br.size = Vector2((br.size as Vector2).x, (br.size as Vector2).y + CAPTION_H)
	UnityUI.apply_rect(bg)
	_bubble_caption = UnityKit.label(bg, "", Rect2(0, 0, 10, 10), CAPTION_FS, "ffffffff", OUTLINE)
	_bubble_caption.name = "Caption"
	_rect(_bubble_caption, [0, 1, 1, 1, 0, -6, -12, CAPTION_H, 0.5, 1])
	root.visible = false


## Sets a node's Unity rect: [anchorMin.x, anchorMin.y, anchorMax.x, anchorMax.y, pos.x, pos.y, size.x, size.y, pivot.x,
## pivot.y].
static func _rect(c: Control, r: Array) -> void:
	c.set_meta("u_rect", {"amin": Vector2(r[0], r[1]), "amax": Vector2(r[2], r[3]), "pos": Vector2(r[4], r[5]),
		"size": Vector2(r[6], r[7]), "pivot": Vector2(r[8], r[9])})
	UnityUI.apply_rect(c)


## Frame centred with FRAME_MARGIN at the sides and FRAME_H of the height; LeaderboardLayer's canvas fills the frame's
## content area (scaled down on narrow screens); the info button sits in the frame's top-left corner; tab strip at the
## bottom, the tab's box and list above it (LeaderboardLayer units).
func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or ui == null or frame == null:
		return
	_hide_bubble()
	var s := UnityUI.canvas_scale(size)
	var cw := size.x / s
	var ch := size.y / s
	var fw := cw - FRAME_MARGIN * cw / REF_W * 2.0
	var fh := ch * FRAME_H
	UnityKit.set_size(frame.node("Panel"), Vector2(fw, fh))
	UnityKit.set_size(frame.node("Panel/Bg"), Vector2(fw, fh))
	var corner := Vector2((cw - fw) * 0.5, (ch - fh) * 0.5)
	var inner := Rect2(corner + Vector2(INSET_SIDE, INSET_TOP),
		Vector2(fw - INSET_SIDE * 2.0, fh - INSET_TOP - INSET_BOTTOM))
	var k := minf(1.0, inner.size.x / CONTENT_MIN_W)
	var canvas: Control = ui.canvas
	canvas.scale = Vector2.ONE * s * k
	canvas.position = inner.position * s
	canvas.size = inner.size / k
	_place_info.call_deferred(k)
	_set_rect(ui.node("BG/Panel"), 0.0, 0.0)
	_set_rect(%TabStrip, 0.0)
	for id in tab_buttons:
		var r: Dictionary = (tab_buttons[id] as Control).get_meta("u_rect")
		r.amin = Vector2(0.5, 0)
		r.amax = Vector2(0.5, 0)
		r.pivot = Vector2((r.pivot as Vector2).x, 0)
		r.pos = Vector2((r.pos as Vector2).x, TAB_PAD)
		UnityUI.apply_rect(tab_buttons[id])
	var bottom := TAB_H + TAB_PAD * 2.0 + GAP
	var top := GAP + (PROMO_H + GAP if (%PromoBox as Control).visible else 0.0)
	_set_rect(ui.node(LIST.trim_suffix("/")), -top, -(top + bottom))
	var wtop := GAP + BOX_H + GAP
	_set_rect(ui.node(RC + "WeekResults"), -wtop, -(wtop + bottom))
	_rect(ui.node(WLIST.trim_suffix("/")), [0, 0, 1, 1, 0, 0, 0, 0, 0.5, 0.5])


## Info button: the frame's X mirrored across the frame's centre line, in LeaderboardLayer units (above the canvas).
## After the frame is laid out (deferred), from where the X really is.
func _place_info(k: float) -> void:
	if not is_inside_tree() or frame == null:
		return
	var pr := (frame.node("Panel") as Control).get_global_rect()
	var xc := (frame.node("Panel/Top/btnTurnOff") as Control).get_global_rect().get_center()
	var c := (ui.root as Control).get_global_transform().affine_inverse() * Vector2(pr.position.x + pr.end.x - xc.x, xc.y)
	var side := INFO_SIZE / k
	_rect(%InfoButton, [0, 1, 0, 1, c.x - side * 0.5, -(c.y - side * 0.5), side, side, 0, 1])


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


## Dựng lại phần theo tab đang chọn; nhãn tab theo giải hiện tại.
func _fill() -> void:
	_hide_bubble()
	_pinned_row = null
	_me_in_list = null
	_scroll_host = null
	_scroll_y = INF
	content = null
	var open := Game.lb_open()
	var locked: Node = ui.node("BG/Panel").get_node_or_null("LockedLabel")
	(%InfoButton as Control).visible = open
	_ends_at_ms = Time.get_ticks_msec() + Game.lb_ends_in() * 1000
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
	LbKit.set_league_icon(%TabLeagueIcon, league)
	ui.text(TABS + "Leagues/Text (TMP)", LbKit.league_name(league))
	if tab == "world":
		_fill_world()
	else:
		_fill_league()


# --- tab League ---

func _fill_league() -> void:
	view = Game.lb_view()
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


## Promotion box: the current league's badge and name, the countdown to the end of the week (_on_tick).
func _fill_promo() -> void:
	var league := str(view.league)
	LbKit.set_league_icon(_badge.node("RankImage"), league)
	UnityUI.set_text(%PromoTitle as Label, tr("lb_league") % LbKit.league_name(league))


## The badge's bubble: the next league's reward, or the top league's own (already received this week).
func _on_badge() -> void:
	var nxt := str(view.get("next_league", ""))
	if nxt == "":
		var cur := str(view.get("league", ""))
		_toggle_bubble(_badge.root, _league_reward(cur), tr("lb_reward_claimed"))
	else:
		_toggle_bubble(_badge.root, _league_reward(nxt), tr("lb_reward_next") % (tr("lb_league") % LbKit.league_name(nxt)))


static func _league_reward(id: String) -> Dictionary:
	for r in Game.lb_leagues_view().get("rows", []):
		if str(r.id) == id:
			return r.reward
	return {}


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
	_layout()
	_fill_ladder()


## Thang giải: giải cao nhất ở trên. Giải cao hơn giải hiện tại mờ (chưa tới), giải hiện tại nền xanh, quầng sáng và
## avatar "Bạn"; mỗi giải ghi số người chơi mô phỏng. Mở tab thì cuộn để giải hiện tại nằm giữa.
func _fill_ladder() -> void:
	_ladder = ui.node(WLIST + "Viewport/Content")
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
	_scroll_to(owner_step, STEP_H)


## One league step: plate with its name, trophy, players; the player's league gets the green row, a glow and the
## player's avatar. A league with a reward: its trophy opens the bubble.
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
	if bool(r.get("has_reward", false)):
		# PASS: a drag that starts on the trophy still scrolls the ladder.
		ic.mouse_filter = Control.MOUSE_FILTER_PASS
		ic.gui_input.connect(_on_icon_input.bind(ic, r))
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


## A tap (press and release without a drag) on a ladder trophy toggles its bubble.
func _on_icon_input(event: InputEvent, ic: Control, r: Dictionary) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_press_at = mb.global_position
		return
	if _press_at == Vector2.INF or mb.global_position.distance_to(_press_at) > TAP_SLOP:
		return
	_press_at = Vector2.INF
	var id := str(r.id)
	var caption := tr("lb_reward_claimed") if bool(r.get("reached", false)) \
		else tr("lb_reward_next") % (tr("lb_league") % LbKit.league_name(id))
	_toggle_bubble(ic, r.get("reward", {}), caption)


# --- bubble ---

## GiftPanelController.ToggleGiftPanel: the same icon hides it, another icon moves it there.
func _toggle_bubble(target: Control, reward: Dictionary, caption: String) -> void:
	if _bubble_for == target:
		_hide_bubble()
		return
	_show_bubble(target, reward, caption)


## MilestoneItem.SetupData: one PopupRewardItem per part of the reward, the caption above them; the bubble hangs
## under `target` (its arrow up at it), kept inside the layer.
func _show_bubble(target: Control, reward: Dictionary, caption: String) -> void:
	var root: Control = _bubble.root
	for c in root.get_children():
		if c.has_meta("u_clone"):
			root.remove_child(c)
			c.queue_free()
	var entries := LbKit.reward_entries(reward)
	if entries.is_empty():
		_hide_bubble()
		return
	var first: Control = _bubble.node("ItemReward6")
	for i in entries.size():
		var item: Control = first
		if i > 0:
			item = _bubble.clone("ItemReward6").root
			item.name = "ItemReward_%d" % i
		LbKit.set_entry_icon(item.get_node("Icon Item"), entries[i])
		UnityUI.set_text(item.get_node("Quantity") as Label, str(entries[i].amount))
	UnityUI.set_text(_bubble_caption, caption)
	# Wide enough for the caption: the side padding grows, the items stay centred (fitter on the horizontal axis).
	var lay: Dictionary = (root.get_meta("u") as Dictionary).lay
	var pad: Array = lay.pad
	var items_w := float((first.get_meta("u_rect") as Dictionary).size.x) * entries.size()
	var cap_w := UnityUI.layout_sizes(_bubble_caption, 0).y + 24.0
	var side := maxf(15.0, (cap_w - items_w) * 0.5)
	pad[0] = side
	pad[1] = side
	UnityUI.relayout(root)
	# Under the target's bottom centre, in LeaderboardLayer's own units (y down from its top).
	var layer: Control = ui.root
	var to_layer := layer.get_global_transform().affine_inverse()
	var rect := target.get_global_rect()
	var at := to_layer * Vector2(rect.get_center().x, rect.end.y)
	var half := root.size.x * BUBBLE_SCALE * 0.5
	var want := at.x
	at.x = clampf(at.x, half + 8.0, layer.size.x - half - 8.0)
	_rect(root, [0, 1, 0, 1, at.x, -at.y, root.size.x, root.size.y, 0.5, 1])
	# Kept inside the layer: the arrow still points at the target.
	var arrow: Control = _bubble.node("RewardBG/Arrow")
	var ar: Dictionary = arrow.get_meta("u_rect")
	var room := maxf(root.size.x * 0.5 - 20.0, 0.0)
	ar.pos = Vector2(clampf((want - at.x) / BUBBLE_SCALE, -room, room), (ar.pos as Vector2).y)
	UnityUI.apply_rect(arrow)
	root.visible = true
	_bubble_for = target
	Sfx.play("button")


func _hide_bubble() -> void:
	_bubble_for = null
	if _bubble != null and is_instance_valid(_bubble.root):
		(_bubble.root as Control).visible = false


## GiftPanelController.Update: a press anywhere but on the icon the bubble belongs to hides it.
func _input(event: InputEvent) -> void:
	if _bubble_for == null:
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if not is_instance_valid(_bubble_for) or not _bubble_for.get_global_rect().has_point(mb.global_position):
		_hide_bubble.call_deferred()


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
		if _scroll_y != INF:
			# The list moved under the bubble.
			_hide_bubble()
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


## Đếm ngược tới lúc hết tuần; về 0 thì chốt tuần (Game.lb_refresh), dựng lại và mở popup kết quả tuần.
func _on_tick() -> void:
	if not Game.lb_open():
		return
	var left := maxi(0, int((_ends_at_ms - Time.get_ticks_msec()) / 1000.0))
	if countdown_label != null and is_instance_valid(countdown_label):
		UnityUI.set_text(countdown_label, tr("lb_ends_in") % LbKit.fmt_week(left))
	if left <= 0 and is_inside_tree() and Time.get_ticks_msec() >= _roll_at_ms:
		_roll_at_ms = Time.get_ticks_msec() + ROLL_RETRY_MS
		_roll.call_deferred()


func _roll() -> void:
	if not is_inside_tree():
		return
	Game.lb_refresh()
	_fill()
	_show_pending()


## Popup con qua Main.open_popup (cùng lớp popup, nên Back đóng popup trên cùng); chạy riêng (test) thì thành con.
func _open(path: String, args: Dictionary) -> Node:
	var n := get_parent()
	while n != null:
		if n.has_method("open_popup") and n.has_method("add_popup"):
			return n.call("open_popup", path, args)
		n = n.get_parent()
	var node: Node = (load(path) as PackedScene).instantiate()
	add_child(node)
	node.connect("closed", func(_r: Variant) -> void: node.queue_free())
	node.call("setup", args)
	return node


## Kết quả tuần chờ xem (tuần đã hết khi vắng mặt) rồi thưởng league còn chờ (ví dụ thoát game trước khi nhận): mở
## popup tương ứng, đóng xong thì dựng lại và xem tiếp.
func _show_pending() -> void:
	if not is_inside_tree() or _done:
		return
	var w := Game.lb_week_result_view()
	var args := {"week": w} if not w.is_empty() else {"view": Game.lb_pending_view()}
	if w.is_empty() and (args.view as Dictionary).is_empty():
		return
	var node := _open(POPUP_RESULT, args)
	if node != null:
		node.connect("closed", _on_pending_closed)


func _on_pending_closed(_r: Variant) -> void:
	if is_inside_tree() and not _done:
		_fill()
		_show_pending.call_deferred()


func _close() -> void:
	if _done:
		return
	_done = true
	closed.emit(null)


func on_back() -> void:
	_close()
