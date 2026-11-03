extends Control
## Wireframe 8.1 Leaderboard: màn hub, tab Ranking. Hai tab: League (BXH 100 người của league, chỉ xem) và
## World (top thế giới, chạm một hàng để xem người chơi). Dữ liệu từ Game.lb_view / Game.lb_world_view.
## setup({tab}): tab "league" (mặc định) | "world". Có thưởng league chờ nhận thì tự mở popup lên giải.
## closed({"action": ...}): "home", "shop", "play", "no_lives" và các action của HubTop; Main điều hướng.
## Layout of LeaderboardLayer (color-cube-match-puzzle): tab League = LeaguesContent (league badges row, league
## card with countdown, list of PlayerLeaderboardItem, sticky card of the player), tab World = RankingContent
## (top 3, world rank, list). HubTop / HubNav stay the game's shared bars; the panel starts below HubTop and the
## lists end above PLAY and HubNav. Added from copies of prefab nodes: league progress strip, PLAY button.

signal closed(result: Variant)

const Config := preload("res://src/config.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")
const LbKit := preload("res://src/ui/lb_kit.gd")
const HubTop := preload("res://src/ui/hub_top.gd")
const HubNav := preload("res://src/ui/hub_nav.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")

const POPUP_LEAGUES := "res://scenes/popup_leagues.tscn"
const POPUP_HOWTO := "res://scenes/popup_lb_howto.tscn"
const POPUP_RESULT := "res://scenes/popup_lb_result.tscn"
const POPUP_PLAYER := "res://scenes/popup_lb_player.tscn"

const LAYER := "LeaderboardLayer"
const TABS := "BG/Panel/ToggleGroup/"
const LC := "BG/Panel/ToggleGroup/LeaguesContent/"
const RC := "BG/Panel/ToggleGroup/RankingContent/"
const CARD := LC + "TimeRemainBG/TimeRemain/"
const LIST := LC + "PlayerScrollParent/"
const WLIST := RC + "WeekResults/RankingScrollParent/"
## Prefab numbers (canvas units): panel top, tabs above it (31 + 108), list tops, row height and list padding.
const PANEL_TOP := 262.34
const LINE_ABOVE := 20.34
const TABS_H := 139.0
const LIST_TOP := 276.2
const LINE1_Y := 270.1
const CARD_BOTTOM := 261.0
const WORLD_TOP := 546.4
const ROW_H := 150.0
const ROW_W := 800.0
const LIST_PAD := 20.0
## Gap between HubTop and the tabs (Unity: currency bar bottom ~80, tabs top 123).
const TABS_GAP := 16.0
## League progress strip under the league card: a copy of TimeRemainBG.
const PROGRESS_H := 100.0
## PLAY: PopupOkLayer pill at SettingLanguage Save's 400 x 120, above HubNav.
const PLAY := Vector2(400, 120)
const PLAY_GAP := 20.0
const BADGE_W := 134.4

var view: Dictionary = {}
var tab: String = "league"
var ui: RefCounted = null
var tab_buttons: Dictionary = {}
var content: Control = null
var countdown_label: Label = null
## Sticky card of the player (UILeaguePanel._stickyPlayerCard) and the player's row in the list.
var _pinned_row: Control = null
var _me_in_list: Control = null

var _built: bool = false
var _refresh_at_ms: int = 0
var _tick: Timer = null
var _top: HubTop = null
var _nav: HubNav = null
var _play: Control = null
var _progress: RefCounted = null
var _badges: Array = []
var _scroll_host: Control = null
var _scroll_y := INF


