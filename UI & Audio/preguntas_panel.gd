extends CanvasLayer

signal respondida(correcta: bool)
signal panel_closed
signal panel_opened
signal victoria_alcanzada(total_puntos: int)
signal derrota_alcanzada

const WIN_THRESHOLD = 15
const HEALTH_ICON = "✚"

var pregunta_actual: Dictionary = {}
var preguntas_por_categoria: Dictionary = {}
var preguntas_originales: Dictionary = {}
var waiting_for_continue: bool = false
var puntos: int = 0
var vidas: int = 3
var ultima_correcta: bool = true
var tiempo_limite: int = 45
var tiempo_restante: int = tiempo_limite
var accent_color: Color = Color.html("#68908d")
var cronometro_base_color: Color = Color.html("#68908d")
var cronometro_warning_color: Color = Color.html("#cc6666")

@onready var label_categoria: Label = $Categoria
@onready var label_pregunta: RichTextLabel = $Pregunta
@onready var label_feedback: RichTextLabel = $Feedback
@onready var label_cronometro: Label = $Cronometro
@onready var botones: Array = [$Card/Opciones/Boton0, $Card/Opciones/Boton1, $Card/Opciones/Boton2, $Card/Opciones/Boton3]
@onready var timer: Timer = $Card/Timer
@onready var categoria_icon: TextureRect = $Panel/CategoriaIcon
@onready var continue_hint: Label = $ContinueHint
@onready var score_label: Label = $"../Score"
@onready var health_label: Label = $"../Health"

var icon_map = {
		"Epidemiología": preload("res://Assets/Icons/epidemiologia.svg"),
		"Fisiopatología": preload("res://Assets/Icons/fisiopatologia.svg"),
		"Manifestaciones clínicas y paraclínicas": preload("res://Assets/Icons/manifestaciones.svg"),
		"Diagnóstico diferencial": preload("res://Assets/Icons/diagnostico.svg"),
		"Tratamiento": preload("res://Assets/Icons/tratamiento.svg"),
		"Seguimiento": preload("res://Assets/Icons/seguimiento.svg"),
		"Cultura": preload("res://Assets/Icons/cultura.svg"),
		"Health": preload("res://Assets/Icons/health.svg")
}

func _ready() -> void:
		hide()
		actualizar_colores_de_ui(Color.html("#1e272e"))
		_cargar_preguntas()
		_update_score_label()
		_update_health_label()
		if continue_hint:
				continue_hint.visible = false
		for i in range(botones.size()):
				botones[i].pressed.connect(_on_opcion_pressed.bind(i))
		timer.timeout.connect(_on_timer_tick)

func _cargar_preguntas() -> void:
		var f = FileAccess.open("res://UI & Audio/preguntas_etapa_1.json", FileAccess.READ)
		if f:
				var parsed = JSON.parse_string(f.get_as_text())
				if typeof(parsed) == TYPE_DICTIONARY:
						preguntas_por_categoria = parsed.duplicate(true)
						preguntas_originales = parsed.duplicate(true)
				else:
						push_error("Formato JSON no esperado.")
		else:
				push_error("No se pudo abrir el archivo de preguntas.")

func mostrar_pregunta_de_categoria(cat: String) -> void:
		if preguntas_por_categoria.has(cat):
				var lista: Array = preguntas_por_categoria[cat]
				if lista.size() == 0 and preguntas_originales.has(cat):
						preguntas_por_categoria[cat] = preguntas_originales[cat].duplicate(true)
						lista = preguntas_por_categoria[cat]
				if lista.size() > 0:
						var idx = randi() % lista.size()
						var pregunta = lista[idx]
						preguntas_por_categoria[cat].remove_at(idx)
						_mostrar_pregunta(pregunta, cat)
				else:
						push_error("Categoría vacía incluso tras reiniciar: " + cat)
		else:
				push_error("Categoría no encontrada: " + cat)

