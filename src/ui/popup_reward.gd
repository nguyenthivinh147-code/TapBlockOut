extends "res://src/ui/stub_ui.gd"
## Wireframe 11.3 Reward Claimed and 6.3 Purchase Success: shows a reward the game has already granted (Win Streak
## milestone, a purchase). Layout of PopupRewardLayer: one ItemReward per part of the reward in the grid
## (PopupRewardItem: gold, boosters, minutes of unlimited lives). ClaimBtn and the X, the dim or Back close it.
## The x2 video action (a copy of ClaimBtn on the blue pill, saved in scenes/popup_reward.tscn) stays hidden: the
## game doubles no reward here, so the economy does not change.
## While it shows, the counters behind keep the numbers before the reward (RewardFly.hold); closed any way (Claim, X,
## dim, Back), each part flies from its tile to its counter, as PopupRewardUICoreLayer.CloseLayer does.
## setup({view}): view = {reward: {coins, items, inf_min}, title (key, default "ads_reward_title"), flown (parts that
## already flew, e.g. ["gold"] after the Shop's gold flight)}.
## closed({"action": "claim" | "close"}).

const UnityUI := preload("res://src/ui/unity_ui.gd")
const LbKit := preload("res://src/ui/lb_kit.gd")
const RewardFly := preload("res://src/ui/reward_fly.gd")

## RewardFly part -> icon of its tile.
var _icons: Dictionary = {}


func _sample() -> Dictionary:
	return {"reward": {"coins": int(SampleData.REWARD.gold)}}


func _build() -> void:
	ui = UnityUI.build(self, "PopupRewardLayer")
	ui.text("Panel/Image/Image/txtHeader", tr(str(view.get("title", "ads_reward_title"))))
	ui.text("Panel/ClaimBtn/Out", tr("daily_claim"))
	ui.on_click("Panel/ClaimBtn", _send.bind("claim"))
	ui.on_click("Panel/Top/btnTurnOff", _send.bind("close"))
	ui.on_click("Bg", _send.bind("close"))
	# PopupRewardUICoreLayer hides the item prefab and pools copies of it.
	ui.show("Panel/Content/ItemReward", false)
	for e: Dictionary in LbKit.reward_entries(view.get("reward", {})):
		var item: RefCounted = ui.clone("Panel/Content/ItemReward")
		item.root.name = "Reward_" + str(e.kind)
		LbKit.set_entry_icon(item.node("Icon Item"), e)
		item.text("Quantity", str(e.amount))
		_icons[str(e.kind)] = item.node("Icon Item")
	%ClaimX2.visible = false
	ui.relayout("Panel")
	if not UnityUI.baking:
		Sfx.play("coin")
		RewardFly.hold(self, view.get("reward", {}), view.get("flown", []))
		closed.connect(_fly_out, CONNECT_ONE_SHOT)


func _fly_out(_r: Variant) -> void:
	RewardFly.launch(self, view.get("reward", {}), _icons, view.get("flown", []))
