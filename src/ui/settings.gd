extends Control
## Settings (wireframe 10.3) on SettingMainMenuLayer of color-cube-match-puzzle: sound effects, vibration and music
## icons in the cream well, Support and Language pills, a Privacy Policy link row, the version under the popup's right
## edge. The game's extras are copies of prefab nodes: a notifications toggle (copy of Vibrate, the well split in 4),
## Restore purchases / UI preview rows and the restore result (copies of PolicyButton, one 78-unit row each; the popup
## grows like GameplaySettingsUI.OnPurchasedAds). Language opens SettingLanguage (popup_language.gd). Static nodes
## are in scenes/settings.tscn; the link rows depend on the platform, the build and the restore result: built here.
## 10 quick taps on the version open the tester menu (tester_menu.gd); after it saves or deletes the account,
## Settings closes so Main rebuilds Home. setup(args: Dictionary); signal closed(result).

signal closed(result: Variant)

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UView := preload("res://src/ui/u_view.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")
const Config := preload("res://src/config.gd")
const PopupLanguage := preload("res://src/ui/popup_language.gd")

const LAYER := "SettingMainMenuLayer"
const PANEL := "Panel/PauseMenu"
const CONTENT := "Panel/PauseMenu/Content"
const WELL := "Panel/PauseMenu/Content/SettingBtn/Content"
const POLICY := "Panel/PauseMenu/Content/PolicyButton"
## Game setting -> prefab icon button and its ImageStateKeeper sprites (UI_Maincenter_<on>, _<off>).
## notif has no prefab button: Toggle_notif in the scene is a copy of Vibrate with ic_clock, greyed when off.
const TOGGLES: Array[Dictionary] = [
	{"key": "sfx", "node": "Mute", "on": 28, "off": 29},
	{"key": "haptics", "node": "Vibrate", "on": 40, "off": 41},
	{"key": "music", "node": "Sound", "on": 42, "off": 43},
	{"key": "notif", "node": ""},
]
const OFF_TINT := Color(0.55, 0.55, 0.55, 0.9)
## ImageStateKeeper is not exported, so its off sprites are missing from _sprites.json: rects (top-left origin) from
## Resources_moved/Sprites/UI_Maincenter.png.meta.
const STATE_TEX := "res://assets/ui/cc/Resources_moved_UI_Maincenter.png"
const STATE_SRC := 2048.0
const STATE_RECTS := {29: Rect2(300, 617, 96, 96), 41: Rect2(100, 719, 96, 96), 43: Rect2(298, 719, 96, 96)}
const MAINCENTER := "Resources_moved_UI_Maincenter:UI_Maincenter_%d"
## PolicyButton row: centre 80.9 above the panel bottom, 78 tall; each extra row adds one row height.
const ROW_Y := 80.9
const ROW_H := 78.0
const PANEL_SIZE := Vector2(724, 559)
const VERSION_Y := -330.0
const INK := "1c4a83ff"
const GALLERY := "res://scenes/ui_gallery.tscn"
const TESTER := "res://scenes/tester_menu.tscn"
const TESTER_TAPS := 10
const TAP_GAP_MS := 1500

## Test thay được để không mở mailto thật. Mặc định OS.shell_open.
var opener: Callable = Callable()
var ui: UView = null
var toggle_buttons: Dictionary = {}
var lang_buttons: Dictionary = {}
var privacy_button: Button = null
var restore_button: Button = null
var gallery_button: Button = null
var support_button: Button = null
var language_button: Button = null
var version_button: Button = null
var close_button: Button = null
var language_panel: Control = null
var tester_panel: Control = null
var status_label: Label = null
var last_url: String = ""

var _built: bool = false
var _rows: Array[Control] = []
var _version_label: Label = null
var _lang: Dictionary = {}
var _version_taps: int = 0
var _last_tap_ms: int = 0
var _busy: bool = false
var _status_text: String = ""


