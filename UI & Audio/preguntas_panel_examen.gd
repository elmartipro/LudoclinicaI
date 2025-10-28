extends CanvasLayer

signal pregunta_respondida(resultado: Dictionary)
signal panel_closed
signal panel_opened

var pregunta_actual: Dictionary = {}
var preguntas_por_categoria: Dictionary = {}
var preguntas_indices: Dictionary = {}
var waiting_for_continue: bool = false
var tiempo_limite: int = 40
var tiempo_restante: int = 40
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
var pregunta_inicio_timestamp: float = 0.0

@onready var label_categoria: Label = $Categoria
@onready var label_pregunta: RichTextLabel = $Pregunta
@onready var label_feedback: RichTextLabel = $Feedback
@onready var label_cronometro: Label = $Cronometro
@onready var botones: Array = [$Card/Opciones/Boton0, $Card/Opciones/Boton1, $Card/Opciones/Boton2, $Card/Opciones/Boton3]
@onready var timer: Timer = $Card/Timer
@onready var categoria_icon: TextureRect = $Panel/CategoriaIcon
@onready var continue_hint: Label = $ContinueHint
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
	if background_rect != null:
		background_alpha = background_rect.color.a
	actualizar_colores_de_ui(Color.html("#1e272e"))
	_cargar_preguntas()
	if continue_hint != null:
		continue_hint.visible = false
		continue_hint.mouse_filter = Control.MOUSE_FILTER_PASS
		continue_hint.mouse_entered.connect(_on_continue_hint_mouse_entered)
		continue_hint.mouse_exited.connect(_on_continue_hint_mouse_exited)
	if timeout_overlay != null:
		timeout_overlay.visible = false
		timeout_overlay.modulate = Color(1, 1, 1, 0)
	if timeout_label != null:
		timeout_label.visible = false
		timeout_label.modulate = Color(1, 1, 1, 0)
		timeout_label.scale = Vector2.ONE
	for i in range(botones.size()):
		botones[i].pressed.connect(_on_opcion_pressed.bind(i))
	timer.timeout.connect(_on_timer_tick)

func _cargar_preguntas() -> void:
	var file = FileAccess.open("res://UI & Audio/preguntas_etapa_1.json", FileAccess.READ)
	if file == null:
		push_error("No se pudo abrir el archivo de preguntas.")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Formato JSON no esperado.")
		return
	preguntas_por_categoria = parsed.duplicate(true)
	preguntas_indices.clear()
	for key in preguntas_por_categoria.keys():
		preguntas_indices[key] = 0

func mostrar_pregunta_de_categoria(categoria: String) -> void:
	if not preguntas_por_categoria.has(categoria):
		push_error("Categoría no encontrada: " + categoria)
		return
	var lista: Array = preguntas_por_categoria[categoria]
	if lista.size() == 0:
		push_error("Categoría sin preguntas disponibles: " + categoria)
		return
	var index = preguntas_indices.get(categoria, 0)
	if index >= lista.size():
		index = 0
	preguntas_indices[categoria] = index + 1
	var pregunta = lista[index]
	_mostrar_pregunta(pregunta, categoria)

func _mostrar_pregunta(p: Dictionary, categoria: String) -> void:
	pregunta_actual = p.duplicate(true)
	label_categoria.text = categoria
	label_pregunta.text = pregunta_actual.get("texto", "")
	_hide_timeout_effect()
	var opciones: Array = []
	var respuesta_correcta = pregunta_actual.get("respuesta_correcta", 0)
	for i in range(pregunta_actual.get("opciones", []).size()):
		var opcion_texto = pregunta_actual["opciones"][i]
		var registro = {
			"texto": opcion_texto,
			"correcta": i == respuesta_correcta
		}
		opciones.append(registro)
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
	if icon_map.has(categoria):
		categoria_icon.texture = icon_map[categoria]
		categoria_icon.self_modulate = Color.WHITE
	else:
		categoria_icon.texture = null
	_prepare_intro_animation()
	show()
	panel_opened.emit()
	_play_intro_animation()
	pregunta_inicio_timestamp = Time.get_ticks_msec() / 1000.0

