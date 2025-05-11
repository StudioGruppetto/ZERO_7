extends CharacterBody2D

# Guard properties
@export var detection_range: float = 100.0
@export var move_speed: float = 100.0
@export var detection_area: Area2D
@export var detection_trigger_area: Area2D  # Area2D for instant game over
@export var patrol_distance: float = 200.0  # Total patrol range

# Nodes
@onready var animated_sprite_2d = $AnimatedSprite2D

# Patrol
var start_position: Vector2
var patrol_direction: int = 1  # 1 = right, -1 = left

# Guard state
var is_leaving: bool = false
var leave_timer: Timer = null
var is_chasing_target: bool = false
var target_position: Vector2 = Vector2.ZERO
var target_node: Node2D = null  # NEW: Track the target node

func _ready() -> void:
	add_to_group("guard")

	start_position = global_position
	animated_sprite_2d.flip_h = patrol_direction < 0
	update_guard_position()

	# Connect hiding area
	var hiding_area = get_node_or_null("../Box2/Hidding spot")
	if hiding_area and hiding_area is Area2D:
		hiding_area.body_exited.connect(_on_hiding_area_body_exited)

	# Connect detection trigger area
	if detection_trigger_area:
		detection_trigger_area.body_entered.connect(_on_detection_trigger_body_entered)

	# Leave timer setup
	leave_timer = Timer.new()
	add_child(leave_timer)
	leave_timer.timeout.connect(_on_leave_timer_timeout)
	leave_timer.start(10.0)  # Adjust as needed

func _physics_process(delta: float) -> void:
	if Global.guard_caught_player:
		return

	if is_leaving:
		position.x -= move_speed * delta
		return

	if is_chasing_target:
		chase_target(delta)
		return

	patrol(delta)
	update_guard_position()
	check_for_player()

func patrol(delta: float) -> void:
	position.x += move_speed * delta * patrol_direction
	var distance_from_start = position.x - start_position.x

	if abs(distance_from_start) >= patrol_distance:
		patrol_direction *= -1  # Reverse direction
		animated_sprite_2d.flip_h = patrol_direction < 0  # Flip sprite

func _on_leave_timer_timeout() -> void:
	if not Global.guard_caught_player:
		is_leaving = true
		print("Guard is leaving - moving off screen")

func check_for_player() -> void:
	if Global.guard_caught_player:
		return

	if not Global.player_in_hiding_area or not can_hide_from_guard():
		var player = get_tree().get_first_node_in_group("Player")
		if player:
			var distance = global_position.distance_to(player.global_position)
			if distance < detection_range and not Global.player_is_hidden:
				catch_player()

func update_guard_position() -> void:
	var hiding_box = get_node_or_null("../Box2/Hidding spot")
	if hiding_box:
		if global_position.x < hiding_box.global_position.x:
			Global.guard_position = "left"
		else:
			Global.guard_position = "right"

func can_hide_from_guard() -> bool:
	return Global.guard_position == "left"

func catch_player() -> void:
	Global.guard_caught_player = true

	if leave_timer and leave_timer.time_left > 0:
		leave_timer.stop()

	var player = get_tree().get_first_node_in_group("Player")
	if player:
		# Face the player
		animated_sprite_2d.flip_h = (global_position.x - player.global_position.x) < 0
		if player.has_method("caught"):
			player.caught()

	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://game_over.tscn")

func _on_hiding_area_body_exited(body: Node) -> void:
	if body.is_in_group("Player") and not is_leaving and not Global.guard_caught_player:
		Global.player_in_hiding_area = false
		Global.player_is_hidden = false

		var player = get_tree().get_first_node_in_group("Player")
		if player:
			global_position = player.global_position
			animated_sprite_2d.flip_h = (global_position.x - player.global_position.x) < 0
			catch_player()

func _on_detection_trigger_body_entered(body: Node) -> void:
	if body.is_in_group("Player") and not Global.guard_caught_player:
		print("Player entered detection zone!")
		global_position = body.global_position
		animated_sprite_2d.flip_h = (global_position.x - body.global_position.x) < 0
		catch_player()

# === NEW: Move to a target node (e.g., bugget) and hide it when reached ===
func move_to_target(target: Node2D) -> void:
	is_chasing_target = true
	target_node = target
	target_position = target.global_position

func chase_target(delta: float) -> void:
	var direction = (target_position - global_position).normalized()
	global_position += direction * move_speed * delta
	animated_sprite_2d.flip_h = direction.x < 0

	if global_position.distance_to(target_position) < 5.0:
		is_chasing_target = false
		print("Guard reached target")

		if target_node and target_node.is_inside_tree():
			# Option 1: Hide the bugget visually
			target_node.visible = false

			# Option 2: Remove it from the scene
			# target_node.queue_free()

		target_node = null
