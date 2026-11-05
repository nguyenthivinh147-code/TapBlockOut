extends SceneTree
## Picks the import compression of PNG textures under assets/ to shrink the exported game. A texture of at least
## LOSSY_MIN_PIXELS (counted after process/size_limit) gets WebP lossy (compress/mode=1, compress/lossy_quality=
## LOSSY_QUALITY) when that saves at least LOSSY_MIN_SAVING against lossless; flat art (patterns, plain frames) and
## smaller icons stay lossless, where lossy saves little and softens edges. VRAM-compressed textures are left alone.
## Run: tools/godot.sh --headless --path . -s res://tools/compress_textures.gd [-- --check]
## then let the open editor reimport on focus, or run --import when it is closed. --check changes nothing and exits 1
## when some .import is not set yet.

const SCAN_DIR := "res://assets"
const LOSSY_MIN_PIXELS := 256 * 256
const LOSSY_QUALITY := 0.9
const LOSSY_MIN_SAVING := 0.25


func _initialize() -> void:
	var check := OS.get_cmdline_user_args().has("--check")
	var lossy := 0
	var lossless := 0
	var small := 0
	var pending: Array[String] = []
	for png: String in _pngs(SCAN_DIR, []):
		var imp := png + ".import"
		var old := FileAccess.get_file_as_string(imp) if FileAccess.file_exists(imp) else ""
		if old != "" and not old.contains("importer=\"texture\""):
			continue
		if int(_param(old, "compress/mode", "0")) >= 2:
			continue
		var img := Image.load_from_file(ProjectSettings.globalize_path(png))
		if img == null:
			push_warning("compress_textures: cannot read %s" % png)
			continue
		_apply_size_limit(img, int(_param(old, "process/size_limit", "0")))
		if img.get_width() * img.get_height() < LOSSY_MIN_PIXELS:
			small += 1
			continue
		var lossy_size := img.save_webp_to_buffer(true, LOSSY_QUALITY).size()
		var lossless_size := img.save_webp_to_buffer(false).size()
		var want_lossy := lossy_size <= lossless_size * (1.0 - LOSSY_MIN_SAVING)
		if want_lossy:
			lossy += 1
		else:
			lossless += 1
		var next := _with_mode(old if old != "" else _new_import(), want_lossy)
		if next == old:
			continue
		pending.append(png)
		if not check:
			var f := FileAccess.open(imp, FileAccess.WRITE)
			f.store_string(next)
			f.close()
	for png: String in pending:
		print(("not set: " if check else "changed: ") + png)
	print("%d lossy, %d lossless (lossy saves < %d%%), %d small kept, %d %s" % [
		lossy, lossless, roundi(LOSSY_MIN_SAVING * 100), small, pending.size(), "to change" if check else "changed"])
	quit(1 if check and not pending.is_empty() else 0)


func _pngs(dir: String, out: Array[String]) -> Array[String]:
	if FileAccess.file_exists(dir.path_join(".gdignore")):
		return out
	for d in DirAccess.get_directories_at(dir):
		_pngs(dir.path_join(d), out)
	for f in DirAccess.get_files_at(dir):
		if f.get_extension().to_lower() == "png":
			out.append(dir.path_join(f))
	return out


## Same downscale as the importer's process/size_limit, so the size test sees what ends up in the game.
func _apply_size_limit(img: Image, limit: int) -> void:
	var m := maxi(img.get_width(), img.get_height())
	if limit <= 0 or m <= limit:
		return
	var s := float(limit) / m
	img.resize(maxi(1, roundi(img.get_width() * s)), maxi(1, roundi(img.get_height() * s)), Image.INTERPOLATE_CUBIC)


func _param(text: String, key: String, fallback: String) -> String:
	var m := RegEx.create_from_string("(?m)^%s=(.*)$" % key.replace("/", "\\/")).search(text)
	return m.get_string(1).strip_edges() if m else fallback


## Sets compress/mode; the lossy quality line is only written for lossy, so a lossless file keeps its own value.
func _with_mode(text: String, lossy: bool) -> String:
	var nl := "\r\n" if text.contains("\r\n") else "\n"
	var mode_re := RegEx.create_from_string("(?m)^compress\\/mode=\\d+")
	var t := text
	var mode_line := "compress/mode=%d" % (1 if lossy else 0)
	if mode_re.search(t):
		t = mode_re.sub(t, mode_line)
	else:
		t = RegEx.create_from_string("(?m)^\\[params\\]\\r?\\n(\\r?\\n)?").sub(t, "$0" + mode_line + nl)
	if not lossy:
		return t
	var q_line := "compress/lossy_quality=%s" % str(LOSSY_QUALITY)
	var q_re := RegEx.create_from_string("(?m)^compress\\/lossy_quality=.*$")
	if q_re.search(t):
		return q_re.sub(t, q_line)
	return mode_re.sub(t, "$0" + nl + q_line)


## Minimal layout as in tools/unity_ui_export.mjs; Godot fills uid and dest paths on import.
func _new_import() -> String:
	return "\n".join(PackedStringArray([
		"[remap]",
		"",
		"importer=\"texture\"",
		"type=\"CompressedTexture2D\"",
		"",
		"[params]",
		"",
		"compress/mode=0",
		"mipmaps/generate=false",
		"process/fix_alpha_border=true",
		"process/premult_alpha=false",
		"process/size_limit=0",
		"detect_3d/compress_to=1",
		"",
	]))
