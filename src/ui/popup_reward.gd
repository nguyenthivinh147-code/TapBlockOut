extends "res://src/ui/stub_ui.gd"
## Wireframe 11.3 Reward Claimed and 6.3 Purchase Success. Layout of PopupRewardLayer: one ItemReward per reward
## in the grid. The game's x2 video action is a copy of ClaimBtn on the blue pill. Not wired to logic.

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")
const LbKit := preload("res://src/ui/lb_kit.gd")

## RewardItemSO icon for gold (RewardType.Gold, ItemId 0).
const GOLD_ICON := "Resources_moved_UI_Maincenter:UI_Maincenter_3"
const VIDEO_ICON := "Resources_moved_UI_Maincenter:UI_Maincenter_5"


func _sample() -> Dictionary:
	return SampleData.REWARD


func _build() -> void:
	ui = UnityUI.build(self, "PopupRewardLayer")
	ui.text("Panel/Image/Image/txtHeader", tr("ads_reward_title"))
	ui.text("Panel/ClaimBtn/Out", tr("daily_claim"))
	ui.on_click("Panel/ClaimBtn", _send.bind("claim"))
	ui.on_click("Panel/Top/btnTurnOff", _send.bind("close"))
	ui.on_click("Bg", _send.bind("close"))
	# PopupRewardUICoreLayer hides the item prefab and pools copies of it.
	ui.show("Panel/Content/ItemReward", false)
	var item: RefCounted = ui.clone("Panel/Content/ItemReward")
	item.sprite("Icon Item", GOLD_ICON)
	item.text("Quantity", LbKit.fmt_int(int(view.get("gold", 0))))
	var x2 := UnityKit.spec("PopupRewardLayer", "Panel/ClaimBtn")
	x2.n = "ClaimX2"
	x2.img.sp = UnityKit.BUTTONS.blue[0]
	x2.ch[0].txt.mat = UnityKit.BUTTONS.blue[1]
	# Text moves right of the video icon (rect of Out: x offset +36, width -72).
	x2.ch[0].r[4] = float(x2.ch[0].r[4]) + 36.0
	x2.ch[0].r[6] = float(x2.ch[0].r[6]) - 72.0
	var v2: RefCounted = UnityKit.add(ui.node("Panel"), x2)
	v2.text("Out", tr("ads_reward_x2"))
	v2.on_click("", _send.bind("claim_x2"))
	UnityKit.sprite(v2.root, VIDEO_ICON, Rect2(16, 22, 76, 76))
	ui.relayout("Panel")
