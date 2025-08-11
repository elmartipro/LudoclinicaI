extends Control

signal respondida(correcta: bool)

var pregunta_actual: Dictionary
var preguntas: Array = []
var indice_pregunta_actual: int = 0

func _ready():
	cargar_preguntas()
	mostrar_siguiente_pregunta()

func cargar_preguntas():
	var archivo = FileAccess.open("res://UI/preguntas.json", FileAccess.READ)
	if archivo:
		var contenido = archivo.get_as_text()
		preguntas = JSON.parse_string(contenido)
	else:
		push_error("No se pudo abrir el archivo de preguntas.")

func mostrar_siguiente_pregunta():
	if indice_pregunta_actual < preguntas.size():
		var pregunta = preguntas[indice_pregunta_actual]
		mostrar_pregunta(pregunta)
	else:
		$LabelPregunta.text = "¡Juego terminado!"


func mostrar_pregunta(pregunta: Dictionary):
	pregunta_actual = pregunta
	visible = true
	$LabelPregunta.text = pregunta["texto"]

	for i in 4:
		var boton = $Opciones.get_child(i)
		boton.text = char(65 + i) + ") " + pregunta["opciones"][i]

		boton.disabled = false  # Asegura que estén habilitados

	$LabelFeedback.text = ""  # Limpiar retroalimentación anteriorS

func _on_Opcion_pressed(index: int) -> void:
	var correcta = index == pregunta_actual["respuesta_correcta"]

	if correcta:
		$LabelFeedback.text = "✅ ¡Correcto!"
	else:
		$LabelFeedback.text = "❌ Incorrecto. " + pregunta_actual.get("retroalimentacion", "")

	# Desactivar los botones
	for i in 4:
		$Opciones.get_child(i).disabled = true

	respondida.emit(correcta)

	await get_tree().create_timer(2.0).timeout
	indice_pregunta_actual += 1
	mostrar_siguiente_pregunta()
