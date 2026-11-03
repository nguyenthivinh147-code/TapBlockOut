extends RefCounted
## Pieces of color-cube-match-puzzle prefabs for screens that have no prefab of their own. Every piece is a copy
## of a real prefab node (PopupOkLayer frame, header, close, body text, cream well, pill button), so it keeps the
## prefab's sprites, TMP materials and button behaviour. Rects are Rect2(x, y, w, h) in Unity canvas units from the
## parent's top-left corner.
## Use: var v := UnityKit.popup(self, tr("ads_notice_title"), Vector2(724, 820)); UnityKit.button(v.node("Panel/Content"), "green", ...).

const UnityUI := preload("res://src/ui/unity_ui.gd")

const FRAME := "PopupOkLayer"
## Pill buttons in Resources_moved/Sprites/UI_Maincenter.png with the TMP material their prefabs use.
const BUTTONS := {
	"green": ["Resources_moved_UI_Maincenter:UI_Maincenter_48", "Baloo Outline - Green"],
	"blue": ["Resources_moved_UI_Maincenter:UI_Maincenter_51", "Baloo Outline - Blue"],
	"cyan": ["Resources_moved_UI_Maincenter:UI_Maincenter_52", "Baloo Outline - Blue"],
	"red": ["Resources_moved_UI_Maincenter:UI_Maincenter_49", "Baloo Outline - Red"],
	"yellow": ["Resources_moved_UI_Maincenter:UI_Maincenter_50", "Baloo Outline - Orange"],
	"purple": ["Resources_moved_UI_Maincenter:UI_Maincenter_79", "Baloo Outline - Purple"],
	"gray": ["Resources_moved_UI_Maincenter:UI_Maincenter_74", "Baloo Outline - Gray"],
}
## Body text colour of PopupOkLayer's description (atlas material, no outline).
const INK := "1c4a83ff"
const WELL := "Resources_moved_UI_Maincenter:UI_Maincenter_68"


## Deep copy of a node spec from an exported layout ("" is the layer root).
static func spec(layer: String, p: String) -> Dictionary:
	var n: Dictionary = UnityUI.layout(layer).get("root", {})
	if p != "":
		for part in p.split("/"):
			var name := part
			var nth := 1
			if part.contains("#"):
				name = part.get_slice("#", 0)
				nth = int(part.get_slice("#", 1))
			var hit: Dictionary = {}
			var seen := 0
			for c in n.get("ch", []):
				if str(c.get("n", "")) == name:
					seen += 1
					if seen == nth:
						hit = c
						break
			if hit.is_empty():
				push_error("UnityKit: %s không có %s" % [layer, p])
				return {}
			n = hit
	return n.duplicate(true)


## PopupOkLayer frame (dim, Popup2, header, X) at `size`, centred. The description, well and button row are
## hidden; put content in v.node("Panel/Content") (whole panel, below the 130-unit header strip).
## on_close runs for the X and a tap on the dim, like PopupOkUICoreLayer.closeButtons.
static func popup(owner: Control, title: String, size: Vector2 = Vector2(724, 660), on_close: Callable = Callable()) -> RefCounted:
	var v := frame(owner, title, on_close)
	for p in ["Panel/Content/Description", "Panel/Content/Image", "Panel/Content/Button"]:
		v.show(p, false)
	set_size(v.node("Panel"), size)
	for p in ["Panel/Bg"]:
		set_size(v.node(p), size)
	return v


## The PopupOkLayer frame a screen's scene already holds as popup() left it (size, hidden parts, content):
## sets the title and wires the close buttons.
static func frame(owner: Control, title: String, on_close: Callable = Callable()) -> RefCounted:
	var v := UnityUI.build(owner, FRAME)
	v.text("Panel/Image/txtHeader", title)
	if on_close.is_valid():
		for b in v.field("closeButtons", "PopupOkUICoreLayer"):
			(b as Button).connect("clicked", on_close)
	else:
		for b in v.field("closeButtons", "PopupOkUICoreLayer"):
			(b as Control).visible = (b as Control).name == "Bg"
	return v


## Builds a spec under parent; rect (if it has area) places it from the parent's top-left.
static func add(parent: Control, s: Dictionary, rect: Rect2 = Rect2()) -> RefCounted:
	var canvas := parent
	while canvas != null and not canvas.has_meta("u_canvas"):
		canvas = canvas.get_parent() as Control
	var v := UnityUI.build_subtree(s, parent, canvas)
	if rect.has_area():
		place(v.root, rect)
	UnityUI.relayout(v.root)
	return v


## Pill button copied from PopupOkLayer's Ok (280x120, text 56 auto, press pulse); color is a BUTTONS key.
static func button(parent: Control, color: String, label: String, rect: Rect2, on_click: Callable = Callable()) -> RefCounted:
	var s := spec(FRAME, "Panel/Content/Button/Ok")
	var art: Array = BUTTONS.get(color, BUTTONS.green)
	s.img.sp = art[0]
	s.n = "Button_" + color
	var out: Dictionary = s.ch[0]
	out.txt.mat = art[1]
	out.txt.s = label
	var v := add(parent, s, rect)
	if on_click.is_valid():
		v.on_click("", on_click)
	return v


## Body text like PopupOkLayer's description (ink blue, atlas material, word wrap, auto size 18..size).
## mat: a _materials.json key for outlined text ("Baloo Outline - Black" for white text on art).
static func label(parent: Control, content: String, rect: Rect2, size: float = 40.0, color: String = INK, mat: String = "",
		halign: int = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var s := spec(FRAME, "Panel/Content/Description")
	s.n = "Text"
	s.txt.s = content
	s.txt.fs = size
	s.txt.auto = [18.0, size]
	s.txt.c = color
	s.txt.h = 1 if halign == HORIZONTAL_ALIGNMENT_LEFT else (4 if halign == HORIZONTAL_ALIGNMENT_RIGHT else 2)
	if mat != "":
		s.txt.mat = mat
	return add(parent, s, rect).root as Label


## Cream well (UI_Maincenter_68, sliced) like PopupOkLayer's content background.
static func well(parent: Control, rect: Rect2) -> Control:
	var s := spec(FRAME, "Panel/Content/Image")
	s.n = "Well"
	return add(parent, s, rect).root


## Sprite by _sprites.json key (or a game texture with key ""), aspect kept like Image.preserveAspect.
static func sprite(parent: Control, key: String, rect: Rect2, tex: Texture2D = null) -> Control:
	var s := {"n": "Sprite", "a": true, "r": [0, 1, 0, 1, 0, 0, rect.size.x, rect.size.y, 0.5, 0.5],
		"img": {"sp": key if key != "" else null, "c": "ffffffff", "t": 0, "pa": true}}
	var v := add(parent, s, rect)
	if tex != null:
		v.texture("", tex)
	return v.root


## Moves a built node to rect (from the parent's top-left), anchoring it top-left like a fixed RectTransform.
static func place(c: Control, rect: Rect2) -> void:
	var r: Dictionary = c.get_meta("u_rect")
	var pv: Vector2 = r.pivot
	r.amin = Vector2(0, 1)
	r.amax = Vector2(0, 1)
	r.size = rect.size
	r.pos = Vector2(rect.position.x + rect.size.x * pv.x, -rect.position.y - rect.size.y * (1.0 - pv.y))
	UnityUI.apply_rect(c)


## Sets a node's sizeDelta (keeps anchors and pivot).
static func set_size(c: Control, size: Vector2) -> void:
	var r: Dictionary = c.get_meta("u_rect")
	r.size = size
	UnityUI.apply_rect(c)
