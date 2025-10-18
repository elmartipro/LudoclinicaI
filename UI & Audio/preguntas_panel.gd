extends CanvasLayer

signal respondida(correcta: bool)
signal panel_closed
signal panel_opened   # notifica cuando se abre el panel

var pregunta_actual: Dictionary
var preguntas_por_categoria: Dictionary
var preguntas_originales: Dictionary   # backup of all questions
var waiting_for_continue: bool = false

var puntos: int = 0
var vidas: int = 3
var ultima_correcta: bool = true  

# Tiempo límite
var tiempo_limite: int = 45
var tiempo_restante: int = tiempo_limite

@onready var label_categoria = $Categoria
@onready var label_pregunta = $Pregunta
@onready var label_feedback = $Feedback
@onready var label_cronometro = $Cronometro  
@onready var botones = [
	$Card/Opciones/Boton0, $Card/Opciones/Boton1, $Card/Opciones/Boton2, $Card/Opciones/Boton3
]
@onready var timer = $Card/Timer   

@onready var categoria_icon = $Panel/CategoriaIcon  # 🔥 reference to TextureRect

var icon_map := {
	"Epidemiología": preload("res://Assets/Icons/epidemiologia.svg"),
	"Fisiopatología": preload("res://Assets/Icons/fisiopatologia.svg"),
	"Manifestaciones clínicas y paraclínicas": preload("res://Assets/Icons/manifestaciones.svg"),
	"Diagnóstico diferencial": preload("res://Assets/Icons/diagnostico.svg"),
	"Tratamiento": preload("res://Assets/Icons/tratamiento.svg"),
	"Seguimiento": preload("res://Assets/Icons/seguimiento.svg"),
	"Cultura": preload("res://Assets/Icons/cultura.svg"),
	"Health": preload("res://Assets/Icons/health.svg")
}

# HUD
@onready var score_label = $"../Score"
@onready var health_label = $"../Health"

func _ready() -> void:
	hide()
	_cargar_preguntas()
	_update_score_label()
	_update_health_label()
	for i in range(botones.size()):
		botones[i].pressed.connect(_on_opcion_pressed.bind(i))

	timer.timeout.connect(_on_timer_tick)

# --- Load & Backup Questions ---
func _cargar_preguntas() -> void:
	var f := FileAccess.open("res://UI & Audio/preguntas_etapa_1.json", FileAccess.READ)
	if f:
		var parsed = JSON.parse_string(f.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			preguntas_por_categoria = parsed.duplicate(true)   # working copy
			preguntas_originales = parsed.duplicate(true)      # 🔥 backup
		else:
			push_error("Formato JSON no esperado.")
	else:
		push_error("No se pudo abrir el archivo de preguntas.")

# --- Show Question by Category ---
func mostrar_pregunta_de_categoria(cat: String) -> void:
	if preguntas_por_categoria.has(cat):
		var lista: Array = preguntas_por_categoria[cat]

		# 🔥 Reset pool if empty
		if lista.size() == 0 and preguntas_originales.has(cat):
			preguntas_por_categoria[cat] = preguntas_originales[cat].duplicate(true)
			lista = preguntas_por_categoria[cat]

		if lista.size() > 0:
			var idx = randi() % lista.size()
			var pregunta = lista[idx]

			# 🔥 remove from current pool
			preguntas_por_categoria[cat].remove_at(idx)

			_mostrar_pregunta(pregunta, cat)
		else:
			push_error("Categoría vacía incluso tras reiniciar: " + cat)
	else:
		push_error("Categoría no encontrada: " + cat)

# --- Display Question ---
func _mostrar_pregunta(p: Dictionary, cat: String) -> void:
	pregunta_actual = p.duplicate(true)
	show()
	panel_opened.emit()
	label_categoria.text = cat
	label_pregunta.text = p["texto"]

	# --- Randomize answers ---
	var opciones = []
	for i in range(p["opciones"].size()):
		opciones.append({"texto": p["opciones"][i], "correcta": i == p["respuesta_correcta"]})

	opciones.shuffle()

	pregunta_actual["opciones"] = []
	for i in range(opciones.size()):
		pregunta_actual["opciones"].append(opciones[i]["texto"])
		if opciones[i]["correcta"]:
			pregunta_actual["respuesta_correcta"] = i

	for i in range(botones.size()):
		botones[i].text = char(65 + i) + ") " + pregunta_actual["opciones"][i]
		botones[i].disabled = false

	label_feedback.text = ""
	waiting_for_continue = false

	# Reset timer
	tiempo_restante = tiempo_limite
	timer.stop()
	timer.wait_time = 1
	timer.start()
	label_cronometro.text = str(tiempo_restante)

	# Update category icon
	if icon_map.has(cat):
		categoria_icon.texture = icon_map[cat]
		categoria_icon.self_modulate = Color.html("#2a7870")
	else:
		categoria_icon.texture = null

# --- Answer Handling ---
func _on_opcion_pressed(index: int) -> void:
	timer.stop()
	ultima_correcta = index == pregunta_actual["respuesta_correcta"]
	var retro = pregunta_actual.get("retroalimentacion", "")

	for b in botones:
		b.disabled = true

	label_feedback.clear()
	label_feedback.bbcode_enabled = true

	if ultima_correcta:
		puntos += 1
		_update_score_label()
		label_feedback.text = "[color=#66bb66]¡Correcto![/color]\n\n"
	else:
		label_feedback.text = "[color=#cc6666]¡Incorrecto![/color]\n"
		var letra_correcta = char(65 + pregunta_actual["respuesta_correcta"])
		label_feedback.text += "La respuesta correcta era: [color=#66bb66]" + letra_correcta + "[/color]\n\n"

	if retro != "":
		label_feedback.text += "[color=white]" + retro + "[/color]"

	respondida.emit(ultima_correcta)
	waiting_for_continue = true

# --- Timer Tick ---
func _on_timer_tick() -> void:
	tiempo_restante -= 1
	if tiempo_restante <= 10:
		if tiempo_restante % 2 == 0:
			label_cronometro.add_theme_color_override("font_color", Color.html("#cc6666"))
		else:
			label_cronometro.add_theme_color_override("font_color", Color.html("#68908d"))
	else:
		label_cronometro.add_theme_color_override("font_color", Color.html("#68908d"))

	label_cronometro.text = str(tiempo_restante)

	if tiempo_restante <= 0:
		timer.stop()
		for b in botones:
			b.disabled = true

		ultima_correcta = false
		var letra_correcta = char(65 + pregunta_actual["respuesta_correcta"])

		label_feedback.clear()
		label_feedback.bbcode_enabled = true
		label_feedback.text = "[color=#cc6666]¡Se acabó el tiempo![/color]\n"
		label_feedback.text += "La respuesta correcta era: [color=#66bb66]" + letra_correcta + "[/color]"

		waiting_for_continue = true

# --- Close Question ---
func _unhandled_input(event: InputEvent) -> void:
	if not waiting_for_continue:
		return
	if event is InputEventKey and event.pressed:
		_close_question()
	if event is InputEventMouseButton and event.pressed:
		_close_question()

func _close_question():
	waiting_for_continue = false
	if not ultima_correcta:
		_perder_vida()
	hide()
	panel_closed.emit()

# --- HUD Updates ---
func _update_score_label():
	if score_label:
		score_label.text = "Puntos: " + str(puntos)

func _update_health_label():
	if health_label:
		health_label.text = "Vidas: " + str(vidas)

func _perder_vida():
	vidas -= 1
	_update_health_label()
	if vidas <= 0:
		_game_over()

func _game_over():
	get_tree().reload_current_scene()