func setup(_args: Dictionary = {}) -> void:
	_build()


func _ready() -> void:
	_build()


func version_text() -> String:
	return str(Config.CONTENT.build)


func support_url() -> String:
	var subject := "%s (%s)" % [tr("settings_support_subject"), str(Config.CONTENT.build)]
	return "mailto:%s?subject=%s" % [str(Config.CONTENT.support_email), subject.uri_encode()]


func _open_url(url: String) -> void:
	last_url = url
	if opener.is_valid():
		opener.call(url)
	else:
		OS.shell_open(url)


func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# The toggles (Notif is a copy of Vibrate), the hidden Policy and Terms rows and VersionButton are nodes of
	# scenes/settings.tscn; the link rows under the pills are built by _layout_rows.
	ui = UnityUI.build(self, LAYER)
	# Layer nodes keep their prefab names in the scene (a renamed instanced node loses its overrides).
	close_button = ui.on_click("Panel/PauseMenu/Top/btnTurnOff", close)
	close_button.name = "CloseX"
	ui.on_click("Bg", close)
	support_button = ui.on_click(CONTENT + "/btnSupport", _on_support)
	support_button.name = "SupportButton"
	language_button = ui.on_click(CONTENT + "/btnLanguage", open_language)
	language_button.name = "LanguageButton"
	_wire_toggles()
	version_button = %VersionButton
	_version_label = version_button.get_node("VersionText") as Label
	version_button.connect("clicked", _on_version)
	_apply_texts()


## Prefab icons for sfx, vibration, music and the Notif copy of Vibrate. MainMenuSettingsUI.InitLayer sets each
## ImageStateKeeper from the saved setting.
func _wire_toggles() -> void:
	for def in TOGGLES:
		var key := str(def.key)
		var b: Button = null
		if str(def.node) != "":
			b = ui.button(WELL + "/" + str(def.node))
			b.name = "Toggle_" + key
		else:
			b = %Toggle_notif
			# Not in the prefab's UIAnimationGroup: play its ScaleAppear with the group (OnShowLayer).
			var v: RefCounted = ui.sub(b)
			var id := str((b.get_meta("u") as Dictionary).get("id", ""))
			_appear_later.call_deferred(b, v.anims.get(id, Callable()) if v != null else Callable())
		b.connect("clicked", _on_toggle.bind(key))
		toggle_buttons[key] = b
		_show_toggle(key)


func _show_toggle(key: String) -> void:
	var b: Control = toggle_buttons.get(key)
	if b == null:
		return
	var on := bool(Game.s.settings.get(key, true))
	var icon: Control = b.get_node("Image")
	for def in TOGGLES:
		if str(def.key) != key:
			continue
		if def.has("on"):
			set_state_sprite(icon, int(def.on) if on else int(def.off))
		else:
			icon.modulate = Color.WHITE if on else OFF_TINT


## UI_Maincenter_<n> on an Image node, including the ImageStateKeeper sprites _sprites.json lacks (STATE_RECTS).
static func set_state_sprite(c: Control, n: int) -> void:
	if not STATE_RECTS.has(n):
		UnityUI.set_sprite(c, MAINCENTER % n)
		return
	var img := UnityUI.image_of(c)
	var tex := load(STATE_TEX) as Texture2D
	if img == null or tex == null:
		return
	var k := float(tex.get_width()) / STATE_SRC
	var r: Rect2 = STATE_RECTS[n]
	img.call("set_texture", tex, Rect2(r.position * k, r.size * k), Vector4.ZERO, 1.0 / k)


## Every visible string (also after a language change, like I2 Localize updating in place).
func _apply_texts() -> void:
	ui.text("Panel/PauseMenu/Image/txtHeader", tr("settings_title"))
	ui.text(CONTENT + "/btnSupport/Text (TMP)", tr("settings_support"))
	ui.text(CONTENT + "/btnLanguage/Out", tr("settings_language"))
	UnityUI.set_text(_version_label, version_text())
	_layout_rows()
	if language_panel != null:
		_fill_language()


