extends "res://src/ui/stub_ui.gd"
## Wireframe 2.3 ADS Daily: xem quảng cáo để đầy thanh thưởng. Chưa nối logic.
## Layout of DailyRewardAdLayer (color-cube-match-puzzle): slider with one MilestoneItem per reward
## (UIDailyRewardAdsLayer.InitLayer places them at milestone / max along the bar), three lines in the info box,
## WatchAdsBtn (FullAdsBtn once every video is watched).

const UnityUI := preload("res://src/ui/unity_ui.gd")

const SLIDER := "Panel/Content/Preview/Bottom/Slider"
const GIFT_ICON := "ui_gift"
## MilestoneItem.SetNextReward scales the next reward up.
const NEXT_SCALE := 1.4


func _sample() -> Dictionary:
	return SampleData.ADS_DAILY


func _build() -> void:
	ui = UnityUI.build(self, "DailyRewardAdLayer")
	for p in ["Panel/txtHeader BG2", "Panel/txtHeader BG1", "Panel/txtHeader"]:
		ui.text(p, tr("home_ads_daily"))
	var watched := int(view.get("watched", 0))
	var total := maxi(1, int(view.get("total", 1)))
	var g := "Panel/Content/Preview/Bottom (1)/Group"
	ui.text(g + "/DescText", tr("ads_daily_sub"))
	ui.text(g + "/DescText (1)", tr("ads_daily_progress") % [watched, total])
	ui.text(g + "/DescText (2)", tr("ads_daily_reset"))
	ui.slider(SLIDER, float(watched) / float(total))
	_milestones(view.get("rewards", []), watched, total)
	var full := watched >= total
	ui.show("Panel/Content/GameObject/ClaimFreeBtn", false)
	ui.show("Panel/Content/GameObject/WatchAdsBtn", not full)
	ui.show("Panel/Content/GameObject/FullAdsBtn", full)
	for b in ["WatchAdsBtn", "FullAdsBtn"]:
		ui.text("Panel/Content/GameObject/%s/Out" % b, tr("ads_daily_watch"))
	ui.on_click("Panel/Content/GameObject/WatchAdsBtn", _send.bind("watch"))
	ui.on_click("Panel/btnTurnOff", _send.bind("close"))
	ui.on_click("Bg", _send.bind("close"))


## One MilestoneItem per reward: reward i is reached at video i + 1; tick when reached, the next one scaled up.
func _milestones(rewards: Array, watched: int, total: int) -> void:
	var tpl := SLIDER + "/MilestonesParent/Milestone"
	ui.show(tpl, false)
	var w := UnityUI.rect_size(ui.node(SLIDER + "/MilestonesParent")).x
	var next := -1
	for i in rewards.size():
		if i + 1 > watched:
			next = i
			break
	for i in rewards.size():
		var m: RefCounted = ui.clone(tpl)
		m.root.name = "Milestone%d" % (i + 1)
		var r: Dictionary = m.root.get_meta("u_rect")
		r.pos = Vector2(lerpf(-w * 0.5, w * 0.5, float(i + 1) / float(total)), (r.pos as Vector2).y)
		UnityUI.apply_rect(m.root)
		(m.field("milestoneText", "MilestoneItem") as Label).text = str(i + 1)
		var item: Control = m.field("rewardItem", "MilestoneItem")
		UnityUI.image_of(item.get_node("Icon Item")).call("set_texture", ThemeKit.icon(GIFT_ICON))
		UnityUI.set_text(item.get_node("Quantity") as Label, tr("booster_count") % int(rewards[i]))
		(m.field("tickMark", "MilestoneItem") as Control).visible = i + 1 <= watched
		var sc: Control = m.field("scaleItemNext", "MilestoneItem")
		if sc != null:
			sc.scale = Vector2.ONE * (NEXT_SCALE if i == next else 1.0)
		m.show("ScaleMilestone/ChildScaleMilestone/Arrow", i == next)
