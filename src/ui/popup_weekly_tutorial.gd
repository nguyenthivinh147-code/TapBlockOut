extends Control
## Popup "How to earn rewards" của Weekly Pass: key theo độ khó, cách nhận thưởng, quyền lợi VIP.
## Mở sau tutorial hoặc bằng nút "i" / biểu tượng chìa trong layer. setup(args); signal closed({}).

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const Config := preload("res://src/config.gd")

var ok_button: Button = null
var rows: Array[Control] = []

var _content: Control = null
var _closed: bool = false


func setup(_args: Dictionary = {}) -> void:
	if _content == null:
		_build()


func _ready() -> void:
	if _content == null:
		_build()
	ThemeKit.popup_in.call_deferred(_content)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := ThemeKit.make_panel()
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)
	_content = panel

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)
	var title := ThemeKit.make_label(tr("weekly_howto_title"), ThemeKit.FS_TITLE, ThemeKit.GOLD)
	title.name = "TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(title)

	var cfg: Dictionary = Config.WEEKLY
	for r in [
		["weekly_howto_normal", int(cfg.get("points_normal", 1))],
		["weekly_howto_hard", int(cfg.get("points_hard", 3))],
		["weekly_howto_very_hard", int(cfg.get("points_very_hard", 5))],
	]:
		var row := _key_row(tr(r[0]), int(r[1]))
		rows.append(row)
		v.add_child(row)

	v.add_child(_note(tr("weekly_howto_claim")))
	v.add_child(_note(tr("weekly_howto_vip") % int(cfg.get("vip_bonus_hearts", 3))))
	v.add_child(_note(tr("weekly_howto_season")))

	ok_button = ThemeKit.make_button(tr("common_ok"), "primary")
	ok_button.name = "OkButton"
	ok_button.pressed.connect(close)
	v.add_child(ok_button)


func _key_row(text: String, points: int) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var l := ThemeKit.make_label(text, ThemeKit.FS_BODY)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(l)
	var n := ThemeKit.make_label(tr("weekly_howto_points") % points, ThemeKit.FS_BUTTON, ThemeKit.GOLD)
	n.name = "Points"
	h.add_child(n)
	var icon := TextureRect.new()
	icon.texture = ThemeKit.icon("mech_key")
	icon.custom_minimum_size = Vector2(56, 56)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(icon)
	return h


func _note(text: String) -> Label:
	var l := ThemeKit.make_label(text, ThemeKit.FS_SMALL, ThemeKit.TEXT_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func close() -> void:
	if _closed:
		return
	_closed = true
	closed.emit({})
