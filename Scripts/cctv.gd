extends Sprite2D

@export var left_angle_deg := -45.0
@export var right_angle_deg := 45.0
@export var rotation_speed := 45.0  # degrees per second
@export var pause_duration := 3.0  # seconds to pause at ends

var rotating_right := true
var target_angle := 0.0
var is_paused := false

func _ready():
	# Start at the left angle and move toward the right angle.
	rotation_degrees = left_angle_deg
	target_angle = right_angle_deg
	rotate_to_target()

func rotate_to_target():
	# Reset pause flag for each rotation cycle.
	is_paused = false

func _process(delta):
	if is_paused:
		return

	# Move rotation gradually toward the target angle.
	var step = rotation_speed * delta
	rotation_degrees = move_toward(rotation_degrees, target_angle, step)

	# Check if the sprite is approximately at the target angle.
	if abs(rotation_degrees - target_angle) <= 0.5:
		# Once at the target, pause, flip direction, and set the next target.
		is_paused = true
		rotating_right = !rotating_right
		target_angle = right_angle_deg if rotating_right else left_angle_deg

		# Wait for the pause duration before continuing rotation.
		await get_tree().create_timer(pause_duration).timeout
		rotate_to_target()
