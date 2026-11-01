extends RefCounted
const T := preload("res://tests/t.gd")


func test_arithmetic(t: T) -> void:
	t.eq(1 + 1, 2, "cộng")
	t.near(0.1 + 0.2, 0.3, 0.0001, "số thực")


func test_autoloads(t: T) -> void:
	t.ok(Engine.get_main_loop().root.has_node("Platform"), "Platform")
	t.ok(Engine.get_main_loop().root.has_node("Game"), "Game")
	t.ok(Engine.get_main_loop().root.has_node("Sfx"), "Sfx")


func test_translation_stub(t: T) -> void:
	TranslationServer.set_locale("en")
	t.eq(str(TranslationServer.translate("APP_NAME")), "Tap Block Out", "dịch en")
