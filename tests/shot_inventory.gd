extends "res://tests/shot.gd"
## Texture and colour inventory of every screen (docs/UI_THEME_PASTEL.md): for each visible node, the textures it
## draws (atlas region, 9-slice margins, rect on screen, tint), its styleboxes, colours and shader parameters.
## Writes <dest>/<screen>.json and <dest>/<screen>.png. Not part of the test suite (run_all.gd runs test_*.gd only).
## Windowed 886x1920 (inside Xephyr on a 1440p monitor):
## godot --path . --resolution 886x1920 -s res://tests/shot_inventory.gd -- --lang=vi --dest=<abs dir> [--theme=] [--only=a,b]

const EXTRA := [
	"level_l120", "level_l165", "shop_l20", "shop_ads_mid", "offer_special", "weekly_pass_tutorial", "level_booster_dlg",
	"popup_special", "popup_special_end", "popup_weekly_tutorial", "popup_lb_howto", "popup_lb_player",
	"popup_road_trip_win", "road_trip", "popup_leagues_x", "popup_offer_x", "splash_x", "load_transition",
]

var dest := ""
var _seen_names := {}


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dest="):
			dest = a.substr(7).rstrip("/") + "/"
	DirAccess.make_dir_recursive_absolute(dest)
	var names: Array = ALL.duplicate()
	names.append_array(["lives_hub", "lives_full", "home_l1", "home_hard", "home_very_hard", "weekly_pass", "chain_offer",
		"chain_offer_reward", "challenge", "ingame_settings", "ingame_settings_life", "settings_language", "profile_frames",
		"leaderboard", "leaderboard_bubble", "leaderboard_world", "leaderboard_world_rewards", "lb_result", "lb_week",
		"lb_leagues", "level_lb", "win_lb", "level_booster_all"])
	for s in Gallery.SCREENS:
		names.append(s[1])
	names.append_array(EXTRA)
	for name in names:
		if _seen_names.has(name):
			continue
		_seen_names[name] = true
		if not only.is_empty() and not only.has(name):
			continue
		await _shot(name)
	for r in _report:
		print(r)
	quit(0)


func _shot(name: String) -> void:
	var g := _g()
	match name:
		"level_l120", "level_l165":
			await _fresh(int(name.substr(7)))
			await _clear_popups()
			_main.go("level")
			await _settle(3.0)
		"shop_l20":
			await _fresh(20)
			_main.go("shop", {"source": "home"})
			await _settle()
		"shop_ads_mid":
			await _fresh(20)
			_main.go("shop", {"source": "home"})
			await _settle()
			var sr: Node = _main.find_child("ScrollRect", true, false)
			if sr != null:
				sr.call("set_vertical_normalized", 0.45)
			await _settle()
		"offer_special":
			await _fresh(20)
			_main.open_popup("res://scenes/popup_offer.tscn", {"id": "special_pack"})
			await _settle()
		"weekly_pass_tutorial":
			await _fresh(30)
			g.s.weekly.tut_seen = false
			var wp: Node = _main.open_popup("res://scenes/weekly_pass.tscn", {})
			await _settle()
			if wp != null and wp.has_method("start_tutorial"):
				wp.call("start_tutorial")
			await _settle()
		"level_booster_dlg":
			await _fresh(20, 500)
			g.s.inv = {"hint": 0, "move": 1, "smash": 3}
			_main.go("level")
			await _settle()
			_main.current_screen.call("_booster_dialog", "hint")
			await _settle()
		"popup_lb_player":
			await _fresh(80)
			await _clear_popups()
			_main.open_popup("res://scenes/popup_lb_player.tscn", {"view": {"name": "Candy", "avatar": "", "frame": "",
				"flag": "Việt Nam", "league": "gold", "points": 128, "rank": 2417}})
			await _settle()
		"road_trip":
			await _fresh(60)
			_main.open_popup("res://scenes/road_trip.tscn", {})
			await _settle()
		"popup_leagues_x":
			await _fresh(30)
			g.lb_refresh()
			_main.open_popup("res://scenes/popup_leagues.tscn", {"view": g.lb_leagues_view()})
			await _settle()
		"popup_offer_x":
			await _fresh(40)
			_main.open_popup("res://scenes/popup_offer.tscn", {"id": "rescue_pack"})
			await _settle()
		"splash_x":
			await _fresh(10)
			_main.open_popup("res://scenes/splash.tscn", {})
			await _settle(0.3)
		"load_transition":
			await _fresh(10)
			_main.go("level")
			await _settle(0.05)
		_:
			await super._shot(name)
			return
	_save(name)
	print("shot ", name)


func _clear_popups() -> void:
	var layer: Node = _main.get("popup_layer")
	if layer != null:
		for c in layer.get_children():
			c.queue_free()
	await _settle(0.2)


