extends Control
## Cài đặt: âm thanh, nhạc, rung, thông báo, mũi tên, ngôn ngữ, Privacy, Restore, hỗ trợ, phiên bản.
## Chạm nhiều lần vào dòng phiên bản mở menu tester. setup(args: Dictionary); signal closed(result).

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const Config := preload("res://src/config.gd")

const TOGGLES: Array[Dictionary] = [
	{"key": "sfx", "label": "settings_sound"},
	{"key": "music", "label": "settings_music"},
	{"key": "haptics", "label": "settings_haptics"},
	{"key": "notif", "label": "settings_notifications"},
	{"key": "arrows", "label": "settings_arrows"},
]
const LANGS: Array[Dictionary] = [
	{"value": "", "label": "settings_language_auto"},
	{"value": "en", "label": "settings_language_en"},
	{"value": "vi", "label": "settings_language_vi"},
]
const TESTER_TAPS := 7
const TAP_GAP_MS := 1500

## Test thay được để không mở mailto thật. Mặc định OS.shell_open.
var opener: Callable = Callable()
var toggle_buttons: Dictionary = {}
var lang_buttons: Dictionary = {}
var privacy_button: Button = null
var restore_button: Button = null
var support_button: Button = null
var version_button: Button = null
var close_button: Button = null
var tester_panel: Control = null
var debugger_button: Button = null
var status_label: Label = null
var last_url: String = ""

var _content: Control = null
var _version_taps: int = 0
var _last_tap_ms: int = 0
var _busy: bool = false
var _status_text: String = ""


func setup(_args: Dictionary = {}) -> void:
	if _content == null:
		_build()


func _ready() -> void:
	if _content == null:
		_build()
	ThemeKit.popup_in(_content)


func version_text() -> String:
	return tr("settings_version") % str(Config.CONTENT.build)


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
	if _content != null:
		_content.queue_free()
		_content = null
	for c in get_children():
		c.queue_free()
	toggle_buttons.clear()
	lang_buttons.clear()
	privacy_button = null
	tester_panel = null
	debugger_button = null

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_content = ThemeKit.make_panel()
	center.add_child(_content)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	_content.add_child(box)
	var title := ThemeKit.make_label(tr("settings_title"), ThemeKit.FS_TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 820)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 14)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)

	for def in TOGGLES:
		rows.add_child(_toggle_row(str(def.key), str(def.label)))
	var note := ThemeKit.make_label(tr("settings_notifications_off"), ThemeKit.FS_SMALL, ThemeKit.TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(560, 0)
	note.visible = bool(Game.s.settings.get("notif", true)) and not Platform.enabled()
	note.name = "NotifNote"
	rows.add_child(note)

	rows.add_child(ThemeKit.make_label(tr("settings_language"), ThemeKit.FS_BODY, ThemeKit.TEXT_DIM))
	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 10)
	rows.add_child(lang_row)
	var cur_lang := str(Game.s.settings.get("lang", ""))
	for def in LANGS:
		var b := ThemeKit.make_button(tr(str(def.label)), "primary" if cur_lang == str(def.value) else "secondary")
		b.add_theme_font_size_override("font_size", ThemeKit.FS_SMALL)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_language.bind(str(def.value)))
		lang_row.add_child(b)
		lang_buttons[str(def.value)] = b

	if Platform.has_privacy:
		privacy_button = ThemeKit.make_button(tr("settings_privacy"), "secondary")
		privacy_button.pressed.connect(_on_privacy)
		rows.add_child(privacy_button)
	restore_button = ThemeKit.make_button(tr("settings_restore"), "secondary")
	restore_button.pressed.connect(_on_restore)
	rows.add_child(restore_button)
	support_button = ThemeKit.make_button(tr("settings_support"), "secondary")
	support_button.pressed.connect(_on_support)
	rows.add_child(support_button)

	status_label = ThemeKit.make_label(_status_text, ThemeKit.FS_SMALL, ThemeKit.GOLD)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(560, 0)
	rows.add_child(status_label)

	version_button = ThemeKit.make_button(version_text(), "ghost")
	version_button.add_theme_font_size_override("font_size", ThemeKit.FS_SMALL)
	version_button.add_theme_color_override("font_color", ThemeKit.TEXT_DIM)
	version_button.pressed.connect(_on_version)
	rows.add_child(version_button)

	close_button = ThemeKit.make_button(tr("settings_close"), "primary")
	close_button.pressed.connect(close)
	box.add_child(close_button)


func _toggle_row(key: String, label_key: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := ThemeKit.make_label(tr(label_key), ThemeKit.FS_BODY)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(300, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var on := bool(Game.s.settings.get(key, true))
	var b := ThemeKit.make_button(tr("settings_on") if on else tr("settings_off"), "primary" if on else "secondary")
	b.custom_minimum_size = Vector2(160, 96)
	b.toggle_mode = false
	b.pressed.connect(_on_toggle.bind(key))
	row.add_child(b)
	toggle_buttons[key] = b
	return row


func _on_toggle(key: String) -> void:
	Sfx.play("sfx_button")
	var on := bool(Game.s.settings.get(key, true))
	Game.set_setting(key, not on)
	_build()


func _on_language(value: String) -> void:
	Sfx.play("sfx_button")
	Game.set_setting("lang", value)
	_status_text = ""
	_build()


func _on_privacy() -> void:
	Sfx.play("sfx_button")
	Platform.open_privacy()


func _on_restore() -> void:
	if _busy:
		return
	_busy = true
	Sfx.play("sfx_button")
	restore_button.disabled = true
	var ok: bool = await Game.restore_purchases()
	_busy = false
	if not is_inside_tree():
		return
	_status_text = tr("shop_restore_ok") if ok else tr("shop_restore_none")
	_build()


func _on_support() -> void:
	Sfx.play("sfx_button")
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
	tester_panel = Control.new()
	tester_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(tester_panel)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	tester_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tester_panel.add_child(center)
	var panel := ThemeKit.make_panel()
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	v.custom_minimum_size = Vector2(520, 0)
	panel.add_child(v)
	var l := ThemeKit.make_label(tr("settings_tester_title"), ThemeKit.FS_TITLE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	debugger_button = ThemeKit.make_button(tr("settings_tester_debugger"), "video")
	debugger_button.pressed.connect(_on_debugger)
	v.add_child(debugger_button)
	var done := ThemeKit.make_button(tr("settings_close"), "secondary")
	done.pressed.connect(close_tester)
	v.add_child(done)


func close_tester() -> void:
	if tester_panel != null:
		tester_panel.queue_free()
		tester_panel = null
		debugger_button = null


func _on_debugger() -> void:
	Sfx.play("sfx_button")
	Platform.open_debugger()


func close() -> void:
	Sfx.play("sfx_button")
	closed.emit(null)
