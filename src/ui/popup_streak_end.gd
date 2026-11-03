extends "res://src/ui/stub_ui.gd"
## Wireframe 9.4 Streak Ended: kết thúc chuỗi, nhận thưởng. Chưa nối logic.
## Layout of PopupWinStreakEnd (color-cube-match-puzzle): ribbon, title, illustration, the pill (here the final streak
## with the game's streak star instead of the next-event clock), the message (the game's "rewards are ready") and the
## button. The game's rewards sit between message and button, as copies of PopupWinStreakInstruction's reward items
## (Preview/Bottom/Group, icon 85 + quantity) on its dark Bottom box.

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")
const LbKit := preload("res://src/ui/lb_kit.gd")

const LAYER := "PopupWinStreakEnd"
const PILL := "Panel/Image#4"
const MESSAGE := "Panel/Image#3"
const ITEM := "Panel/Content/Preview/Bottom/Group/Image (1)"
const BOX := "Panel/Content/Preview/Bottom/BG"
## RewardItemSO gold icon and PopupWinStreakMain's milestone gift.
const GOLD_ICON := "Resources_moved_UI_Maincenter:UI_Maincenter_3"
const CHEST_ICON := "UI_Winstreak_Atlas:UI_Winstreak_Atlas_6"
## Message (prefab 500x150 at y -387) shrinks to one line under the pill; the rewards box takes the rest above
## the frame's inner edge (popup7 bottom at y -500). Items keep the Bottom/Group spacing (~125).
const MESSAGE_Y := -318.0
const MESSAGE_H := 60.0
const BOX_RECT := Rect2(-250, -352, 500, 132)
const ITEM_STEP := 125.0
const ITEM_Y := 24.0


func _sample() -> Dictionary:
	return SampleData.STREAK_END


func _build() -> void:
	ui = UnityUI.build(self, LAYER)
	ui.text("Panel/Text (TMP)", tr("streak_end_title"))
	ui.on_click("Dim", _send.bind("close"))
	ui.text("Panel/Button/Text (TMP)", tr("daily_claim"))
	ui.on_click("Panel/Button", _send.bind("claim"))
	# streakResultText: the final streak, in the pill that UIPopupWinStreakEnd fills with the next event time.
	ui.texture(PILL + "/Image", ThemeKit.icon("ui_star"))
	_shift(ui.node(PILL + "/Image"), -40.0)
	ui.text(PILL + "/Text (TMP)", tr("streak_end_final") % int(view.get("streak", 0)))
	var pill: Control = ui.node(PILL)
	var text: Label = ui.label(PILL + "/Text (TMP)")
	# The pill grows (250 -> 330) for "Final streak: N"; the icon moves out by half of it, the text widens.
	UnityKit.set_size(pill, Vector2(330, 80))
	UnityKit.set_size(text, Vector2(246, 50))
	var msg: Control = ui.node(MESSAGE)
	var r: Dictionary = msg.get_meta("u_rect")
	r.pos = Vector2(0, MESSAGE_Y)
	r.size = Vector2((r.size as Vector2).x, MESSAGE_H)
	UnityUI.apply_rect(msg)
	ui.text(MESSAGE + "/Text (TMP) (1)", tr("streak_end_ready"))
	_build_rewards()


func _build_rewards() -> void:
	var panel: Control = ui.node("Panel")
	var box := UnityKit.spec("PopupWinStreakInstruction", BOX)
	box.n = "Rewards"
	box.r = [0.5, 0.5, 0.5, 0.5, BOX_RECT.position.x + BOX_RECT.size.x * 0.5, BOX_RECT.position.y - BOX_RECT.size.y * 0.5,
		BOX_RECT.size.x, BOX_RECT.size.y, 0.5, 0.5]
	var bv := UnityKit.add(panel, box)
	var items: Array = [
		[GOLD_ICON, null, LbKit.fmt_int(int(view.get("gold", 0)))],
		["", ThemeKit.icon("booster_hint"), tr("booster_count") % int(view.get("hint", 0))],
		[CHEST_ICON, null, tr("streak_chest")],
	]
	for i in items.size():
		var s := UnityKit.spec("PopupWinStreakInstruction", ITEM)
		s.n = "Reward%d" % (i + 1)
		s.r[4] = ITEM_STEP * (float(i) - 1.0)
		s.r[5] = ITEM_Y
		s.img.pa = true
		if items[i][0] != "":
			s.img.sp = items[i][0]
		s.ch[0].txt.s = items[i][2]
		s.ch[0].txt.auto = [18.0, float(s.ch[0].txt.fs)]
		var v := UnityKit.add(bv.root, s)
		if items[i][1] != null:
			v.texture("", items[i][1])


func _shift(c: Control, dx: float) -> void:
	var r: Dictionary = c.get_meta("u_rect")
	r.pos = (r.pos as Vector2) + Vector2(dx, 0)
	UnityUI.apply_rect(c)
