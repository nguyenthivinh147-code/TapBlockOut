extends RefCounted
const T := preload("res://tests/t.gd")
const Config := preload("res://src/config.gd")
const SaveSchema := preload("res://src/meta/save_schema.gd")
const Unlocks := preload("res://src/meta/unlocks.gd")
const Wallet := preload("res://src/meta/wallet.gd")


func test_always_open(t: T) -> void:
	for f in ["rescue", "avatar", "frame"]:
		t.ok(Unlocks.is_open(f, 1), f + " mở từ L1")


func test_thresholds(t: T) -> void:
	var table := {
		"daily_gift": 4, "hint": 5, "shop": 5, "move": 12, "smash": 17, "lives": 10,
		"starter": 10, "review": 10, "challenge": 50, "stone": 14, "ice": 30,
		"chain": 40, "layer": 55, "fog": 70, "pulse": 90, "leaderboard": 8,
	}
	Config.reset()
	Config.FEATURES.challenge = true
	for f in table:
		var lv: int = table[f]
		t.ok(not Unlocks.is_open(f, lv - 1), "%s đóng ở L%d" % [f, lv - 1])
		t.ok(Unlocks.is_open(f, lv), "%s mở ở L%d" % [f, lv])
		t.ok(Unlocks.is_open(f, lv + 500), "%s mở ở level cao" % f)
	t.ok(not Unlocks.is_open("khong_co", 999), "tính năng lạ đóng")
	Config.reset()


## Config.FEATURES: a switched-off feature stays closed at every level and is left off the win-card progress bar.
func test_switched_off_feature(t: T) -> void:
	Config.reset()
	t.ok(not Unlocks.enabled("challenge"), "Daily Challenge tắt mặc định")
	t.ok(Unlocks.enabled("shop"), "không có trong FEATURES thì bật")
	t.ok(not Unlocks.is_open("challenge", 50), "tắt: L50 đóng")
	t.ok(not Unlocks.is_open("challenge", 999), "tắt: level cao vẫn đóng")
	t.eq(Unlocks.features_at(50), [] as Array[String], "tắt: L50 không báo mở")
	var p := Unlocks.feature_progress(49)
	t.eq(p.unlocked, [] as Array[String], "thắng L49 không báo mở")
	t.eq(p.start, 40, "mốc trước là L40 (Chain)")
	t.eq(p.end, 55, "bỏ mốc L50, mốc kế L55 (Layer)")
	Config.FEATURES.shop = false
	t.ok(not Unlocks.is_open("shop", 5), "tắt shop qua FEATURES")
	t.eq(Unlocks.features_at(5), ["hint"] as Array[String], "L5 chỉ còn hint")
	Config.reset()


func test_gifts(t: T) -> void:
	var s := SaveSchema.defaults()
	for lv in [1, 2, 3]:
		t.eq(Unlocks.pending_gift(s, lv), "", "L%d chưa có quà" % lv)
	t.eq(Unlocks.pending_gift(s, 4), "", "L4 chưa có quà")
	t.eq(Unlocks.pending_gift(s, 5), "hint", "L5 tặng hint")
	t.eq(Unlocks.pending_gift(s, 5), "hint", "chưa mark thì vẫn chờ")
	Unlocks.mark_gifted(s, "hint")
	t.eq(Unlocks.pending_gift(s, 5), "", "đã tặng hint")
	t.eq(Unlocks.pending_gift(s, 11), "", "L11 không có quà")
	t.eq(Unlocks.pending_gift(s, 12), "move", "L12 tặng move")
	Unlocks.mark_gifted(s, "move")
	t.eq(Unlocks.pending_gift(s, 16), "", "L16 không có quà")
	t.eq(Unlocks.pending_gift(s, 17), "smash", "L17 tặng smash")
	Unlocks.mark_gifted(s, "smash")
	t.eq(Unlocks.pending_gift(s, 17), "", "hết quà")
	t.eq(Unlocks.pending_gift(s, 100), "", "hết quà ở level cao")
	t.eq(s.gifted, {"hint": true, "move": true, "smash": true}, "cờ gifted")


