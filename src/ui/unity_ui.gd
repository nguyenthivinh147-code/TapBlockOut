extends RefCounted
## Builds the UI of color-cube-match-puzzle's Unity layer prefabs from data/ui_unity/ (tools/unity_ui_export.mjs).
## Every number is in Unity canvas units: a "Canvas" control is scaled like CustomCanvasScaler (reference 886x1920,
## match height when width / height > 0.45, else width), so offsets, font sizes and borders are copied verbatim.
## Use: var v := UnityUI.build(self, "PopupOkLayer"); v.text("Panel/Top/txtHeader", tr("...")); v.on_click(...).

const UView := preload("res://src/ui/u_view.gd")
const UImage := preload("res://src/ui/u_image.gd")
const UButton := preload("res://src/ui/u_button.gd")
const UAnim := preload("res://src/ui/u_anim.gd")
const UScroll := preload("res://src/ui/u_scroll.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")
const TMP_SHADER := preload("res://src/ui/tmp_text.gdshader")
const CUTOUT_SHADER := preload("res://src/ui/cutout_mask.gdshader")
const FONT: FontFile = preload("res://assets/fonts/baloo.res")

const DIR := "res://data/ui_unity/"
## tools/bake_screen.gd: build the static tree only (no reveal, animations, auto size, scroll or button wiring).
static var baking := false
## One scene per layout, made by tools/bake_unity_ui.gd: the source of truth for every prefab layout.
const BAKED := "res://scenes/unity/"
## Metas adopt() sets on nodes; a copied subtree drops them before it is wired again.
const RUNTIME_METAS := ["u_built", "u_slider", "u_input", "u_placeholder", "u_scale_loop", "u_fitting"]
const REF := Vector2(886, 1920)
## TMP font asset "Baloo Bhaijaan Regular 400 SDF": line height and spacing in em/100.
const TMP_POINT := 32.0
const TMP_LINE_HEIGHT := 40.0
const TMP_SPACING := -2.0
const TMP_BOLD_SPACING := 0.0
## Godot line height of baloo.res (ascent + descent at TMP_POINT).
const GODOT_LINE_HEIGHT := 43.9
## Atlas material used when a text has no material of its own.
const DEFAULT_MATERIAL := "Baloo Bhaijaan Regular 400 SDF (atlas)"

static var _layouts := {}
static var _sprites := {}
static var _materials := {}
static var _anims := {}
static var _tex := {}
static var _mats := {}
static var _fonts := {}


# --- data ---

static func layout(layer: String) -> Dictionary:
	if not _layouts.has(layer):
		_layouts[layer] = _json(DIR + layer + ".json")
	return _layouts[layer]


static func _json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("UnityUI: thiếu " + path)
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


static func _table(cache: Dictionary, file: String) -> Dictionary:
	if cache.is_empty():
		cache.merge(_json(DIR + file))
	return cache


## {tex, region, border (Vector4 px of the imported texture), scale (canvas units per imported px at ppu 100)}.
static func sprite_info(key: String) -> Dictionary:
	var s: Dictionary = _table(_sprites, "_sprites.json").get(key, {})
	if s.is_empty():
		return {}
	var path := str(s.tex)
	if not _tex.has(path):
		_tex[path] = load(path) as Texture2D
	var tex: Texture2D = _tex[path]
	if tex == null:
		return {}
	var src: Array = s.get("src", [tex.get_width(), tex.get_height()])
	var k := float(tex.get_width()) / maxf(1.0, float(src[0]))
	var r: Array = s.r
	var b: Array = s.b
	return {
		"tex": tex,
		"region": Rect2(float(r[0]) * k, float(r[1]) * k, float(r[2]) * k, float(r[3]) * k),
		"border": Vector4(float(b[0]), float(b[1]), float(b[2]), float(b[3])) * k,
		"scale": 100.0 / float(s.get("ppu", 100.0)) / k,
	}


static func anim_clip(controller: String) -> Dictionary:
	var a: Variant = _table(_anims, "_anims.json").get(controller)
	return a if a is Dictionary else {}


# --- canvas ---

## CustomCanvasScaler.SetMatchWidthOrHeight: canvas units -> viewport px.
static func canvas_scale(vp: Vector2) -> float:
	if vp.y <= 0.0:
		return 1.0
	return vp.y / REF.y if vp.x / vp.y > 0.45 else vp.x / REF.x


## Builds layer `layer` into owner from its baked scene (BAKED, tools/bake_unity_ui.gd), or from the JSON when the
## scene is missing. A Canvas of that layer already in owner (the screen's .tscn instances it) is used as is.
## opts: reveal (default true) plays DialogueReveal on the next frame.
static func build(owner: Control, layer: String, opts: Dictionary = {}) -> UView:
	var data := layout(layer)
	var canvas := _baked_canvas(owner, layer)
	if canvas == null:
		canvas = instance(layer)
		owner.add_child(canvas)
	else:
		# Drawn above what the screen added before building, as if it were added now.
		owner.move_child(canvas, -1)
	canvas.set_meta("u_built", true)
	_fit_canvas(canvas, owner)
	# One refit for every canvas of the owner: bound callables with the same number of binds compare equal, so a
	# second build into the same owner could not connect a handler of its own.
	if not owner.has_meta("u_fit"):
		owner.set_meta("u_fit", true)
		owner.resized.connect(_fit_canvases.bind(owner))
	var v := adopt(_prefab_root(canvas), canvas)
	v.layer = layer
	# Children of layout groups are saved at 0,0; Unity places them at runtime.
	relayout(v.root)
	if baking:
		return v
	if not v.reveal_cfg.is_empty() and bool(opts.get("reveal", true)):
		_reveal_start(v)
		play_reveal.call_deferred(v)
	# UICoreLayer.SetShow runs OnDisplayLayout, then ShowLayer runs OnShowLayer (PlayAnimation, set_enabled...).
	for ev in ["OnDisplayLayout", "OnShowLayer"]:
		for cs in (data.get("root", {}) as Dictionary).get("cs", []):
			if cs.get(ev) is Array:
				invoke_calls.call_deferred(v, cs[ev])
	return v


## New Canvas of a layer: its baked scene, else built from the JSON (no runtime wiring yet, see adopt).
static func instance(layer: String) -> Control:
	var path := BAKED + layer + ".tscn"
	if ResourceLoader.exists(path):
		var ps: PackedScene = load(path)
		return ps.instantiate() as Control
	return make_canvas(layer)


## Canvas holding the prefab root of a layer, made from the JSON: what tools/bake_unity_ui.gd saves.
static func make_canvas(layer: String) -> Control:
	var canvas := Control.new()
	canvas.name = "Canvas"
	canvas.set_meta("u_canvas", true)
	canvas.set_meta("u_layer", layer)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_make(layout(layer).get("root", {}), canvas, "", true, true)
	return canvas


## A Canvas of `layer` placed in owner by its scene and not built yet.
static func _baked_canvas(owner: Control, layer: String) -> Control:
	for c in owner.get_children():
		if c is Control and c.has_meta("u_canvas") and str(c.get_meta("u_layer", "")) == layer and not c.has_meta("u_built") \
				and not c.is_queued_for_deletion():
			return c
	return null


static func _prefab_root(canvas: Control) -> Control:
	for c in canvas.get_children():
		if c is Control and c.has_meta("u"):
			return c
	return null


## Unwired instance of a baked layer that clone() copies templates from; frees it with the last view using it.
class Pristine extends RefCounted:
	var canvas: Control = null
	var paths := {}

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE and is_instance_valid(canvas):
			canvas.free()


static func pristine_of(layer: String) -> Pristine:
	var p := Pristine.new()
	p.canvas = instance(layer)
	_collect_paths(_prefab_root(p.canvas), "", p.paths)
	return p


## Pristine copy of a layer node (Unity path from the prefab root, "" is the root), not in the tree and not wired;
## null when the layer has no node there.
static func pristine_copy(src: Pristine, p: String) -> Control:
	var n: Variant = src.paths.get(p)
	if n == null:
		return null
	return strip_runtime((n as Control).duplicate())


static func _collect_paths(c: Control, path: String, out: Dictionary) -> void:
	if c == null:
		return
	out[path] = c
	var counts := {}
	for ch in c.get_children():
		if not (ch is Control and ch.has_meta("u")):
			continue
		var n := str((ch.get_meta("u") as Dictionary).get("n", "Node"))
		counts[n] = int(counts.get(n, 0)) + 1
		var key := n if counts[n] == 1 else "%s#%d" % [n, counts[n]]
		_collect_paths(ch, key if path == "" else path + "/" + key, out)


