class_name M5OperationScope
extends RefCounted
## In-process ownership boundary; never deserialized or accepted by a public API.

var operation_kind: String = ""
var input_state_hash: String = ""
var input_day_index: int = 0
var input_resolution_epoch: int = 0
var input_social_revision: int = 0
var scope_id: String = ""
var input_world: WorldState
var intents: Array[ActionIntent] = []
var contexts: Array[ResolutionContext] = []
var _owner: WeakRef
var _input_payload: Dictionary = {}
var _stages: Array[WorldState] = []
var _open: bool = false


static func _begin(owner: RefCounted, world: WorldState, kind: String) -> M5OperationScope:
	var scope: M5OperationScope = M5OperationScope.new()
	scope._owner = weakref(owner)
	scope.input_world = M5Data.clone(world)
	scope._input_payload = StateHasher.state_payload(world)
	scope.operation_kind = kind
	scope.input_state_hash = StateHasher.hash_world(world)
	scope.input_day_index = world.day_index
	scope.input_resolution_epoch = world.resolution_epoch
	scope.input_social_revision = world.social_state.revision
	scope.scope_id = StateHasher.hash_data({"algorithm_id": "m5-operation-scope-v1", "operation_kind": kind,
		"input_state_hash": scope.input_state_hash, "input_day_index": scope.input_day_index,
		"input_resolution_epoch": scope.input_resolution_epoch, "input_social_revision": scope.input_social_revision})
	scope._open = true
	return scope


func is_owned() -> bool:
	return _open and _owner != null and _owner.get_ref() != null and _owner.get_ref().get("_active_scope") == self


func owns_input(world: WorldState) -> bool:
	return is_owned() and world == input_world and StateHasher.state_payload(world) == _input_payload


func register_stage(world: WorldState) -> void:
	if is_owned() and world != input_world and not _stages.has(world):
		_stages.append(world)


func owns_stage(world: WorldState) -> bool:
	return is_owned() and _stages.has(world) and owns_input(input_world)


func finish() -> void:
	_open = false
	_stages.clear()
