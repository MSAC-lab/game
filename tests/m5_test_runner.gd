extends SceneTree

const SUITE: GDScript = preload("res://tests/unit/m5_social_integration_test.gd")


func _init() -> void:
	var suite: M5SocialIntegrationTest = SUITE.new()
	var failures: Array[String] = suite.run_all()
	var status: String = "FAIL" if not failures.is_empty() else "PASS"
	var evidence: Dictionary = suite.runtime_evidence
	evidence["m5_status"] = status
	evidence["checks"] = suite.checks
	evidence["failures"] = failures
	evidence["godot_version"] = Engine.get_version_info().string
	evidence["approved_annex_sha256"] = FileAccess.get_sha256("res://tests/fixtures/m5_design_vectors.json")
	evidence["fcal_erratum_sha256"] = FileAccess.get_sha256("res://docs/decisions/m5-fcal-erratum-01.json")
	evidence["effective_design_content_hash"] = M5FixtureFactory.annex().design_content_hash
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
	print("M5 %s: %d checks, %d failures." % [status, suite.checks, failures.size()])
	for failure: String in failures:
		print(" - " + failure)
	quit(1 if not failures.is_empty() else 0)
