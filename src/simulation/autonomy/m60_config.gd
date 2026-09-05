class_name M60Config
extends RefCounted
## Configuration is a separate versioned input; it does not extend the frozen world schema.

const VERSION: String = "m6-0-runner-v1"
const KEYS: Array[String] = ["runner_version", "initial_state_hash", "simulation_ruleset_hash",
	"automatic_person_ids", "person_sites", "store_sites", "contacts"]


static func validate(value: Variant, world: WorldState) -> String:
	if not M5Data.exact(value, KEYS) or not M5Data.json_value(value):
		return "config"
	var config: Dictionary = value
	if config.runner_version != VERSION:
		return "config.runner_version"
	if typeof(config.initial_state_hash) != TYPE_STRING or not M5StateValidator._hash(config.initial_state_hash):
		return "config.initial_state_hash"
	if config.simulation_ruleset_hash != world.simulation_ruleset_hash:
		return "config.simulation_ruleset_hash"
	if typeof(config.automatic_person_ids) != TYPE_ARRAY:
		return "config.automatic_person_ids"
	var seen: Dictionary = {}
	for id: Variant in config.automatic_person_ids:
		if typeof(id) != TYPE_STRING or world.find_person(id) == null or seen.has(id):
			return "config.automatic_person_ids"
		seen[id] = true
	for key: String in ["person_sites", "store_sites"]:
		if typeof(config[key]) != TYPE_DICTIONARY:
			return "config." + key
		var ids: Array[String] = []
		if key == "person_sites":
			for person: PersonState in world.persons:
				ids.append(person.id)
		else:
			for resource: ResourceStoreState in world.resource_stores:
				ids.append(resource.id)
		if config[key].size() != ids.size():
			return "config." + key
		ids.sort()
		for id: String in ids:
			if typeof(config[key].get(id)) != TYPE_STRING or config[key][id].strip_edges().is_empty():
				return "config." + key
	if typeof(config.contacts) != TYPE_ARRAY:
		return "config.contacts"
	var partners: Dictionary = {}
	seen.clear()
	for pair: Variant in config.contacts:
		if not M5Data.exact(pair, ["id", "person_a_id", "person_b_id"]):
			return "config.contacts"
		if typeof(pair.id) != TYPE_STRING or typeof(pair.person_a_id) != TYPE_STRING or typeof(pair.person_b_id) != TYPE_STRING:
			return "config.contacts"
		var a: String = pair.person_a_id
		var b: String = pair.person_b_id
		if a >= b or pair.id != "contact:%s->%s" % [a, b] or seen.has(pair.id):
			return "config.contacts"
		if not config.person_sites.has(a) or not config.person_sites.has(b) or config.person_sites[a] != config.person_sites[b]:
			return "config.contacts.site"
		seen[pair.id] = true
		for id: String in [a, b]:
			partners[id] = int(partners.get(id, 0)) + 1
			if partners[id] > 3:
				return "config.contacts.degree"
	return ""


static func actors(config: Dictionary, world: WorldState) -> Array[String]:
	var ids: Array[String] = []
	for id: String in config.automatic_person_ids:
		if world.find_person(id).alive:
			ids.append(id)
	ids.sort()
	return ids


static func contact_plan(config: Dictionary, world: WorldState) -> SocialContactPlan:
	var result: SocialContactPlan = SocialContactPlan.new()
	for pair: Dictionary in config.contacts:
		if world.find_person(pair.person_a_id).alive and world.find_person(pair.person_b_id).alive:
			result.pairs.append(SocialContactPair.from_data(pair.duplicate(true)))
	result.pairs.sort_custom(func(a: SocialContactPair, b: SocialContactPair) -> bool: return a.id < b.id)
	return result
