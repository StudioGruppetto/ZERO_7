extends CharacterBody2D

@export var speed = 120
@onready var anim = $AnimatedSprite2D

func _physics_process(delta):
	var input = Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)

	velocity = input.normalized() * speed
	move_and_slide()

	if input != Vector2.ZERO:
		if abs(input.x) > abs(input.y):
			anim.play("walk_right" if input.x > 0 else "walk_left")
		else:
			anim.play("walk_down" if input.y > 0 else "walk_up")
	else:
		anim.play("idle")
