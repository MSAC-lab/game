class_name M60ProbeRunner
extends M60Runner

var fault: String = ""
var calls: int = 0


func _execute_actions(world: WorldState, submissions: Array, issuer: ResolutionContextIssuer) -> M5ObservedExecutionResult:
	calls += 1
	if fault == "M4_REJECTED":
		return M5Facade.execute_decisions_observed_v1(world, M5RequestStamp.for_world(world), submissions, ResolutionContextIssuer.new())
	var value: M5ObservedExecutionResult = super._execute_actions(world, submissions, issuer)
	if fault == "MISSING":
		value.m4_batch_artifact = null
	elif fault == "HASH":
		value.m4_batch_artifact.batch_artifact_hash = "0".repeat(64)
	elif fault == "BODY":
		value.m4_batch_artifact.batch_resolution.output_resolution_epoch += 1
	return value
