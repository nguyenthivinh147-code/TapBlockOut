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
		"chain": 40, "layer": 55, "fog": 70, "pulse": 90,
	}
	for f in table:
		var lv: int = table[f]
		t.ok(not Unlocks.is_open(f, lv - 1), "%s đóng ở L%d" % [f, lv - 1])
		t.ok(Unlocks.is_open(f, lv), "%s mở ở L%d" % [f, lv])
		t.ok(Unlocks.is_open(f, lv + 500), "%s mở ở level cao" % f)
	t.ok(not Unlocks.is_open("khong_co", 999), "tính năng lạ đóng")


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