## Drops what adopt() adds at runtime (Animator, ScrollRect, input editors) from a copied subtree.
static func strip_runtime(c: Control) -> Control:
	for n in c.find_children("*", "", true, false):
		if n.has_meta("u_rt") and is_instance_valid(n):
			n.get_parent().remove_child(n)
			n.free()
	for n in [c] + c.find_children("*", "Control", true, false):
		for m in RUNTIME_METAS:
			if n.has_meta(m):
				n.remove_meta(m)
	return c


## Runs exported UnityEvent calls [{target, method, arg}] on built nodes.
static func invoke_calls(v: UView, calls: Array) -> void:
	for call in calls:
		var found: Variant = v.ids.get(str(call.get("target", "")))
		if found == null or not is_instance_valid(found):
			continue
		var target: Control = found
		var id := str(target.get_meta("u").get("id", ""))
		match str(call.get("method", "")):
			"PlayAnimation", "PlayAnim", "StartScaleAnim":
				var cb: Callable = v.anims.get(id, Callable())
				if cb.is_valid():
					cb.call()
			"StopAnim", "StopScaleAnim":
				var cb: Callable = v.stops.get(id, Callable())
				if cb.is_valid():
					cb.call()
			"PlayAllAnimationsSync":
				for e in v.scripts:
					if e.node == target and str(e.cs.get("name", "")) == "UIAnimationGroup":
						_play_group(v, e.cs)
			"SetActive":
				target.visible = bool(call.get("arg"))
			"set_enabled":
				# Behaviour.enabled of the target's Animator, else of its text.
				var a := target.get_node_or_null("Animator")
				if a is UAnim:
					(a as UAnim).enabled = bool(call.get("arg"))
				elif target is Label:
					target.visible = bool(call.get("arg"))


static func _fit_canvases(owner: Control) -> void:
	for c in owner.get_children():
		if c is Control and c.has_meta("u_canvas"):
			_fit_canvas(c, owner)


static func _fit_canvas(canvas: Control, owner: Control) -> void:
	if not is_instance_valid(canvas):
		return
	var vp := owner.size
	if vp.x <= 0.0 or vp.y <= 0.0:
		vp = owner.get_viewport_rect().size if owner.is_inside_tree() else Vector2(720, 1280)
	var s := canvas_scale(vp)
	canvas.scale = Vector2(s, s)
	canvas.position = Vector2.ZERO
	canvas.size = vp / s


## Builds one prefab subtree under parent; returns a view whose root is the new node.
static func build_subtree(spec: Dictionary, parent: Control, canvas: Control) -> UView:
	var root := _make(spec, parent, "", true, true)
	root.set_meta("u_sub", true)
	return adopt(root, canvas)


## Wires a made or baked prefab subtree for runtime: node lookup, text auto size, Animators, button tints, scroll,
## sliders, input fields, cutouts and the prefab's custom scripts. Properties saved in the scene are kept.
static func adopt(root: Control, canvas: Control) -> UView:
	var v := UView.new()
	v.canvas = canvas
	v.root = root
	if root != null:
		_wire(root, v, "")
		if baking:
			_collect(v.root, v)
		else:
			_scripts(v)
	return v


static func _wire(c: Control, v: UView, path: String) -> void:
	var spec: Dictionary = c.get_meta("u", {})
	v.paths[path] = c
	v.ids[str(spec.get("id", ""))] = c
	if c.has_meta("u_rect"):
		rect_from_node(c)
	if c is UButton:
		var img := c.get_node_or_null("image")
		if img is UImage:
			(c as UButton).image = img
	if c is Label and c.has_meta("u_txt") and (c.get_meta("u_txt") as Dictionary).get("auto") != null and not baking:
		var fit := fit_text.bind(c)
		if not c.resized.is_connected(fit):
			c.resized.connect(fit)
		_fit_later.call_deferred(c)
	var counts := {}
	for ch in c.get_children():
		if not (ch is Control and ch.has_meta("u")):
			continue
		# A piece added with build_subtree (UnityKit) or clone() keeps its own view, as when it was built.
		if ch.has_meta("u_sub"):
			v.subs.append(adopt(ch, v.canvas))
			continue
		var n := str((ch.get_meta("u") as Dictionary).get("n", "Node"))
		counts[n] = int(counts.get(n, 0)) + 1
		var key := n if counts[n] == 1 else "%s#%d" % [n, counts[n]]
		_wire(ch, v, key if path == "" else path + "/" + key)
	if baking:
		return
	# A disabled Animator keeps the prefab's values until it is enabled (set_enabled, UView.animator()).
	if spec.has("anim") and spec.anim.get("controller") != null and c.get_node_or_null("Animator") == null:
		var clip := anim_clip(str(spec.anim.controller))
		if not clip.is_empty():
			var a := UAnim.new()
			a.name = "Animator"
			a.set_meta("u_rt", true)
			a.enabled = bool(spec.anim.get("on", true))
			c.add_child(a)
			a.setup(c, clip)


## Makes one prefab node and its children with every property the prefab sets; adopt() wires them.
static func _make(spec: Dictionary, parent: Control, path: String, rays: bool, inter: bool) -> Control:
	var c: Control
	if spec.has("btn") or spec.has("tog"):
		c = UButton.new()
	elif spec.has("txt"):
		c = Label.new()
	elif spec.has("img") or spec.has("raw"):
		c = UImage.new()
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		c = Control.new()
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.name = _safe_name(str(spec.get("n", "Node")))
	c.set_meta("u", spec)
	var r: Array = spec.get("r", [0.5, 0.5, 0.5, 0.5, 0, 0, 100, 100, 0.5, 0.5])
	c.set_meta("u_rect", {
		"amin": Vector2(r[0], r[1]), "amax": Vector2(r[2], r[3]),
		"pos": Vector2(r[4], r[5]), "size": Vector2(r[6], r[7]), "pivot": Vector2(r[8], r[9]),
	})
	parent.add_child(c)
	apply_rect(c)
	var sc: Array = spec.get("s", [1, 1])
	c.scale = Vector2(sc[0], sc[1])
	c.rotation = deg_to_rad(-float(spec.get("z", 0.0)))
	c.visible = bool(spec.get("a", true))

	var cg: Dictionary = spec.get("cg", {})
	if not cg.is_empty():
		c.modulate.a = float(cg.get("alpha", 1.0))
		if not bool(cg.get("block", true)):
			rays = false
		if not bool(cg.get("inter", true)):
			inter = false
	if spec.has("canvas") and path != "" and bool(spec.canvas.get("override_sort", false)) and int(spec.canvas.get("order", 0)) > 0:
		c.z_index = 1

	if spec.has("img"):
		var img: Control = c if c is UImage else _child_image(c)
		_setup_image(img, spec.img, Vector2(r[8], r[9]))
		if _is_dim(spec, r):
			img.color.a = ThemeKit.POPUP_DIM_ALPHA
		if bool(spec.img.get("rt", false)) and not (c is UButton):
			c.mouse_filter = Control.MOUSE_FILTER_PASS
	elif spec.has("raw"):
		var img: Control = c if c is UImage else _child_image(c)
		_setup_raw(img, spec.raw)
		if bool(spec.raw.get("rt", false)) and not (c is UButton):
			c.mouse_filter = Control.MOUSE_FILTER_PASS
	if spec.has("txt"):
		_setup_text(c as Label, spec.txt)
	if c is UButton:
		_setup_button(c as UButton, spec, inter)
	if spec.has("mask"):
		c.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW if bool(spec.mask.get("show", true)) else CanvasItem.CLIP_CHILDREN_ONLY
	if spec.has("rmask"):
		c.clip_contents = true
	if not rays:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var counts := {}
	for ch in spec.get("ch", []):
		var n := str(ch.get("n", "Node"))
		counts[n] = int(counts.get(n, 0)) + 1
		var key := n if counts[n] == 1 else "%s#%d" % [n, counts[n]]
		_make(ch, c, key if path == "" else path + "/" + key, rays, inter)
	return c


static func _safe_name(n: String) -> String:
	for ch in [".", ":", "@", "/", "\"", "%"]:
		n = n.replace(ch, "_")
	return n if n != "" else "Node"


