extends RefCounted
## Mạng: `s.lives = {count, next_at}`. `next_at` là thời điểm (unix giây) mạng kế tiếp hồi;
## 0 khi đã đầy. Mọi hàm đọc đều gọi `tick` trước nên có thể ghi vào `s`.

const Config := preload("res://src/config.gd")
const Wallet := preload("res://src/meta/wallet.gd")


## Mạng tối đa: cấu hình + thưởng tạm của Weekly Pass VIP (s.lives.bonus).
static func max_for(s: Dictionary) -> int:
	return int(Config.LIVES.max) + maxi(0, int((s.get("lives", {}) as Dictionary).get("bonus", 0)))


static func _regen() -> int:
	return int(Config.LIVES.regen_sec)


## Cộng các mạng đã hồi tới `now`. Đầy thì không tích giờ. Giờ máy lùi thì kẹp lại.
static func tick(s: Dictionary, now: int) -> void:
	var l: Dictionary = s.lives
	var mx := max_for(s)
	var rg := maxi(_regen(), 1)
	if int(l.count) >= mx:
		l.count = mx
		l.next_at = 0
		return
	var nxt := int(l.next_at)
	if nxt <= 0 or nxt > now + rg:
		l.next_at = now + rg
		return
	if now >= nxt:
		@warning_ignore("integer_division")
		var gained := 1 + (now - nxt) / rg
		l.count = mini(mx, int(l.count) + gained)
		l.next_at = 0 if int(l.count) >= mx else nxt + gained * rg


static func count(s: Dictionary, now: int) -> int:
	tick(s, now)
	return int(s.lives.count)


## Mất 1 mạng. Không làm gì khi `level < from_level` hoặc đã hết mạng. Trả true nếu đã trừ.
static func lose(s: Dictionary, now: int, level: int) -> bool:
	if level < int(Config.LIVES.from_level):
		return false
	tick(s, now)
	var l: Dictionary = s.lives
	if int(l.count) <= 0:
		return false
	var was_full := int(l.count) >= max_for(s)
	l.count = int(l.count) - 1
	if was_full:
		l.next_at = now + _regen()
	return true


static func add(s: Dictionary, n: int, now: int) -> void:
	if n <= 0:
		return
	tick(s, now)
	var l: Dictionary = s.lives
	l.count = mini(max_for(s), int(l.count) + n)
	if int(l.count) >= max_for(s):
		l.next_at = 0
	elif int(l.next_at) <= 0:
		l.next_at = now + _regen()


## Số giây tới mạng kế tiếp; 0 khi đã đầy.
static func seconds_to_next(s: Dictionary, now: int) -> int:
	tick(s, now)
	if int(s.lives.count) >= max_for(s):
		return 0
	return maxi(0, int(s.lives.next_at) - now)


## Đổi gold lấy `refill_lives` mạng. Đã đầy hoặc thiếu gold thì không trừ, trả false.
static func refill_coins(s: Dictionary, now: int) -> bool:
	tick(s, now)
	if int(s.lives.count) >= max_for(s):
		return false
	if not Wallet.spend(s, int(Config.ECON.refill_coins)):
		return false
	add(s, int(Config.ECON.refill_lives), now)
	return true
