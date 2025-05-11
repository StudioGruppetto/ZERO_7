extends Area2D

@onready var collision_shape = $CollisionPolygon2D

func _ready():
	# Double safety check
	if not collision_shape:
		push_error("Tool missing collision shape!")
		queue_free()
		return
	
	add_to_group("Tools")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("Player"):
		body.tool_in_range = self

func _on_body_exited(body):
	if body.is_in_group("Player") and is_instance_valid(body) and body.tool_in_range == self:
		body.tool_in_range = null

func disable_collision():
	if collision_shape:
		collision_shape.disabled = true

func enable_collision():
	if collision_shape:
		collision_shape.disabled = false
