extends CharacterBody2D

@export var stop_area: Area2D

const SPEED = 100.0
var start_position: Vector2
var move_enabled = false
var waiting = false
var returning = false

func _ready():
	start_position = global_position
	await get_tree().create_timer(5.0).timeout
	move_enabled = true

	# Connect the signal from the exported Area2D
	if stop_area:
		stop_area.body_entered.connect(_on_area_2d_body_entered)

func _physics_process(delta):
	if move_enabled:
		velocity.x = -SPEED
	elif waiting:
		velocity.x = 0
	elif returning:
		var direction = (start_position - global_position).normalized()
		velocity = direction * SPEED

		if global_position.distance_to(start_position) < 5.0:
			velocity = Vector2.ZERO
			returning = false

	move_and_slide()

func _on_area_2d_body_entered(body):
	if body == self:
		move_enabled = false
		waiting = true
		await get_tree().create_timer(10.0).timeout
		waiting = false
		returning = true
