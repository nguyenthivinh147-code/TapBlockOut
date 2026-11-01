extends Control
## Hồ sơ: lưới avatar và frame. Chọn món đã có để đeo; món chưa có hiện giá gold và nút video.
## Chỉ gọi Game và Sfx. closed({"action": "back"}) khi quay lại.

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const Config := preload("res://src/config.gd")

const COLUMNS := 2
const AVATAR_PX := 150
const CELL_FONT := 26

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

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	margin.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	col.add_child(head)
	back_btn = ThemeKit.make_button(tr("common_back"), "secondary")
	back_btn.name = "BackButton"
	back_btn.add_theme_font_size_override("font_size", CELL_FONT)
	back_btn.pressed.connect(_close)
	head.add_child(back_btn)
	var title := ThemeKit.make_label(tr("profile_title"), ThemeKit.FS_TITLE)
	title.name = "Title"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(title)
	var gold_chip := ThemeKit.make_panel()
	head.add_child(gold_chip)
	var gold_row := HBoxContainer.new()
	gold_row.add_theme_constant_override("separation", 8)
	gold_chip.add_child(gold_row)
	var gi := TextureRect.new()
	gi.texture = ThemeKit.icon("ui_gold")
	gi.custom_minimum_size = Vector2(40, 40)
	gi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gold_row.add_child(gi)
	gold_label = ThemeKit.make_label("0", ThemeKit.FS_BODY, ThemeKit.GOLD)
	gold_label.name = "GoldLabel"
	gold_row.add_child(gold_label)

	_preview_holder = CenterContainer.new()
	col.add_child(_preview_holder)
	level_label = ThemeKit.make_label("", ThemeKit.FS_BODY, ThemeKit.TEXT_DIM)
	level_label.name = "LevelLabel"
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(level_label)
	status_label = ThemeKit.make_label("", CELL_FONT, ThemeKit.DANGER)
	status_label.name = "StatusLabel"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.custom_minimum_size.y = 32
	col.add_child(status_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	scroll.add_child(body)
	body.add_child(ThemeKit.make_label(tr("profile_avatars"), ThemeKit.FS_BODY, ThemeKit.GOLD))
	_avatar_grid = _make_grid()
	body.add_child(_avatar_grid)
	body.add_child(ThemeKit.make_label(tr("profile_frames"), ThemeKit.FS_BODY, ThemeKit.GOLD))
	_frame_grid = _make_grid()
	body.add_child(_frame_grid)


func _make_grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = COLUMNS
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
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
	preview = make_avatar(av_id, fr_id, 200)
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
	var panel := ThemeKit.make_panel()
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
	var cap := ThemeKit.make_label(tr("profile_default") if id.ends_with("_00") else "", ThemeKit.FS_SMALL, ThemeKit.TEXT_DIM)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.custom_minimum_size.y = 28
	v.add_child(cap)
	var entry := {"panel": panel, "equip": null, "buy": null, "video": null}
	if owned:
		var b := ThemeKit.make_button(tr("profile_equipped") if equipped else tr("profile_equip"), "secondary" if equipped else "primary")
		b.add_theme_font_size_override("font_size", CELL_FONT)
		b.disabled = equipped
		b.pressed.connect(_on_equip.bind(id))
		v.add_child(b)
		entry["equip"] = b
	else:
		var buy := ThemeKit.make_button(tr("profile_buy") % Config.cosmetic_price(id), "primary")
		buy.add_theme_font_size_override("font_size", CELL_FONT)
		buy.pressed.connect(_on_buy.bind(id))
		v.add_child(buy)
		var vid := ThemeKit.make_button(tr("ads_watch"), "video")
		vid.add_theme_font_size_override("font_size", CELL_FONT)
		vid.icon = ThemeKit.icon("ui_video")
		vid.expand_icon = true
		vid.pressed.connect(_on_video.bind(id))
		v.add_child(vid)
		entry["buy"] = buy
		entry["video"] = vid
	cells[id] = entry
	return panel


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
