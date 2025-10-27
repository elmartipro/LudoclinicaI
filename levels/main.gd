extends Node

var CATEGORY_COLORS = {
	"Epidemiología": Color.html("#7159C4"),
	"Fisiopatología": Color.html("#C0429D"),
	"Manifestaciones clínicas y paraclínicas": Color.html("#108072"),
	"Diagnóstico diferencial": Color.html("#2A6E96"),
	"Tratamiento": Color.html("#BC3232"),
	"Seguimiento": Color.html("#446F47"),
	"Cultura": Color.html("#E7CB8B"),
	"default": Color.html("#5F9A88")
}

const PANEL_ACTIVE_ALPHA = 0.38
const PANEL_IDLE_ALPHA = 0.18
const EXAM_PERSISTENCE_PATH = "user://examenes.json"

@onready var omni_light: OmniLight3D = $OmniLight3D
@onready var color_rect: ColorRect = $ColorOverlay/ColorRect
@onready var floor_mesh: MeshInstance3D = $Floor/MeshInstance3D
@onready var spots: Node = $Spots
@onready var preguntas_panel: CanvasLayer = $PreguntasPanel
@onready var player: CharacterBody3D = $Player
@onready var score_label: Label = $Score
@onready var progress_label: Label = $Progress
@onready var exam_timer_label: Label = $ExamTimer
@onready var victory_overlay: CanvasLayer = $VictoryOverlay
@onready var victory_title_label: Label = $"VictoryOverlay/CenterContainer/Panel/VBoxContainer/TitleLabel"
@onready var percentage_value_label: Label = $"VictoryOverlay/CenterContainer/Panel/VBoxContainer/StatsGrid/PercentageValue"
@onready var total_time_value_label: Label = $"VictoryOverlay/CenterContainer/Panel/VBoxContainer/StatsGrid/TotalTimeValue"
@onready var average_time_value_label: Label = $"VictoryOverlay/CenterContainer/Panel/VBoxContainer/StatsGrid/AverageTimeValue"
@onready var best_category_value_label: Label = $"VictoryOverlay/CenterContainer/Panel/VBoxContainer/StatsGrid/BestCategoryValue"
@onready var worst_category_value_label: Label = $"VictoryOverlay/CenterContainer/Panel/VBoxContainer/StatsGrid/WorstCategoryValue"
@onready var comparativa_label: Label = $"VictoryOverlay/CenterContainer/Panel/VBoxContainer/ComparativaLabel"
@onready var history_button: Button = $"VictoryOverlay/CenterContainer/Panel/VBoxContainer/HistoryButton"
@onready var history_container: Control = $"VictoryOverlay/CenterContainer/Panel/VBoxContainer/HistoryContainer"
@onready var history_list: VBoxContainer = $"VictoryOverlay/CenterContainer/Panel/VBoxContainer/HistoryContainer/ScrollContainer/HistoryList"
@onready var restart_button: Button = $"VictoryOverlay/CenterContainer/Panel/VBoxContainer/RestartButton"

var default_light_color: Color = Color.WHITE
var default_floor_color: Color = Color.WHITE
var current_category: String = ""
var floor_material: BaseMaterial3D
var overlay_tween: Tween
var light_tween: Tween

var exam_started: bool = false
var exam_timer_running: bool = false
var exam_start_time: float = 0.0
var exam_elapsed_time: float = 0.0
var total_questions: int = 0
var questions_answered: int = 0
var history_visible: bool = false

func _ready() -> void:
	RenderingServer.force_draw(true)
	if omni_light:
		default_light_color = omni_light.light_color
	if floor_mesh:
		_floor_prepare_material()
	if spots:
		if spots.has_signal("category_reached"):
			spots.category_reached.connect(_on_category_reached)
		if spots.has_signal("cycle_completed"):
			spots.cycle_completed.connect(_on_cycle_completed)
	if preguntas_panel:
		if preguntas_panel.has_signal("panel_opened"):
			preguntas_panel.panel_opened.connect(_on_question_panel_opened)
		if preguntas_panel.has_signal("panel_closed"):
			preguntas_panel.panel_closed.connect(_on_question_panel_closed)
		if preguntas_panel.has_signal("pregunta_finalizada"):
			preguntas_panel.pregunta_finalizada.connect(_on_question_completed)
		if preguntas_panel.has_signal("examen_finalizado"):
			preguntas_panel.examen_finalizado.connect(_on_exam_finished)
	if history_button:
		history_button.pressed.connect(_on_history_button_pressed)
	if restart_button:
		restart_button.pressed.connect(_on_restart_button_pressed)
	_apply_scene_color("default", 0.0)
	if history_container:
		history_container.visible = false
	victory_overlay.visible = false
	_initialize_exam_flow()

