extends Node3D

var podiums: Array[PackedScene] = [
	preload("res://Assets/Podium/pA.tscn"),
	preload("res://Assets/Podium/pB.tscn"),
	preload("res://Assets/Podium/pC.tscn"),
	preload("res://Assets/Podium/pD.tscn"),
	preload("res://Assets/Podium/pE.tscn"),
	preload("res://Assets/Podium/pF.tscn"),
	preload("res://Assets/Podium/pG.tscn"),
	preload("res://Assets/Podium/pH.tscn")
]

var category_map := {
	"pA": "Epidemiología",
	"pB": "Fisiopatología",
	"pC": "Manifestaciones clínicas y paraclínicas",
	"pD": "Diagnóstico diferencial",
	"pE": "Tratamiento",
	"pF": "Seguimiento",
	"pG": "Varios",
	"pH": "Varios"
}

func _ready() -> void:
	var last_scene: PackedScene = null
	for spot in get_children():
		if spot is Node3D:
			var scene := _get_random_scene(last_scene)
			var podium := scene.instantiate()
			spot.add_child(podium)

			var fname := scene.resource_path.get_file().get_basename()
			var category := _category_from_filename(fname)

			podium.set_meta("category", category)
			podium.name = fname + "_" + category
			podium.transform = Transform3D.IDENTITY
			last_scene = scene

	var pawn := get_node("../Player")
	if pawn:
		pawn.pawn_finished_moving.connect(_on_pawn_finished_moving)

func _get_random_scene(last_scene: PackedScene) -> PackedScene:
	var scene := podiums[randi() % podiums.size()]
	while scene == last_scene:
		scene = podiums[randi() % podiums.size()]
	return scene

func _category_from_filename(fname: String) -> String:
	return category_map.get(fname, "Varios")

func _on_pawn_finished_moving(landed_spot: Node) -> void:
	# podium should be the first child; if not, scan for meta
	var podium: Node = null
	if landed_spot.get_child_count() > 0 and landed_spot.get_child(0).has_meta("category"):
		podium = landed_spot.get_child(0)
	else:
		for child in landed_spot.get_children():
			if child.has_meta("category"):
				podium = child
				break
	if podium:
		var category: String = podium.get_meta("category")
		var panel := $"../PreguntasPanel"
		panel.mostrar_pregunta_de_categoria(category)
