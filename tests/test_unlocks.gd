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
		"daily_gift": 14, "hint": 5, "shop": 11, "move": 12, "smash": 17, "lives": 10,
		"starter": 10, "review": 10, "challenge": 50, "stone": 14, "ice": 30,
		"chain": 45, "layer": 65, "fog": 85, "pulse": 115, "frost": 165, "leaderboard": 70,
		"road_trip": 95, "win_streak": 45, "special_bomb": 50, "choco": 300, "ribbon": 350,
	}
	Config.reset()
	Config.FEATURES.challenge = true
	Config.FEATURES.win_streak = true
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
	t.eq(Unlocks.features_at(50), ["special_bomb"] as Array[String], "tắt: L50 chỉ báo Màn đặc biệt")
	var p := Unlocks.feature_progress(49)
	t.eq(p.unlocked, ["special_bomb"] as Array[String], "thắng L49 không báo Daily Challenge")
	Config.FEATURES.special_bomb = false
	p = Unlocks.feature_progress(49)
	t.eq(p.unlocked, [] as Array[String], "tắt cả Màn đặc biệt: thắng L49 không báo mở")
	t.eq(p.start, 45, "mốc trước là L45 (Xích)")
	t.eq(p.end, 60, "bỏ mốc L50, mốc kế L60 (Level Pack)")
	Config.FEATURES.shop = false
	t.ok(not Unlocks.is_open("shop", 11), "tắt shop qua FEATURES")
	t.eq(Unlocks.features_at(11), [] as Array[String], "L11 không còn gì để báo")
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
	var table := {14: "stone", 30: "ice", 45: "chain", 65: "layer", 85: "fog", 115: "pulse", 165: "frost",
		300: "choco", 350: "ribbon"}
	for lv in table:
		t.eq(Unlocks.pending_mech(s, lv), table[lv], "L%d giới thiệu %s" % [lv, table[lv]])
		t.eq(int(Config.UNLOCK[table[lv]]), lv, "khớp Config.UNLOCK.%s" % table[lv])
	# Mốc cũ trước 2026-11-10 (40, 55, 70, 90, 110, 130, 150) không còn là level dạy.
	for lv in [1, 13, 15, 29, 31, 40, 55, 70, 90, 110, 130, 150, 200]:
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
	Config.reset()
	var p := Unlocks.feature_progress(1)
	t.ok(p.has_next and p.start == 1 and p.end == 5, "L1: mốc 1 -> 5 (Gợi ý)")
	t.near(p.before, 0.0, 0.001, "L1 trước")
	t.near(p.after, 1.0 / 4.0, 0.001, "L1 sau")
	t.eq(p.features, ["hint"] as Array[String], "L5 chỉ mở Gợi ý (shop từ L11)")
	t.eq(p.unlocked, [] as Array[String], "thắng L1 không mở gì")
	p = Unlocks.feature_progress(3)
	t.ok(p.start == 1 and p.end == 5, "L3: mốc 1 -> 5")
	t.near(p.after, 3.0 / 4.0, 0.001, "L3 sau")
	t.eq(p.unlocked, [] as Array[String], "thắng L3 không mở gì")
	p = Unlocks.feature_progress(4)
	t.near(p.after, 1.0, 0.001, "L4 chạm mốc")
	t.eq(p.unlocked, ["hint"] as Array[String], "thắng L4 mở Gợi ý")
	p = Unlocks.feature_progress(9)
	t.eq(p.unlocked, ["lives"] as Array[String], "L10 chỉ báo mạng, bỏ starter/review")
	p = Unlocks.feature_progress(10)
	t.eq(p.unlocked, ["shop"] as Array[String], "thắng L10 mở shop và video gold")
	p = Unlocks.feature_progress(12)
	t.eq(p.start, 12, "mốc đã mở gần nhất")
	t.eq(p.end, 14, "mốc kế")
	t.eq(p.features, ["daily_gift", "stone"] as Array[String], "mốc 14 là quà ngày và Thùng sắt")
	p = Unlocks.feature_progress(13)
	t.eq(p.unlocked, ["daily_gift", "stone"] as Array[String], "thắng L13 mở quà ngày")
	t.ok(Unlocks.opens_home(p.unlocked), "thắng L13 về Home vì quà ngày")
	var last := 0
	var marks := Unlocks.levels()
	for k in marks:
		last = maxi(last, int(marks[k]))
	t.eq(Unlocks.feature_progress(last).has_next, false, "hết tính năng thì ẩn thanh")
	p = Unlocks.feature_progress(115)
	t.eq(p.end, 130, "sau Cổng nhịp là mốc Chain Offer")
	t.eq(p.features, ["chain_offer"] as Array[String], "mốc 130 là Chain Offer")
	p = Unlocks.feature_progress(299)
	t.eq(p.unlocked, ["choco"] as Array[String], "thắng L299 mở Socola")
	t.eq(Unlocks.feature_progress(300).end, 350, "sau Socola là mốc cuối Ruy băng L350")
	t.eq(Unlocks.feature_progress(20, 20).has_next, false, "demo dừng ở L20")
	t.eq(Unlocks.feature_progress(19, 20).unlocked, [] as Array[String], "ngoài trần demo không báo mở")
	t.ok(Unlocks.opens_home(["daily_gift"]), "quà ngày về Home")
	t.ok(not Unlocks.opens_home(["stone", "ice"]), "cơ chế mới vào thẳng level")


