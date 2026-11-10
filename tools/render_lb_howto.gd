extends SceneTree
## Renders the three step pictures of the Leaderboard "How it works" popup (popup_lb_howto.gd, lb_howto_1..3) from
## the game's own art, so each picture shows what the player meets in the game:
##   lb_howto_1.png: a board tray drawn by BoardView (candy blocks and one crystal block), the rank piece (lb_piece)
##     bursting out of the crystal block, as CrystalFly does in a level.
##   lb_howto_2.png: the rank piece with "+1": every piece is one rank point.
##   lb_howto_3.png: the Silver trophy, the Gold trophy above it with up chevrons, and the Gold league reward of the
##     League Up popup (gold coin, Hint booster).
## Drawn at RENDER px on a transparent SubViewport, downscaled to OUT_PX, alpha un-premultiplied, saved as PNG.
## Run windowed (headless draws nothing), editor closed or rescan after:
##   tools/godot.sh --path . -s res://tools/render_lb_howto.gd [-- --out=res://assets/ui] [--only=1,3]

const BoardState := preload("res://src/core/board_state.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")
const Config := preload("res://src/config.gd")

const RENDER := 1024
const OUT_PX := 512
## Board pass: the viewport is BOARD_SCREEN times this, so BoardView draws cells of BOARD_CELL_MAX times this.
const BOARD_SCALE := 2.0
## art/ has .gdignore: read sources with Image.load_from_file.
const PIECE_SRC := "res://art/images/lb_piece_cube.png"
const TROPHY_SILVER := "res://assets/ui/cc/ic_Silver.png"
const TROPHY_GOLD := "res://assets/ui/cc/ic_Gold.png"
const COIN_SPRITE := "Resources_moved_UI_Maincenter:UI_Maincenter_3"
const HINT_ICON := "res://assets/ui/booster_hint.png"
## Tray of step 1: 4 x 2 cells, crystal block "c" (a 2-cell blue block marked special, as Game.attempt.specials) on
## the top row so the light up to the piece crosses no other block.
const TRAY_BLOCKS := [
	{"id": "g", "color": "green", "cells": [[0, 0]]},
	{"id": "c", "color": "blue", "cells": [[1, 0], [2, 0]]},
	{"id": "p", "color": "purple", "cells": [[3, 0], [3, 1]]},
	{"id": "y", "color": "yellow", "cells": [[0, 1], [1, 1]]},
	{"id": "b", "color": "blue", "cells": [[2, 1]]},
]
const TRAY_SPECIAL := "c"
## Text of "+1": white face, the dark brown outline of the game's titles (TMP txtHeader).
const INK := Color(0.2235, 0.0667, 0.0039)
const GLOW_ICE := Color(0.55, 0.9, 1.0, 0.6)
const GLOW_GOLD := Color(1.0, 0.86, 0.4, 0.6)
const CHEVRON := Color("6DED1E")
const CHEVRON_DARK := Color("2F7A12")
const CHEVRON_LIGHT := Color("D4FFA8")

var out_dir := "res://assets/ui"
var only: Array = ["1", "2", "3"]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a.begins_with("--only="):
			only = Array(a.substr(7).split(","))
	if DisplayServer.get_name() == "headless":
		push_error("render_lb_howto.gd draws nothing headless: run it windowed")
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	var ok := true
	for n in only:
		var root_c := Control.new()
		root_c.size = Vector2(RENDER, RENDER)
		match str(n):
			"1":
				await _step_crystal(root_c)
			"2":
				_step_points(root_c)
			"3":
				_step_league(root_c)
			_:
				push_error("unknown step " + str(n))
				ok = false
				continue
		var img := await _capture(root_c, Vector2i(RENDER, RENDER))
		img.resize(OUT_PX, OUT_PX, Image.INTERPOLATE_LANCZOS)
		_demultiply(img)
		var path := out_dir.path_join("lb_howto_%s.png" % n)
		var err := img.save_png(ProjectSettings.globalize_path(path))
		print("saved ", path, " " if err == OK else " FAILED ", err)
		ok = ok and err == OK
	quit(0 if ok else 1)


# --- steps ---

