extends SceneTree

const EXPECTED_ENGINE_VERSION_PREFIX: String = "4.7.2"
const EXPECTED_MAIN_SCENE: String = "res://ui/main.tscn"
const REQUIRED_WARNING_LEVEL: int = 2


func _init() -> void:
	var failures: Array[String] = []
	var version_info: Dictionary = Engine.get_version_info()
	var actual_version: String = str(version_info.get("string", "unknown"))
	var main_scene: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	var untyped_level: int = int(
		ProjectSettings.get_setting("debug/gdscript/warnings/untyped_declaration", 0)
	)
	var inferred_level: int = int(
		ProjectSettings.get_setting("debug/gdscript/warnings/inferred_declaration", 0)
	)

	if not actual_version.begins_with(EXPECTED_ENGINE_VERSION_PREFIX):
		failures.append(
			"Expected Godot %s.x, received %s"
			% [EXPECTED_ENGINE_VERSION_PREFIX, actual_version]
		)

	if main_scene != EXPECTED_MAIN_SCENE:
		failures.append("Unexpected main scene: %s" % main_scene)

	if not FileAccess.file_exists(EXPECTED_MAIN_SCENE):
		failures.append("Main scene is missing: %s" % EXPECTED_MAIN_SCENE)

	if not FileAccess.file_exists("res://src/application/main.gd"):
		failures.append("Typed application bootstrap is missing")

	if untyped_level != REQUIRED_WARNING_LEVEL:
		failures.append("UNTYPED_DECLARATION must be configured as Error (2)")

	if inferred_level != REQUIRED_WARNING_LEVEL:
		failures.append("INFERRED_DECLARATION must be configured as Error (2)")

	if failures.is_empty():
		print("M0_SMOKE_PASS engine=%s" % actual_version)
		quit(0)
		return

	for failure: String in failures:
		push_error("M0_SMOKE_FAIL: %s" % failure)

	quit(1)