static func _child_image(c: Control) -> Control:
	var img := UImage.new()
	img.name = "image"
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(img)
	if c is UButton:
		(c as UButton).image = img
	return img


## The u_image drawing a node (itself, or a button's image child).
static func image_of(c: Control) -> Control:
	if c == null:
		return null
	if c is UImage:
		return c
	if c is UButton:
		return (c as UButton).image
	return null


## Unity RectTransform (meta "u_rect") -> Godot anchors and offsets.
static func apply_rect(c: Control) -> void:
	var r: Dictionary = c.get_meta("u_rect")
	var amin: Vector2 = r.amin
	var amax: Vector2 = r.amax
	var pos: Vector2 = r.pos
	var sz: Vector2 = r.size
	var pv: Vector2 = r.pivot
	# Left/top push the opposite anchor when they pass it; right/bottom then land on their own value.
	c.set_anchor(SIDE_LEFT, amin.x, false, true)
	c.set_anchor(SIDE_RIGHT, amax.x, false, true)
	c.set_anchor(SIDE_TOP, 1.0 - amax.y, false, true)
	c.set_anchor(SIDE_BOTTOM, 1.0 - amin.y, false, true)
	var omin := pos - sz * pv
	var omax := pos + sz * (Vector2.ONE - pv)
	c.offset_left = omin.x
	c.offset_right = omax.x
	c.offset_top = -omax.y
	c.offset_bottom = -omin.y
	c.pivot_offset_ratio = Vector2(pv.x, 1.0 - pv.y)


## Unity rect (meta "u_rect") read back from the control's anchors, offsets and pivot: a node moved or resized in
## the editor keeps that rect when layout groups, fitters or sliders apply it again. A fresh dictionary, so scene
## instances and copies do not share it.
static func rect_from_node(c: Control) -> void:
	var pv := Vector2(c.pivot_offset_ratio.x, 1.0 - c.pivot_offset_ratio.y)
	var omin := Vector2(c.offset_left, -c.offset_bottom)
	var omax := Vector2(c.offset_right, -c.offset_top)
	var sz := omax - omin
	c.set_meta("u_rect", {
		"amin": Vector2(c.anchor_left, 1.0 - c.anchor_bottom), "amax": Vector2(c.anchor_right, 1.0 - c.anchor_top),
		"pos": omin + sz * pv, "size": sz, "pivot": pv,
	})


## Size the Unity rect resolves to inside its parent (Godot may grow a Label past it).
static func rect_size(c: Control) -> Vector2:
	var r: Dictionary = c.get_meta("u_rect")
	var p := c.get_parent() as Control
	var ps := p.size if p != null else Vector2.ZERO
	return ps * ((r.amax as Vector2) - (r.amin as Vector2)) + (r.size as Vector2)


# --- image ---

static func _setup_image(img: Control, d: Dictionary, pivot: Vector2) -> void:
	img.color = Color(str(d.get("c", "ffffffff")))
	img.kind = int(d.get("t", 0))
	img.preserve_aspect = bool(d.get("pa", false))
	img.pivot = pivot
	img.fill_center = bool(d.get("fc", true))
	img.fill_method = int(d.get("fm", 0))
	img.fill_amount = float(d.get("fa", 1.0))
	img.fill_origin = int(d.get("fo", 0))
	if d.get("sp") != null:
		_assign_sprite(img, str(d.sp), float(d.get("ppu", 1.0)))
	# A disabled Image component draws nothing but its children still show.
	if not bool(d.get("on", true)):
		img.color.a = 0.0


## A popup's full-screen dim: a plain black, raycast-blocking Image stretched exactly over its parent (no sprite,
## no material such as LoadLevelProcess's SwirlMask). Each prefab picks its own alpha; the game uses one for all.
static func _is_dim(spec: Dictionary, r: Array) -> bool:
	var d: Dictionary = spec.img
	if d.get("sp") != null or d.get("mat") != null or not bool(d.get("rt", false)) or not bool(d.get("on", true)):
		return false
	var col := Color(str(d.get("c", "ffffffff")))
	if col.r != 0.0 or col.g != 0.0 or col.b != 0.0 or col.a == 0.0:
		return false
	var full := [0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0]
	for i in full.size():
		if float(r[i]) != full[i]:
			return false
	return true


static func _setup_raw(img: Control, d: Dictionary) -> void:
	img.color = Color(str(d.get("c", "ffffffff")))
	if d.get("tex") != null:
		img.set_texture(load(str(d.tex)) as Texture2D)


static func _assign_sprite(img: Control, key: String, ppu_mult: float = 1.0) -> void:
	var s := sprite_info(key)
	if s.is_empty():
		push_warning("UnityUI: thiếu sprite " + key)
		return
	img.set_texture(s.tex, s.region, s.border, float(s.scale) / maxf(ppu_mult, 0.0001))


## Sprite by _sprites.json key on a node (image or button).
static func set_sprite(c: Control, key: String) -> void:
	var img := image_of(c)
	if img == null:
		return
	var spec: Dictionary = c.get_meta("u", {})
	_assign_sprite(img, key, float(spec.get("img", {}).get("ppu", 1.0)))


static func set_color_channel(c: Control, ch: String, v: float) -> void:
	var img := image_of(c)
	if img != null:
		var col: Color = img.color
		col[ch] = v
		img.set_color(col)
	elif c is Label:
		var l := c as Label
		var col := l.get_theme_color("font_color")
		col[ch] = v
		l.add_theme_color_override("font_color", col)


# --- text ---

static func _setup_text(l: Label, t: Dictionary) -> void:
	l.mouse_filter = Control.MOUSE_FILTER_PASS if bool(t.get("rt", false)) else Control.MOUSE_FILTER_IGNORE
	l.set_meta("u_txt", t)
	var style := int(t.get("st", 0))
	l.uppercase = (style & 16) != 0
	l.add_theme_color_override("font_color", Color(str(t.get("c", "ffffffff"))))
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	l.add_theme_constant_override("shadow_outline_size", 0)
	var m: Array = t.get("m", [0, 0, 0, 0])
	var box := StyleBoxEmpty.new()
	box.content_margin_left = float(m[0])
	box.content_margin_top = float(m[1])
	box.content_margin_right = float(m[2])
	box.content_margin_bottom = float(m[3])
	l.add_theme_stylebox_override("normal", box)
	var h := int(t.get("h", 1))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if h == 2 or h == 32 else (HORIZONTAL_ALIGNMENT_RIGHT if h == 4 else (HORIZONTAL_ALIGNMENT_FILL if h == 8 or h == 16 else HORIZONTAL_ALIGNMENT_LEFT))
	var va := int(t.get("v", 256))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER if va == 512 or va == 4096 else (VERTICAL_ALIGNMENT_BOTTOM if va == 1024 else VERTICAL_ALIGNMENT_TOP)
	# Overflowing text grows away from its alignment, like TMP Overflow mode.
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH if l.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER else (Control.GROW_DIRECTION_BEGIN if l.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT else Control.GROW_DIRECTION_END)
	l.grow_vertical = Control.GROW_DIRECTION_BOTH if l.vertical_alignment == VERTICAL_ALIGNMENT_CENTER else (Control.GROW_DIRECTION_BEGIN if l.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM else Control.GROW_DIRECTION_END)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if bool(t.get("w", true)) else TextServer.AUTOWRAP_OFF
	var ov := int(t.get("ov", 0))
	if ov == 1:
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.clip_text = true
	elif ov == 3:
		l.clip_text = true
	l.material = text_material(str(t.get("mat")) if t.get("mat") != null else DEFAULT_MATERIAL, (style & 1) != 0)
	l.visible = l.visible and bool(t.get("on", true))
	_text_size(l, float(t.get("fs", 36.0)))
	l.text = str(t.get("s", ""))


## Font size plus TMP spacing (normalSpacingOffset, characterSpacing, lineSpacing) at that size.
static func _text_size(l: Label, fs: float) -> void:
	var m := _text_metrics(l.get_meta("u_txt"), fs)
	l.add_theme_font_size_override("font_size", m.size)
	l.add_theme_font_override("font", m.font)
	l.add_theme_constant_override("line_spacing", m.line)


