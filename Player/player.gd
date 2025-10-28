extends CharacterBody3D

signal pawn_finished_moving(spot: Marker3D)

@onready var pawn: CharacterBody3D = self
@onready var dice := $"../Dice"
@export var game_spaces: Array[Marker3D]

var pawn_landed: bool = true

var place: int = 0					# index to move toward next
var place_number: int = 0
var remaining_steps: int = 0

# jump anim
var is_jumping := false
var jump_t := 0.0
var jump_duration := 0.4
var jump_start: Vector3
var jump_end: Vector3
var current_jump_target_index: int = -1	# <-- NEW: the spot we are jumping to

func _ready() -> void:
	place_number = game_spaces.size()
	if dice and dice.has_signal("roll_finished"):
		dice.roll_finished.connect(_on_dice_roll_finished)
	self.pawn_finished_moving.connect(_on_pawn_finished_moving) # connect locally

func _on_dice_roll_finished(rolled_value: int) -> void:
	_queue_step_movement(rolled_value)

func advance_steps(steps: int) -> void:
	_queue_step_movement(steps)

func _queue_step_movement(step_count: int) -> void:
	if step_count <= 0:
		return
	if place_number == 0:
		return
	if place >= place_number:
		place = 0
	# block mid-jump
	if is_jumping or remaining_steps > 0:
		return
	remaining_steps = step_count
	pawn_landed = false
	_start_next_jump()

func _start_next_jump() -> void:
	current_jump_target_index = place					# remember where we’re going
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

			# advance place for the NEXT step/turn
			place = (place + 1) % place_number

			remaining_steps -= 1
			if remaining_steps > 0:
				_start_next_jump()
			else:
				pawn_landed = true
				# emit the spot we actually landed on this turn
				var landed_spot: Marker3D = game_spaces[current_jump_target_index]
				emit_signal("pawn_finished_moving", landed_spot)

		# parabolic interpolation
		var t := jump_t
		var pos := jump_start.lerp(jump_end, t)
		var height := 10.0
		var arc := 4.0 * height * t * (1.0 - t)
		pos.y += arc
		pawn.global_position = pos

func _on_pawn_finished_moving(_landed_spot: Node) -> void:
	var vfx = preload("res://Assets/Vfx/PawnLandingVfx.tscn").instantiate()
	get_tree().current_scene.add_child(vfx)
	vfx.global_position = global_position   # pawn position
	print("vfx")
