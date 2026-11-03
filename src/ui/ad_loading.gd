extends "res://src/ui/stub_ui.gd"
## Wireframe 11.1 Rewarded Ad Loading. No exported prefab: Unity's LoadingAdsPanel ("LoadingAds" under
## LoadingLayer in Prefabs/Manager/GameUIManager.prefab) is rebuilt here node by node with its saved RectTransforms,
## dim colour and TMP settings: full-screen dim, a 400-unit picture above the centre, the "Quick break" text in the
## middle and a 100-unit loading sign below. PlayShowAnimation scales the panel 0 -> 1 and fades its CanvasGroup in
## (0.5 s OutBack). Both images point at a sprite missing from the Unity project; the picture shows Unity's alarm
## clock (the game's waiting icon), the sign stays hidden (rotateSpeed 0, never animated). A tap anywhere emits
## "tap", as before. Not wired to logic.

const UnityUI := preload("res://src/ui/unity_ui.gd")

const CLOCK := "Resources_moved_UI_Maincenter:UI_Maincenter_7"
## LoadingAdsPanel.animDuration / easeType (LitMotion Ease.OutBack).
const SHOW_DUR := 0.5
const SHOW_EASE := 26


func _build() -> void:
	var canvas := _canvas()
	ui = UnityUI.build_subtree(_spec(tr("ads_loading")), canvas, canvas)
	ui.reveal_cfg = {"panel": ui.root, "dim": ui.root, "dur": SHOW_DUR, "ease": SHOW_EASE}
	UnityUI.play_reveal(ui)


## LoadingAds as saved in GameUIManager.prefab (CanvasGroup alpha 0, not blocking; PlayShowAnimation fades it in).
static func _spec(text: String) -> Dictionary:
	var img := func(id: String, n: String, r: Array, sp: Variant, c: String, active: bool = true) -> Dictionary:
		return {"n": n, "id": id, "a": active, "r": r,
			"img": {"sp": sp, "c": c, "t": 0, "pa": sp != null, "fc": true, "fm": 4, "fa": 1, "fo": 0, "ppu": 1, "rt": true, "on": true}}
	return {"n": "LoadingAds", "id": "panel", "a": true, "r": [0, 0, 1, 1, 0, 0, 0, 0, 0.5, 0.5],
		"cg": {"alpha": 0, "inter": false, "block": false},
		"ch": [
			img.call("dim", "Image", [0, 0, 1, 1, 0, 0, 0, 0, 0.5, 0.5], null, "000000f2"),
			{"n": "Text (TMP)", "id": "text", "a": true, "r": [0.5, 0.5, 0.5, 0.5, 0, 0, 500, 100, 0.5, 0.5],
				"txt": {"s": text, "fs": 60, "auto": null, "c": "ffffffff", "h": 2, "v": 512, "w": false, "ov": 0, "st": 16,
					"mat": "Baloo Bhaijaan Regular 400 SDF (atlas)", "cs": 0, "ws": 0, "ls": 0, "m": [0, 0, 0, 0], "rt": false, "on": true}},
			img.call("sign", "LoadingSign", [0.5, 0.5, 0.5, 0.5, 0, -111.4, 100, 100, 0.5, 0.5], null, "ffffffff", false),
			img.call("picture", "Picture", [0.5, 0.5, 0.5, 0.5, 0, 270, 400, 400, 0.5, 0.5], CLOCK, "ffffffff"),
		]}


## Canvas control like UnityUI.build makes (CanvasScaler fit), for a layer that has no exported prefab.
func _canvas() -> Control:
	var canvas := Control.new()
	canvas.name = "Canvas"
	canvas.set_meta("u_canvas", true)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	_fit(canvas)
	resized.connect(_fit.bind(canvas))
	return canvas


func _fit(canvas: Control) -> void:
	var vp := size if size.x > 0.0 and size.y > 0.0 else get_viewport_rect().size
	var s := UnityUI.canvas_scale(vp)
	canvas.scale = Vector2(s, s)
	canvas.position = Vector2.ZERO
	canvas.size = vp / s


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_send("tap")
