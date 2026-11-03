extends SceneTree
const ThemeKit := preload("res://src/ui/theme_kit.gd")
func _initialize() -> void:
	for n in ["booster_hint", "booster_move", "booster_smash", "ui_gold"]:
		print(n, " -> ", ThemeKit._icon_path(n))
	quit(0)
