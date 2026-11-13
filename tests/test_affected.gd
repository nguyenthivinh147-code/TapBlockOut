extends RefCounted
## tools/affected.sh (docs/TESTING.md "Chọn test theo thay đổi"): tests/affected_map.txt khớp cây code hiện tại, và
## vài thay đổi mẫu chọn đúng test, kịch bản smoke. Chạy tools/affected.mjs bằng Node như tools/test.sh gọi
## tools/report.mjs; máy không có Node thì bỏ qua và in SKIP.

const T := preload("res://tests/t.gd")

const SCRIPT := "res://tools/affected.mjs"


static func _node_ok() -> bool:
	var out: Array = []
	return OS.execute("node", PackedStringArray(["--version"]), out, true) == 0


static func _run(args: Array) -> Dictionary:
	var argv := PackedStringArray([ProjectSettings.globalize_path(SCRIPT)])
	for a in args:
		argv.append(str(a))
	var out: Array = []
	var code := OS.execute("node", argv, out, true)
	return {"code": code, "text": "".join(PackedStringArray(out))}


static func _json(t: T, args: Array) -> Dictionary:
	var r := _run(args)
	var data = JSON.parse_string(str(r.text))
	if int(r.code) != 0 or not (data is Dictionary):
		t.fail("affected.mjs %s: mã %d, %s" % [" ".join(PackedStringArray(args)), int(r.code), str(r.text).left(600)])
		return {}
	return data


## Like _json, for a command whose non-zero exit is expected (--check with problems).
static func _json_any(t: T, args: Array) -> Dictionary:
	var r := _run(args)
	var data = JSON.parse_string(str(r.text))
	if not (data is Dictionary):
		t.fail("affected.mjs %s: không ra JSON: %s" % [" ".join(PackedStringArray(args)), str(r.text).left(600)])
		return {}
	return data


static func _per_file(sel: Dictionary) -> Dictionary:
	var out := {}
	for f in sel.get("perFile", []):
		out[str(f.path)] = f
	return out


func test_map_matches_tree(t: T) -> void:
	if not _node_ok():
		print("SKIP test_affected: không có node")
		return
	var r := _json(t, ["--check", "--json"])
	if r.is_empty():
		return
	t.ok(bool(r.ok), "tests/affected_map.txt hợp lệ:\n  %s" % "\n  ".join(PackedStringArray(r.get("problems", []))))


