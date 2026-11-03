extends "res://src/ui/stub_ui.gd"
## Wireframe 9.4 Streak Ended: kết thúc chuỗi, nhận thưởng. Chưa nối logic.
## Layout of PopupWinStreakEnd (color-cube-match-puzzle): ribbon, title, illustration, the pill (here the final streak
## with the game's streak star instead of the next-event clock), the message (the game's "rewards are ready") and the
## button. The game's rewards sit between message and button, as copies of PopupWinStreakInstruction's reward items
## (Preview/Bottom/Group, icon 85 + quantity: gold, hint, the milestone chest) on its dark Bottom box. All of it is
## nodes of scenes/popup_streak_end.tscn; the script fills texts and wires the buttons.

const UnityUI := preload("res://src/ui/unity_ui.gd")
const LbKit := preload("res://src/ui/lb_kit.gd")

const LAYER := "PopupWinStreakEnd"
const PILL := "Panel/Image#4"
const MESSAGE := "Panel/Image#3"


func _sample() -> Dictionary:
	return SampleData.STREAK_END


func _build() -> void:
	# The pill (330 wide, the streak star 40 further out), the one-line message (y -318, 60 high) and the Rewards
	# box (500 x 132 at y -352, items 125 apart) are set up in the scene.
	ui = UnityUI.build(self, LAYER)
	ui.text("Panel/Text (TMP)", tr("streak_end_title"))
	ui.on_click("Dim", _send.bind("close"))
	ui.text("Panel/Button/Text (TMP)", tr("daily_claim"))
	ui.on_click("Panel/Button", _send.bind("claim"))
	# streakResultText: the final streak, in the pill that UIPopupWinStreakEnd fills with the next event time.
	ui.text(PILL + "/Text (TMP)", tr("streak_end_final") % int(view.get("streak", 0)))
	ui.text(MESSAGE + "/Text (TMP) (1)", tr("streak_end_ready"))
	UnityUI.set_text(%Reward1.get_node("Text (TMP)"), LbKit.fmt_int(int(view.get("gold", 0))))
	UnityUI.set_text(%Reward2.get_node("Text (TMP)"), tr("booster_count") % int(view.get("hint", 0)))
	UnityUI.set_text(%Reward3.get_node("Text (TMP)"), tr("streak_chest"))
