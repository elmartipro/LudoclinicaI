extends AudioStreamPlayer2D

var started := false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not started:
		play()
		started = true
