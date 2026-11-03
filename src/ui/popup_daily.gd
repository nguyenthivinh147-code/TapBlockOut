extends Control
## Popup quà 28 ngày: chỉ mở khi người chơi bấm. Hiện 7 ô của tuần đang đi.
## setup(args: Dictionary); signal closed(result) với result = {claimed: bool, ahead: bool}.

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const PopupKit := preload("res://src/ui/popup_kit.gd")
const Config := preload("res://src/config.gd")

const COLS := 3
const CELL_SIZE := Vector2(168, 176)
const CELL_ICON := 56.0

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

	var k := PopupKit.make(self, tr("daily_title"), close)
	_content = k.card
	close_button = k.close
	var box: VBoxContainer = k.box

	box.add_child(PopupKit.text(tr("daily_week") % (int(view.week) + 1), ThemeKit.FS_SMALL, ThemeKit.INK_DIM))

	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	var cells: Array = view.cells
	for i in cells.size():
		var node := _make_cell(cells[i])
		# Ô cuối là thưởng lớn của tuần: chiếm cả hàng riêng.
		if i == cells.size() - 1:
			box.add_child(node)
		else:
			grid.add_child(node)
		cell_nodes.append(node)

	status_label = PopupKit.text("", ThemeKit.FS_SMALL, ThemeKit.BROWN)
	box.add_child(status_label)

	claim_button = ThemeKit.make_button(tr("daily_claim"), "primary")
	claim_button.pressed.connect(_on_claim)
	video_button = ThemeKit.make_button(tr("daily_video"), "video")
	video_button.add_theme_font_size_override("font_size", ThemeKit.FS_SMALL + 2)
	video_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	video_button.pressed.connect(_on_video)
	box.add_child(claim_button)
	box.add_child(video_button)
	_info = PopupKit.text("", ThemeKit.FS_SMALL, ThemeKit.INK_DIM)
	box.add_child(_info)
	_refresh_buttons(view)


func _centered(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _make_cell(cell: Dictionary) -> Control:
	var state := str(cell.state)
	var fill := ThemeKit.WELL
	var border := Color(0, 0, 0, 0)
	match state:
		"current":
			fill = ThemeKit.WELL_HOT
			border = ThemeKit.WELL_HEADER
		"claimed":
			fill = ThemeKit.WELL.darkened(0.08)
			border = ThemeKit.WELL_TODAY
		"next":
			border = ThemeKit.VIDEO
	var p := ThemeKit.make_well(fill, border)
	p.custom_minimum_size = CELL_SIZE
	p.name = "Cell%d" % int(cell.day)
	p.set_meta("state", state)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	v.add_child(_centered(ThemeKit.ink_label(tr("daily_day") % int(cell.day), ThemeKit.FS_SMALL, ThemeKit.BROWN)))
	v.add_child(ThemeKit.make_icon(_reward_icon(cell.reward), CELL_ICON))
	var rw := ThemeKit.ink_label(reward_text(cell.reward), ThemeKit.FS_SMALL - 2)
	rw.name = "Reward"
	rw.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rw.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rw.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rw.custom_minimum_size = Vector2(130, 0)
	v.add_child(rw)
	var st := ""
	match state:
		"claimed":
			st = tr("daily_claimed")
		"current":
			st = tr("daily_today")
	var sl := ThemeKit.ink_label(st, ThemeKit.FS_SMALL - 2, ThemeKit.BROWN if state == "current" else ThemeKit.INK_GOOD)
	sl.name = "State"
	v.add_child(_centered(sl))
	return p


## Icon đại diện của ô quà: món đầu tiên trong thưởng.
func _reward_icon(reward: Dictionary) -> String:
	if int(reward.get("coins", 0)) > 0:
		return "ui_gold"
	var items: Dictionary = reward.get("items", {})
	for k in ["hint", "move", "smash"]:
		if items.has(k):
			return "booster_" + k
	return "ui_gift"


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
