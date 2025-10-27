extends Node

var CATEGORY_COLORS = {
	"Epidemiología": Color.html("#3498db"),
	"Fisiopatología": Color.html("#9b59b6"),
	"Manifestaciones clínicas y paraclínicas": Color.html("#e67e22"),
	"Diagnóstico diferencial": Color.html("#1abc9c"),
	"Tratamiento": Color.html("#e74c3c"),
	"Seguimiento": Color.html("#f1c40f"),
	"Cultura": Color.html("#2ecc71"),
	"Health": Color.html("#27ae60"),
	"default": Color.html("#1e272e")
}

const PANEL_ACTIVE_ALPHA = 0.38
const PANEL_IDLE_ALPHA = 0.18
const HEALTH_FLASH_ALPHA = 0.3

@onready var omni_light: OmniLight3D = $OmniLight3D
@onready var color_rect: ColorRect = $ColorOverlay/ColorRect
@onready var floor_mesh: MeshInstance3D = $Floor/MeshInstance3D
@onready var spots: Node = $Spots
@onready var preguntas_panel: Node = $PreguntasPanel
@onready var extra_life_label: Label = $HUDMessages/ExtraLifeLabel
@onready var score_label: Label = $Score
@onready var health_label: Label = $Health
@onready var dice: Node = $Dice
@onready var victory_overlay: CanvasLayer = $VictoryOverlay
@onready var victory_title_label: Label = $"VictoryOverlay/CenterContainer/Panel/VBoxContainer/TitleLabel"
@onready var victory_message_label: Label = $"VictoryOverlay/CenterContainer/Panel/VBoxContainer/MessageLabel"
@onready var restart_button: Button = $"VictoryOverlay/CenterContainer/Panel/VBoxContainer/RestartButton"

var default_light_color: Color = Color.WHITE
var default_floor_color: Color = Color.WHITE
var current_category: String = ""
var floor_material: BaseMaterial3D
var overlay_tween: Tween
var light_tween: Tween
var extra_life_tween: Tween

func _ready() -> void:
	RenderingServer.force_draw(true)

	if omni_light:
		default_light_color = omni_light.light_color

	if floor_mesh:
		_floor_prepare_material()

	if spots:
		if spots.has_signal("category_reached"):
			spots.category_reached.connect(_on_category_reached)
		if spots.has_signal("extra_life_awarded"):
			spots.extra_life_awarded.connect(_on_extra_life_awarded)

	if preguntas_panel:
		if preguntas_panel.has_signal("panel_opened"):
			preguntas_panel.panel_opened.connect(_on_question_panel_opened)
		if preguntas_panel.has_signal("panel_closed"):
			preguntas_panel.panel_closed.connect(_on_question_panel_closed)
		if preguntas_panel.has_signal("victoria_alcanzada"):
			preguntas_panel.victoria_alcanzada.connect(_on_victory_reached)
		if preguntas_panel.has_signal("derrota_alcanzada"):
			preguntas_panel.derrota_alcanzada.connect(_on_defeat_reached)

	if restart_button:
		restart_button.pressed.connect(_on_restart_button_pressed)

	_apply_scene_color("default", 0.0)
	_set_extra_life_label_visible(false)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().reload_current_scene()
	elif victory_overlay and victory_overlay.visible and event.is_action_pressed("ui_accept"):
		_restart_game()

func _on_category_reached(category: String) -> void:
	current_category = category
	var alpha = PANEL_IDLE_ALPHA
	if preguntas_panel and preguntas_panel.visible:
		alpha = PANEL_ACTIVE_ALPHA
	_apply_scene_color(category, alpha)

func _on_question_panel_opened() -> void:
	if current_category != "":
		_apply_scene_color(current_category, PANEL_ACTIVE_ALPHA)

func _on_question_panel_closed() -> void:
	if current_category != "":
		_apply_scene_color(current_category, PANEL_IDLE_ALPHA)

func _on_extra_life_awarded(total_lives: int) -> void:
	current_category = "Health"
	_apply_scene_color("Health", HEALTH_FLASH_ALPHA)
	_show_extra_life_toast(total_lives)

func _show_extra_life_toast(total_lives: int) -> void:
	if not extra_life_label:
		return

	extra_life_label.text = "+1 Vida extra! Ahora tienes %d" % total_lives
	_set_extra_life_label_visible(true)

	if extra_life_tween and extra_life_tween.is_running():
		extra_life_tween.kill()

	extra_life_label.modulate.a = 0.0
	extra_life_tween = create_tween()
	extra_life_tween.tween_property(extra_life_label, "modulate:a", 1.0, 0.3)
	extra_life_tween.tween_interval(1.6)
	extra_life_tween.tween_property(extra_life_label, "modulate:a", 0.0, 0.7)
	extra_life_tween.finished.connect(func(): _set_extra_life_label_visible(false))

func _set_extra_life_label_visible(visible: bool) -> void:
	if extra_life_label:
		extra_life_label.visible = visible
		if not visible:
			extra_life_label.modulate.a = 0.0

func _on_victory_reached(total_points: int) -> void:
	_show_end_overlay(true, total_points)

func _on_defeat_reached() -> void:
	_show_end_overlay(false, 0)

func _show_end_overlay(victory: bool, total_points: int) -> void:
	if victory_overlay:
		victory_overlay.visible = true
	if victory_title_label:
		victory_title_label.text = "¡Victoria!" if victory else "Juego terminado"
	if victory_message_label:
		victory_message_label.text = ("Alcanzaste %d puntos y ganaste la partida." % total_points) if victory else "Te quedaste sin vidas. ¡Inténtalo de nuevo!"

	current_category = ""
	var finish_color = Color.html("#f5d76e") if victory else Color.html("#e06666")
	_tween_overlay_color(finish_color, 0.42)
	_tween_light_color(finish_color)
	_update_floor_color(finish_color)
	_update_ui_colors(finish_color)

	_lock_gameplay()

	if restart_button:
		restart_button.grab_focus()

func _lock_gameplay() -> void:
	if dice and dice.has_method("lock_roll"):
		dice.lock_roll()
	if preguntas_panel:
		preguntas_panel.hide()

func _on_restart_button_pressed() -> void:
	_restart_game()

func _restart_game() -> void:
	get_tree().reload_current_scene()

func _apply_scene_color(category: String, alpha: float) -> void:
	var base_color = CATEGORY_COLORS.get(category, CATEGORY_COLORS["default"])
	_tween_overlay_color(base_color, 0.0 if alpha < 0.4 else alpha)
	_tween_light_color(base_color)
	_update_floor_color(base_color)
	_update_ui_colors(base_color)
	if preguntas_panel and preguntas_panel.has_method("actualizar_colores_de_ui"):
		preguntas_panel.actualizar_colores_de_ui(base_color)

func _floor_prepare_material() -> void:
	var active_material: Material = floor_mesh.get_active_material(0)
	if active_material:
		floor_material = active_material.duplicate()
		floor_mesh.set_surface_override_material(0, floor_material)
		if floor_material is BaseMaterial3D:
			default_floor_color = (floor_material as BaseMaterial3D).albedo_color
	else:
		default_floor_color = Color.WHITE

func _update_floor_color(base_color: Color) -> void:
	if not floor_material:
		return
	var target_color = base_color.lerp(default_floor_color, 0.35)
	(floor_material as BaseMaterial3D).albedo_color = target_color

func _update_ui_colors(base_color: Color) -> void:
	var accent = base_color.lerp(Color.WHITE, 0.55)
	if score_label:
		score_label.add_theme_color_override("font_color", accent)
	if health_label:
		health_label.add_theme_color_override("font_color", accent)

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
