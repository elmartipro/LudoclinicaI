extends Node

const CATEGORY_COLORS = {
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

const PANEL_ACTIVE_WEIGHT = 0.38
const PANEL_IDLE_WEIGHT = 0.18
const HEALTH_FLASH_WEIGHT = 0.3

@onready var omni_light: OmniLight3D = $OmniLight3D
@onready var spots: Node = $Spots
@onready var preguntas_panel: CanvasLayer = $PreguntasPanel
@onready var extra_life_label: Label = $HUDMessages/ExtraLifeLabel
@onready var dice: Node = $Dice
@onready var victory_overlay: CanvasLayer = $VictoryOverlay
@onready var victory_title_label: Label = $"VictoryOverlay/CenterContainer/Panel/VBoxContainer/TitleLabel"
@onready var victory_message_label: Label = $"VictoryOverlay/CenterContainer/Panel/VBoxContainer/MessageLabel"
@onready var restart_button: Button = $"VictoryOverlay/CenterContainer/Panel/VBoxContainer/RestartButton"
@onready var score_label: Label = $Score
@onready var health_label: Label = $Health
@onready var floor_mesh: MeshInstance3D = $Floor/MeshInstance3D

var default_light_color: Color = Color.WHITE
var current_category: String = ""
var light_tween: Tween
var extra_life_tween: Tween
var floor_tween: Tween

var floor_material: StandardMaterial3D
var default_floor_color: Color = Color(0.136085, 0.201433, 0.314399, 1)

var base_score_font_color: Color = Color.WHITE
var base_health_font_color: Color = Color.WHITE
var base_extra_font_color: Color = Color.WHITE

var score_stylebox: StyleBoxFlat
var health_stylebox: StyleBoxFlat
var extra_life_stylebox: StyleBoxFlat

var base_score_bg_color: Color = Color(0.129412, 0.388235, 0.360784, 0.25098)
var base_health_bg_color: Color = Color(0.129412, 0.388235, 0.360784, 0.25098)
var base_extra_bg_color: Color = Color(0.129412, 0.388235, 0.360784, 0.25098)

var life_icon: String = "✚"

func _ready() -> void:
    RenderingServer.force_draw(true)

    if omni_light:
        default_light_color = omni_light.light_color

    _setup_floor_material()
    _cache_hud_styles()

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
    var weight = PANEL_IDLE_WEIGHT
    if preguntas_panel and preguntas_panel.visible:
        weight = PANEL_ACTIVE_WEIGHT
    _apply_scene_color(category, weight)

func _on_question_panel_opened() -> void:
    if current_category != "":
        _apply_scene_color(current_category, PANEL_ACTIVE_WEIGHT)

func _on_question_panel_closed() -> void:
    if current_category != "":
        _apply_scene_color(current_category, PANEL_IDLE_WEIGHT)

func _on_extra_life_awarded(total_lives: int) -> void:
    current_category = "Health"
    _apply_scene_color("Health", HEALTH_FLASH_WEIGHT)
    _show_extra_life_toast(total_lives)

func _show_extra_life_toast(total_lives: int) -> void:
    if not extra_life_label:
        return

    extra_life_label.text = "+1 Vida extra! Ahora tienes %s" % _format_lives_icons(total_lives)
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
    if not extra_life_label:
        return
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
    _tint_floor(finish_color, 0.75)
    _tint_ui(finish_color, 0.75)
    _tween_light_color(finish_color)

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

func _apply_scene_color(category: String, weight: float) -> void:
    var base_color = CATEGORY_COLORS.get(category, CATEGORY_COLORS["default"])
    var mix = 0.0
    if category != "default":
        mix = clamp(0.2 + weight * 1.3, 0.0, 0.9)
    _tint_floor(base_color, mix)
    _tint_ui(base_color, mix)
    _tween_light_color(base_color)

func _tint_floor(base_color: Color, mix: float) -> void:
    if not floor_material:
        return
    var target_color = default_floor_color.lerp(base_color, mix)
    if floor_tween and floor_tween.is_running():
        floor_tween.kill()
    floor_tween = create_tween()
    floor_tween.tween_property(floor_material, "albedo_color", target_color, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _tint_ui(base_color: Color, mix: float) -> void:
    _apply_label_tint(score_label, score_stylebox, base_score_font_color, base_score_bg_color, base_color, mix)
    _apply_label_tint(health_label, health_stylebox, base_health_font_color, base_health_bg_color, base_color, mix)
    _apply_label_tint(extra_life_label, extra_life_stylebox, base_extra_font_color, base_extra_bg_color, base_color, mix)

func _apply_label_tint(label: Label, stylebox: StyleBoxFlat, default_font: Color, default_bg: Color, base_color: Color, mix: float) -> void:
    if label:
        var accent_font = base_color.lerp(Color.WHITE, 0.35)
        var target_font = default_font.lerp(accent_font, mix)
        label.add_theme_color_override("font_color", target_font)
    if stylebox:
        var accent_bg = base_color.darkened(0.25)
        accent_bg.a = default_bg.a
        stylebox.bg_color = default_bg.lerp(accent_bg, mix)

func _tween_light_color(base_color: Color) -> void:
    if not omni_light:
        return
    if light_tween and light_tween.is_running():
        light_tween.kill()
    var target = base_color.lerp(default_light_color, 0.4)
    light_tween = create_tween()
    light_tween.tween_property(omni_light, "light_color", target, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _setup_floor_material() -> void:
    if not floor_mesh:
        return
    var source: StandardMaterial3D
    var override_material = floor_mesh.get_surface_override_material(0)
    if override_material and override_material is StandardMaterial3D:
        source = override_material
    else:
        var active_material = floor_mesh.get_active_material(0)
        if active_material and active_material is StandardMaterial3D:
            source = active_material
    if source:
        floor_material = source.duplicate()
        default_floor_color = floor_material.albedo_color
    else:
        floor_material = StandardMaterial3D.new()
        floor_material.albedo_color = default_floor_color
    floor_mesh.set_surface_override_material(0, floor_material)

func _cache_hud_styles() -> void:
    if score_label:
        base_score_font_color = score_label.get_theme_color("font_color", "Label")
        var style = score_label.get_theme_stylebox("normal", "Label")
        if style and style is StyleBoxFlat:
            score_stylebox = style.duplicate()
            base_score_bg_color = score_stylebox.bg_color
            score_label.add_theme_stylebox_override("normal", score_stylebox)
    if health_label:
        base_health_font_color = health_label.get_theme_color("font_color", "Label")
        var health_style = health_label.get_theme_stylebox("normal", "Label")
        if health_style and health_style is StyleBoxFlat:
            health_stylebox = health_style.duplicate()
            base_health_bg_color = health_stylebox.bg_color
            health_label.add_theme_stylebox_override("normal", health_stylebox)
    if extra_life_label:
        base_extra_font_color = extra_life_label.get_theme_color("font_color", "Label")
        var extra_style = extra_life_label.get_theme_stylebox("normal", "Label")
        if extra_style and extra_style is StyleBoxFlat:
            extra_life_stylebox = extra_style.duplicate()
            base_extra_bg_color = extra_life_stylebox.bg_color
            extra_life_label.add_theme_stylebox_override("normal", extra_life_stylebox)

func _format_lives_icons(total_lives: int) -> String:
    if total_lives <= 0:
        return "—"
    var icons: Array[String] = []
    for _i in range(total_lives):
        icons.append(life_icon)
    return " ".join(icons)