## Crystal block in a board tray, the rank piece bursting out of it.
func _step_crystal(c: Control) -> void:
	var board := await _render_board()
	var tray_tex: Texture2D = board.tex
	var cell: float = board.cell
	_glow(c, Vector2(540, 560), 500.0, GLOW_ICE)
	# Tray: the board's own colour under the blocks, rounded, a white rim and a soft drop shadow.
	var pad := 0.22 * cell
	var margin: float = board.margin
	var tray_size := Vector2(tray_tex.get_width(), tray_tex.get_height()) - Vector2(margin, margin) * 2.0 + Vector2(pad, pad) * 2.0
	var tray_pos := Vector2(RENDER - 40.0 - tray_size.x, 940.0 - tray_size.y)
	var tray := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = ThemeKit.BOARD_BG
	sb.set_corner_radius_all(int(0.42 * cell))
	sb.set_border_width_all(int(0.07 * cell))
	sb.border_color = Color(1, 1, 1, 0.95)
	sb.shadow_color = Color(0.25, 0.05, 0.2, 0.35)
	sb.shadow_size = int(0.16 * cell)
	sb.shadow_offset = Vector2(0, 0.1 * cell)
	sb.anti_aliasing = true
	tray.add_theme_stylebox_override("panel", sb)
	tray.position = tray_pos
	tray.size = tray_size
	c.add_child(tray)
	var blocks := TextureRect.new()
	blocks.texture = tray_tex
	blocks.position = tray_pos + Vector2(pad, pad) - Vector2(margin, margin)
	blocks.size = Vector2(tray_tex.get_width(), tray_tex.get_height())
	c.add_child(blocks)
	var crystal_at: Vector2 = blocks.position + board.special_center
	# Light from the crystal block up to the piece, under the piece.
	var piece_at := Vector2(270, 285)
	var piece_px := 440.0
	_beam(c, crystal_at, piece_at, cell * 1.2, piece_px * 0.6, Color(0.8, 0.96, 1.0, 0.6), Color(1, 1, 1, 0.1))
	_glow(c, crystal_at, cell * 1.3, Color(1, 1, 1, 0.5))
	# Glass bits flung off the crystal block.
	for b in [[Vector2(-1.05, -0.75), 0.3, 0.3], [Vector2(1.0, -0.85), 0.24, -0.5], [Vector2(0.35, -1.35), 0.2, 0.9]]:
		_shard(c, crystal_at + (b[0] as Vector2) * cell, float(b[1]) * cell, float(b[2]))
	_glow(c, piece_at, piece_px * 0.62, Color(1, 1, 1, 0.5))
	_pic(c, _tex_file(PIECE_SRC, piece_px), piece_at, piece_px, deg_to_rad(-8.0))
	for s in [[Vector2(105, 110), 100.0], [Vector2(530, 150), 80.0], [Vector2(90, 520), 64.0], [Vector2(900, 330), 72.0],
			[Vector2(190, 860), 56.0]]:
		_sparkle(c, s[0], float(s[1]), Color(0.7, 0.93, 1.0))


## The rank piece and "+1".
func _step_points(c: Control) -> void:
	_glow(c, Vector2(512, 500), 500.0, GLOW_GOLD)
	var piece_at := Vector2(430, 430)
	var piece_px := 600.0
	_glow(c, piece_at, piece_px * 0.6, Color(1, 1, 1, 0.45))
	_pic(c, _tex_file(PIECE_SRC, piece_px), piece_at, piece_px, deg_to_rad(-7.0))
	_text(c, "+1", Vector2(735, 755), 300, deg_to_rad(-6.0))
	for s in [[Vector2(120, 140), 104.0], [Vector2(810, 190), 88.0], [Vector2(140, 770), 70.0], [Vector2(915, 470), 60.0],
			[Vector2(470, 905), 52.0]]:
		_sparkle(c, s[0], float(s[1]), Color(1.0, 0.92, 0.6))


## Silver trophy, Gold trophy above it with up chevrons, the Gold league reward.
func _step_league(c: Control) -> void:
	# Kept above ~83% of the height: the step's caption overlaps the bottom of the picture.
	_glow(c, Vector2(560, 480), 500.0, GLOW_GOLD)
	_pic(c, _tex_file(TROPHY_SILVER, 430.0), Vector2(250, 600), 430.0, 0.0, Color(0.9, 0.9, 0.95))
	var gold_at := Vector2(605, 480)
	_glow(c, gold_at + Vector2(0, -20), 300.0, Color(1, 1, 1, 0.5))
	_pic(c, _tex_file(TROPHY_GOLD, 640.0), gold_at, 640.0)
	_chevron(c, Vector2(605, 268), 210.0, 95.0, 46.0)
	_chevron(c, Vector2(605, 163), 210.0, 95.0, 46.0)
	_pic(c, _tex_sprite(COIN_SPRITE, 240.0), Vector2(765, 760), 240.0, deg_to_rad(-8.0))
	_pic(c, _tex_file(HINT_ICON, 190.0), Vector2(910, 660), 190.0, deg_to_rad(14.0))
	for s in [[Vector2(370, 170), 92.0], [Vector2(880, 220), 78.0], [Vector2(100, 330), 64.0], [Vector2(470, 830), 54.0]]:
		_sparkle(c, s[0], float(s[1]), Color(1.0, 0.92, 0.6))


