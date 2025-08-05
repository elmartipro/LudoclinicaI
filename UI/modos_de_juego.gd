extends Control


func _on_texture_button_pressed():
	get_tree().change_scene_to_file("res://UI/pantalla_de_incio.tscn")
	
	


func _on_juego_1_pressed() -> void:
	get_tree().change_scene_to_file("res://levels/main.tscn")
