extends RefCounted
## Lịch thông báo local theo GAME-GUIDE mục 15. Logic thuần: giờ truyền vào qua `now` (unix giây)
## và `tz` (độ lệch múi giờ, giây). Chỉ đọc/ghi nhóm `s.notify`, đọc `s.meta.install_at`.
##
## Quy ước ngày: chỉ số ngày 0 = ngày cài (theo giờ địa phương). Config.NOTIF dùng thẳng chỉ số này:
## `idx < first_week_days` là tuần đầu, `idx <= daily_until_day` là mỗi ngày một lần, `sparse_days` là ngày thưa.
## `s.notify.hours` là danh sách phút trong ngày (0..1439) của các lần mở game, giữ tối đa HISTORY_MAX.

const Config := preload("res://src/config.gd")
const Clock := preload("res://src/meta/clock.gd")

const HISTORY_MAX := 14
## Cần ít nhất chừng này lần mở thì mới tin giờ đã học; dưới đó dùng DEFAULT_MINUTES.
const LEARN_MIN := 3
## Các lần mở cách nhau không quá chừng này phút thì gộp thành một cụm giờ.
const CLUSTER_SPAN_MIN := 90
## Hai thông báo cùng ngày cách nhau tối thiểu chừng này phút.
const MIN_GAP_MIN := 120
## Quay lại trong chừng này phút sau một thông báo cũng tính là phản hồi.
const RESPOND_MIN := 240
## Giờ đặt sẵn (đã trừ lead) khi chưa có lịch sử mở game.
const DEFAULT_MINUTES: Array[int] = [750, 1110, 1230]


## Tính lịch từ `now` tới hết ngày 30 kể từ ngày cài, ghi vào `s.notify.plan` và trả về.
## `candidates`: phần tử là String (kind) hoặc {kind, at?, until?}: `at` = sớm nhất được báo, `until` = hạn.
## Chỉ đưa vào thứ đang chờ thật; rỗng thì không có thông báo nào.
static func plan(s: Dictionary, now: int, tz: int, candidates: Array) -> Array:
	var out: Array = []
	var cands := _normalize(candidates)
	var notify: Dictionary = s["notify"]
	if not cands.is_empty():
		var cfg: Dictionary = Config.NOTIF
		var today := Clock.day_number(now, tz)
		var install_day := _install_day(s, tz, today)
		var last_idx := _last_idx(cfg)
		var quiet: bool = int(notify.get("ignored", 0)) >= int(cfg.quiet_after_ignored)
		var slots := _slots(notify.get("hours", []), cfg)
		for day in range(today, install_day + last_idx + 1):
			var idx := day - install_day
			var cap := _cap_for(idx, cfg, quiet)
			if cap <= 0 or slots.is_empty():
				continue
			var picked: Array = []
			for i in mini(cap, slots.size()):
				picked.append(slots[i])
			picked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.m < b.m)
			var used: Array[String] = []
			var rot := idx % cands.size()
			for slot in picked:
				var at: int = day * Clock.DAY_SEC - tz + int(slot.m) * 60
				if at <= now:
					continue
				for k in cands.size():
					var c: Dictionary = cands[(k + rot) % cands.size()]
					if used.has(c.kind) or not _eligible(c, at):
						continue
					used.append(c.kind)
					out.append({"at": at, "kind": c.kind})
					break
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.at < b.at)
	notify["plan"] = out.duplicate(true)
	return out


## Ghi giờ mở game (phút trong ngày theo giờ địa phương), giữ HISTORY_MAX lần gần nhất.
static func note_open(s: Dictionary, now: int, tz: int) -> void:
	var notify: Dictionary = s["notify"]
	var hours: Array = notify.get("hours", [])
	hours.append(posmod(floori(float(now + tz) / 60.0), 1440))
	while hours.size() > HISTORY_MAX:
		hours.pop_front()
	notify["hours"] = hours


