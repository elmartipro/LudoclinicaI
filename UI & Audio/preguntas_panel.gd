extends CanvasLayer

signal respondida(correcta: bool)
signal panel_closed
signal panel_opened
signal victoria_alcanzada(total_puntos: int)
signal derrota_alcanzada

const WIN_THRESHOLD = 15
const HEART_ICON_PATH = "res://Assets/life.png"
const HEART_ICON_SIZE = 48
const HEALTH_FONT_SIZE = 40

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
@onready var health_label: RichTextLabel = $"../Health"
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
	"Cultura": preload("res://Assets/Icons/cultura.svg"),
	"Health": preload("res://Assets/Icons/health.svg")
}

func _ready() -> void:
	hide()
	if background_rect:
		background_alpha = background_rect.color.a
	actualizar_colores_de_ui(Color.html("#1e272e"))
	_cargar_preguntas()
	_update_score_label()
	if health_label:
		health_label.bbcode_enabled = true
		health_label.scroll_active = false
		health_label.fit_content = true
	_update_health_label()
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
	label_categoria.text = cat
	label_pregunta.text = p["texto"]
	_hide_timeout_effect()
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
		categoria_icon.self_modulate = Color.WHITE
	else:
		categoria_icon.texture = null
	_prepare_intro_animation()
	show()
	panel_opened.emit()
	_play_intro_animation()

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
		SFX.play_correct_answer()
		if puntos >= WIN_THRESHOLD:
			label_feedback.text += "[color=#f1c40f]¡Has alcanzado la meta de %d puntos![/color]" % WIN_THRESHOLD
			respondida.emit(true)
			_trigger_victory()
			return
	else:
		label_feedback.text = "[color=#cc6666]¡Incorrecto![/color]\n"
		var letra_correcta = char(65 + pregunta_actual["respuesta_correcta"])
		label_feedback.text += "La respuesta correcta era: [color=#66bb66]" + letra_correcta + "[/color]\n\n"
		SFX.play_wrong_answer()
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
		SFX.play_wrong_answer()
		var letra_correcta = char(65 + pregunta_actual["respuesta_correcta"])
		label_feedback.clear()
		label_feedback.bbcode_enabled = true
		label_feedback.text = "[color=#cc6666]¡Se acabó el tiempo![/color]
"
		label_feedback.text += "La respuesta correcta era: [color=#66bb66]" + letra_correcta + "[/color]"
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
	if not health_label:
		return
	var heart_tag := "[img=%d]%s[/img]" % [HEART_ICON_SIZE, HEART_ICON_PATH]
	var heart_count = max(vidas, 0)
	var content := ""
	for i in range(heart_count):
		if i > 0:
			content += " "
		content += heart_tag
	if content.is_empty():
		content = "—"
	health_label.bbcode_text = "[center][font_size=%d]Vidas: %s[/font_size][/center]" % [HEALTH_FONT_SIZE, content]

func _perder_vida() -> void:
	vidas -= 1
	_update_health_label()
	if vidas <= 0:
		_game_over()

func _game_over() -> void:
	timer.stop()
	for b in botones:
		b.disabled = true
	if intro_tween and intro_tween.is_running():
		intro_tween.kill()
		_finalize_intro_visuals()
	_hide_timeout_effect()
	waiting_for_continue = false
	SFX.play_failure()
	hide()
	panel_closed.emit()
	derrota_alcanzada.emit()

func _set_continue_hint(text: String, show: bool) -> void:
	if continue_hint:
		continue_hint.text = text
		continue_hint.visible = show
		var target_color = continue_hint_base_color
		continue_hint.add_theme_color_override("font_color", target_color)

func _trigger_victory() -> void:
	timer.stop()
	for b in botones:
		b.disabled = true
	if intro_tween and intro_tween.is_running():
		intro_tween.kill()
		_finalize_intro_visuals()
	_hide_timeout_effect()
	waiting_for_continue = false
	_set_continue_hint("", false)
	SFX.play_success()
	hide()
	panel_closed.emit()
	victoria_alcanzada.emit(puntos)

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
		else:
			fallback_style.corner_radius_top_left = 32
			fallback_style.corner_radius_top_right = 32
			fallback_style.corner_radius_bottom_left = 32
			fallback_style.corner_radius_bottom_right = 32
			fallback_style.content_margin_left = 0
			fallback_style.content_margin_right = 0
			fallback_style.content_margin_top = 0
			fallback_style.content_margin_bottom = 0
		node.add_theme_stylebox_override(style_name, fallback_style)

