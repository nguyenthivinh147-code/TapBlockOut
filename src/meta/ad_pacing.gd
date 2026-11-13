extends RefCounted
## Interstitial `result_exit` pacing as the reference game (design.md mục 6): no Remove Ads, current level above
## ADS.inter_after_level, and ADS.inter_cooldown seconds on a clock that restarts at game entry, when an interstitial
## closes and when a rewarded pays out. No run spacing, no daily cap. Reads and writes s.ads only.

const Config := preload("res://src/config.gd")

const WHY_NONE := ""


## Why the interstitial is blocked; "" means it may show.
## ctx: {now, session_start, x2_taken}. The level is s.level, which goes up at the win, before the win card.
static func inter_why(s: Dictionary, ctx: Dictionary) -> String:
	if bool(s.get("no_ads", false)):
		return "no_ads"
	# x2 closes our win card by itself (no Claim press), so it never leads to an interstitial.
	if bool(ctx.get("x2_taken", false)):
		return "x2_taken"
	var cfg: Dictionary = Config.ADS
	if int(s.get("level", 1)) <= int(cfg.inter_after_level):
		return "level"
	var now: int = int(ctx.get("now", 0))
	if now - clock_start(s, ctx) < int(cfg.inter_cooldown):
		return "cooldown"
	return WHY_NONE


static func inter_due(s: Dictionary, ctx: Dictionary) -> bool:
	return inter_why(s, ctx) == WHY_NONE


## When the interstitial clock last restarted: game entry (session_start), or a later interstitial close or rewarded
## payout in this session. Times from an earlier session (before session_start) or after `now` (device clock set back)
## do not count.
static func clock_start(s: Dictionary, ctx: Dictionary) -> int:
	var a: Dictionary = s.get("ads", {})
	var now: int = int(ctx.get("now", 0))
	var start: int = int(ctx.get("session_start", 0))
	for k in ["last_inter_at", "last_rv_at"]:
		var at := int(a.get(k, 0))
		if at > start and at <= now:
			start = at
	return start


## Call after an interstitial showed and closed.
static func note_inter(s: Dictionary, now: int, day: int) -> void:
	var a: Dictionary = s.ads
	if int(a.get("inter_day", -1)) != day:
		a.inter_day = day
		a.inter_today = 0
	a.inter_today = int(a.get("inter_today", 0)) + 1
	a.last_inter_at = now


## Call when the player watched a rewarded to the end.
static func note_rewarded(s: Dictionary, now: int) -> void:
	s.ads.last_rv_at = now


static func inter_count_today(s: Dictionary, day: int) -> int:
	var a: Dictionary = s.get("ads", {})
	if int(a.get("inter_day", -1)) != day:
		return 0
	return int(a.get("inter_today", 0))
