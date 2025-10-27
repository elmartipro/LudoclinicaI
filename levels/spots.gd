extends Node3D

signal category_reached(category: String)
signal cycle_completed

var category_scene_map: Dictionary = {
	"Epidemiología": preload("res://Assets/Podium/pA.tscn"),
	"Fisiopatología": preload("res://Assets/Podium/pB.tscn"),
	"Manifestaciones clínicas y paraclínicas": preload("res://Assets/Podium/pC.tscn"),
	"Diagnóstico diferencial": preload("res://Assets/Podium/pD.tscn"),
	"Tratamiento": preload("res://Assets/Podium/pE.tscn"),
	"Seguimiento": preload("res://Assets/Podium/pF.tscn"),
	"Cultura": preload("res://Assets/Podium/pG.tscn")
}

var ordered_spots: Array[Marker3D] = []
var ordered_categories: Array[String] = []
var podium_nodes: Dictionary = {}
var spot_to_category: Dictionary = {}
var visited_spots: Dictionary = {}
var current_spot: Marker3D = null
var preguntas_panel: Node = null
var player: CharacterBody3D = null

func _ready() -> void:
	ordered_spots.clear()
	for child in get_children():
		if child is Marker3D:
			ordered_spots.append(child)
	ordered_categories = _build_category_sequence(ordered_spots.size())
	for i in range(ordered_spots.size()):
		var spot: Marker3D = ordered_spots[i]
		var category: String = ordered_categories[i]
		spot_to_category[spot] = category
		var podium_scene: PackedScene = category_scene_map.get(category)
		if podium_scene:
			var podium: Node3D = podium_scene.instantiate()
			spot.add_child(podium)
			podium.set_meta("category", category)
			podium.transform = Transform3D.IDENTITY
			podium_nodes[spot] = podium
		else:
			push_error("No se encontró escena de podio para la categoría: " + category)
	preguntas_panel = get_node_or_null("../PreguntasPanel")
	player = get_node_or_null("../Player")
	if player:
		player.pawn_finished_moving.connect(_on_pawn_finished_moving)

func _build_category_sequence(total: int) -> Array[String]:
	var base_order: Array[String] = [
		"Epidemiología",
		"Fisiopatología",
		"Manifestaciones clínicas y paraclínicas",
		"Diagnóstico diferencial",
		"Tratamiento",
		"Seguimiento",
		"Cultura"
	]
	var sequence: Array[String] = []
	if total <= 0:
		return sequence
	var index: int = 0
	while sequence.size() < total:
		sequence.append(base_order[index])
		index += 1
		if index >= base_order.size():
			index = 0
	return sequence

func _on_pawn_finished_moving(landed_spot: Marker3D) -> void:
	if visited_spots.has(landed_spot):
		if _all_spots_completed():
			cycle_completed.emit()
		return
	current_spot = landed_spot
	var category: String = spot_to_category.get(landed_spot, "")
	if category == "":
		return
	category_reached.emit(category)
	if preguntas_panel:
		preguntas_panel.call("mostrar_pregunta_de_categoria", category, landed_spot)

func clear_podium_for_spot(spot: Marker3D) -> void:
	if not spot:
		return
	if visited_spots.has(spot):
		return
	visited_spots[spot] = true
	if podium_nodes.has(spot):
		var podium: Node3D = podium_nodes[spot]
		var tween = create_tween()
		tween.tween_property(podium, "scale", Vector3.ZERO, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.finished.connect(func() -> void:
			if is_instance_valid(podium):
				podium.queue_free()
		)
		podium_nodes.erase(spot)
	if _all_spots_completed():
		cycle_completed.emit()

func get_total_spots() -> int:
	return ordered_spots.size()

func get_remaining_spots() -> int:
	return ordered_spots.size() - visited_spots.size()

func get_category_sequence() -> Array[String]:
	return ordered_categories.duplicate()

func _all_spots_completed() -> bool:
	return visited_spots.size() >= ordered_spots.size()
