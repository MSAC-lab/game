class_name M2ResourceRules
extends RefCounted

const RULESET_ID: String = "drought-prototype-rules-v2"
const FULL_MEAL_HUNGER_RECOVERY: int = 6
const SHORTFALL_HUNGER_SCALE: int = 24
const SEVERE_HUNGER_THRESHOLD: int = 80
const HEALTH_DAMAGE_DELAY_DAYS: int = 2
const DAILY_HEALTH_DAMAGE: int = 5


static func to_data() -> Dictionary:
	return {
		"daily_health_damage": DAILY_HEALTH_DAMAGE,
		"full_meal_hunger_recovery": FULL_MEAL_HUNGER_RECOVERY,
		"health_damage_delay_days": HEALTH_DAMAGE_DELAY_DAYS,
		"severe_hunger_threshold": SEVERE_HUNGER_THRESHOLD,
		"shortfall_hunger_scale": SHORTFALL_HUNGER_SCALE,
	}


static func ruleset_hash() -> String:
	return StateHasher.hash_data({"m2_resource_rules": to_data()})
