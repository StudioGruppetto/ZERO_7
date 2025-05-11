extends Node2D

@export var unlock_time: float = 5.0  # Time in seconds to unlock the door
@export var show_progress_bar: bool = true  # Whether to show a progress bar while unlocking
@export var slide_distance: float = 300.0  # How far the door slides (negative for left)
@export var slide_duration: float = 3.0  # How long the slide animation takes
@export var next_scene: String = "res://Scenes/L3S1.tscn"  # Path to the next scene to load
@export var fade_duration: float = 1.0  # Duration of fade transition
@export_color_no_alpha var locked_color: Color = Color(1, 0, 0, 1)  # Red when locked
@export_color_no_alpha var unlocked_color: Color = Color(0, 1, 0, 1)  # Green when unlocked

@onready var cell_gate = $Cellbg/CellGate
@onready var unlock_timer = $Cellbg/CellGate/UnlockTimer
@onready var progress_bar = $Cellbg/CellGate/ProgressBar
@onready var unlock_area = $Cellbg/CellGate/Unlock
@onready var status_light = $Cellbg/CellGate/Unlock/Indication

var is_unlocking: bool = false
var player_in_area: bool = false
var original_gate_position: Vector2
var fade_overlay: ColorRect

func _ready():
	# Store original position for reset capability
	original_gate_position = cell_gate.position
	
	# Initialize progress bar
	if show_progress_bar:
		progress_bar.max_value = unlock_time
		progress_bar.value = 0
		progress_bar.visible = false
	
	# Setup timer
	unlock_timer.wait_time = unlock_time
	unlock_timer.one_shot = true
	
	# Initialize status light color
	if status_light:
		status_light.color = locked_color
	
	# Create fade overlay for scene transitions
	create_fade_overlay()
	
	# Verify signal connections (this is just for reference - connect in editor!)
	if not unlock_timer.timeout.is_connected(_on_unlock_timer_timeout):
		unlock_timer.timeout.connect(_on_unlock_timer_timeout)
	if not unlock_area.body_entered.is_connected(_on_unlock_body_entered):
		unlock_area.body_entered.connect(_on_unlock_body_entered)
	if not unlock_area.body_exited.is_connected(_on_unlock_body_exited):
		unlock_area.body_exited.connect(_on_unlock_body_exited)

func _process(delta):
	if is_unlocking and show_progress_bar:
		progress_bar.value = unlock_time - unlock_timer.time_left

func _on_unlock_body_entered(body):
	if body.is_in_group("Player"):
		player_in_area = true
		start_unlock()

func _on_unlock_body_exited(body):
	if body.is_in_group("Player"):
		player_in_area = false
		cancel_unlock()

func start_unlock():
	if not is_unlocking:
		is_unlocking = true
		unlock_timer.start()
		
		if show_progress_bar:
			progress_bar.visible = true
			progress_bar.value = 0
		
		print("Started unlocking sequence")

func cancel_unlock():
	if is_unlocking:
		is_unlocking = false
		unlock_timer.stop()
		
		if show_progress_bar:
			progress_bar.visible = false
		
		print("Unlocking cancelled")

func _on_unlock_timer_timeout():
	print("Unlock timer completed - Player in area: ", player_in_area)
	if player_in_area:
		unlock_door()
	else:
		print("Player left before unlocking finished")

func unlock_door():
	is_unlocking = false
	
	if show_progress_bar:
		progress_bar.visible = false
	
	# Change status light to green (unlocked)
	if status_light:
		status_light.color = unlocked_color
	
	var target_position = original_gate_position + Vector2(-slide_distance, 0)
	
	# Create tween with smoother animation
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(cell_gate, "position", target_position, slide_duration)
	
	# Wait for door animation to complete before scene change
	await tween.finished
	
	# Disable collisions after opening
	unlock_area.monitoring = false
	
	print("Door unlocked successfully")
	
	# Change scene with fade effect if next_scene is specified
	if next_scene != "":
		change_scene_with_fade()

func create_fade_overlay():
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color(0, 0, 0, 0)  # Start transparent
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Make it cover the entire viewport
	var viewport_size = get_viewport_rect().size
	fade_overlay.size = viewport_size
	fade_overlay.global_position = Vector2.ZERO
	
	# Add to scene but make it a child of the CanvasLayer to ensure it stays on top
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100  # Very high layer to be on top
	add_child(canvas_layer)
	canvas_layer.add_child(fade_overlay)
	
	# Initially visible but transparent
	fade_overlay.visible = true

func change_scene_with_fade():
	# Ensure the fade overlay exists
	if not fade_overlay:
		create_fade_overlay()
	
	# Make sure it's visible
	fade_overlay.visible = true
	
	# Create fade-in tween
	var fade_in_tween = create_tween()
	fade_in_tween.set_ease(Tween.EASE_IN)
	fade_in_tween.set_trans(Tween.TRANS_CUBIC)
	fade_in_tween.tween_property(fade_overlay, "color", Color(0, 0, 0, 1), fade_duration)
	
	# Wait for fade-in to complete
	await fade_in_tween.finished
	
	# Change scene
	get_tree().change_scene_to_file(next_scene)
