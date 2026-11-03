extends Control
## Màn Daily Challenge (mở từ L50): giới thiệu thưởng, nút Chơi; chơi thật trong màn level (chế độ challenge)
## được nhúng làm con của màn này, nên thắng/thua đi qua đúng luồng cứu A/B, thẻ thắng, x2 của level thường.
## setup(args): không cần khoá nào; dữ liệu lấy từ Game.challenge_view().
## closed({"action": "home" | "no_lives"}).
## No Unity prefab (docs/UI_UNITY.md): the game background under PopupOkLayer's frame through UnityKit, laid out like
## that popup (header, cream well with the message, one button row 68 from the bottom). The well holds the game's
## calendar art above the text; the X is the way home.

signal closed(result: Variant)

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")
const UiAtlas := preload("res://src/ui/ui_atlas.gd")
const LevelScene := preload("res://scenes/level.tscn")

## PopupOkLayer, taller for the art: well inset 52 like the prefab (Content/Image size -104), button 280x120 with its
## bottom 68 above the panel's (Content/Button pos 68).
const PANEL := Vector2(724, 900)
const WELL := Rect2(52, 130, 620, 530)
const ART := Rect2(237, 160, 250, 250)
const TEXT := Rect2(100, 420, 524, 200)
const BUTTON := Vector2(280, 120)

var back_button: Button = null
var play_button: Button = null
var title_label: Label = null
var bonus_label: Label = null
var done_label: Label = null
var level_node: Control = null
## Unity view of the frame (UnityKit.popup).
var ui: RefCounted = null

var _built: bool = false
var _ui: Control = null
var _left: bool = false


func setup(_args: Dictionary = {}) -> void:
	_build()
	refresh()


func _build() -> void:
	if _built:
		return
	_built = true
	theme = ThemeKit.make_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui = Control.new()
	_ui.name = "Intro"
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui)
	_ui.add_child(ThemeKit.make_background())

	ui = UnityKit.popup(_ui, tr("challenge_title"), PANEL, _on_back_pressed)
	title_label = ui.label("Panel/Image/txtHeader")
	# The X goes home; a full screen does not close on a tap beside the frame.
	back_button = ui.button("Panel/Top/btnTurnOff")
	back_button.name = "BackButton"
	var dim: Button = ui.button("Bg")
	if dim != null and dim.is_connected("clicked", _on_back_pressed):
		dim.disconnect("clicked", _on_back_pressed)
	var panel: Control = ui.node("Panel/Content")
	UnityKit.well(panel, WELL)
	UnityKit.sprite(panel, "", ART, UiAtlas.tex("big_calendar")).name = "Calendar"
	bonus_label = UnityKit.label(panel, "", TEXT, 48)
	bonus_label.name = "BonusLabel"
	done_label = UnityKit.label(panel, tr("challenge_done"), TEXT, 48)
	done_label.name = "DoneLabel"
	var by := PANEL.y - 68.0 - BUTTON.y
	play_button = UnityKit.button(panel, "green", tr("challenge_play"), Rect2((PANEL.x - BUTTON.x) * 0.5, by, BUTTON.x, BUTTON.y)).root
	play_button.name = "PlayButton"
	play_button.connect("clicked", _on_play_pressed)


func refresh() -> void:
	if not _built:
		return
	var v: Dictionary = Game.challenge_view()
	var won := bool(v.get("won", false))
	UnityUI.set_text(bonus_label, tr("challenge_bonus") % int(v.get("coins", 0)))
	bonus_label.visible = not won
	done_label.visible = won
	play_button.visible = not won
	play_button.call("set_interactable", bool(v.get("available", false)))


func _host() -> Node:
	var n := get_parent()
	while n != null:
		if n.has_method("go") and n.has_method("open_popup"):
			return n
		n = n.get_parent()
	return null


## Back của Android: đang chơi thì như bấm Home trong level, không thì về Home.
func on_back() -> void:
	if level_node != null and is_instance_valid(level_node) and level_node.has_method("on_back"):
		level_node.call("on_back")
	elif not _left and level_node == null:
		Sfx.play("button")
		_close("home")


## The frame's X (a prefab button, it plays its own click sound).
func _on_back_pressed() -> void:
	if _left or level_node != null:
		return
	_close("home")


func _on_play_pressed() -> void:
	if level_node != null or not bool(Game.challenge_view().get("available", false)):
		return
	if not bool(Game.lives_view().get("can_play", true)):
		_close("no_lives")
		return
	var h := _host()
	if h != null and h.has_method("curtain_swap"):
		h.call("curtain_swap", _open_level)
	else:
		_open_level()


func _open_level() -> void:
	if _left or level_node != null:
		return
	_ui.visible = false
	level_node = LevelScene.instantiate() as Control
	add_child(level_node)
	level_node.connect("closed", _on_level_closed)
	level_node.call("setup", {"challenge": true})


func _on_level_closed(result: Variant) -> void:
	var action := str(result.get("action", "home")) if result is Dictionary else "home"
	if level_node != null and is_instance_valid(level_node):
		level_node.queue_free()
	level_node = null
	_close(action)


func _close(action: String) -> void:
	if _left:
		return
	_left = true
	if action == "no_lives":
		var h := _host()
		if h != null:
			h.call("go", "no_lives")
			return
	closed.emit({"action": action})
