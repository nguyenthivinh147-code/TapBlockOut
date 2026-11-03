extends RefCounted
## Chuỗi mô tả một phần thưởng {coins, items} cho UI (Weekly Pass, Chain Offer).

const Config := preload("res://src/config.gd")

const BOOSTER_ORDER := ["hint", "move", "smash"]


static func booster_name(kind: String) -> String:
	return TranslationServer.translate("booster_" + kind)


## "1.000 gold, Hint x1". Rỗng thì "".
static func text(reward: Dictionary) -> String:
	var parts: Array[String] = []
	var coins := int(reward.get("coins", 0))
	if coins > 0:
		parts.append(TranslationServer.translate("weekly_reward_gold") % coins)
	var items: Dictionary = reward.get("items", {})
	for k in BOOSTER_ORDER:
		if int(items.get(k, 0)) > 0:
			parts.append("%s %s" % [booster_name(k), TranslationServer.translate("booster_count") % int(items[k])])
	return ", ".join(parts)


## Thưởng của một SKU (gold + booster) ở dạng {coins, items}.
static func sku_reward(sku: String) -> Dictionary:
	var info: Dictionary = Config.SKUS.get(sku, {})
	return {"coins": int(info.get("gold", 0)), "items": (info.get("inv", {}) as Dictionary).duplicate()}
