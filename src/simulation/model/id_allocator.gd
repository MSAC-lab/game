class_name IdAllocator
extends RefCounted


static func next_id(world: WorldState, kind: String) -> String:
	var current: int = int(world.next_ids.get(kind, 1))
	world.next_ids[kind] = current + 1
	return "%s:%06d" % [kind, current]


static func relation_id(from_person_id: String, to_person_id: String) -> String:
	return "relation:%s->%s" % [from_person_id, to_person_id]
