class_name M5ObservedExecutionResult
extends RefCounted
## Detached developer evidence. The legacy operation result and its hashes are unchanged.

var operation_result: M5OperationResult
var m4_batch_artifact: Variant = null


func to_data() -> Dictionary:
	return {"operation_result": operation_result.to_data(),
		"m4_batch_artifact": m4_batch_artifact.duplicate(true) if m4_batch_artifact != null else null}
