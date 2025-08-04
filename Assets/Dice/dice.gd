extends RigidBody3D

@onready var raycasts = $Raycasts.get_children()

var start_pos
var roll_strength = 20

var is_rolling = false

var can_emit : bool = false
var rolled_value : int

signal roll_finished(value)

func _ready() -> void:
	start_pos = global_position

func _input(event):
	if event.is_action_released("RightClick") && !is_rolling:
		_roll()

func _roll():
	#Reset state
	set_sleeping(false)
	freeze = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	
	#Random initial rotation
	var axis = Vector3(randf(), randf(), randf()).normalized()
	var angle = randf_range(0, TAU)
	self.set_transform(Transform3D(Basis(axis, angle), global_position))
	set_sleeping(false)  # Force wake AFTER changing transform
	
	#Random throw
	var throw_vector = Vector3(randf_range(-1,1), randf(), randf_range(-1,1)).normalized()
	angular_velocity = throw_vector * roll_strength / 1.5
	apply_central_impulse(throw_vector * roll_strength)
	
	is_rolling = true
	can_emit = true

#Dice stopped (before tween)
func _on_sleeping_state_changed() -> void:
	if sleeping:
		var landed_on_side = false
		for raycast in raycasts:
			if raycast.is_colliding():
				rolled_value = raycast.opposite_side
				landed_on_side = true
		#is stopped but not landed
		if !landed_on_side:
			_roll()
			return
		#tween once landed
		var tween = create_tween()
		tween.tween_property($".","position", start_pos,.5)
		tween.finished.connect(_on_tween_finished)

func _on_tween_finished():
	is_rolling = false
	if position == start_pos && can_emit:
		print(rolled_value)
		can_emit = false