## {size, font, line} of a TMP text at font size fs.
static func _text_metrics(t: Dictionary, fs: float) -> Dictionary:
	var bold := (int(t.get("st", 0)) & 1) != 0
	var glyph := roundi((TMP_SPACING + float(t.get("cs", 0.0)) + (TMP_BOLD_SPACING if bold else 0.0)) * fs * 0.01)
	var space := roundi(float(t.get("ws", 0.0)) * fs * 0.01)
	var line := (TMP_LINE_HEIGHT - GODOT_LINE_HEIGHT) / TMP_POINT * fs + float(t.get("ls", 0.0)) * fs * 0.01
	return {"size": maxi(1, roundi(fs)), "font": _font(glyph, space), "line": roundi(line)}


static func _font(glyph: int, space: int) -> Font:
	var key := "%d|%d" % [glyph, space]
	if not _fonts.has(key):
		var f := FontVariation.new()
		f.base_font = FONT
		f.spacing_glyph = glyph
		f.spacing_space = space
		_fonts[key] = f
	return _fonts[key]


static func _fit_later(l: Variant) -> void:
	if is_instance_valid(l):
		fit_text(l)


## Sets text and re-runs TMP auto size.
static func set_text(l: Label, s: String) -> void:
	l.text = s
	if l.has_meta("u_txt") and (l.get_meta("u_txt") as Dictionary).get("auto") != null:
		fit_text(l)


## TMP enableAutoSizing: the largest size in [min, max] whose text fits the rect.
static func fit_text(l: Label) -> void:
	# Changing the font size resizes the label, which emits resized again.
	if not is_instance_valid(l) or not l.has_meta("u_txt") or l.has_meta("u_fitting"):
		return
	var t: Dictionary = l.get_meta("u_txt")
	var auto: Variant = t.get("auto")
	if auto == null:
		return
	var m: Array = t.get("m", [0, 0, 0, 0])
	var avail := rect_size(l) - Vector2(float(m[0]) + float(m[2]), float(m[1]) + float(m[3]))
	if avail.x <= 0.0 or avail.y <= 0.0:
		return
	l.set_meta("u_fitting", true)
	var text := l.text.to_upper() if l.uppercase else l.text
	var lo := int(floor(float(auto[0])))
	var hi := int(ceil(float(auto[1])))
	var best := lo
	while lo <= hi:
		var mid := (lo + hi) / 2
		if _fits(l, text, mid, avail):
			best = mid
			lo = mid + 1
		else:
			hi = mid - 1
	_text_size(l, float(best))
	l.remove_meta("u_fitting")


static func _fits(l: Label, text: String, size: int, avail: Vector2) -> bool:
	_text_size(l, float(size))
	var font := l.get_theme_font("font")
	var line := float(l.get_theme_constant("line_spacing"))
	var lh := font.get_height(size) + line
	if l.autowrap_mode == TextServer.AUTOWRAP_OFF:
		var lines := text.split("\n")
		var w := 0.0
		for s in lines:
			w = maxf(w, font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
		return w <= avail.x + 0.5 and lh * lines.size() - line <= avail.y + 0.5
	var sz := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, avail.x, size, -1,
		TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE)
	var n := maxi(1, roundi(sz.y / font.get_height(size)))
	return sz.x <= avail.x + 0.5 and lh * n - line <= avail.y + 0.5


## One ShaderMaterial per TMP material (and bold flag), see tmp_text.gdshader.
static func text_material(mat_name: String, bold: bool) -> ShaderMaterial:
	var key := "%s|%s" % [mat_name, bold]
	if _mats.has(key):
		return _mats[key]
	var all := _table(_materials, "_materials.json")
	var m: Dictionary = all.get(mat_name, all.get(DEFAULT_MATERIAL, {}))
	var ratio: Array = m.get("scale_ratio", [1, 1, 1])
	var sra := float(ratio[0])
	var src := float(ratio[2])
	var gs := float(m.get("gradient_scale", 7.0))
	var weight := (float(m.get("weight_bold" if bold else "weight_normal", 0.0)) / 4.0 + float(m.get("face_dilate", 0.0))) * sra * 0.5
	var off: Array = m.get("underlay_offset", [0, 0])
	var sm := ShaderMaterial.new()
	sm.shader = TMP_SHADER
	sm.set_shader_parameter("face_color", Color(str(m.get("face_color", "ffffffff"))))
	sm.set_shader_parameter("outline_color", Color(str(m.get("outline_color", "000000ff"))))
	sm.set_shader_parameter("underlay_color", Color(str(m.get("underlay_color", "000000ff"))))
	sm.set_shader_parameter("face_edge", 0.5 - weight)
	sm.set_shader_parameter("outline_half", float(m.get("outline_width", 0.0)) * sra * 0.5)
	sm.set_shader_parameter("underlay_on", bool(m.get("underlay", false)))
	sm.set_shader_parameter("underlay_edge", 0.5 - weight - float(m.get("underlay_dilate", 0.0)) * src * 0.5)
	sm.set_shader_parameter("underlay_offset", Vector2(-float(off[0]), float(off[1])) * src * gs)
	sm.set_shader_parameter("px_range", float(FONT.msdf_pixel_range))
	_mats[key] = sm
	return sm


# --- button ---

static func _setup_button(b: UButton, spec: Dictionary, inter: bool) -> void:
	var d: Dictionary = spec.get("btn", spec.get("tog", {}))
	b.transition = int(d.get("tr", 1))
	var mult := float(d.get("mult", 1.0))
	var cols: Array[Color] = []
	for c in d.get("c", ["ffffffff", "f5f5f5ff", "c8c8c8ff", "c8c8c880"]):
		var col := Color(str(c))
		cols.append(Color(minf(1.0, col.r * mult), minf(1.0, col.g * mult), minf(1.0, col.b * mult), minf(1.0, col.a * mult)))
	b.tint_colors = cols
	b.tint_dur = float(d.get("dur", 0.1))
	b.sound = bool(spec.get("snd", false))
	b.vibrate = bool(spec.get("vib", false))
	if not bool(d.get("inter", true)) or not inter:
		b.disabled = true
	var sprites: Dictionary = d.get("sprites", {})
	if sprites.get("pressed") != null:
		var s := sprite_info(str(sprites.pressed))
		if not s.is_empty():
			b.pressed_sprite = s
	if spec.has("tog"):
		b.toggle_mode = true
		b.set_pressed_no_signal(bool(d.get("on", false)))


# --- slider, input field, cutout ---

## Slider.value, then Slider.UpdateVisuals: the handle's anchors sit at the normalized value along the direction;
## the fill's anchors end there, or a Filled fill image spans the fill area and takes the value as fillAmount.
static func set_slider(c: Control, value: float) -> void:
	if c == null or not c.has_meta("u_slider"):
		return
	var d: Dictionary = (c.get_meta("u") as Dictionary).slider
	var refs: Dictionary = c.get_meta("u_slider")
	var lo := float(d.get("min", 0.0))
	var hi := float(d.get("max", 1.0))
	value = clampf(value, minf(lo, hi), maxf(lo, hi))
	if bool(d.get("whole", false)):
		value = roundf(value)
	refs.value = value
	var t := inverse_lerp(lo, hi, value) if hi != lo else 0.0
	var dir := int(d.get("dir", 0))
	var axis := 0 if dir < 2 else 1
	# RightToLeft, TopToBottom.
	var rev := dir == 1 or dir == 3
	var fill: Variant = refs.get("fill")
	if fill is Control and is_instance_valid(fill):
		var r: Dictionary = (fill as Control).get_meta("u_rect")
		var amin := Vector2.ZERO
		var amax := Vector2.ONE
		var img := image_of(fill)
		if img != null and img.kind == UImage.FILLED:
			img.set_fill(t)
		elif rev:
			amin[axis] = 1.0 - t
		else:
			amax[axis] = t
		r.amin = amin
		r.amax = amax
		apply_rect(fill)
	var handle: Variant = refs.get("handle")
	if handle is Control and is_instance_valid(handle):
		var r: Dictionary = (handle as Control).get_meta("u_rect")
		var at := 1.0 - t if rev else t
		var amin := Vector2.ZERO
		var amax := Vector2.ONE
		amin[axis] = at
		amax[axis] = at
		r.amin = amin
		r.amax = amax
		apply_rect(handle)


