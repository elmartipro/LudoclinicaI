extends CanvasLayer

signal overlay_closed
signal menu_requested
signal restart_requested

@onready var panel: Panel = get_node_or_null("CenterContainer/Panel") as Panel
@onready var volume_slider: HSlider = get_node_or_null("CenterContainer/Panel/VBoxContainer/VolumeContainer/VolumeSlider") as HSlider
@onready var slider_info: Label = get_node_or_null("CenterContainer/Panel/VBoxContainer/VolumeContainer/SliderInfo") as Label
@onready var mute_toggle: CheckButton = get_node_or_null("CenterContainer/Panel/VBoxContainer/MuteToggle") as CheckButton
@onready var close_button: Button = get_node_or_null("CenterContainer/Panel/VBoxContainer/ButtonGrid/CloseButton") as Button
@onready var dimmer: ColorRect = get_node_or_null("Dimmer") as ColorRect

var is_open: bool = false
var pause_applied: bool = false
var ignore_toggle_update: bool = false
var stored_volume: float = 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	if volume_slider:
		stored_volume = max(volume_slider.value, 0.05)
		_update_slider_info(volume_slider.value)
		volume_slider.value_changed.connect(_on_volume_value_changed)
		_apply_music_volume(volume_slider.value)
	if mute_toggle:
		mute_toggle.button_pressed = volume_slider.value <= 0.001
	if dimmer:
		dimmer.gui_input.connect(_on_dimmer_gui_input)

func open() -> void:
	if is_open:
		return
	show()
	is_open = true
	if not get_tree().paused:
		get_tree().paused = true
		pause_applied = true
	if close_button:
		close_button.grab_focus()
	elif panel:
		panel.grab_focus()

func close() -> void:
	if not is_open:
		return
	hide()
	is_open = false
	if pause_applied:
		get_tree().paused = false
	pause_applied = false
	overlay_closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_close_button_pressed()
		if get_viewport():
			get_viewport().set_input_as_handled()

func _on_close_button_pressed() -> void:
	close()

func _on_main_menu_button_pressed() -> void:
	var was_open: bool = is_open
	close()
	if was_open:
		menu_requested.emit()

func _on_restart_button_pressed() -> void:
	var was_open: bool = is_open
	close()
	if was_open:
		restart_requested.emit()

func _on_mute_toggle_toggled(button_pressed: bool) -> void:
	if ignore_toggle_update:
		return
	if not volume_slider:
		return
	if button_pressed:
		stored_volume = max(volume_slider.value, stored_volume)
		if stored_volume <= 0.001:
			stored_volume = 0.5
		ignore_toggle_update = true
		volume_slider.value = 0.0
		ignore_toggle_update = false
	else:
		var restore_value: float = max(stored_volume, 0.05)
		ignore_toggle_update = true
		volume_slider.value = restore_value
		ignore_toggle_update = false

func _on_volume_value_changed(value: float) -> void:
	_update_slider_info(value)
	_apply_music_volume(value)
	if value > 0.001:
		stored_volume = value
	if mute_toggle and not ignore_toggle_update:
		var should_mute: bool = value <= 0.001
		if mute_toggle.button_pressed != should_mute:
			ignore_toggle_update = true
			mute_toggle.button_pressed = should_mute
			ignore_toggle_update = false

func _update_slider_info(value: float) -> void:
	if not slider_info:
		return
	var percent: int = int(round(value * 100.0))
	slider_info.text = "%d%%" % percent

func _on_dimmer_gui_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
		_on_close_button_pressed()
		if get_viewport():
			get_viewport().set_input_as_handled()

func _apply_music_volume(value: float) -> void:
	var clamped_value: float = clamp(value, 0.0, 1.0)
	var db: float = -80.0
	if clamped_value > 0.0:
		db = linear_to_db(clamped_value)
	var bus_index: int = AudioServer.get_bus_index("MusicaDeFondo")
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, db)
	if MusicaDeFondo:
		MusicaDeFondo.volume_db = db
