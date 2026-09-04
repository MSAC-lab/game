class_name ResolutionContextIssuer
extends RefCounted

var issuer_id: String = ""


func is_trusted() -> bool:
	return false


func issue_context(_world: WorldState, _intent: ActionIntent) -> ResolutionContext:
	return null


func owns_context(_context: ResolutionContext) -> bool:
	return false
