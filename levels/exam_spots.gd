extends Node3D

signal category_reached(category: String)

const CATEGORY_SEQUENCE: Array[String] = [
	"Epidemiología",
	"Fisiopatología",
	"Manifestaciones clínicas y paraclínicas",
	"Diagnóstico diferencial",
	"Tratamiento",
	"Seguimiento",
	"Cultura"
]

var podium_scene_map: Dictionary = {
	"Epidemiología": preload("res://Assets/Podium/pA.tscn"),
	"Fisiopatología": preload("res://Assets/Podium/pB.tscn"),
	"Manifestaciones clínicas y paraclínicas": preload("res://Assets/Podium/pC.tscn"),
	"Diagnóstico diferencial": preload("res://Assets/Podium/pD.tscn"),
	"Tratamiento": preload("res://Assets/Podium/pE.tscn"),
	"Seguimiento": preload("res://Assets/Podium/pF.tscn"),
	"Cultura": preload("res://Assets/Podium/pG.tscn")
}

var last_landed_spot: Node3D = null
var last_category: String = ""

func _ready() -> void:
	_prepare_podiums()
	var pawn = get_node("../Player")
	if pawn != null:
		pawn.pawn_finished_moving.connect(_on_pawn_finished_moving)

func get_cycle_length() -> int:
	return CATEGORY_SEQUENCE.size()

func get_sequence() -> Array[String]:
	return CATEGORY_SEQUENCE.duplicate(true)


func get_last_category() -> String:
	return last_category
func _prepare_podiums() -> void:
	var spots = _get_spots()
	for i in range(min(CATEGORY_SEQUENCE.size(), spots.size())):
		var spot = spots[i]
		var category = CATEGORY_SEQUENCE[i]
		_place_podium(spot, category)

func _place_podium(spot: Node3D, category: String) -> void:
	if not podium_scene_map.has(category):
		return
	for child in spot.get_children():
		child.queue_free()
	var scene: PackedScene = podium_scene_map[category]
	var podium = scene.instantiate()
	spot.add_child(podium)
	podium.set_meta("category", category)
	podium.name = "%s_%s" % [scene.resource_path.get_file().get_basename(), category]
	podium.transform = Transform3D.IDENTITY

func discard_current_podium() -> void:
	if last_landed_spot == null:
		return
	var podium = _find_podium(last_landed_spot)
	if podium == null:
		return
	var tween = create_tween()
	tween.tween_property(podium, "scale", Vector3.ZERO, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		podium.queue_free()
	)

func _on_pawn_finished_moving(landed_spot: Marker3D) -> void:
	last_landed_spot = landed_spot
	var podium = _find_podium(landed_spot)
	if podium == null:
		return
	var category = podium.get_meta("category")
	last_category = category
	category_reached.emit(category)
	var panel = get_node("../PreguntasPanel")
	if panel != null and panel.has_method("mostrar_pregunta_de_categoria"):
		panel.mostrar_pregunta_de_categoria(category)

func _find_podium(spot: Node) -> Node:
	if spot == null:
		return null
	if spot.get_child_count() == 0:
		return null
	for child in spot.get_children():
		if child.has_meta("category"):
			return child
	return null

func _get_spots() -> Array:
	return get_children()
