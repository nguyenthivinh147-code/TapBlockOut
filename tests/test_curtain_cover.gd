extends RefCounted
## Every curtain Main.curtain_swap can run (candy, bomb, level, gift) covers its parent and takes the touches under it
## from the frame it is added, before close() covers the screen. The candy curtain once kept a 0x0 rect
## (set_anchors_preset in _ready keeps the current rect), so taps went through to Home while it fell: smoke M seed 1
## opened Settings during Play's curtain and the level then freed Home under it.
const T := preload("res://tests/t.gd")
const CandyCurtain := preload("res://src/ui/candy_curtain.gd")
const BombCurtain := preload("res://src/ui/bomb_curtain.gd")
const LevelCurtain := preload("res://src/ui/level_curtain.gd")
const GiftCurtain := preload("res://src/ui/gift_curtain.gd")

const SCREEN := Vector2(886, 1920)


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func test_covers_parent_from_first_frame(t: T) -> void:
	var host := Control.new()
	host.size = SCREEN
	_tree().root.add_child(host)
	for kind: GDScript in [CandyCurtain, BombCurtain, LevelCurtain, GiftCurtain]:
		var name := kind.resource_path.get_file()
		var c: Control = kind.new()
		host.add_child(c)
		t.eq(c.size, SCREEN, "%s: cỡ bằng node cha ngay khi thêm" % name)
		await _tree().process_frame
		t.eq(c.get_rect(), Rect2(Vector2.ZERO, SCREEN), "%s: phủ node cha sau một khung" % name)
		t.eq(c.mouse_filter, Control.MOUSE_FILTER_STOP, "%s: chặn chạm" % name)
		for p: Vector2 in [Vector2(10, 10), SCREEN * 0.5, SCREEN - Vector2(10, 10)]:
			t.ok(c.get_global_rect().has_point(host.global_position + p), "%s: nhận chạm ở %s" % [name, p])
		c.free()
	host.free()
