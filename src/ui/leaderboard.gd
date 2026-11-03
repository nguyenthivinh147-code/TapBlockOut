extends Control
## Wireframe 8.1 Leaderboard: màn hub, tab Ranking. Hai tab: League (BXH 100 người của league, chỉ xem) và
## World (top thế giới, chạm một hàng để xem người chơi). Dữ liệu từ Game.lb_view / Game.lb_world_view.
## setup({tab}): tab "league" (mặc định) | "world". Có thưởng league chờ nhận thì tự mở popup lên giải.
## closed({"action": ...}): "home", "shop", "play", "no_lives" và các action của HubTop; Main điều hướng.

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const Config := preload("res://src/config.gd")
const LbKit := preload("res://src/ui/lb_kit.gd")
const HubTop := preload("res://src/ui/hub_top.gd")
const HubNav := preload("res://src/ui/hub_nav.gd")

const POPUP_LEAGUES := "res://scenes/popup_leagues.tscn"
const POPUP_HOWTO := "res://scenes/popup_lb_howto.tscn"
const POPUP_RESULT := "res://scenes/popup_lb_result.tscn"
const POPUP_PLAYER := "res://scenes/popup_lb_player.tscn"
const BADGE_PX := 132

var view: Dictionary = {}
var tab: String = "league"
var tabs_row: HBoxContainer = null
var tab_buttons: Dictionary = {}
var content: VBoxContainer = null
var scroll: ScrollContainer = null
var countdown_label: Label = null
## Hàng người chơi ghim dưới danh sách, và hàng của người chơi trong danh sách (tab League).
var _pinned_row: Control = null
var _me_in_list: Control = null

var _built: bool = false
var _refresh_at_ms: int = 0
var _tick: Timer = null


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
	theme = ThemeKit.make_theme()
	add_child(ThemeKit.make_background())
	var page := VBoxContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 0)
	add_child(page)
	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 8)
	page.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	var top := HubTop.new()
	top.action.connect(_act)
	col.add_child(top)
	tabs_row = HBoxContainer.new()
	tabs_row.name = "Tabs"
	tabs_row.add_theme_constant_override("separation", 10)
	col.add_child(tabs_row)
	_fill_tabs()
	content = VBoxContainer.new()
	content.name = "Content"
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	col.add_child(content)
	var play := ThemeKit.make_button(tr("home_play"), "primary")
	play.name = "PlayButton"
	play.pressed.connect(_on_play)
	col.add_child(play)

	var nav := HubNav.new("ranking")
	nav.tab.connect(_on_tab)
	page.add_child(nav)
	nav.refresh()

	_tick = Timer.new()
	_tick.wait_time = 1.0
	_tick.timeout.connect(_on_tick)
	add_child(_tick)
	_tick.start()
	_fill()


## Nút tab: tab đang chọn màu xanh, tab kia xám.
func _fill_tabs() -> void:
	for c in tabs_row.get_children():
		tabs_row.remove_child(c)
		c.queue_free()
	tab_buttons.clear()
	for id in ["league", "world"]:
		var b := ThemeKit.make_button(tr("lb_tab_" + id), "primary" if id == tab else "secondary")
		b.name = "Tab_" + id
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_set_tab.bind(id))
		tabs_row.add_child(b)
		tab_buttons[id] = b


func _set_tab(id: String) -> void:
	if id == tab:
		return
	Sfx.play("button")
	tab = id
	_fill_tabs()
	_fill()


## Dựng lại phần dưới tab theo tab đang chọn.
func _fill() -> void:
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	scroll = null
	countdown_label = null
	_pinned_row = null
	_me_in_list = null
	if not Game.lb_open():
		var msg := ThemeKit.make_label(tr("lb_locked") % int(Config.UNLOCK.get("leaderboard", 0)), ThemeKit.FS_BODY)
		msg.name = "LockedLabel"
		msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		msg.size_flags_vertical = Control.SIZE_EXPAND_FILL
		msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		content.add_child(msg)
		return
	if tab == "world":
		_fill_world()
	else:
		_fill_league()