## TMP_InputField: a LineEdit (single line) or TextEdit (multi line) fills the text viewport and draws with the
## Text component's font, size, colour, alignment and TMP material; the Placeholder shows while it is empty. A
## second call replaces the editor (a screen may want multi line where the prefab has a single line).
static func input_field(v: UView, c: Control, multiline: bool) -> Control:
	var d: Dictionary = (c.get_meta("u", {}) as Dictionary).get("input", {})
	var area: Control = v.ids.get(str(d.get("text_view", "")))
	var label := v.ids.get(str(d.get("text", ""))) as Label
	if area == null or label == null:
		return null
	var old: Variant = c.get_meta("u_input") if c.has_meta("u_input") else null
	if old is Control and is_instance_valid(old):
		(old as Control).get_parent().remove_child(old)
		(old as Control).queue_free()
	var e: Control
	# TMP blinks blinkRate times a second, half on, half off.
	var blink := 0.5 / maxf(0.01, float(d.get("blink", 0.85)))
	if multiline:
		var te := TextEdit.new()
		te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		te.caret_blink = true
		te.caret_blink_interval = blink
		te.editable = not bool(d.get("ro", false))
		e = te
	else:
		var le := LineEdit.new()
		le.alignment = HORIZONTAL_ALIGNMENT_LEFT if label.horizontal_alignment == HORIZONTAL_ALIGNMENT_FILL else label.horizontal_alignment
		le.max_length = int(d.get("limit", 0))
		le.flat = true
		le.caret_blink = true
		le.caret_blink_interval = blink
		le.editable = not bool(d.get("ro", false))
		e = le
	e.name = "Input"
	e.set_meta("u_rt", true)
	e.set_anchors_preset(Control.PRESET_FULL_RECT)
	e.material = label.material
	e.add_theme_font_override("font", label.get_theme_font("font"))
	e.add_theme_font_size_override("font_size", label.get_theme_font_size("font_size"))
	var ink := label.get_theme_color("font_color")
	e.add_theme_color_override("font_color", ink)
	# Without a custom caret colour TMP draws the caret in the text colour.
	e.add_theme_color_override("caret_color", Color(str(d.caret)) if d.get("caret") != null else ink)
	e.add_theme_color_override("selection_color", Color(str(d.get("sel", "a8ceffc0"))))
	for st in ["normal", "focus", "read_only"]:
		e.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	area.add_child(e)
	label.visible = false
	c.set_meta("u_input", e)
	var ph: Variant = v.ids.get(str(d.get("placeholder", "")))
	if ph != null:
		e.set_meta("u_placeholder", ph)
	if e is LineEdit:
		(e as LineEdit).text_changed.connect(func(_s: String) -> void: _sync_placeholder(e))
	else:
		(e as TextEdit).text_changed.connect(_sync_placeholder.bind(e))
	set_input_text(e, str(d.get("s", "")))
	return e


## Text of an editor made by input_field (programmatic sets emit no text_changed); the Placeholder follows.
static func set_input_text(e: Control, s: String) -> void:
	e.set("text", s)
	_sync_placeholder(e)


static func _sync_placeholder(e: Control) -> void:
	var p: Variant = e.get_meta("u_placeholder") if e.has_meta("u_placeholder") else null
	if p is Control and is_instance_valid(p):
		(p as Control).visible = str(e.get("text")).is_empty()


## CutoutMaskUI, an Image whose stencil test is NotEqual: it draws only outside its parent Mask's shape. Godot's
## clip_children has no inverse, so the parent stops clipping (its graphic hides when showMaskGraphic is off) and
## a shader cuts the parent's sprite out of the image.
static func _cutout(c: Control) -> void:
	var p := c.get_parent() as Control
	var ps: Dictionary = p.get_meta("u", {}) if p != null else {}
	var mask := image_of(p)
	if not ps.has("mask") or mask == null:
		return
	for ch in p.get_children():
		if ch is Control and ch.has_meta("u") and not bool(((ch.get_meta("u") as Dictionary).get("img", {}) as Dictionary).get("cut", false)):
			push_warning("UnityUI: Mask '%s' có con thường cạnh CutoutMaskUI, con đó không bị cắt" % p.name)
			break
	p.clip_children = CanvasItem.CLIP_CHILDREN_DISABLED
	if not bool(ps.mask.get("show", true)):
		mask.self_modulate.a = 0.0
	var sm := ShaderMaterial.new()
	sm.shader = CUTOUT_SHADER
	if mask.tex != null:
		var tex: Texture2D = mask.tex
		var reg: Rect2 = mask.region
		sm.set_shader_parameter("mask_tex", tex)
		sm.set_shader_parameter("has_mask_tex", true)
		sm.set_shader_parameter("mask_uv", Vector4(reg.position.x / tex.get_width(), reg.position.y / tex.get_height(),
			reg.size.x / tex.get_width(), reg.size.y / tex.get_height()))
	image_of(c).material = sm
	# Lambdas, not bound callables: several cutouts under one Mask each need their own resized handler.
	var sync := func() -> void:
		if is_instance_valid(c) and is_instance_valid(p):
			_cutout_sync(c, p)
	p.resized.connect(sync)
	c.item_rect_changed.connect(sync)
	_cutout_sync(c, p)


## The parent Mask's rect in the cutout's local units.
static func _cutout_sync(c: Control, p: Control) -> void:
	var img := image_of(c)
	if img == null or not (img.material is ShaderMaterial):
		return
	var to_local := c.get_transform().affine_inverse()
	var a := to_local * Vector2.ZERO
	var b := to_local * p.size
	var r := Rect2(a, b - a).abs()
	(img.material as ShaderMaterial).set_shader_parameter("mask_rect", Vector4(r.position.x, r.position.y, r.size.x, r.size.y))


# --- scripts (after the tree exists, so references resolve) ---

static func _scripts(v: UView) -> void:
	_collect(v.root, v)
	var groups := {}
	for c in v.paths.values():
		var spec: Dictionary = c.get_meta("u", {})
		if c is UButton:
			var d: Dictionary = spec.get("btn", spec.get("tog", {}))
			var target: Control = v.ids.get(str(d.get("target", "")))
			(c as UButton).tint_target = image_of(target) if target != null and image_of(target) != null else target
			(c as UButton)._apply_tint(3 if (c as UButton).disabled else 0, false)
			if spec.has("tog"):
				var g: Control = v.ids.get(str(d.get("graphic", "")))
				(c as UButton).toggle_graphic = g
				if g != null:
					g.visible = (c as UButton).button_pressed
				var gid := str(d.get("group", ""))
				if gid != "" and gid != "<null>":
					if not groups.has(gid):
						groups[gid] = ButtonGroup.new()
					(c as UButton).button_group = groups[gid]
		if spec.has("scroll"):
			var sc := UScroll.new()
			sc.name = "ScrollRect"
			sc.set_meta("u_rt", true)
			c.add_child(sc)
			sc.setup(c, v.ids.get(str(spec.scroll.get("viewport", ""))), v.ids.get(str(spec.scroll.get("content", ""))), spec.scroll)
			_pass_buttons(v.ids.get(str(spec.scroll.get("content", ""))))
		if spec.has("slider"):
			c.set_meta("u_slider", {"fill": v.ids.get(str(spec.slider.get("fill", ""))),
				"handle": v.ids.get(str(spec.slider.get("handle", "")))})
			set_slider(c, float(spec.slider.get("value", 0.0)))
		if spec.has("input"):
			input_field(v, c, int(spec.input.get("line", 0)) != 0)
		if bool((spec.get("img", {}) as Dictionary).get("cut", false)):
			_cutout(c)
	for e in v.scripts:
		_script(e.node, e.cs, v)


static func _collect(c: Control, v: UView) -> void:
	var spec: Dictionary = c.get_meta("u", {})
	for cs in spec.get("cs", []):
		v.scripts.append({"node": c, "cs": cs})
	for ch in c.get_children():
		# A u_sub piece wires its own scripts in its own view.
		if ch is Control and ch.has_meta("u") and not ch.has_meta("u_sub"):
			_collect(ch, v)


static func _pass_buttons(content: Control) -> void:
	if content == null:
		return
	for b in content.find_children("*", "Button", true, false):
		(b as Control).mouse_filter = Control.MOUSE_FILTER_PASS


static func _ref(v: UView, x: Variant) -> Control:
	if x is Dictionary and (x as Dictionary).has("node"):
		return v.ids.get(str(x.node))
	return null


static func _f(cs: Dictionary, k: String, d: float) -> float:
	return float(cs.get(k, d)) if cs.get(k) != null else d


