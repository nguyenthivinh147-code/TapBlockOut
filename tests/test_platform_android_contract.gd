extends RefCounted
## Backend Android của Platform (Task 10.3): hợp đồng với mock bằng reflection, kiểm chữ ký Play,
## và hành vi của từng backend với plugin giả (chạy được trên desktop, không cần singleton thật).
const T := preload("res://tests/t.gd")
const AndroidAds := preload("res://src/platform/android_ads.gd")
const AndroidIap := preload("res://src/platform/android_iap.gd")
const AndroidAn := preload("res://src/platform/android_an.gd")
const AndroidRc := preload("res://src/platform/android_rc.gd")
const AndroidSave := preload("res://src/platform/android_save.gd")
const AndroidNotif := preload("res://src/platform/android_notif.gd")
const PlatformScript := preload("res://src/platform/platform.gd")

const DIR := "user://test_platform_android_contract"
const SCALE := 0.001

var _key: CryptoKey = null
var _pub_b64: String = ""


# --- plugin giả ---

class FakePlugin extends RefCounted:
	signal ad_rewarded_done(placement: String, ok: bool, reason: String)
	signal ad_interstitial_done(placement: String, shown: bool)
	signal rc_fetched(json: String)
	signal cloud_loaded(json: String, ok: bool)
	signal cloud_saved(ok: bool)
	signal cloud_conflict(loser_json: String)
	signal notif_permission(granted: bool)

	var log: Array = []
	var rewarded_ready: bool = true
	var inter_ready: bool = true
	var hang: bool = false
	var rewarded_reply: Array = [true, ""]
	var inter_reply: bool = true
	var privacy: bool = true
	var lost: PackedStringArray = PackedStringArray()
	var rc_json: String = "{\"a\":1}"
	var rc_reply: String = "{\"ok\":true,\"values\":{\"x\":5,\"y\":\"s\"}}"
	var cloud_reply: Array = ["", true]
	var cloud_loser: String = ""
	var saved: Array[String] = []
	var save_ok: bool = true
	var notif_on: bool = false
	var notif_grant: bool = true
	var events: Array = []
	var props: Array = []
	var sched: Array = []

	func set_config(_j: String) -> void:
		log.append("set_config")

	func init_sdks() -> void:
		log.append("init_sdks")

	func ready_rewarded() -> bool:
		return rewarded_ready

	func ready_inter() -> bool:
		return inter_ready

	func load_ads() -> void:
		log.append("load_ads")

	func has_privacy() -> bool:
		return privacy

	func lost_rewarded() -> PackedStringArray:
		return lost

	func lost_done() -> void:
		lost = PackedStringArray()
		log.append("lost_done")

	func show_rewarded(pl: String) -> void:
		log.append("show_rewarded:" + pl)
		if not hang:
			ad_rewarded_done.emit(pl, rewarded_reply[0], rewarded_reply[1])

	func show_inter(pl: String) -> void:
		log.append("show_inter:" + pl)
		if not hang:
			ad_interstitial_done.emit(pl, inter_reply)

	func log_event(n: String, j: String) -> void:
		events.append([n, j])

	func set_user_props(j: String) -> void:
		props.append(j)

	func rc_fetch() -> void:
		if not hang:
			rc_fetched.emit(rc_reply)

	func rc_get_all() -> String:
		return rc_json

	func cloud_load() -> void:
		log.append("cloud_load")
		if hang:
			return
		if cloud_loser != "":
			cloud_conflict.emit(cloud_loser)
		cloud_loaded.emit(cloud_reply[0], cloud_reply[1])

	func cloud_save(j: String) -> void:
		saved.append(j)
		if not hang:
			cloud_saved.emit(save_ok)

	func notif_ask() -> void:
		if not hang:
			notif_permission.emit(notif_grant)

	func notif_enabled() -> bool:
		return notif_on

	func notif_schedule(j: String) -> void:
		sched.append(j)

	func notif_cancel_all() -> void:
		log.append("notif_cancel_all")


## Singleton phải là Object (RefCounted bị Godot cảnh báo khi đăng ký).
class FakeSingleton extends Object:
	signal ad_rewarded_done(placement: String, ok: bool, reason: String)
	var log: Array = []

	func set_config(_j: String) -> void:
		log.append("set_config")

	func init_sdks() -> void:
		log.append("init_sdks")

	func ready_rewarded() -> bool:
		return true

	func has_privacy() -> bool:
		return true

	func show_rewarded(pl: String) -> void:
		ad_rewarded_done.emit(pl, true, "")


