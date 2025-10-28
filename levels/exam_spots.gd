extends Node3D

signal category_reached(category: String)
signal podium_cleared(index: int)

var category_scenes: Dictionary = {
	"Epidemiología": preload("res://Assets/Podium/pA.tscn"),
	"Fisiopatología": preload("res://Assets/Podium/pB.tscn"),
	"Manifestaciones clínicas y paraclínicas": preload("res://Assets/Podium/pC.tscn"),
	"Diagnóstico diferencial": preload("res://Assets/Podium/pD.tscn"),
	"Tratamiento": preload("res://Assets/Podium/pE.tscn"),
	"Seguimiento": preload("res://Assets/Podium/pF.tscn"),
	"Cultura": preload("res://Assets/Podium/pG.tscn"),
	"Health": preload("res://Assets/Podium/pH.tscn")
}

var assigned_categories: Dictionary = {}

func populate_podiums(sequence: Array[String]) -> void:
	assigned_categories.clear()
	var children: Array = get_children()
	for child in children:
		if child is Node3D:
			_clear_spot(child)
	var limit: int = min(sequence.size(), children.size())
	for i in range(limit):
		_spawn_podium(i, sequence[i])

func assign_category_to_spot(index: int, category: String) -> void:
	_spawn_podium(index, category)

func handle_landing(index: int, _landed_spot: Node) -> String:
	if not assigned_categories.has(index):
		return ""
	var info: Dictionary = assigned_categories[index]
	var category: String = info.get("category", "")
	if category != "":
		category_reached.emit(category)
	return category

func remove_podium_from_spot(index: int) -> void:
	if not assigned_categories.has(index):
		return
	var info: Dictionary = assigned_categories[index]
	var podium: Node = info.get("node")
	assigned_categories.erase(index)
	if podium == null:
		podium_cleared.emit(index)
		return
	if not is_instance_valid(podium):
		podium_cleared.emit(index)
		return
	var tween: Tween = create_tween()
	tween.tween_property(podium, "scale", Vector3.ZERO, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		if is_instance_valid(podium):
			podium.queue_free()
		podium_cleared.emit(index)
	)

func _spawn_podium(index: int, category: String) -> void:
	var spot: Node3D = _get_spot(index)
	if spot == null:
		return
	_clear_spot(spot)
	if not category_scenes.has(category):
		return
	var podium: Node3D = category_scenes[category].instantiate()
	spot.add_child(podium)
	podium.transform = Transform3D.IDENTITY
	podium.set_meta("category", category)
	podium.scale = Vector3.ONE
	assigned_categories[index] = {"category": category, "node": podium}

func _get_spot(index: int) -> Node3D:
	var children: Array = get_children()
	if index < 0 or index >= children.size():
		return null
	var node: Node = children[index]
	return node if node is Node3D else null

func _clear_spot(spot: Node3D) -> void:
	for child in spot.get_children():
		if child.has_meta("category"):
			child.queue_free()
