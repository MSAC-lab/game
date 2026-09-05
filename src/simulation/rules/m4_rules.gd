class_name M4Rules
extends RefCounted

const RESOURCE_RULESET_ID: String = "drought-prototype-rules-v2"
const RESOURCE_RULESET_HASH: String = "3c5da58d0e0168c9427b827c0e37c4b9dd1e4582834b8c33efc5a6e6c9015f03"
const DECISION_RULESET_ID: String = "drought-prototype-rules-v3"
const DECISION_RULESET_HASH: String = "bd3a83d9491eb0275605817fc50d9fde4cf444efb7f5d3ed749c3d6d975fddb8"
const SIMULATION_RULESET_HASH: String = "2ba7245d5b5481398f3d6d3d7e21f597a2f23a240b82a22e0dde8eca188aa3e4"


static func current_manifest() -> RulesetManifest:
	var manifest: RulesetManifest = RulesetManifest.new()
	manifest.components = {
		"resource": RulesetComponentRef.create(RESOURCE_RULESET_ID, RESOURCE_RULESET_HASH),
		"decision": RulesetComponentRef.create(DECISION_RULESET_ID, DECISION_RULESET_HASH),
		"parameterization": RulesetComponentRef.create(
			M4ParameterizationRules.RULESET_ID, M4ParameterizationRules.EXPECTED_HASH
		),
		"response": RulesetComponentRef.create(
			M4ResponseRules.RULESET_ID, M4ResponseRules.EXPECTED_HASH
		),
		"resolution": RulesetComponentRef.create(
			M4ResolutionRules.RULESET_ID, M4ResolutionRules.EXPECTED_HASH
		),
	}
	return manifest


static func current_manifest_data() -> Dictionary:
	return current_manifest().to_data()


static func simulation_ruleset_hash(manifest_data: Dictionary) -> String:
	return StateHasher.hash_data({"ruleset_manifest": manifest_data})


static func validate_implementation_hashes() -> Array[String]:
	var errors: Array[String] = []
	if M2ResourceRules.ruleset_hash() != RESOURCE_RULESET_HASH:
		errors.append("resource component implementation hash mismatch")
	if M3DecisionRules.ruleset_hash() != DECISION_RULESET_HASH:
		errors.append("decision component implementation hash mismatch")
	if M4ParameterizationRules.ruleset_hash() != M4ParameterizationRules.EXPECTED_HASH:
		errors.append("parameterization component implementation hash mismatch")
	if M4ResponseRules.ruleset_hash() != M4ResponseRules.EXPECTED_HASH:
		errors.append("response component implementation hash mismatch")
	if M4ResolutionRules.ruleset_hash() != M4ResolutionRules.EXPECTED_HASH:
		errors.append("resolution component implementation hash mismatch")
	if simulation_ruleset_hash(current_manifest_data()) != SIMULATION_RULESET_HASH:
		errors.append("simulation ruleset implementation hash mismatch")
	return errors


static func validate_world_manifest(
	world: WorldState, authoritative_components: Array[String]
) -> Array[String]:
	if world.schema_version == WorldState.SCHEMA_VERSION_M5:
		return M5Rules.validate_world_manifest(world, authoritative_components)
	var errors: Array[String] = []
	if world.schema_version != WorldState.SCHEMA_VERSION_M4:
		errors.append("schema 4 ruleset manifest required")
		return errors
	if simulation_ruleset_hash(world.ruleset_manifest) != world.simulation_ruleset_hash:
		errors.append("simulation_ruleset_hash mismatch")
	if world.simulation_ruleset_hash != SIMULATION_RULESET_HASH:
		errors.append("simulation ruleset is not supported by this implementation")
	var expected: Dictionary = current_manifest_data()
	for component_name: String in authoritative_components:
		if world.ruleset_manifest.get(component_name) != expected.get(component_name):
			errors.append("%s component ruleset mismatch" % component_name)
	errors.append_array(validate_implementation_hashes())
	return errors