func _apply_button_styles(button: Button, base_color: Color) -> void:
	if not button:
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
		var stylebox: StyleBox = button.get_theme_stylebox(state, "Button")
		var new_style: StyleBoxFlat = null
		if stylebox and stylebox is StyleBoxFlat:
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
	if background_rect:
		background_rect.color = background_target_color
		background_rect.modulate = Color(1, 1, 1, 1)
	if info_panel:
		_apply_stylebox_color(info_panel, "panel", info_panel_style_color)
		info_panel.modulate = info_panel_target_modulate
	if card_panel:
		_apply_stylebox_color(card_panel, "panel", card_panel_style_color)
		card_panel.modulate = card_panel_target_modulate
	if label_pregunta:
		_apply_stylebox_color(label_pregunta, "normal", question_style_target_color)
	if label_feedback:
		_apply_stylebox_color(label_feedback, "normal", feedback_style_target_color)
	if label_categoria:
		label_categoria.add_theme_color_override("font_color", Color.WHITE)
	if continue_hint:
		continue_hint.add_theme_color_override("font_color", continue_hint_base_color)
	if label_cronometro:
		_apply_stylebox_color(label_cronometro, "normal", info_panel_style_color)
		label_cronometro.add_theme_color_override("font_color", cronometro_base_color)
	if categoria_icon:
		categoria_icon.self_modulate = Color.WHITE
	for button in botones:
		if button:
			_apply_button_styles(button, card_panel_style_color)
			button.add_theme_color_override("font_color", accent_color.lerp(Color.WHITE, 0.5))
			button.add_theme_color_override("font_color_hover", accent_color)
			button.add_theme_color_override("font_color_pressed", accent_color.lerp(Color.BLACK, 0.25))

func _on_continue_hint_mouse_entered() -> void:
	if continue_hint and continue_hint.visible:
		continue_hint.add_theme_color_override("font_color", continue_hint_hover_color)

func _on_continue_hint_mouse_exited() -> void:
	if continue_hint:
		continue_hint.add_theme_color_override("font_color", continue_hint_base_color)

func _show_time_out_effect() -> void:
	if timeout_tween and timeout_tween.is_running():
		timeout_tween.kill()
	if timeout_overlay:
		timeout_overlay.visible = true
		timeout_overlay.modulate = Color(1, 1, 1, 0)
	if timeout_label:
		timeout_label.visible = true
		timeout_label.modulate = Color(1, 1, 1, 0)
		timeout_label.scale = Vector2(0.85, 0.85)
	timeout_tween = create_tween()
	timeout_tween.set_parallel(true)
	if timeout_overlay:
		var overlay_in = timeout_tween.parallel().tween_property(timeout_overlay, "modulate:a", 1.0, 0.25)
		overlay_in.from(0.0)
		overlay_in.set_trans(Tween.TRANS_SINE)
		overlay_in.set_ease(Tween.EASE_OUT)
	if timeout_label:
		var label_in = timeout_tween.parallel().tween_property(timeout_label, "modulate:a", 1.0, 0.25)
		label_in.from(0.0)
		label_in.set_trans(Tween.TRANS_CUBIC)
		label_in.set_ease(Tween.EASE_OUT)
		var label_scale = timeout_tween.parallel().tween_property(timeout_label, "scale", Vector2.ONE, 0.3)
		label_scale.from(Vector2(0.85, 0.85))
		label_scale.set_trans(Tween.TRANS_BACK)
		label_scale.set_ease(Tween.EASE_OUT)
	timeout_tween.tween_interval(0.35)
	if timeout_overlay:
		var overlay_out = timeout_tween.parallel().tween_property(timeout_overlay, "modulate:a", 0.0, 0.35)
		overlay_out.set_trans(Tween.TRANS_SINE)
		overlay_out.set_ease(Tween.EASE_IN)
	if timeout_label:
		var label_out = timeout_tween.parallel().tween_property(timeout_label, "modulate:a", 0.0, 0.3)
		label_out.set_trans(Tween.TRANS_SINE)
		label_out.set_ease(Tween.EASE_IN)
	timeout_tween.finished.connect(_hide_timeout_effect)

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
