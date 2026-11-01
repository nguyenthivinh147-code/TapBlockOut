extends Control
## Popup quà 28 ngày: chỉ mở khi người chơi bấm. Hiện 7 ô của tuần đang đi.
## setup(args: Dictionary); signal closed(result) với result = {claimed: bool, ahead: bool}.

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const Config := preload("res://src/config.gd")

const COLS := 4
const CELL_SIZE := Vector2(140, 200)

var claim_button: Button = null
var video_button: Button = null
var close_button: Button = null
var status_label: Label = null
var cell_nodes: Array[Control] = []
var claimed_any: bool = false
var ahead_any: bool = false

var _busy: bool = false
var _content: Control = null
var _info: Label = null


func setup(_args: Dictionary = {}) -> void:
	if _content == null:
		_build()


func _ready() -> void:
	if _content == null:
		_build()
	ThemeKit.popup_in(_content)


func _build() -> void:
	if _content != null:
		_content.queue_free()
		_content = null
	for c in get_children():
		c.queue_free()
	cell_nodes.clear()
	var view: Dictionary = Game.daily_view()

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_content = ThemeKit.make_panel()
	center.add_child(_content)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	_content.add_child(box)

	box.add_child(_centered(ThemeKit.make_label(tr("daily_title"), ThemeKit.FS_TITLE)))
	var week := ThemeKit.make_label(tr("daily_week") % (int(view.week) + 1), ThemeKit.FS_BODY, ThemeKit.TEXT_DIM)
	box.add_child(_centered(week))

	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	for cell in view.cells:
		var node := _make_cell(cell)
		grid.add_child(node)
		cell_nodes.append(node)

	status_label = ThemeKit.make_label("", ThemeKit.FS_BODY, ThemeKit.GOLD)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(580, 0)
	box.add_child(status_label)

	claim_button = ThemeKit.make_button(tr("daily_claim"), "primary")
	claim_button.pressed.connect(_on_claim)
	video_button = ThemeKit.make_button(tr("daily_video"), "video")
	video_button.pressed.connect(_on_video)
	close_button = ThemeKit.make_button(tr("common_close"), "secondary")
	close_button.pressed.connect(close)
	box.add_child(claim_button)
	box.add_child(video_button)
	var info := ThemeKit.make_label("", ThemeKit.FS_SMALL, ThemeKit.TEXT_DIM)
	_info = info
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(info)
	box.add_child(close_button)
	_refresh_buttons(view)


func _centered(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _make_cell(cell: Dictionary) -> Control:
	var state := str(cell.state)
	var p := PanelContainer.new()
	p.custom_minimum_size = CELL_SIZE
	p.name = "Cell%d" % int(cell.day)
	p.set_meta("state", state)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(4 if state == "current" else 2)
	sb.bg_color = ThemeKit.BG_TOP
	sb.border_color = ThemeKit.PANEL_BORDER
	match state:
		"current":
			sb.border_color = ThemeKit.GOLD
			sb.bg_color = ThemeKit.PANEL_BORDER
		"claimed":
			sb.bg_color = ThemeKit.GOOD.darkened(0.55)
			sb.border_color = ThemeKit.GOOD
		"next":
			sb.border_color = ThemeKit.VIDEO
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(_centered(ThemeKit.make_label(tr("daily_day") % int(cell.day), ThemeKit.FS_SMALL, ThemeKit.TEXT_DIM)))
	var rw := ThemeKit.make_label(reward_text(cell.reward), ThemeKit.FS_SMALL)
	rw.name = "Reward"
	rw.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rw.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rw.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rw.custom_minimum_size = Vector2(120, 0)
	v.add_child(rw)
	var st := ""
	match state:
		"claimed":
			st = tr("daily_claimed")
		"current":
			st = tr("daily_today")
	var sl := ThemeKit.make_label(st, ThemeKit.FS_SMALL, ThemeKit.GOLD if state == "current" else ThemeKit.GOOD)
	sl.name = "State"
	v.add_child(_centered(sl))
	return p


## "300 gold" hoặc "Hint x1"; ô nhiều món thì mỗi món một dòng.
func reward_text(reward: Dictionary) -> String:
	var lines: Array[String] = []
	var coins := int(reward.get("coins", 0))
	if coins > 0:
		lines.append(tr("daily_reward_gold") % coins)
	var items: Dictionary = reward.get("items", {})
	for k in ["hint", "move", "smash"]:
		if items.has(k):
			lines.append(tr("daily_reward_item") % [tr("booster_%s" % k), int(items[k])])
	return "\n".join(lines)


func _refresh_buttons(view: Dictionary) -> void:
	var is_open := bool(view.open)
	var can_claim := bool(view.can_claim)
	var can_next := bool(view.can_ad_next)
	claim_button.visible = is_open and can_claim
	claim_button.disabled = _busy
	video_button.visible = is_open and not can_claim and can_next
	video_button.disabled = _busy
	if video_button.visible:
		Game.offer_video("daily_next")
	if not is_open:
		_info.text = tr("common_locked_level") % int(Config.UNLOCK.get("daily_gift", 0))
	elif can_claim:
		_info.text = ""
	elif can_next:
		_info.text = tr("daily_come_back")
	else:
		_info.text = "%s\n%s" % [tr("daily_come_back"), tr("daily_video_used")]


func _fail_text() -> String:
	match Game.last_ad_reason:
		"not_ready":
			return tr("ads_not_available")
		"closed":
			return tr("ads_closed_early")
	return tr("ads_failed")


func _on_claim() -> void:
	if _busy:
		return
	_busy = true
	Sfx.play("sfx_button")
	var reward: Dictionary = Game.daily_claim()
	_busy = false
	if reward.is_empty():
		status_label.text = ""
	else:
		claimed_any = true
		Sfx.play("sfx_coin")
		status_label.text = tr("daily_reward_received")
	_rebuild_keep_status()


func _on_video() -> void:
	if _busy:
		return
	_busy = true
	Sfx.play("sfx_button")
	_refresh_buttons(Game.daily_view())
	var reward: Dictionary = await Game.daily_claim_next()
	_busy = false
	if not is_inside_tree():
		return
	if reward.is_empty():
		status_label.text = _fail_text()
		_refresh_buttons(Game.daily_view())
		return
	claimed_any = true
	ahead_any = true
	Sfx.play("sfx_coin")
	status_label.text = tr("daily_reward_received")
	_rebuild_keep_status()


func _rebuild_keep_status() -> void:
	var text := status_label.text
	_build()
	status_label.text = text


func close() -> void:
	Sfx.play("sfx_button")
	closed.emit({"claimed": claimed_any, "ahead": ahead_any})
