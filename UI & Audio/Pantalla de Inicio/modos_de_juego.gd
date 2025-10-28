extends Control

func _on_juego_1_pressed() -> void:
	if GameModeManager != null:
		GameModeManager.set_mode(GameModeManager.Mode.FACIL)
	get_tree().change_scene_to_file("res://levels/main.tscn")

func _on_juego_2_pressed() -> void:
	if GameModeManager != null:
		GameModeManager.set_mode(GameModeManager.Mode.EXAMEN)
	get_tree().change_scene_to_file("res://levels/main_exam.tscn")

func _on_volver_1_pressed() -> void:
	get_tree().change_scene_to_file("res://UI & Audio/Pantalla de Inicio/pantalla_de_incio.tscn")