func _on_opcion_pressed(index: int) -> void:
	timer.stop()
	var correcta = index == pregunta_actual.get("respuesta_correcta", 0)
	var retro = pregunta_actual.get("retroalimentacion", "")
	for boton in botones:
		boton.disabled = true
	label_feedback.clear()
	label_feedback.bbcode_enabled = true
	var tiempo_empleado = _calcular_tiempo_empleado()
	var letra_correcta = char(65 + pregunta_actual.get("respuesta_correcta", 0))
	if correcta:
		label_feedback.text = "[color=#66bb66]¡Correcto![/color]\n\n"
	else:
		label_feedback.text = "[color=#cc6666]¡Incorrecto![/color]\n"
		label_feedback.text += "La respuesta correcta era: [color=#66bb66]" + letra_correcta + "[/color]\n\n"

	if retro != "":
		label_feedback.text += "[color=white]" + retro + "[/color]"
	var resultado = _crear_resultado(correcta, tiempo_empleado, index)
	pregunta_respondida.emit(resultado)
	waiting_for_continue = true
	_set_continue_hint("Haz clic o presiona Enter para continuar", true)

func _calcular_tiempo_empleado() -> float:
	var ahora = Time.get_ticks_msec() / 1000.0
	var delta = ahora - pregunta_inicio_timestamp
	if delta < 0.0:
		delta = 0.0
	return delta

func _crear_resultado(correcta: bool, tiempo_empleado: float, indice_seleccionado: int) -> Dictionary:
	var categoria = label_categoria.text
	var respuesta_correcta = pregunta_actual.get("respuesta_correcta", 0)
	var opciones: Array = pregunta_actual.get("opciones", [])
	var respuesta_correcta_texto = ""
	var seleccion_texto = "Sin respuesta"
	if respuesta_correcta >= 0 and respuesta_correcta < opciones.size():
		respuesta_correcta_texto = opciones[respuesta_correcta]
	if indice_seleccionado >= 0 and indice_seleccionado < opciones.size():
		seleccion_texto = opciones[indice_seleccionado]
	return {
		"categoria": categoria,
		"pregunta": pregunta_actual.get("texto", ""),
		"es_correcta": correcta,
		"respuesta_correcta": respuesta_correcta_texto,
		"respuesta_jugador": seleccion_texto,
		"tiempo": tiempo_empleado,
		"opcion_correcta": respuesta_correcta,
		"opcion_seleccionada": indice_seleccionado
	}

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
		for boton in botones:
			boton.disabled = true
		label_feedback.clear()
		label_feedback.bbcode_enabled = true
		label_feedback.text = "[color=#cc6666]¡Se acabó el tiempo![/color]"
		var resultado = _crear_resultado(false, _calcular_tiempo_empleado(), -1)
		pregunta_respondida.emit(resultado)
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
	if intro_tween != null and intro_tween.is_running():
		intro_tween.kill()
		_finalize_intro_visuals()
	_hide_timeout_effect()
	hide()
	panel_closed.emit()

func _set_continue_hint(texto: String, mostrar: bool) -> void:
	if continue_hint == null:
		return
	continue_hint.text = texto
	continue_hint.visible = mostrar
	var target_color = continue_hint_base_color
	continue_hint.add_theme_color_override("font_color", target_color)

func _on_continue_hint_mouse_entered() -> void:
	if continue_hint != null and continue_hint.visible:
		continue_hint.add_theme_color_override("font_color", continue_hint_hover_color)

func _on_continue_hint_mouse_exited() -> void:
	if continue_hint != null:
		continue_hint.add_theme_color_override("font_color", continue_hint_base_color)

