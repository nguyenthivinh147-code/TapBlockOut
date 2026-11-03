extends "res://src/ui/stub_ui.gd"
## Wireframe 11.3 Reward Claimed and 6.3 Purchase Success. Layout of PopupRewardLayer: one ItemReward per reward
## in the grid. The game's x2 video action is a copy of ClaimBtn on the blue pill, saved in scenes/popup_reward.tscn;
## the script fills texts, the reward item and the buttons. Not wired to logic.

const UnityUI := preload("res://src/ui/unity_ui.gd")
const LbKit := preload("res://src/ui/lb_kit.gd")

## RewardItemSO icon for gold (RewardType.Gold, ItemId 0).
const GOLD_ICON := "Resources_moved_UI_Maincenter:UI_Maincenter_3"


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
	# ClaimX2 (copy of ClaimBtn on the blue pill, text right of VideoIcon) is a node of scenes/popup_reward.tscn.
	UnityUI.set_text(%ClaimX2.get_node("Out"), tr("ads_reward_x2"))
	%ClaimX2.connect("clicked", _send.bind("claim_x2"))
	ui.relayout("Panel")
