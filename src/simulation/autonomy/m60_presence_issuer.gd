class_name M60PresenceIssuer
extends ResolutionContextIssuer
## One day-start snapshot and fixed sites. Selecting a target never changes presence.

var _config: Dictionary = {}
var _world_hash: String = ""
var _day: int = -1
var _epoch: int = -1
var _issued: Dictionary = {}


static func create(world: WorldState, config: Dictionary) -> M60PresenceIssuer:
	var issuer: M60PresenceIssuer = M60PresenceIssuer.new()
	if world == null or not M60Config.validate(config, world).is_empty():
		return issuer
	issuer._config = StateCanonicalizer.canonicalize(config)
	issuer._world_hash = StateHasher.hash_world(world)
	issuer._day = world.day_index
	issuer._epoch = world.resolution_epoch
	issuer.issuer_id = "m60-fixed-site:" + StateHasher.hash_data(config)
	return issuer


func is_trusted() -> bool:
	return not _config.is_empty() and not _world_hash.is_empty()


func issue_context(world: WorldState, intent: ActionIntent) -> ResolutionContext:
	if not is_trusted() or world == null or intent == null or world.day_index != _day or world.resolution_epoch != _epoch:
		return null
	if StateHasher.hash_world(world) != _world_hash or intent.source_decision_input_state_hash != _world_hash:
		return null
	if not _config.person_sites.has(intent.actor_person_id):
		return null
	var site: String = _config.person_sites[intent.actor_person_id]
	var context: ResolutionContext = ResolutionContext.new()
	context.issuer_id = issuer_id
	context.action_instance_id = intent.action_instance_id
	context.input_state_hash = _world_hash
	context.resolution_epoch = _epoch
	context.day_index = _day
	context.phase_id = DecisionInstanceKey.PHASE_ID
	for person: PersonState in world.persons:
		if person.alive and _config.person_sites[person.id] == site:
			context.present_person_ids.append(person.id)
	for resource: ResourceStoreState in world.resource_stores:
		if _config.store_sites[resource.id] == site:
			context.present_store_ids.append(resource.id)
	context.present_person_ids.sort()
	context.present_store_ids.sort()
	context.context_id = context.compute_context_id()
	_issued[context.context_id] = StateCanonicalizer.canonical_json(context.to_data())
	return context


func owns_context(context: ResolutionContext) -> bool:
	return context != null and _issued.has(context.context_id) and _issued[context.context_id] == StateCanonicalizer.canonical_json(context.to_data())