func _process(_delta: float) -> void:
	if exam_timer_running:
		var current_time = Time.get_ticks_msec() / 1000.0
		exam_elapsed_time = current_time - exam_start_time
		if exam_elapsed_time < 0.0:
			exam_elapsed_time = 0.0
	_update_exam_timer_label()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().reload_current_scene()
	elif victory_overlay and victory_overlay.visible and event.is_action_pressed("ui_accept"):
		_restart_game()

func _initialize_exam_flow() -> void:
	exam_started = false
	exam_timer_running = false
	exam_elapsed_time = 0.0
	questions_answered = 0
	if spots and spots.has_method("get_total_spots"):
		total_questions = spots.call("get_total_spots")
	else:
		total_questions = 0
	if preguntas_panel:
		preguntas_panel.configurar_examen(total_questions)
	_update_progress_label()
	_update_exam_timer_label()
	if player:
		call_deferred("_start_exam_cycle")

func _start_exam_cycle() -> void:
	if player:
		player.advance_one_space()

func _trigger_next_move() -> void:
	if player:
		player.advance_one_space()

func _on_category_reached(category: String) -> void:
	current_category = category
	var alpha = PANEL_IDLE_ALPHA
	if preguntas_panel and preguntas_panel.visible:
		alpha = PANEL_ACTIVE_ALPHA
	_apply_scene_color(category, alpha)

func _on_question_panel_opened() -> void:
	if current_category != "":
		_apply_scene_color(current_category, PANEL_ACTIVE_ALPHA)
	if not exam_started:
		exam_started = true
		exam_timer_running = true
		exam_start_time = Time.get_ticks_msec() / 1000.0
		exam_elapsed_time = 0.0

func _on_question_panel_closed() -> void:
	if current_category != "":
		_apply_scene_color(current_category, PANEL_IDLE_ALPHA)

func _on_question_completed(resultado: Dictionary) -> void:
	questions_answered += 1
	_update_progress_label()
	var spot: Marker3D = resultado.get("spot", null)
	if spot and spots and spots.has_method("clear_podium_for_spot"):
		spots.call("clear_podium_for_spot", spot)
	if spots and spots.has_method("get_remaining_spots"):
		var remaining: int = spots.call("get_remaining_spots")
		if remaining > 0:
			call_deferred("_trigger_next_move")

func _on_exam_finished(resumen: Dictionary) -> void:
	exam_timer_running = false
	_update_exam_timer_label()
	_show_exam_summary(resumen)

func _on_cycle_completed() -> void:
	exam_timer_running = false
	_update_exam_timer_label()

func _show_exam_summary(resumen: Dictionary) -> void:
	var total: int = resumen.get("total", 0)
	var aciertos: int = resumen.get("aciertos", 0)
	var porcentaje: float = 0.0
	if total > 0:
		porcentaje = float(aciertos) / float(total) * 100.0
	var tiempo_total: float = exam_elapsed_time
	if tiempo_total <= 0.0:
		tiempo_total = resumen.get("tiempo_total_respuestas", 0.0)
	var promedio: float = 0.0
	if total > 0:
		promedio = tiempo_total / float(total)
	var categoria_stats: Dictionary = resumen.get("categoria_stats", {})
	var mejor_categoria: String = "—"
	var peor_categoria: String = "—"
	var mejor_valor: int = -1
	var peor_valor: int = -1
	for categoria in categoria_stats.keys():
		var datos: Dictionary = categoria_stats[categoria]
		var correctas: int = datos.get("correctas", 0)
		var incorrectas: int = datos.get("incorrectas", 0)
		if correctas > mejor_valor:
			mejor_valor = correctas
			mejor_categoria = categoria
		if incorrectas > peor_valor:
			peor_valor = incorrectas
			peor_categoria = categoria
	if mejor_valor <= 0:
		mejor_categoria = "—"
	if peor_valor <= 0:
		peor_categoria = "—"
	if victory_title_label:
		victory_title_label.text = "Resumen del examen"
	if percentage_value_label:
		percentage_value_label.text = "%.2f%%" % porcentaje
	if total_time_value_label:
		total_time_value_label.text = _format_time(tiempo_total)
	if average_time_value_label:
		average_time_value_label.text = _format_time(promedio)
	if best_category_value_label:
		best_category_value_label.text = mejor_categoria
	if worst_category_value_label:
		worst_category_value_label.text = peor_categoria
	_populate_history(resumen.get("historial", []))
	var persistencia = _save_exam_attempt(resumen, tiempo_total, promedio)
	if comparativa_label:
		if persistencia.size() > 0:
			var intentos: int = persistencia.get("intentos", 0)
			var mejor: float = persistencia.get("mejor_porcentaje", porcentaje)
			var promedio_porcentual: float = persistencia.get("promedio_porcentaje", porcentaje)
			comparativa_label.text = "Intentos guardados: %d
