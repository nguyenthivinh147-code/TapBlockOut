extends "res://src/ui/stub_ui.gd"
## Wireframe 10.5 Help & Support. Unity has no help form: CustomerSupportButton opens an e-mail and PopupFeedBack
## is only a timed toast (see popup_change_name.gd). The form is therefore PopupEditNameLayer
## (color-cube-match-puzzle), Unity's popup with a label, a TMP_InputField and a button: the label is the game's
## subtitle, the three topics are copies of the input field art (text + check) spaced like the prefab's label and
## field, the field itself moves below them and grows to two field heights as the message box (a TextEdit in its
## Text Area), the note is a copy of the label under it, SaveButton sends. The panel grows by that content; the
## well, header and button keep their prefab anchors. Not wired to logic.

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")

const LAYER := "PopupEditNameLayer"
const MENU := "Panel/ProfileMenu"
const WELL := MENU + "/PlayerInfo"
const FIELD := WELL + "/InputField (TMP)"
const TOPICS: Array[String] = ["settings_help_bug", "settings_help_purchase", "settings_help_idea"]
const CHECK := "Resources_moved_UI_Maincenter:UI_Maincenter_17"
## btnTurnOff art size, used for the topic checks.
const MARK := 64.0
## Gap between the prefab's label and its input field.
const GAP := 17.0
const NOTE_H := 60.0
const MESSAGE_ROWS := 2.0

var message: TextEdit = null


func _build() -> void:
	ui = UnityUI.build(self, LAYER)
	ui.text(MENU + "/Image/txtHeader", tr("settings_help_title"))
	ui.text(WELL + "/Label", tr("settings_help_sub"))
	ui.text(MENU + "/SaveButton/Text (TMP)", tr("settings_help_send"))
	ui.on_click(MENU + "/SaveButton", _send.bind("send"))
	for b in ui.field("closeButtons", "PopupEditNameUICoreLayer"):
		(b as Button).connect("clicked", _send.bind("close"))
	_layout()
	_message_box()


## Topics take the field's slot one after another; the message box and the note follow. Distances are from the
## well's top edge (the label and field are anchored there); the panel grows so the well's bottom margin stays.
func _layout() -> void:
	var field: Control = ui.node(FIELD)
	var fr: Dictionary = field.get_meta("u_rect")
	var fsize: Vector2 = fr.size
	var y := -(fr.pos as Vector2).y - fsize.y * 0.5
	var well_r: Dictionary = (ui.node(WELL) as Control).get_meta("u_rect")
	var menu: Control = ui.node(MENU)
	var menu_h: float = (menu.get_meta("u_rect") as Dictionary).size.y
	# Original well height and the space under the field inside it.
	var well_h := menu_h + (well_r.size as Vector2).y
	var bottom_pad := well_h - (y + fsize.y)
	for key in TOPICS:
		_topic(Rect2(0, y, fsize.x, fsize.y), tr(key))
		y += fsize.y + GAP
	var msg_h := fsize.y * MESSAGE_ROWS
	fr.pos = Vector2(0, -(y + msg_h * 0.5))
	fr.size = Vector2(fsize.x, msg_h)
	UnityUI.apply_rect(field)
	y += msg_h + GAP
	var note := UnityKit.spec(LAYER, WELL + "/Label")
	note.n = "Note"
	note.r = [0.5, 1, 0.5, 1, 0, -(y + NOTE_H * 0.5), fsize.x, NOTE_H, 0.5, 0.5]
	UnityKit.add(ui.node(WELL), note).text("", tr("settings_help_note"))
	y += NOTE_H + bottom_pad
	UnityKit.set_size(menu, Vector2((menu.get_meta("u_rect") as Dictionary).size.x, menu_h + (y - well_h)))


## A topic row: the input field art, its text style left-aligned in the Text Area, a check on the right.
func _topic(rect: Rect2, content: String) -> void:
	var well: Control = ui.node(WELL)
	var bg := UnityKit.spec(LAYER, FIELD)
	bg.n = "Topic"
	bg.ch = []
	bg.erase("input")
	bg.r = [0.5, 1, 0.5, 1, 0, -(rect.position.y + rect.size.y * 0.5), rect.size.x, rect.size.y, 0.5, 0.5]
	var row: Control = UnityKit.add(well, bg).root
	var area: Array = UnityKit.spec(LAYER, FIELD + "/Text Area").r
	var pad := Vector2(-float(area[6]), -float(area[7])) * 0.5
	var t := UnityKit.spec(LAYER, FIELD + "/Text Area/Text")
	t.n = "Label"
	t.txt.s = content
	t.txt.h = 1
	t.txt.auto = [18.0, float(t.txt.fs)]
	UnityKit.add(row, t, Rect2(pad.x, pad.y, rect.size.x - pad.x * 3.0 - MARK, rect.size.y - pad.y * 2.0))
	UnityKit.sprite(row, CHECK, Rect2(rect.size.x - pad.x - MARK, (rect.size.y - MARK) * 0.5, MARK, MARK))


## TMP_InputField, multi line here: unity_ui.gd swaps the prefab's LineEdit for a TextEdit; the Placeholder shows
## while it is empty.
func _message_box() -> void:
	ui.text(FIELD + "/Text Area/Placeholder", tr("settings_help_placeholder"))
	message = UnityUI.input_field(ui, ui.node(FIELD), true) as TextEdit
	message.name = "Message"
