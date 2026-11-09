extends Control
## Wireframe 8.4: popup lên league, và popup kết quả tuần (design.md mục 7 "Leaderboard theo league").
## setup({view}): lên league, view = Game.lb_pending_view() ({leagues, league, reward}); không truyền thì tự đọc.
##   Huy hiệu league mới, lời chào, thưởng của các league vừa lên. Chạm để nhận: Game.lb_claim().
## setup({week}): kết quả tuần, week = Game.lb_week_result_view() ({week, league, points, rank, reward}). Hạng và
##   điểm của tuần trên thẻ người chơi, huy hiệu giải cuối tuần, "tuần mới bắt đầu lại từ giải đầu", thưởng chờ (nếu có).
##   Chạm để đóng: Game.lb_week_claim() (thưởng không mất).
## closed({"action": "claim", "reward"}).
## Layout of LeaderboardWeeklyResultLayer: header, "Your rank" line and card, "next league" line and trophy,
## RewardGroup with Reward items, "tap to continue"; the whole Dim is the claim button
## (UILeaderboardWeeklyResultLayer._claimButton). League up hides the "Your rank" line and card.

signal closed(result: Variant)

const Config := preload("res://src/config.gd")
const LbKit := preload("res://src/ui/lb_kit.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")

const P := "WeekResultPanel/"

var view: Dictionary = {}
var week: Dictionary = {}
var ui: RefCounted = null
var _built: bool = false
var _done: bool = false


func setup(args: Dictionary = {}) -> void:
	if _built:
		return
	_built = true
	week = args.get("week", {})
	view = week if not week.is_empty() else args.get("view", Game.lb_pending_view())
	set_anchors_preset(Control.PRESET_FULL_RECT)
	ui = UnityUI.build(self, "LeaderboardWeeklyResultLayer")
	var league := str(view.get("league", "silver"))
	var weekly := not week.is_empty()
	for p in ["Image/txtHeader BG2", "Image/txtHeader BG1", "Image/txtHeader"]:
		ui.text(P + p, tr("lb_week_title" if weekly else "lb_result_title"))
	ui.show(P + "YourRankTxt", weekly)
	ui.show(P + "PlayerLeaderboardItem", weekly)
	var line := tr("lb_result_promoted") % LbKit.league_name(league)
	if weekly:
		ui.text(P + "YourRankTxt", tr("lb_week_rank"))
		var card: Control = ui.node(P + "PlayerLeaderboardItem")
		card.name = "WeekCard"
		LbKit.fill_card(card, {"rank": int(week.get("rank", 0)), "points": int(week.get("points", 0)), "me": true,
			"avatar": str(Game.s.cos.get("avatar", "")), "frame": str(Game.s.cos.get("frame", ""))},
			tr("lb_league") % LbKit.league_name(league))
		var first := str(((Config.LEADERBOARD.get("leagues", []) as Array).front() as Dictionary).get("id", "silver"))
		line = tr("lb_week_restart") % (tr("lb_league") % LbKit.league_name(first))
	var hello: Label = ui.text(P + "NextLeagueTxt", line)
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
	var r: Dictionary = Game.lb_week_claim() if not week.is_empty() else Game.lb_claim()
	if int(r.get("coins", 0)) > 0 or not (r.get("items", {}) as Dictionary).is_empty() or int(r.get("inf_min", 0)) > 0:
		Sfx.play("sfx_coin")
	closed.emit({"action": "claim", "reward": r})
