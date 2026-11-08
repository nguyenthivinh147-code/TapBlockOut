extends "res://src/ui/stub_ui.gd"
## Wireframe 1.1 Splash / Loading. Layout of DownloadDataLayer (color-cube-match-puzzle): loading art, logo,
## loading text, Slider and version (UIDownloadDataCoreLayer.loadingText / progressBar / versionText).
## The game's own art replaces Loadingscreen and CandySort_logo: the 9:16 candy scene under BGLoading and the game
## logo (name and tagline baked in) in LogoGame, both laid out as the engine draws the boot splash (the same scene
## with the logo baked in), so the loading screen takes over from it without moving or resizing on any screen.
## PopupLoginNoInternet stays inactive. A tap anywhere emits "tap", as before.
## Main shows it while Game.boot() runs and moves the bar with set_progress(). The layer and LoadingArt are nodes of
## scenes/splash.tscn; loading_screen() sets the rest each time, since download_data.gd and owners without that scene
## share it.

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")

const LAYER := "DownloadDataLayer"
const BG_TEX := "res://assets/ui/loading_bg.png"
const LOGO_TEX := "res://assets/ui/loading_logo.png"
## The icon that rides the bar's fill edge: a peppermint from the candy set of the loading art (candy_curtain.gd)
## instead of the prefab's orange diamond.
const HANDLE := "Slider/Handle Slide Area/Handle"
const HANDLE_TEX := "res://assets/ui/candy_drop/candy_drop_00.png"
## UIDownloadDataCoreLayer._minValue.
const SLIDER_MIN := 0.076
## Size of application/boot_splash/image (assets/ui/boot_splash.png) and of BG_TEX, in px.
const BOOT_SIZE := Vector2(1152, 2048)
## Where boot_splash.png has the logo, in px of that image: LOGO_TEX scaled 1.102 over BG_TEX, measured by pixel
## difference. Redo it when either image changes. On the 886x1920 reference screen it is LogoGame's prefab rect.
const LOGO_RECT := Rect2(187.6, 84.3, 774.7, 577.4)


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
	# BGLoading is a 1920-unit square; the portrait art fills the whole layer instead, in BGLoading's place.
	var bg_slot: Control = v.node("BGLoading")
	bg_slot.visible = false
	var art := bg_slot.get_parent().get_node_or_null("LoadingArt") as ColorRect
	if art == null:
		art = ThemeKit.make_image_background(BG_TEX, Color(0, 0, 0, 0))
		art.name = "LoadingArt"
		bg_slot.add_sibling(art)
		art.get_parent().move_child(art, bg_slot.get_index())
	# What the boot splash shows where the image does not reach (side bars on screens wider than it, Keep Height).
	art.color = ProjectSettings.get_setting("application/boot_splash/bg_color", art.color)
	var logo: Control = v.image("LogoGame")
	logo.set("preserve_aspect", true)
	v.texture("LogoGame", load(LOGO_TEX) as Texture2D)
	# loadingDot cycles "", ".", "..", "..." after the text; the game's strings carry their own dots.
	v.text("Text (TMP)/Text (TMP) (1)", "")
	# Auto size with a horizontal ContentSizeFitter: relayout widens the rect to the text at the max size.
	v.text("Text (TMP)", loading)
	v.text("Version", version)
	v.show("Version", version != "")
	var handle: Control = v.image(HANDLE)
	handle.set("preserve_aspect", true)
	v.texture(HANDLE, load(HANDLE_TEX) as Texture2D)
	v.slider("Slider", maxf(value, SLIDER_MIN))
	v.relayout("")
	_fit_art(art, logo)
	# Bound callables of one method compare equal: is_connected finds an earlier build's handler.
	var fit := _fit_art.bind(art, logo)
	if not art.resized.is_connected(fit):
		art.resized.connect(fit)
	return v


## Lays the art out where the engine draws the boot splash on this screen: the background image in boot_rect() and
## LogoGame (a sibling of the art) at LOGO_RECT of it. The prefab's LogoGame rect would only match it on screens as
## tall as the reference: it follows the canvas scale, not the image.
static func _fit_art(art: Control, logo: Control) -> void:
	if not (is_instance_valid(art) and is_instance_valid(logo)):
		return
	var mode := int(ProjectSettings.get_setting("application/boot_splash/stretch_mode",
		RenderingServer.SPLASH_STRETCH_MODE_COVER))
	var r := boot_rect(art.size, mode)
	var pic := art.get_node_or_null("Image") as TextureRect
	if pic != null:
		pic.stretch_mode = TextureRect.STRETCH_SCALE
		pic.set_anchors_preset(Control.PRESET_TOP_LEFT)
		pic.position = r.position
		pic.size = r.size
	var k := r.size / BOOT_SIZE
	logo.set_anchors_preset(Control.PRESET_TOP_LEFT)
	logo.position = art.position + r.position + LOGO_RECT.position * k
	logo.size = LOGO_RECT.size * k


## Rect the engine draws a BOOT_SIZE boot splash image in on a screen of `area`, for a
## RenderingServer.SplashStretchMode as RenderingServer::get_splash_stretched_screen_rect. Disabled and Keep are not
## followed (they fall to Cover); tests/test_splash_art.gd checks the project uses another mode.
static func boot_rect(area: Vector2, mode: int) -> Rect2:
	if area.x <= 0.0 or area.y <= 0.0:
		return Rect2()
	var by_width := Vector2(area.x, BOOT_SIZE.y * area.x / BOOT_SIZE.x)
	var by_height := Vector2(BOOT_SIZE.x * area.y / BOOT_SIZE.y, area.y)
	var s := area
	match mode:
		RenderingServer.SPLASH_STRETCH_MODE_KEEP_WIDTH:
			s = by_width
		RenderingServer.SPLASH_STRETCH_MODE_KEEP_HEIGHT:
			s = by_height
		RenderingServer.SPLASH_STRETCH_MODE_IGNORE:
			s = area
		_:
			s = by_width if area.x / area.y > BOOT_SIZE.x / BOOT_SIZE.y else by_height
	return Rect2((area - s) / 2.0, s)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_send("tap")
