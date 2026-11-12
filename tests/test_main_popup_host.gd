extends RefCounted
## Main._popup_then: when the screen a popup was opened over is gone by the time the popup closes, the close does
## nothing (no refresh, no Home rebuild) and raises no engine error. The close callback held the host screen in a
## lambda capture, so a freed host printed "Lambda capture at index 0 was freed" (smoke M seed 1, 2026-11-11).
const T := preload("res://tests/t.gd")
const Driver := preload("res://tests/e2e_driver.gd")

const DIR := "user://test_main_popup_host"


func test_host_freed_before_popup_closes(t: T) -> void:
	var d := Driver.new()
	await d.begin(DIR, 20, -1, true, false)
	var main := d.main
	# By id: a test lambda capturing the freed Home would raise the same engine error.
	var home_id := (main.current_screen as Node).get_instance_id()
	t.eq(main.current_name, "home", "đang ở Home")
	var layer: Control = main.popup_layer
	var before := layer.get_child_count()
	main.call("_popup_then", main.SETTINGS, {}, true)
	t.eq(layer.get_child_count(), before + 1, "mở Settings trên Home")
	var p: Node = layer.get_child(layer.get_child_count() - 1)
	main.go("profile")
	t.ok(await d.wait_until(func() -> bool: return not is_instance_id_valid(home_id)), "Home đã bị gỡ")
	p.emit_signal("closed", null)
	await d.tree().process_frame
	t.eq(main.current_name, "profile", "đóng popup không dựng lại Home")
	d.finish()


## Settings mở trên Home rồi đóng mà không đổi gì: Home giữ nguyên (chỉ refresh), không dựng lại và phát lại hiệu ứng
## mở Home (smoke T, ảnh popup_close, 2026-11-12). Đổi ngôn ngữ thì đóng Settings mới dựng lại Home.
func test_settings_close_keeps_home(t: T) -> void:
	var d := Driver.new()
	await d.begin(DIR, 20, -1, true, false)
	var main := d.main
	var home_id := (main.current_screen as Node).get_instance_id()
	main.call("_popup_then", main.SETTINGS, {}, true)
	var layer: Control = main.popup_layer
	var p: Node = layer.get_child(layer.get_child_count() - 1)
	p.call("close")
	await d.tree().process_frame
	t.eq(main.current_name, "home", "vẫn ở Home")
	t.eq((main.current_screen as Node).get_instance_id(), home_id, "đóng Settings không dựng lại Home")
	main.call("_popup_then", main.SETTINGS, {}, true)
	p = layer.get_child(layer.get_child_count() - 1)
	d.game().set_setting("lang", "vi")
	p.call("_on_language", "vi")
	p.call("close")
	await d.tree().process_frame
	t.ok((main.current_screen as Node).get_instance_id() != home_id, "đổi ngôn ngữ rồi đóng Settings thì dựng lại Home")
	d.game().set_setting("lang", "en")
	d.finish()
