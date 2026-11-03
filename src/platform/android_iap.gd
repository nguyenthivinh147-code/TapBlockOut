extends RefCounted
## Mua hàng thật (plugin GodotGooglePlayBilling 3.3.0, singleton "GodotGooglePlayBilling").
## Cùng hàm với mock_iap.gd. Xem docs/BILLING_NOTES.md. Thiếu singleton (desktop, bản demo, bản
## build không kèm plugin) thì price() trả "" và buy() trả `error`, không crash.
##
## Đơn hợp lệ (chữ ký đúng, đã trả tiền) vào hàng đợi `pending()`; Game giao hàng rồi gọi `finish`.
## `finish` consume (consumable) hoặc acknowledge (một lần). Thất bại thì đơn còn nguyên ở Play
## và lần mở game sau lại vào `pending()` (Game chống giao hai lần bằng `buys`).

signal overlay_shown
signal overlay_hidden

const Config := preload("res://src/config.gd")
const BillingClientScript := preload("res://addons/GodotGooglePlayBilling/BillingClient.gd")

const SINGLETON := "GodotGooglePlayBilling"
const CONFIG_PATH := "res://android_config.json"
const CONNECT_TIMEOUT := 15.0
const QUERY_TIMEOUT := 20.0
const FINISH_TIMEOUT := 20.0
## Luồng mua có giao diện Play nên đợi lâu; hết hạn thì đơn (nếu về muộn) vào pending().
const BUY_TIMEOUT := 600.0
const CALLS_MAX := 50

const RC_OK := 0
const RC_USER_CANCELED := 1
const RC_ITEM_ALREADY_OWNED := 7
const RC_ITEM_NOT_OWNED := 8
const STATE_PURCHASED := 1
const STATE_PENDING := 2
const PRODUCT_INAPP := 0

## Khoá công khai base64 (DER X.509) của Play Console, đọc từ billing_public_key trong config.
## Trống thì đơn được chấp nhận không kiểm (demo/nội bộ), có ghi log một lần.
var public_key: String = ""
## Nhân với mọi hạn chờ (test đặt nhỏ).
var timeout_scale: float = 1.0
## Chỉ có ở mock; Android bỏ qua.
var overlay_enabled: bool = false
var persist_path: String = ""
## Nhật ký giống mock: [{sku, status}]
var calls: Array[Dictionary] = []

var _plugin: Object = null
var _bc: Object = null
var _prices: Dictionary = {}
var _pending: Array[Dictionary] = []
var _finishing: Dictionary = {}  # token -> true, đang consume/acknowledge
var _delivered_once: Dictionary = {}  # token món một lần đã finish trong phiên (không đưa lại trừ restore)
var _acked: Dictionary = {}  # token -> true nếu Play báo đã acknowledge
var _busy: bool = false
var _buy_wait: Dictionary = {}
var _connecting: bool = false
var _refreshing: bool = false
var _warned_no_key: bool = false


## `billing` dành cho test (giả lập BillingClient). Thường để trống: tự tạo khi có singleton.
func _init(plugin: Object = null, billing: Object = null) -> void:
	_plugin = plugin
	public_key = _read_public_key()
	_bc = billing
	if _bc == null and Engine.has_singleton(SINGLETON):
		_bc = BillingClientScript.new()
	if _bc == null:
		return
	_bc.connect("on_purchase_updated", _on_purchase_updated)
	_boot()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _bc is Node and not (_bc as Node).is_inside_tree():
		(_bc as Node).free()


## Mock dùng để ép kết quả khi test; Android bỏ qua.
func simulate(_result: Variant) -> void:
	pass


func load_state() -> void:
	pass


## Mock forgets its purchases on "delete account"; Google Play keeps real ones (Restore brings them back).
func wipe() -> void:
	pass


func price(sku: String) -> String:
	if _bc == null:
		return ""
	if _prices.has(sku):
		return str(_prices[sku])
	var info: Dictionary = Config.SKUS.get(sku, {})
	return "$%.2f" % float(info.get("usd", 0.0)) if not info.is_empty() else ""


func buy(sku: String) -> Dictionary:
	var res := _result("error", sku)
	if not Config.SKUS.has(sku) or _bc == null or _busy:
		return _logged(res)
	_busy = true
	res = await _buy(sku)
	_busy = false
	return _logged(res)


