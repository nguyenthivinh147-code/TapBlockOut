extends "res://src/ui/stub_ui.gd"
## Wireframe 9.1 Instruction: giới thiệu Win Streak. Chưa nối logic.
## Layout of PopupWinStreakInstruction (color-cube-match-puzzle): title ribbon, illustration, countdown pill and the
## Start button. The game's three rules go in the description, one line each. The layer and the Rules text are nodes
## of scenes/popup_streak_intro.tscn; the script fills texts, the countdown and wires the buttons.

const UnityUI := preload("res://src/ui/unity_ui.gd")

const LAYER := "PopupWinStreakInstruction"


func _sample() -> Dictionary:
	return SampleData.STREAK_INTRO


func _build() -> void:
	ui = UnityUI.build(self, LAYER)
	ui.text("Panel/Image/txtHeader", tr("streak_title"))
	ui.text("Panel/Content/GameObject/FreeBtn/Out", tr("streak_go"))
	ui.on_click("Panel/Content/GameObject/FreeBtn", _send.bind("go"))
	for b in ui.field("closeButtons", "UIPopupWinStreakInstruction"):
		(b as Button).connect("clicked", _send.bind("close"))
	# UIPopupWinStreakInstruction.StartCooldown hides the countdown when the event has no end time.
	var ends := str(view.get("ends_in", ""))
	ui.show("Panel/Content/Preview/Platform/Time", ends != "")
	if ends != "":
		ui.text("Panel/Content/Preview/Platform/Time/Text (TMP)", ends)
	# Rules (scene node) replaces the prefab description: taller (y -392, 156 high, between the illustration and
	# popup7's inner edge) and with TMP auto size, so the three rules fit the frame.
	UnityUI.set_text(%Rules, "\n".join([tr("streak_intro_1"), tr("streak_intro_2"), tr("streak_intro_3")]))
