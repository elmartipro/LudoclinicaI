extends RigidBody3D

@onready var raycasts = $Raycasts.get_children()
@onready var pawn := $"../Player"
@onready var collision_sound: AudioStreamPlayer = $AudioStreamPlayer

var start_pos
var roll_strength = 20
var is_rolling = false
var centering = false
var rolled_value : int = 0
var can_emit = false
var min_collision_force =  0.1  #Minimum force needed to play sound

signal roll_finished(rolled_value)

func _ready() -> void:
	start_pos = global_position
	randomize()
	contact_monitor = true
	max_contacts_reported = 10
	
	# Debug: Check if audio is properly configured
	if collision_sound == null:
		print("ERROR: CollisionSound node not found!")
	elif collision_sound.stream == null:
		print("ERROR: No audio stream assigned to CollisionSound!")
	else:
		print("Audio setup OK - Stream: ", collision_sound.stream)
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
	centering = true
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
	if sleeping && centering:
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
	centering = false
	is_rolling = false
	if position == start_pos and can_emit == true:
		emit_signal("roll_finished", rolled_value)
		can_emit = false
		print("roll finished")

func _integrate_forces(state):
	if is_rolling:
		set_sleeping(false)  # Prevent sleeping during rolls
	
	if state.get_contact_count() > 0:
		# Calculate collision force/velocity to avoid playing sound on tiny contacts
		var collision_force = linear_velocity.length()
		
		print("Contacts detected: ", state.get_contact_count(), " Force: ", collision_force)
		
		# Only play if force is significant and sound isn't already playing
		if collision_force > min_collision_force and not collision_sound.playing:
			print("Playing collision sound - Force: ", collision_force)

			var start_time := 0.32
			var end_time := 0.52
			var play_duration := end_time - start_time
			
			collision_sound.play(start_time)  # start from 0.32
			
			# Schedule stop after 0.2 seconds
			await get_tree().create_timer(play_duration).timeout
			if collision_sound.playing:
				collision_sound.stop()
