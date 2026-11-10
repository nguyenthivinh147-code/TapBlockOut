extends RefCounted
const T := preload("res://tests/t.gd")
const Config := preload("res://src/config.gd")
const SaveSchema := preload("res://src/meta/save_schema.gd")
const Cosmetics := preload("res://src/meta/cosmetics.gd")


func test_catalog(t: T) -> void:
	var c := Cosmetics.catalog()
	t.eq(c.size(), 26, "13 avatar + 13 frame")
	t.eq(c[0].id, "avatar_00", "đầu tiên")
	t.ok(not c[1].has("price"), "không có giá gold")
	t.eq(c[13].id, "frame_00", "frame sau avatar")
	t.eq(c[25].kind, "frame", "kind")


func test_default_owned(t: T) -> void:
	var s := SaveSchema.defaults()
	t.ok(Cosmetics.is_owned(s, "avatar_00"), "avatar_00")
	t.ok(Cosmetics.is_owned(s, "frame_00"), "frame_00")
	t.ok(not Cosmetics.is_owned(s, "avatar_01"), "chưa có avatar_01")
	t.eq(Cosmetics.equipped(s, "avatar"), "avatar_00", "đang dùng")


func test_unlock(t: T) -> void:
	var s := SaveSchema.defaults()
	var c0: int = s.coins
	t.ok(Cosmetics.unlock(s, "frame_05"), "mở bằng video")
	t.eq(s.coins, c0, "không trừ gold")
	t.ok(Cosmetics.is_owned(s, "frame_05"), "đã có")
	t.ok(not Cosmetics.unlock(s, "frame_05"), "đã có thì sai")
	t.ok(not Cosmetics.unlock(s, "frame_77"), "id lạ")
	t.eq((s.cos.owned as Array).count("frame_05"), 1, "không trùng")


func test_equip(t: T) -> void:
	var s := SaveSchema.defaults()
	t.ok(not Cosmetics.equip(s, "avatar_01"), "chưa có")
	t.eq(s.cos.avatar, "avatar_00", "giữ nguyên")
	Cosmetics.unlock(s, "avatar_01")
	Cosmetics.unlock(s, "frame_02")
	t.ok(Cosmetics.equip(s, "avatar_01"), "equip avatar")
	t.ok(Cosmetics.equip(s, "frame_02"), "equip frame")
	t.eq(s.cos.avatar, "avatar_01", "avatar")
	t.eq(s.cos.frame, "frame_02", "frame không đè avatar")
	t.ok(Cosmetics.equip(s, "avatar_00"), "quay về mặc định")
	t.eq(s.cos.avatar, "avatar_00", "avatar mặc định")
	t.ok(not Cosmetics.equip(s, "nope"), "id lạ")


## Avatar 05-07, frame 06-07 chỉ có từ hộp Road Trip (Config.ROAD_TRIP_COSMETICS): không bán, không mở bằng video.
func test_road_trip_only(t: T) -> void:
	var s := SaveSchema.defaults()
	t.eq([Cosmetics.road_trip_box("avatar_05"), Cosmetics.road_trip_box("frame_07")], [3, 16], "số hộp")
	t.eq(Cosmetics.road_trip_box("avatar_04"), 0, "món thường")
	t.ok(not Cosmetics.for_sale("avatar_06"), "không bán")
	t.ok(Cosmetics.for_sale("frame_05"), "món thường bán được")
	t.ok(not Cosmetics.for_sale("hat_01"), "id lạ")
	t.ok(Cosmetics.unlock(s, "frame_06"), "hộp Road Trip mở được")
	t.ok(Cosmetics.is_owned(s, "frame_06"), "đã có")
	t.ok(Cosmetics.equip(s, "frame_06"), "đeo được")


## Avatar, frame 08-12 chỉ có từ thưởng league (Config.LEADERBOARD.cosmetics): không bán, không video.
func test_league_only(t: T) -> void:
	Config.reset()
	var s := SaveSchema.defaults()
	for id in ["avatar_08", "avatar_12", "frame_08", "frame_12"]:
		t.ok(Cosmetics.league_only(id), "%s chỉ có từ league" % id)
		t.ok(not Cosmetics.for_sale(id), "%s không bán" % id)
	t.ok(not Cosmetics.league_only("avatar_07"), "món Road Trip không phải món league")
	t.ok(not Cosmetics.league_only("frame_05") and Cosmetics.for_sale("frame_05"), "món thường bán được")
	t.ok(Cosmetics.unlock(s, "avatar_09"), "thưởng league mở được")
	t.ok(Cosmetics.equip(s, "avatar_09"), "đeo được")


func test_remote_config_count(t: T) -> void:
	Config.reset()
	Config.COSMETICS.avatar_count = 3
	t.eq(Cosmetics.catalog().size(), 4 + 13, "theo Config")
	Config.reset()
