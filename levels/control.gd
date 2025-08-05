extends Control
#Define Panel y El timer
@onready var panel = $PanelContainer
@onready var timer = $PanelContainer/Timer


func _ready():
	panel.visible = false #hace que el panel este invisible
	timer.start() #el timer comienza, tarda 2 seg
	timer.timeout.connect(_on_Timer_timeout)

func _on_Timer_timeout():
	panel.visible = true #vuelve visible el panel con texto cuando el timer llega a 0
