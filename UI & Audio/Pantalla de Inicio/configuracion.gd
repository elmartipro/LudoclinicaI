extends Control

signal back_requested
signal data_cleared(successful: bool)

@onready var volver_boton: TextureButton = $Volver2
@onready var estado_label: Label = $ClearStatus

func show_panel() -> void:
	visible = true
	if volver_boton:
		volver_boton.grab_focus()

func hide_panel() -> void:
	visible = false

func _on_volver_2_pressed() -> void:
	hide_panel()
	emit_signal("back_requested")

func _on_clear_data_button_pressed() -> void:
	var deleted_any := false
	for path in _get_data_paths():
		if FileAccess.file_exists(path):
			var result := DirAccess.remove_absolute(path)
			if result == OK:
				deleted_any = true
			else:
				printerr("No se pudo borrar el archivo", path)
	if deleted_any:
		_set_status("Datos eliminados correctamente.", true)
	else:
		_set_status("No se encontraron datos para borrar.", false)
	emit_signal("data_cleared", deleted_any)

func _set_status(texto: String, exito: bool) -> void:
	if estado_label:
		estado_label.text = texto
		var color := Color.html("#d8f6ec") if exito else Color.html("#f6d8d8")
		estado_label.add_theme_color_override("font_color", color)

func _get_data_paths() -> PackedStringArray:
	return [
		"user://exam_results.json",
		"user://config.cfg"
	]
