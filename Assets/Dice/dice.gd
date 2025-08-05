extends RigidBody3D

@onready var raycasts = $Raycasts.get_children()
@onready var pawn := $"../Player"

var start_pos
var roll_strength = 20

var is_rolling = false
var rolled_value : int = 0

var can_emit = false
signal roll_finished(rolled_value)

func _ready() -> void:
	start_pos = global_position
	randomize()

func _input(event):
	if event.is_action_released("RightClick") \
	&& global_position.distance_to(start_pos) < 4\
	&& !is_rolling \
	&& pawn.pawn_landed == true:
		rolled_value = 0
		_roll()

func _roll():
	#Reset state
	is_rolling = true
	set_sleeping(false)
	freeze = false
	can_emit = true
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

		#tween back, then up and down once landed
		var tween = create_tween()
		tween.tween_property(self,"position", start_pos,.5)
		tween.finished.connect(_on_tween_finished)

func _on_tween_finished():
	is_rolling = false
	if position == start_pos and can_emit == true:
		emit_signal("roll_finished", rolled_value)
		can_emit = false
		print("roll finished")
