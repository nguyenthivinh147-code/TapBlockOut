extends Control
## In-level settings (wireframe 3.5) on SettingInGameLayer of color-cube-match-puzzle: sound effects, vibration and
## music icons in the cream well, Home (red) and Retry (green) in the button row, version under the popup.
## setup({"life_cost": bool}): true shows the -1 heart on Home (GameplaySettingsUI.removeHeartUI) and on Retry (a copy
## of Home's heart; the game also costs a life on retry). No Support row: like SettingInGameLayer, support is only in
## Settings. Static nodes are in scenes/popup_ingame_settings.tscn. closed("home" | "retry"); X, the dim and Back
## emit null. Level goes on through its life-loss confirm.

signal closed(result: Variant)

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UView := preload("res://src/ui/u_view.gd")
const Config := preload("res://src/config.gd")
const Settings := preload("res://src/ui/settings.gd")

const LAYER := "SettingInGameLayer"
const CONTENT := "Panel/PauseMenu/Content"
const WELL := "Panel/PauseMenu/Content/SettingBtn/Content"
const GROUP := "Panel/PauseMenu/Content/ButtonGroup"
## Game setting -> prefab icon button and its ImageStateKeeper sprites (UI_Maincenter_<on>, _<off>).
const TOGGLES: Array[Dictionary] = [
	{"key": "sfx", "node": "Mute", "on": 28, "off": 29},
	{"key": "haptics", "node": "Vibrate", "on": 40, "off": 41},
	{"key": "music", "node": "Sound", "on": 42, "off": 43},
]

var ui: UView = null
var toggle_buttons: Dictionary = {}
var home_button: Button = null
var retry_button: Button = null

var _life_cost: bool = false
## Màn đặc biệt không có Chơi lại ({"no_retry": true}): nút Retry ẩn.
var _no_retry: bool = false
var _built: bool = false


func setup(args: Dictionary = {}) -> void:
	_life_cost = bool(args.get("life_cost", false))
	_no_retry = bool(args.get("no_retry", false))
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# The hidden Language pill and the Retry heart are in scenes/popup_ingame_settings.tscn. Layer nodes
	# keep their prefab names there (a renamed instanced node loses its overrides): renamed here.
	ui = UnityUI.build(self, LAYER)
	ui.text("Panel/PauseMenu/Image/txtHeader", tr("settings_title"))
	ui.text("VersionText", str(Config.CONTENT.build))
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
	retry_button.visible = not _no_retry
	_badges()


## -1 heart on Home (prefab node) and Retry (LifeBadge, a copy at the same corner in the scene); the Home heart is
## named LifeBadge only while shown, the copy is removed without the cost.
func _badges() -> void:
	var heart := ui.node(GROUP + "/HomeButton/Image")
	heart.visible = _life_cost
	var copy := retry_button.get_node("LifeBadge")
	if not _life_cost:
		retry_button.remove_child(copy)
		copy.queue_free()
		return
	heart.name = "LifeBadge"


func _show_toggle(key: String) -> void:
	var on := bool(Game.s.settings.get(key, true))
	for def in TOGGLES:
		if str(def.key) == key:
			Settings.set_state_sprite((toggle_buttons[key] as Control).get_node("Image"), int(def.on) if on else int(def.off))


func _on_toggle(key: String) -> void:
	Game.set_setting(key, not bool(Game.s.settings.get(key, true)))
	_show_toggle(key)


func _finish(result: Variant) -> void:
	closed.emit(result)