# --- board pass ---

## Draws TRAY_BLOCKS with BoardView (crystal material on TRAY_SPECIAL), without the frame and board panel.
## {tex: blocks cropped to the shape plus `margin` px each side, cell, margin, special_center (px in tex)}.
func _render_board() -> Dictionary:
	var level := {"id": 0, "w": 4, "h": 2, "hard": false, "min_taps": 0, "moves": 20, "seed": 0, "stones": [],
		"pulse_sides": [], "blocks": []}
	for b in TRAY_BLOCKS:
		var d: Dictionary = (b as Dictionary).duplicate(true)
		d.merge({"ice": 0, "chained_by": "", "inner_color": "", "fog": false})
		(level.blocks as Array).append(d)
	var vp_size := Vector2i(Config.BOARD_SCREEN * BOARD_SCALE)
	var bv: Control = (load("res://scenes/board_view.tscn") as PackedScene).instantiate()
	var holder := Control.new()
	holder.size = Vector2(vp_size)
	holder.add_child(bv)
	var vp := _viewport(holder, vp_size)
	bv.call("setup", BoardState.new(level), Vector2(vp_size))
	bv.call("set_specials", [TRAY_SPECIAL])
	bv.input_enabled = false
	bv.get_node("Frame").visible = false
	bv.self_modulate.a = 0.0  # board panel (BoardView._draw); blocks and shadows are children
	await _frames(6)
	var img := vp.get_texture().get_image()
	vp.queue_free()
	var cell: float = bv.call("cell_size")
	var rect: Rect2 = bv.call("content_rect")
	var margin := ceilf(0.3 * cell)
	var crop := Rect2i(rect.grow(margin))
	var cut := img.get_region(crop)
	_demultiply(cut)
	var node: Control = bv.call("block_node", TRAY_SPECIAL)
	var center := node.position + node.size * 0.5 - Vector2(crop.position)
	return {"tex": ImageTexture.create_from_image(cut), "cell": cell, "margin": margin, "special_center": center}


# --- pieces ---

func _viewport(content: Control, px: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = px
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.add_child(content)
	root.add_child(vp)
	return vp


func _capture(content: Control, px: Vector2i) -> Image:
	var vp := _viewport(content, px)
	await _frames(4)
	var img := vp.get_texture().get_image()
	vp.queue_free()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _frames(n: int) -> void:
	for i in n:
		await process_frame
	await RenderingServer.frame_post_draw


## The canvas blends into a transparent target premultiplied (rgb * a); PNG wants straight alpha.
func _demultiply(img: Image) -> void:
	img.convert(Image.FORMAT_RGBA8)
	var d := img.get_data()
	for i in range(0, d.size(), 4):
		var a := d[i + 3]
		if a == 0 or a == 255:
			continue
		d[i] = mini(255, roundi(d[i] * 255.0 / a))
		d[i + 1] = mini(255, roundi(d[i + 1] * 255.0 / a))
		d[i + 2] = mini(255, roundi(d[i + 2] * 255.0 / a))
	img.set_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, d)


## Source PNG scaled once to `px` (longest side) with Lanczos, so the canvas does not minify it without mipmaps.
func _tex_file(path: String, px: float) -> Texture2D:
	return _fit(Image.load_from_file(ProjectSettings.globalize_path(path)), px)


## Unity sprite (atlas region) scaled to `px`.
func _tex_sprite(key: String, px: float) -> Texture2D:
	var sp := UnityUI.sprite_info(key)
	var tex: Texture2D = sp.tex
	var img := Image.load_from_file(ProjectSettings.globalize_path(tex.resource_path))
	var k := float(img.get_width()) / float(tex.get_width())
	var r: Rect2 = sp.region
	return _fit(img.get_region(Rect2i(Rect2(r.position * k, r.size * k))), px)


func _fit(img: Image, px: float) -> Texture2D:
	img.convert(Image.FORMAT_RGBA8)
	var s := px / float(maxi(img.get_width(), img.get_height()))
	img.premultiply_alpha()
	img.resize(maxi(1, roundi(img.get_width() * s)), maxi(1, roundi(img.get_height() * s)), Image.INTERPOLATE_LANCZOS)
	_demultiply(img)
	return ImageTexture.create_from_image(img)


func _pic(parent: Control, tex: Texture2D, center: Vector2, px: float, rot: float = 0.0,
		mod: Color = Color.WHITE) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size = Vector2(px, px)
	r.position = center - r.size * 0.5
	r.pivot_offset = r.size * 0.5
	r.rotation = rot
	r.modulate = mod
	parent.add_child(r)
	return r