func setup(args: Dictionary = {}) -> void:
	if _built:
		return
	_built = true
	tab = str(args.get("tab", "league"))
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
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
	ui.node(LIST + "Viewport/Content").name = "Rows"
	ui.node(WLIST + "Viewport/Content").name = "WorldRows"
	ui.node(LIST + "Viewport/PlayerLeaderboardItem").name = "MeRow"
	ui.node(WLIST + "Viewport/PlayerLeaderboardItem").name = "WorldMeRow"
	ui.node(LC + "TimeRemainBG").name = "LeagueCard"
	ui.node(RC + "WeekResults/Title").name = "WorldCard"
	ui.node(RC + "LastWeekLeaders/Leaders").name = "Podium"
	ui.node(CARD + "RankName").name = "LeagueLabel"
	countdown_label = ui.node(CARD + "Image/TimeText") as Label
	countdown_label.name = "CountdownLabel"
	ui.node(RC + "WeekResults/Title/Text (TMP)").name = "WorldRankLabel"
	var info: Control = ui.on_click(LC + "TimeRemainBG/DescButton", _open.bind(POPUP_HOWTO, {}))
	info.name = "InfoButton"
	ui.on_click(RC + "LastWeekLeaders/Title/DescButton", _open.bind(POPUP_HOWTO, {}))
	ui.show(LC + "RankProgressBG/RankProgress/RankBadge", false)

	for id in ["league", "world"]:
		var p := TABS + ("Leagues" if id == "league" else "Ranking")
		ui.text(p + "/Text (TMP)", tr("lb_tab_" + id))
		var b: Button = ui.button(p)
		b.name = "Tab_" + id
		b.connect("clicked", _set_tab.bind(id))
		tab_buttons[id] = b
	_add_progress()

	_play = UnityKit.button(ui.root, "green", tr("home_play"), Rect2(Vector2.ZERO, PLAY), _on_play).root
	_play.name = "PlayButton"

	_top = HubTop.new()
	_top.action.connect(_act)
	add_child(_top)
	_nav = HubNav.new("ranking")
	_nav.tab.connect(_on_tab)
	add_child(_nav)
	_nav.refresh()

	_tick = Timer.new()
	_tick.wait_time = 1.0
	_tick.timeout.connect(_on_tick)
	add_child(_tick)
	_tick.start()
	resized.connect(_layout)
	_layout()
	if tab == "world":
		(tab_buttons.world as Button).button_pressed = true
	_fill()


## League progress (game content Unity has no slot for): a copy of TimeRemainBG under the league card with the
## Slider prefab (points to the next league) and two texts in TimeText's style (goal, top percent).
func _add_progress() -> void:
	var s := UnityKit.spec(LAYER, LC + "TimeRemainBG")
	s.n = "LeagueProgress"
	s.ch = []
	s.r = [0, 1, 1, 1, 0, -CARD_BOTTOM, 0, PROGRESS_H, 0.5, 1]
	_progress = UnityKit.add(ui.node(LC.trim_suffix("/")), s)
	# Keep it right after the card, before the list (draw order like the prefab siblings).
	ui.node(LC.trim_suffix("/")).move_child(_progress.root, ui.node(LC + "TimeRemainBG").get_index() + 1)
	var bar := UnityKit.spec("Slider", "")
	bar.n = "LeagueBar"
	bar.r = [0.5, 1, 0.5, 1, 0, -12, 610, 40, 0.5, 1]
	var bv: RefCounted = UnityKit.add(_progress.root, bar)
	bv.show("Handle Slide Area", false)
	var pts := UnityKit.spec(LAYER, CARD + "Image/TimeText")
	pts.n = "PointsText"
	pts.r = [0.5, 0.5, 0.5, 0.5, 0, 0, 400, 46, 0.5, 0.5]
	UnityKit.add(bv.root, pts)
	for d in [["GoalLabel", 1, -305.0, 0.0, 400.0], ["TopPercentLabel", 4, 305.0, 1.0, 200.0]]:
		var t := UnityKit.spec(LAYER, CARD + "Image/TimeText")
		t.n = d[0]
		t.txt.h = d[1]
		t.txt.fs = 32.0
		t.txt.auto = [18.0, 32.0]
		t.r = [0.5, 1, 0.5, 1, d[2], -58, d[4], 40, d[3], 1]
		UnityKit.add(_progress.root, t)


