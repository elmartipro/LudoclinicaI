extends "res://UI & Audio/preguntas_panel.gd"

signal examen_pregunta_finalizada(datos: Dictionary)

var categoria_actual: String = ""
var indices_por_categoria: Dictionary = {}
var respuestas_historial: Array = []
var total_preguntas: int = 0
var pregunta_actual_indice: int = 0
var inicio_pregunta_segundos: float = 0.0
var indice_respuesta_seleccionada: int = -1

func _ready() -> void:
	super()
	tiempo_limite = 40
	if timer:
		timer.wait_time = 1
	vidas = 0
	indices_por_categoria.clear()
	respuestas_historial.clear()
	if score_label:
		score_label.text = "Aciertos: 0"
	if health_label:
		health_label.visible = false

func configurar_total_preguntas(total: int) -> void:
	total_preguntas = max(total, 0)

func mostrar_pregunta_de_categoria(cat: String) -> void:
	if not preguntas_por_categoria.has(cat):
		push_error("Categoría no encontrada: " + cat)
		return
	var lista: Array = preguntas_por_categoria[cat]
	if lista.size() == 0:
		push_error("Categoría vacía: " + cat)
		return
	var indice: int = indices_por_categoria.get(cat, 0)
	if indice >= lista.size():
		indice = 0
	indices_por_categoria[cat] = indice + 1
	var pregunta: Dictionary = lista[indice]
	categoria_actual = cat
	indice_respuesta_seleccionada = -1
	pregunta_actual_indice += 1
	inicio_pregunta_segundos = Time.get_ticks_msec() / 1000.0
	_mostrar_pregunta_examen(pregunta, cat)

func _mostrar_pregunta_examen(p: Dictionary, cat: String) -> void:
	pregunta_actual = p.duplicate(true)
	label_categoria.text = cat
	label_pregunta.text = p.get("texto", "")
	_hide_timeout_effect()
	var opciones: Array = []
	if p.has("opciones"):
		opciones = p["opciones"].duplicate(true)
	pregunta_actual["opciones"] = opciones
	pregunta_actual["respuesta_correcta"] = p.get("respuesta_correcta", 0)
	for i in range(botones.size()):
		var texto_opcion: String = ""
		if i < opciones.size():
			texto_opcion = opciones[i]
		botones[i].text = char(65 + i) + ") " + texto_opcion
		botones[i].disabled = false
		botones[i].add_theme_color_override("font_color", accent_color.lerp(Color.WHITE, 0.5))
	if botones.size() > 0:
		botones[0].grab_focus()
	label_feedback.text = ""
	waiting_for_continue = false
	_set_continue_hint("", false)
	tiempo_restante = tiempo_limite
	if timer:
		timer.stop()
		timer.wait_time = 1
		timer.start()
	label_cronometro.text = str(tiempo_restante)
	label_cronometro.add_theme_color_override("font_color", cronometro_base_color)
	if icon_map.has(cat):
		categoria_icon.texture = icon_map[cat]
		categoria_icon.self_modulate = Color.WHITE
	else:
		categoria_icon.texture = null
	_prepare_intro_animation()
	show()
	panel_opened.emit()
	_play_intro_animation()

func _on_opcion_pressed(index: int) -> void:
	indice_respuesta_seleccionada = index
	if timer:
		timer.stop()
	ultima_correcta = index == pregunta_actual.get("respuesta_correcta", -1)
	var retro: String = pregunta_actual.get("retroalimentacion", "")
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
		var letra_correcta: String = char(65 + pregunta_actual.get("respuesta_correcta", 0))
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
	label_cronometro.text = str(max(tiempo_restante, 0))
	if tiempo_restante > 0:
		return
	if timer:
		timer.stop()
	for b in botones:
		b.disabled = true
	ultima_correcta = false
	indice_respuesta_seleccionada = -1
	var letra_correcta: String = char(65 + pregunta_actual.get("respuesta_correcta", 0))
	label_feedback.clear()
	label_feedback.bbcode_enabled = true
	label_feedback.text = "[color=#cc6666]¡Se acabó el tiempo![/color]\n"
	label_feedback.text += "La respuesta correcta era: [color=#66bb66]" + letra_correcta + "[/color]"
	waiting_for_continue = true
	_set_continue_hint("Haz clic o presiona Enter para continuar", true)
	_show_time_out_effect()
	respondida.emit(false)

func _close_question() -> void:
	waiting_for_continue = false
	_set_continue_hint("", false)
	if intro_tween and intro_tween.is_running():
		intro_tween.kill()
		_finalize_intro_visuals()
	_hide_timeout_effect()
	var tiempo_respuesta: float = max(Time.get_ticks_msec() / 1000.0 - inicio_pregunta_segundos, 0.0)
	var opciones: Array = pregunta_actual.get("opciones", [])
	var respuesta_correcta_texto: String = ""
	if pregunta_actual.has("respuesta_correcta") and pregunta_actual["respuesta_correcta"] < opciones.size():
		respuesta_correcta_texto = opciones[pregunta_actual["respuesta_correcta"]]
	var respuesta_jugador_texto: String = ""
	if indice_respuesta_seleccionada >= 0 and indice_respuesta_seleccionada < opciones.size():
		respuesta_jugador_texto = opciones[indice_respuesta_seleccionada]
	var registro: Dictionary = {
		"categoria": categoria_actual,
		"pregunta": pregunta_actual.get("texto", ""),
		"correcta": ultima_correcta,
		"respuesta_jugador": respuesta_jugador_texto,
		"respuesta_correcta": respuesta_correcta_texto,
		"tiempo": tiempo_respuesta,
		"sin_respuesta": indice_respuesta_seleccionada == -1
	}
	respuestas_historial.append(registro)
	examen_pregunta_finalizada.emit(registro)
	hide()
	panel_closed.emit()

func _update_score_label() -> void:
	if score_label:
		score_label.text = "Aciertos: %d" % puntos

func _perder_vida() -> void:
	pass
