extends RefCounted
## Thân khối kẹo: dựng texture khoảng cách-tới-mép (SDF) cho từng hình khối rồi tô bằng `pudding.gdshader`.
## SDF không phụ thuộc màu hay cỡ ô nên cache theo hình. Hàm tĩnh, cache tĩnh.
## Hình của data/levels và data/road_trip lấy từ bank bake sẵn (tools/bake_sdf.gd); hình khác (level sinh lúc chạy)
## dựng trên WorkerThreadPool qua prewarm(), hoặc dựng ngay trên luồng chính nếu chưa ai gọi prewarm.

const SHADER := preload("res://src/ui/pudding.gdshader")
const PuddingBank := preload("res://src/ui/pudding_bank.gd")
const BANK_PATH := "res://data/pudding_sdf.res"
const FIELD_VERSION := 1  # bump when field() changes in a way the constants below do not capture

enum BankState { NONE, LOADING, READY }

const RES := 16  # px mỗi ô trong texture SDF
const PAD_PX := 5  # lề quanh khối (px SDF), chứa bóng đổ và viền khử răng cưa
const PAD := float(PAD_PX) / RES  # cùng lề đó tính theo ô
const GAP := 0.014  # mỗi khối lùi vào chừng này (ô), khe giữa hai khối gấp đôi
const RADIUS := 0.25  # bo góc lồi (ô)
const FILLET := 0.13  # bo góc lõm (ô)
const SHADOW_A := 0.34  # độ đậm bóng đổ
const FAR := 1.0e6

static var _cache: Dictionary = {}  # khoá hình -> {tex, dims}
static var _bank: Resource = null  # pudding_bank.gd; null when missing or baked with another signature()
static var _bank_index: Dictionary = {}  # shape key -> index in _bank
static var _bank_state: BankState = BankState.NONE
static var _jobs: Dictionary = {}  # shape key -> {task, out}: SDF images building on WorkerThreadPool


## Control chứa thân khối, nằm sau phần vẽ của BlockNode.
class Body extends Control:
	var tex: Texture2D = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		show_behind_parent = true
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		material = ShaderMaterial.new()
		(material as ShaderMaterial).shader = SHADER

	func _draw() -> void:
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)


static func make_body() -> Control:
	return Body.new()


## Thân chỉ vẽ bóng đổ, đặt ở lớp nằm dưới mọi khối.
static func make_shadow() -> Control:
	var b := Body.new()
	var m: ShaderMaterial = b.material
	m.set_shader_parameter("body_a", 0.0)
	m.set_shader_parameter("shadow_a", SHADOW_A)
	return b


## Đặt lại thân khối theo ô và màu hiện tại. `cells` theo toạ độ ô gốc của BlockNode, `at` là góc ô gốc.
## `ramp` có deep, side, face, stripe; `overlay` phủ trong hình khối, `flash` 0..1 là nháy sáng.
static func update_body(body: Control, cells: Array, cell: float, ramp: Dictionary, overlay: Color = Color(0, 0, 0, 0), flash: float = 0.0, at: Vector2 = Vector2.ZERO) -> void:
	var entry := sdf_for(cells)
	var dims: Vector2 = entry["dims"]
	body.position = at + Vector2(-PAD, -PAD) * cell
	body.size = dims * cell
	body.tex = entry["tex"]
	var m: ShaderMaterial = body.material
	apply_material(m, entry, cell, ramp)
	m.set_shader_parameter("overlay", overlay)
	m.set_shader_parameter("flash", flash)
	body.queue_redraw()


## Lớp vật cản trên thân: `jelly` lớp pudding phủ trọn khối, `paper` hộp giấy thay thân kẹo, `tape` tâm băng dán
## của hộp (toạ độ ô của khối), `candy_a` 0 thì chỉ còn lớp pudding.
static func set_layers(body: Control, jelly: float, paper: float, tape: Vector2 = Vector2(-9, -9), candy_a: float = 1.0) -> void:
	var m: ShaderMaterial = body.material
	m.set_shader_parameter("jelly", jelly)
	m.set_shader_parameter("paper", paper)
	m.set_shader_parameter("tape", tape)
	m.set_shader_parameter("candy_a", candy_a)


## Lớp phủ: `thick` 1 là lớp dày (khối 2 lớp), `frost` 1 là băng thay cho pudding.
static func set_cover(body: Control, thick: float, frost: float) -> void:
	var m: ShaderMaterial = body.material
	m.set_shader_parameter("jelly_thick", thick)
	m.set_shader_parameter("ice_mat", frost)


