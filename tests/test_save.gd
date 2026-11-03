extends RefCounted
const T := preload("res://tests/t.gd")
const SaveSchema := preload("res://src/meta/save_schema.gd")
const SaveStore := preload("res://src/meta/save_store.gd")
const Clock := preload("res://src/meta/clock.gd")

const DIR := "user://test_test_save"


func _fresh(name: String) -> String:
	if not DirAccess.dir_exists_absolute(DIR):
		DirAccess.make_dir_recursive_absolute(DIR)
	var p := DIR.path_join(name + ".json")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(p + suffix):
			DirAccess.remove_absolute(p + suffix)
	return p


func _write(p: String, text: String) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_defaults(t: T) -> void:
	var s := SaveSchema.defaults()
	t.eq(s.version, 1, "version")
	t.ok(s.coins > 0, "coins từ Config")
	t.eq(s.lives.count, 10, "lives")
	t.eq(s.cos.owned, ["avatar_00", "frame_00"], "cos.owned")
	t.eq(s.settings.sfx, true, "settings.sfx")
	t.ok(not s.settings.has("arrows"), "không còn settings.arrows")
	t.eq(s.offers.last_run, -999, "offers.last_run")
	var s2 := SaveSchema.defaults()
	s2.inv.hint = 5
	t.eq(SaveSchema.defaults().inv.hint, 0, "defaults không dùng chung tham chiếu")


func test_merge_defaults(t: T) -> void:
	var old := {"coins": 777, "inv": {"hint": 2}, "legacy_key": "giữ", "cos": {"owned": ["avatar_00", "avatar_03"]}}
	var m := SaveSchema.merge_defaults(old)
	t.eq(m.coins, 777, "giữ coins")
	t.eq(m.inv.hint, 2, "giữ hint")
	t.eq(m.inv.move, 0, "thêm move")
	t.eq(m.inv.smash, 0, "thêm smash")
	t.eq(m.legacy_key, "giữ", "không xoá khoá cũ")
	t.eq(m.cos.owned, ["avatar_00", "avatar_03"], "giữ owned")
	t.eq(m.cos.frame, "frame_00", "thêm frame")
	t.eq(m.version, 1, "migrate đặt version")
	t.ok(not old.has("lives"), "không sửa bản gốc")
	var bad := SaveSchema.merge_defaults({"coins": "abc", "lives": 5, "level": 12.0})
	t.eq(bad.coins, SaveSchema.defaults().coins, "sai kiểu thì mặc định")
	t.eq(bad.lives.count, 10, "nhóm sai kiểu thì mặc định")
	t.eq(bad.level, 12, "float nguyên thành int")


func test_roundtrip(t: T) -> void:
	var p := _fresh("roundtrip")
	var mirrored: Array[String] = []
	var store := SaveStore.new(p, func(j: String) -> void: mirrored.append(j))
	var s := SaveSchema.defaults()
	s.coins = 4321
	s.level = 7
	s.buys.append({"sku": "gold_s", "token": "tok1"})
	s.meta.install_at = 1700000000
	t.ok(store.save_now(s), "save_now ok")
	t.eq(mirrored.size(), 1, "mirror gọi 1 lần")
	t.eq(JSON.parse_string(mirrored[0]).coins, 4321.0, "mirror nhận json")
	t.ok(not FileAccess.file_exists(p + ".tmp"), "không còn file tạm")
	var l := SaveStore.new(p).load_state()
	t.eq(l.coins, 4321, "coins là int")
	t.eq(l.level, 7, "level")
	t.eq(l.meta.install_at, 1700000000, "install_at int")
	t.eq(l.buys[0].token, "tok1", "buys")


func test_queue_flush(t: T) -> void:
	var p := _fresh("queue")
	var calls := [0]
	var store := SaveStore.new(p, func(_j: String) -> void: calls[0] += 1)
	var s := SaveSchema.defaults()
	store.flush()
	t.eq(calls[0], 0, "flush khi chưa có gì: không ghi")
	s.coins = 1
	store.queue(s)
	s.coins = 2
	store.queue(s)
	t.ok(store.has_pending(), "pending")
	t.ok(not FileAccess.file_exists(p), "queue chưa ghi")
	store.flush()
	t.eq(calls[0], 1, "gộp thành 1 lần ghi")
	t.ok(not store.has_pending(), "hết pending")
	t.eq(SaveStore.new(p).load_state().coins, 2, "ghi bản mới nhất")
	store.flush()
	t.eq(calls[0], 1, "flush lần 2 không ghi")


func test_bak_kept(t: T) -> void:
	var p := _fresh("bak")
	var store := SaveStore.new(p)
	var s := SaveSchema.defaults()
	s.coins = 100
	store.save_now(s)
	t.ok(not FileAccess.file_exists(p + ".bak"), "lần đầu chưa có .bak")
	s.coins = 200
	store.save_now(s)
	t.ok(FileAccess.file_exists(p + ".bak"), "có .bak")
	t.eq(JSON.parse_string(FileAccess.get_file_as_string(p + ".bak")).coins, 100.0, ".bak là bản trước")
	t.eq(JSON.parse_string(FileAccess.get_file_as_string(p)).coins, 200.0, "file chính là bản mới")


