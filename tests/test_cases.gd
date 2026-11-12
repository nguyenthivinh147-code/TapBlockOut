extends RefCounted
## Danh sách test case tests/cases/*.csv (docs/TESTING.md "Test case"): đúng 12 cột, ID không trùng và đúng module,
## nhãn, priority, status hợp lệ, ô bắt buộc có chữ, AUTO đúng dạng. Mỗi case AUTO `smoke:<kịch bản>` có trong
## tests/smoke/*.gd, AUTO `unit:<file>` có trong tests/<file>.gd (AUTO `todo:...` là chưa viết, không kiểm); mọi ID nhắc
## trong code test có trong CSV. In bảng bao phủ theo module (dòng CASES).

const T := preload("res://tests/t.gd")
const Cases := preload("res://tests/cases_csv.gd")

const TAGS: Array[String] = ["[HP]", "[NEG]", "[UI]", "[EDGE]"]
const PRIORITIES: Array[String] = ["P0", "P1", "P2"]
const STATUSES: Array[String] = ["Ready", "Pass", "Fail", "Blocked", "N/A"]
const REQUIRED: Array[String] = ["CASE", "PRIORITY", "DESCRIPTIONS", "PRE COND", "STEP", "EXPECTED RESULT", "STATUS",
	"NOTE", "AUTO"]
const AUTO_RE := "^((todo:)?(smoke:[A-Z0-9]+|unit:test_[a-z0-9_]+)|manual:.+)$"
const L12_RE := "^M[0-9]{2}(\\.[0-9]+)?$"
const CODE_ID_RE := "TC_CA_[A-Z0-9]+_[0-9]{3}"


func test_csv_format(t: T) -> void:
	var all := Cases.load_all()
	var seen := {}
	var auto_re := RegEx.create_from_string(AUTO_RE)
	var l12_re := RegEx.create_from_string(L12_RE)
	for file in all:
		var f: Dictionary = all[file]
		var module := str(file).get_basename()
		var l3_re := RegEx.create_from_string("^TC_CA_%s_[0-9]{3}$" % module)
		t.eq(f.header, Cases.COLUMNS, "%s: hàng tiêu đề" % file)
		var count := {"all": 0}
		for row in f.rows:
			var id := str(row.get("ID", ""))
			var at := "%s bản ghi %d (%s)" % [file, int(row.rec), id]
			if int(row.cells) != Cases.COLUMNS.size():
				t.fail("%s: %d ô, cần %d" % [at, int(row.cells), Cases.COLUMNS.size()])
			if seen.has(id):
				t.fail("%s: trùng ID với %s" % [at, seen[id]])
			seen[id] = file
			if l12_re.search(id) != null:
				continue
			if l3_re.search(id) == null:
				t.fail("%s: ID phải là TC_CA_%s_<3 số> (Level 3) hoặc M01, M01.1 (Level 1, 2)" % [at, module])
				continue
			var case_text := str(row.get("CASE", ""))
			var tag := case_text.get_slice(" ", 0)
			if not TAGS.has(tag):
				t.fail("%s: CASE phải bắt đầu bằng một nhãn %s" % [at, " ".join(TAGS)])
			if not PRIORITIES.has(str(row.get("PRIORITY", ""))):
				t.fail("%s: PRIORITY phải là P0, P1 hoặc P2" % at)
			if not STATUSES.has(str(row.get("STATUS", ""))):
				t.fail("%s: STATUS phải là một trong %s" % [at, ", ".join(STATUSES)])
			for col in REQUIRED:
				if str(row.get(col, "")).is_empty():
					t.fail("%s: cột %s trống" % [at, col])
			var auto := str(row.get("AUTO", ""))
			if auto_re.search(auto) == null:
				t.fail("%s: AUTO '%s' phải là smoke:<kịch bản>, unit:test_<file>, todo:<một trong hai> hoặc manual:<lý do>" %
					[at, auto])
			count.all += 1
			var layer := auto.get_slice(":", 0)
			count[layer] = int(count.get(layer, 0)) + 1
			count[tag] = int(count.get(tag, 0)) + 1
		print("CASES %s: %d case; smoke %d, unit %d, todo %d, manual %d; [HP] %d, [NEG] %d, [UI] %d, [EDGE] %d" % [
			module, count.all, count.get("smoke", 0), count.get("unit", 0), count.get("todo", 0), count.get("manual", 0),
			count.get("[HP]", 0), count.get("[NEG]", 0), count.get("[UI]", 0), count.get("[EDGE]", 0)])


func test_cases_in_code(t: T) -> void:
	var all := Cases.load_all()
	var smoke_text := _read_dir("res://tests/smoke")
	var known := {}
	for file in all:
		for row in all[file].rows:
			var id := str(row.get("ID", ""))
			known[id] = true
			var auto := str(row.get("AUTO", ""))
			if auto.begins_with("smoke:") and not smoke_text.contains("\"%s\"" % id):
				t.fail("%s %s: AUTO %s mà tests/smoke/*.gd chưa chấm (r.tc, r.tc_look hoặc r.tc_blocked với \"%s\")" %
					[file, id, auto, id])
			elif auto.begins_with("unit:"):
				var path := "res://tests/%s.gd" % auto.get_slice(":", 1)
				if not FileAccess.file_exists(path):
					t.fail("%s %s: AUTO %s mà không có %s" % [file, id, auto, path])
				elif not FileAccess.get_file_as_string(path).contains(id):
					t.fail("%s %s: AUTO %s mà %s không nhắc ID (ghi ID trong comment hoặc thông báo của assert)" %
						[file, id, auto, path])
	var id_re := RegEx.create_from_string(CODE_ID_RE)
	var code := {"res://tests/smoke": smoke_text, "res://tests": _read_dir("res://tests")}
	for where in code:
		for m in id_re.search_all(code[where]):
			if not known.has(m.get_string()):
				t.fail("%s nhắc %s nhưng tests/cases/*.csv không có case này" % [where, m.get_string()])


## Nối mọi file .gd trực tiếp trong `dir` (không đệ quy).
static func _read_dir(dir: String) -> String:
	var text := ""
	var d := DirAccess.open(dir)
	if d == null:
		return text
	for f in d.get_files():
		if f.get_extension() == "gd":
			text += FileAccess.get_file_as_string(dir.path_join(f)) + "\n"
	return text
