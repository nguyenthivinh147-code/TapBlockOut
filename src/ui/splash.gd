extends "res://src/ui/stub_ui.gd"
## Wireframe 1.1 Splash / Loading. Layout of DownloadDataLayer (color-cube-match-puzzle): Loadingscreen art,
## logo, loading text, Slider and version (UIDownloadDataCoreLayer.loadingText / progressBar / versionText).
## CandySort_logo has the other game's name baked in, so the LogoGame slot shows the game's icon over the logo
## art's visible area, with the game's name and tagline below it as copies of the loading text.
## PopupLoginNoInternet stays inactive. A tap anywhere emits "tap", as before. Not wired to logic.

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")

const LAYER := "DownloadDataLayer"
const LOGO_TEX := "res://assets/icon_app.png"
## Visible part of CandySort_logo inside the 726 x 726 LogoGame rect (the art has transparent margins):
## 665 x 393 units, centred 10.5 units above the rect centre.
const LOGO_ART_H := 393.0
const LOGO_ART_DY := 10.5
## Game name below the logo: the loading text's style at the title size of SelectAccountLayer.Title.
const NAME_FS := 72.0
const NAME_SIZE := Vector2(800, 100)
## UIDownloadDataCoreLayer._minValue.
const SLIDER_MIN := 0.076


func _sample() -> Dictionary:
	return SampleData.SPLASH


func _build() -> void:
	ui = loading_screen(self, float(view.get("percent", 0)) / 100.0, tr("boot_loading") % int(view.get("percent", 0)),
		str(view.get("version", "")))
	_logo_text(ui)


## DownloadDataLayer as a loading screen: game logo, loading text, Slider at `value`, version (hidden when "").
static func loading_screen(owner: Control, value: float, loading: String, version: String) -> RefCounted:
	var v: RefCounted = UnityUI.build(owner, LAYER)
	v.show("PopupLoginNoInternet", false)
	var logo: Control = v.node("LogoGame")
	var r: Dictionary = logo.get_meta("u_rect")
	r.pos = Vector2((r.pos as Vector2).x, (r.pos as Vector2).y + LOGO_ART_DY)
	r.size = Vector2(LOGO_ART_H, LOGO_ART_H)
	UnityUI.apply_rect(logo)
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


## Copy of the loading text, centred `y` units above the screen centre.
static func text_copy(v: RefCounted, content: String, y: float, size: Vector2, fs: float) -> Label:
	var s := UnityKit.spec(LAYER, "Text (TMP)")
	s.n = "Text"
	s.erase("fit")
	s.ch = []
	s.r = [0.5, 0.5, 0.5, 0.5, 0.0, y, size.x, size.y, 0.5, 0.5]
	s.txt.fs = fs
	s.txt.auto = [18.0, fs]
	var l: Label = UnityKit.add(v.node(""), s).root
	UnityUI.set_text(l, content)
	return l


## Game name and tagline under the logo, where CandySort_logo shows its baked-in name.
func _logo_text(v: RefCounted) -> void:
	var logo_r: Dictionary = (v.node("LogoGame") as Control).get_meta("u_rect")
	var bottom := (logo_r.pos as Vector2).y - LOGO_ART_H * 0.5
	var name_l := text_copy(v, tr("APP_NAME"), bottom - NAME_SIZE.y * 0.5, NAME_SIZE, NAME_FS)
	name_l.name = "AppName"
	var loading: Array = UnityKit.spec(LAYER, "Text (TMP)").r
	var tag_h := float(loading[7])
	var tag := text_copy(v, tr("boot_tagline"), bottom - NAME_SIZE.y - tag_h * 0.5, Vector2(NAME_SIZE.x, tag_h), 56.0)
	tag.name = "Tagline"


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_send("tap")
