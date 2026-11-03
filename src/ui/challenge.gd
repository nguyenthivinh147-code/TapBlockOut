extends Control
## Màn Daily Challenge (mở từ L50): giới thiệu thưởng, nút Chơi; chơi thật trong màn level (chế độ challenge)
## được nhúng làm con của màn này, nên thắng/thua đi qua đúng luồng cứu A/B, thẻ thắng, x2 của level thường.
## setup(args): không cần khoá nào; dữ liệu lấy từ Game.challenge_view().
## closed({"action": "home" | "no_lives"}).

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const PopupKit := preload("res://src/ui/popup_kit.gd")
const LevelScene := preload("res://scenes/level.tscn")

var back_button: Button = null
var play_button: Button = null
var title_label: Label = null
var bonus_label: Label = null
var done_label: Label = null
var level_node: Control = null

var _built: bool = false
var _ui: Control = null
var _left: bool = false


func setup(_args: Dictionary = {}) -> void:
	_build()
	refresh()


func _label(text: String, size: int, color: Color, node_name: String) -> Label:
	return PopupKit.text(text, size, color, node_name)


func _build() -> void:
	if _built:
		return
	_built = true
	theme = ThemeKit.make_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui = Control.new()
	_ui.name = "Intro"
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_ui)
	_ui.add_child(ThemeKit.make_background())

	back_button = ThemeKit.make_button("", "icon")
	back_button.name = "BackButton"
	back_button.icon = ThemeKit.icon("ui_home")
	back_button.expand_icon = true
	back_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_button.custom_minimum_size = Vector2(96, 96)
	back_button.position = Vector2(28, 36)
	back_button.pressed.connect(_on_back_pressed)
	_ui.add_child(back_button)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(center)
	var k := PopupKit.make_card(tr("challenge_title"), Callable(), {"separation": 24})
	center.add_child(k.card)
	title_label = k.title
	var box: VBoxContainer = k.box
	box.add_child(ThemeKit.make_sprite("big_calendar", 200))
	bonus_label = _label("", ThemeKit.FS_BODY, ThemeKit.BROWN, "BonusLabel")
	box.add_child(bonus_label)
	done_label = _label(tr("challenge_done"), ThemeKit.FS_BODY, ThemeKit.INK_DIM, "DoneLabel")
	box.add_child(done_label)
	play_button = ThemeKit.make_button(tr("challenge_play"), "primary")
	play_button.name = "PlayButton"
	play_button.pressed.connect(_on_play_pressed)
	box.add_child(play_button)


func refresh() -> void:
	if not _built:
		return
	var v: Dictionary = Game.challenge_view()
	var won := bool(v.get("won", false))
	bonus_label.text = tr("challenge_bonus") % int(v.get("coins", 0))
	bonus_label.visible = not won
	done_label.visible = won
	play_button.visible = not won
	play_button.disabled = not bool(v.get("available", false))


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
	else:
		_on_back_pressed()


func _on_back_pressed() -> void:
	if _left or level_node != null:
		return
	Sfx.play("button")
	_close("home")


func _on_play_pressed() -> void:
	if level_node != null or not bool(Game.challenge_view().get("available", false)):
		return
	Sfx.play("button")
	if not bool(Game.lives_view().get("can_play", true)):
		_close("no_lives")
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
