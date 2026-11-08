extends RefCounted
## Slim baked scenes (UnityUI.slim, tools/slim_scenes.gd): a layer whose specs are cut to SPEC_KEEP / TXT_KEEP before
## it is wired ends up like one wired with full specs; saved scenes are slim; boxes are shared.
const T := preload("res://tests/t.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")
const UButton := preload("res://src/ui/u_button.gd")
const UImage := preload("res://src/ui/u_image.gd")
const SlimScenes := preload("res://tools/slim_scenes.gd")

const DIR := "user://test_test_unity_slim"

static var AUTO_NAME := RegEx.create_from_string("@(\\w+)@\\d+")


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _owner(canvas: Control) -> Control:
	var o := Control.new()
	o.size = Vector2(720, 1280)
	o.add_child(canvas)
	_tree().root.add_child(o)
	return o


## Every layer exported to data/ui_unity, built twice in the same frames: full specs, and slim before wiring like
## a baked scene. A key runtime reads that SPEC_KEEP or TXT_KEEP drops shows up as a different node.
func test_slim_specs_wire_the_same(t: T) -> void:
	var layers: Array[String] = []
	for f in DirAccess.get_files_at(UnityUI.DIR):
		if f.ends_with(".json") and not f.begins_with("_"):
			layers.append(f.get_basename())
	t.ok(layers.size() > 40, "có layer để dựng: %d" % layers.size())
	var bad: Array[String] = []
	for layer in layers:
		var full := UnityUI.make_canvas(layer)
		var slim := UnityUI.make_canvas(layer)
		UnityUI.slim(slim)
		var oa := _owner(full)
		var ob := _owner(slim)
		var va := UnityUI.build(oa, layer)
		var vb := UnityUI.build(ob, layer)
		for i in 3:
			await _tree().process_frame
		var a: PackedStringArray = []
		var b: PackedStringArray = []
		_view(va, oa, a)
		_view(vb, ob, b)
		_snap(oa, oa, a)
		_snap(ob, ob, b)
		for i in mini(a.size(), b.size()):
			# Godot numbers auto-named duplicate siblings ("@Control@114") from one counter for the whole run.
			if AUTO_NAME.sub(a[i], "@$1@", true) != AUTO_NAME.sub(b[i], "@$1@", true):
				bad.append("%s:\n  đủ  %s\n  gọn %s" % [layer, a[i], b[i]])
				break
		if a.size() != b.size() and bad.is_empty():
			bad.append("%s: %d node / %d node" % [layer, a.size(), b.size()])
		oa.free()
		ob.free()
	t.eq(bad.size(), 0, "layer khác sau khi gọn spec:\n" + "\n".join(bad))


func _view(v: RefCounted, base: Node, out: PackedStringArray) -> void:
	var p: Array = v.paths.keys()
	p.sort()
	var a: Array = v.anims.keys()
	a.sort()
	var s: Array = v.stops.keys()
	s.sort()
	var names: Array = v.scripts.map(func(e: Dictionary) -> String: return str(e.cs.get("name", "")))
	var rc: Dictionary = v.reveal_cfg
	out.append("view paths=%s ids=%d scripts=%s subs=%d anims=%s stops=%s reveal=%s,%s,%s,%s" % [str(p).md5_text(),
		v.ids.size(), names, v.subs.size(), a, s, _rel(base, rc.get("panel")), _rel(base, rc.get("dim")),
		rc.get("dur"), rc.get("ease")])


func _rel(base: Node, n: Variant) -> String:
	return str(base.get_path_to(n)) if n is Node and is_instance_valid(n) else "-"


func _margins(c: Control, st: String) -> String:
	var b := c.get_theme_stylebox(st)
	return "-" if b == null else str([b.get_margin(SIDE_LEFT), b.get_margin(SIDE_TOP), b.get_margin(SIDE_RIGHT),
		b.get_margin(SIDE_BOTTOM)])


## One line per node: what the wiring sets (layout, input, text fit, tints, runtime children, metas).
func _snap(n: Node, base: Node, out: PackedStringArray) -> void:
	var l := "%s %s kids=%d" % [base.get_path_to(n), n.get_class(), n.get_child_count()]
	if n is Control:
		var c := n as Control
		l += " vis=%s mod=%s pos=%s size=%s scale=%s rot=%.4f mf=%d z=%d clip=%d/%s" % [c.visible, c.modulate,
			c.position.snappedf(0.01), c.size.snappedf(0.01), c.scale.snappedf(0.0001), c.rotation, c.mouse_filter,
			c.z_index, c.clip_children, c.clip_contents]
		for s in ["pressed", "resized", "toggled", "item_rect_changed"]:
			if c.has_signal(s):
				l += " %s=%d" % [s, c.get_signal_connection_list(s).size()]
	if n is Label:
		var lb := n as Label
		l += " text=%s fs=%d wrap=%d box=%s mat=%s" % [lb.text.c_escape(), lb.get_theme_font_size("font_size"),
			lb.autowrap_mode, _margins(lb, "normal"), lb.material != null]
	if n is UImage:
		l += " col=%s fill=%.4f mat=%s" % [n.color, n.fill_amount, n.material != null]
	if n is UButton:
		var b := n as UButton
		l += " dis=%s on=%s tint=%s graphic=%s group=%s pulse=%s fx=%d box=%s" % [b.disabled, b.button_pressed,
			_rel(base, b.tint_target), _rel(base, b.toggle_graphic),
			_rel(base, b.button_group.get_buttons()[0]) if b.button_group != null else "-", b.pulse_scale,
			b.press_effects.size(), _margins(b, "normal")]
	var metas: Array = []
	for m in n.get_meta_list():
		if m == "u_rect":
			var r: Dictionary = n.get_meta(m)
			metas.append("u_rect=%s" % [[r.amin, r.amax, (r.pos as Vector2).snappedf(0.01),
				(r.size as Vector2).snappedf(0.01), r.pivot]])
		elif m != "u" and m != "u_txt":
			metas.append(m)
	metas.sort()
	l += " metas=%s" % [metas]
	out.append(l)
	for ch in n.get_children(true):
		_snap(ch, base, out)


