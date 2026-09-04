class_name StateHasher
extends RefCounted


static func state_payload(world: WorldState) -> Dictionary:
	if world.schema_version == WorldState.SCHEMA_VERSION_M4:
		return {
			"schema_version": world.schema_version,
			"ruleset_manifest": world.ruleset_manifest.duplicate(true),
			"simulation_ruleset_hash": world.simulation_ruleset_hash,
			"state": world.to_state_data(),
		}
	return {
		"schema_version": world.schema_version,
		"ruleset_id": world.ruleset_id,
		"ruleset_hash": world.ruleset_hash,
		"state": world.to_state_data(),
	}


static func hash_world(world: WorldState) -> String:
	return hash_data(state_payload(world))


static func hash_data(value: Variant) -> String:
	var context: HashingContext = HashingContext.new()
	var start_error: Error = context.start(HashingContext.HASH_SHA256)
	if start_error != OK:
		push_error("Unable to start SHA-256 hashing context: %s" % error_string(start_error))
		return ""
	var update_error: Error = context.update(
		StateCanonicalizer.canonical_json(value).to_utf8_buffer()
	)
	if update_error != OK:
		push_error("Unable to update SHA-256 hashing context: %s" % error_string(update_error))
		return ""
	return context.finish().hex_encode()
