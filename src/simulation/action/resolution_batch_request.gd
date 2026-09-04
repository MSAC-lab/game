class_name ResolutionBatchRequest
extends RefCounted

var intents: Array[ActionIntent] = []
var execution_contexts: Array[ResolutionContext] = []


func to_data() -> Dictionary:
	var intent_data: Array = []
	for intent: ActionIntent in intents:
		intent_data.append(intent.to_data())
	var context_data: Array = []
	for context: ResolutionContext in execution_contexts:
		context_data.append(context.to_data())
	return {
		"intents": intent_data,
		"execution_contexts": context_data,
	}