## Weekly Pass, Level Pack, Chain Offer keep their marks in their own config; the progress bar shows them too
## (design.md mục 4 "Mở khoá theo level"), without sending the player Home.
func test_offer_marks(t: T) -> void:
	Config.reset()
	var marks := Unlocks.levels()
	t.eq(int(marks.weekly_pass), 27, "Weekly Pass: sau L26, level HARD thứ 2")
	t.eq(int(marks.level_pack), 60, "Level Pack: OFFERS.level_pack.first_level")
	t.eq(int(marks.chain_offer), 130, "Chain Offer: CHAIN.level_unlock")
	t.eq(int(marks.road_trip), 95, "Road Trip L95")
	t.eq(int(marks.special_bomb), 50, "Màn đặc biệt L50")
	t.eq(Unlocks.feature_progress(26).unlocked, ["weekly_pass"] as Array[String], "thắng L26 mở Weekly Pass")
	var p := Unlocks.feature_progress(44)
	t.eq(p.unlocked, ["chain"] as Array[String], "Win Streak tắt: thắng L44 chỉ mở Xích")
	t.ok(not Unlocks.opens_home(p.unlocked), "thắng L44 không về Home")
	Config.FEATURES.win_streak = true
	p = Unlocks.feature_progress(44)
	t.eq(p.unlocked, ["chain", "win_streak"] as Array[String], "bật lại: thắng L44 mở Xích, Win Streak")
	t.ok(Unlocks.opens_home(p.unlocked), "thắng L44 về Home vì Win Streak")
	Config.reset()
	t.eq(Unlocks.feature_progress(59).unlocked, ["level_pack"] as Array[String], "thắng L59 mở Level Pack")
	p = Unlocks.feature_progress(69)
	t.eq(p.unlocked, ["leaderboard"] as Array[String], "thắng L69 mở Leaderboard")
	t.ok(Unlocks.opens_home(p.unlocked), "thắng L69 về Home vì Leaderboard")
	t.eq(Unlocks.feature_progress(84).unlocked, ["fog"] as Array[String], "thắng L84 mở Sương mù")
	t.eq(Unlocks.feature_progress(94).unlocked, ["road_trip"] as Array[String], "thắng L94 mở Road Trip")
	t.eq(Unlocks.feature_progress(129).unlocked, ["chain_offer"] as Array[String], "thắng L129 mở Chain Offer")
	t.ok(not Unlocks.opens_home(["weekly_pass", "level_pack", "chain_offer", "road_trip"]), "không kéo về Home")
	Config.CHAIN.level_unlock = 120
	Config.OFFERS.level_pack.first_level = 40
	t.eq(int(Unlocks.levels().chain_offer), 120, "theo Remote Config chain_level_unlock")
	t.eq(int(Unlocks.levels().level_pack), 40, "theo Remote Config offers_level_pack_first_level")
	Config.WEEKLY.enabled = false
	t.ok("weekly_pass" not in Unlocks.features_at(27), "Weekly Pass tắt thì không báo")
	Config.reset()
	t.eq(Unlocks.feature_progress(19, 20).unlocked, [] as Array[String], "demo: không báo mốc ngoài L20")
