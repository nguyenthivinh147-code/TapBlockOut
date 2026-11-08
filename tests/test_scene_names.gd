extends RefCounted
## Saved scenes hold no Godot auto-name "@Class@N": a run that auto-names a sibling with the same N makes the parent
## lose the saved child, which outlives the parent and crashes on its next layout (UnityUI.readable_names, used by
## tools/bake_screen.gd and tools/bake_unity_ui.gd before saving).
const T := preload("res://tests/t.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")
const ShopScene := preload("res://scenes/shop.tscn")

const DIR := "user://test_test_scene_names"


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _scenes(dir: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".tscn"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_scenes(dir.path_join(d), out)


func test_no_saved_auto_names(t: T) -> void:
	var files: Array[String] = []
	_scenes("res://scenes", files)
	t.ok(files.size() > 10, "có scene để quét: %d" % files.size())
	var bad: Array[String] = []
	for f in files:
		var lines := FileAccess.get_file_as_string(f).split("\n")
		for line in lines:
			if line.begins_with("[node name=\"@"):
				bad.append("%s: %s" % [f, line.get_slice("\"", 1)])
	t.eq(bad, [] as Array[String], "scene không lưu tên tự sinh @Class@N")


func test_readable_names(t: T) -> void:
	var root := Control.new()
	var owner := Control.new()
	root.add_child(owner)
	var keep := Control.new()
	keep.name = "Box"
	owner.add_child(keep)
	var unnamed := Control.new()
	owner.add_child(unnamed)
	var twin := Label.new()
	twin.name = "Box"
	owner.add_child(twin)
	t.ok(String(unnamed.name).begins_with("@"), "Godot tự đặt tên @: " + unnamed.name)
	t.ok(String(twin.name).begins_with("@"), "trùng tên anh em cũng thành @: " + twin.name)
	# A sibling already holding the target name pushes the rename to a free one.
	var parts := String(unnamed.name).split("@", false)
	var taken := Control.new()
	taken.name = "_".join(parts)
	owner.add_child(taken)
	var foreign := Control.new()
	owner.add_child(foreign)
	var foreign_name := String(foreign.name)
	for n in [keep, unnamed, twin, taken]:
		n.owner = owner
	UnityUI.readable_names(owner, owner)
	t.eq(String(keep.name), "Box", "tên thường giữ nguyên")
	t.eq(String(unnamed.name), "_".join(parts) + "_2", "tên đã có thì thêm hậu tố")
	t.ok(not String(twin.name).begins_with("@"), "hết @: " + twin.name)
	t.eq(String(foreign.name), foreign_name, "node không thuộc owner giữ nguyên")
	var names := {}
	for c in owner.get_children():
		names[String(c.name)] = true
	t.eq(names.size(), owner.get_child_count(), "tên anh em không trùng")
	UnityUI.readable_names(root)
	t.ok(not String(foreign.name).begins_with("@"), "không owner: đổi hết")
	root.free()


## Shops built and freed back to back, as the tests and tab switches do: nothing of them outlives the free.
func test_shops_free_all_their_nodes(t: T) -> void:
	var g: Node = _root().get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	var ids: Array[int] = []
	for i in 4:
		var shop: Node = ShopScene.instantiate()
		_root().add_child(shop)
		shop.call("setup", {"source": "test"})
		for n in shop.find_children("*", "Control", true, false):
			ids.append(n.get_instance_id())
		_root().remove_child(shop)
		shop.free()
	var alive := 0
	for id in ids:
		if is_instance_id_valid(id):
			alive += 1
	t.ok(ids.size() > 1000, "đã dựng đủ Shop: %d node" % ids.size())
	t.eq(alive, 0, "không node nào của Shop còn sống sau free")
	await _root().get_tree().process_frame
