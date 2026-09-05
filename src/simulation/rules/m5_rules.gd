class_name M5Rules
extends RefCounted

const RULESET_ID: String = "drought-prototype-social-v2"
const EXPECTED_HASH: String = "c295928deb3178c8ab081aa65ae2cd27ff473dac2d048e668ff8bafa9ca21142"
const SIMULATION_HASH: String = "9781a62e3f607f9fe861201a905c0fff6b7a12ffc564c660facb8fdddc40e5d4"
static var _rules: Dictionary = {}


static func data() -> Dictionary:
	if _rules.is_empty():
		var parsed: Dictionary = M5JsonReader.parse(FileAccess.get_file_as_string("res://src/simulation/rules/m5_social_rules.json"))
		if not parsed.ok or typeof(parsed.value) != TYPE_DICTIONARY:
			return {}
		_rules = parsed.value
	return _rules.duplicate(true)


static func current_manifest_data() -> Dictionary:
	var manifest: Dictionary = M4Rules.current_manifest_data()
	manifest["social"] = {"ruleset_id": RULESET_ID, "ruleset_hash": EXPECTED_HASH}
	return manifest


static func validate_world_manifest(world: WorldState, _components: Array[String]) -> Array[String]:
	var errors: Array[String] = []
	if world.schema_version != WorldState.SCHEMA_VERSION_M5:
		errors.append("schema 5 required")
	if world.ruleset_manifest != current_manifest_data():
		errors.append("schema 5 component ruleset mismatch")
	if world.simulation_ruleset_hash != SIMULATION_HASH or M4Rules.simulation_ruleset_hash(world.ruleset_manifest) != SIMULATION_HASH:
		errors.append("schema 5 simulation_ruleset_hash mismatch")
	if StateHasher.hash_data(data()) != EXPECTED_HASH:
		errors.append("social component implementation hash mismatch")
	errors.append_array(M4Rules.validate_implementation_hashes())
	return errors
