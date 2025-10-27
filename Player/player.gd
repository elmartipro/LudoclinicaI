extends CharacterBody3D

signal pawn_finished_moving(spot: Marker3D)

@onready var pawn: CharacterBody3D = self
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

func advance_one_space() -> void:
	if place >= place_number:
		place = 0
	if is_jumping or remaining_steps > 0:
		return
	remaining_steps = 1
	pawn_landed = false
	_start_next_jump()

func _start_next_jump() -> void:
	current_jump_target_index = place
	jump_start = pawn.global_position
	jump_end = game_spaces[current_jump_target_index].global_position
	jump_t = 0.0
	is_jumping = true

func _process(delta: float) -> void:
	if is_jumping:
		jump_t += delta / jump_duration
		if jump_t >= 1.0:
			jump_t = 1.0
			is_jumping = false
			pawn.global_position = jump_end
			place = (place + 1) % place_number
			remaining_steps -= 1
			if remaining_steps > 0:
				_start_next_jump()
			else:
				pawn_landed = true
				var landed_spot: Marker3D = game_spaces[current_jump_target_index]
				emit_signal("pawn_finished_moving", landed_spot)
		var t: float = jump_t
		var pos: Vector3 = jump_start.lerp(jump_end, t)
		var height: float = 10.0
		var arc: float = 4.0 * height * t * (1.0 - t)
		pos.y += arc
		pawn.global_position = pos

func _on_pawn_finished_moving(_landed_spot: Node) -> void:
	var vfx = preload("res://Assets/Vfx/PawnLandingVfx.tscn").instantiate()
	get_tree().current_scene.add_child(vfx)
	vfx.global_position = global_position
