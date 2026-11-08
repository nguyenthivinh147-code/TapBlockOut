extends RefCounted
## Lời khen (PraiseFx): chữ bật từ đáy nên không xuống dưới mép cho phép, vừa khung, nhóm dòng mờ đi rồi về, tự dọn.
const T := preload("res://tests/t.gd")
const PraiseFx := preload("res://src/ui/praise_fx.gd")

const DT := 1.0 / 60.0


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _host() -> Dictionary:
	var host := Control.new()
	host.size = Vector2(886, 800)
	_tree().root.add_child(host)
	var tut := Label.new()
	tut.text = "Tap a block"
	host.add_child(tut)
	var label := Label.new()
	label.name = "ClapLabel"
	label.text = "Nice one!"
	label.visible = false
	host.add_child(label)
	var fx := PraiseFx.new()
	host.add_child(fx)
	host.move_child(fx, 0)
	return {"host": host, "tut": tut, "label": label, "fx": fx}


func _bottom(label: Label) -> Vector2:
	return label.get_transform() * Vector2(label.size.x * 0.5, label.size.y)


func test_caption_stays_above_foot_and_cleans_up(t: T) -> void:
	var h := _host()
	var label: Label = h.label
	var fx: Control = h.fx
	var tut: Label = h.tut
	var foot := Vector2(443, 400)
	var dim: Array[CanvasItem] = [tut]
	fx.start(label, foot, 2000.0, 2000.0, 1.0, dim)
	t.ok(label.visible, "chữ hiện ngay")
	t.ok(label.material is ShaderMaterial, "chữ có shader tô màu")
	t.ok(h.host.get_node_or_null("PraiseBurst") != null, "lớp sao, confetti trước chữ")
	t.eq(h.host.get_node("PraiseBurst").get_index(), label.get_index() - 1, "lớp sao nằm ngay sau chữ")
	t.ok(label.get_node_or_null("PraiseTwinkles") != null, "lấp lánh trên chữ")
	var low := -INF
	var biggest := 0.0
	var dimmed := 1.0
	var steps := 0
	while not fx.is_queued_for_deletion() and steps < 400:
		low = maxf(low, _bottom(label).y)
		biggest = maxf(biggest, label.scale.x)
		if fx.elapsed() > 0.4 and fx.elapsed() < 1.0:
			dimmed = minf(dimmed, tut.modulate.a)
		fx._process(DT)
		steps += 1
	t.ok(fx.is_queued_for_deletion(), "tự kết thúc")
	t.ok(steps * DT < PraiseFx.END + 0.1, "xong trong %.2f s" % PraiseFx.END)
	t.ok(low <= foot.y + 0.01, "đáy chữ không xuống dưới mép (thấp nhất %.2f)" % low)
	t.ok(biggest >= PraiseFx.PEAK - 0.01, "có lúc bật to tới PEAK")
	t.ok(dimmed < 0.05, "dòng hướng dẫn mờ đi khi khen")
	t.ok(not label.visible, "chữ ẩn khi xong")
	t.eq(label.scale, Vector2.ONE, "chữ về cỡ gốc")
	t.eq(tut.modulate.a, 1.0, "dòng hướng dẫn hiện lại")
	await _tree().process_frame
	t.ok(h.host.get_node_or_null("PraiseBurst") == null, "lớp sao đã gỡ")
	t.ok(label.get_node_or_null("PraiseTwinkles") == null, "lấp lánh đã gỡ")
	t.ok(h.host.get_node_or_null("PraiseFx") == null, "hiệu ứng đã gỡ")
	h.host.free()


func test_caption_shrinks_to_fit(t: T) -> void:
	var h := _host()
	var label: Label = h.label
	var fx: Control = h.fx
	fx.start(label, Vector2(443, 400), 200.0, 40.0, 1.0)
	t.ok(fx.fit_scale() < 1.0, "chữ to hơn chỗ thì co")
	while fx.elapsed() < PraiseFx.REST + 0.05:
		fx._process(DT)
	var sz: Vector2 = label.size * label.scale
	var swell := 1.0 + PraiseFx.BREATHE
	t.ok(sz.x <= 200.0 * swell + 0.5 and sz.y <= 40.0 * swell + 0.5, "lúc nghỉ chữ vừa chỗ (%s)" % sz)
	h.host.free()


func test_free_midway_restores_dimmed(t: T) -> void:
	var h := _host()
	var tut: Label = h.tut
	var fx: Control = h.fx
	var dim: Array[CanvasItem] = [tut]
	fx.start(h.label, Vector2(443, 400), 2000.0, 2000.0, 1.0, dim)
	for i in 30:
		fx._process(DT)
	t.ok(tut.modulate.a < 0.05, "đang mờ")
	h.host.remove_child(fx)
	fx.free()
	t.eq(tut.modulate.a, 1.0, "gỡ giữa chừng thì dòng hướng dẫn hiện lại")
	h.host.free()
