extends "res://src/ui/stub_ui.gd"
## Wireframe 8.1 Leaderboard: màn hub, tab Ranking. Chưa nối logic.

const HubTop := preload("res://src/ui/hub_top.gd")
const HubNav := preload("res://src/ui/hub_nav.gd")

const RANK_PX := 72

func _sample() -> Dictionary:
	return SampleData.LEADERBOARD


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
	top.action.connect(_on_hub)
	col.add_child(top)
	col.add_child(_league_card())
	col.add_child(_zone(tr("lb_promoted"), ThemeKit.GOOD))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for r in view.rows:
		list.add_child(_row(int(r.rank), str(r.name), tr("profile_level") % int(r.level), int(r.points), false))

	col.add_child(_zone(tr("lb_demoted"), ThemeKit.DANGER))
	var delta := "%s %d" % ["▲" if int(view.you_delta) >= 0 else "▼", absi(int(view.you_delta))]
	col.add_child(_row(int(view.you_rank), tr("lb_you"), tr("lb_rank") % [int(view.you_rank), delta], int(view.you_points), true))

	var nav := HubNav.new("ranking")
	nav.tab.connect(_on_tab)
	page.add_child(nav)
	nav.refresh()


func _league_card() -> Control:
	var well := ThemeKit.make_well(ThemeKit.POPUP_CREAM, ThemeKit.PANEL_BORDER)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	well.add_child(h)
	var badge := ThemeKit.make_button("", "ghost")
	badge.icon = UiAtlas.tex("hex_red")
	badge.expand_icon = true
	badge.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.pressed.connect(_open.bind("popup_leagues"))
	h.add_child(badge)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	v.add_child(ThemeKit.ink_label(tr("lb_league") % tr("lb_league_" + str(view.league)), ThemeKit.FS_SMALL + 6, ThemeKit.BROWN))
	v.add_child(ThemeKit.ink_label(tr("lb_week_ends") % str(view.ends_in), ThemeKit.FS_SMALL - 2, ThemeKit.INK_DIM))
	var gift := ThemeKit.make_icon_button("ic_giftbox1")
	gift.pressed.connect(_open.bind("popup_lb_result"))
	h.add_child(gift)
	var info := ThemeKit.make_icon_button("ui_info")
	info.pressed.connect(_open.bind("popup_lb_howto"))
	h.add_child(info)
	return well


func _zone(content: String, color: Color) -> Label:
	var l := ThemeKit.make_label(content, ThemeKit.FS_SMALL, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _row(rank: int, title: String, sub: String, points: int, me: bool) -> Control:
	var well := ThemeKit.make_well(ThemeKit.WELL_HOT if me else ThemeKit.POPUP_CREAM, ThemeKit.WELL_HEADER if me else Color(0, 0, 0, 0))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	well.add_child(h)
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(RANK_PX, RANK_PX)
	h.add_child(holder)
	if rank <= 3:
		holder.add_child(ThemeKit.make_sprite(["hex_green", "hex_blue", "hex_gray"][rank - 1], RANK_PX))
	var num := ThemeKit.make_label(str(rank), ThemeKit.FS_SMALL + 2) if rank <= 3 else ThemeKit.ink_label(str(rank), ThemeKit.FS_SMALL + 2)
	var stack := Control.new()
	holder.add_child(stack)
	num.set_anchors_preset(Control.PRESET_CENTER)
	num.grow_horizontal = Control.GROW_DIRECTION_BOTH
	num.grow_vertical = Control.GROW_DIRECTION_BOTH
	stack.add_child(num)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", -2)
	h.add_child(v)
	v.add_child(ThemeKit.ink_label(title, ThemeKit.FS_SMALL + 2))
	v.add_child(ThemeKit.ink_label(sub, ThemeKit.FS_SMALL - 4, ThemeKit.INK_DIM))
	h.add_child(ThemeKit.make_icon("ui_star", 40))
	var pts := ThemeKit.ink_label(str(points), ThemeKit.FS_SMALL + 4, ThemeKit.BROWN)
	pts.custom_minimum_size.x = 80
	pts.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(pts)
	return well


func _open(scene: String) -> void:
	Sfx.play("button")
	var node := (load("res://scenes/%s.tscn" % scene) as PackedScene).instantiate()
	add_child(node)
	node.call("setup", {})
	node.connect("closed", func(_r: Variant) -> void: node.queue_free())


func _on_hub(action: String) -> void:
	_act(action)


func _on_tab(tab_name: String) -> void:
	if tab_name != "ranking":
		_act(tab_name)
