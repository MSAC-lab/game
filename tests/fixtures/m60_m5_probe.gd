class_name M60M5Probe
extends M5ProbeFacade

var kernel_calls: int = 0
var batch_reference: BatchResolutionRecord = null


func _after_kernel(scope: M5OperationScope, batch: BatchResolutionRecord) -> void:
	kernel_calls += 1
	batch_reference = batch
	super._after_kernel(scope, batch)