func test_picks_per_file(t: T) -> void:
	if not _node_ok():
		return
	var wp_line := 0
	var lines := FileAccess.get_file_as_string("res://tests/smoke/scen_events.gd").split("\n")
	for i in lines.size():
		if lines[i].begins_with("static func scen_wp("):
			wp_line = i + 1
	t.ok(wp_line > 0, "scen_events.gd có scen_wp")
	var sel := _json(t, ["--json", "--static", "--files", "src/meta/weekly_pass.gd", "tests/cases/WP.csv", "docs/TESTING.md",
		"scenes/unity/ShopCashLayer.tscn", "assets/ui/cc/Popup_Lose.png", "src/meta/wallet.gd", "tests/run_all.gd",
		"src/ui/shop.gd",
		"tests/smoke/scen_events.gd:%d" % (wp_line + 2)])
	var by := _per_file(sel)
	if by.is_empty():
		return
	var wp: Dictionary = by["src/meta/weekly_pass.gd"]
	t.ok((wp.smoke as Array).has("WP"), "weekly_pass.gd chọn WP: %s" % str(wp.smoke))
	t.ok((wp.tests as Array).has("test_weekly_pass"), "weekly_pass.gd chọn test_weekly_pass")
	t.ok(not bool(wp.allTests), "weekly_pass.gd không chọn mọi test")
	var csv: Dictionary = by["tests/cases/WP.csv"]
	t.eq(csv.smoke, ["WP"], "WP.csv chỉ chọn kịch bản WP")
	t.ok(not bool(csv.dflt), "WP.csv không chọn bộ mặc định")
	t.ok((csv.tests as Array).has("test_cases"), "WP.csv chọn test_cases")
	var doc: Dictionary = by["docs/TESTING.md"]
	t.eq(doc.smoke, [], "tài liệu không chọn kịch bản")
	t.ok(not bool(doc.dflt) and not bool(doc.allTests), "tài liệu không chọn bộ mặc định, không chọn mọi test")
	var shop_layer: Dictionary = by["scenes/unity/ShopCashLayer.tscn"]
	t.ok((shop_layer.smoke as Array).has("E"), "ShopCashLayer chọn E (Shop): %s" % str(shop_layer.smoke))
	t.ok(not (shop_layer.smoke as Array).has("WP") and not bool(shop_layer.dflt),
		"ShopCashLayer không chọn WP hay bộ mặc định: %s" % str(shop_layer.smoke))
	# Regression (2026-11-12): data/ui_unity/_sprites.json lists every sprite, so each sprite reached every Unity
	# screen through it; the layers that quote the sprite are the ones that draw it.
	var lose_sprite: Dictionary = by["assets/ui/cc/Popup_Lose.png"]
	t.ok((lose_sprite.smoke as Array).has("C"), "Popup_Lose.png chọn C (thua): %s" % str(lose_sprite.smoke))
	t.ok(not (lose_sprite.smoke as Array).has("WP") and not bool(lose_sprite.dflt),
		"Popup_Lose.png không chọn WP hay bộ mặc định: %s" % str(lose_sprite.smoke))
	# Regression (2026-11-12): "Game cộng reward" in a pure module's doc comment, and feature ids such as
	# "weekly_pass" in config.gd read as file names, linked every module to every test.
	var wallet: Dictionary = by["src/meta/wallet.gd"]
	t.ok((wallet.tests as Array).has("test_wallet"), "wallet.gd chọn test_wallet")
	t.ok(not (wallet.tests as Array).has("test_board"), "wallet.gd không chọn test_board")
	t.ok(bool(by["tests/run_all.gd"].allTests), "run_all.gd chọn mọi test")
	t.ok((sel.window as Array).has("E"), "shop.gd chạy E có cửa sổ: %s" % str(sel.window))
	var scen: Dictionary = by["tests/smoke/scen_events.gd"]
	t.eq(scen.smoke, ["WP"], "sửa trong scen_wp chỉ chọn WP")
	t.ok(not bool(scen.dflt), "sửa trong scen_wp không chọn bộ mặc định")


func test_level_range_and_device(t: T) -> void:
	if not _node_ok():
		return
	var sel := _json(t, ["--json", "--static", "--files", "data/levels/level_0012.json", "data/levels/level_0015.json",
		"src/platform/android_iap.gd"])
	if sel.is_empty():
		return
	t.ok((sel.smoke as Array).has("V"), "level đổi chọn V")
	t.eq(sel.vRange, [12.0, 15.0], "V quét đúng L12–L15")
	t.eq(sel.device, ["src/platform/android_iap.gd"], "android_iap.gd báo cần máy thật")
	t.ok(str(sel.commands).contains("from=12 to=15"), "lệnh V có from=12 to=15: %s" % str(sel.commands))


## A made-up coverage map: every test file is known and clean except test_lives (failed during the run). In
## wallet.gd earn ran under test_game, spend under test_ui_home, inv_add under test_daily, inv_count under none;
## test_ui_level created shop.gd's object. None of these tests names wallet.gd or shop.tscn.
static func _fixture_map() -> String:
	var names: Array[String] = []
	for f in DirAccess.get_files_at("res://tests"):
		if f.begins_with("test_") and f.ends_with(".gd"):
			names.append(f.get_basename())
	names.sort()
	var tests: Array = []
	for n in names:
		tests.append({"name": n, "ms": 1000, "failed": 1 if n == "test_lives" else 0})
	var i := func(n: String) -> Array: return [names.find(n)]
	var map := {"version": 1, "created": "2026-11-13T00:00:00Z", "commit": "0000000", "complete": true,
		"tests": tests, "files": {
			"src/meta/wallet.gd": {"sha1": "", "funcs": {"<new>": [], "earn": i.call("test_game"),
				"spend": i.call("test_ui_home"), "inv_count": [], "inv_add": i.call("test_daily"), "inv_use": []}},
			"src/ui/shop.gd": {"sha1": "", "funcs": {"<new>": i.call("test_ui_level")}}}}
	DirAccess.make_dir_recursive_absolute("user://test_affected")
	var path := "user://test_affected/cov_map.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(map))
	f.close()
	return ProjectSettings.globalize_path(path)


static func _write(name: String, text: String) -> String:
	DirAccess.make_dir_recursive_absolute("user://test_affected")
	var path := "user://test_affected/" + name
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	return ProjectSettings.globalize_path(path)


