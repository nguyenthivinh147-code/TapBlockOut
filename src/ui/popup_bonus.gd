extends "res://src/ui/stub_ui.gd"
## Wireframe 4.2 Bonus Multiplier: chạm dừng mũi tên để nhân thưởng. Không có prefab: khung PopupOkLayer cỡ 724x932;
## dải hệ số là nền thanh tiến trình của WinPanel, ô thưởng là bản sao Reward.prefab trên ô kem, hai nút ở hàng nút
## của PopupOkLayer (Để sau xám, Nhận xanh có TV như AdsBtn của PopupReviveLayer). Tất cả là node trong
## scenes/popup_bonus.tscn; script chỉ điền chữ, các ô hệ số theo view và nối nút. Chưa nối logic.

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")


func _sample() -> Dictionary:
	return SampleData.BONUS


func _build() -> void:
	# Frame, hint, strip, well, Reward.prefab and the button row are nodes of scenes/popup_bonus.tscn.
	ui = UnityKit.frame(self, tr("win_bonus_title"), _send.bind("close"))
	UnityUI.set_text(%TapHint, tr("win_bonus_tap"))
	var mult: Array = view.multipliers
	var cell := 580.0 / maxf(1.0, mult.size())
	for i in mult.size():
		UnityKit.label(%Strip, tr("booster_count") % int(mult[i]), Rect2(20 + i * cell, 14, cell, 72), 48.0,
			"ffffffff", "Baloo Outline - Blue 1")
	UnityUI.set_text(%Reward.get_node("RewardText"), tr("shop_gold_pack") % int(view.coins))
	UnityUI.set_text(%Total, tr("win_bonus_total") % int(view.result))
	UnityUI.set_text(%SkipButton.get_node("Out"), tr("offer_no_thanks"))
	UnityUI.set_text(%ClaimButton.get_node("Out"), tr("win_bonus_claim"))
	%SkipButton.connect("clicked", _send.bind("skip"))
	%ClaimButton.connect("clicked", _send.bind("claim"))