func _save(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null:
		img.save_png("%s%s.png" % [dest, name])
	var rows: Array = []
	_inv(root, rows)
	var f := FileAccess.open("%s%s.json" % [dest, name], FileAccess.WRITE)
	f.store_string(JSON.stringify({"screen": name, "viewport": [root.get_viewport().get_visible_rect().size.x,
		root.get_viewport().get_visible_rect().size.y], "rows": rows}, "\t"))


func _tint(ci: CanvasItem) -> Color:
	var c := ci.self_modulate
	var n: Node = ci
	while n != null:
		if n is CanvasItem:
			c *= (n as CanvasItem).modulate
		n = n.get_parent()
	return c


func _rect(n: Node) -> Array:
	if n is Control:
		var r := (n as Control).get_global_rect()
		return [r.position.x, r.position.y, r.size.x, r.size.y]
	if n is Node2D:
		var p := (n as Node2D).global_position
		return [p.x, p.y, 0, 0]
	return []


func _tex_info(t: Texture2D) -> Dictionary:
	var d := {"cls": t.get_class(), "size": [t.get_width(), t.get_height()]}
	if t is AtlasTexture:
		var at := t as AtlasTexture
		if at.atlas != null:
			d["path"] = at.atlas.resource_path
			d["atlas_size"] = [at.atlas.get_width(), at.atlas.get_height()]
		d["region"] = [at.region.position.x, at.region.position.y, at.region.size.x, at.region.size.y]
	else:
		d["path"] = t.resource_path
	if t is ImageTexture:
		d["generated"] = true
	return d


func _style_info(sb: StyleBox) -> Dictionary:
	var d := {"cls": sb.get_class()}
	if sb is StyleBoxTexture:
		var st := sb as StyleBoxTexture
		if st.texture != null:
			d["tex"] = _tex_info(st.texture)
		d["margins"] = [st.texture_margin_left, st.texture_margin_top, st.texture_margin_right, st.texture_margin_bottom]
		d["region"] = [st.region_rect.position.x, st.region_rect.position.y, st.region_rect.size.x, st.region_rect.size.y]
		d["modulate"] = st.modulate_color.to_html()
	elif sb is StyleBoxFlat:
		var sf := sb as StyleBoxFlat
		d["bg"] = sf.bg_color.to_html()
		d["border"] = sf.border_color.to_html()
		d["border_w"] = sf.border_width_top
		if sf.shadow_size > 0:
			d["shadow"] = sf.shadow_color.to_html()
	return d


func _inv(n: Node, rows: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
		return
	if n is CanvasLayer and not (n as CanvasLayer).visible:
		return
	var row := {}
	for p in n.get_property_list():
		var pn: String = p.name
		if pn == "script" or pn.begins_with("metadata/"):
			continue
		if p.type == TYPE_OBJECT:
			var v: Variant = n.get(pn)
			if v is Texture2D:
				row[pn] = _tex_info(v)
			elif v is StyleBox and not (v is StyleBoxEmpty):
				row[pn] = _style_info(v)
			elif v is ShaderMaterial:
				var sm := v as ShaderMaterial
				var sp := {"shader": sm.shader.resource_path if sm.shader != null else ""}
				if sm.shader != null:
					for u in sm.shader.get_shader_uniform_list():
						var uv: Variant = sm.get_shader_parameter(u.name)
						if uv is Texture2D:
							sp[u.name] = _tex_info(uv)
						elif uv is Color:
							sp[u.name] = (uv as Color).to_html()
				row[pn] = sp
		elif p.type == TYPE_COLOR and (pn == "color" or pn.begins_with("theme_override_colors/")):
			var cv: Variant = n.get(pn)
			if cv is Color:
				row[pn] = (cv as Color).to_html()
	if row.has("tex"):
		var rg: Variant = n.get("region")
		if rg is Rect2 and (rg as Rect2).size != Vector2.ZERO:
			row["u_region"] = [rg.position.x, rg.position.y, rg.size.x, rg.size.y]
		var bd: Variant = n.get("border")
		if bd is Vector4 and bd != Vector4.ZERO:
			row["u_border"] = [bd.x, bd.y, bd.z, bd.w]
	if n is NinePatchRect:
		var np := n as NinePatchRect
		row["patch"] = [np.patch_margin_left, np.patch_margin_top, np.patch_margin_right, np.patch_margin_bottom]
		row["region_rect"] = [np.region_rect.position.x, np.region_rect.position.y, np.region_rect.size.x, np.region_rect.size.y]
	if n is Panel or n is PanelContainer:
		var sb := (n as Control).get_theme_stylebox("panel")
		if sb != null and not (sb is StyleBoxEmpty):
			row["panel_style"] = _style_info(sb)
	var drawn: bool = n.get_script() != null and (n.get_script() as Script).source_code.contains("func _draw(")
	if drawn:
		row["custom_draw"] = true
	if not row.is_empty():
		row["node"] = str(n.get_path())
		row["class"] = n.get_class()
		if n.get_script() != null:
			row["script"] = (n.get_script() as Script).resource_path
		row["rect"] = _rect(n)
		if n is CanvasItem:
			row["tint"] = _tint(n as CanvasItem).to_html()
		rows.append(row)
	for c in n.get_children():
		_inv(c, rows)
