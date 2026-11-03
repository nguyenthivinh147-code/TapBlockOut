extends Control
## Wireframe 8.2 How it works: luật leaderboard (khối ngôi sao -> mảnh -> điểm -> lên league). closed(null).

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const PopupKit := preload("res://src/ui/popup_kit.gd")
const STEPS := 4

var _built: bool = false


func setup(_args: Dictionary = {}) -> void:
	if _built:
		return
	_built = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var k := PopupKit.make(self, tr("lb_howto_title"), _close)
	var box: VBoxContainer = k.box
	for i in STEPS:
		box.add_child(_step_row(i + 1, tr("lb_howto_%d" % (i + 1))))
	var ok := ThemeKit.make_button(tr("mech_got_it"), "primary")
	ok.name = "OkButton"
	ok.pressed.connect(_close)
	box.add_child(ok)
	PopupKit.show_in(k)


func _ready() -> void:
	setup.call_deferred()


func _step_row(n: int, content: String) -> Control:
	var well := ThemeKit.make_well()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	well.add_child(h)
	if n == 1:
		h.add_child(ThemeKit.make_icon("lb_piece", 52))
	else:
		var num := ThemeKit.gold_label(str(n), ThemeKit.FS_BUTTON)
		num.custom_minimum_size.x = 52
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(num)
	var l := ThemeKit.ink_label(content, ThemeKit.FS_SMALL + 2)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(l)
	return well


func _close() -> void:
	Sfx.play("button")
	closed.emit(null)
