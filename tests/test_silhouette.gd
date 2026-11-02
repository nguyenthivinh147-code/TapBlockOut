extends RefCounted
## Hình dạng level: raster từ tên hình, liền một mảng, đối xứng, không kín khung.
const T := preload("res://tests/t.gd")
const Silhouette := preload("res://src/core/silhouette.gd")
const LevelData := preload("res://src/core/level_data.gd")


func _set_of(cells: Array[Vector2i]) -> Dictionary:
	var s := {}
	for c in cells:
		s[c] = true
	return s


func test_every_kind_is_a_real_shape(t: T) -> void:
	for kind in Silhouette.KINDS:
		var cells := Silhouette.cells(kind, 10, 16)
		t.ok(cells.size() >= 40, "%s: đủ ô (%d)" % [kind, cells.size()])
		t.ok(cells.size() < 160, "%s: không kín khung" % kind)
		t.ok(LevelData.connected(_set_of(cells)), "%s: liền một mảng" % kind)
		for c in cells:
			t.ok(c.x >= 0 and c.y >= 0 and c.x < 10 and c.y < 16, "%s: ô %s trong khung" % [kind, str(c)])


func test_kinds_differ(t: T) -> void:
	var sigs := {}
	for kind in Silhouette.KINDS:
		sigs[str(Silhouette.cells(kind, 10, 16))] = true
	t.eq(sigs.size(), Silhouette.KINDS.size(), "mỗi hình một dạng khác nhau")


func test_mirror_symmetry(t: T) -> void:
	for kind in Silhouette.KINDS:
		var s := _set_of(Silhouette.cells(kind, 10, 16))
		for c in s:
			t.ok(s.has(Vector2i(9 - c.x, c.y)), "%s: đối xứng trái phải tại %s" % [kind, str(c)])
	for kind in Silhouette.V_SYMMETRIC:
		var s := _set_of(Silhouette.cells(kind, 10, 16))
		for c in s:
			t.ok(s.has(Vector2i(c.x, 15 - c.y)), "%s: đối xứng trên dưới tại %s" % [kind, str(c)])


func test_rect_is_full(t: T) -> void:
	t.eq(Silhouette.cells(Silhouette.RECT, 3, 4).size(), 12, "rect kín khung")


func test_ring_has_a_hole(t: T) -> void:
	var s := _set_of(Silhouette.cells("ring", 10, 16))
	t.ok(not s.has(Vector2i(5, 8)), "giữa vòng trống")


func test_too_small_to_stay_connected_returns_empty(t: T) -> void:
	for kind in Silhouette.KINDS:
		var cells := Silhouette.cells(kind, 2, 2)
		t.ok(cells.is_empty() or LevelData.connected(_set_of(cells)), "%s 2x2: rỗng hoặc liền mảng" % kind)
