extends RefCounted
## Kiểm i18n/strings.csv đọc thẳng từ file (không phụ thuộc .translation đã import).
const T := preload("res://tests/t.gd")
const Config := preload("res://src/config.gd")

const CSV_PATH := "res://i18n/strings.csv"
const GROUPS: Array[String] = [
	"common_", "home_", "level_", "rescue_", "win_", "lose_", "no_lives_",
	"shop_", "daily_", "profile_", "settings_", "offer_", "ads_", "tut_", "mech_",
	"notif_", "booster_", "challenge_", "feature_", "weekly_", "chain_",
]
const REQUIRED: Array[String] = [
	"APP_NAME", "home_play", "home_challenge_locked", "home_coming_soon",
	"level_remaining", "level_remaining_one", "rescue_remaining", "rescue_warn_life",
	"rescue_confirm_title", "rescue_confirm_yes", "tut_tap", "win_x2", "win_x2_free", "lose_retry",
	"no_lives_title", "shop_title", "daily_title", "profile_title", "settings_title",
	"booster_hint", "booster_move", "booster_smash", "ads_not_available",
]
const MECHS: Array[String] = ["stone", "ice", "chain", "layer", "fog", "pulse"]
const BOOSTERS: Array[String] = ["hint", "move", "smash"]
const NOTIF_KINDS: Array[String] = ["daily_gift", "lives_full", "offer_open", "challenge", "come_back"]
const PACKS: Array[String] = ["starter_pack", "level_pack", "rescue_pack", "remove_ads"]


## {rows: Array[PackedStringArray], keys: Dictionary key -> {en, vi}, dup: Array, bad_cols: Array}
func _load() -> Dictionary:
	var out := {"rows": [], "keys": {}, "dup": [], "bad_cols": [], "header": PackedStringArray()}
	var f := FileAccess.open(CSV_PATH, FileAccess.READ)
	if f == null:
		return out
	out.header = f.get_csv_line()
	while not f.eof_reached():
		var r := f.get_csv_line()
		if r.size() == 1 and r[0] == "":
			continue
		out.rows.append(r)
		if r.size() != 3:
			out.bad_cols.append(r[0])
			continue
		if out.keys.has(r[0]):
			out.dup.append(r[0])
		out.keys[r[0]] = {"en": r[1], "vi": r[2]}
	return out


## Chuỗi placeholder theo thứ tự, ví dụ "%d %s" -> "ds". Lẫn "%%" thì bỏ qua cặp đó.
func _placeholders(text: String) -> String:
	var res := ""
	var i := 0
	while i < text.length():
		if text[i] == "%" and i + 1 < text.length():
			var c := text[i + 1]
			if c != "%":
				res += c
			i += 2
		else:
			i += 1
	return res


func _has_non_ascii(text: String) -> bool:
	for i in text.length():
		if text.unicode_at(i) > 127:
			return true
	return false


func test_structure(t: T) -> void:
	var d := _load()
	t.eq(d.header, PackedStringArray(["keys", "en", "vi"]), "header keys,en,vi")
	t.ok(d.rows.size() > 100, "đủ số khoá (>100)")
	t.eq(d.bad_cols, [], "mọi hàng đủ 3 cột")
	t.eq(d.dup, [], "không trùng khoá")
	var empties: Array[String] = []
	for k in d.keys:
		if str(d.keys[k].en).strip_edges() == "" or str(d.keys[k].vi).strip_edges() == "":
			empties.append(k)
	t.eq(empties, [], "không ô rỗng")


func test_key_names(t: T) -> void:
	var d := _load()
	var re := RegEx.create_from_string("^[a-z][a-z0-9_]*$")
	var bad: Array[String] = []
	for k in d.keys:
		if k == "APP_NAME":
			continue
		var in_group := false
		for g in GROUPS:
			if k.begins_with(g):
				in_group = true
		if re.search(k) == null or not in_group:
			bad.append(k)
	t.eq(bad, [], "khoá snake_case và thuộc một nhóm")


func test_required_keys(t: T) -> void:
	var d := _load()
	for k in REQUIRED:
		t.ok(d.keys.has(k), "có khoá bắt buộc " + k)
	t.eq(d.keys.get("APP_NAME", {}).get("en", ""), "Tap Block Out", "APP_NAME en")
	for g in GROUPS:
		var n := 0
		for k in d.keys:
			if k.begins_with(g):
				n += 1
		t.ok(n > 0, "nhóm " + g + " có khoá")


