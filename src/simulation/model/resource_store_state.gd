class_name ResourceStoreState
extends RefCounted

var id: String = ""
var owner_kind: String = ""
var owner_id: String = ""
var resource_type_id: String = "food"
var quantity: int = 0


func to_data() -> Dictionary:
	return {
		"id": id,
		"owner_kind": owner_kind,
		"owner_id": owner_id,
		"resource_type_id": resource_type_id,
		"quantity": quantity,
	}


static func from_data(data: Dictionary) -> ResourceStoreState:
	var state: ResourceStoreState = ResourceStoreState.new()
	state.id = str(data.get("id", ""))
	state.owner_kind = str(data.get("owner_kind", ""))
	state.owner_id = str(data.get("owner_id", ""))
	state.resource_type_id = str(data.get("resource_type_id", ""))
	state.quantity = int(data.get("quantity", 0))
	return state
