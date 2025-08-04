extends Control

# Musica De el juego 
var sonido_fondo = preload("res://UI/no-copyright-music-corporate-medical-338514 (2).mp3") 

func _ready():
	MusicaDeFondo.stream = sonido_fondo
	MusicaDeFondo.play()
# Jugar redirecciona a la escena de escoger modos 
func _on_play_pressed(): 
	get_tree().change_scene_to_file("res://UI/modos_de_juego.tscn")
