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
	var sel := _json(t, ["--json", "--files", "src/meta/weekly_pass.gd", "tests/cases/WP.csv", "docs/TESTING.md",
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
	var sel := _json(t, ["--json", "--files", "data/levels/level_0012.json", "data/levels/level_0015.json",
		"src/platform/android_iap.gd"])
	if sel.is_empty():
		return
	t.ok((sel.smoke as Array).has("V"), "level đổi chọn V")
	t.eq(sel.vRange, [12.0, 15.0], "V quét đúng L12–L15")
	t.eq(sel.device, ["src/platform/android_iap.gd"], "android_iap.gd báo cần máy thật")
	t.ok(str(sel.commands).contains("from=12 to=15"), "lệnh V có from=12 to=15: %s" % str(sel.commands))


func test_bad_argument(t: T) -> void:
	if not _node_ok():
		return
	t.eq(int(_run(["--no-such-flag"]).code), 2, "tham số lạ thoát mã 2")