static func _line_of(lines: PackedStringArray, prefix: String) -> int:
	for k in lines.size():
		if lines[k].begins_with(prefix):
			return k + 1
	return 0


func test_coverage_picks(t: T) -> void:
	if not _node_ok():
		return
	var map := _fixture_map()
	var lines := FileAccess.get_file_as_string("res://src/meta/wallet.gd").split("\n")
	var spend := _line_of(lines, "static func spend(")
	var kinds := _line_of(lines, "const KINDS")
	var count := _line_of(lines, "static func inv_count(")
	t.ok(spend > 1 and kinds > 0 and count > 0, "wallet.gd có spend, KINDS, inv_count")
	var no_allow := _write("allow_none.txt", "")
	var pick := func(target: String) -> Dictionary:
		var sel := _json(t, ["--json", "--coverage-map", map, "--allow-file", no_allow, "--files", target])
		return {} if sel.is_empty() else (sel.perFile as Array)[0]

	var body: Dictionary = pick.call("src/meta/wallet.gd:%d" % (spend + 1))
	if body.is_empty():
		return
	t.eq(body.testMode, "coverage", "có bản đo thì chọn theo độ phủ")
	var tests: Array = body.tests
	t.ok(tests.has("test_ui_home") and str(body.testWhy.test_ui_home).contains("spend"),
		"sửa thân spend chọn test chạy qua spend: %s" % str(body.testWhy.get("test_ui_home")))
	t.ok(tests.has("test_wallet"), "test nhắc tên wallet.gd vẫn chạy")
	t.ok(tests.has("test_static_check"), "dòng test: của tests/affected_map.txt vẫn áp")
	t.ok(tests.has("test_lives"), "test lỗi trong lần đo đi theo đồ thị tĩnh")
	for x in ["test_game", "test_daily", "test_board", "test_ui_level"]:
		t.ok(not tests.has(x), "sửa spend không chọn %s: %s" % [x, str(body.testWhy.get(x))])
	t.ok(int(body.staticTests) > tests.size(), "ít test hơn đồ thị tĩnh: %d < %d" % [tests.size(), int(body.staticTests)])

	var comment: Dictionary = pick.call("src/meta/wallet.gd:%d" % (spend - 1))
	t.ok(not (comment.tests as Array).has("test_ui_home"), "sửa comment không chọn test theo độ phủ")

	var cold: Dictionary = pick.call("src/meta/wallet.gd:%d" % (count + 1))
	t.eq(cold.untested, ["inv_count"], "hàm không test nào chạy tới được báo")

	var konst: Dictionary = pick.call("src/meta/wallet.gd:%d" % kinds)
	t.ok((konst.tests as Array).has("test_daily"), "sửa KINDS chọn test của inv_add (dùng KINDS)")
	t.ok(not (konst.tests as Array).has("test_ui_home") and not (konst.tests as Array).has("test_game"),
		"sửa KINDS không chọn test của hàm không dùng nó")

	var scene: Dictionary = pick.call("scenes/shop.tscn")
	t.ok((scene.tests as Array).has("test_ui_level"), "sửa shop.tscn chọn test tạo shop.gd")
	t.ok(not (scene.tests as Array).has("test_game") and not (scene.tests as Array).has("test_board"),
		"sửa shop.tscn không chọn test_game, test_board: %s" % str(scene.tests))

	var sel := _json(t, ["--json", "--static", "--coverage-map", map, "--files", "src/meta/wallet.gd"])
	if not sel.is_empty():
		var st: Dictionary = (sel.perFile as Array)[0]
		t.eq(st.testMode, "static", "--static bỏ qua bản đo")
		t.ok((st.tests as Array).has("test_ui_level"), "đồ thị tĩnh vẫn chọn test_ui_level")