Mejor porcentaje: %.2f%%
Promedio porcentual: %.2f%%" % [intentos, mejor, promedio_porcentual]
		else:
			comparativa_label.text = "Este es tu primer intento guardado."
	history_visible = false
	if history_container:
		history_container.visible = history_visible
	if history_button:
		history_button.text = "Ver historial"
	if victory_overlay:
		victory_overlay.visible = true
	if restart_button:
		restart_button.grab_focus()

func _populate_history(historial: Array) -> void:
	if not history_list:
		return
	for child in history_list.get_children():
		child.queue_free()
	var indice: int = 1
	for entrada in historial:
		var contenedor = VBoxContainer.new()
		contenedor.add_theme_constant_override("separation", 4)
		var titulo = Label.new()
		var texto: String = entrada.get("texto", "")
		var categoria: String = entrada.get("categoria", "")
		titulo.text = "%d. %s" % [indice, texto]
		history_list.add_child(contenedor)
		contenedor.add_child(titulo)
		var categoria_label = Label.new()
		categoria_label.text = "Categoría: " + categoria
		contenedor.add_child(categoria_label)
		var respuesta_usuario_texto: String = entrada.get("respuesta_usuario_texto", "")
		if respuesta_usuario_texto == "":
			respuesta_usuario_texto = "Sin respuesta"
		var respuesta_label = Label.new()
		respuesta_label.text = "Respuesta dada: " + respuesta_usuario_texto
		contenedor.add_child(respuesta_label)
		var correcta_label = Label.new()
		correcta_label.text = "Respuesta correcta: " + entrada.get("respuesta_correcta_texto", "")
		contenedor.add_child(correcta_label)
		var tiempo_label = Label.new()
		tiempo_label.text = "Tiempo usado: " + _format_time(entrada.get("tiempo", 0.0))
		contenedor.add_child(tiempo_label)
		var estado_label = Label.new()
		var es_correcta: bool = entrada.get("correcta", false)
		if es_correcta:
			estado_label.text = "Resultado: Correcta"
		else:
			estado_label.text = "Resultado: Incorrecta"
		contenedor.add_child(estado_label)
		var separador = HSeparator.new()
		contenedor.add_child(separador)
		indice += 1

func _save_exam_attempt(resumen: Dictionary, tiempo_total: float, promedio: float) -> Dictionary:
	var intentos: Array = []
	if FileAccess.file_exists(EXAM_PERSISTENCE_PATH):
		var lectura = FileAccess.open(EXAM_PERSISTENCE_PATH, FileAccess.READ)
		if lectura:
			var parsed = JSON.parse_string(lectura.get_as_text())
			if typeof(parsed) == TYPE_ARRAY:
				intentos = parsed
	var fecha = _obtener_fecha_actual()
	var total: int = resumen.get("total", 0)
	var aciertos: int = resumen.get("aciertos", 0)
	var porcentaje: float = 0.0
	if total > 0:
		porcentaje = float(aciertos) / float(total) * 100.0
	var intento = {
		"fecha": fecha,
		"aciertos": aciertos,
		"total": total,
		"porcentaje": porcentaje,
		"tiempo_total": tiempo_total,
		"promedio_pregunta": promedio,
		"categoria_stats": resumen.get("categoria_stats", {})
	}
	intentos.append(intento)
	var archivo = FileAccess.open(EXAM_PERSISTENCE_PATH, FileAccess.WRITE)
	if archivo:
		archivo.store_string(JSON.stringify(intentos))
	var mejor: float = porcentaje
	var suma: float = 0.0
	for intento_guardado in intentos:
		var valor: float = intento_guardado.get("porcentaje", 0.0)
		suma += valor
		if valor > mejor:
			mejor = valor
	var promedio_porcentual: float = 0.0
	if intentos.size() > 0:
		promedio_porcentual = suma / float(intentos.size())
	var resumen_intentos = {
		"intentos": intentos.size(),
		"mejor_porcentaje": mejor,
		"promedio_porcentaje": promedio_porcentual
	}
	return resumen_intentos

