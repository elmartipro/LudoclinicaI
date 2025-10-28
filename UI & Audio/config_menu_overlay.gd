extends CanvasLayer

signal menu_requested
signal menu_visibility_changed(abierto: bool)

@onready var config_button: Button = $ConfigButton
@onready var dimmer: ColorRect = $Dimmer
@onready var panel_container: MarginContainer = $PanelContainer
@onready var panel: Panel = $PanelContainer/Panel
@onready var close_button: Button = $PanelContainer/Panel/VBoxContainer/CloseButton
@onready var main_menu_button: Button = $PanelContainer/Panel/VBoxContainer/MainMenuButton
@onready var slider: HSlider = $PanelContainer/Panel/VBoxContainer/MusicRow/MusicSlider

var menu_open: bool = false

func _ready() -> void:
	_hide_menu_elements()
	if config_button:
		config_button.pressed.connect(_on_config_button_pressed)
	if close_button:
		close_button.pressed.connect(close_menu)
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_button_pressed)
	if dimmer:
		dimmer.gui_input.connect(_on_dimmer_gui_input)
	if slider:
		slider.focus_mode = Control.FOCUS_ALL

func _on_config_button_pressed() -> void:
	if menu_open:
		close_menu()
	else:
		open_menu()

func open_menu() -> void:
	if menu_open:
		return
	menu_open = true
	_show_menu_elements()
	emit_signal("menu_visibility_changed", true)
	if slider:
		slider.grab_focus()

func close_menu() -> void:
	if not menu_open:
		return
	menu_open = false
	_hide_menu_elements()
	emit_signal("menu_visibility_changed", false)
	if config_button:
		config_button.grab_focus()

func is_menu_open() -> bool:
	return menu_open

func _on_main_menu_button_pressed() -> void:
	close_menu()
	emit_signal("menu_requested")

func _on_dimmer_gui_input(event: InputEvent) -> void:
	if not menu_open:
		return
	if event is InputEventMouseButton and event.pressed:
		close_menu()

func _unhandled_input(event: InputEvent) -> void:
	if not menu_open:
		return
	if event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()

func _show_menu_elements() -> void:
	if dimmer:
		dimmer.visible = true
		dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	if panel_container:
		panel_container.visible = true

func _hide_menu_elements() -> void:
	if dimmer:
		dimmer.visible = false
		dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if panel_container:
		panel_container.visible = false
