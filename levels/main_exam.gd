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

@onready var omni_light: OmniLight3D = $OmniLight3D
@onready var color_rect: ColorRect = $ColorOverlay/ColorRect
@onready var floor_mesh: MeshInstance3D = $Floor/MeshInstance3D
@onready var spots: Node = $Spots
@onready var preguntas_panel: CanvasLayer = $PreguntasPanel
@onready var player: CharacterBody3D = $Player
@onready var score_label: Label = $HUD/Score
@onready var progress_label: Label = $HUD/Progress
@onready var timer_label: Label = $HUD/Timer
@onready var overlay: CanvasLayer = $ExamOverlay
@onready var overlay_title: Label = $"ExamOverlay/CenterContainer/Panel/VBoxContainer/TitleLabel"
@onready var overlay_summary: Label = $"ExamOverlay/CenterContainer/Panel/VBoxContainer/SummaryLabel"
@onready var overlay_time: Label = $"ExamOverlay/CenterContainer/Panel/VBoxContainer/TimeLabel"
@onready var overlay_average: Label = $"ExamOverlay/CenterContainer/Panel/VBoxContainer/AverageLabel"
@onready var overlay_best: Label = $"ExamOverlay/CenterContainer/Panel/VBoxContainer/BestCategoryLabel"
@onready var overlay_worst: Label = $"ExamOverlay/CenterContainer/Panel/VBoxContainer/WorstCategoryLabel"
@onready var overlay_attempts: Label = $"ExamOverlay/CenterContainer/Panel/VBoxContainer/AttemptsLabel"
@onready var overlay_history_button: Button = $"ExamOverlay/CenterContainer/Panel/VBoxContainer/ButtonRow/HistoryButton"
@onready var overlay_restart_button: Button = $"ExamOverlay/CenterContainer/Panel/VBoxContainer/ButtonRow/RestartButton"
@onready var overlay_history_panel: Panel = $"ExamOverlay/HistoryPanel"
@onready var overlay_history_text: RichTextLabel = $"ExamOverlay/HistoryPanel/ScrollContainer/HistoryText"
@onready var overlay_history_close: Button = $"ExamOverlay/HistoryPanel/CloseButton"

var default_light_color: Color = Color.WHITE
var default_floor_color: Color = Color.WHITE
var floor_material: BaseMaterial3D = null
var overlay_tween: Tween = null
var light_tween: Tween = null
var current_category: String = ""
var total_questions: int = 0
var questions_answered: int = 0
var correct_answers: int = 0
var exam_started: bool = false
var exam_finished: bool = false
var exam_start_time: float = 0.0
var exam_end_time: float = 0.0
var per_category_stats: Dictionary = {}
var history: Array = []
var pending_move: bool = false

func _ready() -> void:
	RenderingServer.force_draw(true)
	if omni_light != null:
		default_light_color = omni_light.light_color
	if floor_mesh != null:
		_floor_prepare_material()
	if spots != null:
		if spots.has_signal("category_reached"):
			spots.category_reached.connect(_on_category_reached)
		if spots.has_method("get_cycle_length"):
			total_questions = spots.get_cycle_length()
		else:
			total_questions = 0
	else:
		total_questions = 0
	if preguntas_panel != null:
		preguntas_panel.panel_opened.connect(_on_panel_opened)
		preguntas_panel.panel_closed.connect(_on_panel_closed)
		if preguntas_panel.has_signal("pregunta_respondida"):
			preguntas_panel.pregunta_respondida.connect(_on_question_answered)
	if overlay_history_button != null:
		overlay_history_button.pressed.connect(_on_history_button_pressed)
	if overlay_restart_button != null:
		overlay_restart_button.pressed.connect(_on_restart_button_pressed)
	if overlay_history_close != null:
		overlay_history_close.pressed.connect(_on_close_history_pressed)
	_update_score_label()
	_update_progress_label()
	_update_timer_label(0.0)
	_apply_scene_color("default", 0.0)
	if overlay != null:
		overlay.visible = false
	if overlay_history_panel != null:
		overlay_history_panel.visible = false
	call_deferred("_start_exam")

func _process(_delta: float) -> void:
	if exam_started and not exam_finished:
		var elapsed = Time.get_ticks_msec() / 1000.0 - exam_start_time
		_update_timer_label(elapsed)

func _start_exam() -> void:
	if player != null:
		player.advance_steps(1)

