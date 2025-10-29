extends Node

const CORRECT_STREAM: AudioStream = preload("res://Assets/sfx/correct_answer.mp3")
const WRONG_STREAM: AudioStream = preload("res://Assets/sfx/wrong_answer.mp3")
const FAILURE_STREAM: AudioStream = preload("res://Assets/sfx/failure.mp3")
const SUCCESS_STREAM: AudioStream = preload("res://Assets/sfx/success.mp3")
const DICE_THROW_STREAM: AudioStream = preload("res://Assets/sfx/dice throw.mp3")
const PAWN_LAND_STREAM: AudioStream = preload("res://Assets/sfx/pawn land.mp3")
const SELECT_STREAMS: Array[AudioStream] = [
	preload("res://Assets/sfx/select_button1.mp3"),
	preload("res://Assets/sfx/select_button2.mp3")
]

var rng := RandomNumberGenerator.new()
var correct_player: AudioStreamPlayer
var wrong_player: AudioStreamPlayer
var failure_player: AudioStreamPlayer
var success_player: AudioStreamPlayer
var select_player: AudioStreamPlayer
var dice_throw_player: AudioStreamPlayer
var pawn_land_player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	correct_player = _create_player("CorrectPlayer", CORRECT_STREAM, 4)
	wrong_player = _create_player("WrongPlayer", WRONG_STREAM, 4)
	failure_player = _create_player("FailurePlayer", FAILURE_STREAM, 2)
	success_player = _create_player("SuccessPlayer", SUCCESS_STREAM, 2)
	var initial_select_stream: AudioStream = SELECT_STREAMS[0] if not SELECT_STREAMS.is_empty() else null
	select_player = _create_player("SelectPlayer", initial_select_stream, 12)
	dice_throw_player = _create_player("DiceThrowPlayer", DICE_THROW_STREAM, 2)
	pawn_land_player = _create_player("PawnLandPlayer", PAWN_LAND_STREAM, 4)
	var tree := get_tree()
	if tree:
		tree.node_added.connect(_on_node_added)
		_scan_tree(tree.root)

func play_correct_answer() -> void:
	_play_stream(correct_player, CORRECT_STREAM)

func play_wrong_answer() -> void:
	_play_stream(wrong_player, WRONG_STREAM)

func play_failure() -> void:
	_play_stream(failure_player, FAILURE_STREAM)

func play_success() -> void:
	_play_stream(success_player, SUCCESS_STREAM)

func play_select() -> void:
	if SELECT_STREAMS.is_empty():
		return
	var index := rng.randi_range(0, SELECT_STREAMS.size() - 1)
	var stream := SELECT_STREAMS[index]
	_play_stream(select_player, stream)

func play_dice_throw() -> void:
	_play_stream(dice_throw_player, DICE_THROW_STREAM)

func play_pawn_land() -> void:
	_play_stream(pawn_land_player, PAWN_LAND_STREAM)

func _create_player(player_name: String, stream: AudioStream, polyphony: int) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.stream = stream
	player.max_polyphony = max(polyphony, 1)
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player

func _play_stream(player: AudioStreamPlayer, stream: AudioStream) -> void:
	if player == null or stream == null:
		return
	player.stream = stream
	player.play()

func _on_node_added(node: Node) -> void:
	if node == null:
		return
	if node is BaseButton:
		_connect_button(node as BaseButton)
	_scan_tree(node)

func _scan_tree(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		if child is BaseButton:
			_connect_button(child as BaseButton)
		_scan_tree(child)

func _connect_button(button: BaseButton) -> void:
	if button == null:
		return
	if button.has_meta("_sfx_select_connected"):
		return
	button.pressed.connect(_on_any_button_pressed)
	button.set_meta("_sfx_select_connected", true)

func _on_any_button_pressed() -> void:
	play_select()
