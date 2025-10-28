extends Node

const BASE_CATEGORY_SEQUENCE: Array[String] = [
	"Epidemiología",
	"Fisiopatología",
	"Manifestaciones clínicas y paraclínicas",
	"Diagnóstico diferencial",
	"Tratamiento",
	"Seguimiento",
	"Cultura"
]

const PANEL_ACTIVE_ALPHA: float = 0.38
const PANEL_IDLE_ALPHA: float = 0.18

@onready var omni_light: OmniLight3D = $OmniLight3D
@onready var color_rect: ColorRect = $ColorOverlay/ColorRect
@onready var floor_mesh: MeshInstance3D = $Floor/MeshInstance3D
@onready var spots: Node = $Spots
@onready var preguntas_panel: Node = $PreguntasPanel
@onready var score_label: Label = $Score
@onready var time_label: Label = $Health
@onready var exam_overlay: CanvasLayer = $ExamResultsOverlay
@onready var player: CharacterBody3D = $Player
@onready var exit_confirm_dialog: ConfirmationDialog = $ExitConfirmDialog
@onready var config_overlay: CanvasLayer = $ConfigMenuOverlay

var category_sequence: Array[String] = []
var floor_material: BaseMaterial3D
var default_light_color: Color = Color.WHITE
var default_floor_color: Color = Color.WHITE
var overlay_tween: Tween
var light_tween: Tween

var total_spots: int = 0
var total_questions: int = 0
var current_index: int = 0
var current_spot_index: int = 0
var current_category: String = ""
var correct_answers: int = 0
var answered_questions: int = 0
var movement_in_progress: bool = false
var exam_started: bool = false
var exam_finished: bool = false
var exam_start_time: float = 0.0
var exam_end_time: float = 0.0
var category_stats: Dictionary = {}
var question_history: Array = []
var previous_attempts: Array = []
var finish_spot_index: int = -1
var steps_per_exam: int = 0

func _ready() -> void:
	if omni_light:
		default_light_color = omni_light.light_color
	if floor_mesh:
		_floor_prepare_material()
	if spots:
		total_spots = spots.get_child_count()
		finish_spot_index = _find_finish_spot_index()
		steps_per_exam = _compute_exam_length()
		category_sequence = _build_exam_sequence(steps_per_exam)
		if spots.has_method("populate_podiums"):
			spots.populate_podiums(category_sequence)
		if spots.has_signal("category_reached"):
			spots.category_reached.connect(_on_category_reached)
	if category_sequence.is_empty():
		category_sequence = BASE_CATEGORY_SEQUENCE.duplicate()
	total_questions = category_sequence.size()
	for categoria in BASE_CATEGORY_SEQUENCE:
		category_stats[categoria] = {"total": 0, "correctas": 0}
	_update_score_label()
	_update_time_label(0.0)
	if preguntas_panel:
		preguntas_panel.configurar_total_preguntas(total_questions)
		preguntas_panel.panel_opened.connect(_on_question_panel_opened)
		preguntas_panel.panel_closed.connect(_on_question_panel_closed)
		preguntas_panel.examen_pregunta_finalizada.connect(_on_exam_question_finished)
	if player:
		player.pawn_finished_moving.connect(_on_pawn_finished_moving)
		player.reset_path(0)
	if exam_overlay and exam_overlay.has_signal("overlay_cerrado"):
		exam_overlay.overlay_cerrado.connect(_on_overlay_closed)
	if exit_confirm_dialog:
		exit_confirm_dialog.dialog_text = "¿Está seguro que quiere ir al menu principal?\nSu progreso no se guardará"
		var ok_button: Button = exit_confirm_dialog.get_ok_button()
		if ok_button:
			ok_button.text = "Sí"
		var cancel_button_ready: Button = exit_confirm_dialog.get_cancel_button()
		if cancel_button_ready:
			cancel_button_ready.text = "No"
		exit_confirm_dialog.confirmed.connect(_on_exit_confirmed)
	if config_overlay:
		if config_overlay.has_signal("menu_requested"):
			config_overlay.menu_requested.connect(_on_config_menu_requested)
	_apply_scene_color("default", 0.0)
	set_process(true)
	set_process_input(true)
	_advance_to_next_question()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if config_overlay and config_overlay.has_method("is_menu_open") and config_overlay.is_menu_open():
			config_overlay.close_menu()
			return
		_show_exit_dialog()

