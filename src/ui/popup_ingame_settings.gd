extends Control
## Wireframe 3.5 In-game Settings: nhạc, âm thanh, rung, Home, Retry. setup(args).
## closed("home" | "retry"); X và Back phát null. Level tự đi tiếp qua luồng xác nhận mất mạng.

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const PopupKit := preload("res://src/ui/popup_kit.gd")
const Config := preload("res://src/config.gd")

const TOGGLES: Array[Dictionary] = [
	{"key": "music", "label": "settings_music", "on": "ic_music_on", "off": "ic_music_off"},
	{"key": "sfx", "label": "settings_sound", "on": "ic_sound_on", "off": "ic_sound_off"},
	{"key": "haptics", "label": "settings_haptics", "on": "ic_vibrance_on", "off": "ic_vibrance_off"},
]
const HELP := "res://scenes/popup_help.tscn"

var toggle_buttons: Dictionary = {}
var home_button: Button = null
var retry_button: Button = null

func setup(_args: Dictionary = {}) -> void:
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	toggle_buttons.clear()
	var k := PopupKit.make(self, tr("settings_title"), _finish.bind(null))
	var box: VBoxContainer = k.box
	for def in TOGGLES:
		box.add_child(_toggle_row(def))
	if Config.ui_preview():
		var help := ThemeKit.make_button(tr("settings_help_title"), "video")
		help.name = "HelpButton"
		help.pressed.connect(_on_help)
		box.add_child(help)
	home_button = ThemeKit.make_button(tr("level_home"), "secondary")
	home_button.name = "HomeButton"
	home_button.pressed.connect(_finish.bind("home"))
	retry_button = ThemeKit.make_button(tr("level_restart"), "primary")
	retry_button.name = "RetryButton"
	retry_button.pressed.connect(_finish.bind("retry"))
	box.add_child(PopupKit.row([home_button, retry_button]))
	box.add_child(PopupKit.text(tr("settings_version") % str(Config.CONTENT.build), ThemeKit.FS_SMALL, ThemeKit.INK_DIM))
	PopupKit.show_in(k)


func _toggle_row(def: Dictionary) -> Control:
	var key := str(def.key)
	var on := bool(Game.s.settings.get(key, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(ThemeKit.make_icon(str(def.on) if on else str(def.off), 64))
	var l := ThemeKit.ink_label(tr(str(def.label)), ThemeKit.FS_SMALL + 4)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var b := ThemeKit.make_button(tr("settings_on") if on else tr("settings_off"), "primary" if on else "secondary")
	b.custom_minimum_size = Vector2(150, 96)
	b.pressed.connect(_on_toggle.bind(key))
	row.add_child(b)
	toggle_buttons[key] = b
	return row


func _on_toggle(key: String) -> void:
	Sfx.play("button")
	Game.set_setting(key, not bool(Game.s.settings.get(key, true)))
	_build()


func _on_help() -> void:
	Sfx.play("button")
	var node := (load(HELP) as PackedScene).instantiate()
	add_child(node)
	node.call("setup", {})
	node.connect("closed", func(_r: Variant) -> void: node.queue_free())


func _finish(result: Variant) -> void:
	Sfx.play("button")
	closed.emit(result)
