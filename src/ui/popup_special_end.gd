extends Control
## Popup thua Màn đặc biệt (design.md mục 7 "Màn đặc biệt"), khung PopupOkLayer dựng lúc chạy. Thắng dùng thẻ thắng
## như level thường (win_card.gd, args.special), không qua popup này.
## setup({"mode": "fail" | "boom", level}): hết bước ("Thử thách thất bại") hoặc bom nổ ("Bùm!", ảnh bom tối và
## nghiêng), "Hẹn gặp lần sau!", nút "Level N" ({level}: level chính kế) và X.
## closed({"action": "level" | "close"}). Không có Chơi lại.

signal closed(result: Variant)

const UnityKit := preload("res://src/ui/unity_kit.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")

const PANEL := Vector2(724, 820)
const WELL := Rect2(52, 150, 620, 470)
const BOMB := Rect2(252, 170, 220, 220)
const BODY := Rect2(80, 410, 564, 160)
const BUTTON := Rect2(222, 660, 280, 120)

var ui: RefCounted = null
var ok_button: Control = null

var _args: Dictionary = {}
var _mode: String = "fail"
var _built: bool = false
var _closed: bool = false


func setup(args: Dictionary = {}) -> void:
	if _built:
		return
	_args = args
	_mode = str(args.get("mode", "fail"))
	_build()
	if not UnityUI.baking:
		_play.call_deferred()


func _build() -> void:
	_built = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var boom := _mode == "boom"
	ui = UnityKit.popup(self, tr("special_boom_title") if boom else tr("special_fail_title"), PANEL, _send.bind("close"))
	var content: Control = ui.node("Panel/Content")
	UnityKit.well(content, WELL)
	var bomb := UnityKit.sprite(content, "", BOMB, ThemeKit.icon("special_bomb"))
	bomb.name = "BombSprite"
	if boom:
		bomb.self_modulate = Color(0.55, 0.45, 0.5)
		bomb.pivot_offset = BOMB.size * 0.5
		bomb.rotation_degrees = -14.0
	UnityKit.label(content, tr("special_fail_body"), BODY, 40.0).name = "BodyLabel"
	var lv := int(_args.get("level", 1))
	ok_button = UnityKit.button(content, "green", tr("level_title") % lv, BUTTON, _send.bind("level")).root
	ok_button.name = "LevelButton"


func _play() -> void:
	if is_inside_tree():
		Sfx.play_or("lose", "button")


func _send(action: String) -> void:
	if _closed:
		return
	_closed = true
	Sfx.play("button")
	closed.emit({"action": action})
