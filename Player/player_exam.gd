extends CharacterBody3D

signal pawn_finished_moving(spot: Marker3D)

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
	self.pawn_finished_moving.connect(_on_pawn_finished_moving)

func advance_steps(steps: int) -> void:
	if steps <= 0:
		return
	if place_number == 0:
		return
	if is_jumping or remaining_steps > 0:
		return
	remaining_steps = steps
	pawn_landed = false
	_start_next_jump()

func _process(delta: float) -> void:
	if not is_jumping:
		return
	jump_t += delta / jump_duration
	if jump_t >= 1.0:
		jump_t = 1.0
		is_jumping = false
		global_position = jump_end
		place = (place + 1) % place_number
		remaining_steps -= 1
		if remaining_steps > 0:
			_start_next_jump()
		else:
			pawn_landed = true
			var landed_spot: Marker3D = game_spaces[current_jump_target_index]
			emit_signal("pawn_finished_moving", landed_spot)
	_update_jump_position()

func _start_next_jump() -> void:
	current_jump_target_index = place
	jump_start = global_position
	jump_end = game_spaces[current_jump_target_index].global_position
	jump_t = 0.0
	is_jumping = true

func _update_jump_position() -> void:
	var t = jump_t
	var pos = jump_start.lerp(jump_end, t)
	var height = 10.0
	var arc = 4.0 * height * t * (1.0 - t)
	pos.y += arc
	global_position = pos

func spawn_landing_vfx() -> void:
	var vfx_scene = preload("res://Assets/Vfx/PawnLandingVfx.tscn")
	var vfx = vfx_scene.instantiate()
	get_tree().current_scene.add_child(vfx)
	vfx.global_position = global_position

func _on_pawn_finished_moving(_spot: Node) -> void:
	spawn_landing_vfx()
