extends RefCounted
const T := preload("res://tests/t.gd")
const SaveSchema := preload("res://src/meta/save_schema.gd")
const Wallet := preload("res://src/meta/wallet.gd")


func test_earn_spend(t: T) -> void:
	var s := SaveSchema.defaults()
	var start: int = s.coins
	Wallet.earn(s, 40)
	t.eq(s.coins, start + 40, "earn")
	Wallet.earn(s, -5)
	Wallet.earn(s, 0)
	t.eq(s.coins, start + 40, "earn âm/0 bị bỏ qua")
	t.ok(Wallet.spend(s, 40), "spend đủ")
	t.eq(s.coins, start, "sau spend")
	t.ok(Wallet.spend(s, start), "spend hết")
	t.eq(s.coins, 0, "còn 0")
	t.ok(not Wallet.spend(s, 1), "spend thiếu")
	t.eq(s.coins, 0, "thiếu thì không trừ")
	t.ok(Wallet.spend(s, 0), "spend 0")
	t.ok(not Wallet.spend(s, -10), "spend âm bị từ chối")
	t.eq(s.coins, 0, "spend âm không đổi")


func test_inventory(t: T) -> void:
	var s := SaveSchema.defaults()
	t.eq(Wallet.inv_count(s, "hint"), 0, "kho trống")
	t.ok(not Wallet.inv_use(s, "hint"), "dùng khi hết")
	Wallet.inv_add(s, "hint", 2)
	Wallet.inv_add(s, "smash", 1)
	t.eq(Wallet.inv_count(s, "hint"), 2, "hint 2")
	t.eq(Wallet.inv_count(s, "smash"), 1, "smash 1")
	t.eq(Wallet.inv_count(s, "move"), 0, "move 0")
	t.ok(Wallet.inv_use(s, "hint"), "dùng hint")
	t.eq(Wallet.inv_count(s, "hint"), 1, "hint còn 1")
	t.ok(Wallet.inv_use(s, "hint"), "dùng hint lần 2")
	t.ok(not Wallet.inv_use(s, "hint"), "hint hết")
	t.eq(Wallet.inv_count(s, "hint"), 0, "hint 0")
	Wallet.inv_add(s, "move", -3)
	Wallet.inv_add(s, "bogus", 5)
	t.eq(Wallet.inv_count(s, "move"), 0, "add âm bị bỏ qua")
	t.eq(Wallet.inv_count(s, "bogus"), 0, "loại lạ bị bỏ qua")
	t.ok(not s.inv.has("bogus"), "không thêm khoá lạ")
