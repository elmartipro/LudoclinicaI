extends CharacterBody3D

signal pawn_finished_moving(spot: Marker3D, index: int)

@export var game_spaces: Array[Marker3D]

var pawn_landed: bool = true
var place: int = 0
var place_number: int = 0
var remaining_steps: int = 0
var is_jumping: bool = false
var jump_t: float = 0.0
var jump_duration: float = 0.4
var jump_start: Vector3
var jump_end: Vector3
var current_jump_target_index: int = -1

func _ready() -> void:
	place_number = game_spaces.size()
	place = 0
	remaining_steps = 0
	is_jumping = false

func reset_path(start_index: int = 0) -> void:
	place = clamp(start_index, 0, max(place_number - 1, 0))
	remaining_steps = 0
	is_jumping = false
	pawn_landed = true
	if game_spaces.size() > 0:
		global_position = game_spaces[place].global_position

func advance_to_next_spot(steps: int = 1) -> void:
	if place_number == 0:
		return
	if steps <= 0:
		steps = 1
	if is_jumping or remaining_steps > 0:
		return
	remaining_steps = steps
	pawn_landed = false
	_start_next_jump()

func _start_next_jump() -> void:
	current_jump_target_index = place % place_number
	jump_start = global_position
	jump_end = game_spaces[current_jump_target_index].global_position
	jump_t = 0.0
	is_jumping = true

func _process(delta: float) -> void:
	if not is_jumping:
		return
	jump_t += delta / jump_duration
	if jump_t >= 1.0:
		jump_t = 1.0
		is_jumping = false
		global_position = jump_end
		var landed_index: int = current_jump_target_index
		place = (place + 1) % place_number
		remaining_steps -= 1
		if remaining_steps > 0:
			_start_next_jump()
		else:
			pawn_landed = true
			emit_signal("pawn_finished_moving", game_spaces[landed_index], landed_index)
		return
	var t: float = jump_t
	var pos: Vector3 = jump_start.lerp(jump_end, t)
	var height: float = 10.0
	var arc: float = 4.0 * height * t * (1.0 - t)
	pos.y += arc
	global_position = pos