static func _script(c: Control, cs: Dictionary, v: UView) -> void:
	match str(cs.get("name", "")):
		"DialogueReveal", "ShowPopupAnimation":
			v.reveal_cfg = {
				"panel": _ref(v, cs.get("panelRect")),
				"dim": _ref(v, cs.get("dimCanvasGroup")),
				"dur": _f(cs, "duration", 0.4),
				"ease": int(_f(cs, "easeType", 26)),
			}
		"UIHoldAnim_Pulse":
			var target := c
			var te := ease_of(int(_f(cs, "_ease", 5)))
			if target is UButton:
				var b := target as UButton
				b.pulse_scale = _f(cs, "_pressScale", 1.1)
				b.pulse_dur = _f(cs, "_easeDuration", 0.15)
				b.pulse_trans = te[0]
				b.pulse_ease = te[1]
		"UIAnim_ScaleAppear":
			var play := func() -> void:
				if not is_instance_valid(c):
					return
				var e := ease_of(int(_f(cs, "_ease", 26)))
				c.scale = Vector2.ONE * _f(cs, "_startScale", 0.2)
				if c.is_inside_tree():
					c.create_tween().set_trans(e[0]).set_ease(e[1]).tween_property(c, "scale", Vector2.ONE, _f(cs, "_duration", 0.4))
				else:
					c.scale = Vector2.ONE
			v.anims[str(c.get_meta("u").get("id", ""))] = play
			if int(_f(cs, "_trigger", 3)) == 0:
				play.call_deferred()
		"UIAnim_Pulse":
			var pulse := func() -> void:
				if not is_instance_valid(c) or not c.is_inside_tree():
					return
				var e_in := ease_of(int(_f(cs, "_easeIn", 6)))
				var e_out := ease_of(int(_f(cs, "_easeOut", 26)))
				var d := _f(cs, "_duration", 0.25)
				var tw := c.create_tween()
				tw.tween_property(c, "scale", Vector2.ONE * _f(cs, "_shrinkScale", 0.9), d * 0.4).set_trans(e_in[0]).set_ease(e_in[1])
				tw.tween_property(c, "scale", Vector2.ONE, d * 0.6).set_trans(e_out[0]).set_ease(e_out[1])
			v.anims[str(c.get_meta("u").get("id", ""))] = pulse
			var trig := int(_f(cs, "_trigger", 3))
			if trig == 2 and c is UButton:
				(c as UButton).pressed.connect(pulse)
			elif trig == 0:
				pulse.call_deferred()
		"AnimScaleButton":
			var target := _ref(v, cs.get("targetRect"))
			if target == null:
				target = c
			var id := str(c.get_meta("u").get("id", ""))
			v.anims[id] = _scale_loop.bind(c, target, _f(cs, "endScale", 1.1), _f(cs, "duration", 0.7), int(_f(cs, "ease", 26)))
			v.stops[id] = _scale_stop.bind(target)
		"UIAnimationGroup":
			if bool(int(_f(cs, "_playOnEnable", 0))):
				_play_group.call_deferred(v, cs)
		"SimpleUIRotator":
			var target := _ref(v, cs.get("targetUI"))
			if target == null:
				target = c
			if bool(int(_f(cs, "rotateOnStart", 1))):
				_spin.call_deferred(target, _f(cs, "rotationSpeed", 90.0))
		"UIAnimScale":
			if bool(int(_f(cs, "ActiveOnStart", 0))):
				for x in cs.get("rectTransforms", []):
					var target := _ref(v, x)
					if target != null:
						_yoyo.call_deferred(target, _f(cs, "scaleValue", 1.2), _f(cs, "duration", 0.5), ease_of(3))
		"PressEffect":
			if c is UButton:
				var list: Array = []
				for e in cs.get("effectImages", []):
					var img := _ref(v, (e as Dictionary).get("Image"))
					if img != null:
						list.append([image_of(img) if image_of(img) != null else img, _color(e.get("NormalColor")), _color(e.get("PressColor")), float(e.get("colorTransitionDuration", 0.1))])
				(c as UButton).press_effects = list
		"SafeAreaUIAdjuster":
			for x in cs.get("rectPanelSafes", []):
				var target := _ref(v, x)
				if target != null:
					_safe_area(target)
		"ToggleAnimator":
			var tog := _ref(v, cs.get("toggle"))
			if tog == null:
				tog = c
			if tog is UButton:
				var apply := _toggle_anim.bind(v, cs)
				apply.call((tog as UButton).button_pressed, false)
				(tog as UButton).toggled.connect(func(on: bool) -> void: apply.call(on, true))


## ToggleAnimator.ChangeAnimToggle (sprite, color, scale or size, title, icon, on/off objects).
static func _toggle_anim(on: bool, smooth: bool, v: UView, cs: Dictionary) -> void:
	var tog := _ref(v, cs.get("toggle"))
	var img := _ref(v, cs.get("targetImage"))
	if tog is UButton:
		# A selected tab cannot be pressed again.
		(tog as UButton).disabled = on
	if img != null and bool(int(_f(cs, "changeSprite", 0))):
		var sp: Variant = cs.get("onSprite" if on else "offSprite")
		if sp is Dictionary and sp.get("sprite") != null:
			set_sprite(img, str(sp.sprite))
	if img != null and bool(int(_f(cs, "changeColor", 0))):
		var im := image_of(img)
		if im != null:
			im.set_color(_color(cs.get("onColor" if on else "offColor")))
	var host := tog if tog != null else img
	match int(_f(cs, "scaleType", 0)):
		1:
			var sd: Dictionary = cs.get("sizeDeltaOn" if on else "sizeDeltaOff", {})
			var r: Dictionary = host.get_meta("u_rect")
			r.size = Vector2(float(sd.get("x", 1)), float(sd.get("y", 1)))
			apply_rect(host)
		2:
			var s: Dictionary = cs.get("scaleOn" if on else "scaleOff", {})
			var to := Vector2(float(s.get("x", 1)), float(s.get("y", 1)))
			if smooth and bool(int(_f(cs, "isSmoothScaleChange", 0))) and host.is_inside_tree():
				host.create_tween().tween_property(host, "scale", to, _f(cs, "timeSmoothScale", 0.2))
			else:
				host.scale = to
	if bool(int(_f(cs, "hasTitle", 0))):
		var title := _ref(v, cs.get("title"))
		if title != null:
			title.visible = on
	if bool(int(_f(cs, "hasIcon", 0))):
		var icon := _ref(v, cs.get("icon"))
		if icon != null:
			var a: Dictionary = cs.get("iconAnchorOn" if on else "iconAnchorOff", {})
			var sc: Dictionary = cs.get("iconScaleOn" if on else "iconScaleOff", {})
			var r: Dictionary = icon.get_meta("u_rect")
			r.pos = Vector2(float(a.get("x", 0)), float(a.get("y", 0)))
			apply_rect(icon)
			icon.scale = Vector2(float(sc.get("x", 1)), float(sc.get("y", 1)))
	for x in cs.get("onObjects", []):
		var o := _ref(v, x)
		if o != null:
			o.visible = on
	for x in cs.get("offObjects", []):
		var o := _ref(v, x)
		if o != null:
			o.visible = not on


static func _color(d: Variant) -> Color:
	if d is Dictionary:
		return Color(float(d.get("r", 1)), float(d.get("g", 1)), float(d.get("b", 1)), float(d.get("a", 1)))
	return Color.WHITE


static func _play_group(v: UView, cs: Dictionary) -> void:
	if not is_instance_valid(v.root):
		return
	var delay := _f(cs, "_initialDelay", 0.0)
	var step := _f(cs, "_delayBetweenAnims", 0.0)
	var t := delay
	for x in cs.get("_animations", []):
		if not (x is Dictionary) or not (x as Dictionary).has("node"):
			continue
		var cb: Callable = v.anims.get(str(x.node), Callable())
		if not cb.is_valid():
			continue
		if t <= 0.0:
			cb.call()
		else:
			v.root.get_tree().create_timer(t).timeout.connect(cb)
		t += step


static func _spin(c: Variant, speed: float) -> void:
	if not is_instance_valid(c) or not c.is_inside_tree() or speed == 0.0:
		return
	var tw: Tween = (c as Control).create_tween().set_loops()
	tw.tween_property(c, "rotation", -TAU * signf(speed), 360.0 / absf(speed)).as_relative()


static func _yoyo(c: Variant, s: float, dur: float, e: Array) -> void:
	if not is_instance_valid(c) or not c.is_inside_tree():
		return
	var tw: Tween = (c as Control).create_tween().set_loops().set_trans(e[0]).set_ease(e[1])
	tw.tween_property(c, "scale", Vector2.ONE * s, dur)
	tw.tween_property(c, "scale", Vector2.ONE, dur)


