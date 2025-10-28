extends Control

# Musica De el juego
var sonido_fondo := preload("res://UI & Audio/Musica y Audios/main_music.mp3")

@onready var background_video: VideoStreamPlayer = $BackgroundVideo
@onready var main_menu: Control = $MainMenu
@onready var config_panel: Control = $Configuracion

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

	if background_video and not background_video.playing:
		background_video.play()

	if config_panel:
		if config_panel.has_method("hide_panel"):
			config_panel.hide_panel()
		else:
			config_panel.visible = false
		if config_panel.has_signal("back_requested"):
			config_panel.connect("back_requested", Callable(self, "_on_config_back_requested"))
		if config_panel.has_signal("data_cleared"):
			config_panel.connect("data_cleared", Callable(self, "_on_config_data_cleared"))

func _on_play_pressed():
	get_tree().change_scene_to_file("res://UI & Audio/Pantalla de Inicio/modos_de_juego.tscn")

func _on_configuracion_pressed():
	if main_menu:
		main_menu.visible = false
	if config_panel:
		if config_panel.has_method("show_panel"):
			config_panel.show_panel()
		else:
			config_panel.visible = true

func _on_salir_pressed():
	get_tree().quit()

func _on_config_back_requested() -> void:
	if config_panel:
		if config_panel.has_method("hide_panel"):
			config_panel.hide_panel()
		else:
			config_panel.visible = false
	if main_menu:
		main_menu.visible = true
	if main_menu and main_menu.has_node("Buttons/Configuracion"):
		var button := main_menu.get_node("Buttons/Configuracion")
		if button is BaseButton:
			button.grab_focus()

func _on_config_data_cleared(_success: bool) -> void:
	pass