func _on_category_reached(category: String) -> void:
	current_category = category
	var alpha = PANEL_IDLE_ALPHA
	if preguntas_panel != null and preguntas_panel.visible:
		alpha = PANEL_ACTIVE_ALPHA
	_apply_scene_color(category, alpha)

func _on_panel_opened() -> void:
	if not exam_started:
		exam_started = true
		exam_start_time = Time.get_ticks_msec() / 1000.0
	if current_category != "":
		_apply_scene_color(current_category, PANEL_ACTIVE_ALPHA)

func _on_question_answered(resultado: Dictionary) -> void:
	questions_answered += 1
	if resultado.get("es_correcta", false):
		correct_answers += 1
	var categoria = resultado.get("categoria", current_category)
	if not per_category_stats.has(categoria):
		per_category_stats[categoria] = {
			"correctas": 0,
			"incorrectas": 0,
			"tiempo": 0.0,
			"total": 0
		}
	var stats: Dictionary = per_category_stats[categoria]
	stats["total"] = stats.get("total", 0) + 1
	stats["tiempo"] = stats.get("tiempo", 0.0) + float(resultado.get("tiempo", 0.0))
	if resultado.get("es_correcta", false):
		stats["correctas"] = stats.get("correctas", 0) + 1
	else:
		stats["incorrectas"] = stats.get("incorrectas", 0) + 1
	per_category_stats[categoria] = stats
	history.append(resultado.duplicate(true))
	_update_score_label()
	_update_progress_label()
	if spots != null and spots.has_method("discard_current_podium"):
		spots.discard_current_podium()
	pending_move = true

func _on_panel_closed() -> void:
	if not pending_move:
		return
	pending_move = false
	if questions_answered >= total_questions and total_questions > 0:
		_finish_exam()
	else:
		if player != null:
			player.advance_steps(1)

func _finish_exam() -> void:
	exam_finished = true
	exam_end_time = Time.get_ticks_msec() / 1000.0
	_update_timer_label(exam_end_time - exam_start_time)
	_show_exam_overlay()

func _show_exam_overlay() -> void:
	if overlay == null:
		return
	overlay.visible = true
	var porcentaje = 0.0
	if total_questions > 0:
		porcentaje = float(correct_answers) / float(total_questions) * 100.0
	var total_time = max(exam_end_time - exam_start_time, 0.0)
	var promedio = 0.0
	if questions_answered > 0:
		promedio = total_time / float(questions_answered)
	overlay_title.text = "Modo examen completado"
	overlay_summary.text = "Aciertos: %d de %d (%.2f%%)" % [correct_answers, total_questions, porcentaje]
	overlay_time.text = "Tiempo total: %s" % _format_time(total_time)
	overlay_average.text = "Promedio por pregunta: %s" % _format_time(promedio)
	var mejores = _analizar_categorias()
	overlay_best.text = "Mayor acierto: %s" % mejores.get("best", "-")
	overlay_worst.text = "Mayor dificultad: %s" % mejores.get("worst", "-")
	var attempts_summary = _build_attempt_summary(porcentaje, total_time, promedio)
	overlay_attempts.text = attempts_summary
	_update_history_text()

func _analizar_categorias() -> Dictionary:
	if per_category_stats.size() == 0:
		return {"best": "-", "worst": "-"}
	var best_label = "-"
	var worst_label = "-"
	var best_value = -1.0
	var worst_value = 2.0
	for categoria in per_category_stats.keys():
		var stats: Dictionary = per_category_stats[categoria]
		var total = max(stats.get("total", 0), 1)
		var correctas = stats.get("correctas", 0)
		var ratio = float(correctas) / float(total)
		var etiqueta = "%s (%.0f%%)" % [categoria, ratio * 100.0]
		if ratio > best_value:
			best_value = ratio
			best_label = etiqueta
		if ratio < worst_value:
			worst_value = ratio
			worst_label = etiqueta
	return {"best": best_label, "worst": worst_label}

