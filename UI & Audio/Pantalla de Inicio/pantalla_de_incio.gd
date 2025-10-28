extends Control

# Musica De el juego
var sonido_fondo := preload("res://UI & Audio/Musica y Audios/main_music.mp3")

func _ready():
	TitleBackground.ensure_visible()
	# Make sure we assign the right stream
	if MusicaDeFondo.stream != sonido_fondo:
		MusicaDeFondo.stream = sonido_fondo

	# Ensure it loops forever
	if MusicaDeFondo.stream is AudioStream:
		MusicaDeFondo.stream.set_loop(true)  # Godot 4.x

	# Play if not already playing
	if not MusicaDeFondo.playing:
		MusicaDeFondo.play()


# Jugar redirecciona a la escena de escoger modos
func _on_play_pressed():
	TitleBackground.hide_background()
	get_tree().change_scene_to_file("res://UI & Audio/Pantalla de Inicio/modos_de_juego.tscn")


func _on_configuracion_pressed():
	get_tree().change_scene_to_file("res://UI & Audio/Pantalla de Inicio/configuracion.tscn")


func _on_salir_pressed():
	TitleBackground.hide_background()
	get_tree().quit()
