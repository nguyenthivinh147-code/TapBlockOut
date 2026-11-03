extends Control
## In-level settings (wireframe 3.5) on SettingInGameLayer of color-cube-match-puzzle: sound effects, vibration and
## music icons in the cream well, Home (red) and Retry (green) in the button row, version under the popup.
## setup({"life_cost": bool}): true shows the -1 heart on Home (GameplaySettingsUI.removeHeartUI) and on Retry (a copy
## of Home's heart; the game also costs a life on retry). With Config.ui_preview a Help row (copy of PolicyButton) opens
## popup_help. closed("home" | "retry"); X, the dim and Back emit null. Level goes on through its life-loss confirm.

signal closed(result: Variant)

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")
const UView := preload("res://src/ui/u_view.gd")
const Config := preload("res://src/config.gd")
const Settings := preload("res://src/ui/settings.gd")

const LAYER := "SettingInGameLayer"
const PANEL := "Panel/PauseMenu"
const CONTENT := "Panel/PauseMenu/Content"
const WELL := "Panel/PauseMenu/Content/SettingBtn/Content"
const GROUP := "Panel/PauseMenu/Content/ButtonGroup"
## Game setting -> prefab icon button and its ImageStateKeeper sprites (UI_Maincenter_<on>, _<off>).
const TOGGLES: Array[Dictionary] = [
	{"key": "sfx", "node": "Mute", "on": 28, "off": 29},
	{"key": "haptics", "node": "Vibrate", "on": 40, "off": 41},
	{"key": "music", "node": "Sound", "on": 42, "off": 43},
]
const HELP := "res://scenes/popup_help.tscn"
## Help row: SettingMainMenuLayer's PolicyButton row (centre 80.9 above the bottom, 78 tall); the popup grows by one row
## and the button row keeps its distance from the top.
const ROW_Y := 80.9
const ROW_H := 78.0

var ui: UView = null
var toggle_buttons: Dictionary = {}
var home_button: Button = null
var retry_button: Button = null
var help_button: Button = null

var _life_cost: bool = false
var _built: bool = false


func setup(args: Dictionary = {}) -> void:
	_life_cost = bool(args.get("life_cost", false))
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	ui = UnityUI.build(self, LAYER)
	ui.text("Panel/PauseMenu/Image/txtHeader", tr("settings_title"))
	ui.text("VersionText", str(Config.CONTENT.build))
	ui.show(CONTENT + "/Language", false)
	var x := ui.on_click("Panel/PauseMenu/Top/btnTurnOff", _finish.bind(null))
	x.name = "CloseX"
	ui.on_click("Bg", _finish.bind(null))
	for def in TOGGLES:
		var key := str(def.key)
		var b := ui.button(WELL + "/" + str(def.node))
		b.name = "Toggle_" + key
		b.connect("clicked", _on_toggle.bind(key))
		toggle_buttons[key] = b
		_show_toggle(key)
	home_button = ui.on_click(GROUP + "/HomeButton", _finish.bind("home"))
	retry_button = ui.on_click(GROUP + "/RetryButton", _finish.bind("retry"))
	ui.text(GROUP + "/HomeButton/Text (TMP)", tr("level_home"))
	ui.text(GROUP + "/RetryButton/Text (TMP)", tr("level_restart"))
	_badges()
	if Config.ui_preview():
		_help_row()


## -1 heart on Home (prefab node) and Retry (copy at the same corner); named LifeBadge only while shown.
func _badges() -> void:
	var heart := ui.node(GROUP + "/HomeButton/Image")
	heart.visible = _life_cost
	if not _life_cost:
		return
	heart.name = "LifeBadge"
	var s := UnityKit.spec(LAYER, GROUP + "/HomeButton/Image")
	s.n = "LifeBadge"
	UnityKit.add(retry_button, s)


func _help_row() -> void:
	var panel := ui.node(PANEL)
	var size := UnityUI.rect_size(panel)
	UnityKit.set_size(panel, size + Vector2(0, ROW_H))
	var group := ui.node(GROUP)
	var gr: Dictionary = group.get_meta("u_rect")
	gr.pos = (gr.pos as Vector2) + Vector2(0, ROW_H * 0.5)
	UnityUI.apply_rect(group)
	var vt := ui.node("VersionText")
	var vr: Dictionary = vt.get_meta("u_rect")
	vr.pos = (vr.pos as Vector2) - Vector2(0, ROW_H * 0.5)
	UnityUI.apply_rect(vt)
	var s := UnityKit.spec("SettingMainMenuLayer", "Panel/PauseMenu/Content/PolicyButton")
	s.n = "HelpButton"
	s.r[5] = ROW_Y
	var v: RefCounted = UnityKit.add(ui.node(CONTENT), s)
	help_button = v.root as Button
	Settings.underline(v.text("Text (TMP)", tr("settings_help_title")))
	help_button.connect("clicked", _on_help)


func _show_toggle(key: String) -> void:
	var on := bool(Game.s.settings.get(key, true))
	for def in TOGGLES:
		if str(def.key) == key:
			Settings.set_state_sprite((toggle_buttons[key] as Control).get_node("Image"), int(def.on) if on else int(def.off))


func _on_toggle(key: String) -> void:
	Game.set_setting(key, not bool(Game.s.settings.get(key, true)))
	_show_toggle(key)


func _on_help() -> void:
	var node := (load(HELP) as PackedScene).instantiate()
	add_child(node)
	node.call("setup", {})
	node.connect("closed", func(_r: Variant) -> void: node.queue_free())


func _finish(result: Variant) -> void:
	closed.emit(result)
