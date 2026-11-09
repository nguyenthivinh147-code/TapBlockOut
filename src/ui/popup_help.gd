extends "res://src/ui/stub_ui.gd"
## Wireframe 10.5 Help & Support. Unity has no help form: CustomerSupportButton opens an e-mail and PopupFeedBack
## is only a timed toast (see popup_change_name.gd). The form is therefore PopupEditNameLayer
## (color-cube-match-puzzle), Unity's popup with a label, a TMP_InputField and a button: the label is the game's
## subtitle, the three topics are copies of the input field art (text + check) spaced like the prefab's label and
## field, the field itself moves below them and grows to two field heights as the message box (a TextEdit in its
## Text Area), the note is a copy of the label under it, SaveButton sends. The panel grows by that content; the
## well, header and button keep their prefab anchors. Topics, note, the moved field and the grown panel are nodes of
## scenes/popup_help.tscn; the script sets the texts, the message box and the buttons.
## Settings opens it from Support. A tap on a topic row selects it (its check shows; Bug first); Send closes with
## closed({"action": "send", "topic": <key>, "message": <text>}) and Settings opens a mail to support with the topic
## and the message. X and the dim close ({"action": "close"}).

const UnityUI := preload("res://src/ui/unity_ui.gd")

const LAYER := "PopupEditNameLayer"
const MENU := "Panel/ProfileMenu"
const WELL := MENU + "/PlayerInfo"
const FIELD := WELL + "/InputField (TMP)"
## Topic label key -> row Topic_<suffix> in the scene.
const TOPICS: Array[String] = ["settings_help_bug", "settings_help_purchase", "settings_help_idea"]

var message: TextEdit = null
## Key of the picked topic (TOPICS).
var topic: String = ""


func _build() -> void:
	ui = UnityUI.build(self, LAYER)
	ui.text(MENU + "/Image/txtHeader", tr("settings_help_title"))
	ui.text(WELL + "/Label", tr("settings_help_sub"))
	ui.text(MENU + "/SaveButton/Text (TMP)", tr("settings_help_send"))
	ui.on_click(MENU + "/SaveButton", _on_send)
	for b in ui.field("closeButtons", "PopupEditNameUICoreLayer"):
		(b as Button).connect("clicked", _send.bind("close"))
	for key in TOPICS:
		var row := get_node("%Topic_" + key.trim_prefix("settings_help_")) as Control
		UnityUI.set_text(row.get_node("Label") as Label, tr(key))
		# The row is art only: a clear button over it picks the topic (96 high at least, like every button).
		var hit := Button.new()
		hit.name = "Pick"
		hit.flat = true
		hit.focus_mode = Control.FOCUS_NONE
		hit.set_anchors_preset(Control.PRESET_FULL_RECT)
		hit.custom_minimum_size = Vector2(96, 96)
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			hit.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		hit.pressed.connect(_pick.bind(key))
		row.add_child(hit)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
	_pick(TOPICS[0], false)
	UnityUI.set_text(%Note, tr("settings_help_note"))
	_message_box()


## TMP_InputField, multi line here: unity_ui.gd swaps the prefab's LineEdit for a TextEdit; the Placeholder shows
## while it is empty.
func _message_box() -> void:
	ui.text(FIELD + "/Text Area/Placeholder", tr("settings_help_placeholder"))
	message = UnityUI.input_field(ui, ui.node(FIELD), true) as TextEdit
	message.name = "Message"


## The picked topic's check shows, the others hide.
func _pick(key: String, sound: bool = true) -> void:
	topic = key
	for k in TOPICS:
		var row := get_node("%Topic_" + k.trim_prefix("settings_help_")) as Control
		(row.get_node("Sprite") as Control).visible = k == key
	if sound:
		Sfx.play("button")


func _on_send() -> void:
	closed.emit({"action": "send", "topic": topic, "message": message.text.strip_edges() if message != null else ""})
