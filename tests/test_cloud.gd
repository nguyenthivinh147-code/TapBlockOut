extends RefCounted
const T := preload("res://tests/t.gd")
const SaveSchema := preload("res://src/meta/save_schema.gd")
const MockIap := preload("res://src/platform/mock_iap.gd")

const DIR := "user://test_cloud"


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _p() -> Node:
	return _root().get_node("Platform")


func _g() -> Node:
	DirAccess.make_dir_recursive_absolute(DIR)
	var g: Node = _root().get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	var p := _p()
	p.save.last_json = ""
	p.save.cloud_json = ""
	p.iap = MockIap.new()
	p.notif.granted = true
	return g


## Bản save mẫu đã qua JSON như khi lên cloud.
func _save(runs: int, coins: int, level: int, buys: Array = []) -> Dictionary:
	var d := SaveSchema.defaults()
	d["runs"] = runs
	d["coins"] = coins
	d["level"] = level
	d["buys"] = buys
	return d


func _json(d: Dictionary) -> String:
	return JSON.stringify(d)


func _buy(token: String, sku: String) -> Dictionary:
	return {"token": token, "sku": sku, "order_id": "o_" + token, "at": 1}


## Như android_save sau khi đồng bộ xong: đặt cloud_json rồi phát cloud_synced.
func _sync(json: String) -> void:
	_p().save.cloud_json = json
	_p().save.cloud_synced.emit(json)


func _boot_with(g: Node, local: Dictionary, cloud_raw: String) -> void:
	g.s = local
	g.save_now()
	_p().save.cloud_json = cloud_raw
	await g.boot()


func test_cloud_with_more_runs_wins(t: T) -> void:
	var g := _g()
	await _boot_with(g, _save(2, 100, 3), _json(_save(5, 777, 9)))
	t.eq(int(g.s.runs), 5, "runs lấy từ cloud")
	t.eq(int(g.s.coins), 777, "coins lấy từ cloud")
	t.eq(int(g.s.level), 9, "level lấy từ cloud")
	var saved := JSON.parse_string(FileAccess.get_file_as_string(DIR + "/save.json")) as Dictionary
	t.eq(int(saved.runs), 5, "đã lưu ngay xuống file")


func test_equal_runs_uses_play_ms(t: T) -> void:
	var g := _g()
	var cloud := _save(4, 50, 6)
	cloud["play_ms"] = 9000
	var local := _save(4, 10, 2)
	local["play_ms"] = 100
	await _boot_with(g, local, _json(cloud))
	t.eq(int(g.s.level), 6, "runs bằng nhau thì play_ms cao hơn thắng")


func test_local_wins_keeps_state(t: T) -> void:
	var g := _g()
	await _boot_with(g, _save(8, 300, 12), _json(_save(3, 9999, 40)))
	t.eq(int(g.s.runs), 8, "local nhiều runs hơn")
	t.eq(int(g.s.coins), 300, "coins local giữ nguyên")
	t.eq(int(g.s.level), 12, "level local giữ nguyên")
	# hoà: giữ local
	g = _g()
	await _boot_with(g, _save(4, 300, 12), _json(_save(4, 9999, 40)))
	t.eq(int(g.s.coins), 300, "hoà thì giữ local")


func test_merge_purchases_grants_once(t: T) -> void:
	var g := _g()
	var local := _save(8, 1000, 12, [_buy("a", "gold_pack_1")])
	var cloud := _save(3, 0, 5, [_buy("a", "gold_pack_1"), _buy("b", "gold_pack_2")])
	await _boot_with(g, local, _json(cloud))
	t.eq(int(g.s.runs), 8, "local thắng")
	t.eq(g.s.buys.size(), 2, "gộp đơn không trùng token")
	t.eq(int(g.s.coins), 6000, "chỉ đơn b được cấp: 1000 + 5000")
	# cùng bản cloud tới lần nữa (signal muộn): không cấp lại
	_sync(_json(cloud))
	t.eq(int(g.s.coins), 6000, "không cấp hai lần cùng bản cloud")
	# bản cloud khác nhưng vẫn chứa đơn b: không cấp lại theo token
	cloud["coins"] = 1
	_sync(_json(cloud))
	t.eq(g.s.buys.size(), 2, "token b đã có")
	t.eq(int(g.s.coins), 6000, "token b không cộng lần hai")


