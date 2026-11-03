extends "res://src/ui/stub_ui.gd"
## Wireframe 3.7 Booster Coming Soon: booster còn khoá theo level. Bố cục BoosterTutorialLayer (color-cube-match-puzzle):
## tiêu đề ba lớp chữ ("Chơi tiếp nhé!"), tia sáng quay, ba bản sao icon booster cạnh nhau (booster khoá hiện ổ khoá),
## mô tả. Tên, số lượng và nút của prefab ẩn: màn chỉ báo, chạm đâu cũng đóng như wireframe. Chưa nối logic.

const UnityUI := preload("res://src/ui/unity_ui.gd")

const PANEL := "GameObject/UnlockPanel"
const HEADERS := ["txtHeader BG2", "txtHeader BG1", "txtHeader"]


func _build() -> void:
	# The three icons (Icon_hint, Icon_move, Icon_lock: 220 each, centres 240 apart in the icon slot's row) and the
	# hidden name, quantity, button and icon slot are saved in scenes/booster_soon.tscn.
	ui = UnityUI.build(self, "BoosterTutorialLayer")
	for h in HEADERS:
		ui.text(PANEL + "/Image/" + h, tr("booster_soon_keep"))
	ui.text(PANEL + "/BoosterDescription", tr("booster_soon_body"))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_send("tap")
