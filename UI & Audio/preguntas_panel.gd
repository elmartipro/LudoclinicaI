extends CanvasLayer

signal panel_closed
signal panel_opened
signal pregunta_finalizada(resultado: Dictionary)
signal examen_finalizado(resumen: Dictionary)

const DEFAULT_TIEMPO_LIMITE: int = 40

var pregunta_actual: Dictionary = {}
var preguntas_por_categoria: Dictionary = {}
var preguntas_originales: Dictionary = {}
var indices_por_categoria: Dictionary = {}
var waiting_for_continue: bool = false
var aciertos: int = 0
var total_preguntas: int = 0
var preguntas_contestadas: int = 0
var examen_activo: bool = false
var ultima_correcta: bool = true
var tiempo_limite: int = DEFAULT_TIEMPO_LIMITE
var tiempo_restante: int = DEFAULT_TIEMPO_LIMITE
var categoria_actual: String = ""
var historial: Array = []
var categoria_stats: Dictionary = {}
var resultado_pregunta_actual: Dictionary = {}
var tiempo_pregunta_inicio: float = 0.0
var tiempo_total_respuestas: float = 0.0
var current_spot: Node = null
var accent_color: Color = Color.html("#68908d")
var cronometro_base_color: Color = Color.html("#68908d")
var cronometro_warning_color: Color = Color.html("#cc6666")
var background_alpha: float = 0.9
var background_target_color: Color = Color.TRANSPARENT
var info_panel_target_modulate: Color = Color.WHITE
var card_panel_target_modulate: Color = Color.WHITE
var info_panel_style_color: Color = Color.WHITE
var card_panel_style_color: Color = Color.WHITE
var question_style_target_color: Color = Color.WHITE
var feedback_style_target_color: Color = Color.WHITE
var continue_hint_base_color: Color = Color.WHITE
var continue_hint_hover_color: Color = Color.WHITE
var intro_tween: Tween = null
var timeout_tween: Tween = null

@onready var label_categoria: Label = $Categoria
@onready var label_pregunta: RichTextLabel = $Pregunta
@onready var label_feedback: RichTextLabel = $Feedback
@onready var label_cronometro: Label = $Cronometro
@onready var botones: Array = [$Card/Opciones/Boton0, $Card/Opciones/Boton1, $Card/Opciones/Boton2, $Card/Opciones/Boton3]
@onready var timer: Timer = $Card/Timer
@onready var categoria_icon: TextureRect = $Panel/CategoriaIcon
@onready var continue_hint: Label = $ContinueHint
@onready var score_label: Label = $"../Score"
@onready var background_rect: ColorRect = $ColorRect
@onready var card_panel: Panel = $Card
@onready var info_panel: Panel = $Panel
@onready var timeout_overlay: ColorRect = $TiempoFueraOverlay
@onready var timeout_label: Label = $TiempoFueraLabel

var icon_map = {
	"Epidemiología": preload("res://Assets/Icons/epidemiologia.svg"),
	"Fisiopatología": preload("res://Assets/Icons/fisiopatologia.svg"),
	"Manifestaciones clínicas y paraclínicas": preload("res://Assets/Icons/manifestaciones.svg"),
	"Diagnóstico diferencial": preload("res://Assets/Icons/diagnostico.svg"),
	"Tratamiento": preload("res://Assets/Icons/tratamiento.svg"),
	"Seguimiento": preload("res://Assets/Icons/seguimiento.svg"),
	"Cultura": preload("res://Assets/Icons/cultura.svg")
}

func _ready() -> void:
	hide()
	if background_rect:
		background_alpha = background_rect.color.a
	actualizar_colores_de_ui(Color.html("#1e272e"))
	_cargar_preguntas()
	_update_score_label()
	if continue_hint:
		continue_hint.visible = false
		continue_hint.mouse_filter = Control.MOUSE_FILTER_PASS
		continue_hint.mouse_entered.connect(_on_continue_hint_mouse_entered)
		continue_hint.mouse_exited.connect(_on_continue_hint_mouse_exited)
	if timeout_overlay:
		timeout_overlay.visible = false
		timeout_overlay.modulate = Color(1, 1, 1, 0)
	if timeout_label:
		timeout_label.visible = false
		timeout_label.modulate = Color(1, 1, 1, 0)
		timeout_label.scale = Vector2.ONE
	for i in range(botones.size()):
		botones[i].pressed.connect(_on_opcion_pressed.bind(i))
	timer.timeout.connect(_on_timer_tick)

