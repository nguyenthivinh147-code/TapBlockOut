extends "res://src/ui/stub_ui.gd"
## Wireframe 1.5 First-time Tutorial. Layout of MainTutorialLayer (color-cube-match-puzzle): Step1 is the active
## step (MainTutorialOverlay.PlayStep(1)): its Animator plays TutController_Step1 (hand press, tap rings) and its
## TargetButton under the hand continues. Step2 stays hidden. The game's "Tap to continue" is a copy of the step's
## text below the panel, white with the black outline Unity uses on top of gameplay; a tap anywhere also continues,
## as before. Not wired to logic.

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")

const STEP := "GameObject/Step1"
## Gap between the step panel and the hint, as PopupFeedBack's VerticalLayoutGroup spacing.
const HINT_GAP := 30.0
const HINT_H := 72.0


func _build() -> void:
	ui = UnityUI.build(self, "MainTutorialLayer")
	ui.show("GameObject/Step2", false)
	# MainTutStep.SetActive(true): animator.enabled and CanvasGroup interactable + blocksRaycasts (the prefab saves
	# both off, so unity_ui.gd built the step without input).
	ui.animator(STEP).enabled = true
	var target: Button = ui.button(STEP + "/Hand/TargetButton")
	target.mouse_filter = Control.MOUSE_FILTER_STOP
	target.call("set_interactable", true)
	target.connect("clicked", _send.bind("tap"))
	ui.text(STEP + "/Panel/Canvas/Text (TMP)", tr("boot_tut_body"))
	var hint := UnityKit.spec("MainTutorialLayer", STEP + "/Panel/Canvas/Text (TMP)")
	hint.n = "Hint"
	# Same width as the step text (panel width - 40), centred below the bottom-anchored panel.
	var panel_r: Array = UnityKit.spec("MainTutorialLayer", STEP + "/Panel").r
	var bottom := float(panel_r[5]) - float(panel_r[7]) * 0.5
	hint.r = [0.5, 0, 0.5, 0, 0, bottom - HINT_GAP - HINT_H * 0.5, float(panel_r[6]) - 40.0, HINT_H, 0.5, 0.5]
	hint.txt.c = "ffffffff"
	hint.txt.mat = "Baloo Outline - Black"
	hint.txt.w = false
	UnityKit.add(ui.node(STEP), hint).text("", tr("boot_tap_continue"))


## A tap anywhere continues, like the stub before the prefab (MainTutStep only listens to TargetButton).
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_send("tap")
