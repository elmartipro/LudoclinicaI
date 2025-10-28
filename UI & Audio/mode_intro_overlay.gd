extends CanvasLayer

signal intro_closed

@onready var title_label: Label = $"CenterContainer/Panel/VBoxContainer/Title"
@onready var body_label: RichTextLabel = $"CenterContainer/Panel/VBoxContainer/Body"
@onready var start_button: Button = $"CenterContainer/Panel/VBoxContainer/StartButton"

var is_showing: bool = false
var pause_applied: bool = false

func _ready() -> void:
		hide()
		if start_button:
			start_button.pressed.connect(_on_start_button_pressed)
		process_mode = Node.PROCESS_MODE_WHEN_PAUSED

func show_intro(title: String, body: String) -> void:
		if title_label:
				title_label.text = title
		if body_label:
				body_label.text = body
		show()
		is_showing = true
		if not get_tree().paused:
				get_tree().paused = true
				pause_applied = true
		if start_button:
				start_button.grab_focus()

func close_intro() -> void:
		if not is_showing:
				return
		hide()
		is_showing = false
		if pause_applied and get_tree().paused:
				get_tree().paused = false
		pause_applied = false
		intro_closed.emit()

func _on_start_button_pressed() -> void:
		close_intro()

func _unhandled_input(event: InputEvent) -> void:
		if not is_showing:
				return
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
				close_intro()
				if get_viewport():
						get_viewport().set_input_as_handled()