# --- tab League ---

func _fill_league() -> void:
	view = Game.lb_view()
	_refresh_at_ms = Time.get_ticks_msec() + int(view.refresh_in) * 1000
	content.add_child(_league_card())
	var list := _scroll_list()
	list.add_child(LbKit.podium(view.podium))
	var me_row: Control = null
	for r in view.rows:
		if int(r.rank) <= 3:
			continue
		var row := LbKit.row(r)
		list.add_child(row)
		if bool(r.me):
			me_row = row
	var delta := int(view.delta)
	var sub := tr("lb_rank") % [int(view.rank), ("▲ %d" % delta) if delta > 0 else (("▼ %d" % -delta) if delta < 0 else "")]
	_pinned_row = _pinned(_me_view(), sub)
	content.add_child(_pinned_row)
	_me_in_list = me_row
	scroll.get_v_scroll_bar().value_changed.connect(_update_pinned)
	_scroll_to(me_row)
	Game.lb_opened()


func _me_view() -> Dictionary:
	for r in view.rows:
		if bool(r.me):
			return r
	return {"rank": int(view.get("rank", 0)), "points": int(view.get("points", 0)), "me": true,
		"avatar": str(Game.s.cos.get("avatar", "")), "frame": str(Game.s.cos.get("frame", ""))}


func _league_card() -> Control:
	var well := ThemeKit.make_well(ThemeKit.POPUP_CREAM, ThemeKit.PANEL_BORDER)
	well.name = "LeagueCard"
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	well.add_child(h)
	var badge := Button.new()
	badge.name = "LeagueBadgeButton"
	badge.flat = true
	badge.focus_mode = Control.FOCUS_NONE
	badge.custom_minimum_size = Vector2(BADGE_PX, BADGE_PX)
	var art := LbKit.league_badge(str(view.league), BADGE_PX - 12)
	art.set_anchors_preset(Control.PRESET_CENTER)
	art.grow_horizontal = Control.GROW_DIRECTION_BOTH
	art.grow_vertical = Control.GROW_DIRECTION_BOTH
	badge.add_child(art)
	badge.pressed.connect(_open_leagues)
	h.add_child(badge)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	h.add_child(v)
	var title := ThemeKit.ink_label(tr("lb_league") % LbKit.league_name(str(view.league)), ThemeKit.FS_SMALL + 8, ThemeKit.BROWN)
	title.name = "LeagueLabel"
	v.add_child(title)
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 8)
	v.add_child(bar_row)
	var bar := ProgressBar.new()
	bar.name = "LeagueBar"
	bar.custom_minimum_size = Vector2(0, 26)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.001
	bar.value = float(view.progress)
	ThemeKit.style_bar(bar, LbKit.league_color(str(view.league)))
	bar_row.add_child(bar)
	var nxt := int(view.next_min)
	bar_row.add_child(ThemeKit.ink_label(("%d/%d" % [int(view.points), nxt]) if nxt >= 0 else LbKit.fmt_int(int(view.points)), ThemeKit.FS_SMALL - 2))
	var goal := tr("lb_top_league") if nxt < 0 else tr("lb_to_next") % [nxt - int(view.points), LbKit.league_name(str(view.next_league))]
	var goal_label := ThemeKit.ink_label(goal, ThemeKit.FS_SMALL - 4, ThemeKit.INK_DIM)
	goal_label.name = "GoalLabel"
	v.add_child(goal_label)
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 14)
	v.add_child(info_row)
	var pct := ThemeKit.ink_label(tr("lb_top_percent") % int(view.top_percent), ThemeKit.FS_SMALL - 2, ThemeKit.INK_GOOD)
	pct.name = "TopPercentLabel"
	info_row.add_child(pct)
	countdown_label = ThemeKit.ink_label("", ThemeKit.FS_SMALL - 4, ThemeKit.INK_DIM)
	countdown_label.name = "CountdownLabel"
	info_row.add_child(countdown_label)
	_on_tick()

	var info := ThemeKit.make_icon_button("ui_info")
	info.name = "InfoButton"
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.pressed.connect(_open.bind(POPUP_HOWTO, {}))
	h.add_child(info)
	return well


