extends Control

# Musica De el juego 
var sonido_fondo := preload("res://UI & Audio/Musica y Audios/main_music.mp3") 


func _ready():
 # Verifica si el stream actual es diferente al que quieres usar
	if MusicaDeFondo.stream != sonido_fondo:
		MusicaDeFondo.stream = sonido_fondo

	# Reproduce la música solo si no está sonando
		if not MusicaDeFondo.playing:
			MusicaDeFondo.play()



# Jugar redirecciona a la escena de escoger modos 
func _on_play_pressed(): 
	get_tree().change_scene_to_file("res://UI & Audio/Pantalla de Inicio/modos_de_juego.tscn")


func _on_configuracion_pressed():
	get_tree().change_scene_to_file("res://UI & Audio/Pantalla de Inicio/configuracion.tscn")


func _on_salir_pressed():
	get_tree().quit()
