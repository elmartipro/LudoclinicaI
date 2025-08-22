extends Node3D

@export var assets : Array[PackedScene] = [
	preload("res://Assets/Podium/pA.tscn"),
	preload("res://Assets/Podium/pB.tscn"),
	preload("res://Assets/Podium/pC.tscn"),
	preload("res://Assets/Podium/pD.tscn"),
	preload("res://Assets/Podium/pE.tscn"),
	preload("res://Assets/Podium/pF.tscn"),
	preload("res://Assets/Podium/pG.tscn"),
	preload("res://Assets/Podium/pH.tscn")
]

var podiums : Array[PackedScene] = []

func _ready() -> void:
	if assets.is_empty():
		return
	var random_index = randi() % assets.size()
	var instance = assets[random_index].instantiate()
	add_child(instance)