## Soft round light: `col` at the centre fading to nothing at `radius`.
func _glow(parent: Control, center: Vector2, radius: float, col: Color) -> void:
	var g := Gradient.new()
	g.set_color(0, col)
	g.set_color(1, Color(col, 0.0))
	g.add_point(0.45, Color(col, col.a * 0.45))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	var r := TextureRect.new()
	r.texture = gt
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.size = Vector2(radius, radius) * 2.0
	r.position = center - Vector2(radius, radius)
	parent.add_child(r)


## Tapered light from `a` (width wa) to `b` (width wb).
func _beam(parent: Control, a: Vector2, b: Vector2, wa: float, wb: float, ca: Color, cb: Color) -> void:
	var n := (b - a).normalized().orthogonal()
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([a + n * wa * 0.5, b + n * wb * 0.5, b - n * wb * 0.5, a - n * wa * 0.5])
	p.vertex_colors = PackedColorArray([ca, cb, cb, ca])
	p.antialiased = true
	parent.add_child(p)


## Four-point twinkle (super-ellipse star) over a small halo of `tint`, like the game's sparkles.
func _sparkle(parent: Control, at: Vector2, px: float, tint: Color) -> void:
	_glow(parent, at, px * 0.55, Color(tint, 0.8))
	var pts := PackedVector2Array()
	var steps := 64
	for i in steps:
		var t := TAU * float(i) / float(steps)
		var cx := cos(t)
		var sy := sin(t)
		pts.append(Vector2(signf(cx) * pow(absf(cx), 2.7), signf(sy) * pow(absf(sy), 2.7)) * px * 0.5)
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = Color(1, 1, 1, 1)
	p.position = at
	p.antialiased = true
	parent.add_child(p)


## Glass bit flung off the crystal block: a pale ice diamond with a white edge.
func _shard(parent: Control, at: Vector2, px: float, rot: float) -> void:
	var pts := PackedVector2Array([Vector2(0, -0.5), Vector2(0.32, -0.05), Vector2(0.05, 0.5), Vector2(-0.3, 0.1)])
	for i in pts.size():
		pts[i] *= px
	var p := Polygon2D.new()
	p.polygon = pts
	p.vertex_colors = PackedColorArray([Color(1, 1, 1, 0.95), Color(0.7, 0.92, 1.0, 0.9), Color(0.35, 0.72, 1.0, 0.85),
		Color(0.85, 0.75, 1.0, 0.9)])
	p.position = at
	p.rotation = rot
	p.antialiased = true
	parent.add_child(p)
	var edge := Line2D.new()
	edge.points = pts
	edge.closed = true
	edge.width = maxf(2.0, px * 0.06)
	edge.default_color = Color(1, 1, 1, 0.9)
	edge.position = at
	edge.rotation = rot
	edge.antialiased = true
	parent.add_child(edge)


## Up chevron of rounded candy stroke: dark outline, lime body, light streak on top.
func _chevron(parent: Control, center: Vector2, w: float, h: float, thick: float) -> void:
	var pts := PackedVector2Array([Vector2(-w * 0.5, h * 0.5), Vector2(0, -h * 0.5), Vector2(w * 0.5, h * 0.5)])
	for spec in [[thick + 16.0, CHEVRON_DARK, Vector2(0, 6)], [thick, CHEVRON, Vector2.ZERO],
			[thick * 0.28, CHEVRON_LIGHT, Vector2(0, -thick * 0.2)]]:
		var l := Line2D.new()
		var scaled := PackedVector2Array()
		var k := 1.0 if float(spec[0]) >= thick else 0.82
		for q in pts:
			scaled.append(q * k)
		l.points = scaled
		l.width = float(spec[0])
		l.default_color = spec[1]
		l.joint_mode = Line2D.LINE_JOINT_ROUND
		l.begin_cap_mode = Line2D.LINE_CAP_ROUND
		l.end_cap_mode = Line2D.LINE_CAP_ROUND
		l.antialiased = true
		l.position = center + (spec[2] as Vector2)
		parent.add_child(l)


## Number in the game font: white face, thick dark brown outline and a drop under it.
func _text(parent: Control, s: String, center: Vector2, font_px: int, rot: float) -> void:
	var ls := LabelSettings.new()
	ls.font = ThemeKit.FONT
	ls.font_size = font_px
	ls.font_color = Color.WHITE
	ls.outline_size = int(font_px * 0.16)
	ls.outline_color = INK
	ls.shadow_color = Color(INK, 0.85)
	ls.shadow_size = int(font_px * 0.16)
	ls.shadow_offset = Vector2(0, font_px * 0.06)
	var l := Label.new()
	l.text = s
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(font_px * 2.0, font_px * 1.4)
	l.position = center - l.size * 0.5
	l.pivot_offset = l.size * 0.5
	l.rotation = rot
	parent.add_child(l)