func test_design_texts(t: T) -> void:
	var d := _load()
	t.eq(d.keys.level_remaining.vi % 5, "Còn 5 khối", "Còn N khối")
	t.eq(d.keys.level_remaining.en % 5, "5 blocks left", "N blocks left")
	t.eq(d.keys.home_challenge_locked.en % 50, "Unlocked at Level 50", "Unlocked at Level 50")
	t.eq(d.keys.home_coming_soon.vi, "Sắp có level mới", "Sắp có level mới")
	t.eq(d.keys.tut_tap.en, "Tap the block", "Tap the block")


func test_placeholders_match(t: T) -> void:
	var d := _load()
	var bad: Array[String] = []
	for k in d.keys:
		if _placeholders(d.keys[k].en) != _placeholders(d.keys[k].vi):
			bad.append(k)
	t.eq(bad, [], "placeholder en = vi (cùng thứ tự)")
	# áp tham số thật, không lỗi định dạng
	for k in d.keys:
		var ph := _placeholders(d.keys[k].en)
		if ph == "":
			continue
		var args: Array = []
		for c in ph:
			args.append(7 if c == "d" else "x")
		for lang in ["en", "vi"]:
			var s: String = d.keys[k][lang]
			t.ok((s % args) != "", "định dạng được " + k + "/" + lang)


func test_vietnamese_quality(t: T) -> void:
	var d := _load()
	var accented := 0
	var same := 0
	for k in d.keys:
		var vi: String = d.keys[k].vi
		if _has_non_ascii(vi):
			accented += 1
		if vi == d.keys[k].en:
			same += 1
	t.ok(accented > d.keys.size() / 2, "tiếng Việt có dấu ở đa số khoá")
	t.ok(same < d.keys.size() / 3, "không sao chép en sang vi hàng loạt")
	t.eq(d.keys.level_remaining.vi.begins_with("Còn"), true, "vi dùng 'Còn'")


func test_config_coverage(t: T) -> void:
	var d := _load()
	for b in BOOSTERS:
		t.ok(Config.ECON.booster_price.has(b), "Config có booster " + b)
		t.ok(d.keys.has("booster_" + b), "booster_" + b)
		t.ok(d.keys.has("booster_%s_desc" % b), "booster_%s_desc" % b)
	for m in MECHS:
		t.ok(Config.UNLOCK.has(m), "Config.UNLOCK có cơ chế " + m)
		t.ok(d.keys.has("mech_" + m), "mech_" + m)
		t.ok(d.keys.has("mech_%s_desc" % m), "mech_%s_desc" % m)
	for p in PACKS:
		t.ok(Config.SKUS.has(p), "Config có SKU " + p)
		t.ok(d.keys.has("shop_" + p), "shop_" + p)
		t.ok(d.keys.has("shop_%s_desc" % p), "shop_%s_desc" % p)
		t.ok(d.keys.has("offer_%s_title" % p), "offer_%s_title" % p)
		t.ok(d.keys.has("offer_%s_body" % p), "offer_%s_body" % p)
	for kind in NOTIF_KINDS:
		t.ok(d.keys.has("notif_%s_title" % kind), "notif_%s_title" % kind)
		t.ok(d.keys.has("notif_%s_body" % kind), "notif_%s_body" % kind)
	# khoá "Còn N khối" của popup hết MOVES có bản số ít
	t.ok(d.keys.has("rescue_remaining_one"), "rescue_remaining_one")


## Mọi tr("KEY") dạng literal trong src/ phải có khoá. Khoá ghép động thì bỏ qua.
func test_tr_literals_exist(t: T) -> void:
	var d := _load()
	var re := RegEx.create_from_string("\\btr\\(\"([A-Za-z0-9_]+)\"\\)")
	var missing: Array[String] = []
	var stack: Array[String] = ["res://src"]
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		for sub in dir.get_directories():
			stack.append(dir_path + "/" + sub)
		for fname in dir.get_files():
			if not fname.ends_with(".gd"):
				continue
			var f := FileAccess.open(dir_path + "/" + fname, FileAccess.READ)
			if f == null:
				continue
			for m in re.search_all(f.get_as_text()):
				var key := m.get_string(1)
				if not d.keys.has(key):
					missing.append("%s: %s" % [fname, key])
	t.eq(missing, [], "tr() literal đều có khoá")