## AnimScaleButton.PlayAnim: target scale 1 -> s and back, looping (LitMotion Yoyo), only while c is shown.
static func _scale_loop(c: Control, target: Control, s: float, dur: float, ease_code: int) -> void:
	if not is_instance_valid(c) or not c.is_inside_tree() or not c.is_visible_in_tree():
		return
	_scale_stop(target)
	var e := ease_of(ease_code)
	var tw := target.create_tween().set_loops().set_trans(e[0]).set_ease(e[1])
	tw.tween_property(target, "scale", Vector2.ONE * s, dur)
	tw.tween_property(target, "scale", Vector2.ONE, dur)
	target.set_meta("u_scale_loop", tw)


## AnimScaleButton.StopAnim: cancel the loop, scale back to 1.
static func _scale_stop(target: Control) -> void:
	if not is_instance_valid(target):
		return
	if target.has_meta("u_scale_loop"):
		var tw: Variant = target.get_meta("u_scale_loop")
		if tw is Tween and (tw as Tween).is_valid():
			(tw as Tween).kill()
		target.remove_meta("u_scale_loop")
	target.scale = Vector2.ONE


static func _safe_area(c: Control) -> void:
	if not c.is_inside_tree():
		return
	var win := DisplayServer.window_get_size()
	var sa := DisplayServer.get_display_safe_area()
	if win.x <= 0 or win.y <= 0 or sa.size.x <= 0:
		return
	var pos := Vector2(sa.position) - Vector2(DisplayServer.window_get_position())
	var r: Dictionary = c.get_meta("u_rect")
	r.amin = Vector2(clampf(pos.x / win.x, 0, 1), clampf(1.0 - (pos.y + sa.size.y) / win.y, 0, 1))
	r.amax = Vector2(clampf((pos.x + sa.size.x) / win.x, 0, 1), clampf(1.0 - pos.y / win.y, 0, 1))
	r.pos = Vector2.ZERO
	r.size = Vector2.ZERO
	apply_rect(c)


# --- reveal ---

static func _reveal_start(v: UView) -> void:
	var panel: Control = v.reveal_cfg.get("panel")
	var dim: Control = v.reveal_cfg.get("dim")
	if panel != null:
		panel.scale = Vector2.ZERO
	if dim != null:
		dim.modulate.a = 0.0


static func play_reveal(v: UView) -> void:
	# Deferred: the popup may already be freed (tests build and free it in one frame).
	var p: Variant = v.reveal_cfg.get("panel")
	var d: Variant = v.reveal_cfg.get("dim")
	var panel: Control = p if is_instance_valid(p) else null
	var dim: Control = d if is_instance_valid(d) else null
	var host: Control = panel if panel != null else dim
	if host == null or not host.is_inside_tree():
		return
	_reveal_start(v)
	var e := ease_of(int(v.reveal_cfg.get("ease", 26)))
	var dur := float(v.reveal_cfg.get("dur", 0.4))
	var tw := host.create_tween().set_parallel(true).set_trans(e[0]).set_ease(e[1])
	if panel != null:
		tw.tween_property(panel, "scale", Vector2.ONE, dur)
	if dim != null:
		tw.tween_property(dim, "modulate:a", 1.0, dur)


## LitMotion Ease -> [Tween.TransitionType, Tween.EaseType].
static func ease_of(code: int) -> Array:
	if code <= 0 or code > 30:
		return [Tween.TRANS_LINEAR, Tween.EASE_IN_OUT]
	var trans := [Tween.TRANS_SINE, Tween.TRANS_QUAD, Tween.TRANS_CUBIC, Tween.TRANS_QUART, Tween.TRANS_QUINT,
		Tween.TRANS_EXPO, Tween.TRANS_CIRC, Tween.TRANS_ELASTIC, Tween.TRANS_BACK, Tween.TRANS_BOUNCE]
	var eases := [Tween.EASE_IN, Tween.EASE_OUT, Tween.EASE_IN_OUT]
	return [trans[(code - 1) / 3], eases[(code - 1) % 3]]


# --- layout groups (Unity HorizontalLayoutGroup / VerticalLayoutGroup / GridLayoutGroup) ---

## Recomputes fitters and layout groups below c, children first like LayoutRebuilder.
static func relayout(c: Control) -> void:
	if c == null:
		return
	for ch in c.get_children():
		if ch is Control and ch.has_meta("u"):
			relayout(ch)
	var spec: Dictionary = c.get_meta("u", {})
	if spec.has("fit"):
		_fit(c, spec.fit)
	if spec.has("lay"):
		_arrange(c, spec.lay)
		for ch in _layout_children(c):
			if (ch.get_meta("u") as Dictionary).has("lay"):
				_arrange(ch, ch.get_meta("u").lay)


static func _layout_children(c: Control) -> Array[Control]:
	var out: Array[Control] = []
	for ch in c.get_children():
		if not (ch is Control) or not ch.has_meta("u") or not (ch as Control).visible:
			continue
		var le: Dictionary = (ch.get_meta("u") as Dictionary).get("le", {})
		if bool(le.get("ignore", false)):
			continue
		out.append(ch)
	return out


## [min, preferred, flexible] along axis, like LayoutUtility.
static func layout_sizes(c: Control, axis: int) -> Vector3:
	var spec: Dictionary = c.get_meta("u", {})
	var mn := 0.0
	var pref := 0.0
	var flex := 0.0
	if spec.has("lay"):
		var g := _group_sizes(c, spec.lay, axis)
		mn = g.x
		pref = g.y
		flex = g.z
	elif c is Label:
		pref = _text_preferred(c as Label)[axis]
	elif spec.has("img") and image_of(c) != null and image_of(c).tex != null:
		var img := image_of(c)
		if img.kind == UImage.SIMPLE or img.kind == UImage.FILLED:
			pref = img.region.size[axis] * img.border_scale
		else:
			pref = (img.border.x + img.border.z if axis == 0 else img.border.y + img.border.w) * img.border_scale
			mn = pref
	var le: Dictionary = spec.get("le", {})
	if not le.is_empty():
		var lm: Array = le.get("min", [-1, -1])
		var lp: Array = le.get("pref", [-1, -1])
		var lf: Array = le.get("flex", [-1, -1])
		if float(lm[axis]) >= 0.0:
			mn = float(lm[axis])
		if float(lp[axis]) >= 0.0:
			pref = float(lp[axis])
		if float(lf[axis]) >= 0.0:
			flex = float(lf[axis])
	return Vector3(mn, maxf(pref, mn), flex)


## TMP preferred size. With auto size on, TMP_Text.GetPreferredWidth / Height measure at fontSizeMax, not at the
## fitted size, so a fitter or a layout group sizes the rect for the largest size and fit_text shrinks inside it.
static func _text_preferred(l: Label) -> Vector2:
	var t: Dictionary = l.get_meta("u_txt", {})
	var m: Array = t.get("m", [0, 0, 0, 0])
	var font := l.get_theme_font("font")
	var size := l.get_theme_font_size("font_size")
	var line := float(l.get_theme_constant("line_spacing"))
	var auto: Variant = t.get("auto")
	if auto is Array:
		# fit_text's upper bound.
		var mt := _text_metrics(t, ceilf(float(auto[1])))
		font = mt.font
		size = mt.size
		line = float(mt.line)
	var text := l.text.to_upper() if l.uppercase else l.text
	var w := 0.0
	var lines := 0
	for s in text.split("\n"):
		w = maxf(w, font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
		lines += 1
	var h := (font.get_height(size) + line) * lines - line
	if l.autowrap_mode != TextServer.AUTOWRAP_OFF:
		var avail := rect_size(l).x - float(m[0]) - float(m[2])
		if avail > 0.0 and w > avail:
			var sz := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, avail, size)
			var n := maxi(1, roundi(sz.y / font.get_height(size)))
			h = (font.get_height(size) + line) * n - line
	return Vector2(w + float(m[0]) + float(m[2]), h + float(m[1]) + float(m[3]))


