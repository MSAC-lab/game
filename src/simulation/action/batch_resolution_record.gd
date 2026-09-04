class_name BatchResolutionRecord
extends RefCounted

var batch_status: String = ""
var input_state_hash: String = ""
var output_state_hash: String = ""
var input_resolution_epoch: int = -1
var output_resolution_epoch: int = -1
var errors: Array[String] = []
var committed_outcomes: Array[ActionOutcomeRecord] = []
var resource_transactions: Array[ResourceTransactionRecord] = []
var witness_evidence_seeds: Array[WitnessEvidenceSeed] = []
var attempt_diagnostics: Array[AttemptDiagnostic] = []
var next_world: WorldState = null
var batch_artifact_hash: String = ""


static func rejected(
	world_value: Variant, reason_id: String, action_instance_id: String = ""
) -> BatchResolutionRecord:
	var result: BatchResolutionRecord = BatchResolutionRecord.new()
	result.batch_status = "REJECTED"
	if world_value is WorldState:
		var world: WorldState = world_value
		result.input_state_hash = StateHasher.hash_world(world)
		result.input_resolution_epoch = world.resolution_epoch
	var stages: Dictionary = M4ResolutionRules.reason_stage()
	var stage_id: String = str(stages.get(reason_id, "WORLD_VALIDATION"))
	result.errors = [reason_id]
	result.attempt_diagnostics = [
		AttemptDiagnostic.create(reason_id, stage_id, action_instance_id)
	]
	result.finalize_hash()
	return result


func to_data_without_batch_artifact_hash_and_next_world() -> Dictionary:
	var outcome_data: Array = []
	for outcome: ActionOutcomeRecord in committed_outcomes:
		outcome_data.append(outcome.to_data())
	var transaction_data: Array = []
	for transaction: ResourceTransactionRecord in resource_transactions:
		transaction_data.append(transaction.to_data())
	var seed_data: Array = []
	for seed: WitnessEvidenceSeed in witness_evidence_seeds:
		seed_data.append(seed.to_data())
	var diagnostic_data: Array = []
	for diagnostic: AttemptDiagnostic in attempt_diagnostics:
		diagnostic_data.append(diagnostic.to_data())
	return {
		"batch_status": batch_status,
		"input_state_hash": input_state_hash,
		"output_state_hash": output_state_hash,
		"input_resolution_epoch": input_resolution_epoch,
		"output_resolution_epoch": output_resolution_epoch,
		"errors": errors.duplicate(),
		"committed_outcomes": outcome_data,
		"resource_transactions": transaction_data,
		"witness_evidence_seeds": seed_data,
		"attempt_diagnostics": diagnostic_data,
	}


func to_data() -> Dictionary:
	var data: Dictionary = to_data_without_batch_artifact_hash_and_next_world()
	data["next_world"] = StateHasher.state_payload(next_world) if next_world != null else null
	data["batch_artifact_hash"] = batch_artifact_hash
	return data


func finalize_hash() -> void:
	batch_artifact_hash = StateHasher.hash_data({
		"algorithm_id": "m4-batch-artifact-v1",
		"batch_resolution": to_data_without_batch_artifact_hash_and_next_world(),
	})
