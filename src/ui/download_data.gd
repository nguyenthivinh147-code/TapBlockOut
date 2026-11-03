extends "res://src/ui/stub_ui.gd"
## Wireframe 1.3 Download Resources. DownloadDataLayer (color-cube-match-puzzle) as in splash.gd: the Slider and
## loading text show the download progress. The game's choice is DownloadDataLayer's own dialog,
## PopupLoginNoInternet: title, two-line message (subtitle, size needed), Cancel as Skip and Ok as Download in its
## button row. The panel grows by the two network options, each a copy of PopupEditNameLayer's input field art
## with its text style and a check (on) or cross (off), spaced like that prefab's label and field. Not wired to logic.

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")
const Splash := preload("res://src/ui/splash.gd")

const POP := "PopupLoginNoInternet"
const FIELD_LAYER := "PopupEditNameLayer"
const FIELD := "Panel/ProfileMenu/PlayerInfo/InputField (TMP)"
## PopupEditNameLayer: gap between its rules label and the input field.
const ROW_GAP := 17.0
## Space below the message inside the cream well (PopupLoginNoInternet: message bottom to well bottom).
const WELL_PAD := 47.4
const CHECK_ON := "Resources_moved_UI_Maincenter:UI_Maincenter_17"
const CHECK_OFF := "Resources_moved_UI_Maincenter:UI_Maincenter_20"
## btnTurnOff size, used for the option marks.
const MARK := 64.0


func _sample() -> Dictionary:
	return SampleData.DOWNLOAD


func _build() -> void:
	var pct := int(view.get("percent", 0))
	var progress := tr("boot_download_progress") % [pct, int(view.get("done_mb", 0)), int(view.get("total_mb", 0))]
	ui = Splash.loading_screen(self, pct / 100.0, progress, str(view.get("version", "")))
	ui.show(POP, true)
	ui.text(POP + "/Panel/Image/txtHeader", tr("boot_download_title"))
	ui.text(POP + "/Panel/Content/Description", "%s\n%s" % [tr("boot_download_sub"), tr("boot_download_need") % int(view.get("total_mb", 0))])
	ui.show(POP + "/Panel/Content/Button/Cancel", true)
	ui.text(POP + "/Panel/Content/Button/Cancel/Out", tr("boot_skip"))
	ui.on_click(POP + "/Panel/Content/Button/Cancel", _send.bind("skip"))
	ui.text(POP + "/Panel/Content/Button/Ok/Out", tr("boot_download_go"))
	ui.on_click(POP + "/Panel/Content/Button/Ok", _send.bind("download"))
	ui.on_click(POP + "/Panel/Top/btnTurnOff", _send.bind("close"))
	_options([[tr("boot_download_wifi"), true], [tr("boot_download_cell"), false]])
	ui.relayout(POP + "/Panel")


## Grows the panel (the well stretches with it, the button row stays at the bottom) and adds one row per option
## below the message.
func _options(rows: Array) -> void:
	var field := UnityKit.spec(FIELD_LAYER, FIELD)
	var row_size := Vector2(float(field.r[6]), float(field.r[7]))
	var desc: Control = ui.node(POP + "/Panel/Content/Description")
	var dr: Dictionary = desc.get_meta("u_rect")
	# Description is anchored to the top: its bottom edge in units from the panel top.
	var desc_bottom := -(dr.pos as Vector2).y + (dr.size as Vector2).y * 0.5
	var grow := rows.size() * (row_size.y + ROW_GAP)
	for p in [POP + "/Panel", POP + "/Panel/Bg"]:
		var n: Control = ui.node(p)
		var s: Vector2 = (n.get_meta("u_rect") as Dictionary).size
		UnityKit.set_size(n, Vector2(s.x, s.y + grow))
	var panel_w: float = ((ui.node(POP + "/Panel") as Control).get_meta("u_rect") as Dictionary).size.x
	var content: Control = ui.node(POP + "/Panel/Content")
	var y := desc_bottom + ROW_GAP
	for row in rows:
		_option(content, Rect2((panel_w - row_size.x) * 0.5, y, row_size.x, row_size.y), str(row[0]), bool(row[1]))
		y += row_size.y + ROW_GAP


## One option: the input field art, its text style left-aligned in the Text Area, a mark on the right.
func _option(parent: Control, rect: Rect2, content: String, on: bool) -> void:
	var bg := UnityKit.spec(FIELD_LAYER, FIELD)
	bg.n = "Option"
	bg.ch = []
	bg.erase("input")
	var row: Control = UnityKit.add(parent, bg, rect).root
	var area: Array = UnityKit.spec(FIELD_LAYER, FIELD + "/Text Area").r
	var pad := Vector2(-float(area[6]), -float(area[7])) * 0.5
	var t := UnityKit.spec(FIELD_LAYER, FIELD + "/Text Area/Text")
	t.n = "Label"
	t.txt.s = content
	t.txt.h = 1
	t.txt.auto = [18.0, float(t.txt.fs)]
	UnityKit.add(row, t, Rect2(pad.x, pad.y, rect.size.x - pad.x * 3.0 - MARK, rect.size.y - pad.y * 2.0))
	UnityKit.sprite(row, CHECK_ON if on else CHECK_OFF,
		Rect2(rect.size.x - pad.x - MARK, (rect.size.y - MARK) * 0.5, MARK, MARK))