func _prepare_intro_animation() -> void:
	if intro_tween != null and intro_tween.is_running():
		intro_tween.kill()
		_finalize_intro_visuals()
	_hide_timeout_effect()
	intro_tween = null
	if background_rect != null:
		background_rect.modulate = Color(1, 1, 1, 0)
	if info_panel != null:
		info_panel.modulate = Color(info_panel_target_modulate.r, info_panel_target_modulate.g, info_panel_target_modulate.b, 0)
	if card_panel != null:
		card_panel.modulate = Color(card_panel_target_modulate.r, card_panel_target_modulate.g, card_panel_target_modulate.b, 0)
	if label_categoria != null:
		label_categoria.modulate = Color(1, 1, 1, 0)
		label_categoria.scale = Vector2(0.75, 0.75)
	if label_pregunta != null:
		label_pregunta.modulate = Color(1, 1, 1, 0)
	if label_feedback != null:
		label_feedback.modulate = Color(1, 1, 1, 0)
	for button in botones:
		if button != null:
			button.modulate = Color(1, 1, 1, 0)

func _play_intro_animation() -> void:
	intro_tween = create_tween()
	intro_tween.set_parallel(true)
	if background_rect != null:
		var background_track = intro_tween.parallel().tween_property(background_rect, "modulate:a", 1.0, 0.45)
		background_track.from(0.0)
		background_track.set_trans(Tween.TRANS_SINE)
		background_track.set_ease(Tween.EASE_OUT)
	if info_panel != null:
		var info_track = intro_tween.parallel().tween_property(info_panel, "modulate", info_panel_target_modulate, 0.35)
		info_track.from(Color(info_panel_target_modulate.r, info_panel_target_modulate.g, info_panel_target_modulate.b, 0))
		info_track.set_trans(Tween.TRANS_SINE)
		info_track.set_ease(Tween.EASE_OUT)
	if card_panel != null:
		var card_track = intro_tween.parallel().tween_property(card_panel, "modulate", card_panel_target_modulate, 0.4)
		card_track.from(Color(card_panel_target_modulate.r, card_panel_target_modulate.g, card_panel_target_modulate.b, 0))
		card_track.set_trans(Tween.TRANS_SINE)
		card_track.set_ease(Tween.EASE_OUT)
	if label_pregunta != null:
		var pregunta_track = intro_tween.parallel().tween_property(label_pregunta, "modulate:a", 1.0, 0.3)
		pregunta_track.from(0.0)
		pregunta_track.set_delay(0.1)
		pregunta_track.set_trans(Tween.TRANS_CUBIC)
		pregunta_track.set_ease(Tween.EASE_OUT)
	if label_feedback != null:
		var feedback_track = intro_tween.parallel().tween_property(label_feedback, "modulate:a", 1.0, 0.3)
		feedback_track.from(0.0)
		feedback_track.set_delay(0.15)
		feedback_track.set_trans(Tween.TRANS_CUBIC)
		feedback_track.set_ease(Tween.EASE_OUT)
	if label_categoria != null:
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
		if button != null:
			var button_track = intro_tween.parallel().tween_property(button, "modulate:a", 1.0, 0.3)
			button_track.from(0.0)
			button_track.set_delay(0.18)
			button_track.set_trans(Tween.TRANS_SINE)
			button_track.set_ease(Tween.EASE_OUT)
	intro_tween.finished.connect(_finalize_intro_visuals)

func _finalize_intro_visuals() -> void:
	intro_tween = null
	if background_rect != null:
		background_rect.modulate = Color(1, 1, 1, 1)
	if info_panel != null:
		info_panel.modulate = info_panel_target_modulate
	if card_panel != null:
		card_panel.modulate = card_panel_target_modulate
	if label_categoria != null:
		label_categoria.modulate = Color(1, 1, 1, 1)
		label_categoria.scale = Vector2.ONE
	if label_pregunta != null:
		label_pregunta.modulate = Color(1, 1, 1, 1)
	if label_feedback != null:
		label_feedback.modulate = Color(1, 1, 1, 1)
	for button in botones:
		if button != null:
			button.modulate = Color(1, 1, 1, 1)

