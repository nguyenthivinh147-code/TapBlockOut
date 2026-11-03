extends RefCounted
## A built Unity layout: look nodes up by prefab path ("Panel/Top/txtHeader", "Content/Item#2" for the 2nd
## sibling with that name), by serialized script field (field("okButton")), or by name anywhere (find()).

const UnityUI := preload("res://src/ui/unity_ui.gd")

var canvas: Control = null
var root: Control = null
## path -> Control, relative to root ("" is root).
var paths := {}
## Unity GameObject id -> Control.
var ids := {}
## [{node, cs}] for every custom script entry, in tree order.
var scripts: Array = []
## DialogueReveal / ShowPopupAnimation config: {panel, dim, dur, ease}.
var reveal_cfg: Dictionary = {}
## node id -> Callable for UIAnimationBase scripts (PlayAnimation).
var anims := {}
## node id -> Callable that cancels an animation (AnimScaleButton.StopAnim).
var stops := {}


func node(p: String = "") -> Control:
	var n: Control = paths.get(p)
	if n == null:
		push_warning("UView: không có node '%s'" % p)
	return n


func has(p: String) -> bool:
	return paths.has(p)


## First node named `n_name` in tree order (Unity GameObject name).
func find(n_name: String) -> Control:
	for p in paths:
		var c: Control = paths[p]
		if str(c.get_meta("u", {}).get("n", "")) == n_name:
			return c
	return null


func label(p: String) -> Label:
	return node(p) as Label


func button(p: String) -> Button:
	return node(p) as Button


## The u_image of a path (a button's own image child when the node is a button).
func image(p: String) -> Control:
	return UnityUI.image_of(node(p))


## Node(s) a script field points to; script narrows the search to one component name.
func field(f: String, script: String = "") -> Variant:
	for e in scripts:
		var cs: Dictionary = e.cs
		if script != "" and str(cs.get("name", "")) != script:
			continue
		if cs.has(f):
			return _deref(cs[f])
	return null


func _deref(v: Variant) -> Variant:
	if v is Dictionary and (v as Dictionary).has("node"):
		return ids.get(str(v.node))
	if v is Array:
		var out: Array = []
		for x in v:
			out.append(_deref(x))
		return out
	return v


func text(p: String, s: String) -> Label:
	var l := label(p)
	if l != null:
		UnityUI.set_text(l, s)
	return l


func sprite(p: String, key: String) -> void:
	UnityUI.set_sprite(node(p), key)


func texture(p: String, tex: Texture2D) -> void:
	var img := image(p)
	if img != null:
		img.call("set_texture", tex)


func show(p: String, on: bool = true) -> void:
	var n := node(p)
	if n != null:
		n.visible = on


func on_click(p: String, cb: Callable) -> Button:
	var b := button(p)
	if b != null:
		b.connect("clicked", cb)
	return b


## Copy of a template subtree (Unity pools clone an inactive item); returns its own view. parent_path
## defaults to the template's parent. The copy is shown and added after the last sibling.
func clone(template_path: String, parent_path: String = "") -> RefCounted:
	var tpl := node(template_path)
	if tpl == null:
		return null
	var parent: Control = tpl.get_parent() if parent_path == "" else node(parent_path)
	var v := UnityUI.build_subtree(tpl.get_meta("u"), parent, canvas)
	v.root.visible = true
	return v


## Re-run the Unity layout groups and content size fitters below a path.
func relayout(p: String = "") -> void:
	UnityUI.relayout(node(p))


## DialogueReveal: panel scales 0 -> 1 and dim fades in (0.4 s OutBack in every prefab).
func reveal() -> void:
	UnityUI.play_reveal(self)


## UIAnimationBase.PlayAnimation on a node that has one (UIAnim_ScaleAppear, UIAnim_Pulse).
func play(p: String) -> void:
	var n := node(p)
	if n == null:
		return
	var cb: Callable = anims.get(str(n.get_meta("u", {}).get("id", "")), Callable())
	if cb.is_valid():
		cb.call()


## StopAnim on a node that has one (AnimScaleButton).
func stop(p: String) -> void:
	var n := node(p)
	if n == null:
		return
	var cb: Callable = stops.get(str(n.get_meta("u", {}).get("id", "")), Callable())
	if cb.is_valid():
		cb.call()


## Unity Animator of a node (u_anim.gd); `enabled = true` starts one the prefab keeps off.
func animator(p: String) -> Node:
	var n := node(p)
	return n.get_node_or_null("Animator") if n != null else null


## Slider.value (min..max of the prefab) on a node with a Unity Slider.
func slider(p: String, value: float) -> void:
	UnityUI.set_slider(node(p), value)


## The LineEdit / TextEdit of a TMP_InputField node.
func input(p: String) -> Control:
	var n := node(p)
	return n.get_meta("u_input") if n != null and n.has_meta("u_input") else null


## Sets an input field's text; its Placeholder follows.
func input_text(p: String, s: String) -> void:
	var e := input(p)
	if e != null:
		UnityUI.set_input_text(e, s)
