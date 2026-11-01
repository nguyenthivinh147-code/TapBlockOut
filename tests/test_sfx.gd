extends RefCounted
const T := preload("res://tests/t.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")
const SfxScript := preload("res://src/game/sfx.gd")


func _make() -> Node:
	var s := SfxScript.new()
	Engine.get_main_loop().root.add_child(s)
	return s


func test_buses(t: T) -> void:
	var s := _make()
	t.ok(AudioServer.get_bus_index("SFX") != -1, "bus SFX")
	t.ok(AudioServer.get_bus_index("Music") != -1, "bus Music")
	var count := AudioServer.bus_count
	s.setup()
	t.eq(AudioServer.bus_count, count, "setup lặp không thêm bus")
	s.queue_free()


func test_missing_files_silent(t: T) -> void:
	var s := _make()
	s.play("khong_ton_tai")
	s.play("")
	s.music("khong_co_nhac")
	t.eq(s.last_played, "", "không phát file thiếu")
	t.ok(not s.is_music_playing(), "không có nhạc")
	t.eq(s.music_name, "khong_co_nhac", "nhớ tên nhạc")
	s.stop_music()
	t.eq(s.music_name, "", "stop_music xoá tên")
	s.pause_for_ad()
	s.resume_after_ad()
	s.queue_free()


func test_settings_mute(t: T) -> void:
	var s := _make()
	s.apply_settings({"sfx": false, "music": false, "haptics": false})
	t.ok(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "SFX tắt")
	t.ok(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "Music tắt")
	t.ok(not s.haptics_on, "haptics tắt")
	s.apply_settings({"sfx": true})
	t.ok(not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "SFX bật lại")
	t.ok(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "khoá thiếu giữ nguyên")
	s.apply_settings({"sfx": true, "music": true, "haptics": true})
	s.queue_free()


func test_real_stream_playback_state(t: T) -> void:
	var s := _make()
	# Tự nạp stream vào cache để kiểm luồng phát mà không cần file asset.
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.data = PackedByteArray([0, 0, 0, 0])
	s._cache["s:test_tone"] = wav
	s.play("test_tone")
	t.eq(s.last_played, "test_tone", "đã phát")
	s.apply_settings({"sfx": false})
	s.play("test_tone")
	s.last_played = ""
	s.play("test_tone")
	t.eq(s.last_played, "", "sfx tắt không phát")
	s.apply_settings({"sfx": true})
	s.pause_for_ad()
	s.play("test_tone")
	t.eq(s.last_played, "", "đang quảng cáo không phát")
	s.resume_after_ad()
	s.play("test_tone")
	t.eq(s.last_played, "test_tone", "hết quảng cáo phát lại")
	s.queue_free()


func test_music_pause_resume(t: T) -> void:
	var s := _make()
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.data = PackedByteArray([0, 0, 0, 0])
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s._cache["m:bgm_test"] = wav
	s.music("bgm_test")
	t.ok(s.is_music_playing(), "nhạc chạy")
	s.pause_for_ad()
	t.ok(not s.is_music_playing(), "dừng khi quảng cáo")
	s.resume_after_ad()
	t.ok(s.is_music_playing(), "chạy lại sau quảng cáo")
	s.apply_settings({"music": false})
	t.ok(not s.is_music_playing(), "tắt nhạc")
	s.apply_settings({"music": true})
	t.ok(s.is_music_playing(), "bật nhạc lại")
	s.stop_music()
	t.ok(not s.is_music_playing(), "stop_music")
	s.apply_settings({"music": true})
	s.queue_free()


func test_theme_palette_and_widgets(t: T) -> void:
	t.eq(ThemeKit.block_color("yellow"), Color("F5C518"), "vàng")
	t.eq(ThemeKit.block_color("purple"), Color("9B51E0"), "tím")
	for kind in ["primary", "secondary", "video", "danger", "ghost"]:
		var b := ThemeKit.make_button("OK", kind)
		t.ok(b.custom_minimum_size.x >= 96 and b.custom_minimum_size.y >= 96, "nút >= 96 (%s)" % kind)
		t.eq(b.text, "OK", "chữ nút")
		b.free()
	var p := ThemeKit.make_panel()
	t.ok(p.has_theme_stylebox_override("panel"), "panel có style")
	p.free()
	t.ok(ThemeKit.make_theme() != null, "theme")
	var bg := ThemeKit.make_background()
	t.eq(bg.color, ThemeKit.BG, "nền")
	bg.free()


func test_icon_placeholder(t: T) -> void:
	ThemeKit.clear_icon_cache()
	var tex := ThemeKit.icon("khong_co_icon")
	t.ok(tex != null, "placeholder không null")
	t.eq(tex.get_width(), ThemeKit.ICON_SIZE, "rộng")
	t.ok(ThemeKit.icon("khong_co_icon") == tex, "cache")
	t.ok(not ThemeKit.has_real_icon("khong_co_icon"), "không phải file thật")
	t.ok(ThemeKit.icon("khac") != tex, "tên khác, hình khác")


func test_popup_tween(t: T) -> void:
	var loose := Control.new()
	t.ok(ThemeKit.popup_in(loose) == null, "chưa trong cây thì null")
	loose.free()
	var root: Node = Engine.get_main_loop().root
	var c := Control.new()
	c.size = Vector2(200, 100)
	root.add_child(c)
	var tw := ThemeKit.popup_in(c)
	t.ok(tw != null, "popup_in có tween")
	t.near(c.modulate.a, 0.0, 0.0001, "bắt đầu trong suốt")
	tw.kill()
	var tw2 := ThemeKit.popup_out(c)
	t.ok(tw2 != null, "popup_out có tween")
	tw2.kill()
	c.queue_free()