## Gọi khi mở lại game. Mở từ thông báo (`opened_kind` khác rỗng) hoặc quay lại trong RESPOND_MIN
## phút sau một thông báo đã tới giờ: `ignored` về 0. Ngược lại mỗi thông báo đã tới giờ mà không
## ai nhận cộng 1 (trừ khi `enabled` = false: máy đã tắt thông báo thì không tính bỏ qua).
## Xong thì xoá `plan` cũ (Game lập lại ngay sau đó).
static func note_return(s: Dictionary, now: int, opened_kind: String, enabled: bool = true) -> void:
	var notify: Dictionary = s["notify"]
	var sent: Array = []
	for e in notify.get("plan", []):
		if e is Dictionary and int(e.get("at", 0)) <= now:
			sent.append(e)
	var responded := opened_kind != ""
	if not responded:
		for e in sent:
			if now - int(e.at) <= RESPOND_MIN * 60:
				responded = true
				break
	if responded:
		notify["ignored"] = 0
	elif enabled:
		notify["ignored"] = int(notify.get("ignored", 0)) + sent.size()
	notify["plan"] = []


static func _normalize(candidates: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Array[String] = []
	for raw in candidates:
		var c := {"kind": "", "at": 0, "until": 0}
		if raw is String or raw is StringName:
			c.kind = str(raw)
		elif raw is Dictionary:
			c.kind = str(raw.get("kind", ""))
			c.at = int(raw.get("at", 0))
			c.until = int(raw.get("until", 0))
		if c.kind == "" or seen.has(c.kind):
			continue
		seen.append(c.kind)
		out.append(c)
	return out


static func _eligible(c: Dictionary, at: int) -> bool:
	if int(c.at) > 0 and at < int(c.at):
		return false
	if int(c.until) > 0 and at >= int(c.until):
		return false
	return true


static func _install_day(s: Dictionary, tz: int, today: int) -> int:
	var meta: Dictionary = s.get("meta", {})
	var at := int(meta.get("install_at", 0))
	if at <= 0:
		return today
	return mini(Clock.day_number(at, tz), today)


static func _last_idx(cfg: Dictionary) -> int:
	var last := int(cfg.daily_until_day)
	for d in cfg.sparse_days:
		last = maxi(last, int(d))
	return last


## Số thông báo tối đa của ngày `idx` (0 = không báo).
static func _cap_for(idx: int, cfg: Dictionary, quiet: bool) -> int:
	if idx < 0:
		return 0
	var cap := 0
	if idx < int(cfg.first_week_days):
		cap = int(cfg.first_week_per_day)
	elif idx <= int(cfg.daily_until_day):
		cap = 1
	elif cfg.sparse_days.has(idx):
		cap = 1
	if quiet:
		cap = mini(cap, 1)
	return cap


## Các giờ báo trong ngày (phút), xếp theo độ hay mở giảm dần; phần tử đầu là giờ chính.
## Mỗi phần tử {m, n}. Đã trừ lead_min, kẹp vào [earliest_hour, latest_hour], cách nhau >= MIN_GAP_MIN.
static func _slots(hours_raw: Variant, cfg: Dictionary) -> Array[Dictionary]:
	var lo := int(cfg.earliest_hour) * 60
	var hi := int(cfg.latest_hour) * 60
	var lead := int(cfg.lead_min)
	var cands: Array[Dictionary] = []
	var hours: Array[int] = []
	if hours_raw is Array:
		for h in hours_raw:
			hours.append(posmod(int(h), 1440))
	if hours.size() < LEARN_MIN:
		for i in DEFAULT_MINUTES.size():
			cands.append({"m": clampi(DEFAULT_MINUTES[i], lo, hi), "n": DEFAULT_MINUTES.size() - i})
	else:
		hours.sort()
		var start := 0
		while start < hours.size():
			var end := start
			while end + 1 < hours.size() and hours[end + 1] - hours[start] <= CLUSTER_SPAN_MIN:
				end += 1
			@warning_ignore("integer_division")
			var mid := hours[(start + end) / 2]
			cands.append({"m": clampi(mid - lead, lo, hi), "n": end - start + 1})
			start = end + 1
	cands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.n > b.n or (a.n == b.n and a.m < b.m))
	var out: Array[Dictionary] = []
	for c in cands:
		var far := true
		for p in out:
			if absi(int(p.m) - int(c.m)) < MIN_GAP_MIN:
				far = false
				break
		if far:
			out.append(c)
	return out
