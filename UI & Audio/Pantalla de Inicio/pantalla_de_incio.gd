extends Control

# Musica De el juego
var sonido_fondo := preload("res://UI & Audio/Musica y Audios/main_music.mp3")

@onready var guide_overlay: CanvasLayer = $GuideOverlay
@onready var enciclopedia_button: Button = $"VBoxContainer/Enciclopedia"

func _ready():
	# Make sure we assign the right stream
	if MusicaDeFondo.stream != sonido_fondo:
		MusicaDeFondo.stream = sonido_fondo

	# Ensure it loops forever
	if MusicaDeFondo.stream is AudioStream:
		MusicaDeFondo.stream.set_loop(true)  # Godot 4.x

	# Play if not already playing
	if not MusicaDeFondo.playing:
		MusicaDeFondo.play()

	if guide_overlay:
		guide_overlay.overlay_closed.connect(_on_guide_overlay_closed)


# Jugar redirecciona a la escena de escoger modos
func _on_play_pressed():
	get_tree().change_scene_to_file("res://UI & Audio/Pantalla de Inicio/modos_de_juego.tscn")


func _on_configuracion_pressed():
	get_tree().change_scene_to_file("res://UI & Audio/Pantalla de Inicio/configuracion.tscn")


func _on_salir_pressed():
	get_tree().quit()


func _on_enciclopedia_pressed():
	if guide_overlay:
		guide_overlay.open()


func _on_guide_overlay_closed() -> void:
	if enciclopedia_button:
		enciclopedia_button.grab_focus()
