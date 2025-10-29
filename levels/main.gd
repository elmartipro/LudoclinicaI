extends Node

var CATEGORY_COLORS = {
	"Epidemiología": Color.html("#7159C4"),
	"Fisiopatología": Color.html("#C0429D"),
	"Manifestaciones clínicas y paraclínicas": Color.html("#108072"),
	"Diagnóstico diferencial": Color.html("#2A6E96"),
	"Tratamiento": Color.html("#BC3232"),
	"Seguimiento": Color.html("#446F47"),
	"Cultura": Color.html("#E7CB8B"),
	"Health": Color.html("#27ae60"),
	"default": Color.html("#5F9A88")
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
@onready var click_instruction_label: Label = $"HUDMessages/ClickInstructionLabel"
@onready var score_label: Label = $Score
@onready var health_label: Label = $Health
@onready var dice: Node = $Dice
@onready var victory_overlay: CanvasLayer = $VictoryOverlay
@onready var victory_title_label: Label = $"VictoryOverlay/CenterContainer/Panel/VBoxContainer/TitleLabel"
@onready var victory_message_label: Label = $"VictoryOverlay/CenterContainer/Panel/VBoxContainer/MessageLabel"
@onready var restart_button: Button = $"VictoryOverlay/CenterContainer/Panel/VBoxContainer/RestartButton"
@onready var menu_button: Button = $"VictoryOverlay/CenterContainer/Panel/VBoxContainer/MenuButton"
@onready var exit_confirm_dialog: ConfirmationDialog = $ExitConfirmDialog
@onready var config_overlay: CanvasLayer = $ConfigOverlay
@onready var intro_overlay: CanvasLayer = $ModeIntroOverlay
@onready var config_button: BaseButton = $"ConfigButtonLayer/ConfigButtonRoot/ConfigButton"
@onready var guide_overlay: CanvasLayer = $GuideOverlay
@onready var guide_button: BaseButton = $"GuideButtonLayer/GuideButtonRoot/GuideButton"

var default_light_color: Color = Color.WHITE
var default_floor_color: Color = Color.WHITE
var current_category: String = ""
var floor_material: BaseMaterial3D
var overlay_tween: Tween
var light_tween: Tween
var extra_life_tween: Tween
var defeat_forces_menu: bool = false
var has_shown_click_instruction: bool = false

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
	if menu_button:
		menu_button.pressed.connect(_on_menu_button_pressed)
	if guide_button:
		guide_button.pressed.connect(_on_guide_button_pressed)
	if guide_overlay:
		guide_overlay.overlay_closed.connect(_on_guide_overlay_closed)
	if exit_confirm_dialog:
		exit_confirm_dialog.dialog_text = "¿Está seguro que quiere ir al menu principal?\nSu progreso no se guardará"
		var ok_button: Button = exit_confirm_dialog.get_ok_button()
		if ok_button:
			ok_button.text = "Sí"
		var cancel_button: Button = exit_confirm_dialog.get_cancel_button()
		if cancel_button:
			cancel_button.text = "No"
		exit_confirm_dialog.confirmed.connect(_on_exit_confirmed)
		if config_button:
				config_button.pressed.connect(_on_config_button_pressed)
		if config_overlay:
				config_overlay.overlay_closed.connect(_on_config_overlay_closed)
				config_overlay.menu_requested.connect(_on_config_overlay_menu_requested)
				config_overlay.restart_requested.connect(_on_config_overlay_restart_requested)
		if intro_overlay:
				intro_overlay.intro_closed.connect(_on_intro_overlay_closed)
				intro_overlay.call_deferred("show_intro", "Modo fácil", "[center]Un recorrido relajado para practicar las categorías del juego sin presión.\nLanza el dado, aprende a tu ritmo y experimenta cada tema con calma.[/center]")
		defeat_forces_menu = false

		_apply_scene_color("default", 0.0)
		_set_extra_life_label_visible(false)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("LeftClick"):
		if click_instruction_label and click_instruction_label.visible:
			click_instruction_label.visible = false
	if event.is_action_pressed("ui_cancel"):
		if guide_overlay and guide_overlay.is_open:
			guide_overlay.close()
		elif config_overlay and config_overlay.is_open:
			config_overlay.close()
		else:
			_show_exit_dialog()
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

func _on_guide_button_pressed() -> void:
	if guide_overlay:
		guide_overlay.open()

func _on_guide_overlay_closed() -> void:
	if guide_button:
		guide_button.grab_focus()

func _on_victory_reached(total_points: int) -> void:
	_show_end_overlay(true, total_points)

func _on_defeat_reached() -> void:
	_show_end_overlay(false, 0)

func _show_end_overlay(victory: bool, total_points: int) -> void:
	if victory_overlay:
		victory_overlay.visible = true
	if victory_title_label:
		if victory:
			victory_title_label.text = "¡Victoria!"
		else:
			victory_title_label.text = "Juego terminado"
	if victory_message_label:
		if victory:
			victory_message_label.text = "Alcanzaste %d puntos y ganaste la partida." % total_points
		else:
			victory_message_label.text = "Te quedaste sin vidas.\n¡Inténtalo de nuevo!"

	current_category = ""
	var finish_color: Color = Color.html("#f5d76e")
	if not victory:
		finish_color = Color.html("#e06666")
	var podium_color = _update_floor_color(finish_color)
	_tween_overlay_color(podium_color, 0.42)
	_tween_light_color(finish_color)
	_update_ui_colors(podium_color)

	_lock_gameplay()
	defeat_forces_menu = not victory
	if restart_button:
		if victory:
			restart_button.visible = true
			restart_button.text = "Reiniciar partida"
		else:
			restart_button.visible = false
	if menu_button:
		menu_button.visible = true
		menu_button.text = "Menú principal"
	if victory:
		if restart_button and restart_button.visible:
			restart_button.grab_focus()
		elif menu_button:
			menu_button.grab_focus()
	else:
		if menu_button:
			menu_button.grab_focus()

func _lock_gameplay() -> void:
	if dice and dice.has_method("lock_roll"):
		dice.lock_roll()
	if preguntas_panel:
		preguntas_panel.hide()

func _on_restart_button_pressed() -> void:
	_restart_game()

func _restart_game() -> void:
	if defeat_forces_menu:
		_return_to_main_menu()
		return
	get_tree().reload_current_scene()

func _on_menu_button_pressed() -> void:
	_return_to_main_menu()

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

func _on_exit_confirmed() -> void:
	defeat_forces_menu = false
	_return_to_main_menu()

func _return_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://UI & Audio/Pantalla de Inicio/pantalla_de_incio.tscn")

func _on_config_button_pressed() -> void:
	if config_overlay:
		config_overlay.open()

func _on_config_overlay_closed() -> void:
	if config_button:
		config_button.grab_focus()

func _on_config_overlay_menu_requested() -> void:
	_show_exit_dialog()

func _on_config_overlay_restart_requested() -> void:
		defeat_forces_menu = false
		get_tree().reload_current_scene()

func _on_intro_overlay_closed() -> void:
	if config_button:
		config_button.grab_focus()
	if not has_shown_click_instruction and click_instruction_label:
		click_instruction_label.visible = true
		has_shown_click_instruction = true

func _apply_scene_color(category: String, alpha: float) -> void:
	var base_color = CATEGORY_COLORS.get(category, CATEGORY_COLORS["default"])
	var podium_color = _update_floor_color(base_color)
	_tween_overlay_color(podium_color, 0.0 if alpha < 0.4 else alpha)
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
	if health_label:
		health_label.add_theme_color_override("font_color", accent)
		health_label.add_theme_color_override("font_outline_color", secondary)

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
