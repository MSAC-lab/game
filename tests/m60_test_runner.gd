extends SceneTree

const SUITE: GDScript = preload("res://tests/unit/m60_autonomy_test.gd")


func _init() -> void:
	var suite: M60AutonomyTest = SUITE.new()
	var failures: Array[String] = suite.run_all()
	var status: String = "FAIL" if not failures.is_empty() else "PASS"
	var evidence: Dictionary = suite.runtime_evidence
	evidence.m60_status = status
	evidence.checks = suite.checks
	evidence.failures = failures
	evidence.godot_version = Engine.get_version_info().string
	evidence.design_sha256 = FileAccess.get_sha256("res://docs/decisions/m6-0-v0.2.md")
	evidence.scenario_sha256 = FileAccess.get_sha256("res://scenarios/m6-0-food-pressure-v1.json")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-path="):
			var path: String = argument.trim_prefix("--evidence-path=")
			var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
			if file == null:
				push_error("Cannot write M6-0 evidence: " + path)
				quit(1)
				return
			file.store_string(StateCanonicalizer.canonical_json(evidence) + "\n")
			file.close()
	print("M6-0 %s: %d checks, %d failures." % [status, suite.checks, failures.size()])
	for failure: String in failures:
		print(" - " + failure)
	quit(1 if not failures.is_empty() else 0)
