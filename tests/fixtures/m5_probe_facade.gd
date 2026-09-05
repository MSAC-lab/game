class_name M5ProbeFacade
extends M5Facade
## Test-only fault injection at real native checkpoints. No public fault parameter.

var fault: String = ""
var stage_checks: Dictionary = {}


func _after_kernel(scope: M5OperationScope, batch: BatchResolutionRecord) -> void:
	if batch.batch_status != "COMMITTED":
		return
	stage_checks["public_rejected"] = not StateValidator.validate_world(batch.next_world).is_empty()
	stage_checks["save_rejected"] = not M5SaveCodec.encode_checked(batch.next_world).ok
	stage_checks["hash_rejected"] = StateHasher.hash_world(batch.next_world).is_empty()
	stage_checks["decision_rejected"] = not DecisionEngine.evaluate(batch.next_world, DecisionRequest.create("person:000001", "daily_food_strategy")).ok
	stage_checks["internal_accepted"] = M5StageBoundary._validate_after_resolution(scope, batch.next_world, batch.resource_transactions).is_empty()
	if fault == "FAR-03":
		batch.output_state_hash = "f".repeat(64)
	elif fault == "STAGE_QUANTITY":
		batch.next_world.resource_stores[0].quantity += 1
	elif fault == "STAGE_EPOCH":
		batch.next_world.resolution_epoch += 1
	elif fault == "STAGE_SOCIAL":
		batch.next_world.social_state.revision += 1


func _after_day_kernel(scope: M5OperationScope, stage: WorldState) -> void:
	stage_checks["day_public_rejected"] = not StateValidator.validate_world(stage).is_empty()
	stage_checks["day_save_rejected"] = not M5SaveCodec.encode_checked(stage).ok
	stage_checks["day_scope_owned"] = scope.owns_stage(stage)


func _before_publish(scope: M5OperationScope, stage: WorldState, _artifact: Dictionary) -> void:
	if fault == "FAR-04":
		for memory: MemoryState in stage.memories:
			if memory.id == "memory:000002":
				memory.source_observation_id = ""
	elif fault == "FAR-05":
		stage.social_state.revision = scope.input_social_revision
	elif fault == "FAR-06":
		stage.social_state.last_closed_day_index = scope.input_day_index - 1
	elif fault == "SOCIAL_RESOURCE":
		stage.resource_stores[0].quantity += 1
	elif fault == "SOCIAL_HEALTH":
		stage.persons[0].health -= 1
