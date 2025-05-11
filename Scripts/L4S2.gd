extends Node2D

@onready var camera_2d = $Walll/Player/Camera2D
@export var fade_duration: float = 1.0

var fade_overlay: ColorRect

func _ready():
	# Set camera limits
	camera_2d.limit_left = 0
	camera_2d.limit_top = 0
	camera_2d.limit_right = 3600
	camera_2d.limit_bottom = 1100
	
	# Create the fade overlay
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
	
	fade_overlay.visible = false  # Only show when fading

func _on_next_scene_body_entered(body):
	if body.is_in_group("Player"):
		change_scene_with_fade("res://Scenes/L4S3.tscn")

func change_scene_with_fade(scene_path: String):
	fade_overlay.visible = true
	
	var fade_in_tween = create_tween()
	fade_in_tween.set_ease(Tween.EASE_IN)
	fade_in_tween.set_trans(Tween.TRANS_CUBIC)
	fade_in_tween.tween_property(fade_overlay, "color", Color(0, 0, 0, 1), fade_duration)
	
	await fade_in_tween.finished
	
	get_tree().change_scene_to_file(scene_path)