func test_corrupt_main_uses_bak(t: T) -> void:
	var p := _fresh("corrupt")
	var store := SaveStore.new(p)
	var s := SaveSchema.defaults()
	s.coins = 100
	store.save_now(s)
	s.coins = 200
	store.save_now(s)
	_write(p, "{ không phải json")
	t.eq(SaveStore.new(p).load_state().coins, 100, "file hỏng thì dùng .bak")
	# lưu tiếp không được ghi đè .bak tốt bằng file hỏng
	s.coins = 300
	store.save_now(s)
	t.eq(JSON.parse_string(FileAccess.get_file_as_string(p + ".bak")).coins, 100.0, ".bak còn nguyên")


func test_missing_main_uses_bak(t: T) -> void:
	var p := _fresh("missing")
	var store := SaveStore.new(p)
	var s := SaveSchema.defaults()
	s.coins = 100
	store.save_now(s)
	s.coins = 200
	store.save_now(s)
	DirAccess.remove_absolute(p)
	t.eq(SaveStore.new(p).load_state().coins, 100, "mất file chính thì dùng .bak")


func test_backup_json_then_defaults(t: T) -> void:
	var p := _fresh("backupjson")
	var s := SaveSchema.defaults()
	s.coins = 555
	var json := JSON.stringify(s)
	t.eq(SaveStore.new(p).load_state(json).coins, 555, "dùng backup_json khi không có file")
	_write(p, "rác")
	_write(p + ".bak", "")
	t.eq(SaveStore.new(p).load_state(json).coins, 555, "file và .bak hỏng thì dùng backup_json")
	t.eq(SaveStore.new(p).load_state("hỏng nốt").coins, SaveSchema.defaults().coins, "hỏng hết thì mặc định")
	t.eq(SaveStore.new(_fresh("none")).load_state().level, 1, "không có gì thì mặc định")


func test_further(t: T) -> void:
	var a := {"runs": 10, "play_ms": 100, "tag": "a"}
	var b := {"runs": 12, "play_ms": 50, "tag": "b"}
	t.eq(SaveStore.further(a, b).tag, "b", "runs cao hơn")
	t.eq(SaveStore.further(b, a).tag, "b", "đối xứng")
	var c := {"runs": 10, "play_ms": 300, "tag": "c"}
	t.eq(SaveStore.further(a, c).tag, "c", "bằng runs thì play_ms")
	t.eq(SaveStore.further(a, {"runs": 10, "play_ms": 100, "tag": "d"}).tag, "a", "bằng hết thì a")


func test_merge_purchases(t: T) -> void:
	var into := SaveSchema.defaults()
	into.buys = [{"sku": "gold_s", "token": "t1"}, {"sku": "gold_m", "token": "t2"}]
	var from := SaveSchema.defaults()
	from.buys = [{"sku": "gold_m", "token": "t2"}, {"sku": "remove_ads", "token": "t3"},
		{"sku": "gold_l", "token": "t4"}, {"sku": "gold_l", "token": "t4"}]
	from.no_ads = true
	var granted_skus: Array = []
	var granted := SaveStore.merge_purchases(into, from, func(e: Dictionary) -> void: granted_skus.append(e.sku))
	t.eq(into.buys.size(), 4, "4 token khác nhau")
	t.eq(granted.size(), 2, "chỉ 2 đơn thiếu")
	t.eq(granted_skus, ["remove_ads", "gold_l"], "cấp lại đúng hàng thiếu, mỗi token một lần")
	t.eq(into.no_ads, true, "giữ no_ads của bên kia")
	var again := SaveStore.merge_purchases(into, from, func(_e: Dictionary) -> void: t.fail("không được cấp lại"))
	t.eq(again.size(), 0, "gộp lần hai không cấp thêm")
	t.eq(into.buys.size(), 4, "không trùng token")
	var keep := SaveSchema.defaults()
	keep.no_ads = true
	SaveStore.merge_purchases(keep, SaveSchema.defaults())
	t.eq(keep.no_ads, true, "no_ads bên into không bị mất")


func test_clock(t: T) -> void:
	t.eq(Clock.day_number(0, 0), 0, "epoch")
	t.eq(Clock.day_number(86399, 0), 0, "cuối ngày 0")
	t.eq(Clock.day_number(86400, 0), 1, "đầu ngày 1")
	t.eq(Clock.day_number(86400 - 3600, 3600), 1, "múi giờ +1h")
	t.eq(Clock.day_number(3600, -7200), -1, "múi giờ âm qua ngày trước")
	t.eq(Clock.weekday(0, 0), 4, "1970-01-01 là thứ Năm")
	t.eq(Clock.weekday(2 * 86400, 0), 6, "1970-01-03 là thứ Bảy")
	t.eq(Clock.weekday(3 * 86400, 0), 0, "1970-01-04 là Chủ nhật")
	t.eq(Clock.weekday(-86400, 0), 3, "ngày âm")
	t.eq(Clock.weekday(1767225600, 0), 4, "2026-01-01 là thứ Năm")
	var off := Clock.local_tz_offset()
	t.ok(off >= -14 * 3600 and off <= 14 * 3600, "offset hợp lý")
