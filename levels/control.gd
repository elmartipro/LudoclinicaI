extends Control

@onready var ventana = $CanvasLayer/VentanaEmergente
@onready var texto_ventana = $CanvasLayer/VentanaEmergente/TextoVentana
@onready var boton_mostrar = $CanvasLayer/MostrarVentana
@onready var boton_cerrar = $CanvasLayer/VentanaEmergente/CerrarVentana

func _ready():
	if ventana:
		ventana.visible = false
		boton_mostrar.pressed.connect(_on_mostrar_ventana)
		boton_cerrar.pressed.connect(_on_cerrar_ventana)
	else:
		print("No se encontro el nodo")

func _on_mostrar_ventana():
	texto_ventana.text = "🩺 ¡Bienvenido a Ludoclínica!"
	ventana.visible = true
	ventana.set_position((get_viewport_rect().size - ventana.size) / 2) 


func _on_cerrar_ventana():
	ventana.visible = false


func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://UI/pantalla_de_incio.tscn")
