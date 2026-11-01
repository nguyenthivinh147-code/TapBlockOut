extends RefCounted
## Nhịp interstitial `result_exit`. Viết lại theo monetize.interDue của Horus. Chỉ đọc/ghi s.ads.
## Số "lượt" là s.runs: Game phải tăng s.runs trước khi gọi inter_due/note_inter.

const Config := preload("res://src/config.gd")

const WHY_NONE := ""


## Lý do chặn, "" nghĩa là đến lượt hiện interstitial.
## ctx: {now, session_start, first_session, level, x2_offered, x2_taken, day}
## level là level vừa xong ở thẻ thắng; phiên đầu chỉ có quảng cáo khi level > first_session_block_until_level.
static func inter_why(s: Dictionary, ctx: Dictionary) -> String:
	if bool(s.get("no_ads", false)):
		return "no_ads"
	var a: Dictionary = s.get("ads", {})
	var cfg: Dictionary = Config.ADS
	var now: int = int(ctx.get("now", 0))
	var runs: int = int(s.get("runs", 0))
	if bool(ctx.get("x2_taken", false)):
		return "x2_taken"
	if bool(ctx.get("first_session", false)) and int(ctx.get("level", 0)) <= int(cfg.first_session_block_until_level):
		return "first_session"
	if runs < int(cfg.inter_from_run):
		return "early"
	if runs - int(a.get("last_inter_run", -99)) < int(cfg.inter_every):
		return "every"
	if now - int(ctx.get("session_start", 0)) < int(cfg.session_warmup):
		return "warmup"
	if now - int(a.get("last_inter_at", 0)) <= int(cfg.inter_cooldown):
		return "cooldown"
	if now - int(a.get("last_rv_at", 0)) <= int(cfg.rewarded_grace):
		return "rewarded"
	return WHY_NONE


static func inter_due(s: Dictionary, ctx: Dictionary) -> bool:
	return inter_why(s, ctx) == WHY_NONE


## Gọi sau khi interstitial đã hiện.
static func note_inter(s: Dictionary, now: int, day: int) -> void:
	var a: Dictionary = s.ads
	if int(a.get("inter_day", -1)) != day:
		a.inter_day = day
		a.inter_today = 0
	a.inter_today = int(a.get("inter_today", 0)) + 1
	a.last_inter_run = int(s.get("runs", 0))
	a.last_inter_at = now


## Gọi khi người chơi xem hết rewarded.
static func note_rewarded(s: Dictionary, now: int) -> void:
	s.ads.last_rv_at = now


static func inter_count_today(s: Dictionary, day: int) -> int:
	var a: Dictionary = s.get("ads", {})
	if int(a.get("inter_day", -1)) != day:
		return 0
	return int(a.get("inter_today", 0))
