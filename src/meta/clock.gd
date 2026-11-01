extends RefCounted
## Quy đổi thời gian theo giờ máy. Chỉ `local_tz_offset` đọc hệ thống.

const DAY_SEC := 86400


## Số ngày kể từ 1970-01-01 theo giờ địa phương.
static func day_number(now: int, tz_offset_sec: int) -> int:
	return floori(float(now + tz_offset_sec) / float(DAY_SEC))


## Thứ trong tuần theo giờ địa phương, quy ước Godot: 0 = Chủ nhật ... 6 = Thứ bảy.
static func weekday(now: int, tz_offset_sec: int) -> int:
	return posmod(day_number(now, tz_offset_sec) + 4, 7)


## Độ lệch múi giờ của máy so với UTC, đơn vị giây.
static func local_tz_offset() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60
