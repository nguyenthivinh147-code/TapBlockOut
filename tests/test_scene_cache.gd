extends RefCounted
## SceneCache (src/ui/scene_cache.gd): holds the scenes opened last and lets the oldest go; UnityUI.instance loads
## through it; opening a scene leaves the resources every instance of a held PackedScene shares as they were.
const T := preload("res://tests/t.gd")
const SceneCache := preload("res://src/ui/scene_cache.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")

const DIR := "user://test_test_scene_cache"
const A := "res://scenes/popup_notice.tscn"
const B := "res://scenes/popup_rate.tscn"
const C := "res://scenes/popup_update.tscn"
## Not opened: the game root, the debug gallery, the tester menu (its buttons wipe the save).
const SKIP := ["main.tscn", "ui_gallery.tscn", "tester_menu.tscn"]
## Scenes open at the same time, and how long each batch stays open (past the 0.4 s reveal and a shine sweep).
const BATCH := 6
const OPEN_SEC := 0.5


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func test_keeps_last_opened(t: T) -> void:
	var cap := SceneCache.capacity
	SceneCache.clear()
	SceneCache.capacity = 2
	var a := SceneCache.scene(A)
	SceneCache.scene(B)
	t.ok(SceneCache.scene(A) == a, "scene giữ lại là cùng một PackedScene")
	SceneCache.scene(C)
	t.eq(SceneCache.held(), [A, C], "đầy thì bỏ scene mở lâu nhất")
	SceneCache.capacity = 0
	SceneCache.clear()
	var n := SceneCache.instantiate(A)
	t.ok(n is Control, "capacity 0 vẫn nạp được")
	n.free()
	t.eq(SceneCache.held(), [], "capacity 0 không giữ gì")
	SceneCache.capacity = cap
	SceneCache.clear()


## A screen that builds its layer at runtime and then clones from it (UView.clone -> pristine_of) loads the layer
## once: the second instance comes from the held scene.
func test_layer_instances_held(t: T) -> void:
	SceneCache.clear()
	var a := UnityUI.instance("PopupOkLayer")
	t.eq(SceneCache.held(), [UnityUI.BAKED + "PopupOkLayer.tscn"], "layer giữ trong cache")
	var ps := SceneCache.scene(UnityUI.BAKED + "PopupOkLayer.tscn")
	var b := UnityUI.instance("PopupOkLayer")
	t.ok(SceneCache.scene(UnityUI.BAKED + "PopupOkLayer.tscn") == ps, "lần hai lấy từ cache")
	t.eq(SceneCache.held().size(), 1, "một layer, một mục")
	a.free()
	b.free()
	SceneCache.clear()


## Every screen and popup opened from held scenes (its layers held too): no material, stylebox, font or animation
## those PackedScenes share is changed, so nothing carries over to the next open. Code that must change one
## duplicates it (or sets resource_local_to_scene, like board_view's frame materials).
func test_open_keeps_shared_resources(t: T) -> void:
	var g: Node = _tree().root.get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	g.s.level = 30
	var cap := SceneCache.capacity
	SceneCache.clear()
	SceneCache.capacity = 1000
	for f in DirAccess.get_files_at(UnityUI.BAKED):
		if f.ends_with(".tscn"):
			SceneCache.scene(UnityUI.BAKED + f)
	var paths: Array[String] = []
	for f in DirAccess.get_files_at("res://scenes"):
		if f.ends_with(".tscn") and not SKIP.has(f):
			paths.append("res://scenes/" + f)
			SceneCache.scene("res://scenes/" + f)
	var owners := {}
	var res := _shared(owners)
	t.ok(res.size() > 100, "có resource dùng chung để so: %d" % res.size())
	var before := _snap(res)
	# The check sees a change to a shared resource.
	var probe: StyleBox = null
	for r in res:
		if r is StyleBoxEmpty:
			probe = r
			break
	probe.content_margin_left += 1.0
	t.ok(_snap(res) != before, "đổi một resource dùng chung thì thấy")
	probe.content_margin_left -= 1.0
	for i in range(0, paths.size(), BATCH):
		var hosts: Array[Control] = []
		for p in paths.slice(i, i + BATCH):
			var host := Control.new()
			host.size = Vector2(720, 1280)
			_tree().root.add_child(host)
			hosts.append(host)
			var node := SceneCache.instantiate(p)
			host.add_child(node)
			for m in node.get_method_list():
				if m.name == "setup" and m.args.size() >= 1 and int(m.args[0].type) == TYPE_DICTIONARY:
					node.call("setup", {})
					break
		await _tree().create_timer(OPEN_SEC).timeout
		for h in hosts:
			h.free()
		await _tree().process_frame
	var after := _snap(res)
	var changed: Array[String] = []
	for k in before:
		if before[k] != after[k]:
			changed.append("%s (%s): %s" % [k, owners[k], _first_diff(str(before[k]), str(after[k]))])
	t.eq(changed, [] as Array[String], "mở scene làm đổi resource dùng chung")
	SceneCache.capacity = cap
	SceneCache.clear()


## Resources the held PackedScenes give their instances, by key; owners: key -> file of the scene saving it. Scripts,
## textures and font files are left out (code does not edit those).
func _shared(owners: Dictionary) -> Array:
	var out: Array = []
	var seen := {}
	for p in SceneCache.held():
		var ps := SceneCache.scene(p)
		for v in (ps.get("_bundled") as Dictionary).get("variants", []):
			_walk(v, p.get_file(), out, seen, owners)
	return out


func _walk(v: Variant, owner: String, out: Array, seen: Dictionary, owners: Dictionary) -> void:
	if v is Array:
		for e in v:
			_walk(e, owner, out, seen, owners)
	elif v is Dictionary:
		for k in v:
			_walk(v[k], owner, out, seen, owners)
	elif v is Resource:
		var r := v as Resource
		if seen.has(r.get_instance_id()) or r is Texture2D or r is Script or r is FontFile or r is PackedScene:
			return
		seen[r.get_instance_id()] = true
		out.append(r)
		owners[_key(r)] = owner
		for p in r.get_property_list():
			if int(p.usage) & PROPERTY_USAGE_STORAGE:
				_walk(r.get(p.name), owner, out, seen, owners)


func _key(r: Resource) -> String:
	return "%s#%d" % [r.get_class(), r.get_instance_id()]


func _snap(res: Array) -> Dictionary:
	var d := {}
	for r in res:
		var parts: PackedStringArray = []
		for p in (r as Resource).get_property_list():
			if int(p.usage) & PROPERTY_USAGE_STORAGE:
				var v: Variant = r.get(p.name)
				parts.append("%s=%s" % [p.name, _key(v) if v is Resource else str(v)])
		if r is ShaderMaterial and (r as ShaderMaterial).shader != null:
			for u in (r as ShaderMaterial).shader.get_shader_uniform_list():
				parts.append("%s=%s" % [u.name, (r as ShaderMaterial).get_shader_parameter(u.name)])
		d[_key(r)] = "; ".join(parts)
	return d


func _first_diff(a: String, b: String) -> String:
	var pa := a.split("; ")
	var pb := b.split("; ")
	for i in mini(pa.size(), pb.size()):
		if pa[i] != pb[i]:
			return "%s -> %s" % [pa[i].left(120), pb[i].left(120)]
	return "%d -> %d thuộc tính" % [pa.size(), pb.size()]
