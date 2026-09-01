extends Control

const EXPECTED_ENGINE_VERSION_PREFIX: String = "4.7.2"

@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	var version_info: Dictionary = Engine.get_version_info()
	var actual_version: String = str(version_info.get("string", "unknown"))

	status_label.text = "M0 foundation ready\nGodot %s\nNo simulation systems are implemented." % actual_version

	if not actual_version.begins_with(EXPECTED_ENGINE_VERSION_PREFIX):
		push_error(
			"Expected Godot %s.x, received %s"
			% [EXPECTED_ENGINE_VERSION_PREFIX, actual_version]
		)
