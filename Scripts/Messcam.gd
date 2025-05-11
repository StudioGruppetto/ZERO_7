extends Sprite2D

@export var left_angle_deg := -45.0
@export var right_angle_deg := 45.0
@export var rotation_speed := 45.0  # degrees per second
@export var pause_duration := 3.0  # seconds to pause at ends

@export_node_path("Area2D") var detection_area_path
var detection_area: Area2D

# Visual feedback for camera status
@export var normal_color: Color = Color(1, 1, 1, 1)  # White/normal
@export var alert_color: Color = Color(1, 0.3, 0.3, 1)  # Red tint when detecting player

var rotating_right := true
var target_angle := 0.0
var is_paused := false
var is_alert := false

# Track detected objects
var detected_player: CharacterBody2D = null
var detected_toolbox: Area2D = null

signal player_detected(is_detected)
signal player_caught_in_toolbox()

func _ready():
	# Get reference to detection area
	if detection_area_path and has_node(detection_area_path):
		detection_area = get_node(detection_area_path)
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)
		detection_area.area_entered.connect(_on_detection_area_area_entered)
		detection_area.area_exited.connect(_on_detection_area_area_exited)
		print("Camera detection area connected successfully")
	else:
		push_error("Camera detection area not connected!")
	
	# Set initial rotation and target
	rotation_degrees = left_angle_deg
	target_angle = right_angle_deg
	
	# Start rotation sequence
	rotate_to_target()
	
	# Initialize appearance
	modulate = normal_color
	
	print("Camera controller initialized")

func rotate_to_target():
	is_paused = false

func _process(delta):
	if is_paused:
		return
		
	# Smoothly rotate toward target angle
	var step = rotation_speed * delta
	rotation_degrees = move_toward(rotation_degrees, target_angle, step)
	
	# Check if reached the target angle
	if abs(rotation_degrees - target_angle) <= 0.5:
		is_paused = true
		rotating_right = !rotating_right
		target_angle = rotating_right if right_angle_deg else left_angle_deg
		
		# Pause before continuing rotation
		await get_tree().create_timer(pause_duration).timeout
		
		# Check if we're still paused (could have been paused by game logic)
		if is_paused:
			rotate_to_target()

func _physics_process(_delta):
	# Check detection status each physics frame
	check_detection_status()

func _on_detection_area_body_entered(body):
	print("Camera detected body: ", body.name)
	
	if body.is_in_group("Player") or body.get_script().resource_path.find("Player") != -1:
		print("Camera is now seeing the player")
		detected_player = body
		check_detection_status()
		
		# Emit signal to notify player
		player_detected.emit(true)

func _on_detection_area_body_exited(body):
	if body == detected_player:
		print("Player left camera view")
		detected_player = null
		check_detection_status()
		
		# Emit signal to notify player
		player_detected.emit(false)

func _on_detection_area_area_entered(area):
	print("Camera detected area: ", area.name)
	
	if area.name.contains("Toolbox") or area.get_groups().has("Toolbox"):
		print("Camera is now seeing the toolbox area")
		detected_toolbox = area
		check_detection_status()

func _on_detection_area_area_exited(area):
	if area == detected_toolbox:
		print("Toolbox left camera view")
		detected_toolbox = null
		check_detection_status()

func check_detection_status():
	var alert_state = false
	
	# If we have a player reference and a toolbox reference
	if detected_player != null and detected_toolbox != null:
		# Check if player is inside toolbox
		var bodies_in_toolbox = detected_toolbox.get_overlapping_bodies()
		if bodies_in_toolbox.has(detected_player):
			print("Player caught hiding in toolbox!")
			alert_state = true
			is_paused = true  # Stop camera rotation
			player_caught_in_toolbox.emit()  # Signal that player was caught
		else:
			print("Camera sees player and toolbox, but player is not in toolbox")
			alert_state = true
	elif detected_player != null:
		print("Camera sees player (toolbox not in view)")
		alert_state = true
	elif detected_toolbox != null:
		print("Camera sees toolbox (no player)")
		# No alert for just seeing the toolbox
		alert_state = false
	else:
		alert_state = false
	
	# Update visual state if changed
	if alert_state != is_alert:
		is_alert = alert_state
		modulate = alert_color if is_alert else normal_color
		
		# Optional: Add animation or effect to show detection status
		if is_alert:
			# Make camera pulse or flash when alerted
			var tween = create_tween()
			tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.2)
			tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
			print("Camera alerted!")
		else:
			print("Camera returned to normal state")

# Public function to forcibly pause/resume camera
func set_paused(paused: bool):
	is_paused = paused
	
	if not paused:
		rotate_to_target()