func _process(_delta: float) -> void:
	if exam_started and not exam_finished:
		_update_time_label()

func _advance_to_next_question() -> void:
	if exam_finished:
		return
	if movement_in_progress:
		return
	if current_index >= total_questions:
		_finalize_exam()
		return
	if total_spots == 0 or category_sequence.is_empty():
		return
	current_spot_index = current_index % total_spots
	current_category = category_sequence[current_index]
	movement_in_progress = true
	if player:
		player.advance_to_next_spot(1)
	current_index += 1

func _on_pawn_finished_moving(spot: Node, index: int) -> void:
	movement_in_progress = false
	var resolved_category: String = current_category
	if spots and spots.has_method("handle_landing"):
		var category = spots.handle_landing(index, spot)
		if category != "":
			resolved_category = category
	current_category = resolved_category
	_apply_scene_color(current_category, PANEL_IDLE_ALPHA)
	if not exam_started:
		exam_started = true
		exam_start_time = Time.get_ticks_msec() / 1000.0
	_update_time_label()
	if preguntas_panel:
		preguntas_panel.mostrar_pregunta_de_categoria(current_category)

func _on_category_reached(category: String) -> void:
	_apply_scene_color(category, PANEL_IDLE_ALPHA)

func _on_question_panel_opened() -> void:
	if current_category != "":
		_apply_scene_color(current_category, PANEL_ACTIVE_ALPHA)

func _on_question_panel_closed() -> void:
	if current_category != "":
		_apply_scene_color(current_category, PANEL_IDLE_ALPHA)
	if not exam_finished:
		_advance_to_next_question()

func _on_exam_question_finished(datos: Dictionary) -> void:
	question_history.append(datos.duplicate(true))
	var categoria: String = datos.get("categoria", current_category)
	var correcta: bool = datos.get("correcta", false)
	var stats: Dictionary = category_stats.get(categoria, {"total": 0, "correctas": 0})
	stats["total"] = stats.get("total", 0) + 1
	if correcta:
		stats["correctas"] = stats.get("correctas", 0) + 1
		correct_answers += 1
	category_stats[categoria] = stats
	answered_questions += 1
	_update_score_label()
	if spots and spots.has_method("remove_podium_from_spot"):
		spots.remove_podium_from_spot(current_spot_index)

func _finalize_exam() -> void:
	if exam_finished:
		return
	exam_finished = true
	if config_overlay and config_overlay.has_method("close_menu"):
		config_overlay.close_menu()
	exam_end_time = Time.get_ticks_msec() / 1000.0
	var total_time: float = 0.0
	if exam_started:
		total_time = max(exam_end_time - exam_start_time, 0.0)
	_update_time_label(total_time)
	var answered_total: int = max(answered_questions, 1)
	var promedio: float = total_time / float(answered_total)
	var porcentaje: float = 0.0
	if total_questions > 0:
		porcentaje = float(correct_answers) / float(total_questions) * 100.0
	var resumen: Dictionary = {
		"aciertos": correct_answers,
		"total": total_questions,
		"porcentaje": porcentaje,
		"tiempo_total": total_time,
		"promedio": promedio,
		"categorias": category_stats.duplicate(true)
	}
	previous_attempts = _persist_attempt(resumen)
	if exam_overlay and exam_overlay.has_method("mostrar_resumen"):
		exam_overlay.mostrar_resumen(resumen, question_history, previous_attempts)
		exam_overlay.visible = true

