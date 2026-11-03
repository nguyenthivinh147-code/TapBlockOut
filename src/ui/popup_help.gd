extends "res://src/ui/stub_ui.gd"
## Wireframe 10.5 Help & Support. Unity has no help form: CustomerSupportButton opens an e-mail and PopupFeedBack
## is only a timed toast (see popup_change_name.gd). The form is therefore PopupEditNameLayer
## (color-cube-match-puzzle), Unity's popup with a label, a TMP_InputField and a button: the label is the game's
## subtitle, the three topics are copies of the input field art (text + check) spaced like the prefab's label and
## field, the field itself moves below them and grows to two field heights as the message box (a TextEdit in its
## Text Area), the note is a copy of the label under it, SaveButton sends. The panel grows by that content; the
## well, header and button keep their prefab anchors. Topics, note, the moved field and the grown panel are nodes of
## scenes/popup_help.tscn; the script sets the texts, the message box and the buttons. Not wired to logic.

const UnityUI := preload("res://src/ui/unity_ui.gd")

const LAYER := "PopupEditNameLayer"
const MENU := "Panel/ProfileMenu"
const WELL := MENU + "/PlayerInfo"
const FIELD := WELL + "/InputField (TMP)"
## Topic label key -> row Topic_<suffix> in the scene.
const TOPICS: Array[String] = ["settings_help_bug", "settings_help_purchase", "settings_help_idea"]

var message: TextEdit = null


func _build() -> void:
	ui = UnityUI.build(self, LAYER)
	ui.text(MENU + "/Image/txtHeader", tr("settings_help_title"))
	ui.text(WELL + "/Label", tr("settings_help_sub"))
	ui.text(MENU + "/SaveButton/Text (TMP)", tr("settings_help_send"))
	ui.on_click(MENU + "/SaveButton", _send.bind("send"))
	for b in ui.field("closeButtons", "PopupEditNameUICoreLayer"):
		(b as Button).connect("clicked", _send.bind("close"))
	for key in TOPICS:
		var row := get_node("%Topic_" + key.trim_prefix("settings_help_"))
		UnityUI.set_text(row.get_node("Label") as Label, tr(key))
	UnityUI.set_text(%Note, tr("settings_help_note"))
	_message_box()


## TMP_InputField, multi line here: unity_ui.gd swaps the prefab's LineEdit for a TextEdit; the Placeholder shows
## while it is empty.
func _message_box() -> void:
	ui.text(FIELD + "/Text Area/Placeholder", tr("settings_help_placeholder"))
	message = UnityUI.input_field(ui, ui.node(FIELD), true) as TextEdit
	message.name = "Message"
