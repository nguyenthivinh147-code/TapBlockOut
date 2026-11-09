extends "res://src/ui/stub_ui.gd"
## Wireframe 9.4 Streak Ended (design.md mục 7 "Win Streak"): opened by the Home icon when no event runs and no
## reward waits (UIPopupWinStreakEnd: shown when the event is over, or on a ClaimOnly day with every reward
## claimed). It only sums up: the final streak and the time to the next event; it holds no reward.
## Layout of PopupWinStreakEnd (color-cube-match-puzzle): ribbon, title, illustration, the message (the game's final
## streak), the pill (nextEventText: clock and the time to the next event, "{d}d {h}h" or "{h}h {m}m") and the
## button, which closes like the dim. The Rewards box of the earlier mock-up (scene nodes) stays hidden.
## setup({view}): Game.streak_view() by default ({streak, next_in}). closed({"action": "close"}).

const UnityUI := preload("res://src/ui/unity_ui.gd")

const LAYER := "PopupWinStreakEnd"
const PILL := "Panel/Image#4"
const MESSAGE := "Panel/Image#3"
## nextEventText's clock (the mock-up put the streak star there).
const CLOCK := "Resources_UI_Maincenter:UI_Maincenter_79"


func _sample() -> Dictionary:
	return Game.streak_view()


func _build() -> void:
	ui = UnityUI.build(self, LAYER)
	ui.text("Panel/Text (TMP)", tr("streak_end_title"))
	ui.on_click("Dim", _send.bind("close"))
	ui.text("Panel/Button/Text (TMP)", tr("common_ok"))
	ui.on_click("Panel/Button", _send.bind("close"))
	ui.text(MESSAGE + "/Text (TMP) (1)", tr("streak_end_final") % int(view.get("streak", 0)))
	ui.sprite(PILL + "/Image", CLOCK)
	ui.text(PILL + "/Text (TMP)", next_text(int(view.get("next_in", 0))))
	%Rewards.visible = false


## UIPopupWinStreakEnd.InitLayer: "{d}d {h}h" from a day on, else "{h}h {m}m".
static func next_text(sec: int) -> String:
	sec = maxi(sec, 0)
	@warning_ignore("integer_division")
	var d := sec / 86400
	@warning_ignore("integer_division")
	var h := (sec % 86400) / 3600
	@warning_ignore("integer_division")
	var m := (sec % 3600) / 60
	return "%dd %dh" % [d, h] if d >= 1 else "%dh %dm" % [h, m]
