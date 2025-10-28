extends Control


func _ready() -> void:
	TitleBackground.ensure_visible()


func _on_volver_2_pressed() -> void:
	get_tree().change_scene_to_file("res://UI & Audio/Pantalla de Inicio/pantalla_de_incio.tscn")


func _on_borrar_datos_pressed() -> void:
	var deleted := false
	for path in ["user://exam_results.json", "user://config.cfg"]:
		if FileAccess.file_exists(path):
			var error := DirAccess.remove_absolute(path)
			if error == OK:
				deleted = true
	if deleted:
		OS.alert("Los datos guardados se eliminaron correctamente.", "Datos reiniciados")
	else:
		OS.alert("No se encontraron datos guardados para eliminar.", "Datos reiniciados")


func _on_music_control_value_changed(_value: float) -> void:
	pass
