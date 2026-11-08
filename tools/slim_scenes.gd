extends SceneTree
## Slims saved scenes in place, without baking them again (editor edits stay): every metadata/u and metadata/u_txt
## value keeps only what runtime reads (UnityUI.slim_spec, UnityUI.TXT_KEEP), and StyleBoxEmpty sub-resources with
## the same properties become one. It edits the scene text, so uids, unique_ids, overrides and order stay as they are.
## Running it again changes nothing. The bake tools save slim scenes already (UnityUI.slim); this is for scenes saved
## before that, or edited by hand. Run with the editor closed, it rewrites scenes the editor may hold:
## tools/godot.sh --headless --path . -s res://tools/slim_scenes.gd [-- res://scenes/<name>.tscn ...]

const UnityUI := preload("res://src/ui/unity_ui.gd")

const ROOT := "res://scenes"
const METAS := {"metadata/u = ": "u", "metadata/u_txt = ": "u_txt"}
const BOX_HEAD := "[sub_resource type=\"StyleBoxEmpty\" "


func _initialize() -> void:
	var files: Array[String] = []
	for a in OS.get_cmdline_user_args():
		files.append(a)
	if files.is_empty():
		scenes(ROOT, files)
	var changed := 0
	var before := 0
	var after := 0
	for p in files:
		var text := FileAccess.get_file_as_string(p)
		var out := slim_text(text)
		before += text.length()
		after += out.length()
		if out == text:
			continue
		var f := FileAccess.open(p, FileAccess.WRITE)
		if f == null:
			push_error("slim_scenes: không ghi được %s" % p)
			quit(1)
			return
		f.store_string(out)
		f.close()
		changed += 1
		print("  ", p)
	print("slim_scenes: %d/%d scene đổi, %d KB -> %d KB" % [changed, files.size(), before / 1024, after / 1024])
	quit()


## Every .tscn under dir.
static func scenes(dir: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".tscn"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		scenes(dir.path_join(d), out)


## Scene text with slim metas and one StyleBoxEmpty per distinct body.
static func slim_text(text: String) -> String:
	return _merge_boxes(_slim_metas(text))


static func _slim_metas(text: String) -> String:
	var parts: PackedStringArray = []
	var at := 0
	while true:
		var hit := -1
		var key := ""
		for k in METAS:
			var i := text.find("\n" + k, at)
			if i >= 0 and (hit < 0 or i < hit):
				hit = i
				key = k
		if hit < 0:
			break
		var from := hit + 1 + key.length()
		var to := _value_end(text, from)
		var v: Variant = str_to_var(text.substr(from, to - from))
		parts.append(text.substr(at, from - at))
		if v is Dictionary:
			var slim: Dictionary = UnityUI.slim_spec(v) if METAS[key] == "u" else UnityUI.slim_txt(v)
			parts.append(var_to_str(slim))
		else:
			parts.append(text.substr(from, to - from))
		at = to
	parts.append(text.substr(at))
	return "".join(parts)


## End of the property value starting at from: past its matching bracket, or the end of the line.
static func _value_end(s: String, from: int) -> int:
	var open := s.unicode_at(from) if from < s.length() else 0
	if open != 123 and open != 91:  # { [
		var nl := s.find("\n", from)
		return s.length() if nl < 0 else nl
	var depth := 0
	var in_str := false
	var i := from
	var n := s.length()
	while i < n:
		var c := s.unicode_at(i)
		if in_str:
			if c == 92:  # backslash
				i += 1
			elif c == 34:
				in_str = false
		elif c == 34:
			in_str = true
		elif c == 123 or c == 91 or c == 40:  # { [ (
			depth += 1
		elif c == 125 or c == 93 or c == 41:  # } ] )
			depth -= 1
			if depth == 0:
				return i + 1
		i += 1
	return n


## Godot saves one sub-resource per box object; equal boxes (same property lines) become the first of them.
static func _merge_boxes(text: String) -> String:
	var lines := text.split("\n")
	var first := {}
	var alias := {}
	var out: PackedStringArray = []
	var i := 0
	while i < lines.size():
		var line := lines[i]
		if line.begins_with(BOX_HEAD):
			var id := line.get_slice("id=\"", 1).get_slice("\"", 0)
			var j := i + 1
			var body: PackedStringArray = []
			while j < lines.size() and lines[j] != "" and not lines[j].begins_with("["):
				body.append(lines[j])
				j += 1
			var k := "\n".join(body)
			if first.has(k):
				alias[id] = first[k]
				# The block and the blank line after it.
				i = j + 1 if j < lines.size() and lines[j] == "" else j
				continue
			first[k] = id
		out.append(line)
		i += 1
	var res := "\n".join(out)
	if alias.is_empty():
		return res
	var re := RegEx.create_from_string("SubResource\\(\"([^\"]+)\"\\)")
	var parts: PackedStringArray = []
	var at := 0
	for m in re.search_all(res):
		var id := m.get_string(1)
		if not alias.has(id):
			continue
		parts.append(res.substr(at, m.get_start() - at))
		parts.append("SubResource(\"%s\")" % alias[id])
		at = m.get_end()
	parts.append(res.substr(at))
	return "".join(parts)