class FakeBilling extends RefCounted:
	signal connected
	signal connect_error(response_code: int, debug_message: String)
	signal query_product_details_response(response: Dictionary)
	signal query_purchases_response(response: Dictionary)
	signal on_purchase_updated(response: Dictionary)
	signal consume_purchase_response(response: Dictionary)
	signal acknowledge_purchase_response(response: Dictionary)

	var ready: bool = true
	var connect_ok: bool = true
	var catalog: Dictionary = {}  # sku -> giá hiển thị
	var owned: Array = []
	var start_reply: Dictionary = {"response_code": 0}
	var buy_reply: Dictionary = {"response_code": 0}
	var hang_buy: bool = false
	var consumed: Array[String] = []
	var acked: Array[String] = []
	var finish_code: int = 0

	func is_ready() -> bool:
		return ready

	func start_connection() -> void:
		if connect_ok:
			ready = true
			connected.emit()
		else:
			connect_error.emit(3, "unavailable")

	func query_product_details(ids: PackedStringArray, _type: int) -> void:
		var details: Array = []
		for id in ids:
			if catalog.has(id):
				details.append({"product_id": id, "one_time_purchase_offer_details_list": [{"formatted_price": catalog[id]}]})
		query_product_details_response.emit({"response_code": 0, "debug_message": "", "product_details": details,
			"unfetched_products": []})

	func query_purchases(_type: int, _susp: bool = false) -> void:
		query_purchases_response.emit({"response_code": 0, "debug_message": "", "purchases": owned.duplicate(true)})

	func purchase(_id: String, _a: String = "", _b: String = "", _c: bool = false) -> Dictionary:
		if int(start_reply.get("response_code", 0)) == 0 and not hang_buy:
			on_purchase_updated.emit(buy_reply)
		return start_reply

	func consume_purchase(token: String) -> void:
		consumed.append(token)
		if finish_code == 0:
			owned = owned.filter(func(p: Dictionary) -> bool: return str(p["purchase_token"]) != token)
		consume_purchase_response.emit({"response_code": finish_code, "debug_message": "", "token": token})

	func acknowledge_purchase(token: String) -> void:
		acked.append(token)
		acknowledge_purchase_response.emit({"response_code": finish_code, "debug_message": "", "token": token})


# --- hỗ trợ ---

func _keys() -> void:
	if _key != null:
		return
	_key = Crypto.new().generate_rsa(2048)
	var pem := _key.save_to_string(true)
	_pub_b64 = pem.replace("-----BEGIN PUBLIC KEY-----", "").replace("-----END PUBLIC KEY-----", "") \
		.replace("\n", "").strip_edges()


func _sign(data: String) -> String:
	_keys()
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA1)
	ctx.update(data.to_utf8_buffer())
	var sig := Crypto.new().sign(HashingContext.HASH_SHA1, ctx.finish(), _key)
	return Marshalls.raw_to_base64(sig)


func _purchase(sku: String, token: String, state: int = 1, acked: bool = false, tamper: bool = false) -> Dictionary:
	var orig := JSON.stringify({"orderId": "GPA.%s" % token, "packageName": "com.test.app", "productId": sku,
		"purchaseToken": token, "purchaseState": 0})
	var sig := _sign(orig)
	if tamper:
		orig = orig.replace("com.test.app", "com.evil.app")
	return {"order_id": "GPA.%s" % token, "purchase_token": token, "package_name": "com.test.app",
		"purchase_state": state, "original_json": orig, "signature": sig, "is_acknowledged": acked,
		"product_ids": [sku]}


func _billing() -> FakeBilling:
	var b := FakeBilling.new()
	for sku in ["gold_pack_1", "remove_ads", "starter_pack", "rescue_pack"]:
		b.catalog[sku] = "VND 99.000"
	return b


func _iap(b: FakeBilling, key: String = "") -> AndroidIap:
	var iap := AndroidIap.new(null, b)
	iap.public_key = key
	iap.timeout_scale = SCALE
	return iap


func _buy_reply(purchases: Array) -> Dictionary:
	return {"response_code": 0, "debug_message": "", "purchases": purchases}


# --- hợp đồng bằng reflection ---

func _methods(script: GDScript) -> Dictionary:
	var out := {}
	for m in script.get_script_method_list():
		var n: String = m["name"]
		if n.begins_with("_") or n.begins_with("<"):
			continue
		out[n] = [(m["args"] as Array).size(), (m["default_args"] as Array).size()]
	return out


