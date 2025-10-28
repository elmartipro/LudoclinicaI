extends Node

enum Mode {
	FACIL,
	EXAMEN
}

const ATTEMPT_FILE: String = "user://exam_attempts.json"

var current_mode: Mode = Mode.FACIL
var exam_attempts: Array = []

func _ready() -> void:
	_load_attempts()

func set_mode(mode: Mode) -> void:
	current_mode = mode

func is_exam_mode() -> bool:
	return current_mode == Mode.EXAMEN

func record_exam_attempt(data: Dictionary) -> void:
	exam_attempts.append(data)
	_save_attempts()

func get_attempts() -> Array:
	return exam_attempts.duplicate(true)

func _load_attempts() -> void:
	if not FileAccess.file_exists(ATTEMPT_FILE):
		exam_attempts = []
		return
	var file = FileAccess.open(ATTEMPT_FILE, FileAccess.READ)
	if file == null:
		exam_attempts = []
		return
	var content = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(content)
	if typeof(parsed) == TYPE_ARRAY:
		exam_attempts = parsed
	else:
		exam_attempts = []

func _save_attempts() -> void:
	var file = FileAccess.open(ATTEMPT_FILE, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(exam_attempts))
	file.close()
