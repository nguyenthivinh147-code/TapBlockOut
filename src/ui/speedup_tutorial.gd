extends "res://src/ui/stub_ui.gd"
## Wireframe 3.11 Speed-up Tutorial: giữ để tăng tốc. Bố cục SpeedUpTutorialLayer (color-cube-match-puzzle): khung lời
## dặn ở dưới (tiêu đề và mô tả là hai nửa của ô chữ prefab), bàn tay nhấp (Animator TutController_Step1) chỉ vào ô
## TargetButton ở góc trên, ô đó ghi "Giữ". Chạm ô đó hoặc chỗ bất kỳ thì đóng như wireframe. Chưa nối logic.

const UnityUI := preload("res://src/ui/unity_ui.gd")

const TEXT := "Panel/Canvas/Text (TMP)"
const TARGET := "GameObject/Step1/Hand/TargetButton"


func _build() -> void:
	# The description in the lower half of the text box, TitleText (upper half, 52 bold) and HoldText (left of the
	# hand sprite, Baloo Outline - Blue 1) are saved in scenes/speedup_tutorial.tscn.
	ui = UnityUI.build(self, "SpeedUpTutorialLayer")
	ui.text(TEXT, tr("level_speed_body"))
	UnityUI.set_text(%TitleText, tr("level_speed_title"))
	UnityUI.set_text(%HoldText, tr("level_speed_hold"))
	ui.on_click(TARGET, _send.bind("tap"))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_send("tap")