## Places HubTop / HubNav like Home and fits the prefab panel between them (canvas units).
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
	var nav_u := HubNav.DESIGN_H * s / cs
	var panel_top := maxf(PANEL_TOP, top_u + TABS_GAP + TABS_H)
	_set_rect(ui.node("BG/Panel"), -panel_top, -panel_top)
	_set_rect(ui.node("BG/Line"), -(panel_top - LINE_ABOVE))
	var bottom := nav_u + PLAY_GAP * 2.0 + PLAY.y
	_set_rect(ui.node(LC + "Line (1)"), -(LINE1_Y + PROGRESS_H))
	_set_rect(ui.node(LIST.trim_suffix("/")), -(LIST_TOP + PROGRESS_H), -(LIST_TOP + PROGRESS_H + bottom))
	_set_rect(ui.node(RC + "WeekResults"), -WORLD_TOP, -(WORLD_TOP + bottom))
	var r: Dictionary = _play.get_meta("u_rect")
	r.amin = Vector2(0.5, 0)
	r.amax = Vector2(0.5, 0)
	r.pivot = Vector2(0.5, 0)
	r.pos = Vector2(0, nav_u + PLAY_GAP)
	UnityUI.apply_rect(_play)
	# Seven league badges in a row made for five: shrink the row to the canvas width.
	var row: Control = ui.node(LC + "RankProgressBG/RankProgress")
	var need := BADGE_W * maxi(_badges.size(), 5)
	var rr: Dictionary = row.get_meta("u_rect")
	rr.size = Vector2(need, (rr.size as Vector2).y)
	UnityUI.apply_rect(row)
	var avail := size.x / cs - 16.0
	row.scale = Vector2.ONE * minf(1.0, avail / need)
	UnityUI.relayout(row)


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


## Dựng lại phần dưới tab theo tab đang chọn.
func _fill() -> void:
	_pinned_row = null
	_me_in_list = null
	_scroll_host = null
	_scroll_y = INF
	var open := Game.lb_open()
	var locked: Node = ui.node("BG/Panel").get_node_or_null("LockedLabel")
	if not open:
		ui.show(LC.trim_suffix("/"), false)
		ui.show(RC.trim_suffix("/"), false)
		if locked == null:
			var l := UnityKit.label(ui.node("BG/Panel"), tr("lb_locked") % int(Config.UNLOCK.get("leaderboard", 0)),
				Rect2(140, 300, 800, 200), 50.0, "ffffffff", "Baloo Outline - Blue 1")
			l.name = "LockedLabel"
		return
	if tab == "world":
		_fill_world()
	else:
		_fill_league()


# --- tab League ---

func _fill_league() -> void:
	view = Game.lb_view()
	_refresh_at_ms = Time.get_ticks_msec() + int(view.refresh_in) * 1000
	var league := str(view.league)
	_fill_badges(league)
	LbKit.set_league_icon(ui.node(CARD + "RankIcon"), league)
	UnityUI.set_text(ui.node(CARD + "RankName") as Label, tr("lb_league") % LbKit.league_name(league))
	_on_tick()
	_fill_progress()

	content = ui.node(LIST + "Viewport/Content")
	_clear(content)
	var y := LIST_PAD
	var me_row: Control = null
	var podium := Control.new()
	podium.name = "Podium"
	podium.mouse_filter = Control.MOUSE_FILTER_IGNORE
	podium.set_meta("u_rect", {"amin": Vector2(0, 1), "amax": Vector2(0, 1), "pos": Vector2.ZERO, "size": Vector2.ZERO,
		"pivot": Vector2(0.5, 0.5)})
	content.add_child(podium)
	UnityKit.place(podium, Rect2(0, y, ROW_W, ROW_H * (view.podium as Array).size()))
	_center_x(podium)
	for i in (view.podium as Array).size():
		var r: Dictionary = view.podium[i]
		var c: Control = LbKit.card(podium, r, Rect2(0, ROW_H * i, ROW_W, ROW_H)).root
		c.name = "Me" if bool(r.me) else "Row_%d" % int(r.rank)
		if bool(r.me):
			me_row = c
	y += ROW_H * (view.podium as Array).size()
	for r in view.rows:
		if int(r.rank) <= 3:
			continue
		var c: Control = LbKit.card(content, r, Rect2(0, y, ROW_W, ROW_H)).root
		_center_x(c)
		c.name = "Me" if bool(r.me) else "Row_%d" % int(r.rank)
		if bool(r.me):
			me_row = c
		y += ROW_H
	_set_height(content, y)
	var delta := int(view.delta)
	var sub := tr("lb_rank") % [int(view.rank), ("▲ %d" % delta) if delta > 0 else (("▼ %d" % -delta) if delta < 0 else "")]
	_pinned_row = ui.node(LIST + "Viewport/PlayerLeaderboardItem")
	LbKit.fill_card(_pinned_row, _me_view(), sub.strip_edges())
	_pinned_row.visible = false
	_me_in_list = me_row
	_scroll_host = ui.node(LIST.trim_suffix("/"))
	_scroll_to(me_row)
	Game.lb_opened()


