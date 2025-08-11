extends AudioStreamPlayer2D

var started := false

func _ready():
	if not started:
		play()
		started = true
