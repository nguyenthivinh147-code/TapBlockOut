extends Control
## Wireframe 8.4: popup lên league. Huy hiệu league mới, lời chào, thưởng của các league vừa lên.
## setup({view}): view = Game.lb_pending_view() ({leagues, league, reward}); không truyền thì tự đọc.
## Chạm để nhận: luôn gọi Game.lb_claim() (thưởng không mất). closed({"action": "claim", "reward"}).
## Layout of LeaderboardWeeklyResultLayer: header, "next league" line and trophy, RewardGroup with Reward items,
## "tap to continue"; the whole Dim is the claim button (UILeaderboardWeeklyResultLayer._claimButton). The
## "Your rank" line and card are hidden: the game's popup is about the new league, not a weekly placement.

signal closed(result: Variant)

const LbKit := preload("res://src/ui/lb_kit.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")

const P := "WeekResultPanel/"

var view: Dictionary = {}
var ui: RefCounted = null
var _built: bool = false
var _done: bool = false


func setup(args: Dictionary = {}) -> void:
	if _built:
		return
	_built = true
	view = args.get("view", Game.lb_pending_view())
	set_anchors_preset(Control.PRESET_FULL_RECT)
	ui = UnityUI.build(self, "LeaderboardWeeklyResultLayer")
	var league := str(view.get("league", "silver"))
	for p in ["Image/txtHeader BG2", "Image/txtHeader BG1", "Image/txtHeader"]:
		ui.text(P + p, tr("lb_result_title"))
	ui.show(P + "YourRankTxt", false)
	ui.show(P + "PlayerLeaderboardItem", false)
	var hello: Label = ui.text(P + "NextLeagueTxt", tr("lb_result_promoted") % LbKit.league_name(league))
	hello.name = "PromotedLabel"
	LbKit.set_league_icon(ui.node(P + "Image#2"), league)
	ui.node(P + "Image#2").name = "LeagueBadge"
	var items := LbKit.reward_items(ui.node(P + "RewardGroup/Rewards"), view.get("reward", {}))
	ui.show(P + "RewardGroup", not items.is_empty())
	ui.text(P + "RewardGroup/NextLeagueTxt (1)", tr("lb_result_reward"))
	ui.relayout(P + "RewardGroup")
	ui.text(P + "TapToContinueTxt", tr("boot_tap_continue"))
	var claim: Button = ui.on_click(P + "Dim", _claim)
	claim.name = "ClaimButton"
	Sfx.play("sfx_win")


func _ready() -> void:
	setup.call_deferred()


func _claim() -> void:
	if _done:
		return
	_done = true
	var r: Dictionary = Game.lb_claim()
	if not r.is_empty():
		Sfx.play("sfx_coin")
	closed.emit({"action": "claim", "reward": r})
