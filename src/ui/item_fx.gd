extends "res://src/ui/coin_fx.gd"
## One reward item (a booster, lives) flying from its icon into its counter (RewardFly), in the look of CoinFx's gold
## coins: the icon swells to POP_SCALE at its source, flies on a curve with the light trail and star dust, shrinks to
## LAND_SCALE of the target icon and lands with the flash and star burst. Unlike a coin it does not flip, and it keeps
## its picture's aspect. start_item(), then the CoinFx callbacks: on_land(amount, true) once.

const POP_SCALE := 1.2
const LAND_SCALE := 0.75
## Landing flash and rings at this part of a coin's last landing: the target (a tab, a booster button) is larger
## than a gold chip's coin.
const FINALE := 0.5

var _from_px := 64.0


## `from` is the item's icon in the popup (a Control, or its Rect2 in canvas coordinates), `to` the counter's icon,
## `tex` the picture (null: a plain dot), `amount` what on_land reports. Call after add_child.
func start_item(from: Variant, to: Control, tex: Texture2D, amount: int, land: Callable = Callable()) -> void:
	start(from, to, tex, 1, amount, Callable(), land)
	finale_k = FINALE
	var r: Rect2 = from if from is Rect2 else (from as Control).get_global_rect()
	_from_px = maxf(minf(r.size.x, r.size.y), 1.0)


func _draw_solid() -> void:
	for c in _coins:
		var f := _t - float(c.start)
		if f < 0.0 or bool(c.landed):
			continue
		var px: float
		if f < POP:
			px = _from_px * lerpf(1.0, POP_SCALE, sin(clampf(f / POP, 0.0, 1.0) * PI * 0.5))
		else:
			px = lerpf(_from_px * POP_SCALE, _size * LAND_SCALE, _fly_s(f - POP))
		_solid.draw_set_transform(_pos(c, f), sin(f * 7.0) * 0.12, Vector2.ONE)
		if _tex != null:
			var ts := _tex.get_size()
			var k := px / maxf(ts.x, ts.y) if ts.x > 0.0 and ts.y > 0.0 else 0.0
			var sz := ts * k
			_solid.draw_texture_rect(_tex, Rect2(-sz * 0.5, sz), false)
		else:
			_solid.draw_circle(Vector2.ZERO, px * 0.5, AMBER)
	_solid.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