func _mostrar_pregunta(p: Dictionary, cat: String) -> void:
		pregunta_actual = p.duplicate(true)
		show()
		panel_opened.emit()
		label_categoria.text = cat
		label_pregunta.text = p["texto"]
		var opciones: Array = []
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
				botones[i].add_theme_color_override("font_color", accent_color.lerp(Color.WHITE, 0.5))
		if botones.size() > 0:
				botones[0].grab_focus()
		label_feedback.text = ""
		waiting_for_continue = false
		_set_continue_hint("", false)
		tiempo_restante = tiempo_limite
		timer.stop()
		timer.wait_time = 1
		timer.start()
		label_cronometro.text = str(tiempo_restante)
		label_cronometro.add_theme_color_override("font_color", cronometro_base_color)
		if icon_map.has(cat):
				categoria_icon.texture = icon_map[cat]
				categoria_icon.self_modulate = accent_color.lerp(Color.WHITE, 0.35)
		else:
				categoria_icon.texture = null

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
				if puntos >= WIN_THRESHOLD:
						label_feedback.text += "[color=#f1c40f]¡Has alcanzado la meta de %d puntos![/color]" % WIN_THRESHOLD
						respondida.emit(true)
						_trigger_victory()
						return
		else:
				label_feedback.text = "[color=#cc6666]¡Incorrecto![/color]\n"
				var letra_correcta = char(65 + pregunta_actual["respuesta_correcta"])
				label_feedback.text += "La respuesta correcta era: [color=#66bb66]" + letra_correcta + "[/color]\n\n"
		if retro != "":
				label_feedback.text += "[color=white]" + retro + "[/color]"
		respondida.emit(ultima_correcta)
		waiting_for_continue = true
		_set_continue_hint("Haz clic o presiona Enter para continuar", true)

func _on_timer_tick() -> void:
		tiempo_restante -= 1
		if tiempo_restante <= 10:
				if tiempo_restante % 2 == 0:
						label_cronometro.add_theme_color_override("font_color", cronometro_warning_color)
				else:
						label_cronometro.add_theme_color_override("font_color", cronometro_base_color)
		else:
				label_cronometro.add_theme_color_override("font_color", cronometro_base_color)
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
				_set_continue_hint("Haz clic o presiona Enter para continuar", true)

func _unhandled_input(event: InputEvent) -> void:
		if not waiting_for_continue:
				return
		if event is InputEventKey and event.pressed:
				_close_question()
		if event is InputEventMouseButton and event.pressed:
				_close_question()

func _close_question() -> void:
		waiting_for_continue = false
		_set_continue_hint("", false)
		if not ultima_correcta:
				_perder_vida()
				if vidas <= 0:
						return
		hide()
		panel_closed.emit()

func _update_score_label() -> void:
		if score_label:
				score_label.text = "Puntos: %d / %d" % [puntos, WIN_THRESHOLD]

func _update_health_label() -> void:
		if health_label:
				var icons = HEALTH_ICON.repeat(max(vidas, 0))
				if icons.is_empty():
						icons = "—"
				health_label.text = "Vidas: %s" % icons

func _perder_vida() -> void:
		vidas -= 1
		_update_health_label()
		if vidas <= 0:
				_game_over()

func _game_over() -> void:
		timer.stop()
		for b in botones:
				b.disabled = true
		waiting_for_continue = false
		hide()
		panel_closed.emit()
		derrota_alcanzada.emit()

func _set_continue_hint(text: String, show: bool) -> void:
		if continue_hint:
				continue_hint.text = text
				continue_hint.visible = show

func _trigger_victory() -> void:
		timer.stop()
		for b in botones:
				b.disabled = true
		waiting_for_continue = false
		_set_continue_hint("", false)
		hide()
		panel_closed.emit()
		victoria_alcanzada.emit(puntos)

func actualizar_colores_de_ui(color: Color) -> void:
		accent_color = color.lerp(Color.WHITE, 0.45)
		cronometro_base_color = accent_color.lerp(Color.WHITE, 0.25)
		cronometro_warning_color = Color.html("#cc6666").lerp(accent_color, 0.3)
		if label_categoria:
				label_categoria.add_theme_color_override("font_color", accent_color)
		if continue_hint:
				continue_hint.add_theme_color_override("font_color", accent_color.lerp(Color.WHITE, 0.2))
		if label_cronometro:
				label_cronometro.add_theme_color_override("font_color", cronometro_base_color)
		if categoria_icon:
				categoria_icon.self_modulate = accent_color.lerp(Color.WHITE, 0.35)
		for button in botones:
				if button:
						button.add_theme_color_override("font_color", accent_color.lerp(Color.WHITE, 0.5))
						button.add_theme_color_override("font_color_hover", accent_color)
						button.add_theme_color_override("font_color_pressed", accent_color.lerp(Color.BLACK, 0.25))
