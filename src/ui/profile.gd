extends Control
## Hồ sơ: lưới avatar và frame. Chọn món đã có để đeo; món chưa có hiện giá gold và nút video.
## Chỉ gọi Game và Sfx. closed({"action": "back"}) khi quay lại.

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const PopupKit := preload("res://src/ui/popup_kit.gd")
const Config := preload("res://src/config.gd")

const COLUMNS := 3
const AVATAR_PX := 130
const CELL_FONT := 22
const CARD_W := 680.0
const SCROLL_H := 760.0
const CHANGE_NAME := "res://scenes/popup_change_name.tscn"

var gold_label: Label = null
var level_label: Label = null
var status_label: Label = null
var preview: Control = null
var back_btn: Button = null
## id -> {"panel": Control, "equip": Button | null, "buy": Button | null, "video": Button | null}
var cells: Dictionary = {}

var _args: Dictionary = {}
var _built: bool = false
var _avatar_grid: GridContainer = null
var _frame_grid: GridContainer = null
var _preview_holder: CenterContainer = null
var _busy: bool = false


## Avatar có frame bao ngoài. Thiếu ảnh thật thì avatar là hình tròn placeholder, frame là vòng viền.
static func make_avatar(avatar_id: String, frame_id: String, px: int) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(px, px)
	root.size = Vector2(px, px)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := int(px * 0.08)
	var av := TextureRect.new()
	av.texture = ThemeKit.icon(avatar_id)
	av.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	av.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	av.set_anchors_preset(Control.PRESET_FULL_RECT)
	av.offset_left = pad
	av.offset_top = pad
	av.offset_right = -pad
	av.offset_bottom = -pad
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	av.name = "Avatar"
	root.add_child(av)
	var fr: Control = null
	if ThemeKit.has_real_icon(frame_id):
		var tr_rect := TextureRect.new()
		tr_rect.texture = ThemeKit.icon(frame_id)
		tr_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fr = tr_rect
	else:
		var panel := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.set_corner_radius_all(px)
		var keys := ThemeKit.BLOCK_COLORS.keys()
		var col: Color = ThemeKit.TEXT_DIM
		if not frame_id.ends_with("_00"):
			col = ThemeKit.BLOCK_COLORS[keys[absi(frame_id.hash()) % keys.size()]]
		sb.border_color = col
		sb.set_border_width_all(maxi(4, int(px * 0.05)))
		panel.add_theme_stylebox_override("panel", sb)
		fr = panel
	fr.set_anchors_preset(Control.PRESET_FULL_RECT)
	fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fr.name = "Frame"
	root.add_child(fr)
	return root


func _ready() -> void:
	_build()
	_connect_game()
	refresh()


func _exit_tree() -> void:
	if Game.coins_changed.is_connected(_on_game_changed):
		Game.coins_changed.disconnect(_on_game_changed)
	if Game.cos_changed.is_connected(_on_game_changed):
		Game.cos_changed.disconnect(_on_game_changed)


func setup(args: Dictionary) -> void:
	_args = args
	_build()
	_connect_game()
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()


func _connect_game() -> void:
	if not Game.coins_changed.is_connected(_on_game_changed):
		Game.coins_changed.connect(_on_game_changed)
	if not Game.cos_changed.is_connected(_on_game_changed):
		Game.cos_changed.connect(_on_game_changed)


func _on_game_changed(_v: Variant = null) -> void:
	refresh()


func _build() -> void:
	if _built:
		return
	_built = true
	theme = ThemeKit.make_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ThemeKit.make_background())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var k := PopupKit.make_card(tr("profile_title"), _close, {"width": CARD_W, "separation": 12})
	center.add_child(k.card)
	back_btn = k.close
	back_btn.name = "BackButton"
	var col: VBoxContainer = k.box

	# đầu card: avatar đang đeo, level, gold
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	col.add_child(head)
	_preview_holder = CenterContainer.new()
	head.add_child(_preview_holder)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 6)
	head.add_child(info)
	level_label = ThemeKit.ink_label("", ThemeKit.FS_BODY)
	level_label.name = "LevelLabel"
	info.add_child(level_label)
	var gold_row := HBoxContainer.new()
	gold_row.add_theme_constant_override("separation", 8)
	info.add_child(gold_row)
	gold_row.add_child(ThemeKit.make_icon("ui_gold", 48))
	gold_label = ThemeKit.gold_label("0", ThemeKit.FS_BODY)
	gold_label.name = "GoldLabel"
	gold_row.add_child(gold_label)
	if Config.ui_preview():
		var edit := ThemeKit.make_icon_button("ic_edit")
		edit.name = "EditNameButton"
		edit.pressed.connect(_on_edit_name)
		head.add_child(edit)

	status_label = PopupKit.text("", CELL_FONT, ThemeKit.INK_DANGER, "StatusLabel")
	status_label.custom_minimum_size.y = 32
	col.add_child(status_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, SCROLL_H)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	body.add_child(ThemeKit.ink_label(tr("profile_avatars"), ThemeKit.FS_BODY, ThemeKit.BROWN))
	_avatar_grid = _make_grid()
	body.add_child(_avatar_grid)
	body.add_child(ThemeKit.ink_label(tr("profile_frames"), ThemeKit.FS_BODY, ThemeKit.BROWN))
	_frame_grid = _make_grid()
	body.add_child(_frame_grid)
	PopupKit.show_in(k)


