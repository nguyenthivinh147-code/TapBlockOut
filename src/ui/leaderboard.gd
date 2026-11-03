extends "res://src/ui/stub_ui.gd"
## Wireframe 8.1 Leaderboard: màn hub, tab Ranking. Chưa nối logic.

const HubTop := preload("res://src/ui/hub_top.gd")
const HubNav := preload("res://src/ui/hub_nav.gd")

const RANK_PX := 72
## Nền hàng hạng 1, 2, 3.
const ROW_ART := ["row_gold", "row_blue", "row_orange"]

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
	col.add_child(_zone(tr("lb_promoted"), ThemeKit.GOOD, "chevron_up"))

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

	col.add_child(_zone(tr("lb_demoted"), ThemeKit.DANGER, "chevron_down"))
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
	var badge := ThemeKit.make_icon_button("cup_" + str(view.league))
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


## Dòng phân vùng thăng hạng hoặc xuống hạng.
func _zone(content: String, color: Color, chevron: String) -> Control:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 8)
	h.add_child(ThemeKit.make_sprite(chevron, 36))
	h.add_child(ThemeKit.make_label(content, ThemeKit.FS_SMALL, color))
	return h


## Hàng xếp hạng theo component User: top 3 nền màu kèm huy chương, người chơi nền xanh, còn lại nền kem.
func _row(rank: int, title: String, sub: String, points: int, me: bool) -> Control:
	var art: String = "row_green" if me else (ROW_ART[rank - 1] if rank <= ROW_ART.size() else "row_cream")
	var light: bool = art == "row_cream"
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UiAtlas.box(art, Vector4(30, 30, 30, 34), Vector4(18, 10, 22, 14)))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	row.add_child(h)
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(RANK_PX, RANK_PX)
	h.add_child(holder)
	if rank <= 3 and not me:
		holder.add_child(ThemeKit.make_icon("medal_%d" % rank, RANK_PX))
	else:
		holder.add_child(_row_text(str(rank), ThemeKit.FS_SMALL + 4, light, ThemeKit.INK))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", -2)
	h.add_child(v)
	v.add_child(_row_text(title, ThemeKit.FS_SMALL + 2, light, ThemeKit.INK))
	v.add_child(_row_text(sub, ThemeKit.FS_SMALL - 4, light, ThemeKit.INK_DIM))
	h.add_child(ThemeKit.make_icon("cup_gold", 48))
	var pts := _row_text(str(points), ThemeKit.FS_SMALL + 4, light, ThemeKit.BROWN)
	pts.custom_minimum_size.x = 80
	pts.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(pts)
	return row


## Chữ trong hàng: chữ mực trên nền kem, chữ trắng viền tối trên nền màu.
func _row_text(content: String, size: int, light: bool, ink: Color) -> Label:
	return ThemeKit.ink_label(content, size, ink) if light else ThemeKit.make_label(content, size)


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