func test_gift_skipped_levels(t: T) -> void:
	## Nhảy cóc tới L17 (ví dụ restore cloud): tặng lần lượt từng món.
	var s := SaveSchema.defaults()
	var got: Array[String] = []
	var guard := 0
	while guard < 10:
		guard += 1
		var k := Unlocks.pending_gift(s, 17)
		if k == "":
			break
		got.append(k)
		Unlocks.mark_gifted(s, k)
		Wallet.inv_add(s, k, 1)
	t.eq(got, ["hint", "move", "smash"] as Array[String], "tặng đủ 3 món")
	t.eq(Wallet.inv_count(s, "smash"), 1, "vào kho")
	Unlocks.mark_gifted(s, "bogus")
	t.ok(not s.gifted.has("bogus"), "loại lạ bị bỏ qua")


## Popup cơ chế mới: đúng level dạy, mỗi cơ chế một lần.
func test_mech_intro(t: T) -> void:
	var s := SaveSchema.defaults()
	t.eq(s.mech_seen, [], "bản lưu mới chưa xem cơ chế nào")
	var table := {14: "stone", 30: "ice", 40: "chain", 55: "layer", 70: "fog", 90: "pulse"}
	for lv in table:
		t.eq(Unlocks.pending_mech(s, lv), table[lv], "L%d giới thiệu %s" % [lv, table[lv]])
		t.eq(int(Config.UNLOCK[table[lv]]), lv, "khớp Config.UNLOCK.%s" % table[lv])
	for lv in [1, 13, 15, 29, 31, 89, 91, 200]:
		t.eq(Unlocks.pending_mech(s, lv), "", "L%d không phải level dạy" % lv)
	Unlocks.mark_mech_seen(s, "stone")
	t.eq(Unlocks.pending_mech(s, 14), "", "đã xem thì không hiện lại")
	Unlocks.mark_mech_seen(s, "stone")
	t.eq(s.mech_seen, ["stone"], "đánh dấu hai lần vẫn một mục")
	Unlocks.mark_mech_seen(s, "bogus")
	t.eq(s.mech_seen, ["stone"], "cơ chế lạ bị bỏ qua")
	t.eq(Unlocks.pending_mech({}, 30), "ice", "bản lưu thiếu khoá vẫn đọc được")
	var old := {}
	Unlocks.mark_mech_seen(old, "ice")
	t.eq(old.mech_seen, ["ice"], "bản lưu thiếu khoá thì tạo khi đánh dấu")


func test_feature_progress(t: T) -> void:
	var p := Unlocks.feature_progress(1)
	t.ok(p.has_next and p.start == 1 and p.end == 2, "L1: mốc 1 -> 2 (Road Trip)")
	t.near(p.before, 0.0, 0.001, "L1 trước")
	t.near(p.after, 1.0, 0.001, "L1 sau: chạm mốc")
	t.eq(p.features, ["road_trip"] as Array[String], "mốc 2 là Road Trip")
	t.eq(p.unlocked, ["road_trip"] as Array[String], "thắng L1 mở Road Trip")
	t.ok(not Unlocks.opens_home(["road_trip"]), "Road Trip không kéo về Home: hướng dẫn hiện khi về Home")
	p = Unlocks.feature_progress(2)
	t.ok(p.start == 2 and p.end == 4, "L2: mốc 2 -> 4")
	t.near(p.after, 0.5, 0.001, "L2 sau")
	t.eq(p.features, ["daily_gift"] as Array[String], "mốc 4 là quà ngày")
	p = Unlocks.feature_progress(3)
	t.near(p.after, 1.0, 0.001, "L3 chạm mốc")
	t.eq(p.unlocked, ["daily_gift"] as Array[String], "thắng L3 mở quà ngày")
	p = Unlocks.feature_progress(4)
	t.eq(p.start, 4, "mốc đã mở gần nhất")
	t.eq(p.end, 5, "mốc kế")
	t.eq(p.features, ["hint", "shop"] as Array[String], "L5 mở hai tính năng")
	p = Unlocks.feature_progress(9)
	t.eq(p.unlocked, ["lives"] as Array[String], "L10 chỉ báo mạng, bỏ starter/review")
	t.eq(Unlocks.feature_progress(90).has_next, false, "hết tính năng thì ẩn thanh")
	t.eq(Unlocks.feature_progress(20, 20).has_next, false, "demo dừng ở L20")
	t.eq(Unlocks.feature_progress(19, 20).unlocked, [] as Array[String], "ngoài trần demo không báo mở")
	t.ok(Unlocks.opens_home(["daily_gift"]), "quà ngày về Home")
	t.ok(not Unlocks.opens_home(["stone", "ice"]), "cơ chế mới vào thẳng level")
