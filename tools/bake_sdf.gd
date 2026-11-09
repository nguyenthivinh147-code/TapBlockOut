extends SceneTree
## Bakes the block body SDF (src/ui/pudding.gd) of every block shape in data/levels, data/road_trip and data/special into
## data/pudding_sdf.res, so the game does not build them on the main thread when a level opens.
## Run again after regenerating levels or changing how Pudding builds the SDF; tests/test_pudding_bank.gd fails
## when the bank is out of date.
## Run: tools/godot.sh --headless --path . -s res://tools/bake_sdf.gd [-- --force]
## Without --force it keeps a bank that already has the same signature() and shape set (the export scripts call it).

const Pudding := preload("res://src/ui/pudding.gd")
const PuddingBank := preload("res://src/ui/pudding_bank.gd")

const DIRS := ["res://data/levels", "res://data/road_trip", "res://data/special"]
const EXTRA_SHAPES := [[Vector2i.ZERO]]  # CandyShards.prewarm() draws a one-cell block


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	var shapes := collect_shapes()
	if shapes.is_empty():
		printerr("No block shape found in %s" % [DIRS])
		quit(1)
		return
	var keys: Array = shapes.keys()
	keys.sort()
	if not ("--force" in OS.get_cmdline_user_args()) and is_current(PackedStringArray(keys)):
		print("%s is up to date (%d shapes)" % [Pudding.BANK_PATH, keys.size()])
		quit(0)
		return
	var outs: Array = []
	for k in keys:
		outs.append([null])
	# Each task writes only its own holder.
	var job := func(i: int) -> void:
		(outs[i] as Array)[0] = Pudding.image_for(shapes[keys[i]])
	var group := WorkerThreadPool.add_group_task(job, keys.size(), -1, true, "bake_sdf")
	WorkerThreadPool.wait_for_group_task_completion(group)
	var bank := PuddingBank.new()
	bank.signature = Pudding.signature()
	var sizes := PackedInt32Array()
	var offsets := PackedInt32Array()
	var data := PackedByteArray()
	var raw_bytes := 0
	for i in keys.size():
		var img: Image = (outs[i] as Array)[0]
		if img == null:
			printerr("Shape %s did not build" % keys[i])
			quit(1)
			return
		bank.keys.append(keys[i])
		sizes.append(img.get_width())
		sizes.append(img.get_height())
		offsets.append(data.size())
		raw_bytes += img.get_data().size()
		data.append_array(img.get_data().compress(FileAccess.COMPRESSION_ZSTD))
	offsets.append(data.size())
	bank.sizes = sizes
	bank.offsets = offsets
	bank.data = data
	var err := ResourceSaver.save(bank, Pudding.BANK_PATH)
	if err != OK:
		printerr("Could not save %s (error %d)" % [Pudding.BANK_PATH, err])
		quit(1)
		return
	var file_kb := FileAccess.get_file_as_bytes(Pudding.BANK_PATH).size() / 1024.0
	print("%d shapes, %.0f KB of pixels, %s %.0f KB, %d ms" % [keys.size(), raw_bytes / 1024.0,
		Pudding.BANK_PATH, file_kb, Time.get_ticks_msec() - t0])
	quit(0)


## The saved bank was baked by the current code for exactly these shape keys.
static func is_current(keys: PackedStringArray) -> bool:
	if not ResourceLoader.exists(Pudding.BANK_PATH):
		return false
	var bank: Resource = ResourceLoader.load(Pudding.BANK_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	return bank != null and bank.get("signature") == Pudding.signature() and bank.get("keys") == keys


## shape key -> local cells, for every block of every level file in DIRS plus EXTRA_SHAPES.
static func collect_shapes() -> Dictionary:
	var out := {}
	for cells: Array in EXTRA_SHAPES:
		out[Pudding.shape_key(cells)] = cells
	for dir_path: String in DIRS:
		for level: Dictionary in read_levels(dir_path):
			for cells: Array in Pudding.level_shapes(level):
				out[Pudding.shape_key(cells)] = cells
	return out


static func read_levels(dir_path: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	var files := dir.get_files()
	files.sort()
	for f in files:
		if not f.ends_with(".json"):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir_path + "/" + f))
		if parsed is Dictionary and (parsed as Dictionary).has("blocks"):
			out.append(parsed)
	return out
