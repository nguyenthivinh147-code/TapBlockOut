extends SceneTree
## Saves what a screen's setup() builds into its scene: scenes/<name>.tscn gets every node the script adds (Unity
## pieces, ThemeKit nodes) as plain nodes, with UnityUI.baking on so nothing runtime is kept (reveal, Animators,
## ScrollRects, auto size, clones). Use it once when moving a screen from code to its scene, then remove that
## building code from the script; it overwrites the scene.
## Run: tools/godot.sh --headless --path . -s res://tools/bake_screen.gd -- <name> ['{"setup": "args as JSON"}']

const UnityUI := preload("res://src/ui/unity_ui.gd")

const VIEW := Vector2(720, 1280)
## Metas the builders leave on a build owner (the screen root or a root it builds into) for runtime only.
const ROOT_METAS := ["u_fit"]


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("bake_screen: thiếu tên màn")
		quit(1)
		return
	var path := "res://scenes/%s.tscn" % args[0]
	var setup_args: Dictionary = {}
	if args.size() > 1:
		var d: Variant = JSON.parse_string(args[1])
		setup_args = d if d is Dictionary else {}
	UnityUI.baking = true
	# Same state on every run: a fresh save at level 30 (every feature open), fixed clock.
	var game: Node = root.get_node_or_null("Game")
	if game != null:
		game.call("reset_for_test", "user://bake_screen/save.json")
		game.s.level = 30
		game.test_now = 1_800_000_000
	var host := Control.new()
	host.size = VIEW
	root.add_child(host)
	var screen: Control = (load(path) as PackedScene).instantiate()
	host.add_child(screen)
	if screen.has_method("setup"):
		screen.call("setup", setup_args)
	for i in 2:
		await process_frame
	var err := save(screen, path)
	host.queue_free()
	await process_frame
	print("bake_screen: %s %s" % [path, "xong" if err == OK else "lỗi %d" % err])
	quit(0 if err == OK else 1)


static func save(screen: Control, path: String) -> int:
	for n in _nodes(screen):
		if not is_instance_valid(n) or n.is_queued_for_deletion():
			continue
		if n.has_meta("u_rt") or n.has_meta("u_clone"):
			n.get_parent().remove_child(n)
			n.free()
	for n in [screen] + _nodes(screen):
		for m in ROOT_METAS:
			if is_instance_valid(n) and n.has_meta(m):
				n.remove_meta(m)
	for n in _nodes(screen):
		if not is_instance_valid(n):
			continue
		if n.is_queued_for_deletion():
			n.get_parent().remove_child(n)
			n.free()
			continue
		for m in UnityUI.RUNTIME_METAS:
			if n.has_meta(m):
				n.remove_meta(m)
		# Nodes the script added; nodes of an instanced layer keep that scene as owner.
		if n.owner == null:
			n.owner = screen
	# Only the spec keys runtime reads (pieces built from a spec carry their children's, which the scene holds), one
	# box per margins. Run tools/slim_scenes.gd on the layers first, or slimmed metas of their nodes become overrides.
	UnityUI.slim(screen)
	# Nodes the script added unnamed or under a sibling's name are auto-named "@Class@N"; a saved name like that
	# crashes later runs (UnityUI.readable_names).
	UnityUI.readable_names(screen, screen)
	# Changes to an instanced scene's nodes and nodes added under it are saved only when its children are
	# editable. A Unity layer Canvas always is (the screen hides, resizes and fills prefab nodes); another screen's
	# scene (board_view in level) only when nodes were added under it, so its children are not copied in.
	for n in _nodes(screen):
		if n.scene_file_path != "" and n.owner == screen:
			var added := _nodes(n).any(func(k: Node) -> bool: return k.owner == screen)
			screen.set_editable_instance(n, added or n.has_meta("u_canvas"))
	var ps := PackedScene.new()
	var err := ps.pack(screen)
	if err == OK:
		err = ResourceSaver.save(ps, path)
	if err == OK:
		_drop_layout_overrides(path)
	return err


## Descendants in tree order without internal children (a ScrollContainer's scroll bars), which the node makes
## itself and a scene must not hold.
static func _nodes(n: Node) -> Array[Node]:
	var out: Array[Node] = []
	for c in n.get_children():
		out.append(c)
		out.append_array(_nodes(c))
	return out


## Re-setting layout_mode on an anchored node of an instance moves the offsets the override does not store
## (btnTurnOff 128 wide instead of 64): drop it from override sections, the instanced scene has the right one.
static func _drop_layout_overrides(path: String) -> void:
	var lines := FileAccess.get_file_as_string(path).split("\n")
	var out: PackedStringArray = []
	var in_override := false
	for line in lines:
		if line.begins_with("["):
			in_override = line.begins_with("[node ") and line.contains(" parent=") and not line.contains(" type=") \
				and not line.contains(" instance=")
		if in_override and line.begins_with("layout_mode = "):
			continue
		out.append(line)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(out))
