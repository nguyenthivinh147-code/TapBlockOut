extends "res://src/ui/stub_ui.gd"
## Wireframe 1.5 First-time Tutorial. Layout of MainTutorialLayer (color-cube-match-puzzle): Step1 is the active
## step (MainTutorialOverlay.PlayStep(1)): its Animator plays TutController_Step1 (hand press, tap rings) and its
## TargetButton under the hand continues. Step2 stays hidden. The game's "Tap to continue" is a copy of the step's
## text below the panel, white with the black outline Unity uses on top of gameplay; a tap anywhere also continues,
## as before. level.gd opens it once, before the first play of L1 (Game.take_intro, s.meta.intro_seen):
## closed({"action": "tap"}) starts the level, whose own "tap a block" hint follows.

const UnityUI := preload("res://src/ui/unity_ui.gd")

const STEP := "GameObject/Step1"


func _build() -> void:
	# Hint (the step text, panel width - 40, 30 below the bottom-anchored panel like PopupFeedBack's spacing) and the
	# hidden Step2 are saved in scenes/tutorial_intro.tscn.
	ui = UnityUI.build(self, "MainTutorialLayer")
	# MainTutStep.SetActive(true): animator.enabled and CanvasGroup interactable + blocksRaycasts (the prefab saves
	# both off, so unity_ui.gd built the step without input).
	ui.animator(STEP).enabled = true
	var target: Button = ui.button(STEP + "/Hand/TargetButton")
	target.mouse_filter = Control.MOUSE_FILTER_STOP
	target.call("set_interactable", true)
	target.connect("clicked", _send.bind("tap"))
	ui.text(STEP + "/Panel/Canvas/Text (TMP)", tr("boot_tut_body"))
	UnityUI.set_text(%Hint, tr("boot_tap_continue"))


## A tap anywhere continues, like the stub before the prefab (MainTutStep only listens to TargetButton).
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_send("tap")