func actualizar_colores_de_ui(color: Color) -> void:
	background_target_color = Color(color.r, color.g, color.b, background_alpha)
	info_panel_style_color = color.lerp(Color.BLACK, 0.3)
	card_panel_style_color = color.lerp(Color.BLACK, 0.35)
	info_panel_target_modulate = Color(1, 1, 1, 1)
	card_panel_target_modulate = Color(1, 1, 1, 1)
	question_style_target_color = card_panel_style_color
	feedback_style_target_color = card_panel_style_color
	accent_color = color.lerp(Color.WHITE, 0.5)
	cronometro_base_color = accent_color.lerp(Color.WHITE, 0.25)
	cronometro_warning_color = Color.html("#cc6666").lerp(accent_color, 0.3)
	continue_hint_base_color = accent_color.lerp(Color.WHITE, 0.15)
	continue_hint_hover_color = continue_hint_base_color.lerp(Color.WHITE, 0.35)
	if background_rect != null:
		background_rect.color = background_target_color
		background_rect.modulate = Color(1, 1, 1, 1)
	if info_panel != null:
		_apply_stylebox_color(info_panel, "panel", info_panel_style_color)
		info_panel.modulate = info_panel_target_modulate
	if card_panel != null:
		_apply_stylebox_color(card_panel, "panel", card_panel_style_color)
		card_panel.modulate = card_panel_target_modulate
	if label_pregunta != null:
		_apply_stylebox_color(label_pregunta, "normal", question_style_target_color)
	if label_feedback != null:
		_apply_stylebox_color(label_feedback, "normal", feedback_style_target_color)
	if label_categoria != null:
		label_categoria.add_theme_color_override("font_color", Color.WHITE)
	if continue_hint != null:
		continue_hint.add_theme_color_override("font_color", continue_hint_base_color)
	if label_cronometro != null:
		_apply_stylebox_color(label_cronometro, "normal", info_panel_style_color)
		label_cronometro.add_theme_color_override("font_color", cronometro_base_color)
	if categoria_icon != null:
		categoria_icon.self_modulate = Color.WHITE
	for button in botones:
		if button != null:
			_apply_button_styles(button, card_panel_style_color)
			button.add_theme_color_override("font_color", accent_color.lerp(Color.WHITE, 0.5))
			button.add_theme_color_override("font_color_hover", accent_color)
			button.add_theme_color_override("font_color_pressed", accent_color.lerp(Color.BLACK, 0.25))

func _apply_stylebox_color(node: Control, style_name: String, color: Color) -> void:
	if node == null:
		return
	var base_style = node.get_theme_stylebox(style_name, node.get_class())
	var custom_style: StyleBoxFlat = null
	if base_style != null and base_style is StyleBoxFlat:
		custom_style = base_style.duplicate()
	else:
		custom_style = StyleBoxFlat.new()
	if node is RichTextLabel:
		custom_style.corner_radius_top_left = 24
		custom_style.corner_radius_top_right = 24
		custom_style.corner_radius_bottom_left = 24
		custom_style.corner_radius_bottom_right = 24
		custom_style.content_margin_left = 24
		custom_style.content_margin_right = 24
		custom_style.content_margin_top = 18
		custom_style.content_margin_bottom = 18
	elif node is Label:
		custom_style.corner_radius_top_left = 18
		custom_style.corner_radius_top_right = 18
		custom_style.corner_radius_bottom_left = 18
		custom_style.corner_radius_bottom_right = 18
		custom_style.content_margin_left = 16
		custom_style.content_margin_right = 16
		custom_style.content_margin_top = 12
		custom_style.content_margin_bottom = 12
	else:
		custom_style.corner_radius_top_left = 32
		custom_style.corner_radius_top_right = 32
		custom_style.corner_radius_bottom_left = 32
		custom_style.corner_radius_bottom_right = 32
		custom_style.content_margin_left = 0
		custom_style.content_margin_right = 0
		custom_style.content_margin_top = 0
		custom_style.content_margin_bottom = 0
	custom_style.bg_color = color
	custom_style.border_color = color
	node.add_theme_stylebox_override(style_name, custom_style)

