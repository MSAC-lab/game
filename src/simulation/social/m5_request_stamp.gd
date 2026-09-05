class_name M5RequestStamp
extends RefCounted

var day_index: int = 0
var input_state_hash: String = ""
var social_revision: int = 0


func to_data() -> Dictionary:
	return {
		"day_index": day_index,
		"input_state_hash": input_state_hash,
		"social_revision": social_revision,
	}


static func from_data(data: Dictionary) -> M5RequestStamp:
	var value: M5RequestStamp = M5RequestStamp.new()
	value.day_index = data["day_index"]
	value.input_state_hash = data["input_state_hash"]
	value.social_revision = data["social_revision"]
	return value


static func for_world(world: WorldState) -> M5RequestStamp:
	return from_data({"input_state_hash": StateHasher.hash_world(world),
		"day_index": world.day_index, "social_revision": world.social_state.revision})
