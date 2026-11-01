extends RefCounted
const T := preload("res://tests/t.gd")
const Config := preload("res://src/config.gd")
const RescueFlow := preload("res://src/meta/rescue_flow.gd")


func test_four_offers_then_lost(t: T) -> void:
	Config.reset()
	var r := RescueFlow.new()
	var prices := [1900, 2200, 2500, 2800]
	for i in 4:
		var o := r.offer(0, 99999, 2, 3)
		t.eq(o.index, i, "lần %d" % (i + 1))
		t.eq(o.price, prices[i], "giá lần %d" % (i + 1))
		t.eq(o.video, true, "video lần %d" % (i + 1))
		t.eq(o.use_inventory, false, "không kho")
		t.eq(o.affordable, true, "đủ gold")
		t.eq(o.remaining, 2, "còn 2 khối")
		t.eq(r.accept("gold"), {"moves": 3, "price": prices[i]}, "mua lần %d" % (i + 1))
		t.ok(not r.is_lost(), "chưa thua sau lần %d" % (i + 1))
	var end := r.offer(0, 99999, 1, 1)
	t.eq(end.index, -1, "quá 4 lần không còn popup")
	t.ok(r.is_lost(), "quá 4 lần là thua")
	t.eq(r.accept("gold"), {}, "thua rồi không accept")


func test_skip_loses(t: T) -> void:
	Config.reset()
	var r := RescueFlow.new()
	t.eq(r.offer(0, 0, 5, 1).index, 0, "popup đầu")
	r.skip()
	t.ok(r.is_lost(), "bỏ qua là thua")
	t.eq(r.offer(0, 9999, 5, 1).index, -1, "đã thua")
	t.eq(r.accept("gold"), {}, "thua rồi không accept")
	var r2 := RescueFlow.new()
	r2.offer(0, 99999, 5, 1)
	r2.accept("gold")
	r2.offer(0, 99999, 5, 1)
	r2.skip()
	t.ok(r2.is_lost(), "bỏ qua ở lần 2 cũng thua")


func test_inventory_counts_one(t: T) -> void:
	Config.reset()
	var r := RescueFlow.new()
	var o := r.offer(2, 0, 3, 1)
	t.eq(o.use_inventory, true, "dùng kho")
	t.eq(o.affordable, true, "kho thì miễn phí")
	t.eq(r.accept("inventory"), {"moves": 3, "price": 0}, "dùng kho lần 1")
	o = r.offer(1, 0, 3, 1)
	t.eq(o.index, 1, "kho vẫn tính một lần")
	t.eq(r.accept("inventory"), {"moves": 3, "price": 0}, "dùng kho lần 2")
	o = r.offer(0, 5000, 3, 1)
	t.eq(o.index, 2, "lần 3")
	t.eq(o.price, 2500, "giá lần 3")
	t.eq(r.accept("inventory"), {}, "không có kho thì từ chối")


func test_insufficient_gold(t: T) -> void:
	Config.reset()
	var r := RescueFlow.new()
	var o := r.offer(0, 1800, 4, 1)
	t.eq(o.index, 0, "popup vẫn hiện")
	t.eq(o.affordable, false, "thiếu gold")
	t.eq(r.accept("gold"), {}, "không mua được")
	o = r.offer(0, 1900, 4, 1)
	t.eq(o.affordable, true, "đúng đủ gold")
	t.eq(r.accept("gold").price, 1900, "mua được")
	o = r.offer(0, 0, 4, 1)
	t.eq(o.affordable, false, "hết gold")
	t.ok(o.video, "video vẫn có")
	t.eq(r.accept("video"), {"moves": 3, "price": 0}, "video thay gold")


func test_video_all_four_by_default(t: T) -> void:
	Config.reset()
	var r := RescueFlow.new()
	for i in 4:
		r.offer(0, 0, 1, 1)
		t.eq(r.accept("video"), {"moves": 3, "price": 0}, "video lần %d" % (i + 1))
	t.eq(r.offer(0, 0, 1, 1).index, -1, "hết 4 lần")


func test_video_max_config(t: T) -> void:
	Config.reset()
	Config.ECON.rescue_video_max = 1
	var r := RescueFlow.new()
	t.eq(r.offer(0, 99999, 1, 1).video, true, "lần 1 có video")
	r.accept("gold")
	var o := r.offer(0, 99999, 1, 1)
	t.eq(o.video, false, "lần 2 tắt video")
	t.eq(r.accept("video"), {}, "video bị từ chối")
	t.eq(r.accept("bogus"), {}, "method lạ")
	t.eq(r.accept("gold").price, 2200, "gold lần 2")
	Config.reset()


func test_warn_life_from_level(t: T) -> void:
	Config.reset()
	t.eq(RescueFlow.new().offer(0, 0, 1, 9).warn_life, false, "L9")
	t.eq(RescueFlow.new().offer(0, 0, 1, 10).warn_life, true, "L10")
	t.eq(RescueFlow.new().offer(0, 0, 1, 50).warn_life, true, "L50")


func test_config_driven(t: T) -> void:
	Config.reset()
	Config.ECON.rescue_moves = 5
	Config.ECON.rescue_prices = [100, 150]
	var r := RescueFlow.new()
	t.eq(r.offer(0, 100, 1, 1).price, 100, "giá theo config")
	t.eq(r.accept("gold"), {"moves": 5, "price": 100}, "moves theo config")
	t.eq(r.offer(0, 500, 1, 1).price, 150, "giá lần 2 theo config")
	r.accept("gold")
	t.eq(r.offer(0, 500, 1, 1).index, -1, "số lần theo độ dài mảng giá")
	Config.reset()


func test_fresh_flow_resets(t: T) -> void:
	Config.reset()
	var r := RescueFlow.new()
	r.offer(0, 0, 1, 1)
	r.skip()
	var r2 := RescueFlow.new()
	t.eq(r2.offer(0, 0, 1, 1).index, 0, "lượt mới có popup đầu")
	t.ok(not r2.is_lost(), "lượt mới chưa thua")
