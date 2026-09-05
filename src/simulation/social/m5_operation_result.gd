class_name M5OperationResult
extends RefCounted

var ok: bool = false
var next_world: WorldState = null
var resource_transactions: Array[ResourceTransactionRecord] = []
var artifact: Dictionary = {}


func to_data() -> Dictionary:
	return {"ok": ok, "next_world": StateHasher.state_payload(next_world) if next_world != null else null,
		"resource_transactions": ModelData.object_array_to_data(resource_transactions), "artifact": artifact.duplicate(true)}
