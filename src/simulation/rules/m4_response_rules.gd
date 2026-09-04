class_name M4ResponseRules
extends RefCounted

const RULESET_ID: String = "drought-prototype-response-v1"
const EXPECTED_HASH: String = "6599cea3c34469b9051a6a6ecc8eebc89d4291620a792388a7a5b8aa9b5dae4d"
const DATA_PATH: String = "res://src/simulation/rules/m4_response_rules.json"


static func to_data() -> Dictionary:
	return M4RulesData.load_dictionary(DATA_PATH)


static func ruleset_hash() -> String:
	return StateHasher.hash_data({"m4_response_rules": to_data()})
