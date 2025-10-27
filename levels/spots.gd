extends Node3D

signal category_reached(category: String)
signal extra_life_awarded(total_lives: int)

var podiums: Array[PackedScene] = [
	preload("res://Assets/Podium/pA.tscn"),
	preload("res://Assets/Podium/pB.tscn"),
	preload("res://Assets/Podium/pC.tscn"),
	preload("res://Assets/Podium/pD.tscn"),
	preload("res://Assets/Podium/pE.tscn"),
	preload("res://Assets/Podium/pF.tscn"),
	preload("res://Assets/Podium/pG.tscn"),
	preload("res://Assets/Podium/pH.tscn") # Health
]

var category_map := {
	"pA": "Epidemiología",
	"pB": "Fisiopatología",
	"pC": "Manifestaciones clínicas y paraclínicas",
	"pD": "Diagnóstico diferencial",
	"pE": "Tratamiento",
	"pF": "Seguimiento",
	"pG": "Cultura",
	"pH": "Health"  
}

func _ready() -> void:
	var last_scene: PackedScene = null
	var spots = get_children()

	for i in range(spots.size()):
		var spot = spots[i]
		if spot is Node3D:
			var scene: PackedScene

			# 🔥 Spots 10 y 20 siempre son pH
			if i == 9:   # (porque el array empieza en 0 → spot 10 = index 9, spot 20 = index 19)
				scene = preload("res://Assets/Podium/pH.tscn")
			else:
				scene = _get_random_scene(last_scene, true)

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

# 🔥 Excluir Health en random normal
func _get_random_scene(last_scene: PackedScene, exclude_health: bool = false) -> PackedScene:
	var candidates = podiums.duplicate()
	if exclude_health:
		candidates.erase(preload("res://Assets/Podium/pH.tscn"))

	var scene: PackedScene = candidates[randi() % candidates.size()]
	while scene == last_scene:
		scene = candidates[randi() % candidates.size()]
	return scene


func _category_from_filename(fname: String) -> String:
	return category_map.get(fname, "Varios")

func _on_pawn_finished_moving(landed_spot: Node) -> void:
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

				# 🔥 Caso especial: Podio de vida extra
				if category == "Health":
						var preguntas_panel = $"../PreguntasPanel"
						if preguntas_panel:
								preguntas_panel.vidas += 1
								preguntas_panel._update_health_label()
								extra_life_awarded.emit(preguntas_panel.vidas)
						return

				# 🔥 Para cualquier otro podio → pregunta normal
				var panel := $"../PreguntasPanel"
				category_reached.emit(category)
				panel.mostrar_pregunta_de_categoria(category)
