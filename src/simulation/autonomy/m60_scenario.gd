class_name M60Scenario
extends RefCounted


static func load_json(text: String) -> Dictionary:
	var parsed: Dictionary = M5JsonReader.parse(text)
	if not parsed.ok or not M5Data.exact(parsed.value, ["algorithm_id", "initial_payload", "config"]):
		return _failure("scenario.shape")
	var data: Dictionary = parsed.value
	if data.algorithm_id != "m60-scenario-v1" or typeof(data.initial_payload) != TYPE_DICTIONARY:
		return _failure("scenario.version_or_payload")
	if not M5StateValidator.issues(data.initial_payload).is_empty():
		return _failure("scenario.initial_payload")
	var world: WorldState = WorldState.from_data(data.initial_payload, data.initial_payload.state)
	var error: String = M60Checkpoint.boundary_error(world)
	if error.is_empty():
		error = M60Config.validate(data.config, world)
	if error.is_empty() and data.config.initial_state_hash != StateHasher.hash_world(world):
		error = "scenario.initial_state_hash"
	if not error.is_empty():
		return _failure(error)
	return {"ok": true, "world": world, "config": data.config.duplicate(true), "error": ""}


static func _failure(error: String) -> Dictionary:
	return {"ok": false, "world": null, "config": {}, "error": error}
