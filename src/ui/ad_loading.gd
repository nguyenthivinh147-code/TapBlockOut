extends "res://src/ui/stub_ui.gd"
## Wireframe 11.1 Rewarded Ad Loading. No exported prefab: Unity's LoadingAdsPanel ("LoadingAds" under
## LoadingLayer in Prefabs/Manager/GameUIManager.prefab) is rebuilt node by node in scenes/ad_loading.tscn with its
## saved RectTransforms, dim colour and TMP settings: full-screen dim, a 400-unit picture above the centre, the
## "Quick break" text in the middle and a 100-unit loading sign below. Its CanvasGroup is saved at alpha 0, not
## blocking; PlayShowAnimation scales the panel 0 -> 1 and fades it in (0.5 s OutBack). Both images point at a
## sprite missing from the Unity project; the picture shows Unity's alarm clock (the game's waiting icon), the sign
## stays hidden (rotateSpeed 0, never animated). Main shows it over everything while Game waits for a rewarded video
## (Game.ad_wait) and removes it when the wait ends; it swallows taps meanwhile.

const UnityUI := preload("res://src/ui/unity_ui.gd")

## LoadingAdsPanel.animDuration / easeType (LitMotion Ease.OutBack).
const SHOW_DUR := 0.5
const SHOW_EASE := 26


func _build() -> void:
	# Canvas fits the screen like UnityUI.build's CanvasScaler, for a layer that has no exported prefab.
	var canvas: Control = $Canvas
	_fit(canvas)
	resized.connect(_fit.bind(canvas))
	ui = UnityUI.adopt(%LoadingAds, canvas)
	ui.text("Text (TMP)", tr("ads_loading"))
	ui.reveal_cfg = {"panel": ui.root, "dim": ui.root, "dur": SHOW_DUR, "ease": SHOW_EASE}
	UnityUI.play_reveal(ui)


func _fit(canvas: Control) -> void:
	var vp := size if size.x > 0.0 and size.y > 0.0 else get_viewport_rect().size
	var s := UnityUI.canvas_scale(vp)
	canvas.scale = Vector2(s, s)
	canvas.position = Vector2.ZERO
	canvas.size = vp / s


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		accept_event()