## Ruy băng: số dải satin còn quấn trên khối (0..Config.RIBBON_MAX_LAYERS).
static func set_ribbons(body: Control, ribbons: float) -> void:
	(body.material as ShaderMaterial).set_shader_parameter("ribbons", ribbons)


## Chất liệu thân: `crystal` 1 là khối crystal (mảnh leaderboard), 0 là kẹo sọc.
static func set_crystal(body: Control, crystal: float) -> void:
	(body.material as ShaderMaterial).set_shader_parameter("crystal", crystal)


## Đặt các tham số chất liệu chung (`candy_body.gdshaderinc`) cho một material.
static func apply_material(m: ShaderMaterial, entry: Dictionary, cell: float, ramp: Dictionary) -> void:
	m.set_shader_parameter("sdf", entry["tex"])
	for tone in ["deep", "side", "face", "stripe"]:
		m.set_shader_parameter(tone, ramp[tone])
	m.set_shader_parameter("dims", entry["dims"])
	m.set_shader_parameter("pad", PAD)
	m.set_shader_parameter("cell_px", cell)


## {tex, dims} of the shape. Order: cache, a prewarm() job (waits for that one only), the baked bank, then a build
## on the main thread (about 30 ms per shape on desktop).
static func sdf_for(cells: Array) -> Dictionary:
	var key := shape_key(cells)
	if _cache.has(key):
		return _cache[key]
	var img: Image = _finish_job(key) if _jobs.has(key) else null
	if img == null:
		img = _bank_image(key)
	if img == null:
		img = image_for(cells)
	var entry := _entry(img)
	_cache[key] = entry
	return entry


static func shape_key(cells: Array) -> String:
	var parts: PackedStringArray = []
	for c: Vector2i in cells:
		parts.append("%d,%d" % [c.x, c.y])
	parts.sort()
	return ";".join(parts)


## Cells moved so the bounding box starts at (0, 0), as BlockNode.local_cells() passes them to sdf_for().
static func local_shape(cells: Array) -> Array:
	var mn := Vector2i(1 << 20, 1 << 20)
	var out: Array = []
	for raw: Variant in cells:
		var c: Vector2i = raw if raw is Vector2i else Vector2i(int(raw[0]), int(raw[1]))
		mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
		out.append(c)
	for i in out.size():
		out[i] = (out[i] as Vector2i) - mn
	return out


## Local shapes of every block in a level dictionary (data/levels, data/road_trip, LevelGenerator output).
static func level_shapes(level: Dictionary) -> Array:
	var out: Array = []
	for b: Dictionary in level.get("blocks", []):
		out.append(local_shape(b.get("cells", [])))
	return out


## Everything that changes the bytes of image_for(); the bank stores it and is ignored when it differs.
static func signature() -> String:
	return "v%d res%d pad%d gap%s r%s f%s" % [FIELD_VERSION, RES, PAD_PX, GAP, RADIUS, FILLET]


## SDF image (FORMAT_RH) of a shape. Pure and thread-safe: prewarm() runs it on WorkerThreadPool, the bake tool too.
static func image_for(cells: Array) -> Image:
	var f := field(cells)
	var w: int = f["w"]
	var h: int = f["h"]
	var data: PackedFloat32Array = f["data"]
	var img := Image.create(w, h, false, Image.FORMAT_RH)
	for y in h:
		for x in w:
			img.set_pixel(x, y, Color(data[y * w + x], 0.0, 0.0, 1.0))
	return img


static func _entry(img: Image) -> Dictionary:
	return {"tex": ImageTexture.create_from_image(img), "dims": Vector2(img.get_width(), img.get_height()) / float(RES)}


# --- baked bank and background builds ---

## Starts reading the bank on a loader thread (Main calls it as the splash opens). Without it the first sdf_for()
## or prewarm() reads the bank on the main thread.
static func load_bank_async() -> void:
	if _bank_state != BankState.NONE:
		return
	if ResourceLoader.exists(BANK_PATH) and ResourceLoader.load_threaded_request(BANK_PATH) == OK:
		_bank_state = BankState.LOADING


