extends Node

func _ready() -> void:
	# Optional: force redraw or init code
	RenderingServer.force_draw(true)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # Escape defaults to "ui_cancel"
		get_tree().reload_current_scene()     # Restart the game
