extends "res://src/ui/stub_ui.gd"
## Wireframe 10.4 Language on SettingLanguage (color-cube-match-puzzle): one LanguageCell toggle per language in the
## scrolling grid (purple when chosen, ToggleAnimator), Save below. Settings (settings.gd) opens this scene from its
## Language button. A cell applies its language at once (Game.set_setting "lang", the 14 Game.LANGS, the current one
## lit) and the texts here follow; language_changed lets Settings refresh its own. Save, X and the dim close
## (closed({"action": "close"})). No "device language" cell: the device locale applies until one is picked.

signal language_changed(code: String)

const UnityUI := preload("res://src/ui/unity_ui.gd")

const LAYER := "SettingLanguage"
const PANEL := "Panel/PauseMenu"
const SCROLL := "Panel/PauseMenu/Content/SettingBtn/Scroll View"
const GRID := "Panel/PauseMenu/Content/SettingBtn/Scroll View/Viewport/Content"
## Grid of the prefab (GridLayoutGroup: top padding 24, cells 264x100, spacing 12).
const GRID_TOP := 24.0
const CELL_H := 100.0
const CELL_GAP := 12.0
const COLS := 2

## Language code -> its cell (Button).
var buttons: Dictionary = {}
var _built_layer: Dictionary = {}


func _sample() -> Dictionary:
	return {"rows": Game.LANGS}


func _build() -> void:
	var codes: Array = []
	for code in view.get("rows", Game.LANGS):
		codes.append([str(code), label_key(str(code))])
	_built_layer = build_layer(self, codes, true)
	ui = _built_layer.ui
	buttons = _built_layer.buttons
	for code in buttons:
		(buttons[code] as Button).connect("clicked", _pick.bind(str(code)))
	var save: Button = _built_layer.save
	save.name = "LanguageOk"
	save.connect("clicked", _send.bind("close"))
	for b in _built_layer.close:
		(b as Button).connect("clicked", _send.bind("close"))
	fill()


## Texts in the current language; the current language's cell lit.
func fill() -> void:
	ui.text("Panel/PauseMenu/Image/txtHeader", tr("settings_language"))
	ui.text("Panel/PauseMenu/Content/Save/Out", tr("common_ok"))
	var cur: String = Game.current_lang()
	var names: Array = []
	for code in buttons:
		var b: Button = buttons[code]
		var l := b.get_node("Txt") as Label
		l.text = tr(label_key(str(code)))
		# A name of several words goes onto two lines (whole words) rather than shrinking the whole list.
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		names.append(l)
		b.button_pressed = cur == code
	# Every language name at one size: the smallest any name needs.
	UnityUI.fit_group(names)


func _pick(code: String) -> void:
	Game.set_setting("lang", code)
	fill()
	language_changed.emit(code)


## Key of a language's own name ("pt_BR" -> settings_language_pt_br: "Português (Brasil)" in every language).
static func label_key(code: String) -> String:
	return "settings_language_" + code.to_lower()


## Builds SettingLanguage into owner with one LanguageCell per row [value, label key]; the prefab's other cells are
## hidden (PopupSettingLanguage keeps a fixed list). fit: shrink the popup so the scroll area just holds the rows
## (the prefab's area is sized for its 14 languages). Returns {ui, buttons: {value: Button}, save, close: [Button]}.
static func build_layer(owner: Control, rows: Array, fit: bool) -> Dictionary:
	var v := UnityUI.build(owner, LAYER)
	# ScrollRect drives the Viewport rect (scrollbar AutoHideAndExpandViewport), so the prefab saves it as 0x0 at the
	# corner; with the scrollbar hidden Unity stretches it over the Scroll View.
	var vp := v.node(SCROLL + "/Viewport")
	var r: Dictionary = vp.get_meta("u_rect")
	r.amin = Vector2.ZERO
	r.amax = Vector2.ONE
	r.pos = Vector2.ZERO
	r.size = Vector2.ZERO
	UnityUI.apply_rect(vp)
	v.show(SCROLL + "/Scrollbar Vertical", false)
	v.show("Panel/PauseMenu/Content/SaveGray", false)
	var grid := v.node(GRID)
	var cells: Array[Button] = []
	for c in grid.get_children():
		if c is Button:
			cells.append(c as Button)
	var buttons := {}
	for i in cells.size():
		var b := cells[i]
		b.visible = i < rows.size()
		if i < rows.size():
			b.name = "Lang_" + str(rows[i][0])
			buttons[str(rows[i][0])] = b
	# Content height of the visible rows (the prefab's fixed 868 would scroll into empty space).
	@warning_ignore("integer_division")
	var lines := (mini(rows.size(), cells.size()) + COLS - 1) / COLS
	var need := GRID_TOP + CELL_H * lines + CELL_GAP * maxi(0, lines - 1)
	var gr: Dictionary = grid.get_meta("u_rect")
	gr.size = Vector2((gr.size as Vector2).x, need)
	gr.pos = Vector2((gr.pos as Vector2).x, -need * 0.5)
	UnityUI.apply_rect(grid)
	if fit:
		var view_h := UnityUI.rect_size(v.node(SCROLL)).y
		var panel := v.node(PANEL)
		var pr: Dictionary = panel.get_meta("u_rect")
		if need + GRID_TOP < view_h:
			pr.size = (pr.size as Vector2) - Vector2(0, view_h - need - GRID_TOP)
			UnityUI.apply_rect(panel)
	v.relayout("")
	var close: Array = [v.button("Bg"), v.button("Panel/PauseMenu/Top/btnTurnOff")]
	(close[1] as Control).name = "CloseX"
	return {"ui": v, "buttons": buttons, "save": v.button("Panel/PauseMenu/Content/Save"), "close": close}