## The gate of tools/affected.sh --run: a changed method is tested, untested, allowed (tests/untested_allow.txt) or
## unmeasured (not in the map).
func test_untested_gate(t: T) -> void:
	if not _node_ok():
		return
	var map := _fixture_map()
	var wallet := FileAccess.get_file_as_string("res://src/meta/wallet.gd").split("\n")
	var count := _line_of(wallet, "static func inv_count(")
	var spend := _line_of(wallet, "static func spend(")
	var lives := FileAccess.get_file_as_string("res://src/meta/lives.gd").split("\n")
	var max_for := _line_of(lives, "static func max_for(")
	t.ok(count > 0 and spend > 0 and max_for > 0, "wallet.gd có inv_count, spend; lives.gd có max_for")
	var targets := ["src/meta/wallet.gd:%d,%d" % [count + 1, spend + 1], "src/meta/lives.gd:%d" % (max_for + 1)]

	var none := _write("allow_none.txt", "")
	var sel := _json(t, ["--json", "--coverage-map", map, "--allow-file", none, "--files"] + targets)
	if sel.is_empty():
		return
	t.eq(sel.untested, ["src/meta/wallet.gd:inv_count"], "inv_count không test nào chạy tới; spend có test_ui_home")
	t.eq(sel.unmeasured, ["src/meta/lives.gd:max_for"], "lives.gd không có trong bản đo nên chưa đo")

	var allow := _write("allow_inv.txt", "# miễn trừ thử\nsrc/meta/wallet.gd:inv_* ## thử (2026-11-13)\n")
	sel = _json(t, ["--json", "--coverage-map", map, "--allow-file", allow, "--files"] + targets)
	if sel.is_empty():
		return
	t.eq(sel.untested, [], "inv_count được miễn trừ theo mẫu inv_*")
	t.eq(sel.allowed, ["src/meta/wallet.gd:inv_count"], "danh sách miễn trừ có inv_count")

	var bad := _write("allow_bad.txt",
		"src/meta/wallet.gd:inv_count thiếu lý do\nsrc/meta/wallet.gd:no_such_method ## đã xoá (2026-11-13)\n")
	var chk := _json_any(t, ["--check", "--json", "--allow-file", bad])
	var problems := "\n".join(PackedStringArray(chk.get("problems", [])))
	t.ok(problems.contains("allow_bad.txt:1: cần dạng"), "dòng thiếu lý do bị báo:\n%s" % problems)
	t.ok(problems.contains("no_such_method"), "dòng không khớp hàm nào bị báo:\n%s" % problems)


## Merging a filtered coverage run into the map: rows replace the same test's hits, new tests are appended, the
## method list follows the current source.
func test_coverage_merge(t: T) -> void:
	if not _node_ok():
		return
	var code := """
const { buildMap } = await import('%s');
const base = { version: 1, tests: [{ name: 'test_a' }, { name: 'test_b' }],
  files: { 'src/x.gd': { sha1: '1', funcs: { f: [0, 1], g: [1], gone: [0] } } } };
const rows = [{ test: 'test_b', ms: 5, failed: 0, hits: ['src/x.gd:f', 'src/x.gd:h'] },
  { test: 'test_c', ms: 7, failed: 1, hits: ['src/x.gd:g'] }];
const m = buildMap(base, rows, { 'src/x.gd': { sha1: '2', ids: ['f', 'g', 'h'] } }, { updated: 'now' });
console.log(JSON.stringify(m));
""" % ("file://" + ProjectSettings.globalize_path("res://tools/coverage.mjs"))
	var out: Array = []
	var rc := OS.execute("node", PackedStringArray(["--input-type=module", "-e", code]), out, true)
	var json := JSON.new()
	var m: Variant = json.data if rc == 0 and json.parse("".join(PackedStringArray(out))) == OK else null
	t.ok(m is Dictionary, "buildMap chạy: %s" % str(out).left(300))
	if not (m is Dictionary):
		return
	var names: Array = []
	for x in m.tests:
		names.append(x.name)
	t.eq(names, ["test_a", "test_b", "test_c"], "test mới nối vào cuối")
	var funcs: Dictionary = m.files["src/x.gd"].funcs
	t.eq(funcs.f, [0.0, 1.0], "f: test_a giữ nguyên, test_b chạy lại vẫn tới")
	t.eq(funcs.g, [2.0], "g: test_b chạy lại không tới nữa, test_c tới")
	t.eq(funcs.h, [1.0], "h: hàm mới, test_b tới")
	t.ok(not funcs.has("gone"), "hàm không còn trong mã nguồn bị bỏ")
	t.eq(str(m.files["src/x.gd"].sha1), "2", "sha1 theo mã nguồn hiện tại")
	t.eq(int(m.tests[2].failed), 1, "test_c ghi số test lỗi")
	t.eq(str(m.updated), "now", "meta của lần gộp")


func test_bad_argument(t: T) -> void:
	if not _node_ok():
		return
	t.eq(int(_run(["--no-such-flag"]).code), 2, "tham số lạ thoát mã 2")
