extends RefCounted
## popup_change_name over the Profile: saves through Game, rejects invalid and banned nicknames with the toast.
const T := preload("res://tests/t.gd")
const Config := preload("res://src/config.gd")

const DIR := "user://test_ui_change_name"


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _g() -> Node:
	var g: Node = _root().get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	g.s.level = 5
	g.test_now = 1_800_000_000
	return g


func _profile() -> Control:
	var p := (load("res://scenes/profile.tscn") as PackedScene).instantiate() as Control
	_root().add_child(p)
	p.setup({})
	return p


func _popup(args: Dictionary = {}) -> Control:
	var n := (load("res://scenes/popup_change_name.tscn") as PackedScene).instantiate() as Control
	_root().add_child(n)
	n.setup(args)
	return n


func test_rename_from_profile(t: T) -> void:
	var g := _g()
	var p := _profile()
	t.eq(p.name_label.text, p.tr("profile_name_default"), "chưa đặt tên: hiện tên mặc định")
	var edit := p.find_child("EditNameButton", true, false) as Button
	t.ok(edit != null, "có nút đổi tên")
	edit.pressed.emit()
	var pop := p.get_node_or_null("ChangeName") as Control
	t.ok(pop != null, "mở popup đổi tên")
	edit.pressed.emit()
	t.eq(p.get_children().filter(func(c: Node) -> bool: return c.has_method("_save")).size(), 1, "chạm hai lần chỉ mở một popup")
	t.eq(pop.name_input.text, "", "ô trống, hiện Placeholder")
	pop.name_input.text = "  Mint_Pop "
	pop.save_button.pressed.emit()
	t.eq(g.profile_name(), "Mint_Pop", "đã lưu, bỏ khoảng trắng")
	t.eq(str(g.s.profile.name), "Mint_Pop", "ghi vào s.profile")
	t.ok(pop.is_queued_for_deletion(), "lưu xong đóng popup")
	t.eq(p.name_label.text, "Mint_Pop", "Profile hiện tên mới")
	p.free()
	var again := _profile()
	t.eq(again.name_label.text, "Mint_Pop", "mở lại Profile vẫn là tên mới")
	again.free()


func test_rejected_names_keep_popup_open(t: T) -> void:
	var g := _g()
	var pop := _popup()
	var got: Array = []
	pop.closed.connect(func(r: Variant) -> void: got.append(r))
	pop.name_input.text = "f.u.c.k"
	pop.save_button.pressed.emit()
	t.eq(pop.toast_text, pop.tr("profile_name_banned"), "từ cấm: báo không được dùng")
	t.eq(g.profile_name(), "", "từ cấm: không lưu")
	pop.name_input.text = "ab"
	pop.save_button.pressed.emit()
	t.eq(pop.toast_text, pop.tr("profile_name_invalid"), "quá ngắn: báo sai quy định")
	pop.name_input.text = "Việt"
	pop.save_button.pressed.emit()
	t.eq(pop.toast_text, pop.tr("profile_name_invalid"), "chữ có dấu: báo sai quy định")
	t.eq(pop.find_children("*", "Control", true, false).filter(
		func(c: Node) -> bool: return c.has_meta("u_canvas")).size(), 2, "toast mới thay toast cũ")
	t.eq(got.size(), 0, "popup vẫn mở")
	pop.name_input.text = "Taffy.Cat"
	pop.name_input.text_submitted.emit(pop.name_input.text)
	t.eq(g.profile_name(), "Taffy.Cat", "Enter cũng lưu")
	t.eq(got.size(), 1, "đóng một lần")
	t.eq((got[0] as Dictionary).get("action", ""), "ok", "action ok")
	t.eq((got[0] as Dictionary).get("name", ""), "Taffy.Cat", "kèm tên")
	pop.free()


func test_close_keeps_old_name(t: T) -> void:
	var g := _g()
	g.set_profile_name("Bob")
	var pop := _popup()
	var got: Array = []
	pop.closed.connect(func(r: Variant) -> void: got.append(r))
	t.eq(pop.name_input.text, "Bob", "điền sẵn tên đang dùng")
	t.eq(pop.name_input.max_length, Config.NAME_MAX, "giới hạn 14 ký tự")
	pop.name_input.text = "Lolly"
	var x: Array = pop.ui.field("closeButtons", "PopupEditNameUICoreLayer")
	(x[1] as Button).pressed.emit()
	(x[0] as Button).pressed.emit()
	t.eq(got.size(), 1, "đóng một lần")
	t.eq((got[0] as Dictionary).get("action", ""), "close", "action close")
	t.eq(g.profile_name(), "Bob", "đóng không lưu")
	pop.free()


func test_edit_button_in_release(t: T) -> void:
	_g()
	Config.ui_preview_override = 0
	var p := _profile()
	t.ok(p.find_child("EditNameButton", true, false) != null, "bản phát hành vẫn đổi tên được")
	p.free()
	Config.ui_preview_override = -1
