extends Node2D

@onready var camera_2d = $Player/Camera2D
@export var guard : NodePath  # Exported variable to link the guard node
@export var hide_time : float = 3.0  # Time in seconds before changing the scene
@export var fade_duration: float = 1.0

# Assuming the guard has a reference to its own path or movement logic
var is_hiding : bool = false
var hide_timer : Timer
var fade_overlay : ColorRect

func _ready():
	# For example, if your level is 2000x1000 pixels
	camera_2d.limit_left = 0
	camera_2d.limit_top = 0
	camera_2d.limit_right = 3500
	camera_2d.limit_bottom = 1100
	
	# Set up the timer for scene change
	hide_timer = Timer.new()
	hide_timer.wait_time = hide_time
	hide_timer.one_shot = true
	
	# Connect the timeout signal using a callable
	hide_timer.timeout.connect(self._on_hide_timeout)
	
	add_child(hide_timer)
	
	# Set up the fade overlay
	create_fade_overlay()

func create_fade_overlay():
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color(0, 0, 0, 0)  # Start transparent
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var viewport_size = get_viewport_rect().size
	fade_overlay.size = viewport_size
	fade_overlay.global_position = Vector2.ZERO
	
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	add_child(canvas_layer)
	canvas_layer.add_child(fade_overlay)

	fade_overlay.visible = false  # Initially invisible

func _on_hide_behind_body_entered(body):
	if body.is_in_group("Player"):
		# Hide the player and set flag
		body.z_index = -1
		is_hiding = true
		
		# Start the timer to change the scene
		hide_timer.start()

		# Move the guard closer to the hiding position (you can customize this part)
		guard_approach_cover()

func guard_approach_cover():
	# Example logic for the guard to move toward the cover position
	if guard:
		var guard_node = get_node(guard)
		# You could use a path or any movement logic here to move the guard towards the cover
		guard_node.position = position  # Assuming `position` is the cover's position

func _on_hide_timeout():
	# Fade out and then change the scene
	change_scene_with_fade()

func change_scene_with_fade():
	# Make the fade overlay visible
	fade_overlay.visible = true
	
	# Fade to black
	var fade_in_tween = create_tween()
	fade_in_tween.set_ease(Tween.EASE_IN)
	fade_in_tween.set_trans(Tween.TRANS_CUBIC)
	fade_in_tween.tween_property(fade_overlay, "color", Color(0, 0, 0, 1), fade_duration)
	
	# Wait for the fade-in to complete
	await fade_in_tween.finished
	
	# Change the scene after the fade-out
	get_tree().change_scene_to_file("res://Scenes/L4S2.tscn")
