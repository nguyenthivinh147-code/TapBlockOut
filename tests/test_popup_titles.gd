extends RefCounted
## Popup titles show their translation as written, capital on the first letter only (2026-11-13, like the Settings
## title): no TMP UpperCase on the title labels (scenes and the Unity data they are baked from), and title strings in
## sentence case in every language with letter case. Feature and pack names keep their own capitals
## (docs/UI_UNITY.md "Tiêu đề popup").
const T := preload("res://tests/t.gd")

## Title labels of the Unity layers: the header and its two shadow copies, the Remove Ads title, and the ribbons of the
## result cards and of Select Account (node path suffixes).
const TITLE_NAMES := ["txtHeader", "txtHeader BG1", "txtHeader BG2", "txtHeader (1)", "Title_txt"]
const TITLE_PATHS := ["WinPanel/WinPanel/Panel/Image/Text (TMP)", "LossPanel/BG/Lose_Panel/Text (TMP)",
	"SelectAccountLayer/Title"]
const MARKERS := ["txtHeader", "Title_txt", "Lose_Panel", "WinPanel", "SelectAccountLayer"]
## Unity TMP FontStyles.UpperCase.
const UPPER_BIT := 16

## Title keys written in sentence case.
const SENTENCE_KEYS := ["settings_title", "no_lives_title", "profile_name_title", "settings_language", "lb_howto_title",
	"ads_notice_title", "settings_notifications", "boot_offline_title", "win_rate_title", "rescue_title",
	"ads_reward_title", "shop_buy_ok", "streak_keep_title", "streak_rules_title", "boot_update_title", "profile_title",
	"lb_week_title", "lb_result_title", "special_guide_title", "mech_pop_title", "mech_new_title", "booster_new_title",
	"daily_title", "win_title", "lose_title", "hearts_support_title", "lb_leagues_title", "special_boom_title",
	"special_fail_title", "weekly_howto_title", "shop_mini_title", "lose_keep_title", "level_restart_confirm_title",
	"rescue_confirm_title", "special_leave_title"]
## Title keys that are feature, pack or booster names: their capitals stay, but none is written in capitals only.
const NAME_KEYS := ["lb_title", "streak_title", "shop_remove_ads", "weekly_title", "chain_title", "hearts_bundle_title",
	"offer_starter_pack_title", "offer_level_pack_title", "offer_remove_ads_title", "offer_rescue_pack_title",
	"offer_special_pack_title", "home_ads_daily", "challenge_title", "special_title", "level_title", "booster_hint",
	"booster_move", "booster_smash"]
## Languages with letter case. German capitalises every noun, so it only gets the "not all capitals" check.
const CASED := ["en", "vi", "pt_BR", "tr", "fr", "id", "es", "ru", "uk", "it"]
## Words that keep their capital inside a sentence-case title.
const ALLOW_WORDS := ["d'Internet"]


func _scenes(dir: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".tscn"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_scenes(dir.path_join(d), out)


static func is_title(path: String) -> bool:
	if path.get_file() in TITLE_NAMES:
		return true
	for p in TITLE_PATHS:
		if path.ends_with(p):
			return true
	return false


func _walk(n: Node, root: Node, file: String, bad: Array[String], found: Array) -> void:
	if n is Label:
		var path := str(root.get_path_to(n))
		if is_title(path):
			found[0] += 1
			if (n as Label).uppercase:
				bad.append("%s: %s" % [file.get_file(), path])
	for c in n.get_children():
		_walk(c, root, file, bad, found)


func test_title_labels_not_uppercase(t: T) -> void:
	var files: Array[String] = []
	_scenes("res://scenes", files)
	var bad: Array[String] = []
	var found := [0]
	for f in files:
		var text := FileAccess.get_file_as_string(f)
		var hit := false
		for m in MARKERS:
			if text.contains(m):
				hit = true
				break
		if not hit:
			continue
		var scene := load(f) as PackedScene
		var root := scene.instantiate()
		_walk(root, root, f, bad, found)
		root.free()
	t.ok(found[0] > 60, "có đủ nhãn tiêu đề để kiểm: %d" % found[0])
	t.eq(bad, [] as Array[String], "nhãn tiêu đề popup không bật in hoa")


func _walk_data(spec: Dictionary, path: String, file: String, bad: Array[String]) -> void:
	var p := (path + "/" if path != "" else "") + str(spec.get("n", ""))
	var txt: Variant = spec.get("txt")
	if txt is Dictionary and is_title(p) and (int((txt as Dictionary).get("st", 0)) & UPPER_BIT) != 0:
		bad.append("%s: %s" % [file, p])
	for ch in spec.get("ch", []):
		_walk_data(ch, p, file, bad)


func test_title_data_not_uppercase(t: T) -> void:
	var bad: Array[String] = []
	var dir := "res://data/ui_unity"
	var n := 0
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".json") or f.begins_with("_"):
			continue
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(f)))
		if data is Dictionary and (data as Dictionary).has("root"):
			n += 1
			_walk_data(data.root, "", f, bad)
	t.ok(n > 30, "có dữ liệu layer: %d" % n)
	t.eq(bad, [] as Array[String], "dữ liệu Unity: tiêu đề không có cờ UpperCase")


func _strings() -> Dictionary:
	var out := {}
	var f := FileAccess.open("res://i18n/strings.csv", FileAccess.READ)
	var head := f.get_csv_line()
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < head.size():
			continue
		var by_lang := {}
		for i in range(1, head.size()):
			by_lang[head[i]] = row[i]
		out[row[0]] = by_lang
	return out


static func _all_caps(s: String) -> bool:
	return s != s.to_lower() and s == s.to_upper()


func test_title_strings_sentence_case(t: T) -> void:
	var strings := _strings()
	var bad: Array[String] = []
	for k in SENTENCE_KEYS + NAME_KEYS:
		t.ok(strings.has(k), "có key " + k)
		if not strings.has(k):
			continue
		for lang in strings[k]:
			var s := str(strings[k][lang])
			if _all_caps(s.replace("%d", "")) and s.length() > 3:
				bad.append("%s %s toàn chữ hoa: %s" % [k, lang, s])
	for k in SENTENCE_KEYS:
		if not strings.has(k):
			continue
		for lang in CASED:
			var words := str(strings[k][lang]).split(" ", false)
			for i in range(1, words.size()):
				var w := words[i]
				if w in ALLOW_WORDS:
					continue
				var first := w.substr(0, 1)
				if first != first.to_lower():
					bad.append("%s %s hoa giữa câu: %s" % [k, lang, strings[k][lang]])
					break
	t.eq(bad, [] as Array[String], "tiêu đề popup chỉ hoa chữ đầu")
