extends RefCounted
## Cấu trúc bản lưu. Mỗi module meta chỉ đọc và ghi nhóm khoá của mình.

const Config := preload("res://src/config.gd")

const VERSION := 1


static func defaults() -> Dictionary:
	return {
		"version": VERSION,
		"coins": int(Config.ECON.start_coins),
		"inv": {"hint": 0, "move": 0, "smash": 0},
		"gifted": {"hint": false, "move": false, "smash": false},
		"level": 1, "runs": 0, "play_ms": 0, "fail_streak": {"level": 0, "count": 0},
		"lives": {"count": 10, "next_at": 0, "bonus": 0, "inf_until": 0},
		"daily": {"idx": 0, "claim_day": -1, "ad_day": -1},
		"shop": {"day": -1, "videos": 0},
		"cos": {"owned": ["avatar_00", "frame_00"], "avatar": "avatar_00", "frame": "frame_00"},
		"profile": {"name": ""},
		"ads": {"last_inter_run": -99, "last_inter_at": 0, "last_rv_at": 0, "inter_today": 0, "inter_day": -1},
		"ad_pend": {}, "ad_credit": {},
		"offers": {"last_run": -999, "items": {}},
		"buys": [], "no_ads": false,
		"weekly": {
			"cycle": "", "points": 0, "vip": false, "opened": false, "end_seen": false, "tut_seen": false,
			"claimed_free": [], "claimed_vip": [], "claimed_bank": [], "pending_end": {},
		},
		"chain": {
			"active": false, "id": "", "step": 0, "expires": 0, "cooldown_until": 0,
			"shown": false, "rotation": 0,
		},
		"challenge": {"day": -1, "won": false},
		"road_trip": {"level": 1, "boxes": 0, "guide": false},
		"lb": {
			"joined": false, "points": 0, "league": 0, "seed": 0, "day": -1, "seen_rank": 0,
			"bots": [], "risen": [], "pending": [],
		},
		"notify": {"ignored": 0, "plan": [], "asked": false, "hours": []},
		"settings": {"sfx": true, "music": true, "haptics": true, "notif": true, "lang": ""},
		"meta": {"install_at": 0, "sessions": 0, "first_session_done": false, "rated": false, "ftue": []},
	}


## Đưa bản lưu cũ lên phiên bản hiện tại. Sửa tại chỗ và trả lại chính `s`.
static func migrate(s: Dictionary) -> Dictionary:
	var v := int(s.get("version", 0))
	if v < 1:
		v = 1 # bản lưu không có phiên bản: coi là v1
	# Khi tăng VERSION, thêm bước `if v < N: ...; v = N` ở đây.
	s["version"] = v
	return s


## Trả bản mới: migrate, thêm khoá thiếu theo `defaults()`, không xoá khoá cũ.
## Khoá sai kiểu thì lấy lại mặc định. Số nguyên đọc từ JSON (float) được ép về int.
static func merge_defaults(s: Dictionary) -> Dictionary:
	var out: Dictionary = _normalize(s.duplicate(true))
	migrate(out)
	_fill(out, defaults())
	return out


static func _fill(dst: Dictionary, def: Dictionary) -> void:
	for k in def:
		var dv: Variant = def[k]
		if not dst.has(k):
			dst[k] = _copy(dv)
			continue
		var cur: Variant = dst[k]
		if dv is Dictionary:
			if cur is Dictionary:
				_fill(cur, dv)
			else:
				dst[k] = _copy(dv)
		elif dv is Array:
			if not (cur is Array):
				dst[k] = _copy(dv)
		elif typeof(dv) == TYPE_INT:
			if typeof(cur) != TYPE_INT:
				dst[k] = _copy(dv)
		elif typeof(dv) != typeof(cur):
			dst[k] = _copy(dv)


static func _copy(v: Variant) -> Variant:
	if v is Dictionary or v is Array:
		return v.duplicate(true)
	return v


## JSON không phân biệt int và float: số nguyên đọc về là float. Ép lại thành int.
static func _normalize(v: Variant) -> Variant:
	if v is Dictionary:
		for k in v:
			v[k] = _normalize(v[k])
		return v
	if v is Array:
		for i in v.size():
			v[i] = _normalize(v[i])
		return v
	if typeof(v) == TYPE_FLOAT and is_finite(v) and v == floorf(v) and absf(v) < 9.0e15:
		return int(v)
	return v
