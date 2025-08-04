extends Node

@onready var pawn : CharacterBody3D = $Player
@export var game_spaces : Array[Marker3D] 

var place : int = 0
var number_places : int = 3

func _ready() -> void:
	number_places = game_spaces.size()

func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("LeftClick") and place <= number_places:
		var tween = create_tween()
		tween.tween_property(pawn, "position" , game_spaces[place].position, .5)
		place += 1
	elif place >= number_places:
		place = 0

func _on_dice_roll_finished(value: Variant) -> void:
	print(value)