func _persist_attempt(resumen: Dictionary) -> Array:
	var attempts: Array = []
	var path: String = "user://exam_results.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			if typeof(parsed) == TYPE_ARRAY:
				attempts = parsed
	var dt = Time.get_datetime_dict_from_system()
	var fecha: String = "%04d-%02d-%02d %02d:%02d:%02d" % [dt["year"], dt["month"], dt["day"], dt["hour"], dt["minute"], dt["second"]]
	var attempt: Dictionary = {
		"fecha": fecha,
		"aciertos": resumen.get("aciertos", 0),
		"total": resumen.get("total", 0),
		"tiempo_total": resumen.get("tiempo_total", 0.0),
		"promedio": resumen.get("promedio", 0.0),
		"categorias": resumen.get("categorias", {}),
		"historial": question_history.duplicate(true)
	}
	var previous = attempts.duplicate(true)
	attempts.append(attempt)
	var save_file = FileAccess.open(path, FileAccess.WRITE)
	if save_file:
		save_file.store_string(JSON.stringify(attempts, "						"))
	return previous

func _on_overlay_closed() -> void:
	_return_to_main_menu()

func _apply_scene_color(category: String, alpha: float) -> void:
	var base_color = _resolve_category_color(category)
	var podium_color = _update_floor_color(base_color)
	_tween_overlay_color(podium_color, alpha)
	_tween_light_color(base_color)
	_update_ui_colors(podium_color)
	if preguntas_panel and preguntas_panel.has_method("actualizar_colores_de_ui"):
		preguntas_panel.actualizar_colores_de_ui(podium_color)

func _resolve_category_color(category: String) -> Color:
	var palette: Dictionary = {
		"Epidemiología": Color.html("#7159C4"),
		"Fisiopatología": Color.html("#C0429D"),
		"Manifestaciones clínicas y paraclínicas": Color.html("#108072"),
		"Diagnóstico diferencial": Color.html("#2A6E96"),
		"Tratamiento": Color.html("#BC3232"),
		"Seguimiento": Color.html("#446F47"),
		"Cultura": Color.html("#E7CB8B"),
		"default": Color.html("#5F9A88")
	}
	return palette.get(category, palette["default"])

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
	if time_label:
		time_label.add_theme_color_override("font_color", accent)
		time_label.add_theme_color_override("font_outline_color", secondary)

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

func _update_score_label() -> void:
	if score_label:
		score_label.text = "Aciertos: %d / %d" % [correct_answers, total_questions]

func _update_time_label(force_seconds: float = -1.0) -> void:
	var elapsed: float = 0.0
	if force_seconds >= 0.0:
		elapsed = force_seconds
	elif exam_started:
		elapsed = max(Time.get_ticks_msec() / 1000.0 - exam_start_time, 0.0)
	if time_label:
		time_label.text = "Tiempo total: %s" % _format_time(elapsed)

func _format_time(segundos: float) -> String:
	var total_segundos: float = max(segundos, 0.0)
	var minutos: int = int(total_segundos) / 60
	var resto_segundos: float = total_segundos - float(minutos * 60)
	return "%02d:%05.2f" % [minutos, resto_segundos]

func _build_exam_sequence(length: int) -> Array[String]:
	var sequence: Array[String] = []
	if length <= 0:
		return sequence
	var base_count: int = BASE_CATEGORY_SEQUENCE.size()
	if base_count == 0:
		return sequence
	for i in range(length):
		var categoria: String = BASE_CATEGORY_SEQUENCE[i % base_count]
		sequence.append(categoria)
	return sequence

func _find_finish_spot_index() -> int:
	if not spots:
		return -1
	var children: Array = spots.get_children()
	for i in range(children.size()):
		if str(children[i].name) == "Spot19":
			return i
	if children.is_empty():
		return -1
	return children.size() - 1

func _compute_exam_length() -> int:
	if total_spots <= 0:
		return BASE_CATEGORY_SEQUENCE.size()
	if finish_spot_index >= 0:
		return clamp(finish_spot_index + 1, 1, total_spots)
	return total_spots

func _on_config_menu_requested() -> void:
	_show_exit_dialog()

func _show_exit_dialog() -> void:
	if exit_confirm_dialog == null:
		return
	if exit_confirm_dialog.visible:
		return
	exit_confirm_dialog.popup_centered()
	exit_confirm_dialog.grab_focus()
	var cancel_button: Button = exit_confirm_dialog.get_cancel_button()
	if cancel_button:
		cancel_button.grab_focus()

func _return_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://UI & Audio/Pantalla de Inicio/pantalla_de_incio.tscn")

func _on_exit_confirmed() -> void:
	_return_to_main_menu()
