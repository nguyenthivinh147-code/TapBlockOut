extends RefCounted
## Bank SDF bake sẵn (data/pudding_sdf.res, tools/bake_sdf.gd) khớp code Pudding và dữ liệu level; hình ngoài bank
## dựng trên WorkerThreadPool qua Pudding.prewarm().
const T := preload("res://tests/t.gd")
const Pudding := preload("res://src/ui/pudding.gd")
const PuddingBank := preload("res://src/ui/pudding_bank.gd")
const BakeTool := preload("res://tools/bake_sdf.gd")
const FIX := "chạy tools/godot.sh --headless --path . -s res://tools/bake_sdf.gd"
const SAMPLES := 12
const WAIT_MSEC := 10000


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _cells(key: String) -> Array:
	var out: Array = []
	for part in key.split(";"):
		var xy := part.split(",")
		out.append(Vector2i(int(xy[0]), int(xy[1])))
	return out


## Hình thử không có trong level nào: bốn góc rời nhau của khung 5×5 cộng ô giữa.
func _odd_shape(dx: int) -> Array:
	return [Vector2i(0, 0), Vector2i(4 + dx, 0), Vector2i(0, 4), Vector2i(4 + dx, 4), Vector2i(2, 2)]


func test_bank_matches_code(t: T) -> void:
	var bank: Resource = load(Pudding.BANK_PATH)
	t.ok(bank != null and bank.get_script() == PuddingBank, "có bank %s; %s" % [Pudding.BANK_PATH, FIX])
	if bank == null:
		return
	t.eq(bank.get("signature"), Pudding.signature(), "bank bake theo hằng số hiện tại; " + FIX)
	var keys: PackedStringArray = bank.get("keys")
	t.eq((bank.get("offsets") as PackedInt32Array).size(), keys.size() + 1, "mỗi hình một offset, thêm offset cuối")
	t.eq((bank.get("sizes") as PackedInt32Array).size(), keys.size() * 2, "mỗi hình rộng và cao")
	# Đổi field() mà quên tăng FIELD_VERSION: bản bake khác bản dựng lại.
	var step := maxi(1, keys.size() / SAMPLES)
	for i in range(0, keys.size(), step):
		var cells := _cells(keys[i])
		var baked: Image = Pudding._bank_image(keys[i])
		t.ok(baked != null and baked.get_data() == Pudding.image_for(cells).get_data(),
			"hình %s giống bản dựng lại; tăng Pudding.FIELD_VERSION rồi %s" % [keys[i], FIX])


func test_bank_covers_levels(t: T) -> void:
	var shapes: Dictionary = BakeTool.collect_shapes()
	t.ok(shapes.size() > 100, "đọc được hình khối từ data/levels và data/road_trip")
	var missing: Array = []
	for key: String in shapes:
		if not Pudding.has_baked(shapes[key]):
			missing.append(key)
	t.eq(missing.size(), 0, "mọi hình khối của level có trong bank (thiếu %s); %s" % [missing.slice(0, 3), FIX])


func test_local_shape(t: T) -> void:
	t.eq(Pudding.local_shape([[3, 4], [4, 4], [3, 5]]), [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)], "dời về góc khung bao")
	t.eq(Pudding.local_shape([Vector2i(5, 2), Vector2i(4, 3)]), [Vector2i(1, 0), Vector2i(0, 1)], "nhận cả Vector2i")
	var lv := {"blocks": [{"cells": [[6, 4], [7, 4]]}, {"cells": [[1, 1]]}]}
	t.eq(Pudding.level_shapes(lv), [[Vector2i(0, 0), Vector2i(1, 0)], [Vector2i(0, 0)]], "một hình mỗi khối")
	t.eq(Pudding.shape_key([Vector2i(1, 0), Vector2i(0, 0)]), Pudding.shape_key([Vector2i(0, 0), Vector2i(1, 0)]),
		"khoá không theo thứ tự ô")


func test_prewarm_builds_on_workers(t: T) -> void:
	var shape := _odd_shape(0)
	t.ok(not Pudding.has_baked(shape), "hình thử không có trong bank")
	var before := Pudding.pending_jobs()
	Pudding.prewarm([shape, shape.duplicate()])
	t.eq(Pudding.pending_jobs(), before + 1, "mỗi hình một job")
	Pudding.prewarm([shape])
	t.eq(Pudding.pending_jobs(), before + 1, "gọi lại không thêm job")
	var t0 := Time.get_ticks_msec()
	while not Pudding.is_warm() and Time.get_ticks_msec() - t0 < WAIT_MSEC:
		await _tree().process_frame
	t.ok(Pudding.is_warm(), "job xong trong %d ms" % WAIT_MSEC)
	var e := Pudding.sdf_for(shape)
	t.ok(e["tex"] is ImageTexture, "có texture")
	t.eq(e["dims"], Vector2(5, 5) + Vector2.ONE * 2.0 * Pudding.PAD, "cỡ texture theo khung bao cộng lề")
	t.ok(Pudding.sdf_for(shape)["tex"] == e["tex"], "lần sau lấy từ cache")
	Pudding.prewarm([shape])
	t.eq(Pudding.pending_jobs(), 0, "hình đã cache không dựng lại")


func test_sdf_for_waits_for_its_job(t: T) -> void:
	var shape := _odd_shape(1)
	Pudding.prewarm([shape])
	t.eq(Pudding.pending_jobs(), 1, "đang dựng")
	var e := Pudding.sdf_for(shape)
	t.eq(Pudding.pending_jobs(), 0, "sdf_for đợi job của hình đó rồi bỏ khỏi hàng")
	t.eq(e["dims"], Vector2(6, 5) + Vector2.ONE * 2.0 * Pudding.PAD, "cỡ đúng hình")


func test_baked_shape_is_not_built(t: T) -> void:
	var shapes: Dictionary = BakeTool.collect_shapes()
	var key: String = shapes.keys()[shapes.size() / 2]
	Pudding.prewarm([shapes[key]])
	t.eq(Pudding.pending_jobs(), 0, "hình có trong bank không cần job")
	var t0 := Time.get_ticks_usec()
	var e := Pudding.sdf_for(shapes[key])
	t.ok(e["tex"] is ImageTexture, "texture từ bank")
	print("    sdf_for từ bank: %d us" % (Time.get_ticks_usec() - t0))