func _apply_button_styles(button: Button, base_color: Color) -> void:
	if button == null:
		return
	var normal_color = base_color.lerp(Color.BLACK, 0.2)
	var hover_color = base_color.lerp(Color.WHITE, 0.15)
	var pressed_color = base_color.lerp(Color.BLACK, 0.35)
	var disabled_color = base_color.lerp(Color.BLACK, 0.45)
	var focus_color = base_color.lerp(Color.WHITE, 0.05)
	var state_colors = {
		"normal": normal_color,
		"hover": hover_color,
		"pressed": pressed_color,
		"disabled": disabled_color,
		"focus": focus_color
	}
	for state in state_colors.keys():
		var stylebox = button.get_theme_stylebox(state, "Button")
		var new_style: StyleBoxFlat = null
		if stylebox != null and stylebox is StyleBoxFlat:
			new_style = stylebox.duplicate()
		else:
			new_style = StyleBoxFlat.new()
			new_style.corner_radius_top_left = 18
			new_style.corner_radius_top_right = 18
			new_style.corner_radius_bottom_left = 18
			new_style.corner_radius_bottom_right = 18
			new_style.content_margin_left = 24
			new_style.content_margin_right = 24
			new_style.content_margin_top = 16
			new_style.content_margin_bottom = 16
		new_style.bg_color = state_colors[state]
		new_style.border_color = state_colors[state].lerp(Color.BLACK, 0.3)
		button.add_theme_stylebox_override(state, new_style)
	button.add_theme_color_override("font_outline_color", base_color.lerp(Color.BLACK, 0.5))

func _show_time_out_effect() -> void:
	if timeout_tween != null and timeout_tween.is_running():
		timeout_tween.kill()
	if timeout_overlay != null:
		timeout_overlay.visible = true
		timeout_overlay.modulate = Color(1, 1, 1, 0)
	if timeout_label != null:
		timeout_label.visible = true
		timeout_label.modulate = Color(1, 1, 1, 0)
		timeout_label.scale = Vector2(0.85, 0.85)
	timeout_tween = create_tween()
	timeout_tween.set_parallel(true)
	if timeout_overlay != null:
		var overlay_in = timeout_tween.parallel().tween_property(timeout_overlay, "modulate:a", 1.0, 0.25)
		overlay_in.from(0.0)
		overlay_in.set_trans(Tween.TRANS_SINE)
		overlay_in.set_ease(Tween.EASE_OUT)
	if timeout_label != null:
		var label_in = timeout_tween.parallel().tween_property(timeout_label, "modulate:a", 1.0, 0.25)
		label_in.from(0.0)
		label_in.set_trans(Tween.TRANS_CUBIC)
		label_in.set_ease(Tween.EASE_OUT)
		var label_scale = timeout_tween.parallel().tween_property(timeout_label, "scale", Vector2.ONE, 0.3)
		label_scale.from(Vector2(0.85, 0.85))
		label_scale.set_trans(Tween.TRANS_BACK)
		label_scale.set_ease(Tween.EASE_OUT)
	timeout_tween.tween_interval(0.35)
	if timeout_overlay != null:
		var overlay_out = timeout_tween.parallel().tween_property(timeout_overlay, "modulate:a", 0.0, 0.35)
		overlay_out.set_trans(Tween.TRANS_SINE)
		overlay_out.set_ease(Tween.EASE_IN)
	if timeout_label != null:
		var label_out = timeout_tween.parallel().tween_property(timeout_label, "modulate:a", 0.0, 0.3)
		label_out.set_trans(Tween.TRANS_SINE)
		label_out.set_ease(Tween.EASE_IN)
	timeout_tween.finished.connect(_hide_timeout_effect)

func _hide_timeout_effect() -> void:
	if timeout_tween != null and timeout_tween.is_running():
		timeout_tween.kill()
	timeout_tween = null
	if timeout_overlay != null:
		timeout_overlay.visible = false
		timeout_overlay.modulate = Color(1, 1, 1, 0)
	if timeout_label != null:
		timeout_label.visible = false
		timeout_label.modulate = Color(1, 1, 1, 0)
		timeout_label.scale = Vector2.ONE
