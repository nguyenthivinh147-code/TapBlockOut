extends "res://src/ui/stub_ui.gd"
## Wireframe 9.3 Rewards Info: thưởng từng mốc. Chưa nối logic.
## Layout of PopupWinStreakInfo (color-cube-match-puzzle): dark full-screen panel, curved title, zig-zag steps joined
## by arrows that pop in one by one (LeaderboarDescriptionAnim), the closing line and "Tap to continue" (the panel is
## the close button). One step per milestone: the game's reward icon and "Streak N / reward" under it. The prefab has
## three steps; a fourth is a copy of Step2, and the steps keep the prefab's Step1 -> Step2 offset at 0.8 scale so
## four fit above the closing line.

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")

const LAYER := "PopupWinStreakInfo"
const DESC := "Panel/LeaguesDesc"
## Step1 and Step2 of the prefab: x of the left / right column, and the vertical step between them.
const LEFT_X := -196.3
const RIGHT_X := 229.7
const TOP_Y := 558.0
const STEP_Y := 299.1
const STEP_SCALE := 0.8
## The closing line moves below the fourth step (prefab: y -526 under three steps).
const NOTE_Y := -560.0
## LeaderboarDescriptionAnim of the prefab: OutBack, 0.8 s per step, 0.3 s apart.
const ANIM_DUR := 0.8
const ANIM_GAP := 0.3
## RewardItemSO icons (gold, unlimited lives) and the milestone gift of PopupWinStreakMain.
const ICONS := {
	"gold": "Resources_moved_UI_Maincenter:UI_Maincenter_3",
	"heart": "Resources_moved_UI_Maincenter:UI_Maincenter_16",
	"chest": "UI_Winstreak_Atlas:UI_Winstreak_Atlas_6",
}

var _steps: Array[Control] = []


func _sample() -> Dictionary:
	return SampleData.STREAK_REWARDS


func _build() -> void:
	ui = UnityUI.build(self, LAYER)
	ui.text(DESC + "/txtHeader", tr("streak_rewards_title"))
	ui.text("Panel/TapToContinueTxt", tr("boot_tap_continue"))
	ui.on_click("Panel", _send.bind("ok"))
	var rows: Array = view.get("rows", [])
	for i in rows.size():
		_steps.append(_step(i, rows[i], i == rows.size() - 1))
	for i in range(rows.size(), 3):
		ui.show(DESC + "/Step%d" % (i + 1), false)
	var note: Label = ui.text(DESC + "/Desc", tr("streak_rewards_note"))
	var r: Dictionary = note.get_meta("u_rect")
	r.pos = Vector2((r.pos as Vector2).x, NOTE_Y)
	UnityUI.apply_rect(note)
	_play.call_deferred()


func _step(i: int, row: Dictionary, last: bool) -> Control:
	var v: RefCounted = null
	var step: Control
	if i < 3:
		step = ui.node(DESC + "/Step%d" % (i + 1))
	else:
		v = ui.clone(DESC + "/Step2")
		step = v.root
		step.name = "Step%d" % (i + 1)
	var left := i % 2 == 0
	var r: Dictionary = step.get_meta("u_rect")
	r.pos = Vector2(LEFT_X if left else RIGHT_X, TOP_Y - STEP_Y * i)
	UnityUI.apply_rect(step)
	step.scale = Vector2.ZERO
	var kind := str(row.get("kind", "gold"))
	var img := UnityUI.image_of(step)
	if ICONS.has(kind):
		UnityUI.set_sprite(step, str(ICONS[kind]))
	elif img != null:
		img.call("set_texture", ThemeKit.icon("booster_" + kind))
	if img != null:
		img.set("preserve_aspect", true)
	for c in step.get_children():
		if c is Label:
			UnityUI.set_text(c as Label, "%s\n%s" % [tr("streak_row") % int(row.get("streak", 0)),
				tr("streak_reward_" + kind) % int(row.get("amount", 0))])
		elif c is Control and (c as Control).has_meta("u"):
			# The prefab's arrows fit its own gaps; every step but the last gets Step1's arrow instead.
			(c as Control).visible = false
	if not last:
		var a := UnityKit.spec(LAYER, DESC + "/Step1/Image")
		a.n = "Arrow"
		if not left:
			# Step1's arrow mirrored: from the right column down to the left one.
			a.r[4] = -float(a.r[4])
			a.z = -float(a.z)
			a.s = [-1, 1]
		UnityKit.add(step, a)
	return step


## LeaderboarDescriptionAnim.PlayScaleAnimationAsync: each step, then the closing line, scales in (OutBack).
func _play() -> void:
	if not is_inside_tree():
		return
	var targets: Array = []
	for s in _steps:
		targets.append([s, Vector2.ONE * STEP_SCALE])
	var note: Control = ui.node(DESC + "/Desc")
	targets.append([note, Vector2.ONE])
	var t := 0.0
	for e in targets:
		var c: Control = e[0]
		c.scale = Vector2.ZERO
		var tw := c.create_tween()
		tw.tween_interval(t)
		tw.tween_property(c, "scale", e[1], ANIM_DUR).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t += ANIM_GAP
