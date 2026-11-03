extends "res://src/ui/stub_ui.gd"
## Wireframe 4.2 Bonus Multiplier: chạm dừng mũi tên để nhân thưởng. Không có prefab: khung PopupOkLayer qua UnityKit;
## dải hệ số là nền thanh tiến trình của WinPanel, ô thưởng là bản sao Reward.prefab trên ô kem, hai nút ở hàng nút
## của PopupOkLayer (Để sau xám, Nhận xanh có TV như AdsBtn của PopupReviveLayer). Chưa nối logic.

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")

const SIZE := Vector2(724, 932)
const GOLD_ICON := "Resources_moved_UI_Maincenter:UI_Maincenter_3"
const STRIP := "Panel/WinPanel/WinPanel/NewFeatureUnlock/Slider/Background"


func _sample() -> Dictionary:
	return SampleData.BONUS


func _build() -> void:
	ui = UnityKit.popup(self, tr("win_bonus_title"), SIZE, _send.bind("close"))
	var c: Control = ui.node("Panel/Content")
	UnityKit.label(c, tr("win_bonus_tap"), Rect2(72, 140, 580, 56), 40.0)
	UnityKit.sprite(c, "", Rect2(332, 200, 60, 60), ThemeKit.icon("ic_arrow"))
	var strip: RefCounted = UnityKit.add(c, UnityKit.spec("EndGameUILayer", STRIP), Rect2(52, 266, 620, 100))
	strip.root.name = "Strip"
	var mult: Array = view.multipliers
	var cell := 580.0 / maxf(1.0, mult.size())
	for i in mult.size():
		UnityKit.label(strip.root, tr("booster_count") % int(mult[i]), Rect2(20 + i * cell, 14, cell, 72), 48.0,
			"ffffffff", "Baloo Outline - Blue 1")
	UnityKit.well(c, Rect2(52, 380, 620, 290))
	# Reward.prefab: icon centred in its 150 x 200 box, amount 146.5 under the icon centre.
	var reward: RefCounted = UnityKit.add(c, UnityKit.spec("Reward", ""), Rect2(287, 380, 150, 200))
	reward.root.visible = true
	reward.sprite("RewardIcon", GOLD_ICON)
	reward.text("RewardText", tr("shop_gold_pack") % int(view.coins))
	UnityKit.label(c, tr("win_bonus_total") % int(view.result), Rect2(72, 676, 580, 56), 44.0)
	# PopupOkLayer button row: 280 + 52 + 280 on 612, 68 above the panel bottom.
	var y := SIZE.y - 68.0 - 120.0
	UnityKit.button(c, "gray", tr("offer_no_thanks"), Rect2(56, y, 280, 120), _send.bind("skip"))
	var claim: RefCounted = UnityKit.button(c, "blue", tr("win_bonus_claim"), Rect2(388, y, 280, 120), _send.bind("claim"))
	UnityKit.add(claim.root, UnityKit.spec("PopupReviveLayer", "Bg/Panel/Content/GameObject/AdsBtn/Image"))
