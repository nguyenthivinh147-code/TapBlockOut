extends RefCounted
## Kịch bản smoke cho luật UI chung (checklist [EDGE] của skill /game-testcase-generator, docs/TESTING.md "Ma trận
## bao phủ"). Gọi qua scenarios.gd SCEN_FILES; mỗi hàm nhận runner `r` (tests/smoke/smoke.gd).
##
## IDLE. Để yên lâu: Home, Shop rồi màn chơi, mỗi nơi đứng yên `stay` giây thật (SMOKE_ARGS="stay=1800" là 30 phút
## mỗi nơi; mặc định 60), không chạm. Mỗi nơi in SMOKE FRAMES của pha đứng yên và SMOKE MEM trước, sau; rồi kiểm game
## vẫn nhận chạm: ở Home, Settings mở rồi Back đóng; ở Shop, bấm tab Home về được Home; ở màn chơi, chơi thắng level. Fail khi có lỗi script hay
## engine, khi không chạm được, hoặc số object tăng quá IDLE_OBJECT_GROWTH trong lúc đứng yên. Chạy lâu thì nới hạn:
## SMOKE_TIMEOUT phải lớn hơn 3 * stay + 300.

const Scen := preload("res://tests/smoke/scenarios.gd")
const Saves := preload("res://tests/smoke/smoke_saves.gd")

## Object được phép tăng trong một pha đứng yên (tween, timer sinh rồi huỷ): hơn mức này là rò.
const IDLE_OBJECT_GROWTH := 200


static func run(r, scen: String) -> bool:
	match scen:
		"IDLE":
			return await scen_idle(r)
	return r.fail("không có kịch bản %s" % scen)


static func scen_idle(r) -> bool:
	var stay := float(r.args.get("stay", "60"))
	if not await r.open_game("IDLE", Callable(Saves, "all_unlocked")):
		return false
	if not await Scen.go_home_from_level(r):
		return false
	if not await _stay(r, "home", stay):
		return false
	if not await Scen.tap_named(r, "ShopButton", r.main.current_screen):
		return false
	if not await Scen.wait_for(r, func() -> bool: return r.screen_name() == "shop", 10000):
		return r.fail("bấm Shop không mở màn Shop")
	if not await _stay(r, "shop", stay):
		return false
	if not await Scen.back_home(r):
		return r.fail("đứng yên ở Shop rồi không về được Home")
	r.step("đứng yên ở Shop rồi vẫn bấm tab Home về được")
	await Scen.settle_all(r)
	if not await Scen.tap_named(r, "PlayButton", r.main.current_screen):
		return false
	if not await Scen.wait_for(r, func() -> bool: return Scen._playing(r) > 0, 20000):
		return r.fail("bấm Chơi không vào màn chơi")
	if not await _stay(r, "level", stay):
		return false
	return await Scen.verify_saved(r)


## Đứng yên `sec` giây thật ở `place` (màn đang hiện), rồi kiểm game còn nhận chạm.
static func _stay(r, place: String, sec: float) -> bool:
	await Scen.settle_all(r)
	await r.shot("idle_%s_start" % place)
	r.mem("idle %s trước" % place)
	var objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	r.step("đứng yên %d giây ở %s, không chạm" % [int(sec), place])
	r.begin_phase("idle %s" % place)
	await r.get_tree().create_timer(sec, true, false, true).timeout
	r.end_phase()
	r.mem("idle %s sau" % place)
	await r.shot("idle_%s_end" % place)
	var grew := int(Performance.get_monitor(Performance.OBJECT_COUNT)) - objects
	if grew > IDLE_OBJECT_GROWTH:
		return r.fail("đứng yên %d giây ở %s: object tăng %d (quá %d)" % [int(sec), place, grew, IDLE_OBJECT_GROWTH])
	if r.screen_name() != place:
		return r.fail("đứng yên ở %s mà màn tự đổi sang %s" % [place, r.screen_name()])
	if place == "level":
		if not await Scen.win_level(r):
			return r.fail("đứng yên ở màn chơi rồi không chơi tiếp được")
		r.step("đứng yên ở màn chơi rồi vẫn chơi thắng được")
		return true
	if place == "shop":
		# Shop has no Settings: the tap on the Home tab that follows (Scen.back_home) is the check.
		return true
	var before: int = r.main.popup_count()
	if not await Scen.tap_named(r, "SettingsButton", r.main.current_screen):
		return false
	if not await Scen.wait_for(r, func() -> bool: return r.main.popup_count() > before, 4000, "settings.gd"):
		return r.fail("đứng yên ở %s rồi bấm Settings không mở" % place)
	await r.wait_sec(0.6)
	await r.back()
	if not await Scen.wait_for(r, func() -> bool: return r.main.popup_count() <= before, 4000):
		return r.fail("đứng yên ở %s rồi Back không đóng Settings" % place)
	r.step("đứng yên ở %s rồi vẫn mở và đóng được Settings" % place)
	return true