## Every saved scene is what tools/slim_scenes.gd would leave (the bake tools slim what they save).
func test_saved_scenes_are_slim(t: T) -> void:
	var files: Array[String] = []
	SlimScenes.scenes("res://scenes", files)
	t.ok(files.size() > 10, "có scene để quét: %d" % files.size())
	var fat: Array[String] = []
	for f in files:
		var text := FileAccess.get_file_as_string(f)
		if SlimScenes.slim_text(text) != text:
			fat.append(f)
	t.eq(fat, [] as Array[String], "scene chưa gọn, chạy tools/slim_scenes.gd")


## The text pass keeps runtime keys, drops the rest, merges equal boxes and points their users at the one kept.
func test_slim_text(t: T) -> void:
	var src := "\n".join([
		"[gd_scene format=3]",
		"",
		"[sub_resource type=\"StyleBoxEmpty\" id=\"A\"]",
		"",
		"[sub_resource type=\"StyleBoxEmpty\" id=\"B\"]",
		"",
		"[sub_resource type=\"StyleBoxEmpty\" id=\"C\"]",
		"content_margin_left = 4.0",
		"",
		"[node name=\"L\" type=\"Label\"]",
		"theme_override_styles/normal = SubResource(\"B\")",
		"text = \"a = b\"",
		"metadata/u = " + var_to_str({"id": "1", "n": "L", "r": [0, 0, 1, 1], "txt": {"rt": true, "s": "{x"}}),
		"metadata/u_txt = " + var_to_str({"fs": 30.0, "c": "ffffffff", "s": "multi\nline } ]"}),
		"",
		"[node name=\"K\" type=\"Label\" parent=\".\"]",
		"theme_override_styles/normal = SubResource(\"C\")",
		"",
	])
	var out := SlimScenes.slim_text(src)
	t.ok(not out.contains("id=\"B\""), "box trùng bị bỏ")
	t.ok(out.contains("id=\"C\""), "box khác margin giữ")
	t.ok(out.contains("theme_override_styles/normal = SubResource(\"A\")"), "node dùng box giữ lại")
	t.ok(out.contains("text = \"a = b\""), "thuộc tính khác giữ nguyên")
	t.ok(out.contains("metadata/u = " + var_to_str({"id": "1", "n": "L", "txt": {"rt": true}})), "spec chỉ còn khoá runtime")
	t.ok(out.contains("metadata/u_txt = " + var_to_str({"fs": 30.0})), "u_txt chỉ còn khoá runtime")
	t.eq(SlimScenes.slim_text(out), out, "chạy lại không đổi")


## Buttons and labels with the same margins draw one box, so a baked scene saves one sub-resource per margins.
func test_boxes_shared(t: T) -> void:
	var a := UButton.new()
	var b := UButton.new()
	t.ok(a.get_theme_stylebox("normal") == b.get_theme_stylebox("pressed"), "mọi trạng thái nút chung một box")
	t.ok(a.get_theme_stylebox("normal") == UnityUI.empty_box(), "box nút là empty_box()")
	t.ok(UnityUI.empty_box(Vector4(1, 2, 3, 4)) == UnityUI.empty_box(Vector4(1, 2, 3, 4)), "cùng margin, cùng box")
	t.near(UnityUI.empty_box(Vector4(1, 2, 3, 4)).content_margin_bottom, 4.0, 0.0001, "margin đúng")
	a.free()
	b.free()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var canvas := UnityUI.make_canvas("PopupOkLayer")
	for n in canvas.find_children("*", "", true, false):
		n.owner = canvas
	UnityUI.slim(canvas)
	var margins := {}
	for n in canvas.find_children("*", "Control", true, false):
		for st in ["normal", "pressed"]:
			var box := (n as Control).get_theme_stylebox(st)
			if box is StyleBoxEmpty and (n as Control).has_theme_stylebox_override(st):
				margins[[box.content_margin_left, box.content_margin_top, box.content_margin_right,
					box.content_margin_bottom]] = true
	var ps := PackedScene.new()
	ps.pack(canvas)
	canvas.free()
	var path := DIR + "/PopupOkLayer.tscn"
	t.eq(ResourceSaver.save(ps, path), OK, "lưu scene")
	var text := FileAccess.get_file_as_string(path)
	t.eq(text.count("[sub_resource type=\"StyleBoxEmpty\""), margins.size(), "một box mỗi margin")
	t.ok(not text.contains("\"r\": ["), "không lưu rect của spec")
	t.eq(SlimScenes.slim_text(text), text, "scene bake ra đã gọn")
