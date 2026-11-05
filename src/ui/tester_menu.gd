extends Control
## Tester menu, opened by 10 quick taps on the version in Settings or by F1 (main.gd). No prefab: PopupOkLayer frame
## (UnityKit) in scenes/tester_menu.tscn. With Config.account_tool (debug builds) it edits the account: gold, level
## and booster counts in copies of PopupEditNameLayer's input field, Save, and Delete account (tap twice), built here.
## Mediation debugger is always there. setup(args: Dictionary); signal closed(result): null when closed,
## {"action": "changed"} after Save, {"action": "wiped"} after Delete account; the opener rebuilds its screen for both.

signal closed(result: Variant)

const UnityKit := preload("res://src/ui/unity_kit.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")
const Config := preload("res://src/config.gd")

const GROUP := "tester_menu"
## [field key, label key]; hint, move and smash are booster kinds (Game.s.inv); rt_level is the Road Trip level.
const FIELDS: Array[Array] = [
	["coins", "common_gold"],
	["level", "settings_tester_level"],
	["hint", "booster_hint"],
	["move", "booster_move"],
	["smash", "booster_smash"],
	["rt_level", "rt_title"],
]
const INPUT_LAYER := "PopupEditNameLayer"
const INPUT := "Panel/ProfileMenu/PlayerInfo/InputField (TMP)"
const FIELD_LIMIT := 9
const BAD_INK := Color("c31f1f")
## Canvas units from the panel's top-left (the 130-unit header strip on top). Debugger only: the old tester menu.
const SIZE_SMALL := Vector2(724, 360)
const DEBUG_BTN_SMALL := Rect2(222, 172, 280, 120)
const SIZE_FULL := Vector2(724, 1198)
const WELL_RECT := Rect2(40, 150, 644, 690)
const ROW_Y := 170.0
const ROW_H := 110.0
const LABEL_RECT := Rect2(76, 0, 250, 94)
const FIELD_RECT := Rect2(334, 0, 320, 94)
const SAVE_BTN := Rect2(64, 870, 280, 120)
const WIPE_BTN := Rect2(380, 870, 280, 120)
const DEBUG_BTN := Rect2(222, 1010, 280, 120)

var ui: RefCounted = null
## Field key -> LineEdit.
var fields: Dictionary = {}
var save_button: Button = null
var wipe_button: Button = null
var debugger_button: Button = null

var _built: bool = false
## Text colour of the prefab's input field (BAD_INK while a field is invalid).
var _ink: Color = Color.WHITE
var _wipe_armed: bool = false
var _busy: bool = false


func setup(_args: Dictionary = {}) -> void:
	_build()


func _ready() -> void:
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	add_to_group(GROUP)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var account := Config.account_tool()
	# The PopupOkLayer frame (description, well and button row hidden) and DebuggerButton are in
	# scenes/tester_menu.tscn; the popup size, the button's place and the account rows follow the build.
	ui = UnityKit.frame(self, tr("settings_tester_title"), close)
	var size := SIZE_FULL if account else SIZE_SMALL
	UnityKit.set_size(ui.node("Panel"), size)
	UnityKit.set_size(ui.node("Panel/Bg"), size)
	var content: Control = ui.node("Panel/Content")
	if account:
		_build_account(content)
	debugger_button = %DebuggerButton
	# Last in Content, after the account rows, as when it was built.
	content.move_child(debugger_button, -1)
	UnityKit.place(debugger_button, DEBUG_BTN if account else DEBUG_BTN_SMALL)
	UnityUI.set_text(debugger_button.get_node("Out") as Label, tr("settings_tester_debugger"))
	debugger_button.connect("clicked", _on_debugger)


## A cream well of label + number field rows, then Save (green) and Delete account (red).
func _build_account(content: Control) -> void:
	UnityKit.well(content, WELL_RECT)
	var values := current_values()
	for i in FIELDS.size():
		var key := str(FIELDS[i][0])
		var y := ROW_Y + ROW_H * i
		UnityKit.label(content, tr(str(FIELDS[i][1])), Rect2(LABEL_RECT.position + Vector2(0, y), LABEL_RECT.size),
			40.0, UnityKit.INK, "", HORIZONTAL_ALIGNMENT_LEFT)
		var s := UnityKit.spec(INPUT_LAYER, INPUT)
		s.n = "Field_" + key
		s.input.limit = FIELD_LIMIT
		var v: RefCounted = UnityKit.add(content, s, Rect2(FIELD_RECT.position + Vector2(0, y), FIELD_RECT.size))
		v.text("Text Area/Placeholder", "0")
		var e := v.root.get_meta("u_input") as LineEdit
		e.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		e.select_all_on_focus = true
		_ink = e.get_theme_color("font_color")
		e.text_changed.connect(func(_t: String) -> void: _mark(key, true))
		UnityUI.set_input_text(e, str(values[key]))
		fields[key] = e
	save_button = UnityKit.button(content, "green", tr("settings_tester_save"), SAVE_BTN, save).root as Button
	save_button.name = "SaveButton"
	wipe_button = UnityKit.button(content, "red", tr("settings_tester_wipe"), WIPE_BTN, _on_wipe).root as Button
	wipe_button.name = "WipeButton"


func current_values() -> Dictionary:
	var s: Dictionary = Game.s
	return {"coins": int(s.coins), "level": int(s.level), "hint": int(s.inv.get("hint", 0)),
		"move": int(s.inv.get("move", 0)), "smash": int(s.inv.get("smash", 0)), "rt_level": int(s.road_trip.get("level", 1))}


## Writes every field through Game.tester_edit and closes with "changed". A field that is not a whole number
## (level: at least 1) turns red and nothing is saved.
func save() -> void:
	if _busy:
		return
	var vals := {}
	var ok := true
	for key in fields:
		var t := (fields[key] as LineEdit).text.strip_edges()
		var good := t.is_valid_int() and t.to_int() >= (1 if key == "level" or key == "rt_level" else 0)
		_mark(key, good)
		ok = ok and good
		if good:
			vals[key] = t.to_int()
	if not ok:
		return
	Game.tester_edit({"coins": vals.coins, "level": vals.level,
		"inv": {"hint": vals.hint, "move": vals.move, "smash": vals.smash}, "rt_level": vals.rt_level})
	closed.emit({"action": "changed"})


func _mark(key: String, good: bool) -> void:
	var e: LineEdit = fields.get(key)
	if e != null:
		e.add_theme_color_override("font_color", _ink if good else BAD_INK)


## First tap asks for confirmation on the button itself, the second deletes the account and closes with "wiped".
func _on_wipe() -> void:
	if _busy:
		return
	if not _wipe_armed:
		_wipe_armed = true
		_set_button_text(wipe_button, tr("settings_tester_wipe_confirm"))
		return
	_busy = true
	await Game.tester_wipe()
	_busy = false
	closed.emit({"action": "wiped"})


static func _set_button_text(b: Button, s: String) -> void:
	var l := b.find_children("*", "Label", true, false)
	if not l.is_empty():
		UnityUI.set_text(l[0] as Label, s)


func _on_debugger() -> void:
	Platform.open_debugger()


func close() -> void:
	closed.emit(null)
