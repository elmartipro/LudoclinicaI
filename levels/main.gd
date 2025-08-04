extends Node

@onready var pawn : CharacterBody3D = $Player #Pawn is Player
@export var game_spaces : Array[Marker3D] #Gamespaces as the collection of spots.

var place : int = 0 #Initial place
var place_number : int #init place number

#Jump Animation
var is_jumping = false
var jump_t = 0.0
var jump_duration = 0.4
var jump_start : Vector3
var jump_end : Vector3

func _ready() -> void:
	place_number = game_spaces.size() 

func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("LeftClick") and !is_jumping:
		if (place >= place_number):
			place = 0
		jump_start = pawn.global_position
		jump_end = game_spaces[place].global_position
		jump_t = 0.0
		is_jumping = true
		place += 1
		

func _process(delta):
	print(1 / delta) #FPS Counter
	
	if is_jumping:
		jump_t += delta / jump_duration
		if jump_t >= 1.0:
			jump_t = 1.0
			is_jumping = false
		
		var t = jump_t
		var pos = jump_start.lerp(jump_end, t)
		
		# Add parabolic arc to the Y axis
		var height = 10.0  # ← tweak this to make it arc higher
		var arc = 4 * height * t * (1 - t)  # This is the parabola: 0 → 1 → 0
		pos.y += arc

		pawn.global_position = pos


func _on_dice_roll_finished(value: Variant) -> void:
	print(value)
	
