extends CanvasLayer

signal tutorial_closed

@onready var dimmer: ColorRect = $Dimmer
@onready var title_label: Label = $"CenterContainer/Panel/VBoxContainer/Title"
@onready var description_label: RichTextLabel = $"CenterContainer/Panel/VBoxContainer/Description"
@onready var start_button: Button = $"CenterContainer/Panel/VBoxContainer/StartButton"

var _is_open: bool = false
var _was_paused: bool = false

func _ready() -> void:
        visible = false
        pause_mode = Node.PAUSE_MODE_PROCESS
        set_process_unhandled_input(true)
        if start_button:
                start_button.pressed.connect(_on_start_button_pressed)
        if dimmer:
                dimmer.visible = true

func show_tutorial(title: String, description: String) -> void:
        if title_label:
                title_label.text = title
        if description_label:
                description_label.bbcode_text = description
        if _is_open:
                return
        _was_paused = get_tree().paused
        if not _was_paused:
                get_tree().paused = true
        visible = true
        _is_open = true
        if start_button:
                start_button.grab_focus()

func is_showing() -> bool:
        return _is_open

func _on_start_button_pressed() -> void:
        close()

func close() -> void:
        if not _is_open:
                return
        visible = false
        _is_open = false
        if not _was_paused and get_tree().paused:
                get_tree().paused = false
        tutorial_closed.emit()
        _was_paused = false

func _unhandled_input(event: InputEvent) -> void:
        if not _is_open:
                return
        if event.is_action_pressed("ui_accept"):
                _on_start_button_pressed()
                if get_viewport():
                        get_viewport().set_input_as_handled()
        elif event.is_action_pressed("ui_cancel"):
                if get_viewport():
                        get_viewport().set_input_as_handled()
