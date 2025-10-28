extends Node

const BACKGROUND_SCENE := preload("res://UI & Audio/Pantalla de Inicio/title_background.tscn")

var _background_instance: CanvasLayer = null
var _visible: bool = false

func ensure_visible() -> void:
	if not is_instance_valid(_background_instance):
		_background_instance = BACKGROUND_SCENE.instantiate() as CanvasLayer
		_background_instance.hide()
		get_tree().root.add_child(_background_instance)
	_show_internal()

func hide_background() -> void:
	_visible = false
	if is_instance_valid(_background_instance):
		_background_instance.hide()
		var player := _background_instance.get_node_or_null("Video")
		if player is VideoStreamPlayer:
			(player as VideoStreamPlayer).stop()

func _show_internal() -> void:
	_visible = true
	if not is_instance_valid(_background_instance):
		return
	_background_instance.show()
	var player := _background_instance.get_node_or_null("Video")
	if player is VideoStreamPlayer:
		var stream_player: VideoStreamPlayer = player
		if stream_player.stream:
			if not stream_player.is_playing():
				stream_player.play()
		stream_player.loop = true

func is_visible() -> bool:
	return _visible and is_instance_valid(_background_instance)
