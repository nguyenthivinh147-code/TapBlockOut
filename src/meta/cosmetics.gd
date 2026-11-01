extends RefCounted
## Avatar và frame. Chỉ đọc và ghi s.cos (và s.coins khi mua bằng gold, không qua Wallet).

const Config := preload("res://src/config.gd")

const KINDS := ["avatar", "frame"]


## [{id, kind, price}] gồm cả *_00 mặc định (price 0), avatar trước frame.
static func catalog() -> Array:
	var out: Array = []
	for kind in KINDS:
		for id in Config.cosmetic_ids(kind):
			out.append({"id": id, "kind": kind, "price": Config.cosmetic_price(id)})
	return out


## "avatar" | "frame" | "" nếu id không có trong catalog.
static func kind_of(id: String) -> String:
	for kind in KINDS:
		if Config.cosmetic_ids(kind).has(id):
			return kind
	return ""


static func is_owned(s: Dictionary, id: String) -> bool:
	return (s.cos.owned as Array).has(id)


static func equipped(s: Dictionary, kind: String) -> String:
	return str(s.cos.get(kind, ""))


## Mua bằng gold: trừ thẳng s.coins. Sai khi id lạ, đã có, hoặc thiếu gold.
static func buy(s: Dictionary, id: String) -> bool:
	if kind_of(id) == "" or is_owned(s, id):
		return false
	var price := Config.cosmetic_price(id)
	if int(s.coins) < price:
		return false
	s.coins = int(s.coins) - price
	(s.cos.owned as Array).append(id)
	return true


## Mở bằng video (Game đã xem xong): không trừ gold. Sai khi id lạ hoặc đã có.
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
