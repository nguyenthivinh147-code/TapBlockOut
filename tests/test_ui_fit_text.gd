extends RefCounted
## fit_text skips a refit whose text, room and size did not change (docs/UI_UNITY.md), yet still refits on new text
## or after an outside size change.
const T := preload("res://tests/t.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")

const DIR := "user://test_ui_fit_text"
const NOW := 1800000000
const WIN_CARD := "res://scenes/win_card.tscn"
const TITLE := "Panel/WinPanel/WinPanel/Panel/Image/Text (TMP)"


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func test_fit_text_refits_on_change(t: T) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var g: Node = _tree().root.get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	g.test_now = NOW
	var node := (load(WIN_CARD) as PackedScene).instantiate() as Control
	_tree().root.add_child(node)
	node.call("setup", {"coins": 40})
	await _tree().process_frame
	var l := (node.get("ui") as RefCounted).call("node", TITLE) as Label
	var short := l.text
	var fs := l.get_theme_font_size("font_size")
	UnityUI.set_text(l, short + " " + short + " " + short + " " + short)
	var long_fs := l.get_theme_font_size("font_size")
	t.ok(long_fs < fs, "chữ dài hơn: co lại (%d < %d)" % [long_fs, fs])
	UnityUI.fit_text(l)
	t.eq(l.get_theme_font_size("font_size"), long_fs, "fit lại không đổi gì: giữ cỡ")
	l.add_theme_font_size_override("font_size", fs + 20)
	UnityUI.fit_text(l)
	t.eq(l.get_theme_font_size("font_size"), long_fs, "cỡ bị đổi từ ngoài: fit lại")
	UnityUI.set_text(l, short)
	t.eq(l.get_theme_font_size("font_size"), fs, "chữ cũ: về cỡ cũ")
	node.free()
