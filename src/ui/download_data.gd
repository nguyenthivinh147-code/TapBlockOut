extends "res://src/ui/stub_ui.gd"
## Wireframe 1.3 Download Resources: tải gói nội dung lần đầu. Chưa nối logic.

func _sample() -> Dictionary:
	return SampleData.DOWNLOAD


func _full_screen() -> bool:
	return true


func _title() -> String:
	return tr("boot_download_title")


func _fill(box: VBoxContainer) -> void:
	box.add_child(_say(tr("boot_download_sub"), ThemeKit.FS_SMALL, ThemeKit.INK_DIM))
	box.add_child(ThemeKit.make_sprite("banner_coins", 220))
	box.add_child(_say(tr("boot_download_need") % int(view.total_mb), ThemeKit.FS_SMALL + 4, ThemeKit.BROWN))
	box.add_child(_option(tr("boot_download_wifi"), true))
	box.add_child(_option(tr("boot_download_cell"), false))
	box.add_child(_bar(float(view.percent) / 100.0))
	box.add_child(_say(tr("boot_download_progress") % [int(view.percent), int(view.done_mb), int(view.total_mb)], ThemeKit.FS_SMALL, ThemeKit.INK_DIM))
	box.add_child(_btn(tr("boot_download_go"), "primary", "download"))
	box.add_child(_btn(tr("boot_skip"), "ghost", "skip"))


func _option(content: String, on: bool) -> Control:
	var well := ThemeKit.make_well()
	var h := HBoxContainer.new()
	well.add_child(h)
	var l := ThemeKit.ink_label(content, ThemeKit.FS_SMALL + 2)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	h.add_child(ThemeKit.make_icon("ui_check" if on else "ui_close", 44))
	return well
