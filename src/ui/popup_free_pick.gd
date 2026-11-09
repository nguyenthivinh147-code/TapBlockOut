extends "res://src/ui/stub_ui.gd"
## Wireframe 3.9 Free Pick: mời dùng thử booster vừa tặng (level.gd, ngay sau popup booster mới 3.8). Nhận
## (closed({"action": "claim"})) thì vào chơi với bàn tay nhấp vào nút booster đó tới khi bấm; X đóng
## ({"action": "close"}). Booster tặng đã vào kho nên dùng thử không tốn gì. Không có prefab: khung PopupOkLayer cỡ
## 724x660 (tiêu đề, X, ô kem của prefab, nút xanh), bàn tay chỉ của prefab hướng dẫn. Tất cả là node trong
## scenes/popup_free_pick.tscn; script điền chữ theo booster và nối nút. setup({view}): {kind}.

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")


func _sample() -> Dictionary:
	return {"kind": "hint"}


func _build() -> void:
	# Frame, well, title, hand (SpeedUpTutorialLayer HandSprite), body and the green button are scene nodes.
	ui = UnityKit.frame(self, tr("booster_new_short"), _send.bind("close"))
	UnityUI.set_text(%Title, tr("booster_free_pick"))
	UnityUI.set_text(%Body, tr("booster_free_pick_body") % tr("booster_" + str(view.get("kind", "hint"))))
	UnityUI.set_text(%ClaimButton.get_node("Out"), tr("booster_try"))
	%ClaimButton.connect("clicked", _send.bind("claim"))
