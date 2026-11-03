extends "res://src/ui/stub_ui.gd"
## Wireframe 3.9 Free Pick: dùng thử booster lần đầu. Không có prefab: khung PopupOkLayer qua UnityKit (tiêu đề, X,
## ô kem của prefab, nút xanh), bàn tay chỉ của prefab hướng dẫn. Chưa nối logic.

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")

## Hand of the tutorial prefabs (SpeedUpTutorialLayer HandSprite).
const HAND := "Resources_UI_Maincenter:UI_Maincenter_19"


func _build() -> void:
	ui = UnityKit.popup(self, tr("booster_new_short"), Vector2(724, 660), _send.bind("close"))
	var c: Control = ui.node("Panel/Content")
	# PopupOkLayer content: well 620 x 307 under the header, Ok button 280 x 120 centred on the bottom row.
	UnityKit.well(c, Rect2(52, 133, 620, 307))
	UnityKit.label(c, tr("booster_free_pick"), Rect2(72, 145, 580, 72), 56.0, "ffffffff", "Baloo Outline - Purple")
	UnityKit.sprite(c, HAND, Rect2(297, 217, 130, 130))
	UnityKit.label(c, tr("booster_free_pick_body"), Rect2(72, 352, 580, 80), 40.0)
	UnityKit.button(c, "green", tr("daily_claim"), Rect2(222, 472, 280, 120), _send.bind("claim"))