func _build_attempt_summary(porcentaje: float, total_time: float, promedio: float) -> String:
	var data = {
		"fecha": Time.get_datetime_string_from_system(true),
		"aciertos": correct_answers,
		"total": total_questions,
		"porcentaje": porcentaje,
		"tiempo_total": total_time,
		"tiempo_promedio": promedio,
		"categorias": per_category_stats.duplicate(true),
		"historial": history.duplicate(true)
	}
	if GameModeManager != null:
		GameModeManager.record_exam_attempt(data)
		var attempts = GameModeManager.get_attempts()
		if attempts.size() > 1:
			var prev = attempts[attempts.size() - 2]
			return "Último intento: %.2f%% en %s\nIntento anterior: %.2f%% en %s" % [porcentaje, _format_time(total_time), prev.get("porcentaje", 0.0), _format_time(float(prev.get("tiempo_total", 0.0)))]
		return "Último intento registrado."
	return "Resumen no disponible."

func _update_history_text() -> void:
	if overlay_history_text == null:
		return
	overlay_history_text.clear()
	overlay_history_text.bbcode_enabled = true
	if history.size() == 0:
		overlay_history_text.text = "Sin preguntas registradas."
		return
	var index = 1
	for item in history:
		var correcta = item.get("es_correcta", false)
		var color = "#66bb66" if correcta else "#cc6666"
		var tiempo = _format_time(float(item.get("tiempo", 0.0)))
		var texto = "[b]%d.[/b] [color=%s]%s[/color]\n[b]Categoría:[/b] %s\n[b]Respuesta jugador:[/b] %s\n[b]Respuesta correcta:[/b] %s\n[b]Tiempo:[/b] %s\n\n" % [index, color, item.get("pregunta", ""), item.get("categoria", ""), item.get("respuesta_jugador", "Sin respuesta"), item.get("respuesta_correcta", ""), tiempo]
		overlay_history_text.append_text(texto)
		index += 1

func _on_history_button_pressed() -> void:
	if overlay_history_panel != null:
		overlay_history_panel.visible = true

func _on_close_history_pressed() -> void:
	if overlay_history_panel != null:
		overlay_history_panel.visible = false

func _on_restart_button_pressed() -> void:
	get_tree().reload_current_scene()

func _update_score_label() -> void:
	if score_label != null:
		score_label.text = "Aciertos: %d / %d" % [correct_answers, max(total_questions, 1)]

func _update_progress_label() -> void:
	if progress_label != null:
		progress_label.text = "Preguntas: %d / %d" % [questions_answered, max(total_questions, 1)]

func _update_timer_label(elapsed: float) -> void:
	if timer_label != null:
		timer_label.text = "Tiempo: %s" % _format_time(elapsed)

func _format_time(seconds: float) -> String:
	var secs = int(round(seconds))
	var minutes = secs / 60
	var rem = secs % 60
	return "%02d:%02d" % [minutes, rem]

func _apply_scene_color(category: String, alpha: float) -> void:
	var base_color = CATEGORY_COLORS.get(category, CATEGORY_COLORS["default"])
	var podium_color = _update_floor_color(base_color)
	_tween_overlay_color(podium_color, alpha)
	_tween_light_color(base_color)
	if preguntas_panel != null and preguntas_panel.has_method("actualizar_colores_de_ui"):
		preguntas_panel.actualizar_colores_de_ui(podium_color)

func _floor_prepare_material() -> void:
	var active_material: Material = floor_mesh.get_active_material(0)
	if active_material != null:
		floor_material = active_material.duplicate()
		floor_mesh.set_surface_override_material(0, floor_material)
		if floor_material is BaseMaterial3D:
			default_floor_color = (floor_material as BaseMaterial3D).albedo_color
	else:
		default_floor_color = Color.WHITE

func _update_floor_color(base_color: Color) -> Color:
	if floor_material == null:
		return base_color
	var target_color = base_color.lerp(default_floor_color, 0.35)
	(floor_material as BaseMaterial3D).albedo_color = target_color
	return target_color

func _tween_overlay_color(base_color: Color, alpha: float) -> void:
	if color_rect == null:
		return
	var target_color: Color = Color(base_color.r, base_color.g, base_color.b, alpha)
	if overlay_tween != null and overlay_tween.is_running():
		overlay_tween.kill()
	overlay_tween = create_tween()
	overlay_tween.tween_property(color_rect, "color", target_color, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _tween_light_color(base_color: Color) -> void:
	if omni_light == null:
		return
	if light_tween != null and light_tween.is_running():
		light_tween.kill()
	var target: Color = base_color.lerp(default_light_color, 0.4)
	light_tween = create_tween()
	light_tween.tween_property(omni_light, "light_color", target, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
