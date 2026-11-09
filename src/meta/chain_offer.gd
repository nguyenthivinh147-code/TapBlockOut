extends RefCounted
## Chain Offer: chuỗi quà nhiều bước (free / xem quảng cáo / mua). Logic thuần: giờ truyền vào.
## Ghi vào s.chain {active, id, step, expires, cooldown_until, shown, rotation}.
##
## Bật khi chưa có chuỗi nào đang chạy, level >= level_unlock và đã hết cooldown. Chuỗi được chọn
## xoay vòng. Sống `days_to_existence` ngày; hết hạn thì nghỉ `days_to_reset` ngày (tính từ lúc hết
## hạn, không phụ thuộc lúc người chơi mở game). Làm hết mọi bước không tắt chuỗi.

const Config := preload("res://src/config.gd")

const DAY_SEC := 86400


static func _c(s: Dictionary) -> Dictionary:
	if not (s.get("chain") is Dictionary):
		s["chain"] = {}
	var c: Dictionary = s.chain
	c["active"] = bool(c.get("active", false))
	c["id"] = str(c.get("id", ""))
	for k in ["step", "expires", "cooldown_until", "rotation"]:
		c[k] = int(c.get(k, 0))
	c["shown"] = bool(c.get("shown", false))
	return c


static func sequences() -> Array:
	return Config.CHAIN.get("sequences", [])


static func sequence(id: String) -> Dictionary:
	for q in sequences():
		if str(q.get("id", "")) == id:
			return q
	return {}


## Sau mỗi ván: -1 xét cả thắng lẫn thua; giá trị khác chỉ xét khi thua ở level không HARD.
static func should_trigger(lost: bool, hard: bool) -> bool:
	if int(Config.CHAIN.get("require_lose", -1)) == -1:
		return true
	return lost and not hard


## Hết hạn thì tắt chuỗi và đặt cooldown. Trả true nếu vừa tắt.
static func update(s: Dictionary, now: int) -> bool:
	var c := _c(s)
	if not bool(c.active) or now < int(c.expires):
		return false
	c["active"] = false
	c["id"] = ""
	c["step"] = 0
	c["shown"] = false
	c["cooldown_until"] = int(c.expires) + int(Config.CHAIN.get("days_to_reset", 3)) * DAY_SEC
	return true


## Bật chuỗi mới nếu đủ điều kiện. Trả true nếu đã bật.
static func try_activate(s: Dictionary, now: int, level: int) -> bool:
	update(s, now)
	var c := _c(s)
	var seqs := sequences()
	if bool(c.active) or seqs.is_empty():
		return false
	if level < int(Config.CHAIN.get("level_unlock", 100)) or now < int(c.cooldown_until):
		return false
	var q: Dictionary = seqs[int(c.rotation) % seqs.size()]
	c["active"] = true
	c["id"] = str(q.get("id", ""))
	c["step"] = 0
	c["expires"] = now + int(Config.CHAIN.get("days_to_existence", 1)) * DAY_SEC
	c["shown"] = false
	c["rotation"] = int(c.rotation) + 1
	return true


## Chuỗi đang chạy: {id, steps, step, count, expires, seconds_left}. {} nếu không có.
static func current(s: Dictionary, now: int) -> Dictionary:
	update(s, now)
	var c := _c(s)
	if not bool(c.active):
		return {}
	var q := sequence(str(c.id))
	if q.is_empty():
		return {}
	var steps: Array = q.get("steps", [])
	return {
		"id": str(c.id), "steps": steps, "step": int(c.step), "count": steps.size(),
		"expires": int(c.expires), "seconds_left": maxi(0, int(c.expires) - now),
	}


## Bước đang chờ nhận ({} nếu đã hết bước).
static func current_step(s: Dictionary, now: int) -> Dictionary:
	var cur := current(s, now)
	if cur.is_empty() or int(cur.step) >= int(cur.count):
		return {}
	return cur.steps[int(cur.step)]


## Sang bước kế tiếp. Trả {type, reward}; reward rỗng với bước Pay (hàng đã cộng qua IAP). {} nếu hết bước.
static func advance(s: Dictionary, now: int) -> Dictionary:
	var st := current_step(s, now)
	if st.is_empty():
		return {}
	var c := _c(s)
	c["step"] = int(c.step) + 1
	var type := str(st.get("type", "free"))
	var reward := {"coins": 0, "items": {}}
	if type != "pay":
		reward = {"coins": int(st.get("coins", 0)), "items": (st.get("items", {}) as Dictionary).duplicate()}
	return {"type": type, "reward": reward}


## Popup tự mở một lần mỗi chuỗi.
static func should_autoshow(s: Dictionary, now: int) -> bool:
	return not current(s, now).is_empty() and not bool(_c(s).shown)


static func mark_shown(s: Dictionary) -> void:
	_c(s)["shown"] = true
