extends "res://src/ui/stub_ui.gd"
## Wireframe 9.3 Win Streak "How to play" (design.md mục 7 "Win Streak"): the rules, opened by the "i" button of
## the Main popup and once after Start in the intro (UILeaderboardDescriptionLayer, WinStreak tab: its close opens
## the Main popup, which main.gd does). Layout of PopupWinStreakInfo (color-cube-match-puzzle): dark full-screen
## panel, title, three zig-zag steps joined by the prefab's arrows that pop in one by one
## (LeaderboarDescriptionAnim), the closing line and "Tap to continue" (the panel is the close button). Each step
## shows Win Streak art of the prefabs: the intro illustration (win in a row), the milestone chest (claim), the
## crying cat bar of PopupKeepPlayingWinstreak (a loss drops to the last milestone). closed({"action": "ok"}).

const UnityUI := preload("res://src/ui/unity_ui.gd")

const LAYER := "PopupWinStreakInfo"
const DESC := "Panel/LeaguesDesc"
## LeaderboarDescriptionAnim of the prefab: OutBack, 0.8 s per step, 0.3 s apart.
const ANIM_DUR := 0.8
const ANIM_GAP := 0.3
## [rule key, sprite] per step.
const STEPS := [
	["streak_rule_win", "illustration01_1"],
	["streak_rule_claim", "UI_Winstreak_Atlas:UI_Winstreak_Atlas_6"],
	["streak_rule_drop", "UI_Winstreak_Atlas:UI_Winstreak_Atlas_7"],
]

var _steps: Array[Control] = []


func _build() -> void:
	ui = UnityUI.build(self, LAYER)
	ui.text(DESC + "/txtHeader", tr("streak_rules_title"))
	ui.text("Panel/TapToContinueTxt", tr("boot_tap_continue"))
	ui.on_click("Panel", _send.bind("ok"))
	for i in STEPS.size():
		var p := DESC + "/Step%d" % (i + 1)
		var step: Control = ui.node(p)
		UnityUI.set_sprite(step, str(STEPS[i][1]))
		var img := UnityUI.image_of(step)
		if img != null:
			img.set("preserve_aspect", true)
		ui.text(p + "/Desc", tr(str(STEPS[i][0])))
		_steps.append(step)
	ui.text(DESC + "/Desc", tr("streak_rules_note"))
	if not UnityUI.baking:
		_play.call_deferred()


## LeaderboarDescriptionAnim.PlayScaleAnimationAsync: each step, then the closing line, scales in (OutBack).
func _play() -> void:
	if not is_inside_tree():
		return
	var targets: Array[Control] = _steps.duplicate()
	targets.append(ui.node(DESC + "/Desc"))
	var t := 0.0
	for c in targets:
		c.scale = Vector2.ZERO
		var tw := c.create_tween()
		tw.tween_interval(t)
		tw.tween_property(c, "scale", Vector2.ONE, ANIM_DUR).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t += ANIM_GAP
