extends Control
## Popup "How to earn rewards" của Weekly Pass: key theo độ khó, cách nhận thưởng, quyền lợi VIP.
## Mở sau tutorial hoặc bằng nút "i" / biểu tượng chìa trong layer. setup(args); signal closed({}).

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const PopupKit := preload("res://src/ui/popup_kit.gd")
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
	var k := PopupKit.make(self, tr("weekly_howto_title"), Callable(), {"separation": 14})
	_content = k.card
	var v: VBoxContainer = k.box

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
	var well := ThemeKit.make_well()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	well.add_child(h)
	var l := ThemeKit.ink_label(text, ThemeKit.FS_SMALL + 4)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(l)
	var n := ThemeKit.gold_label(tr("weekly_howto_points") % points, ThemeKit.FS_BUTTON)
	n.name = "Points"
	h.add_child(n)
	h.add_child(ThemeKit.make_icon("mech_key", 56))
	return well


func _note(text: String) -> Label:
	var l := PopupKit.text(text, ThemeKit.FS_SMALL, ThemeKit.INK_DIM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return l


func close() -> void:
	if _closed:
		return
	_closed = true
	closed.emit({})