func configurar_examen(total: int) -> void:
	total_preguntas = max(total, 0)
	preguntas_contestadas = 0
	aciertos = 0
	historial.clear()
	categoria_stats.clear()
	indices_por_categoria.clear()
	for categoria in preguntas_por_categoria.keys():
		indices_por_categoria[categoria] = 0
	examen_activo = total_preguntas > 0
	_update_score_label()

func _cargar_preguntas() -> void:
	var f = FileAccess.open("res://UI & Audio/preguntas_etapa_1.json", FileAccess.READ)
	if f:
		var parsed = JSON.parse_string(f.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			preguntas_por_categoria = parsed.duplicate(true)
			preguntas_originales = parsed.duplicate(true)
			for categoria in preguntas_por_categoria.keys():
				indices_por_categoria[categoria] = 0
		else:
			push_error("Formato JSON no esperado.")
	else:
		push_error("No se pudo abrir el archivo de preguntas.")

func mostrar_pregunta_de_categoria(cat: String, spot: Node) -> void:
	if not examen_activo:
		return
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
		indices_por_categoria[cat] = 0
	var pregunta = lista[indice]
	indices_por_categoria[cat] = indice + 1
	categoria_actual = cat
	current_spot = spot
	_mostrar_pregunta(pregunta, cat)

func _mostrar_pregunta(p: Dictionary, cat: String) -> void:
	pregunta_actual = p.duplicate(true)
	resultado_pregunta_actual.clear()
	label_categoria.text = cat
	label_pregunta.text = p.get("texto", "")
	_hide_timeout_effect()
	for i in range(botones.size()):
		if i < p["opciones"].size():
			botones[i].text = char(65 + i) + ") " + p["opciones"][i]
			botones[i].disabled = false
			botones[i].add_theme_color_override("font_color", accent_color.lerp(Color.WHITE, 0.5))
		else:
			botones[i].text = ""
			botones[i].disabled = true
	if botones.size() > 0:
		botones[0].grab_focus()
	label_feedback.text = ""
	waiting_for_continue = false
	_set_continue_hint("", false)
	tiempo_limite = DEFAULT_TIEMPO_LIMITE
	tiempo_restante = tiempo_limite
	tiempo_pregunta_inicio = Time.get_ticks_msec() / 1000.0
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
	if waiting_for_continue:
		return
	timer.stop()
	ultima_correcta = index == pregunta_actual.get("respuesta_correcta", -1)
	var retro = pregunta_actual.get("retroalimentacion", "")
	for b in botones:
		b.disabled = true
	label_feedback.clear()
	label_feedback.bbcode_enabled = true
	var respuesta_usuario_texto: String = ""
	if index >= 0 and index < pregunta_actual.get("opciones", []).size():
		respuesta_usuario_texto = pregunta_actual["opciones"][index]
	if ultima_correcta:
		aciertos += 1
		_update_score_label()
		label_feedback.text = "[color=#66bb66]¡Correcto![/color]

"
	else:
		label_feedback.text = "[color=#cc6666]¡Incorrecto![/color]
"
		var letra_correcta = char(65 + pregunta_actual.get("respuesta_correcta", 0))
		label_feedback.text += "La respuesta correcta era: [color=#66bb66]" + letra_correcta + "[/color]

"
	if retro != "":
		label_feedback.text += "[color=white]" + retro + "[/color]"
	_registrar_resultado(respuesta_usuario_texto, index, false)
	waiting_for_continue = true
	_set_continue_hint("Haz clic o presiona Enter para continuar", true)

func _registrar_resultado(respuesta_usuario_texto: String, indice_usuario: int, por_timeout: bool) -> void:
	var tiempo_fin = Time.get_ticks_msec() / 1000.0
	var tiempo_usado = max(tiempo_fin - tiempo_pregunta_inicio, 0.0)
	tiempo_total_respuestas += tiempo_usado
	var indice_correcto = pregunta_actual.get("respuesta_correcta", -1)
	var respuesta_correcta_texto = ""
	var opciones: Array = []
	if pregunta_actual.has("opciones"):
		opciones = pregunta_actual["opciones"].duplicate()
		if indice_correcto >= 0 and indice_correcto < opciones.size():
			respuesta_correcta_texto = opciones[indice_correcto]
	if categoria_actual != "":
		if not categoria_stats.has(categoria_actual):
			categoria_stats[categoria_actual] = {"correctas": 0, "incorrectas": 0}
		var registro_categoria: Dictionary = categoria_stats[categoria_actual]
		if ultima_correcta:
			registro_categoria["correctas"] = registro_categoria.get("correctas", 0) + 1
		else:
			registro_categoria["incorrectas"] = registro_categoria.get("incorrectas", 0) + 1
	var respuesta_usuario_indice = indice_usuario
	var respuesta_usuario_texto_final = respuesta_usuario_texto
	var respuesta_correcta_flag = ultima_correcta
	if por_timeout:
		respuesta_usuario_indice = -1
		respuesta_usuario_texto_final = "Sin respuesta"
		respuesta_correcta_flag = false
	var historial_entry = {
		"categoria": categoria_actual,
		"texto": pregunta_actual.get("texto", ""),
		"opciones": opciones,
		"respuesta_correcta": indice_correcto,
		"respuesta_correcta_texto": respuesta_correcta_texto,
		"respuesta_usuario": respuesta_usuario_indice,
		"respuesta_usuario_texto": respuesta_usuario_texto_final,
		"correcta": respuesta_correcta_flag,
		"retroalimentacion": pregunta_actual.get("retroalimentacion", ""),
		"tiempo": tiempo_usado
	}
	historial.append(historial_entry)
	resultado_pregunta_actual = historial_entry.duplicate(true)
	resultado_pregunta_actual["spot"] = current_spot

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
	if tiempo_restante <= 0:
		timer.stop()
		for b in botones:
			b.disabled = true
		ultima_correcta = false
		label_feedback.clear()
		label_feedback.bbcode_enabled = true
		label_feedback.text = "[color=#cc6666]¡Se acabó el tiempo![/color]
"
		var letra_correcta = char(65 + pregunta_actual.get("respuesta_correcta", 0))
		label_feedback.text += "La respuesta correcta era: [color=#66bb66]" + letra_correcta + "[/color]"
		_registrar_resultado("", -1, true)
		waiting_for_continue = true
		_set_continue_hint("Haz clic o presiona Enter para continuar", true)
		_show_time_out_effect()

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
	if intro_tween and intro_tween.is_running():
		intro_tween.kill()
		_finalize_intro_visuals()
	_hide_timeout_effect()
	timer.stop()
	hide()
	panel_closed.emit()
	if resultado_pregunta_actual.is_empty():
		return
	preguntas_contestadas += 1
	var resultado = resultado_pregunta_actual.duplicate(true)
	resultado_pregunta_actual.clear()
	current_spot = null
	pregunta_finalizada.emit(resultado)
	if preguntas_contestadas >= total_preguntas and examen_activo:
		examen_activo = false
		examen_finalizado.emit(_crear_resumen())

func _crear_resumen() -> Dictionary:
	var resumen = {
		"aciertos": aciertos,
		"total": total_preguntas,
		"historial": historial.duplicate(true),
		"categoria_stats": categoria_stats.duplicate(true),
		"tiempo_total_respuestas": tiempo_total_respuestas
	}
	return resumen

func _update_score_label() -> void:
	if score_label:
		if total_preguntas > 0:
			score_label.text = "Aciertos: %d / %d" % [aciertos, total_preguntas]
		else:
			score_label.text = "Aciertos: %d" % aciertos

func _set_continue_hint(text: String, show: bool) -> void:
	if continue_hint:
		continue_hint.text = text
		continue_hint.visible = show
		var target_color = continue_hint_base_color
		continue_hint.add_theme_color_override("font_color", target_color)

func _prepare_intro_animation() -> void:
	if intro_tween and intro_tween.is_running():
		intro_tween.kill()
		_finalize_intro_visuals()
	_hide_timeout_effect()
	intro_tween = null
	if background_rect:
		background_rect.modulate = Color(1, 1, 1, 0)
	if info_panel:
		info_panel.modulate = Color(info_panel_target_modulate.r, info_panel_target_modulate.g, info_panel_target_modulate.b, 0)
	if card_panel:
		card_panel.modulate = Color(card_panel_target_modulate.r, card_panel_target_modulate.g, card_panel_target_modulate.b, 0)
	if label_categoria:
		label_categoria.modulate = Color(1, 1, 1, 0)
		label_categoria.scale = Vector2(0.75, 0.75)
	if label_pregunta:
		label_pregunta.modulate = Color(1, 1, 1, 0)
	if label_feedback:
		label_feedback.modulate = Color(1, 1, 1, 0)
	for button in botones:
		if button:
			button.modulate = Color(1, 1, 1, 0)

func _play_intro_animation() -> void:
	intro_tween = create_tween()
	intro_tween.set_parallel(true)
	if background_rect:
		var background_track = intro_tween.parallel().tween_property(background_rect, "modulate:a", 1.0, 0.45)
		background_track.from(0.0)
		background_track.set_trans(Tween.TRANS_SINE)
		background_track.set_ease(Tween.EASE_OUT)
	if info_panel:
		var info_track = intro_tween.parallel().tween_property(info_panel, "modulate", info_panel_target_modulate, 0.35)
		info_track.from(Color(info_panel_target_modulate.r, info_panel_target_modulate.g, info_panel_target_modulate.b, 0))
		info_track.set_trans(Tween.TRANS_SINE)
		info_track.set_ease(Tween.EASE_OUT)
	if card_panel:
		var card_track = intro_tween.parallel().tween_property(card_panel, "modulate", card_panel_target_modulate, 0.4)
		card_track.from(Color(card_panel_target_modulate.r, card_panel_target_modulate.g, card_panel_target_modulate.b, 0))
		card_track.set_trans(Tween.TRANS_SINE)
		card_track.set_ease(Tween.EASE_OUT)
	if label_pregunta:
		var pregunta_track = intro_tween.parallel().tween_property(label_pregunta, "modulate:a", 1.0, 0.3)
		pregunta_track.from(0.0)
		pregunta_track.set_delay(0.1)
		pregunta_track.set_trans(Tween.TRANS_CUBIC)
		pregunta_track.set_ease(Tween.EASE_OUT)
	if label_feedback:
		var feedback_track = intro_tween.parallel().tween_property(label_feedback, "modulate:a", 1.0, 0.3)
		feedback_track.from(0.0)
		feedback_track.set_delay(0.15)
		feedback_track.set_trans(Tween.TRANS_CUBIC)
		feedback_track.set_ease(Tween.EASE_OUT)
	if label_categoria:
		var categoria_color_track = intro_tween.parallel().tween_property(label_categoria, "modulate", Color(1, 1, 1, 1.0), 0.3)
		categoria_color_track.from(Color(1, 1, 1, 0.0))
		categoria_color_track.set_delay(0.1)
		categoria_color_track.set_trans(Tween.TRANS_BACK)
		categoria_color_track.set_ease(Tween.EASE_OUT)
		var categoria_scale_track = intro_tween.parallel().tween_property(label_categoria, "scale", Vector2.ONE, 0.32)
		categoria_scale_track.from(Vector2(0.75, 0.75))
		categoria_scale_track.set_delay(0.1)
		categoria_scale_track.set_trans(Tween.TRANS_BACK)
		categoria_scale_track.set_ease(Tween.EASE_OUT)
	for button in botones:
		if button:
			var button_track = intro_tween.parallel().tween_property(button, "modulate:a", 1.0, 0.3)
			button_track.from(0.0)
			button_track.set_delay(0.18)
			button_track.set_trans(Tween.TRANS_SINE)
			button_track.set_ease(Tween.EASE_OUT)
	intro_tween.finished.connect(_finalize_intro_visuals)

func _finalize_intro_visuals() -> void:
	intro_tween = null
	if background_rect:
		background_rect.modulate = Color(1, 1, 1, 1)
	if info_panel:
		info_panel.modulate = info_panel_target_modulate
	if card_panel:
		card_panel.modulate = card_panel_target_modulate
	if label_categoria:
		label_categoria.modulate = Color(1, 1, 1, 1)
		label_categoria.scale = Vector2.ONE
	if label_pregunta:
		label_pregunta.modulate = Color(1, 1, 1, 1)
	if label_feedback:
		label_feedback.modulate = Color(1, 1, 1, 1)
	for button in botones:
		if button:
			button.modulate = Color(1, 1, 1, 1)

func _apply_stylebox_color(node: Control, style_name: String, color: Color) -> void:
	if not node:
		return
	var base_style = node.get_theme_stylebox(style_name, node.get_class())
	if base_style and base_style is StyleBoxFlat:
		var custom_style: StyleBoxFlat = base_style.duplicate()
		custom_style.bg_color = color
		custom_style.border_color = color
		node.add_theme_stylebox_override(style_name, custom_style)
	else:
		var fallback_style = StyleBoxFlat.new()
		fallback_style.bg_color = color
		fallback_style.border_color = color
		if node is RichTextLabel:
			fallback_style.corner_radius_top_left = 24
			fallback_style.corner_radius_top_right = 24
			fallback_style.corner_radius_bottom_left = 24
			fallback_style.corner_radius_bottom_right = 24
			fallback_style.content_margin_left = 24
			fallback_style.content_margin_right = 24
			fallback_style.content_margin_top = 18
			fallback_style.content_margin_bottom = 18
		elif node is Label:
			fallback_style.corner_radius_top_left = 18
			fallback_style.corner_radius_top_right = 18
			fallback_style.corner_radius_bottom_left = 18
			fallback_style.corner_radius_bottom_right = 18
			fallback_style.content_margin_left = 16
			fallback_style.content_margin_right = 16
			fallback_style.content_margin_top = 12
			fallback_style.content_margin_bottom = 12
		node.add_theme_stylebox_override(style_name, fallback_style)

func actualizar_colores_de_ui(base_color: Color) -> void:
	accent_color = base_color.lerp(Color.WHITE, 0.35)
	cronometro_base_color = base_color.lerp(Color.WHITE, 0.35)
	cronometro_warning_color = base_color.lerp(Color.RED, 0.45)
	continue_hint_base_color = base_color.lerp(Color.WHITE, 0.6)
	continue_hint_hover_color = base_color.lerp(Color.WHITE, 0.85)
	info_panel_target_modulate = Color(base_color.r, base_color.g, base_color.b, 0.92)
	card_panel_target_modulate = Color(base_color.r, base_color.g, base_color.b, 0.88)
	info_panel_style_color = base_color.lerp(Color.BLACK, 0.25)
	card_panel_style_color = base_color.lerp(Color.BLACK, 0.3)
	question_style_target_color = base_color.lerp(Color.WHITE, 0.65)
	feedback_style_target_color = base_color.lerp(Color.WHITE, 0.72)
	_apply_stylebox_color(label_pregunta, "normal", question_style_target_color)
	_apply_stylebox_color(label_feedback, "normal", feedback_style_target_color)
	_apply_stylebox_color(info_panel, "panel", info_panel_style_color)
	_apply_stylebox_color(card_panel, "panel", card_panel_style_color)
	_update_button_feedback_colors()

func _update_button_feedback_colors() -> void:
	for button in botones:
		if button:
			button.add_theme_color_override("font_color", accent_color.lerp(Color.WHITE, 0.5))
			button.add_theme_color_override("font_focus_color", accent_color.lerp(Color.WHITE, 0.8))
			button.add_theme_color_override("font_pressed_color", accent_color.lerp(Color.BLACK, 0.2))

func _hide_timeout_effect() -> void:
	if timeout_tween and timeout_tween.is_running():
		timeout_tween.kill()
	timeout_tween = null
	if timeout_overlay:
		timeout_overlay.visible = false
		timeout_overlay.modulate = Color(1, 1, 1, 0)
	if timeout_label:
		timeout_label.visible = false
		timeout_label.modulate = Color(1, 1, 1, 0)
		timeout_label.scale = Vector2.ONE

func _show_time_out_effect() -> void:
	if timeout_overlay:
		timeout_overlay.visible = true
	if timeout_label:
		timeout_label.visible = true
	timeout_tween = create_tween()
	timeout_tween.set_parallel(true)
	if timeout_overlay:
		var overlay_track = timeout_tween.parallel().tween_property(timeout_overlay, "modulate:a", 0.4, 0.35)
		overlay_track.from(0.0)
		overlay_track.set_trans(Tween.TRANS_SINE)
		overlay_track.set_ease(Tween.EASE_OUT)
	if timeout_label:
		var label_alpha_track = timeout_tween.parallel().tween_property(timeout_label, "modulate:a", 1.0, 0.35)
		label_alpha_track.from(0.0)
		label_alpha_track.set_trans(Tween.TRANS_SINE)
		label_alpha_track.set_ease(Tween.EASE_OUT)
		var label_scale_track = timeout_tween.parallel().tween_property(timeout_label, "scale", Vector2.ONE * 1.05, 0.4)
		label_scale_track.from(Vector2.ONE)
		label_scale_track.set_trans(Tween.TRANS_BACK)
		label_scale_track.set_ease(Tween.EASE_OUT)

func _on_continue_hint_mouse_entered() -> void:
	if continue_hint and continue_hint.visible:
		continue_hint.add_theme_color_override("font_color", continue_hint_hover_color)

func _on_continue_hint_mouse_exited() -> void:
	if continue_hint and continue_hint.visible:
		continue_hint.add_theme_color_override("font_color", continue_hint_base_color)
