extends RefCounted
## Avatar và frame. Chỉ đọc và ghi s.cos. Không bán bằng gold: món bán chỉ mở bằng video (Game.cos_unlock_video).

const Config := preload("res://src/config.gd")

const KINDS := ["avatar", "frame"]


## [{id, kind}] gồm cả *_00 mặc định, avatar trước frame.
static func catalog() -> Array:
	var out: Array = []
	for kind in KINDS:
		for id in Config.cosmetic_ids(kind):
			out.append({"id": id, "kind": kind})
	return out


## "avatar" | "frame" | "" nếu id không có trong catalog.
static func kind_of(id: String) -> String:
	for kind in KINDS:
		if Config.cosmetic_ids(kind).has(id):
			return kind
	return ""


static func is_owned(s: Dictionary, id: String) -> bool:
	return (s.cos.owned as Array).has(id)


## Số thứ tự hộp Road Trip (đếm từ 1) tặng món `id`; 0 khi món không thuộc Road Trip (Config.ROAD_TRIP_COSMETICS).
static func road_trip_box(id: String) -> int:
	for box in Config.ROAD_TRIP_COSMETICS:
		if str(Config.ROAD_TRIP_COSMETICS[box]) == id:
			return int(box)
	return 0


## Món chỉ có từ thưởng league của Leaderboard (Config.LEADERBOARD.cosmetics).
static func league_only(id: String) -> bool:
	var raw: Variant = Config.LEADERBOARD.get("cosmetics", [])
	return raw is Array and (raw as Array).has(id)


## Mở bằng video được: món có trong catalog, không chỉ có từ Road Trip hay thưởng league.
static func for_sale(id: String) -> bool:
	return kind_of(id) != "" and road_trip_box(id) == 0 and not league_only(id)


static func equipped(s: Dictionary, kind: String) -> String:
	return str(s.cos.get(kind, ""))


## Mở không trả gold (video Game đã xem xong, hoặc hộp Road Trip): sai khi id lạ hoặc đã có. Món chỉ có từ Road
## Trip thì Game không mở bằng video (for_sale).
static func unlock(s: Dictionary, id: String) -> bool:
	if kind_of(id) == "" or is_owned(s, id):
		return false
	(s.cos.owned as Array).append(id)
	return true


## Đang dùng: chỉ món đã có.
static func equip(s: Dictionary, id: String) -> bool:
	var kind := kind_of(id)
	if kind == "" or not is_owned(s, id):
		return false
	s.cos[kind] = id
	return true