## Link rows under the pills (Privacy, Restore, UI preview) and the restore result, bottom-up like PolicyButton.
func _layout_rows() -> void:
	for c in _rows:
		if is_instance_valid(c):
			c.queue_free()
	_rows.clear()
	privacy_button = null
	restore_button = null
	gallery_button = null
	status_label = null
	var defs: Array[Array] = []
	if Platform.has_privacy:
		defs.append(["PrivacyButton", tr("settings_privacy"), _on_privacy])
	defs.append(["RestoreButton", tr("settings_restore"), _on_restore])
	if Config.ui_preview():
		defs.append(["GalleryButton", tr("settings_gallery"), _on_gallery])
	if _status_text != "":
		defs.append(["StatusLabel", _status_text, Callable()])
	var n := defs.size()
	var grow := ROW_H * (n - 1)
	UnityKit.set_size(ui.node(PANEL), PANEL_SIZE + Vector2(0, grow))
	var vr: Dictionary = version_button.get_meta("u_rect")
	vr.pos = Vector2((vr.pos as Vector2).x, VERSION_Y - grow * 0.5)
	UnityUI.apply_rect(version_button)
	for i in n:
		var d: Array = defs[i]
		var s := UnityKit.spec(LAYER, POLICY)
		s.r[5] = ROW_Y + ROW_H * (n - 1 - i)
		var row: Control = null
		if (d[2] as Callable).is_valid():
			s.n = str(d[0])
			var v: RefCounted = UnityKit.add(ui.node(CONTENT), s)
			row = v.root
			var l: Label = v.text("Text (TMP)", str(d[1]))
			underline(l)
			row.connect("clicked", d[2])
		else:
			# Plain line in the row's place: PolicyButton's text without bold or underline, body ink.
			var t: Dictionary = (s.ch as Array)[0]
			var text_h := ROW_H + float(t.r[7])
			t.n = "StatusLabel"
			t.r = (s.r as Array).duplicate()
			t.r[7] = text_h
			t.txt.st = 0
			t.txt.c = INK
			t.txt.s = str(d[1])
			row = UnityKit.add(ui.node(CONTENT), t).root
			status_label = row as Label
		row.set_meta("u_rt", true)
		_rows.append(row)
		match str(d[0]):
			"PrivacyButton":
				privacy_button = row as Button
			"RestoreButton":
				restore_button = row as Button
			"GalleryButton":
				gallery_button = row as Button


## TMP Underline (fontStyle 4) is not drawn by unity_ui.gd: a line under the text in its colour, refitted when the
## label resizes or auto-sizes (TMP underline: about 6% thick, 8% below the baseline). A line the scene already holds
## (child "Underline") is reused.
static func underline(l: Label) -> void:
	var line := l.get_node_or_null("Underline") as ColorRect
	if line == null:
		line = ColorRect.new()
		line.name = "Underline"
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_child(line)
	l.resized.connect(_fit_underline.bind(l, line))
	_fit_underline.call_deferred(l, line)


