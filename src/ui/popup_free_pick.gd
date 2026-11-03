extends "res://src/ui/stub_ui.gd"
## Wireframe 3.9 Free Pick: dùng thử booster lần đầu. Không có prefab: khung PopupOkLayer cỡ 724x660 (tiêu đề, X,
## ô kem của prefab, nút xanh), bàn tay chỉ của prefab hướng dẫn. Tất cả là node trong scenes/popup_free_pick.tscn;
## script chỉ điền chữ và nối nút. Chưa nối logic.

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")


func _build() -> void:
	# Frame, well, title, hand (SpeedUpTutorialLayer HandSprite), body and the green button are scene nodes.
	ui = UnityKit.frame(self, tr("booster_new_short"), _send.bind("close"))
	UnityUI.set_text(%Title, tr("booster_free_pick"))
	UnityUI.set_text(%Body, tr("booster_free_pick_body"))
	UnityUI.set_text(%ClaimButton.get_node("Out"), tr("daily_claim"))
	%ClaimButton.connect("clicked", _send.bind("claim"))