func _make_grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = COLUMNS
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	return g


func refresh() -> void:
	if not _built:
		return
	var cosm: Dictionary = Game.s.cos
	var av_id := str(cosm.get("avatar", "avatar_00"))
	var fr_id := str(cosm.get("frame", "frame_00"))
	gold_label.text = str(int(Game.s.coins))
	level_label.text = tr("profile_level") % int(Game.s.level)
	for c in _preview_holder.get_children():
		c.queue_free()
	preview = make_avatar(av_id, fr_id, 150)
	preview.name = "Preview"
	_preview_holder.add_child(preview)
	cells.clear()
	_fill(_avatar_grid, "avatar", av_id, fr_id)
	_fill(_frame_grid, "frame", av_id, fr_id)


func _fill(grid: GridContainer, kind: String, av_id: String, fr_id: String) -> void:
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	for id in Config.cosmetic_ids(kind):
		grid.add_child(_make_cell(str(id), kind, av_id, fr_id))


func _make_cell(id: String, kind: String, av_id: String, fr_id: String) -> Control:
	var owned: bool = (Game.s.cos.owned as Array).has(id)
	var equipped := (id == av_id) if kind == "avatar" else (id == fr_id)
	var panel := ThemeKit.make_well(ThemeKit.WELL_HOT if equipped else ThemeKit.WELL, ThemeKit.WELL_HEADER if equipped else Color(0, 0, 0, 0))
	panel.name = "Cell_" + id
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var shown_av := id if kind == "avatar" else av_id
	var shown_fr := id if kind == "frame" else fr_id
	var holder := CenterContainer.new()
	v.add_child(holder)
	holder.add_child(make_avatar(shown_av, shown_fr, AVATAR_PX))
	if id.ends_with("_00"):
		var cap := ThemeKit.ink_label(tr("profile_default"), ThemeKit.FS_SMALL - 4, ThemeKit.INK_DIM)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(cap)
	var entry := {"panel": panel, "equip": null, "buy": null, "video": null}
	if owned:
		var b := ThemeKit.make_button(tr("profile_equipped") if equipped else tr("profile_equip"), "secondary" if equipped else "primary")
		b.add_theme_font_size_override("font_size", CELL_FONT)
		ThemeKit.tighten(b)
		b.disabled = equipped
		b.pressed.connect(_on_equip.bind(id))
		v.add_child(b)
		entry["equip"] = b
	else:
		var buy := ThemeKit.make_button(tr("profile_buy") % Config.cosmetic_price(id), "primary")
		buy.add_theme_font_size_override("font_size", CELL_FONT)
		ThemeKit.tighten(buy)
		buy.pressed.connect(_on_buy.bind(id))
		v.add_child(buy)
		var vid := ThemeKit.make_button(tr("ads_watch"), "video")
		vid.add_theme_font_size_override("font_size", CELL_FONT)
		ThemeKit.tighten(vid)
		vid.pressed.connect(_on_video.bind(id))
		v.add_child(vid)
		entry["buy"] = buy
		entry["video"] = vid
	cells[id] = entry
	return panel


func _on_edit_name() -> void:
	Sfx.play("button")
	var node := (load(CHANGE_NAME) as PackedScene).instantiate()
	add_child(node)
	node.call("setup", {})
	node.connect("closed", func(_r: Variant) -> void: node.queue_free())


func _say(text: String) -> void:
	if status_label != null:
		status_label.text = text


func _on_equip(id: String) -> void:
	Sfx.play("button")
	_say("")
	Game.cos_equip(id)


func _on_buy(id: String) -> void:
	Sfx.play("button")
	if Game.cos_buy(id):
		_say("")
		Sfx.play("coin")
		Game.cos_equip(id)
	else:
		_say(tr("profile_not_enough"))


func _on_video(id: String) -> void:
	if _busy:
		return
	Sfx.play("button")
	_busy = true
	var ok: bool = await Game.cos_unlock_video(id)
	_busy = false
	if ok:
		_say("")
		Game.cos_equip(id)
	elif Game.last_ad_reason == "closed":
		_say(tr("ads_closed_early"))
	elif Game.last_ad_reason == "error":
		_say(tr("ads_failed"))
	else:
		_say(tr("ads_not_available"))


func _close() -> void:
	Sfx.play("button")
	closed.emit({"action": "back"})
