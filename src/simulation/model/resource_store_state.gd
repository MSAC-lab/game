class_name ResourceStoreState
extends RefCounted

var id: String = ""
var owner_kind: String = ""
var owner_id: String = ""
var resource_type_id: String = "food"
var quantity: int = 0
var security_level: int = 0


func to_data(schema_version: int = WorldState.SCHEMA_VERSION_M2) -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"owner_kind": owner_kind,
		"owner_id": owner_id,
		"resource_type_id": resource_type_id,
		"quantity": quantity,
	}
	if schema_version in [WorldState.SCHEMA_VERSION_M3, WorldState.SCHEMA_VERSION_M4]:
		data["security_level"] = security_level
	return data


static func from_data(
	data: Dictionary, schema_version: int = WorldState.SCHEMA_VERSION_M2
) -> ResourceStoreState:
	var state: ResourceStoreState = ResourceStoreState.new()
	state.id = str(data.get("id", ""))
	state.owner_kind = str(data.get("owner_kind", ""))
	state.owner_id = str(data.get("owner_id", ""))
	state.resource_type_id = str(data.get("resource_type_id", ""))
	state.quantity = int(data.get("quantity", 0))
	if schema_version in [WorldState.SCHEMA_VERSION_M3, WorldState.SCHEMA_VERSION_M4]:
		state.security_level = int(data.get("security_level", 0))
	return state