func pending() -> Array:
	return _pending.duplicate(true)


func finish(p: Dictionary, consumable: bool) -> void:
	var token := str(p.get("token", ""))
	for i in range(_pending.size() - 1, -1, -1):
		if str(_pending[i].get("token", "")) == token:
			_pending.remove_at(i)
	if token == "" or _bc == null:
		return
	if not consumable:
		_delivered_once[token] = true
	if not _finishing.has(token):
		_finish_async(token, consumable)


## Hỏi Play các món đang sở hữu rồi đưa lại món mua một lần vào pending(). true nếu có món hợp lệ.
func restore() -> bool:
	if _bc == null:
		return false
	_delivered_once.clear()
	var found := await _refresh_purchases(true)
	return found


## Platform gọi khi app quay lại: đơn treo hoàn tất khi app ở nền thì vào pending().
func on_resume() -> void:
	if _bc != null and not _busy:
		_refresh_purchases(false)


## Kiểm chữ ký Play: RSA PKCS#1 v1.5 + SHA-1 trên đúng chuỗi `original_json`.
static func verify_purchase(original_json: String, signature_b64: String, public_key_b64: String) -> bool:
	if public_key_b64.strip_edges().is_empty() or signature_b64.strip_edges().is_empty():
		return false
	if not _is_base64(public_key_b64.strip_edges()) or not _is_base64(signature_b64.strip_edges()):
		return false
	var der := Marshalls.base64_to_raw(public_key_b64.strip_edges())
	if der.size() < 32 or der[0] != 0x30:  # không phải DER (SEQUENCE): tránh lỗi in ra log
		return false
	var pem := "-----BEGIN PUBLIC KEY-----\n" + public_key_b64.strip_edges() + "\n-----END PUBLIC KEY-----\n"
	var key := CryptoKey.new()
	if key.load_from_string(pem, true) != OK:
		return false
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA1)
	ctx.update(original_json.to_utf8_buffer())
	return Crypto.new().verify(HashingContext.HASH_SHA1, ctx.finish(),
			Marshalls.base64_to_raw(signature_b64.strip_edges()), key)


## Kiểm trước để base64_to_raw không in lỗi ra log khi gặp chuỗi hỏng.
static func _is_base64(s: String) -> bool:
	if s.is_empty() or s.length() % 4 != 0:
		return false
	var re := RegEx.create_from_string("^[A-Za-z0-9+/]+={0,2}$")
	return re.search(s) != null


# --- mua ---

func _buy(sku: String) -> Dictionary:
	if not await _ensure_connected():
		return _result("error", sku)
	if not _prices.has(sku):
		await _query_details([sku])
		if not _prices.has(sku):
			return _result("error", sku)  # SKU chưa có trên Play Console
	_buy_wait = _arm([Signal(_bc, &"on_purchase_updated")])
	var started: Variant = _bc.purchase(sku)
	var start_code := int(started.get("response_code", -99)) if started is Dictionary else -99
	if start_code != RC_OK:
		_disarm(_buy_wait)
		_buy_wait = {}
		return await _from_code(sku, start_code)
	overlay_shown.emit()
	var got := await _until(_buy_wait, BUY_TIMEOUT)
	_buy_wait = {}
	overlay_hidden.emit()
	if got.is_empty():
		return _result("error", sku)
	var resp: Dictionary = got["args"][0]
	var code := int(resp.get("response_code", -99))
	if code != RC_OK:
		return await _from_code(sku, code)
	var out := _result("error", sku)
	for pu in resp.get("purchases", []):
		var r := _ingest(pu)
		if not r.is_empty() and str(r["sku"]) == sku:
			out = r
	return out


## Mã lỗi Play -> status.
func _from_code(sku: String, code: int) -> Dictionary:
	if code == RC_USER_CANCELED:
		return _result("cancel", sku)
	if code == RC_ITEM_ALREADY_OWNED:
		await _refresh_purchases(false)
		var info: Dictionary = Config.SKUS.get(sku, {})
		if bool(info.get("consumable", true)):
			# Đã trả tiền nhưng chưa giao: giao luôn.
			for p in _pending:
				if str(p.get("sku", "")) == sku:
					return p.duplicate()
		return _result("owned", sku)
	return _result("error", sku)


