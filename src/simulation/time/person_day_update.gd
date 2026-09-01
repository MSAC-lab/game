class_name PersonDayUpdate
extends RefCounted


static func update_hunger(person: PersonState, eaten_units: int) -> String:
	var need: int = person.daily_food_need_units
	if need == 0:
		return ""
	if eaten_units < 0 or eaten_units > need:
		return "invalid eaten quantity for %s: %d of %d" % [person.id, eaten_units, need]
	var hunger: int = int(person.need_scores.get("hunger", 0))
	if eaten_units == need:
		person.need_scores["hunger"] = maxi(
			0, hunger - M2ResourceRules.FULL_MEAL_HUNGER_RECOVERY
		)
		return ""
	var shortfall: int = need - eaten_units
	@warning_ignore("integer_division")
	var increase: int = (
		M2ResourceRules.SHORTFALL_HUNGER_SCALE * shortfall + need - 1
	) / need
	person.need_scores["hunger"] = mini(100, hunger + increase)
	return ""


static func update_health(person: PersonState) -> String:
	if person.daily_food_need_units == 0:
		return ""
	var hunger: int = int(person.need_scores.get("hunger", 0))
	var next_severe_days: int = 0
	if hunger >= M2ResourceRules.SEVERE_HUNGER_THRESHOLD:
		next_severe_days = person.severe_hunger_days + 1
	var next_health: int = person.health
	if next_severe_days >= M2ResourceRules.HEALTH_DAMAGE_DELAY_DAYS:
		next_health -= M2ResourceRules.DAILY_HEALTH_DAMAGE
	if next_health <= 0:
		return "M2_DEATH_NOT_IMPLEMENTED: %s health would become %d" % [person.id, next_health]
	person.severe_hunger_days = next_severe_days
	person.health = next_health
	return ""
