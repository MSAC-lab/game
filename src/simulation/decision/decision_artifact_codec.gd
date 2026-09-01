class_name DecisionArtifactCodec
extends RefCounted


static func canonical_json(result: DecisionResult) -> String:
	return StateCanonicalizer.canonical_json(result.to_data())


static func pretty_json(result: DecisionResult) -> String:
	return StateCanonicalizer.pretty_json(result.to_data())


static func hash_result(result: DecisionResult) -> String:
	return StateHasher.hash_data(result.to_data())
