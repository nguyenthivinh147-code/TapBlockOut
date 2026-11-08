extends RefCounted
## Loading screen (splash.gd) art laid out as the engine draws the boot splash: background and logo at the same place
## and size on every screen, so the switch from the boot splash neither zooms nor shrinks.
const T := preload("res://tests/t.gd")
const Splash := preload("res://src/ui/splash.gd")

const SCENE := "res://scenes/splash.tscn"
## 886x1920 reference, 20:9 and 21:9 phones (canvas matches width below 0.45), 16:9 phone, tablets, desktop window.
const SCREENS: Array[Vector2] = [
	Vector2(886, 1920), Vector2(1080, 2400), Vector2(1080, 2520), Vector2(1080, 1920),
	Vector2(1200, 1920), Vector2(1536, 2048), Vector2(886, 1368),
]
const SUPPORTED_MODES := [
	RenderingServer.SPLASH_STRETCH_MODE_KEEP_WIDTH, RenderingServer.SPLASH_STRETCH_MODE_KEEP_HEIGHT,
	RenderingServer.SPLASH_STRETCH_MODE_COVER, RenderingServer.SPLASH_STRETCH_MODE_IGNORE,
]


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _mode() -> int:
	return int(ProjectSettings.get_setting("application/boot_splash/stretch_mode"))


## Splash screen in a host the size of the screen, as Main shows it.
func _splash(screen: Vector2) -> Control:
	var host := Control.new()
	host.size = screen
	_tree().root.add_child(host)
	var sp := (load(SCENE) as PackedScene).instantiate() as Control
	host.add_child(sp)
	sp.call("setup", {"view": {"percent": 0, "version": "v0.1.0"}})
	return host


func _check(t: T, host: Control, screen: Vector2) -> void:
	var r := Splash.boot_rect(screen, _mode())
	var k := r.size / Splash.BOOT_SIZE
	var want_logo := Rect2(r.position + Splash.LOGO_RECT.position * k, Splash.LOGO_RECT.size * k)
	var pic := host.find_child("Image", true, false) as Control
	var logo := host.find_child("LogoGame", true, false) as Control
	var tag := "%dx%d " % [screen.x, screen.y]
	for pair in [[pic.get_global_rect(), r, "nền"], [logo.get_global_rect(), want_logo, "logo"]]:
		var got: Rect2 = pair[0]
		var want: Rect2 = pair[1]
		t.ok(got.position.distance_to(want.position) < 0.5 and got.size.distance_to(want.size) < 0.5,
			tag + pair[2] + " đúng chỗ boot splash: %s, cần %s" % [got, want])
	t.ok(logo.is_visible_in_tree(), tag + "logo hiện")


func test_art_matches_boot_splash_on_every_screen(t: T) -> void:
	for screen in SCREENS:
		var host := _splash(screen)
		_check(t, host, screen)
		var art := host.find_child("LoadingArt", true, false) as ColorRect
		t.eq(art.color, ProjectSettings.get_setting("application/boot_splash/bg_color"), "nền quanh ảnh là màu boot splash")
		host.free()


func test_art_follows_resize(t: T) -> void:
	var host := _splash(SCREENS[0])
	for screen in [SCREENS[2], SCREENS[5]]:
		host.size = screen
		_check(t, host, screen)
	host.free()


## The logo is whole on screen. Cover cuts the image top and bottom on screens wider than 9:16, so those are skipped
## while the project uses it.
func test_logo_inside_screen(t: T) -> void:
	var cover := _mode() == RenderingServer.SPLASH_STRETCH_MODE_COVER
	for screen in SCREENS:
		if cover and screen.x / screen.y > Splash.BOOT_SIZE.x / Splash.BOOT_SIZE.y:
			continue
		var r := Splash.boot_rect(screen, _mode())
		var k := r.size / Splash.BOOT_SIZE
		var logo := Rect2(r.position + Splash.LOGO_RECT.position * k, Splash.LOGO_RECT.size * k)
		t.ok(Rect2(Vector2.ZERO, screen).encloses(logo), "%dx%d logo trong màn: %s" % [screen.x, screen.y, logo])


func test_boot_splash_image_matches_art(t: T) -> void:
	t.ok(_mode() in SUPPORTED_MODES, "stretch_mode boot splash là mode màn loading vẽ theo được: %d" % _mode())
	# Width and height of the PNG's IHDR (big-endian, bytes 16..23); the image is not imported as a texture.
	var png := FileAccess.get_file_as_bytes(str(ProjectSettings.get_setting("application/boot_splash/image")))
	t.ok(png.size() > 24, "đọc được ảnh boot splash")
	if png.size() > 24:
		var w := (png[16] << 24) | (png[17] << 16) | (png[18] << 8) | png[19]
		var h := (png[20] << 24) | (png[21] << 16) | (png[22] << 8) | png[23]
		t.eq(Vector2(w, h), Splash.BOOT_SIZE, "cỡ ảnh boot splash")
	t.eq((load(Splash.BG_TEX) as Texture2D).get_size(), Splash.BOOT_SIZE, "cỡ ảnh nền loading như boot splash")
	var logo := load(Splash.LOGO_TEX) as Texture2D
	var lr: Vector2 = Splash.LOGO_RECT.size
	t.near(lr.x / lr.y, float(logo.get_width()) / logo.get_height(), 0.002, "LOGO_RECT cùng tỉ lệ ảnh logo")
