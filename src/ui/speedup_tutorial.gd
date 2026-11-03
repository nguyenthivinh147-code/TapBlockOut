extends "res://src/ui/stub_ui.gd"
## Wireframe 3.11 Speed-up Tutorial: giữ để tăng tốc. Bố cục SpeedUpTutorialLayer (color-cube-match-puzzle): khung lời
## dặn ở dưới (tiêu đề và mô tả là hai nửa của ô chữ prefab), bàn tay nhấp (Animator TutController_Step1) chỉ vào ô
## TargetButton ở góc trên, ô đó ghi "Giữ". Chạm ô đó hoặc chỗ bất kỳ thì đóng như wireframe. Chưa nối logic.

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")

const TEXT := "Panel/Canvas/Text (TMP)"
const TARGET := "GameObject/Step1/Hand/TargetButton"


func _build() -> void:
	ui = UnityUI.build(self, "SpeedUpTutorialLayer")
	ui.text(TEXT, tr("level_speed_body"))
	_set_rect(ui.node(TEXT), [0, 0, 1, 0.5, 0, 10, -40, -12, 0.5, 0.5])
	var title := UnityKit.spec("SpeedUpTutorialLayer", TEXT)
	title.n = "TitleText"
	title.r = [0, 0.5, 1, 1, 0, -6, -40, -12, 0.5, 0.5]
	title.txt.s = tr("level_speed_title")
	title.txt.fs = 52.0
	title.txt.auto = [18.0, 52.0]
	title.txt.st = 1
	UnityKit.add(ui.node("Panel/Canvas"), title)
	var hold := UnityKit.spec("SpeedUpTutorialLayer", TEXT)
	hold.n = "HoldText"
	# Left of the hand sprite (HandSprite spans x -231..-46 of Hand; TargetButton centre is at x -74).
	hold.r = [0.5, 0.5, 0.5, 0.5, -256, 0, 180, 90, 0.5, 0.5]
	hold.txt.s = tr("level_speed_hold")
	hold.txt.fs = 56.0
	hold.txt.auto = [18.0, 56.0]
	hold.txt.c = "ffffffff"
	hold.txt.mat = "Baloo Outline - Blue 1"
	UnityKit.add(ui.node(TARGET), hold)
	ui.on_click(TARGET, _send.bind("tap"))


static func _set_rect(c: Control, r: Array) -> void:
	c.set_meta("u_rect", {"amin": Vector2(r[0], r[1]), "amax": Vector2(r[2], r[3]), "pos": Vector2(r[4], r[5]),
		"size": Vector2(r[6], r[7]), "pivot": Vector2(r[8], r[9])})
	UnityUI.apply_rect(c)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_send("tap")