func _me_view() -> Dictionary:
	for r in view.rows:
		if bool(r.me):
			return r
	return {"rank": int(view.get("rank", 0)), "points": int(view.get("points", 0)), "me": true,
		"avatar": str(Game.s.cos.get("avatar", "")), "frame": str(Game.s.cos.get("frame", ""))}


## RankBadgeInfo per league: trophy (alpha 0.4 except the current league, which gets the light), gift while its
## reward is still ahead, arrow to the next. Every badge opens the Leagues popup.
func _fill_badges(current: String) -> void:
	for b in _badges:
		if is_instance_valid(b.root):
			b.root.queue_free()
			b.root.get_parent().remove_child(b.root)
	_badges.clear()
	var rows: Array = Game.lb_leagues_view().get("rows", [])
	for i in rows.size():
		var r: Dictionary = rows[i]
		var b: RefCounted = ui.clone(LC + "RankProgressBG/RankProgress/RankBadge")
		var cur := str(r.id) == current
		b.root.name = "LeagueBadgeButton" if cur else "Badge_" + str(r.id)
		LbKit.set_league_icon(b.node("RankImage"), str(r.id))
		var img: Control = b.image("RankImage")
		img.call("set_color", Color(img.color, 1.0 if cur else 0.4))
		b.show("Image", cur)
		b.show("RankImage/RewardImage", not (r.get("reward", {}) as Dictionary).is_empty() and not bool(r.get("reached", false)))
		b.show("Arrow", i < rows.size() - 1)
		b.on_click("", _open_leagues)
		_badges.append(b)
	_layout()


func _fill_progress() -> void:
	var nxt := int(view.next_min)
	var bar: Control = _progress.root.get_node("LeagueBar")
	UnityUI.set_slider(bar, float(view.progress))
	UnityUI.set_text(bar.get_node("PointsText") as Label,
		("%d/%d" % [int(view.points), nxt]) if nxt >= 0 else LbKit.fmt_int(int(view.points)))
	var goal := tr("lb_top_league") if nxt < 0 else tr("lb_to_next") % [nxt - int(view.points), LbKit.league_name(str(view.next_league))]
	UnityUI.set_text(_progress.root.get_node("GoalLabel") as Label, goal)
	UnityUI.set_text(_progress.root.get_node("TopPercentLabel") as Label, tr("lb_top_percent") % int(view.top_percent))


# --- tab World ---

