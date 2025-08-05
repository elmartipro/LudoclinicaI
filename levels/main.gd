extends Node

@onready var pawn : CharacterBody3D = $Player #Pawn is Player
@onready var dice := $Dice
@export var game_spaces : Array[Marker3D] #Gamespaces as the collection of spots.

var place : int = 0 #Initial place
var place_number : int #init place number
var remaining_steps : int = 0

#Jump Animation Variables
var is_jumping = false
var jump_t = 0.0
var jump_duration = 0.4
var jump_start : Vector3
var jump_end : Vector3

func _ready() -> void:
	place_number = game_spaces.size() 
	dice.roll_finished.connect(_on_dice_roll_finished)

func _on_dice_roll_finished(rolled_value : int) -> void:
	#Reset places once final place is reached
	if place >= place_number:
		place = 0
	
	# Prevent mid-jump restarts or multiple signals
	if is_jumping or remaining_steps > 0:
		return 
	
	remaining_steps = rolled_value
	_start_next_jump()

func _start_next_jump():
	if place >= place_number:
		place = 0
	jump_start = pawn.global_position
	jump_end = game_spaces[place].global_position
	jump_t = 0.0
	is_jumping = true

func _process(delta):
	#print(1 / delta) #FPS Counter
	
	if is_jumping:
		jump_t += delta / jump_duration
		if jump_t >= 1.0:
			jump_t = 1.0
			is_jumping = false
			pawn.global_position = jump_end
			place += 1
			if place >= place_number:
				place = 0
			remaining_steps -= 1
			if remaining_steps > 0:
				_start_next_jump()

		var t = jump_t
		var pos = jump_start.lerp(jump_end, t)

		# Parabolic arc
		var height = 10.0
		var arc = 4 * height * t * (1 - t)
		pos.y += arc

		pawn.global_position = pos
