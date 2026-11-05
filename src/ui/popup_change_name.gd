extends Control
## Wireframe 10.2 Change Name on PopupEditNameLayer (color-cube-match-puzzle): rules label, the TMP_InputField (a
## LineEdit in its Text Area, styled like its Text and Placeholder), SaveButton as OK, closeButtons close. BuyButton
## stays inactive: renaming is free. OK or Enter saves through Game.set_profile_name; a rejected name keeps the popup
## open and shows the PopupFeedBack toast, as Unity's ShowPopupFeedBackLayer does.
## setup(args): args.name fills the field (default: the saved nickname, empty shows the Placeholder).
## closed({"action": "ok", "name": String}) after a save; closed({"action": "close"}) on X, the dim or Back.

signal closed(result: Variant)

const UnityUI := preload("res://src/ui/unity_ui.gd")
const Config := preload("res://src/config.gd")

const LAYER := "PopupEditNameLayer"
const INPUT := "Panel/ProfileMenu/PlayerInfo/InputField (TMP)"
## Game.set_profile_name error -> toast text key.
const ERRORS := {"length": "profile_name_invalid", "chars": "profile_name_invalid", "banned": "profile_name_banned"}

var ui: RefCounted = null
var name_input: LineEdit = null
var save_button: Button = null
## Text of the last toast, "" before any.
var toast_text: String = ""

var _toast: RefCounted = null
var _built: bool = false
var _done: bool = false


func _ready() -> void:
	# Profile calls setup(args) right after add_child; build here only when nobody does.
	setup.call_deferred()


func setup(args: Dictionary = {}) -> void:
	if _built:
		return
	_built = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build(str(args.get("name", Game.profile_name())))


func _unhandled_input(event: InputEvent) -> void:
	if _built and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _build(current: String) -> void:
	ui = UnityUI.build(self, LAYER)
	ui.text("Panel/ProfileMenu/Image/txtHeader", tr("profile_name_title"))
	ui.text("Panel/ProfileMenu/PlayerInfo/Label", tr("profile_name_rules"))
	ui.text("Panel/ProfileMenu/SaveButton/Text (TMP)", tr("common_ok"))
	save_button = ui.on_click("Panel/ProfileMenu/SaveButton", _save)
	for b in ui.field("closeButtons", "PopupEditNameUICoreLayer"):
		(b as Button).connect("clicked", _close)
	ui.text(INPUT + "/Text Area/Placeholder", tr("profile_nickname"))
	name_input = ui.input(INPUT) as LineEdit
	name_input.name = "NameInput"
	name_input.max_length = Config.NAME_MAX
	name_input.text_submitted.connect(func(_t: String) -> void: _save())
	ui.input_text(INPUT, current)


func _save() -> void:
	if _done:
		return
	var err: String = Game.set_profile_name(name_input.text)
	if err != "":
		_show_toast(tr(str(ERRORS.get(err, "profile_name_invalid"))))
		return
	_done = true
	closed.emit({"action": "ok", "name": Game.profile_name()})


func _close() -> void:
	if _done:
		return
	_done = true
	closed.emit({"action": "close"})


## PopupFeedbackUICoreLayer.SetupData with a content only: the title label carries it, the content label hides;
## AnimFadeInFadeOut fades the layer in while the panel scales 0 -> 1, holds, then fades out. A new toast replaces
## the one still showing.
func _show_toast(content: String) -> void:
	toast_text = content
	if _toast != null and is_instance_valid(_toast.canvas):
		var old: Control = _toast.canvas
		remove_child(old)
		old.queue_free()
	_toast = UnityUI.build(self, "PopupFeedBack")
	var toast: RefCounted = _toast
	toast.show("Panel/Text (TMP) (1)", false)
	toast.text("Panel/Text (TMP)", content)
	toast.relayout("Panel")
	var cs: Dictionary = {}
	for e in toast.scripts:
		if str(e.cs.get("name", "")) == "PopupFeedbackUICoreLayer":
			cs = e.cs
	var fade := float(cs.get("fadeDuration", 0.5))
	var hold := float(cs.get("showDuration", 2.0))
	var layer: Control = toast.root
	var panel: Control = toast.node("Panel")
	# The toast only informs: taps reach the field and buttons under it.
	for c in toast.canvas.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	(toast.canvas as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.modulate.a = 0.0
	panel.scale = Vector2.ZERO
	var tw := layer.create_tween()
	tw.tween_property(layer, "modulate:a", 1.0, fade)
	tw.parallel().tween_property(panel, "scale", Vector2.ONE, fade)
	tw.tween_interval(hold)
	tw.tween_property(layer, "modulate:a", 0.0, fade)
	tw.tween_callback(func() -> void: layer.visible = false)