func _fill_world() -> void:
	var w := Game.lb_world_view()
	UnityUI.set_text(ui.node(RC + "LastWeekLeaders/Title/Text (TMP)") as Label, tr("lb_world_sub") % LbKit.fmt_int(int(w.total)))
	UnityUI.set_text(ui.node(RC + "WeekResults/Title/Text (TMP)") as Label, tr("lb_world_rank") % LbKit.fmt_int(int(w.rank)))
	# RemainTime pill: the week countdown slot shows the player's top percent (no clock: not a time).
	var pct: Label = ui.label(RC + "WeekResults/Title/RemainTime/Text (TMP) (1)")
	UnityUI.set_text(pct, tr("lb_top_percent") % int(w.top_percent))
	var pr: Dictionary = pct.get_meta("u_rect")
	pr.pos = Vector2(0, (pr.pos as Vector2).y)
	UnityUI.apply_rect(pct)
	ui.show(RC + "WeekResults/Title/RemainTime/Image", false)
	var rows: Array = w.rows
	for i in 3:
		var top: Control = ui.node(RC + "LastWeekLeaders/Leaders/Top%d" % (i + 1))
		top.visible = i < rows.size()
		if i < rows.size():
			_fill_top(top, rows[i])
	content = ui.node(WLIST + "Viewport/Content")
	_clear(content)
	var y := LIST_PAD
	var me_row: Control = null
	for r in rows:
		if int(r.rank) <= 3:
			continue
		var b: Control = LbKit.card(content, r, Rect2(0, y, ROW_W, ROW_H), "", true).root
		_center_x(b)
		b.name = "WorldRow_%d" % int(r.rank)
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.connect("clicked", _open_player.bind(r))
		if bool(r.me):
			me_row = b
		y += ROW_H
	_set_height(content, y)
	var me := {"rank": int(w.rank), "points": int(w.points), "me": true, "league": str(w.league),
		"avatar": str(Game.s.cos.get("avatar", "")), "frame": str(Game.s.cos.get("frame", ""))}
	_pinned_row = ui.node(WLIST + "Viewport/PlayerLeaderboardItem")
	LbKit.fill_card(_pinned_row, me, tr("lb_league") % LbKit.league_name(str(w.league)))
	_pinned_row.visible = false
	_me_in_list = me_row
	_scroll_host = ui.node(WLIST.trim_suffix("/"))


## UILeaderboardUserCard.SetupTop3Card on Top1..Top3 (badge art stays; name, points, avatar, frame).
func _fill_top(top: Control, r: Dictionary) -> void:
	UnityUI.set_text(top.get_node("PlayerName") as Label, LbKit.display_name(r))
	UnityUI.set_text(top.get_node("PointPanel/PointText") as Label, LbKit.fmt_int(int(r.points)))
	(UnityUI.image_of(top.get_node("PointPanel/RankPointIcon"))).call("set_texture", ThemeKit.icon(LbKit.PIECE_ICON))
	LbKit.set_avatar(top.get_node("Avatar"), str(r.get("avatar", "")), str(r.get("frame", "")))


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


## Row anchored to the top centre of the full-width content (see _set_height).
static func _center_x(c: Control) -> void:
	var r: Dictionary = c.get_meta("u_rect")
	r.amin = Vector2(0.5, (r.amin as Vector2).y)
	r.amax = Vector2(0.5, (r.amax as Vector2).y)
	r.pos = Vector2(0, (r.pos as Vector2).y)
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


## Cuộn để hàng người chơi nằm giữa danh sách, sau khi danh sách xếp xong. Tween gắn với màn nên tự huỷ khi
## màn bị xoá.
func _scroll_to(target: Control) -> void:
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
		sc.call("set_content_position", Vector2(content.position.x, -clampf(y + ROW_H * 0.5 - vp.size.y * 0.5, 0.0, span)))
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


func _open_leagues() -> void:
	_open(POPUP_LEAGUES, {"view": Game.lb_leagues_view()})


func _open_player(r: Dictionary) -> void:
	_open(POPUP_PLAYER, {"view": r})


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


func _on_play() -> void:
	_send("play" if bool(Game.lives_view().get("can_play", true)) else "no_lives")


## HubTop / HubNav buttons are the game's own and need the click sound; prefab buttons play theirs.
func _act(action: String) -> void:
	Sfx.play("button")
	closed.emit({"action": action})


func _send(action: String) -> void:
	closed.emit({"action": action})


func _on_tab(tab_name: String) -> void:
	if tab_name != "ranking":
		_act(tab_name)


func on_back() -> void:
	_act("home")
