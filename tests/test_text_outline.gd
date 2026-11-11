extends RefCounted
## Text outline and drop shadow are plum, never black: ThemeKit tokens, the prefab TMP materials whose stroke was
## black or near black (names kept, plum colours) and every baked scene. Exception: text on gray buttons keeps the
## black stroke of "Baloo Outline - Gray".
const T := preload("res://tests/t.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")
const MockIap := preload("res://src/platform/mock_iap.gd")

const DIR := "user://test_text_outline"
const BLACK := "Color(0, 0, 0, 1)"
## Prefab TMP materials that had a black or near-black stroke, and those stroke colours.
const PLUM_MATERIALS := ["Baloo Outline - Black", "Baloo Outline - Blue 1", "Baloo Outline - BlueLose",
	"Baloo Outline - DarkBlue"]
const OLD_STROKES := ["000000", "0a1834", "071019", "00032b"]
## Stroke and underlay of "Baloo Outline - Gray" (prefab colour), the text material of gray buttons.
const GRAY_STROKE := Color("0c1011")


func test_tokens_plum(t: T) -> void:
	t.ok(ThemeKit.TEXT_OUTLINE.is_equal_approx(ThemeKit.RIBBON_STROKE), "TEXT_OUTLINE mận: %s" % ThemeKit.TEXT_OUTLINE)
	t.ok(ThemeKit.UNDERLAY.is_equal_approx(ThemeKit.RIBBON_STROKE), "UNDERLAY mận: %s" % ThemeKit.UNDERLAY)
	var l := ThemeKit.make_label("A")
	t.ok(l.get_theme_color("font_outline_color").is_equal_approx(ThemeKit.TEXT_OUTLINE), "make_label viền mận")
	t.ok(l.get_theme_color("font_shadow_color").is_equal_approx(ThemeKit.UNDERLAY), "make_label bóng mận")
	l.free()
	var th := ThemeKit.make_theme()
	t.ok(th.get_color("font_outline_color", "Label").is_equal_approx(ThemeKit.TEXT_OUTLINE), "theme Label viền mận")
	t.ok(th.get_color("font_shadow_color", "Label").is_equal_approx(ThemeKit.UNDERLAY), "theme Label bóng mận")


func test_tmp_materials_plum(t: T) -> void:
	for mat in PLUM_MATERIALS:
		var m := UnityUI.text_material(mat, false)
		var ol: Color = m.get_shader_parameter("outline_color")
		var ul: Color = m.get_shader_parameter("underlay_color")
		t.ok(ol.is_equal_approx(ThemeKit.TEXT_OUTLINE), "%s viền mận: %s" % [mat, ol])
		t.ok(ul.is_equal_approx(ThemeKit.UNDERLAY), "%s bóng mận: %s" % [mat, ul])


func test_gray_buttons_black(t: T) -> void:
	var m := UnityUI.text_material("Baloo Outline - Gray", false)
	t.ok((m.get_shader_parameter("outline_color") as Color).is_equal_approx(GRAY_STROKE), "nút xám viền đen")
	t.ok((m.get_shader_parameter("underlay_color") as Color).is_equal_approx(GRAY_STROKE), "nút xám bóng đen")
	# Chain Offer: a claimed pack shows Button_Claim, the gray pill, whose prefab text uses "Baloo Outline - Black".
	var root := (Engine.get_main_loop() as SceneTree).root
	var g: Node = root.get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	g.test_tz = 0
	g.test_now = 1699833600
	g.s.level = 24
	root.get_node("Platform").iap = MockIap.new()
	g.s.chain = {"active": true, "id": "chain_a", "step": 1, "expires": g.test_now + 86400, "cooldown_until": 0,
		"shown": true, "rotation": 1}
	var node := (load("res://scenes/chain_offer.tscn") as PackedScene).instantiate() as Control
	root.add_child(node)
	node.setup({})
	t.eq(node.node_states[0], "claimed", "gói 1 đã nhận")
	var l: Label = node.ui.label("Panel/Content/ListPack/ChainOfferPack/Button_Claim/ComboText/Text (TMP)")
	var ol: Color = (l.material as ShaderMaterial).get_shader_parameter("outline_color")
	t.ok(ol.is_equal_approx(GRAY_STROKE), "chữ nút Đã nhận (xám) viền đen: %s" % ol)
	node.queue_free()


## Baked scenes keep the colours they were saved with; a token or material change must reach them too.
func test_baked_scenes_no_black_outline(t: T) -> void:
	var stale: Array[String] = []
	for f in _scene_files("res://scenes"):
		var text := FileAccess.get_file_as_string(f)
		for key in ["font_outline_color", "font_shadow_color"]:
			if text.contains("%s = %s" % [key, BLACK]):
				stale.append("%s %s" % [f, key])
		# A TMP material draws its outline only when outline_half > 0, its underlay only when underlay_on.
		for block in text.split("\n["):
			if not block.begins_with("sub_resource type=\"ShaderMaterial\""):
				continue
			var outlined := _old_stroke(block, "outline_color") and not block.contains("shader_parameter/outline_half = 0.0\n")
			var shadowed := _old_stroke(block, "underlay_color") and block.contains("shader_parameter/underlay_on = true")
			if outlined or shadowed:
				stale.append("%s %s" % [f, block.get_slice("\n", 0)])
	t.eq(stale, [] as Array[String], "không scene nào còn viền hoặc bóng chữ đen")


func _old_stroke(block: String, param: String) -> bool:
	var key := "shader_parameter/%s = " % param
	var i := block.find(key)
	if i < 0:
		return false
	var c: Variant = str_to_var(block.substr(i + key.length()).get_slice("\n", 0))
	return c is Color and (c as Color).a > 0.0 and OLD_STROKES.has((c as Color).to_html(false))


func _scene_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".tscn"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scene_files(dir.path_join(d)))
	return out
