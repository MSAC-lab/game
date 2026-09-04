class_name M4ParameterizationRules
extends RefCounted

const RULESET_ID: String = "drought-prototype-parameterization-v1"
const EXPECTED_HASH: String = "2b3b28f3ad886962e462eaedbd7dfd5321b519329af25f2f2d9664c666c46ae3"
const DATA_PATH: String = "res://src/simulation/rules/m4_parameterization_rules.json"


static func to_data() -> Dictionary:
	return M4RulesData.load_dictionary(DATA_PATH)


static func ruleset_hash() -> String:
	return StateHasher.hash_data({"m4_parameterization_rules": to_data()})