## Blocks until the bank is read (or known to be missing or stale). Main calls it when the splash ends.
static func ensure_bank() -> void:
	if _bank_state == BankState.READY:
		return
	var res: Resource = null
	if _bank_state == BankState.LOADING:
		res = ResourceLoader.load_threaded_get(BANK_PATH)
	elif ResourceLoader.exists(BANK_PATH):
		res = load(BANK_PATH)
	_bank_state = BankState.READY
	if res == null or res.get_script() != PuddingBank:
		return
	if res.get("signature") != signature():
		push_warning("Pudding: %s was baked for '%s', the code is '%s'; run tools/bake_sdf.gd" % [
			BANK_PATH, res.get("signature"), signature()])
		return
	_bank = res
	var keys: PackedStringArray = res.get("keys")
	for i in keys.size():
		_bank_index[keys[i]] = i


## Takes a load_bank_async() still in flight (leaving during the splash), so ResourceLoader frees its token.
static func finish_bank_load() -> void:
	if _bank_state == BankState.LOADING:
		ensure_bank()


static func has_baked(cells: Array) -> bool:
	ensure_bank()
	return _bank_index.has(shape_key(cells))


static func _bank_image(key: String) -> Image:
	ensure_bank()
	var i: int = _bank_index.get(key, -1)
	if i < 0:
		return null
	var sizes: PackedInt32Array = _bank.get("sizes")
	var offsets: PackedInt32Array = _bank.get("offsets")
	var w := sizes[2 * i]
	var h := sizes[2 * i + 1]
	var packed: PackedByteArray = (_bank.get("data") as PackedByteArray).slice(offsets[i], offsets[i + 1])
	var bytes := packed.decompress(w * h * 2, FileAccess.COMPRESSION_ZSTD)  # FORMAT_RH: 2 bytes per pixel
	if bytes.size() != w * h * 2:
		push_warning("Pudding: baked shape %s is damaged; building it" % key)
		return null
	return Image.create_from_data(w, h, false, Image.FORMAT_RH, bytes)


## Builds on WorkerThreadPool the SDFs of `shapes` (local cells, as sdf_for takes them) that are neither cached nor
## baked. Call it as soon as the level is known, then wait on is_warm() behind a loading or transition screen.
static func prewarm(shapes: Array) -> void:
	ensure_bank()
	for cells: Array in shapes:
		var key := shape_key(cells)
		if _cache.has(key) or _jobs.has(key) or _bank_index.has(key):
			continue
		# The worker writes only into `out`; the main thread reads it after the task is waited for. High priority: a
		# low priority task gets about a third of the pool, and the screen is waiting on these.
		var out: Array = [null]
		var task := WorkerThreadPool.add_task(_run_job.bind(cells.duplicate(), out), true, "Pudding SDF")
		_jobs[key] = {"task": task, "out": out}


static func _run_job(cells: Array, out: Array) -> void:
	out[0] = image_for(cells)


## True when no prewarm() job is left; finished jobs move into the cache (textures are made on the calling thread,
## which must be the main one).
static func is_warm() -> bool:
	for key: String in _jobs.keys():
		if WorkerThreadPool.is_task_completed(int(_jobs[key]["task"])):
			_cache[key] = _entry(_finish_job(key))
	return _jobs.is_empty()


static func pending_jobs() -> int:
	return _jobs.size()


static func _finish_job(key: String) -> Image:
	var job: Dictionary = _jobs[key]
	_jobs.erase(key)
	WorkerThreadPool.wait_for_task_completion(int(job["task"]))
	return (job["out"] as Array)[0]


