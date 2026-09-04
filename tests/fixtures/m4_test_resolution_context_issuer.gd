class_name TestResolutionContextIssuer
extends ResolutionContextIssuer

const TEST_ISSUER_ID: String = "m4-test-context-issuer-v1"

var _presence_by_action: Dictionary = {}
var _issued_context_ids: Dictionary = {}


func _init() -> void:
	issuer_id = TEST_ISSUER_ID


func is_trusted() -> bool:
	return true


func set_presence(
	action_instance_id: String,
	present_person_ids: Array[String],
	present_store_ids: Array[String]
) -> void:
	var people: Array[String] = _sorted_unique(present_person_ids)
	var stores: Array[String] = _sorted_unique(present_store_ids)
	_presence_by_action[action_instance_id] = {
		"present_person_ids": people,
		"present_store_ids": stores,
	}


func issue_context(world: WorldState, intent: ActionIntent) -> ResolutionContext:
	if not _presence_by_action.has(intent.action_instance_id):
		return null
	var presence: Dictionary = _presence_by_action[intent.action_instance_id]
	var context: ResolutionContext = ResolutionContext.new()
	context.issuer_id = issuer_id
	context.action_instance_id = intent.action_instance_id
	context.input_state_hash = StateHasher.hash_world(world)
	context.resolution_epoch = world.resolution_epoch
	context.day_index = world.day_index
	context.phase_id = DecisionInstanceKey.PHASE_ID
	context.present_person_ids = ModelData.copy_string_array(
		presence.get("present_person_ids", [])
	)
	context.present_store_ids = ModelData.copy_string_array(
		presence.get("present_store_ids", [])
	)
	context.context_id = context.compute_context_id()
	_issued_context_ids[context.context_id] = true
	return context


func owns_context(context: ResolutionContext) -> bool:
	return (
		is_trusted()
		and context != null
		and context.issuer_id == issuer_id
		and _issued_context_ids.has(context.context_id)
	)


func register_context_for_testing(context: ResolutionContext) -> void:
	_issued_context_ids[context.context_id] = true


static func _sorted_unique(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value: String in values:
		if not result.has(value):
			result.append(value)
	result.sort()
	return result