# --- đơn ---

## Kiểm một purchase của Play. Trả {} nếu bỏ qua (SKU lạ, đang xử lý, hết hiệu lực),
## ngược lại {status, sku, token, order_id}. Chỉ `ok` mới vào pending().
func _ingest(pu: Variant, force: bool = false) -> Dictionary:
	if not (pu is Dictionary):
		return {}
	var skus: Array = pu.get("product_ids", [])
	var sku := str(skus[0]) if not skus.is_empty() else ""
	if not Config.SKUS.has(sku):
		return {}
	var token := str(pu.get("purchase_token", ""))
	var order_id := str(pu.get("order_id", ""))
	var state := int(pu.get("purchase_state", 0))
	if state == STATE_PENDING:
		return {"status": "pending", "sku": sku, "token": "", "order_id": order_id}
	if state != STATE_PURCHASED or token == "":
		return {}
	if not _valid(pu, sku, token):
		return {"status": "invalid", "sku": sku, "token": token, "order_id": order_id}
	var rec := {"status": "ok", "sku": sku, "token": token, "order_id": order_id}
	if bool(pu.get("is_acknowledged", false)):
		_acked[token] = true
	if _finishing.has(token) or (_delivered_once.has(token) and not force):
		return rec
	for p in _pending:
		if str(p.get("token", "")) == token:
			return rec
	_pending.append(rec)
	return rec


func _valid(pu: Dictionary, sku: String, token: String) -> bool:
	if public_key == "":
		if not _warned_no_key:
			_warned_no_key = true
			print("[android_iap] thiếu billing_public_key: nhận đơn không kiểm chữ ký")
		return true
	var orig := str(pu.get("original_json", ""))
	if not verify_purchase(orig, str(pu.get("signature", "")), public_key):
		return false
	# Sau khi chữ ký đúng: các trường game đọc phải khớp với chuỗi Play đã ký.
	var j := JSON.new()
	if j.parse(orig) != OK or not (j.data is Dictionary):
		return false
	var d: Dictionary = j.data
	if str(d.get("productId", "")) != sku or str(d.get("purchaseToken", "")) != token:
		return false
	var pkg := str(pu.get("package_name", ""))
	return str(d.get("packageName", pkg)) == pkg


func _on_purchase_updated(resp: Dictionary) -> void:
	if not _buy_wait.is_empty():
		return  # buy() đang đợi và tự xử lý
	if int(resp.get("response_code", -99)) != RC_OK:
		return
	for pu in resp.get("purchases", []):
		_ingest(pu)


## Trả true nếu thấy món mua một lần hợp lệ (cho restore). `force` đưa lại cả món đã giao trong phiên.
func _refresh_purchases(force: bool) -> bool:
	if _bc == null or not await _ensure_connected():
		return false
	while _refreshing:
		await _next_frame()
	_refreshing = true
	var w := _arm([Signal(_bc, &"query_purchases_response")])
	_bc.query_purchases(PRODUCT_INAPP)
	var got := await _until(w, QUERY_TIMEOUT)
	_refreshing = false
	if got.is_empty():
		return false
	var resp: Dictionary = got["args"][0]
	if int(resp.get("response_code", -99)) != RC_OK:
		return false
	var found := false
	for pu in resp.get("purchases", []):
		var r := _ingest(pu, force)
		if r.is_empty() or str(r["status"]) != "ok":
			continue
		if not bool(Config.SKUS.get(str(r["sku"]), {}).get("consumable", true)):
			found = true
	return found


func _finish_async(token: String, consumable: bool) -> void:
	_finishing[token] = true
	if consumable:
		await _finish_call(token, "consume_purchase", &"consume_purchase_response")
	elif not _acked.has(token):
		await _finish_call(token, "acknowledge_purchase", &"acknowledge_purchase_response")
	_finishing.erase(token)


func _finish_call(token: String, method: String, sig: StringName) -> void:
	if not await _ensure_connected():
		return
	var w := _arm([Signal(_bc, sig)], func(a: Array) -> bool:
		return a[0] is Dictionary and str(a[0].get("token", "")) == token)
	_bc.call(method, token)
	var got := await _until(w, FINISH_TIMEOUT)
	if got.is_empty():
		return
	var code := int((got["args"][0] as Dictionary).get("response_code", -99))
	if code == RC_OK or code == RC_ITEM_NOT_OWNED:
		_acked[token] = true