func _props(script: GDScript) -> Array[String]:
	var out: Array[String] = []
	for p in script.get_script_property_list():
		var n: String = p["name"]
		if (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0 and not n.begins_with("_"):
			out.append(n)
	return out


func _signals(script: GDScript) -> Array[String]:
	var out: Array[String] = []
	for s in script.get_script_signal_list():
		out.append(str(s["name"]))
	return out


func test_contract_matches_mocks(t: T) -> void:
	for part in ["ads", "iap", "an", "rc", "save", "notif"]:
		var mock := load("res://src/platform/mock_%s.gd" % part) as GDScript
		var droid := load("res://src/platform/android_%s.gd" % part) as GDScript
		t.ok(mock != null and droid != null and droid.can_instantiate(), "%s: nạp được hai backend" % part)
		var mm := _methods(mock)
		var am := _methods(droid)
		t.ok(not mm.is_empty(), "%s: mock có hàm công khai" % part)
		for n in mm:
			t.ok(am.has(n), "%s: android thiếu hàm %s" % [part, n])
			if am.has(n):
				t.eq(am[n], mm[n], "%s.%s: số tham số (tổng, mặc định)" % [part, n])
		var ap := _props(droid)
		for n in _props(mock):
			t.ok(n in ap, "%s: android thiếu thuộc tính %s" % [part, n])
		var asg := _signals(droid)
		for n in _signals(mock):
			t.ok(n in asg, "%s: android thiếu signal %s" % [part, n])


## Game đọc `Platform.ads.lost` và gọi `lost_done()`; mock_ads chưa có nhưng Android phải có.
func test_contract_game_extras(t: T) -> void:
	var am := _methods(AndroidAds)
	t.ok(am.has("lost_done"), "ads.lost_done")
	t.ok("lost" in _props(AndroidAds), "ads.lost")
	t.ok(_methods(AndroidIap).has("on_resume"), "iap.on_resume cho Platform")
	var ads := AndroidAds.new(null)
	t.eq(ads.lost, [], "lost mặc định rỗng")


func test_backends_safe_without_plugin(t: T) -> void:
	var ads := AndroidAds.new(null)
	t.eq(ads.ready_rewarded(), false, "ads: không sẵn sàng")
	t.eq((await ads.rewarded("x"))["ok"], false, "ads: rewarded không ok")
	t.eq((await ads.rewarded("x"))["reason"], "not_ready", "ads: lý do")
	t.eq((await ads.inter("x"))["shown"], false, "ads: inter không hiện")
	t.eq(ads.has_privacy, false, "ads: has_privacy")
	var iap := AndroidIap.new(null)
	t.eq(iap.price("gold_pack_1"), "", "iap: không giá khi thiếu billing")
	t.eq((await iap.buy("gold_pack_1"))["status"], "error", "iap: buy lỗi an toàn")
	t.eq(await iap.restore(), false, "iap: restore false")
	t.eq(iap.pending(), [], "iap: pending rỗng")
	var rc := AndroidRc.new(null)
	await rc.fetch()
	t.eq(rc.values, {}, "rc: rỗng")
	var an := AndroidAn.new(null)
	an.log_event("x", {"a": 1})
	an.user({"k": "v"})
	t.eq(an.user_props, {"k": "v"}, "an: user_props")
	var notif := AndroidNotif.new(null)
	t.eq(await notif.ask(), false, "notif: ask false")
	t.eq(notif.enabled(), false, "notif: enabled false")
	notif.schedule([{"at": 1, "kind": "k", "title": "t", "body": "b"}])
	notif.cancel_all()
	var save := AndroidSave.new(null)
	save.cache_path = DIR + "/none.json"
	save.mirror("{}")
	save.flush()
	save.sync_cloud()
	t.eq(save.last_json, "{}", "save: last_json")


# --- Platform chọn backend ---

func test_platform_picks_android_backends(t: T) -> void:
	var fake := FakeSingleton.new()
	Engine.register_singleton("TboPlatform", fake)
	var p: Node = PlatformScript.new()
	Engine.unregister_singleton("TboPlatform")
	t.eq(p.is_android, true, "is_android")
	t.ok(p.ads is AndroidAds, "ads")
	t.ok(p.iap is AndroidIap, "iap")
	t.ok(p.an is AndroidAn, "an")
	t.ok(p.rc is AndroidRc, "rc")
	t.ok(p.save is AndroidSave, "save")
	t.ok(p.notif is AndroidNotif, "notif")
	t.ok("init_sdks" in fake.log, "init_sdks được gọi")
	if "set_config" in fake.log:
		t.ok(fake.log.find("set_config") < fake.log.find("init_sdks"), "set_config trước init_sdks")
	t.eq(p.ready_rewarded(), true, "ready_rewarded qua plugin")
	t.eq(p.has_privacy, true, "has_privacy qua plugin")
	var seen := {"p": 0, "r": 0}
	p.paused.connect(func() -> void: seen["p"] += 1)
	p.resumed.connect(func() -> void: seen["r"] += 1)
	var r: Dictionary = await p.rewarded("pl")
	t.eq(r["ok"], true, "rewarded ok")
	t.eq(seen, {"p": 1, "r": 1}, "overlay phát paused rồi resumed")
	p.free()
	fake.free()


# --- chữ ký ---

func test_verify_signature(t: T) -> void:
	_keys()
	var data := "{\"productId\":\"remove_ads\",\"purchaseToken\":\"abc\"}"
	var sig := _sign(data)
	t.eq(AndroidIap.verify_purchase(data, sig, _pub_b64), true, "chữ ký đúng")
	t.eq(AndroidIap.verify_purchase(data.replace("abc", "abd"), sig, _pub_b64), false, "dữ liệu bị sửa")
	t.eq(AndroidIap.verify_purchase(data, "AAAA" + sig.substr(4), _pub_b64), false, "chữ ký bị sửa")
	t.eq(AndroidIap.verify_purchase(data, sig, ""), false, "thiếu khoá")
	t.eq(AndroidIap.verify_purchase(data, "", _pub_b64), false, "thiếu chữ ký")
	t.eq(AndroidIap.verify_purchase(data, sig, "not-a-key"), false, "khoá hỏng")
	var other := Crypto.new().generate_rsa(2048)
	var other_b64 := other.save_to_string(true).replace("-----BEGIN PUBLIC KEY-----", "") \
		.replace("-----END PUBLIC KEY-----", "").replace("\n", "").strip_edges()
	t.eq(AndroidIap.verify_purchase(data, sig, other_b64), false, "khoá khác")


# --- ads ---

func test_ads_flow(t: T) -> void:
	var f := FakePlugin.new()
	f.lost = PackedStringArray(["x2_coins"])
	var ads := AndroidAds.new(f)
	ads.timeout_scale = SCALE
	t.eq(ads.lost, ["x2_coins"], "lost lấy từ plugin")
	ads.lost_done()
	t.eq(ads.lost, [], "lost_done xoá")
	t.ok("lost_done" in f.log, "lost_done chuyển cho plugin")
	var ov := {"n": 0}
	ads.overlay_shown.connect(func() -> void: ov["n"] += 1)
	ads.overlay_hidden.connect(func() -> void: ov["n"] += 10)
	t.eq(await ads.rewarded("a"), {"ok": true, "reason": ""}, "rewarded ok")
	t.eq(ov["n"], 11, "overlay shown rồi hidden")
	f.rewarded_reply = [false, "closed"]
	t.eq(await ads.rewarded("a"), {"ok": false, "reason": "closed"}, "đóng sớm")
	f.rewarded_reply = [false, "zzz"]
	t.eq(await ads.rewarded("a"), {"ok": false, "reason": "error"}, "lý do lạ thành error")
	f.rewarded_ready = false
	t.eq(await ads.rewarded("a"), {"ok": false, "reason": "not_ready"}, "chưa sẵn sàng")
	f.rewarded_reply = [true, ""]
	t.eq(ads.rewarded_loaded, false, "rewarded_loaded theo plugin")
	f.rewarded_ready = true
	f.hang = true
	t.eq(await ads.rewarded("a"), {"ok": false, "reason": "error"}, "treo thì hết giờ, không kẹt")
	f.hang = false
	t.eq(await ads.rewarded("a"), {"ok": true, "reason": ""}, "dùng lại được sau khi hết giờ")
	t.eq(await ads.inter("i"), {"shown": true}, "inter hiện")
	f.inter_reply = false
	t.eq(await ads.inter("i"), {"shown": false}, "inter không hiện")
	f.inter_ready = false
	t.eq(await ads.inter("i"), {"shown": false}, "inter chưa sẵn sàng")
	ads.load_ads()
	t.ok("load_ads" in f.log, "load_ads")
	t.ok(ads.calls.size() >= 8, "nhật ký calls")


# --- iap ---

func test_iap_buy_ok_and_prices(t: T) -> void:
	_keys()
	var b := _billing()
	var iap := _iap(b, _pub_b64)
	t.eq(iap.price("gold_pack_1"), "VND 99.000", "giá từ Play")
	t.eq(iap.price("level_pack"), "$4.99", "SKU chưa có trên Play: giá USD dự phòng")
	b.buy_reply = _buy_reply([_purchase("gold_pack_1", "tok1")])
	var r := await iap.buy("gold_pack_1")
	t.eq(r, {"status": "ok", "sku": "gold_pack_1", "token": "tok1", "order_id": "GPA.tok1"}, "buy ok")
	t.eq(iap.pending().size(), 1, "đơn vào pending")
	iap.finish(r, true)
	t.eq(iap.pending().size(), 0, "finish gỡ khỏi pending")
	t.eq(b.consumed, ["tok1"], "consumable: consume")
	t.eq(b.acked, [], "consumable: không acknowledge riêng")
	b.buy_reply = _buy_reply([_purchase("remove_ads", "tok2")])
	r = await iap.buy("remove_ads")
	t.eq(str(r["status"]), "ok", "remove_ads ok")
	iap.finish(r, false)
	await Engine.get_main_loop().process_frame
	t.eq(b.acked, ["tok2"], "một lần: acknowledge")
	t.eq(b.consumed, ["tok1"], "một lần: không consume")
	t.eq(iap.calls.size(), 2, "nhật ký calls")


func test_iap_invalid_pending_cancel_error(t: T) -> void:
	_keys()
	var b := _billing()
	var iap := _iap(b, _pub_b64)
	b.buy_reply = _buy_reply([_purchase("gold_pack_1", "tokx", 1, false, true)])
	var r := await iap.buy("gold_pack_1")
	t.eq(str(r["status"]), "invalid", "chữ ký sai là invalid")
	t.eq(iap.pending().size(), 0, "đơn invalid không vào pending")
	t.eq(b.consumed, [], "đơn invalid không consume")
	b.buy_reply = _buy_reply([_purchase("gold_pack_1", "tokp", 2)])
	r = await iap.buy("gold_pack_1")
	t.eq(str(r["status"]), "pending", "đơn chờ")
	t.eq(str(r["token"]), "", "đơn chờ không token")
	t.eq(iap.pending().size(), 0, "đơn chờ không vào pending")
	b.buy_reply = {"response_code": 1, "debug_message": ""}
	t.eq(str((await iap.buy("gold_pack_1"))["status"]), "cancel", "huỷ")
	b.buy_reply = {"response_code": 6, "debug_message": ""}
	t.eq(str((await iap.buy("gold_pack_1"))["status"]), "error", "lỗi khác")
	b.start_reply = {"response_code": 3, "debug_message": ""}
	t.eq(str((await iap.buy("gold_pack_1"))["status"]), "error", "không mở được luồng mua")
	b.start_reply = {"response_code": 0}
	t.eq(str((await iap.buy("no_such_sku"))["status"]), "error", "SKU lạ")
	t.eq(str((await iap.buy("level_pack"))["status"]), "error", "SKU chưa tạo trên Play")
	b.hang_buy = true
	t.eq(str((await iap.buy("gold_pack_1"))["status"]), "error", "luồng mua treo thì hết giờ")
	b.hang_buy = false
	b.buy_reply = _buy_reply([_purchase("gold_pack_1", "tok9")])
	t.eq(str((await iap.buy("gold_pack_1"))["status"]), "ok", "mua lại được sau khi hết giờ")


func test_iap_missing_key_accepts(t: T) -> void:
	var b := _billing()
	var iap := _iap(b, "")
	b.buy_reply = _buy_reply([_purchase("gold_pack_1", "tokk", 1, false, true)])
	t.eq(str((await iap.buy("gold_pack_1"))["status"]), "ok", "thiếu public key thì chấp nhận đơn")


func test_iap_connect_failure_is_safe(t: T) -> void:
	var b := _billing()
	b.ready = false
	b.connect_ok = false
	var iap := _iap(b, "")
	t.eq(str((await iap.buy("gold_pack_1"))["status"]), "error", "không kết nối được")
	t.eq(await iap.restore(), false, "restore khi không kết nối")
	t.eq(iap.pending(), [], "pending rỗng")


func test_iap_already_owned(t: T) -> void:
	_keys()
	var b := _billing()
	var iap := _iap(b, _pub_b64)
	# Một lần đã sở hữu: owned.
	b.owned = [_purchase("remove_ads", "tokr", 1, true)]
	b.buy_reply = {"response_code": 7, "debug_message": ""}
	t.eq(str((await iap.buy("remove_ads"))["status"]), "owned", "một lần đã sở hữu")
	# Consumable trả tiền chưa giao: giao luôn bằng đơn treo.
	b.owned = [_purchase("gold_pack_1", "tokg", 1, false)]
	var r := await iap.buy("gold_pack_1")
	t.eq(str(r["status"]), "ok", "consumable chưa giao thì giao")
	t.eq(str(r["token"]), "tokg", "đúng token đơn treo")


func test_iap_boot_pending(t: T) -> void:
	_keys()
	var b := _billing()
	b.owned = [_purchase("gold_pack_1", "tb1"), _purchase("gold_pack_2", "tb2", 2), _purchase("unknown_sku", "tb3")]
	var iap := AndroidIap.new(null, b)
	iap.timeout_scale = SCALE
	t.eq(iap.pending().size(), 1, "mở game: chỉ đơn đã trả tiền, SKU của game")
	t.eq(str(iap.pending()[0]["token"]), "tb1", "đúng đơn")


func test_iap_restore(t: T) -> void:
	_keys()
	var b := _billing()
	var iap := _iap(b, _pub_b64)
	b.owned = [_purchase("gold_pack_1", "tp1"), _purchase("remove_ads", "tp2", 1, true),
		_purchase("gold_pack_2", "tp3", 2), _purchase("gold_pack_3", "tp4", 1, false, true),
		_purchase("unknown_sku", "tp5")]
	t.eq(await iap.restore(), true, "restore thấy remove_ads")
	var toks: Array = []
	for p in iap.pending():
		toks.append(str(p["token"]))
	toks.sort()
	t.eq(toks, ["tp1", "tp2"], "pending: chỉ đơn hợp lệ, đã trả tiền, SKU của game")
	for p in iap.pending():
		iap.finish(p, str(p["sku"]) != "remove_ads")
	await Engine.get_main_loop().process_frame
	t.eq(b.consumed, ["tp1"], "consume đơn consumable")
	t.eq(b.acked, [], "remove_ads đã acknowledge từ Play: không gọi lại")
	# Làm mới thường không đưa lại món một lần đã giao; restore thì có.
	await iap._refresh_purchases(false)
	t.eq(iap.pending().size(), 0, "không giao lại khi làm mới thường")
	t.eq(await iap.restore(), true, "restore lần nữa")
	t.eq(iap.pending().size(), 1, "restore đưa lại remove_ads")
	b.owned = []
	t.eq(await iap.restore(), false, "không có gì để restore")


func test_iap_unsolicited_purchase_goes_to_pending(t: T) -> void:
	_keys()
	var b := _billing()
	var iap := _iap(b, _pub_b64)
	b.on_purchase_updated.emit(_buy_reply([_purchase("rescue_pack", "tokq")]))
	t.eq(iap.pending().size(), 1, "đơn đến ngoài buy vào pending")
	t.eq(str(iap.pending()[0]["sku"]), "rescue_pack", "đúng sku")
	b.on_purchase_updated.emit(_buy_reply([_purchase("rescue_pack", "tokq")]))
	t.eq(iap.pending().size(), 1, "không trùng token")


func test_iap_finish_failure_keeps_order_for_next_boot(t: T) -> void:
	_keys()
	var b := _billing()
	b.finish_code = 6
	var iap := _iap(b, _pub_b64)
	b.buy_reply = _buy_reply([_purchase("gold_pack_1", "tokf")])
	var r := await iap.buy("gold_pack_1")
	iap.finish(r, true)
	await Engine.get_main_loop().process_frame
	t.eq(b.consumed, ["tokf"], "đã thử consume")
	b.owned = [_purchase("gold_pack_1", "tokf")]
	await iap._refresh_purchases(false)
	t.eq(iap.pending().size(), 1, "consume lỗi: đơn còn ở Play nên giao lại")


# --- rc, an, notif ---

func test_rc(t: T) -> void:
	var f := FakePlugin.new()
	var rc := AndroidRc.new(f)
	rc.timeout_scale = SCALE
	t.eq(rc.values, {"a": "1"}, "giá trị hiện có là chuỗi")
	await rc.fetch()
	t.eq(rc.values, {"x": "5", "y": "s"}, "fetch thay giá trị, đều là chuỗi")
	t.eq(rc.fetch_count, 1, "fetch_count")
	f.hang = true
	f.rc_json = "{\"k\":true}"
	await rc.fetch()
	t.eq(rc.values, {"k": "true"}, "hết giờ thì dùng giá trị đang hiệu lực")
	f.hang = false
	f.rc_reply = "không phải json"
	await rc.fetch()
	t.eq(rc.values, {"k": "true"}, "trả lời hỏng thì giữ nguyên")
	rc.set_values({"a": 1})
	t.eq(rc.values, {"a": "1"}, "set_values")


func test_an(t: T) -> void:
	var f := FakePlugin.new()
	var an := AndroidAn.new(f)
	an.log_event("level_win", {"level": 3, "t": 1.5, "ok": true, "s": "x", "n": null, "arr": [1, 2]})
	var e: Array = f.events[0]
	t.eq(e[0], "level_win", "tên sự kiện")
	var d: Dictionary = JSON.parse_string(e[1])
	t.eq(d, {"level": 3.0, "t": 1.5, "ok": true, "s": "x", "arr": "[1, 2]"}, "tham số phẳng")
	an.earn("gold", 50, "level")
	an.spend("gold", 20, "hint")
	t.eq(f.events[1][0], "earn", "earn")
	t.eq(JSON.parse_string(f.events[2][1]), {"currency": "gold", "amount": 20.0, "sink": "hint"}, "spend")
	an.user({"level": 7, "build": "b1"})
	t.eq(JSON.parse_string(f.props[0]), {"level": "7", "build": "b1"}, "user props là chuỗi")
	t.eq(an.user_props["level"], 7, "user_props giữ bản địa phương")


func test_notif(t: T) -> void:
	var f := FakePlugin.new()
	var n := AndroidNotif.new(f)
	n.timeout_scale = SCALE
	t.eq(n.enabled(), false, "chưa cho phép")
	t.eq(n.granted, false, "granted theo enabled")
	f.notif_on = true
	t.eq(await n.ask(), true, "cho phép")
	t.eq(n.asked, true, "asked")
	f.notif_grant = false
	t.eq(await n.ask(), false, "từ chối")
	f.hang = true
	f.notif_on = false
	t.eq(await n.ask(), false, "treo thì hết giờ")
	n.schedule([{"at": 100, "kind": "daily_gift", "title": "T", "body": "B"}, "bỏ qua"])
	t.eq(n.scheduled.size(), 1, "scheduled")
	var arr: Array = JSON.parse_string(f.sched[0])
	t.eq(arr.size(), 1, "gửi một mục")
	t.eq(arr[0]["kind"], "daily_gift", "kind")
	t.eq(int(arr[0]["at"]), 100, "at")
	n.cancel_all()
	t.eq(n.scheduled.size(), 0, "cancel_all")
	t.ok("notif_cancel_all" in f.log, "plugin nhận cancel_all")


# --- save ---

func _save(f: FakePlugin, name: String) -> AndroidSave:
	DirAccess.make_dir_recursive_absolute(DIR)
	var path := "%s/%s.json" % [DIR, name]
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var s := AndroidSave.new(f)
	s.cache_path = path
	s.timeout_scale = SCALE
	return s


func test_save_sync_and_push(t: T) -> void:
	var f := FakePlugin.new()
	var s := _save(f, "push")
	s.mirror("{\"runs\":2}")
	t.eq(f.saved, [], "chưa đồng bộ thì không đẩy lên")
	f.cloud_reply = ["", true]
	await s.sync_cloud()
	await Engine.get_main_loop().process_frame
	t.ok("cloud_load" in f.log, "cloud_load")
	t.eq(f.saved, ["{\"runs\":2}"], "cloud trống: đẩy bản local đã chờ")
	s.mirror("{\"runs\":3}")
	await Engine.get_main_loop().process_frame
	t.eq(f.saved.size(), 2, "mirror sau đồng bộ thì đẩy")
	t.eq(s.backup(), "{\"runs\":3}", "backup giữ bản đã đẩy")
	s.flush()
	t.eq(s.flush_count, 1, "flush_count")
	t.eq(s.mirror_count, 2, "mirror_count")
	t.eq(s.last_json, "{\"runs\":3}", "last_json")


func test_save_does_not_overwrite_newer_cloud(t: T) -> void:
	var f := FakePlugin.new()
	var s := _save(f, "ahead")
	f.cloud_reply = ["{\"runs\":9,\"play_ms\":5}", true]
	s.mirror("{\"runs\":0}")
	await s.sync_cloud()
	await Engine.get_main_loop().process_frame
	t.eq(f.saved, [], "local thua cloud: không ghi đè")
	t.eq(s.cloud_json, "{\"runs\":9,\"play_ms\":5}", "cloud_json cho Game đọc")
	t.eq(JSON.parse_string(s.backup()), {"runs": 9.0, "play_ms": 5.0}, "backup trả bản cloud")
	s.mirror("{\"runs\":10}")
	await Engine.get_main_loop().process_frame
	t.eq(f.saved, ["{\"runs\":10}"], "local vượt cloud thì đẩy")
	# Phiên sau đọc lại bản lưu tạm.
	var s2 := AndroidSave.new(f, s.cache_path)
	t.eq(s2.backup(), "{\"runs\":10}", "backup còn sau khi khởi động lại")


## Menu tester xoá tài khoản: bản cloud cũ (chơi xa hơn) không được khôi phục mà bị bản mới ghi đè.
func test_save_wipe_overwrites_cloud(t: T) -> void:
	var f := FakePlugin.new()
	var s := _save(f, "wipe")
	f.cloud_reply = ["{\"runs\":9}", true]
	await s.sync_cloud()
	await Engine.get_main_loop().process_frame
	t.ok(FileAccess.file_exists(s.cache_path), "có bản lưu tạm cloud")
	s.wipe()
	t.eq(s.backup(), "", "backup rỗng sau khi xoá")
	t.eq(s.cloud_json, "", "cloud_json rỗng")
	t.ok(not FileAccess.file_exists(s.cache_path), "xoá bản lưu tạm")
	s.mirror("{\"runs\":0}")
	s.flush()
	await Engine.get_main_loop().process_frame
	t.eq(f.saved, ["{\"runs\":0}"], "đẩy tài khoản mới đè bản cloud")
	# Xoá trước khi đồng bộ: bản cloud tải về sau bị bỏ qua.
	var f2 := FakePlugin.new()
	var s2 := _save(f2, "wipe_early")
	f2.cloud_reply = ["{\"runs\":9}", true]
	s2.wipe()
	s2.mirror("{\"runs\":0}")
	var got: Array = []
	s2.cloud_synced.connect(func(j: String) -> void: got.append(j))
	await s2.sync_cloud()
	await Engine.get_main_loop().process_frame
	t.eq(got, [""], "không đưa bản cloud cũ cho Game")
	t.eq(f2.saved, ["{\"runs\":0}"], "đẩy tài khoản mới")


func test_save_conflict_merges_buys(t: T) -> void:
	var f := FakePlugin.new()
	var s := _save(f, "conflict")
	var win := {"runs": 5, "no_ads": false, "buys": [{"token": "a", "sku": "gold_pack_1"}]}
	var lose := {"runs": 2, "no_ads": true, "buys": [{"token": "b", "sku": "remove_ads"}, {"token": "a", "sku": "gold_pack_1"}]}
	f.cloud_reply = [JSON.stringify(win), true]
	f.cloud_loser = JSON.stringify(lose)
	await s.sync_cloud()
	await Engine.get_main_loop().process_frame
	t.ok(f.saved.size() >= 1, "ghi bản đã gộp")
	var merged: Dictionary = JSON.parse_string(f.saved[0])
	var toks: Array = []
	for e in merged["buys"]:
		toks.append(e["token"])
	t.eq(toks, ["a", "b"], "gộp buys theo token")
	t.eq(merged["no_ads"], true, "no_ads giữ true")
	t.eq(int(merged["runs"]), 5, "giữ bản thắng")


func test_save_sync_failures_are_safe(t: T) -> void:
	var f := FakePlugin.new()
	var s := _save(f, "fail")
	f.cloud_reply = ["", false]
	s.mirror("{\"runs\":1}")
	await s.sync_cloud()
	t.eq(f.saved, [], "đồng bộ lỗi: không đẩy")
	f.hang = true
	var s2 := _save(f, "hang")
	await s2.sync_cloud()
	t.eq(s2.cloud_json, "", "treo thì hết giờ, không kẹt")
