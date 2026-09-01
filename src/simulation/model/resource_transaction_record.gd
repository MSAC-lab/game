class_name ResourceTransactionRecord
extends RefCounted

var id: String = ""
var day_index: int = 0
var sequence_index: int = 0
var resource_type_id: String = "food"
var source_store_id: String = ""
var destination_store_id: String = ""
var consumer_person_id: String = ""
var quantity: int = 0
var reason_id: String = ""


func to_data() -> Dictionary:
	return {
		"id": id,
		"day_index": day_index,
		"sequence_index": sequence_index,
		"resource_type_id": resource_type_id,
		"source_store_id": source_store_id,
		"destination_store_id": destination_store_id,
		"consumer_person_id": consumer_person_id,
		"quantity": quantity,
		"reason_id": reason_id,
	}


static func from_data(data: Dictionary) -> ResourceTransactionRecord:
	var record: ResourceTransactionRecord = ResourceTransactionRecord.new()
	record.id = str(data.get("id", ""))
	record.day_index = int(data.get("day_index", 0))
	record.sequence_index = int(data.get("sequence_index", 0))
	record.resource_type_id = str(data.get("resource_type_id", ""))
	record.source_store_id = str(data.get("source_store_id", ""))
	record.destination_store_id = str(data.get("destination_store_id", ""))
	record.consumer_person_id = str(data.get("consumer_person_id", ""))
	record.quantity = int(data.get("quantity", 0))
	record.reason_id = str(data.get("reason_id", ""))
	return record
