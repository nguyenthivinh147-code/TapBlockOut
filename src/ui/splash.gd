extends "res://src/ui/stub_ui.gd"
## Wireframe 1.1 Splash / Loading: logo, tiến trình tải. Chưa nối logic.

func _sample() -> Dictionary:
	return SampleData.SPLASH


func _build() -> void:
	add_child(ThemeKit.make_background())
	var col := _center_column()
	var logo := TextureRect.new()
	logo.texture = load("res://assets/icon_app.png") as Texture2D
	logo.custom_minimum_size = Vector2(260, 260)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(logo)
	col.add_child(_shout(tr("APP_NAME"), ThemeKit.FS_HUGE))
	col.add_child(_shout(tr("boot_tagline"), ThemeKit.FS_BODY, ThemeKit.TEXT_DIM))
	var bar := _bar(float(view.percent) / 100.0, ThemeKit.GOLD_DEEP)
	bar.custom_minimum_size = Vector2(520, 32)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(bar)
	col.add_child(_shout(tr("boot_loading") % int(view.percent), ThemeKit.FS_SMALL))
	col.add_child(_shout(str(view.version), ThemeKit.FS_SMALL - 4, ThemeKit.TEXT_DIM))
