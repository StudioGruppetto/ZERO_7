extends Area2D

@export_category("Top Floor Guard")
@export var top_floor_guard: NodePath = NodePath("../TopFloorGuard")
@export var top_guard_leave_time: float = 3.0
@export var top_guard_move_distance: float = 500.0
@export var top_guard_move_speed: float = 2.0
@export var patrol_distance: float = 100.0  # How far the guard patrols left/right
@export var patrol_speed: float = 1.0      # Patrol movement speed

var top_guard_leave_timer: Timer
var is_player_in_area: bool = false
var original_position: Vector2
var patrol_target_position: Vector2
var is_patrolling_right: bool = true
var animated_sprite: AnimatedSprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	top_guard_leave_timer = Timer.new()
	add_child(top_guard_leave_timer)
	top_guard_leave_timer.one_shot = true
	top_guard_leave_timer.timeout.connect(_on_top_guard_leave_timer_timeout)
	
	add_to_group("hiding_box")
	
	# Store original position when game starts
	var guard = _get_guard()
	if guard:
		original_position = guard.global_position
		patrol_target_position = original_position + Vector2(patrol_distance, 0)
		set_process(true)  # Enable _process for patrolling
		
		# Get the AnimatedSprite2D from the guard
		animated_sprite = guard.get_node("AnimatedSprite2D")
		if !animated_sprite:
			print("Warning: AnimatedSprite2D not found in guard node")

func _process(delta):
	if !is_player_in_area:
		_patrol_guard()

func _patrol_guard():
	var guard = _get_guard()
	if guard:
		# Move toward current target position
		var direction = (patrol_target_position - guard.global_position).normalized()
		guard.global_position += direction * patrol_speed
		
		# Flip sprite based on movement direction
		if animated_sprite:
			animated_sprite.flip_h = direction.x < 0
		
		# If close to target, switch direction
		if guard.global_position.distance_to(patrol_target_position) < 5:
			is_patrolling_right = !is_patrolling_right
			if is_patrolling_right:
				patrol_target_position = original_position + Vector2(patrol_distance, 0)
			else:
				patrol_target_position = original_position - Vector2(patrol_distance, 0)

func _get_guard() -> Node2D:
	if top_floor_guard.is_empty() or not has_node(top_floor_guard):
		print("Top Floor: Guard not found at path: ", top_floor_guard)
		return null
	return get_node(top_floor_guard)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player") and is_in_group("top_floor"):
		is_player_in_area = true
		Global.player_in_top_hiding_area = true
		top_guard_leave_timer.wait_time = top_guard_leave_time
		top_guard_leave_timer.start()
		print("Player detected - guard will leave in ", top_guard_leave_time, " seconds")

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player") and is_in_group("top_floor"):
		is_player_in_area = false
		Global.player_in_top_hiding_area = false
		if top_guard_leave_timer.time_left > 0:
			top_guard_leave_timer.stop()
			var guard_node = _get_guard()
			if guard_node and guard_node.has_method("catch_player"):
				print("Player exited too early - guard caught them!")
				guard_node.catch_player()
				guard_node.global_position = body.global_position

func _on_top_guard_leave_timer_timeout() -> void:
	print("Guard leave timer timeout!")
	_make_guard_leave()

func _make_guard_leave() -> void:
	var guard_node = _get_guard()
	if guard_node:
		print("Making guard leave the scene")
		
		# Flip sprite to face left when leaving
		if animated_sprite:
			animated_sprite.flip_h = true
		
		# Calculate target position (left of screen)
		var target_position = guard_node.global_position - Vector2(top_guard_move_distance, 0)
		
		var leave_tween = create_tween()
		leave_tween.tween_property(guard_node, "global_position", target_position, top_guard_move_speed)
		leave_tween.tween_callback(func(): 
			print("Guard deleted")
			guard_node.queue_free()
		)

func _on_player_position_changer_body_entered(body):
	if body.is_in_group("Player"):
		body.global_position = Vector2(38, 907)
