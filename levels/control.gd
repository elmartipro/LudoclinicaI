extends Control

@onready var ventana = $CanvasLayer/VentanaEmergente
@onready var texto_ventana = $CanvasLayer/VentanaEmergente/TextoVentana
@onready var boton_mostrar = $CanvasLayer/MostrarVentana
@onready var boton_cerrar = $CanvasLayer/VentanaEmergente/CerrarVentana

func _ready():
	ventana.visible = false
	boton_mostrar.pressed.connect(_on_mostrar_ventana)
	boton_cerrar.pressed.connect(_on_cerrar_ventana)

func _on_mostrar_ventana():
	texto_ventana.text = "🩺 ¡Bienvenido a Ludoclínica!"
	ventana.popup_centered()  # Muestra la ventana centrada

func _on_cerrar_ventana():
	ventana.hide()


func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://UI/pantalla_de_incio.tscn")