## Khoảng cách có dấu tới mép hình khối (đơn vị ô, dương là bên trong): {"w", "h", "data"}, ô (0, 0) bắt đầu ở pixel PAD_PX.
static func field(cells: Array) -> Dictionary:
	var max_c := Vector2i.ZERO
	for c: Vector2i in cells:
		max_c = Vector2i(maxi(max_c.x, c.x), maxi(max_c.y, c.y))
	var w := (max_c.x + 1) * RES + 2 * PAD_PX
	var h := (max_c.y + 1) * RES + 2 * PAD_PX
	# mặt nạ hình khối, ô liền nhau thì liền
	var inside := PackedByteArray()
	inside.resize(w * h)
	for c: Vector2i in cells:
		var x0 := PAD_PX + c.x * RES
		var y0 := PAD_PX + c.y * RES
		for y in range(y0, y0 + RES):
			for x in range(x0, x0 + RES):
				inside[y * w + x] = 1
	# bo góc lõm: nở ra FILLET rồi co lại
	var fillet_px := FILLET * RES
	var d_out := _chamfer(inside, w, h, true)
	var grown := PackedByteArray()
	grown.resize(w * h)
	for i in w * h:
		if inside[i] == 1 or d_out[i] - 0.5 <= fillet_px:
			grown[i] = 1
	var d_grown := _chamfer(grown, w, h, false)
	var closed := PackedByteArray()
	closed.resize(w * h)
	for i in w * h:
		if grown[i] == 1 and d_grown[i] - 0.5 > fillet_px:
			closed[i] = 1
	# bo góc lồi: co vào RADIUS rồi nở ra lại (SDF của phần đã co, cộng lại RADIUS)
	var radius_px := RADIUS * RES
	var d_in := _chamfer(closed, w, h, false)
	var eroded := PackedByteArray()
	eroded.resize(w * h)
	for i in w * h:
		if closed[i] == 1 and d_in[i] - 0.5 >= radius_px:
			eroded[i] = 1
	var e_in := _chamfer(eroded, w, h, false)
	var e_out := _chamfer(eroded, w, h, true)
	var sd_cells := PackedFloat32Array()
	sd_cells.resize(w * h)
	for i in w * h:
		var sd: float = e_in[i] - 0.5 if eroded[i] == 1 else -(e_out[i] - 0.5)
		sd_cells[i] = (sd + radius_px) / float(RES) - GAP
	return {"w": w, "h": h, "data": _smooth(sd_cells, w, h)}


## Làm mượt 1-2-1 theo hai chiều: mặt nạ nhị phân để lại bậc thang nhỏ trên đường cong của SDF.
static func _smooth(f: PackedFloat32Array, w: int, h: int) -> PackedFloat32Array:
	var a := f.duplicate()
	for y in h:
		for x in range(1, w - 1):
			var i := y * w + x
			a[i] = (f[i - 1] + 2.0 * f[i] + f[i + 1]) * 0.25
	var b := a.duplicate()
	for y in range(1, h - 1):
		for x in w:
			var i := y * w + x
			b[i] = (a[i - w] + 2.0 * a[i] + a[i + w]) * 0.25
	return b


## Khoảng cách Euclid (px) từ mỗi pixel tới pixel gần nhất thuộc phía đối diện (Felzenszwalb, hai lượt 1 chiều).
## `to_inside` false: đo từ pixel trong mặt nạ tới pixel ngoài; true: từ pixel ngoài tới pixel trong.
static func _chamfer(mask: PackedByteArray, w: int, h: int, to_inside: bool) -> PackedFloat32Array:
	var target := 1 if to_inside else 0
	var f := PackedFloat32Array()
	f.resize(w * h)
	for i in w * h:
		f[i] = 0.0 if mask[i] == target else FAR
	var n := maxi(w, h)
	var col := PackedFloat32Array()
	col.resize(n)
	var out := PackedFloat32Array()
	out.resize(n)
	var v := PackedInt32Array()
	v.resize(n)
	var z := PackedFloat32Array()
	z.resize(n + 1)
	# lượt theo cột rồi theo hàng
	for pass_i in 2:
		var lines := w if pass_i == 0 else h
		var len_ := h if pass_i == 0 else w
		for l in lines:
			for k in len_:
				col[k] = f[k * w + l] if pass_i == 0 else f[l * w + k]
			_dt1d(col, out, v, z, len_)
			for k in len_:
				if pass_i == 0:
					f[k * w + l] = out[k]
				else:
					f[l * w + k] = out[k]
	for i in w * h:
		f[i] = sqrt(minf(f[i], 1.0e6))
	return f


static func _dt1d(src: PackedFloat32Array, dst: PackedFloat32Array, v: PackedInt32Array, z: PackedFloat32Array, n: int) -> void:
	var k := 0
	v[0] = 0
	z[0] = -FAR
	z[1] = FAR
	for q in range(1, n):
		var s := 0.0
		while true:
			var p := v[k]
			s = ((src[q] + q * q) - (src[p] + p * p)) / float(2 * q - 2 * p)
			if s <= z[k] and k > 0:
				k -= 1
			else:
				break
		if s <= z[k]:
			# k == 0 và vẫn thấp hơn: thay hẳn
			v[0] = q
			z[0] = -FAR
			z[1] = FAR
			continue
		k += 1
		v[k] = q
		z[k] = s
		z[k + 1] = FAR
	k = 0
	for q in n:
		while z[k + 1] < q:
			k += 1
		var p := v[k]
		dst[q] = float((q - p) * (q - p)) + src[p]
