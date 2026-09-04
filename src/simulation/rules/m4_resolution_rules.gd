class_name M4ResolutionRules
extends RefCounted

const RULESET_ID: String = "drought-prototype-resolution-v1"
const EXPECTED_HASH: String = "5ac0e95d42761ba1037480a28edb996d73e318ab04dae44ee5ef587eb537a3fe"
const DATA_PATH: String = "res://src/simulation/rules/m4_resolution_rules.json"


static func to_data() -> Dictionary:
	return M4RulesData.load_dictionary(DATA_PATH)


static func ruleset_hash() -> String:
	return StateHasher.hash_data({"m4_resolution_rules": to_data()})


static func validation_precedence() -> Dictionary:
	var rejection: Dictionary = to_data().get("rejection", {})
	return rejection.get("validation_precedence", {}).duplicate(true)


static func reason_stage() -> Dictionary:
	var rejection: Dictionary = to_data().get("rejection", {})
	return rejection.get("reason_stage", {}).duplicate(true)