func _obtener_fecha_actual() -> String:
	var datos = Time.get_datetime_dict_from_system()
	var year = datos.get("year", 0)
	var month = datos.get("month", 0)
	var day = datos.get("day", 0)
	var hour = datos.get("hour", 0)
	var minute = datos.get("minute", 0)
	var second = datos.get("second", 0)
	return "%04d-%02d-%02d %02d:%02d:%02d" % [year, month, day, hour, minute, second]

func _on_history_button_pressed() -> void:
	history_visible = not history_visible
	if history_container:
		history_container.visible = history_visible
	if history_button:
		if history_visible:
			history_button.text = "Ocultar historial"
		else:
			history_button.text = "Ver historial"

func _on_restart_button_pressed() -> void:
	_restart_game()

func _restart_game() -> void:
	get_tree().reload_current_scene()

func _update_progress_label() -> void:
	if progress_label:
		progress_label.text = "Pregunta: %d / %d" % [questions_answered, total_questions]

func _update_exam_timer_label() -> void:
	if exam_timer_label:
		exam_timer_label.text = "Tiempo: " + _format_time(exam_elapsed_time)

func _format_time(segundos: float) -> String:
	var tiempo_segundos = max(segundos, 0.0)
	var segundos_entero = int(floor(tiempo_segundos))
	var minutos = segundos_entero / 60
	var segundos_restantes = segundos_entero % 60
	var fraccion = tiempo_segundos - float(segundos_entero)
	var centesimas = int(round(fraccion * 100.0))
	if centesimas >= 100:
		centesimas = 0
		segundos_restantes += 1
		if segundos_restantes >= 60:
			segundos_restantes = 0
			minutos += 1
	return "%02d:%02d.%02d" % [minutos, segundos_restantes, centesimas]

func _apply_scene_color(category: String, alpha: float) -> void:
	var base_color = CATEGORY_COLORS.get(category, CATEGORY_COLORS["default"])
	var podium_color = _update_floor_color(base_color)
	var overlay_alpha = alpha
	if overlay_alpha < 0.4:
		overlay_alpha = 0.0
	_tween_overlay_color(podium_color, overlay_alpha)
	_tween_light_color(base_color)
	_update_ui_colors(podium_color)
	if preguntas_panel and preguntas_panel.has_method("actualizar_colores_de_ui"):
		preguntas_panel.actualizar_colores_de_ui(podium_color)

func _floor_prepare_material() -> void:
	var active_material: Material = floor_mesh.get_active_material(0)
	if active_material:
		floor_material = active_material.duplicate()
		floor_mesh.set_surface_override_material(0, floor_material)
		if floor_material is BaseMaterial3D:
			default_floor_color = (floor_material as BaseMaterial3D).albedo_color
	else:
		default_floor_color = Color.WHITE

func _update_floor_color(base_color: Color) -> Color:
	if not floor_material:
		return base_color
	var target_color = base_color.lerp(default_floor_color, 0.35)
	(floor_material as BaseMaterial3D).albedo_color = target_color
	return target_color

func _update_ui_colors(podium_color: Color) -> void:
	var accent = podium_color.lerp(Color.WHITE, 0.6)
	var secondary = podium_color.lerp(Color.BLACK, 0.35)
	if score_label:
		score_label.add_theme_color_override("font_color", accent)
		score_label.add_theme_color_override("font_outline_color", secondary)
	if progress_label:
		progress_label.add_theme_color_override("font_color", accent)
		progress_label.add_theme_color_override("font_outline_color", secondary)
	if exam_timer_label:
		exam_timer_label.add_theme_color_override("font_color", accent)
		exam_timer_label.add_theme_color_override("font_outline_color", secondary)

func _tween_overlay_color(base_color: Color, alpha: float) -> void:
	if not color_rect:
		return
	var target_color: Color = Color(base_color.r, base_color.g, base_color.b, alpha)
	if overlay_tween and overlay_tween.is_running():
		overlay_tween.kill()
	overlay_tween = create_tween()
	overlay_tween.tween_property(color_rect, "color", target_color, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _tween_light_color(base_color: Color) -> void:
	if not omni_light:
		return
	if light_tween and light_tween.is_running():
		light_tween.kill()
	var target: Color = base_color.lerp(default_light_color, 0.4)
	light_tween = create_tween()
	light_tween.tween_property(omni_light, "light_color", target, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
