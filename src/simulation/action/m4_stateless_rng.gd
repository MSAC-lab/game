class_name M4StatelessRng
extends RefCounted

const TIE_PURPOSE: String = "A04_RESPONSE_TIE"
const OFFSET_PURPOSES: Array[String] = [
	"A11_PERFORMANCE",
	"A11_EXPOSURE",
	"A11_WITNESS",
]


static func draw(
	world: WorldState,
	action_instance_id: String,
	roll_purpose: String,
	participant_id: String,
	candidate_count: int = 0
) -> RandomDrawRecord:
	var payload: Dictionary = {
		"algorithm_id": "m4-stateless-roll-v1",
		"simulation_ruleset_hash": world.simulation_ruleset_hash,
		"rng_seed_hex": world.rng_seed_hex,
		"day_index": world.day_index,
		"phase_id": DecisionInstanceKey.PHASE_ID,
		"action_instance_id": action_instance_id,
		"roll_purpose": roll_purpose,
		"participant_id": participant_id,
	}
	var record: RandomDrawRecord = RandomDrawRecord.new()
	record.roll_purpose = roll_purpose
	record.participant_id = participant_id
	record.digest_hex = StateHasher.hash_data(payload)
	record.source_hex = record.digest_hex.substr(0, 15)
	var source_integer: int = record.source_hex.hex_to_int()
	if roll_purpose == TIE_PURPOSE:
		assert(candidate_count > 0)
		record.modulus = candidate_count
		record.mapped_value = source_integer % candidate_count
	else:
		assert(OFFSET_PURPOSES.has(roll_purpose))
		record.modulus = 21
		record.mapped_value = source_integer % 21 - 10
	return record
