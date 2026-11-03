extends "res://src/ui/stub_ui.gd"
## Wireframe 3.7 Booster Coming Soon: booster còn khoá theo level. Bố cục BoosterTutorialLayer (color-cube-match-puzzle):
## tiêu đề ba lớp chữ ("Chơi tiếp nhé!"), tia sáng quay, ba bản sao icon booster cạnh nhau (booster khoá hiện ổ khoá),
## mô tả. Tên, số lượng và nút của prefab ẩn: màn chỉ báo, chạm đâu cũng đóng như wireframe. Chưa nối logic.

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")

const PANEL := "GameObject/UnlockPanel"
const HEADERS := ["txtHeader BG2", "txtHeader BG1", "txtHeader"]
## Three icons share the 350-unit icon slot's row: 220 each, centres 240 apart.
const ICON := 220.0
const STEP := 240.0


func _build() -> void:
	ui = UnityUI.build(self, "BoosterTutorialLayer")
	for h in HEADERS:
		ui.text(PANEL + "/Image/" + h, tr("booster_soon_keep"))
	ui.text(PANEL + "/BoosterDescription", tr("booster_soon_body"))
	for p in ["BoosterName", "BoosterQuantity", "ClaimButton"]:
		ui.show(PANEL + "/" + p, false)
	var icons := ["booster_hint", "booster_move", "ui_lock"]
	var slot: Control = ui.node(PANEL + "/BoosterImage/Icon")
	slot.visible = false
	for i in icons.size():
		var s := UnityKit.spec("BoosterTutorialLayer", PANEL + "/BoosterImage/Icon")
		s.n = "Icon_" + str(icons[i]).trim_prefix("booster_").trim_prefix("ui_")
		s.r[4] = (i - 1) * STEP
		s.r[6] = ICON
		s.r[7] = ICON
		var v: RefCounted = UnityKit.add(slot.get_parent(), s)
		v.texture("", ThemeKit.icon(icons[i]))
		UnityUI.image_of(v.root).preserve_aspect = true


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_send("tap")