## Variant args: the label may be freed before the deferred call (tests build and free in one frame).
static func _fit_underline(lv: Variant, linev: Variant) -> void:
	if not is_instance_valid(lv) or not is_instance_valid(linev):
		return
	var l: Label = lv
	var line: ColorRect = linev
	var font := l.get_theme_font("font")
	var fs := l.get_theme_font_size("font_size")
	var w := font.get_string_size(l.text.to_upper() if l.uppercase else l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base := (l.size.y - font.get_height(fs)) * 0.5 + font.get_ascent(fs)
	line.color = l.get_theme_color("font_color")
	var x := (l.size.x - w) * 0.5 if l.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER else 0.0
	line.position = Vector2(x, base + fs * 0.08)
	line.size = Vector2(w, maxf(2.0, fs * 0.06))


## Runs a builder animation later only if its node still exists (its lambda would get a freed capture).
static func _appear_later(node: Variant, cb: Callable) -> void:
	if is_instance_valid(node) and cb.is_valid():
		cb.call()


func _on_toggle(key: String) -> void:
	Game.set_setting(key, not bool(Game.s.settings.get(key, true)))
	_show_toggle(key)


# --- Language (SettingLanguage) ---

func open_language() -> void:
	if language_panel != null:
		return
	language_panel = Control.new()
	language_panel.name = "LanguagePanel"
	language_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(language_panel)
	var rows: Array = []
	for code in Game.LANGS:
		rows.append([code, PopupLanguage.label_key(code)])
	_lang = PopupLanguage.build_layer(language_panel, rows, true)
	lang_buttons = _lang.buttons
	for value in lang_buttons:
		(lang_buttons[value] as Button).connect("clicked", _on_language.bind(str(value)))
	var ok: Button = _lang.save
	ok.name = "LanguageOk"
	ok.connect("clicked", close_language)
	for b in _lang.close:
		(b as Button).connect("clicked", close_language)
	_fill_language()


func _fill_language() -> void:
	var v: RefCounted = _lang.ui
	v.text("Panel/PauseMenu/Image/txtHeader", tr("settings_language"))
	v.text("Panel/PauseMenu/Content/Save/Out", tr("common_ok"))
	# No "device language" cell (the prefab holds the 14 languages): the device locale applies until one is picked.
	var cur: String = Game.current_lang()
	for code in Game.LANGS:
		var b: Button = lang_buttons[code]
		UnityUI.set_text(b.get_node("Txt") as Label, tr(PopupLanguage.label_key(code)))
		b.button_pressed = cur == code


func close_language() -> void:
	if language_panel != null:
		language_panel.queue_free()
		language_panel = null
		lang_buttons = {}
		_lang = {}


func _on_language(value: String) -> void:
	Game.set_setting("lang", value)
	_status_text = ""
	# Texts follow the new language in place; the Language popup stays open.
	_apply_texts()


# --- links ---

func _on_privacy() -> void:
	Platform.open_privacy()


func _on_restore() -> void:
	if _busy:
		return
	_busy = true
	restore_button.call("set_interactable", false)
	var ok: bool = await Game.restore_purchases()
	_busy = false
	if not is_inside_tree():
		return
	_status_text = tr("shop_restore_ok") if ok else tr("shop_restore_none")
	_layout_rows()


func _on_support() -> void:
	_open_url(support_url())


func _on_version() -> void:
	var t := Time.get_ticks_msec()
	if t - _last_tap_ms > TAP_GAP_MS:
		_version_taps = 0
	_last_tap_ms = t
	_version_taps += 1
	if _version_taps >= TESTER_TAPS:
		_version_taps = 0
		open_tester()


func open_tester() -> void:
	if tester_panel != null:
		return
	tester_panel = (load(TESTER) as PackedScene).instantiate() as Control
	add_child(tester_panel)
	tester_panel.call("setup", {})
	tester_panel.connect("closed", _on_tester_closed)


func close_tester() -> void:
	if tester_panel != null:
		tester_panel.queue_free()
		tester_panel = null


## The account changed (or was deleted, settings included): Settings closes and Main rebuilds Home.
func _on_tester_closed(result: Variant) -> void:
	close_tester()
	if result is Dictionary:
		close()


## Danh sách các màn đã dựng UI nhưng chưa nối logic (chỉ có khi Config.ui_preview).
func _on_gallery() -> void:
	var node := (load(GALLERY) as PackedScene).instantiate()
	add_child(node)
	node.call("setup", {})
	node.connect("closed", func(_r: Variant) -> void: node.queue_free())


func close() -> void:
	closed.emit(null)
