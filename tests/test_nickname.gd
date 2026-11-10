extends RefCounted
const T := preload("res://tests/t.gd")
const SaveSchema := preload("res://src/meta/save_schema.gd")
const Nickname := preload("res://src/meta/nickname.gd")
const NameFilter := preload("res://src/meta/name_filter.gd")


func test_rules(t: T) -> void:
	for ok_name in ["Bob", "candy_fan", "J.R-99", "ABCDEFGHIJKLMN", "  Mint  ", "007", "a_b"]:
		t.eq(Nickname.check(ok_name), "", "hợp lệ: " + ok_name)
	t.eq(Nickname.check("ab"), Nickname.ERR_LENGTH, "dưới 3 ký tự")
	t.eq(Nickname.check("   ab   "), Nickname.ERR_LENGTH, "bỏ khoảng trắng hai đầu rồi mới đếm")
	t.eq(Nickname.check("ABCDEFGHIJKLMNO"), Nickname.ERR_LENGTH, "quá 14 ký tự")
	t.eq(Nickname.check(""), Nickname.ERR_LENGTH, "trống")
	t.eq(Nickname.check("Việt Nam"), Nickname.ERR_CHARS, "chữ có dấu và khoảng trắng")
	t.eq(Nickname.check("John Doe"), Nickname.ERR_CHARS, "khoảng trắng giữa tên")
	t.eq(Nickname.check("mint@candy"), Nickname.ERR_CHARS, "ký tự lạ")
	t.eq(Nickname.check("ミント太郎"), Nickname.ERR_CHARS, "chữ Nhật")
	t.eq(Nickname.check("_._"), Nickname.ERR_CHARS, "không có chữ hay số")
	t.eq(Nickname.check("fuck_you"), Nickname.ERR_BANNED, "từ cấm")


func test_change_saves_trimmed(t: T) -> void:
	var s := SaveSchema.defaults()
	t.eq(Nickname.current(s), "", "chưa đặt tên")
	t.eq(Nickname.change(s, "  Mint_Pop "), "", "đổi được")
	t.eq(Nickname.current(s), "Mint_Pop", "lưu tên đã bỏ khoảng trắng")
	t.eq(Nickname.change(s, "x"), Nickname.ERR_LENGTH, "tên sai")
	t.eq(Nickname.current(s), "Mint_Pop", "tên sai không ghi đè")
	t.eq(Nickname.change(s, "shithead"), Nickname.ERR_BANNED, "từ cấm")
	t.eq(Nickname.current(s), "Mint_Pop", "từ cấm không ghi đè")
	t.eq(Nickname.change(s, "Taffy.Cat"), "", "đổi lần nữa, miễn phí")
	t.eq(Nickname.current(s), "Taffy.Cat", "tên mới")
	t.eq(SaveSchema.merge_defaults({"version": 1}).profile, {"name": ""}, "bản lưu cũ thêm profile.name trống")
	var old := {"version": 1}
	t.eq(Nickname.current(old), "", "bản lưu cũ không có profile")
	t.eq(Nickname.change(old, "Bob"), "", "bản lưu cũ đổi được")
	t.eq(Nickname.current(old), "Bob", "tạo profile")


func test_default_code(t: T) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bad: Array[String] = []
	var seen := {}
	for i in 500:
		var n := Nickname.make_default(rng)
		seen[n] = true
		if not n.begins_with("CD_") or n.length() != 9 or not n.substr(3).is_valid_int() or Nickname.check(n) != "":
			bad.append(n)
	t.eq(bad, [] as Array[String], "500 mã đều dạng CD_ + 6 chữ số, hợp lệ")
	t.ok(seen.size() > 490, "mã ngẫu nhiên, hiếm trùng")
	for n in ["CD_000000", "CD_455455", "CD_555555", "CD_123456", "CD_808080", "CD_133700", "CD_999999"]:
		t.eq(Nickname.check(n), "", "chữ số ở cuối không đọc thành chữ: " + n)
	var a := RandomNumberGenerator.new()
	a.seed = 42
	var b := RandomNumberGenerator.new()
	b.seed = 42
	t.eq(Nickname.make_default(a), Nickname.make_default(b), "cùng seed cùng mã")


func test_ensure_gives_code_once(t: T) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var s := SaveSchema.defaults()
	t.ok(Nickname.ensure(s, rng), "chưa có tên: ghi mã")
	var code := Nickname.current(s)
	t.ok(code.begins_with("CD_"), "mã mặc định " + code)
	t.ok(not Nickname.ensure(s, rng), "đã có mã: không ghi lại")
	t.eq(Nickname.current(s), code, "giữ mã cũ")
	t.eq(Nickname.change(s, "Bob"), "", "đổi tên")
	t.ok(not Nickname.ensure(s, rng), "đã đặt tên: không ghi mã")
	t.eq(Nickname.current(s), "Bob", "giữ tên người chơi đặt")
	var old := {"version": 1}
	t.ok(Nickname.ensure(old, rng), "bản lưu cũ không có profile: ghi mã")
	t.ok(Nickname.current(old).begins_with("CD_"), "tạo profile với mã")


func test_banned_variants(t: T) -> void:
	var bad := [
		"fuck", "FUCK", "fuuuuck", "f.u.c.k", "f_u_c_k", "fuckyou", "MotherFucker", "sh1t", "5h1thead", "5hit", "b1tch",
		"a55hole", "niiigger", "Nigga99", "pu55y",
		"ass", "a.s.s", "MyAss", "ass_99", "ass123", "big_ass", "Dick", "c0ck",
		"dit_me", "DitMe", "concac", "vcl", "Lon", "occho", "cailon",
		"puta", "Hijodeputa", "mierda", "caralho", "fdp", "merde", "connard", "scheisse", "Arschloch", "cazzo",
		"vaffanculo", "orospu", "amk", "kontol", "ngentot", "blyat", "pizdec", "chutiya", "bhenchod", "shibal",
		"admin", "Admin_01", "moderator", "official_mint", "candyaway", "Horus", "support", "gm_jack",
	]
	for n in bad:
		t.ok(NameFilter.is_banned(n), "cấm: " + n)


func test_harmless_words_pass(t: T) -> void:
	var good := [
		"class", "Classic", "grass", "Bassist", "Cassie", "Glasses", "Scunthorpe", "therapist", "shiitake", "Yamashita",
		"Matsushita", "badminton", "Chorus", "Niger", "Nigeria", "Cazorla", "Peacock", "Hancock", "Dickens", "Sussex",
		"Essex", "Ana1", "Anna", "Analyst", "Penistone", "Grape", "Drape", "Scrape", "longcat", "London", "Edit",
		"Credit", "Cacao", "Puttanesca", "Negeri", "Marsch", "Mint", "Taffy", "Lolly", "Nguyen", "Kim_Lan",
		"Pho_Bo", "Buoi_sang", "SukaKopi", "Player_2692", "Hello123", "Sam007", "Mood", "Duc.Anh", "Raccoon",
		"Cocktail", "Pushkin", "Shuttle", "Assassin", "Embassy", "Compass", "Pass_word", "Merdeka", "Merdan", "Fodera",
		"Nutter", "Poornima", "Shitake", "Loz", "Arsenal", "Pakistan", "Spicey", "Gandhi", "Hitchcock", "Cumberland",
	]
	for n in good:
		t.ok(not NameFilter.is_banned(n), "không cấm nhầm: " + n)
