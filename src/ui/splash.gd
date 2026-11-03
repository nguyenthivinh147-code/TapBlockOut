extends "res://src/ui/stub_ui.gd"
## Wireframe 1.1 Splash / Loading. Layout of DownloadDataLayer (color-cube-match-puzzle): loading art, logo,
## loading text, Slider and version (UIDownloadDataCoreLayer.loadingText / progressBar / versionText).
## The game's own art replaces Loadingscreen and CandySort_logo: a 9:16 candy scene scaled to cover the screen
## under BGLoading, and the game logo (name and tagline baked in) fitted to the LogoGame rect.
## PopupLoginNoInternet stays inactive. A tap anywhere emits "tap", as before.
## Main shows it while Game.boot() runs and moves the bar with set_progress(). The layer and LoadingArt are nodes of
## scenes/splash.tscn; loading_screen() sets the rest each time, since download_data.gd and owners without that scene
## share it.

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")

const LAYER := "DownloadDataLayer"
const BG_TEX := "res://assets/ui/loading_bg.png"
const LOGO_TEX := "res://assets/ui/loading_logo.png"
## UIDownloadDataCoreLayer._minValue.
const SLIDER_MIN := 0.076


func _sample() -> Dictionary:
	return SampleData.SPLASH


func _build() -> void:
	ui = loading_screen(self, float(view.get("percent", 0)) / 100.0, tr("boot_loading") % int(view.get("percent", 0)),
		str(view.get("version", "")))


## Bar and loading text at `value` (0..1). tr() runs each time, so the text follows the language boot applies.
func set_progress(value: float) -> void:
	if ui == null:
		return
	ui.text("Text (TMP)", tr("boot_loading") % roundi(value * 100.0))
	ui.slider("Slider", maxf(value, SLIDER_MIN))


## DownloadDataLayer as a loading screen: game logo, loading text, Slider at `value`, version (hidden when "").
## The owner's scene may already hold the layer with LoadingArt (scenes/splash.tscn, download_data.tscn); otherwise
## both are built here.
static func loading_screen(owner: Control, value: float, loading: String, version: String) -> RefCounted:
	var v: RefCounted = UnityUI.build(owner, LAYER)
	v.show("PopupLoginNoInternet", false)
	# BGLoading is a 1920-unit square; the portrait art covers the whole layer instead, in BGLoading's place.
	var bg_slot: Control = v.node("BGLoading")
	bg_slot.visible = false
	if bg_slot.get_parent().get_node_or_null("LoadingArt") == null:
		var bg := ThemeKit.make_image_background(BG_TEX, Color(0, 0, 0, 0))
		bg.name = "LoadingArt"
		bg_slot.add_sibling(bg)
		bg.get_parent().move_child(bg, bg_slot.get_index())
	var img: Control = v.image("LogoGame")
	img.set("preserve_aspect", true)
	v.texture("LogoGame", load(LOGO_TEX) as Texture2D)
	# loadingDot cycles "", ".", "..", "..." after the text; the game's strings carry their own dots.
	v.text("Text (TMP)/Text (TMP) (1)", "")
	# Auto size with a horizontal ContentSizeFitter: relayout widens the rect to the text at the max size.
	v.text("Text (TMP)", loading)
	v.text("Version", version)
	v.show("Version", version != "")
	v.slider("Slider", maxf(value, SLIDER_MIN))
	v.relayout("")
	return v


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_send("tap")
