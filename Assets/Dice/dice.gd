extends RigidBody3D

@onready var raycasts = $Raycasts.get_children()
@onready var pawn := $"../Player"
@onready var collision_sound: AudioStreamPlayer = $"Dice sound"
@onready var preguntas_panel = $"../PreguntasPanel" # reference to the question panel

var start_pos
var roll_strength = 20
var is_rolling = false
var centering = false
var rolled_value : int = 0
var can_emit = false
var min_collision_force = 3.5  # Minimum force needed to play sound

var can_roll: bool = true  # NEW flag to control if dice can roll

signal roll_finished(rolled_value)

func _ready() -> void:
	start_pos = global_position
	randomize()
	contact_monitor = true
	max_contacts_reported = 10

	if preguntas_panel:
		preguntas_panel.panel_closed.connect(_on_panel_closed)
		preguntas_panel.panel_opened.connect(lock_roll)  # lock when question open

	# Debug: Check if audio is properly configured
	if collision_sound == null:
		print("ERROR: CollisionSound node not found!")
	elif collision_sound.stream == null:
		print("ERROR: No audio stream assigned to CollisionSound!")
	else:
		print("Audio setup OK - Stream: ", collision_sound.stream)

func _input(event):
	if event.is_action_released("LeftClick") \
	&& global_position.distance_to(start_pos) < 4 \
	&& !is_rolling \
	&& pawn.pawn_landed == true \
	&& can_roll:   # <-- only roll if allowed
		rolled_value = 0
		_roll()

func _roll():
		# Reset state
		is_rolling = true
		set_sleeping(false)
		freeze = false
		can_emit = true
		centering = true
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO

		if Engine.has_singleton("SFX") and SFX.has_method("play_dice_throw"):
				SFX.play_dice_throw()

		# Random initial rotation
		var axis = Vector3(randf(), randf(), randf()).normalized()
		var angle = randf_range(0, TAU)
		self.set_transform(Transform3D(Basis(axis, angle), global_position))
	set_sleeping(false)  # Force wake AFTER changing transform

	# Random throw
	var throw_vector = Vector3(randf_range(-1,1), randf(), randf_range(-1,1)).normalized()
	angular_velocity = throw_vector * roll_strength / 1.5
	apply_central_impulse(throw_vector * roll_strength)

# Dice stopped (before tween)
func _on_sleeping_state_changed() -> void:
	if sleeping and centering:
		var landed_on_side = false
		for raycast in raycasts:
			if raycast.is_colliding():
				rolled_value = raycast.opposite_side
				landed_on_side = true
		# If stopped but not landed properly, reroll
		if !landed_on_side:
			_roll()
			return
		# Tween back, then up and down once landed
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
		var collision_force = linear_velocity.length()
		if collision_force > min_collision_force and not collision_sound.playing:
			# 🔥 Calculate pitch scale inversely proportional to force
			# Example: force 3.5 → pitch ~1.0, force very high → pitch ~0.6
			var pitch = clamp(1.2 - (collision_force * 0.05), 0.6, 1.2)
			collision_sound.pitch_scale = pitch

			# Play only part of the sound
			var start_time := 0.32
			var end_time := 0.42
			var play_duration := end_time - start_time
			collision_sound.play(start_time)
			
			await get_tree().create_timer(play_duration).timeout
			if collision_sound.playing:
				collision_sound.stop()


# --- NEW FUNCTIONS ---

# Called externally by PreguntasPanel when it shows
func lock_roll():
	can_roll = false

# Called when the panel closes
func _on_panel_closed():
	can_roll = true
