extends CanvasLayer

signal respondida(correcta: bool)

var pregunta_actual: Dictionary
var preguntas_por_categoria: Dictionary

@onready var label_pregunta = $LabelPregunta
@onready var label_feedback = $LabelFeedback
@onready var botones = [
	$Opciones/Boton0,
	$Opciones/Boton1,
	$Opciones/Boton2,
	$Opciones/Boton3
]

func _ready() -> void:
	hide()
	_cargar_preguntas()
	for i in range(botones.size()):
		botones[i].pressed.connect(_on_opcion_pressed.bind(i))

func _cargar_preguntas() -> void:
	var f := FileAccess.open("res://UI & Audio/preguntas_etapa_1.json", FileAccess.READ)
	if f:
		var parsed = JSON.parse_string(f.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			preguntas_por_categoria = parsed
		else:
			push_error("Formato JSON no esperado.")
	else:
		push_error("No se pudo abrir el archivo de preguntas.")

func mostrar_pregunta_de_categoria(cat: String) -> void:
	if preguntas_por_categoria.has(cat):
		var lista: Array = preguntas_por_categoria[cat]
		if lista.size() > 0:
			_mostrar_pregunta(lista.pick_random())
		else:
			push_error("Categoría vacía: " + cat)
	else:
		push_error("Categoría no encontrada: " + cat)

func _mostrar_pregunta(p: Dictionary) -> void:
	pregunta_actual = p
	show()
	label_pregunta.text = p["texto"]
	for i in range(botones.size()):
		botones[i].text = char(65 + i) + ") " + p["opciones"][i]
		botones[i].disabled = false
	label_feedback.text = ""

func _on_opcion_pressed(index: int) -> void:
	var correcta = index == pregunta_actual["respuesta_correcta"]
	label_feedback.text = "Correcto" if correcta else "Incorrecto. " + str(pregunta_actual.get("retroalimentacion", ""))
	
	for b in botones:
		b.disabled = true
	
	respondida.emit(correcta)
	await get_tree().create_timer(1.5).timeout
	hide()
