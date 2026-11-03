extends "res://src/ui/stub_ui.gd"
## Wireframe 9.5 Keep Your Streak?: giữ chuỗi bằng quảng cáo. Chưa nối logic.
## Layout of PopupKeepPlayingWinstreak (color-cube-match-puzzle): purple frame, the crying cat bar with the streak cat
## icon, the warning and the red Quit button. The game's streak count takes the broken heart's place (the game's
## text does not mention a heart); its video Continue is a copy of Quit on the green pill with the TV icon, and the
## two buttons share the row like PopupOkLayer's pair (280 each, spacing 52). The layer, StreakText and Continue are
## nodes of scenes/popup_streak_keep.tscn; the script fills texts and wires the buttons.

const UnityUI := preload("res://src/ui/unity_ui.gd")

const LAYER := "PopupKeepPlayingWinstreak"
const ROW := "Panel/Content/Button"


func _sample() -> Dictionary:
	return SampleData.STREAK_KEEP


func _build() -> void:
	ui = UnityUI.build(self, LAYER)
	ui.text("Panel/GameObject/txtHeader", tr("streak_keep_title"))
	for b in ui.field("closeButtons", "UIPopupKeepPlayingWinstreak"):
		(b as Button).connect("clicked", _send.bind("close"))
	ui.text("Panel/Content/Description", "%s\n%s" % [tr("streak_keep_reset"), tr("streak_keep_body")])
	# StreakText fills the broken heart's slot (centre x 117, y 74.1) up to the cat icon.
	UnityUI.set_text(%StreakText, tr("streak_row") % int(view.get("streak", 0)))
	# Continue (first) and Quit (Ok, 280 wide) share the row; Continue's text sits right of the video icon.
	ui.text(ROW + "/Ok/Out", tr("lose_keep_quit"))
	ui.on_click(ROW + "/Ok", _send.bind("quit"))
	UnityUI.set_text(%Continue.get_node("Out"), tr("streak_keep_ad"))
	%Continue.connect("clicked", _send.bind("continue"))
