class_name DayPhaseGuard
extends RefCounted

const DAY_END: String = "DAY_END"
const NEEDS_FIXED: String = "NEEDS_FIXED"
const ALLOCATION_PLANNED: String = "ALLOCATION_PLANNED"
const CONSUMPTION_APPLIED: String = "CONSUMPTION_APPLIED"
const HUNGER_UPDATED: String = "HUNGER_UPDATED"
const HEALTH_UPDATED: String = "HEALTH_UPDATED"
const CONSERVATION_VERIFIED: String = "CONSERVATION_VERIFIED"

const TRANSITIONS: Dictionary = {
	DAY_END: NEEDS_FIXED,
	NEEDS_FIXED: ALLOCATION_PLANNED,
	ALLOCATION_PLANNED: CONSUMPTION_APPLIED,
	CONSUMPTION_APPLIED: HUNGER_UPDATED,
	HUNGER_UPDATED: HEALTH_UPDATED,
	HEALTH_UPDATED: CONSERVATION_VERIFIED,
	CONSERVATION_VERIFIED: DAY_END,
}

var current_phase: String = DAY_END


func advance(next_phase: String) -> String:
	var expected: String = str(TRANSITIONS.get(current_phase, ""))
	if next_phase != expected:
		return "invalid day phase transition: %s -> %s; expected %s" % [
			current_phase, next_phase, expected
		]
	current_phase = next_phase
	return ""