# --- kết nối ---

func _boot() -> void:
	if not await _ensure_connected():
		return
	await _query_details(PackedStringArray(Config.SKUS.keys()))
	await _refresh_purchases(false)


func _ensure_connected() -> bool:
	if _bc == null:
		return false
	if _bc.is_ready():
		return true
	while _connecting:
		await _next_frame()
	if _bc.is_ready():
		return true
	_connecting = true
	var w := _arm([Signal(_bc, &"connected"), Signal(_bc, &"connect_error")])
	_bc.start_connection()
	var got := await _until(w, CONNECT_TIMEOUT)
	_connecting = false
	return not got.is_empty() and int(got["i"]) == 0 and bool(_bc.is_ready())


func _query_details(ids: PackedStringArray) -> void:
	var w := _arm([Signal(_bc, &"query_product_details_response")])
	_bc.query_product_details(ids, PRODUCT_INAPP)
	var got := await _until(w, QUERY_TIMEOUT)
	if got.is_empty():
		return
	var resp: Dictionary = got["args"][0]
	if int(resp.get("response_code", -99)) != RC_OK:
		return
	for d in resp.get("product_details", []):
		if not (d is Dictionary):
			continue
		var offers: Variant = d.get("one_time_purchase_offer_details_list")
		if offers is Array and not (offers as Array).is_empty():
			var txt := str(offers[0].get("formatted_price", ""))
			if txt != "":
				_prices[str(d.get("product_id", ""))] = txt


# --- tiện ích ---

func _read_public_key() -> String:
	if not FileAccess.file_exists(CONFIG_PATH):
		return ""
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(CONFIG_PATH)) != OK or not (j.data is Dictionary):
		return ""
	var key := str(j.data.get("billing_public_key", "")).strip_edges()
	# Cùng quy ước với plugin: rỗng hoặc chỗ giữ chỗ coi là thiếu.
	for bad in ["YOUR_", "REPLACE", "<", "TODO"]:
		if key.begins_with(bad):
			return ""
	return key


func _result(status: String, sku: String) -> Dictionary:
	return {"status": status, "sku": sku, "token": "", "order_id": ""}


func _logged(res: Dictionary) -> Dictionary:
	calls.append({"sku": str(res.get("sku", "")), "status": str(res.get("status", ""))})
	if calls.size() > CALLS_MAX:
		calls.pop_front()
	return res


func _next_frame() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		await tree.process_frame


func _arm(sigs: Array, filter: Callable = Callable()) -> Dictionary:
	var w := {"done": false, "i": -1, "args": [], "cbs": [], "sigs": sigs}
	for i in sigs.size():
		var idx := i
		var cb := func(...args: Array) -> void:
			if bool(w["done"]):
				return
			if filter.is_valid() and not bool(filter.call(args)):
				return
			w["done"] = true
			w["i"] = idx
			w["args"] = args
		(sigs[i] as Signal).connect(cb)
		(w["cbs"] as Array).append(cb)
	return w


func _disarm(w: Dictionary) -> void:
	var sigs: Array = w.get("sigs", [])
	var cbs: Array = w.get("cbs", [])
	for i in cbs.size():
		if (sigs[i] as Signal).is_connected(cbs[i]):
			(sigs[i] as Signal).disconnect(cbs[i])
	w["cbs"] = []  # cắt vòng tham chiếu lambda <-> w


## {"i", "args"} khi có signal, {} khi hết giờ. Sau hạn còn đợi thêm một khung hình
## để signal xếp hàng lúc app ở nền kịp được giao.
func _until(w: Dictionary, timeout_s: float) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var limit := Time.get_ticks_msec() + int(timeout_s * timeout_scale * 1000.0)
	var late := false
	while tree != null and not bool(w["done"]):
		if Time.get_ticks_msec() >= limit:
			if late:
				break
			late = true
		await tree.process_frame
	_disarm(w)
	if not bool(w["done"]):
		return {}
	return {"i": w["i"], "args": w["args"]}