static func _group_sizes(c: Control, lay: Dictionary, axis: int) -> Vector3:
	var pad: Array = lay.get("pad", [0, 0, 0, 0])
	var pad_axis := float(pad[0]) + float(pad[1]) if axis == 0 else float(pad[2]) + float(pad[3])
	var kids := _layout_children(c)
	if str(lay.t) == "g":
		var cell: Array = lay.get("cell", [100, 100])
		var sp: Array = lay.get("sp", [0, 0])
		var cols := _grid_cols(c, lay, kids.size())
		var rows := ceili(float(kids.size()) / float(maxi(1, cols)))
		var n := cols if axis == 0 else rows
		var s := pad_axis + n * float(cell[axis]) + maxi(0, n - 1) * float(sp[axis])
		return Vector3(s, s, 0.0)
	var along := (str(lay.t) == "h") == (axis == 0)
	var control := bool(lay.get("cw" if axis == 0 else "ch", false))
	var expand := bool(lay.get("ew" if axis == 0 else "eh", false))
	var spacing := float(lay.get("sp", 0.0))
	var mn := 0.0
	var pref := 0.0
	var flex := 0.0
	for k in kids:
		var s := _child_sizes(k, axis, control, expand)
		if along:
			mn += s.x
			pref += s.y
			flex += s.z
		else:
			mn = maxf(mn, s.x)
			pref = maxf(pref, s.y)
			flex = maxf(flex, s.z)
	if along and kids.size() > 1:
		mn += spacing * (kids.size() - 1)
		pref += spacing * (kids.size() - 1)
	return Vector3(mn + pad_axis, pref + pad_axis, flex)


static func _child_sizes(k: Control, axis: int, control: bool, expand: bool) -> Vector3:
	var s: Vector3
	if not control:
		var sz := ((k.get_meta("u_rect") as Dictionary).size as Vector2)[axis]
		s = Vector3(sz, sz, 0.0)
	else:
		s = layout_sizes(k, axis)
	if expand:
		s.z = maxf(s.z, 1.0)
	return s


static func _grid_cols(c: Control, lay: Dictionary, count: int) -> int:
	var cons := int(lay.get("cons", 0))
	var n := int(lay.get("count", 2))
	if cons == 1:
		return maxi(1, n)
	if cons == 2:
		return maxi(1, ceili(float(count) / float(maxi(1, n))))
	var pad: Array = lay.get("pad", [0, 0, 0, 0])
	var cell: Array = lay.get("cell", [100, 100])
	var sp: Array = lay.get("sp", [0, 0])
	var w := c.size.x - float(pad[0]) - float(pad[1])
	return maxi(1, floori((w + float(sp[0]) + 0.001) / (float(cell[0]) + float(sp[0]))))


## LayoutGroup.GetStartOffset.
static func _start_offset(c: Control, lay: Dictionary, axis: int, required: float) -> float:
	var pad: Array = lay.get("pad", [0, 0, 0, 0])
	var pad_axis := float(pad[0]) + float(pad[1]) if axis == 0 else float(pad[2]) + float(pad[3])
	var surplus := c.size[axis] - (required + pad_axis)
	var al := int(lay.get("al", 0))
	var align := float(al % 3) * 0.5 if axis == 0 else float(al / 3) * 0.5
	return (float(pad[0]) if axis == 0 else float(pad[2])) + surplus * align


## LayoutGroup.SetChildAlongAxis: anchor top-left, pos from the top-left edge.
static func _place(k: Control, axis: int, pos: float, size: float = -1.0) -> void:
	var r: Dictionary = k.get_meta("u_rect")
	var pv: Vector2 = r.pivot
	var sz: Vector2 = r.size
	if size >= 0.0:
		sz[axis] = size
	if axis == 0:
		r.amin = Vector2(0.0, (r.amin as Vector2).y)
		r.amax = Vector2(0.0, (r.amax as Vector2).y)
		r.pos = Vector2(pos + sz.x * pv.x, (r.pos as Vector2).y)
	else:
		r.amin = Vector2((r.amin as Vector2).x, 1.0)
		r.amax = Vector2((r.amax as Vector2).x, 1.0)
		r.pos = Vector2((r.pos as Vector2).x, -pos - sz.y * (1.0 - pv.y))
	r.size = sz
	apply_rect(k)


static func _arrange(c: Control, lay: Dictionary) -> void:
	var kids := _layout_children(c)
	if str(lay.t) == "g":
		_arrange_grid(c, lay, kids)
		return
	var vertical := str(lay.t) == "v"
	var spacing := float(lay.get("sp", 0.0))
	if bool(lay.get("rev", false)):
		kids.reverse()
	for axis in 2:
		var control := bool(lay.get("cw" if axis == 0 else "ch", false))
		var expand := bool(lay.get("ew" if axis == 0 else "eh", false))
		var pad: Array = lay.get("pad", [0, 0, 0, 0])
		var al := int(lay.get("al", 0))
		var align := float(al % 3) * 0.5 if axis == 0 else float(al / 3) * 0.5
		if vertical != (axis == 1):
			var inner := c.size[axis] - (float(pad[0]) + float(pad[1]) if axis == 0 else float(pad[2]) + float(pad[3]))
			for k in kids:
				var s := _child_sizes(k, axis, control, expand)
				var req := clampf(inner, s.x, s.y if s.z <= 0.0 else c.size[axis])
				var start := _start_offset(c, lay, axis, req)
				if control:
					_place(k, axis, start, req)
				else:
					var cur := ((k.get_meta("u_rect") as Dictionary).size as Vector2)[axis]
					_place(k, axis, start + (req - cur) * align)
		else:
			var g := _group_sizes(c, lay, axis)
			var pos := float(pad[0]) if axis == 0 else float(pad[2])
			var mult := 0.0
			var surplus := c.size[axis] - g.y
			if surplus > 0.0:
				if g.z == 0.0:
					pos = _start_offset(c, lay, axis, g.y - (float(pad[0]) + float(pad[1]) if axis == 0 else float(pad[2]) + float(pad[3])))
				else:
					mult = surplus / g.z
			var lerp_t := 0.0
			if g.x != g.y:
				lerp_t = clampf((c.size[axis] - g.x) / (g.y - g.x), 0.0, 1.0)
			for k in kids:
				var s := _child_sizes(k, axis, control, expand)
				var size := lerpf(s.x, s.y, lerp_t) + s.z * mult
				if control:
					_place(k, axis, pos, size)
				else:
					var cur := ((k.get_meta("u_rect") as Dictionary).size as Vector2)[axis]
					_place(k, axis, pos + (size - cur) * align)
				pos += size + spacing


static func _arrange_grid(c: Control, lay: Dictionary, kids: Array[Control]) -> void:
	var cell: Array = lay.get("cell", [100, 100])
	var sp: Array = lay.get("sp", [0, 0])
	var cols := _grid_cols(c, lay, kids.size())
	var rows := ceili(float(kids.size()) / float(maxi(1, cols)))
	var horizontal_first := int(lay.get("axis", 0)) == 0
	var per_main := cols if horizontal_first else rows
	var ax := mini(cols, kids.size())
	var ay := rows
	var req := Vector2(ax * float(cell[0]) + maxi(0, ax - 1) * float(sp[0]), ay * float(cell[1]) + maxi(0, ay - 1) * float(sp[1]))
	var start := Vector2(_start_offset(c, lay, 0, req.x), _start_offset(c, lay, 1, req.y))
	var corner := int(lay.get("corner", 0))
	for i in kids.size():
		var px := i % per_main if horizontal_first else i / per_main
		var py := i / per_main if horizontal_first else i % per_main
		if corner % 2 == 1:
			px = ax - 1 - px
		if corner / 2 == 1:
			py = ay - 1 - py
		_place(kids[i], 0, start.x + (float(cell[0]) + float(sp[0])) * px, float(cell[0]))
		_place(kids[i], 1, start.y + (float(cell[1]) + float(sp[1])) * py, float(cell[1]))


## ContentSizeFitter: 1 min size, 2 preferred size; keeps the pivot in place.
static func _fit(c: Control, fit: Dictionary) -> void:
	var r: Dictionary = c.get_meta("u_rect")
	var changed := false
	for axis in 2:
		var mode := int(fit.get("h" if axis == 0 else "v", 0))
		if mode == 0:
			continue
		var s := layout_sizes(c, axis)
		var want := s.x if mode == 1 else s.y
		var p := c.get_parent() as Control
		var stretch := (p.size[axis] if p != null else 0.0) * (((r.amax as Vector2) - (r.amin as Vector2))[axis])
		var sz: Vector2 = r.size
		sz[axis] = want - stretch
		r.size = sz
		changed = true
	if changed:
		apply_rect(c)
