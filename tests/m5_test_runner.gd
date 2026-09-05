extends SceneTree

const SUITE: GDScript = preload("res://tests/unit/m5_social_integration_test.gd")


func _init() -> void:
	var suite: M5SocialIntegrationTest = SUITE.new()
	var failures: Array[String] = suite.run_all()
	var hold: bool = suite.runtime_evidence.has("FCAL_canonical_blocker")
	var status: String = "FAIL" if not failures.is_empty() else "HOLD" if hold else "PASS"
	var evidence: Dictionary = suite.runtime_evidence
	evidence["m5_status"] = status
	evidence["checks"] = suite.checks
	evidence["failures"] = failures
	evidence["godot_version"] = Engine.get_version_info().string
	evidence["approved_annex_sha256"] = FileAccess.get_sha256("res://tests/fixtures/m5_design_vectors.json")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-path="):
			var path: String = argument.trim_prefix("--evidence-path=")
			var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
			if file == null:
				push_error("Cannot write M5 evidence: " + path)
				quit(1)
				return
			file.store_string(StateCanonicalizer.canonical_json(evidence) + "\n")
			file.close()
	print("M5 %s: %d supporting checks, %d failures." % [status, suite.checks, failures.size()])
	for failure: String in failures:
		print(" - " + failure)
	if hold:
		print("CANONICAL FCAL HOLD: day 27 close reaches unsupported health 0 for person:000003.")
		print("The hunger 37 proposal is NON-CANONICAL; passing it does not satisfy D26-R02.")
	quit(1 if not failures.is_empty() else 2 if hold else 0)
