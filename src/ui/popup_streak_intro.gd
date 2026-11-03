extends "res://src/ui/stub_ui.gd"
## Wireframe 9.1 Instruction: giới thiệu Win Streak. Chưa nối logic.
## Layout of PopupWinStreakInstruction (color-cube-match-puzzle): title ribbon, illustration, countdown pill and the
## Start button. The game's three rules go in the description, one line each.

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")

const LAYER := "PopupWinStreakInstruction"
const DESC := "Panel/Content/Text (TMP) (1)"
## The description (700x100 at y -384) grows to three lines between the illustration (bottom at y -310) and the
## frame's inner edge (popup7 bottom at y -500).
const DESC_Y := -392.0
const DESC_H := 156.0


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
	# Copy of the description, taller and with TMP auto size so the three rules fit the frame.
	ui.show(DESC, false)
	var s := UnityKit.spec(LAYER, DESC)
	s.n = "Rules"
	s.txt.auto = [18.0, float(s.txt.fs)]
	s.r[5] = DESC_Y
	s.r[7] = DESC_H
	var v := UnityKit.add(ui.node("Panel/Content"), s)
	v.text("", "\n".join([tr("streak_intro_1"), tr("streak_intro_2"), tr("streak_intro_3")]))