func test_cloud_wins_regrants_local_only_purchase(t: T) -> void:
	var g := _g()
	var local := _save(2, 0, 3, [_buy("x", "gold_pack_1")])
	var cloud := _save(9, 400, 20, [_buy("y", "remove_ads")])
	cloud["no_ads"] = true
	await _boot_with(g, local, _json(cloud))
	t.eq(int(g.s.runs), 9, "cloud thắng")
	t.eq(g.s.buys.size(), 2, "gộp đơn hai bên")
	t.eq(int(g.s.coins), 1400, "đơn x chỉ ở local được cấp lại lên nền cloud")
	t.eq(bool(g.s.no_ads), true, "no_ads giữ")


func test_non_consumable_not_granted_twice(t: T) -> void:
	var g := _g()
	var local := _save(8, 100, 12, [_buy("n1", "remove_ads")])
	local["no_ads"] = true
	var cloud := _save(2, 0, 1, [_buy("n2", "remove_ads")])
	await _boot_with(g, local, _json(cloud))
	t.eq(g.s.buys.size(), 2, "ghi cả hai token")
	t.eq(int(g.s.coins), 100, "remove_ads đã có thì không cộng 500 lần hai")


func test_corrupt_or_empty_cloud_ignored(t: T) -> void:
	for raw in ["{not json", "[1,2]", "{}", "", "   "]:
		var g := _g()
		await _boot_with(g, _save(3, 55, 4), raw)
		t.eq(int(g.s.coins), 55, "cloud hỏng bị bỏ qua: " + raw)
		t.eq(int(g.s.runs), 3, "runs giữ: " + raw)
	var g2 := _g()
	await _boot_with(g2, _save(3, 55, 4), "")
	_sync("garbage")
	t.eq(int(g2.s.coins), 55, "cloud_synced hỏng không đổi gì")


func test_no_cloud_changes_nothing(t: T) -> void:
	var g := _g()
	await g.boot()
	t.eq(int(g.s.runs), 0, "mock không có cloud thì như cũ")
	t.eq(int(g.s.level), 1, "level mặc định")


func test_late_cloud_applied_after_boot(t: T) -> void:
	var g := _g()
	await _boot_with(g, _save(1, 10, 2), "")
	_sync(_json(_save(6, 600, 15)))
	t.eq(int(g.s.runs), 6, "cloud tới muộn được áp khi không ở level")
	t.eq(int(g.s.coins), 600, "coins từ cloud")


func test_late_cloud_deferred_while_in_level(t: T) -> void:
	var g := _g()
	await _boot_with(g, _save(1, 10, 2), "")
	g.set_in_level(true)
	_sync(_json(_save(6, 600, 15)))
	t.eq(int(g.s.coins), 10, "đang chơi level thì chưa đè")
	g.set_in_level(false)
	t.eq(int(g.s.coins), 600, "về Home thì áp")
	g.set_in_level(true)
	g.set_in_level(false)
	t.eq(int(g.s.runs), 6, "chỉ áp một lần")


func test_resume_delivers_pending_once(t: T) -> void:
	var g := _g()
	await g.boot()
	var r: Dictionary = await _p().buy("gold_pack_2")
	t.eq(r.status, "ok", "thanh toán xong ngoài game")
	t.eq(_p().pending().size(), 1, "đơn treo")
	var coins0 := int(g.s.coins)
	_p().resumed.emit()
	t.eq(int(g.s.coins), coins0 + 5000, "resume giao đơn treo")
	t.eq(g.s.buys.size(), 1, "ghi buys")
	t.eq(_p().pending().size(), 0, "đã finish")
	_p().resumed.emit()
	t.eq(int(g.s.coins), coins0 + 5000, "resume lần hai không giao lại")
	t.eq(g.s.buys.size(), 1, "buys vẫn một")


func test_resume_skips_delivery_while_buying(t: T) -> void:
	var g := _g()
	await g.boot()
	var coins0 := int(g.s.coins)
	var res: Dictionary = await g.buy_sku("gold_pack_1")
	t.eq(res.granted, true, "buy_sku vẫn thấy granted")
	_p().resumed.emit()
	t.eq(int(g.s.coins), coins0 + 1000, "không cộng trùng")
