extends "res://src/ui/stub_ui.gd"
## Wireframe 10.2 Change Name. Layout of PopupEditNameLayer (color-cube-match-puzzle): rules label, the
## TMP_InputField (here a LineEdit in its Text Area, styled like its Text and Placeholder), SaveButton as the game's
## OK, closeButtons close. BuyButton stays inactive. Unity reports a rejected name with the PopupFeedBack toast
## (ShowPopupFeedBackLayer), so the game's "name taken" error is that toast. Not wired to logic.

const UnityUI := preload("res://src/ui/unity_ui.gd")

const INPUT := "Panel/ProfileMenu/PlayerInfo/InputField (TMP)"

var name_input: LineEdit = null


func _sample() -> Dictionary:
	return SampleData.PROFILE_NAME


func _build() -> void:
	ui = UnityUI.build(self, "PopupEditNameLayer")
	ui.text("Panel/ProfileMenu/Image/txtHeader", tr("profile_name_title"))
	ui.text("Panel/ProfileMenu/PlayerInfo/Label", tr("profile_name_rules"))
	ui.text("Panel/ProfileMenu/SaveButton/Text (TMP)", tr("common_ok"))
	ui.on_click("Panel/ProfileMenu/SaveButton", _send.bind("ok"))
	for b in ui.field("closeButtons", "PopupEditNameUICoreLayer"):
		(b as Button).connect("clicked", _send.bind("close"))
	_name_input()
	if bool(view.get("error", false)):
		_toast(tr("profile_name_taken"))


## TMP_InputField (a LineEdit from unity_ui.gd, characterLimit from the prefab); the Placeholder shows while empty.
func _name_input() -> void:
	ui.text(INPUT + "/Text Area/Placeholder", tr("profile_nickname"))
	name_input = ui.input(INPUT) as LineEdit
	name_input.name = "NameInput"
	ui.input_text(INPUT, str(view.get("name", "")))


## PopupFeedbackUICoreLayer.SetupData with a content only: the title label carries it, the content label hides;
## AnimFadeInFadeOut fades the layer in while the panel scales 0 -> 1, holds, then fades out.
func _toast(content: String) -> void:
	var toast: RefCounted = UnityUI.build(self, "PopupFeedBack")
	toast.show("Panel/Text (TMP) (1)", false)
	toast.text("Panel/Text (TMP)", content)
	toast.relayout("Panel")
	var cs: Dictionary = {}
	for e in toast.scripts:
		if str(e.cs.get("name", "")) == "PopupFeedbackUICoreLayer":
			cs = e.cs
	var fade := float(cs.get("fadeDuration", 0.5))
	var hold := float(cs.get("showDuration", 2.0))
	var layer: Control = toast.root
	var panel: Control = toast.node("Panel")
	layer.modulate.a = 0.0
	panel.scale = Vector2.ZERO
	var tw := layer.create_tween()
	tw.tween_property(layer, "modulate:a", 1.0, fade)
	tw.parallel().tween_property(panel, "scale", Vector2.ONE, fade)
	tw.tween_interval(hold)
	tw.tween_property(layer, "modulate:a", 0.0, fade)
	tw.tween_callback(func() -> void: layer.visible = false)
