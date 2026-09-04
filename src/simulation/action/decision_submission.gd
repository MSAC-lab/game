class_name DecisionSubmission
extends RefCounted

var decision_request: DecisionRequest = null
var submitted_decision_result: DecisionResult = null


static func create(request: DecisionRequest, result: DecisionResult) -> DecisionSubmission:
	var submission: DecisionSubmission = DecisionSubmission.new()
	submission.decision_request = request
	submission.submitted_decision_result = result
	return submission