# --- tab World ---

func _fill_world() -> void:
	var w := Game.lb_world_view()
	var card := ThemeKit.make_well(ThemeKit.POPUP_CREAM, ThemeKit.PANEL_BORDER)
	card.name = "WorldCard"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)
	var t := ThemeKit.ink_label(tr("lb_world_rank") % LbKit.fmt_int(int(w.rank)), ThemeKit.FS_SMALL + 8, ThemeKit.BROWN)
	t.name = "WorldRankLabel"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := ThemeKit.ink_label("%s · %s" % [tr("lb_top_percent") % int(w.top_percent), tr("lb_world_sub") % LbKit.fmt_int(int(w.total))],
		ThemeKit.FS_SMALL - 2, ThemeKit.INK_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	content.add_child(card)
	var list := _scroll_list()
	var top3: Array = (w.rows as Array).slice(0, 3)
	list.add_child(LbKit.podium(top3))
	for r in w.rows:
		if int(r.rank) <= 3:
			continue
		var b := LbKit.row_button(r)
		b.pressed.connect(_open_player.bind(r))
		list.add_child(b)
	var me := {"rank": int(w.rank), "points": int(w.points), "me": true, "league": str(w.league),
		"avatar": str(Game.s.cos.get("avatar", "")), "frame": str(Game.s.cos.get("frame", ""))}
	content.add_child(_pinned(me, tr("lb_league") % LbKit.league_name(str(w.league))))


# --- chung ---

func _scroll_list() -> VBoxContainer:
	scroll = ScrollContainer.new()
	scroll.name = "List"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "Rows"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	return list


## Hàng của người chơi ghim dưới danh sách.
func _pinned(me: Dictionary, sub: String) -> Control:
	var row := LbKit.row(me, sub)
	row.name = "MeRow"
	return row


## Cuộn để hàng người chơi nằm giữa danh sách, sau khi danh sách xếp xong. Tween gắn với màn nên tự huỷ khi
## màn bị xoá.
func _scroll_to(target: Control) -> void:
	if target == null or scroll == null or not is_inside_tree():
		return
	var tw := create_tween()
	tw.tween_interval(0.05)
	tw.tween_callback(func() -> void:
		if is_instance_valid(scroll) and is_instance_valid(target) and target.is_inside_tree():
			scroll.scroll_vertical = maxi(0, int(target.position.y - (scroll.size.y - target.size.y) * 0.5))
			_update_pinned())


## Hàng ghim chỉ hiện khi hàng của người chơi trong danh sách đã khuất (tránh hiện hai lần).
func _update_pinned(_v: float = 0.0) -> void:
	if _pinned_row == null or not is_instance_valid(_pinned_row):
		return
	var show := true
	if _me_in_list != null and is_instance_valid(_me_in_list) and scroll != null and is_instance_valid(scroll):
		var top := float(scroll.scroll_vertical)
		var y := _me_in_list.position.y
		show = y < top or y + _me_in_list.size.y > top + scroll.size.y
	_pinned_row.visible = show


func _on_tick() -> void:
	if countdown_label == null or not is_instance_valid(countdown_label):
		return
	var left := maxi(0, int((_refresh_at_ms - Time.get_ticks_msec()) / 1000.0))
	countdown_label.text = tr("lb_updates_in") % LbKit.fmt_clock(left)
	if left <= 0 and tab == "league" and is_inside_tree():
		# bot vừa tăng điểm: đọc lại BXH
		_fill.call_deferred()


func _open(path: String, args: Dictionary) -> Node:
	Sfx.play("button")
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
	_act("play" if bool(Game.lives_view().get("can_play", true)) else "no_lives")


func _act(action: String) -> void:
	Sfx.play("button")
	closed.emit({"action": action})


func _on_tab(tab_name: String) -> void:
	if tab_name != "ranking":
		_act(tab_name)


func on_back() -> void:
	_act("home")
