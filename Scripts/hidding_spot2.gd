extends Area2D

# Reference to the guard
@export var guard: NodePath = "../BottomFloorGuard"

# Timer for guard to leave
var guard_leave_timer: Timer

func _ready() -> void:
	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Create and set up timer
	guard_leave_timer = Timer.new()
	add_child(guard_leave_timer)
	guard_leave_timer.one_shot = true
	guard_leave_timer.wait_time = 5.0  # Bottom floor waits 5 seconds
	guard_leave_timer.timeout.connect(_on_guard_leave_timer_timeout)
	
	# Add to group for easy reference
	add_to_group("hiding_box")
	add_to_group("bottom_floor")
	
	print("Bottom Floor Hiding Box initialized")

# Get the guard node
func _get_guard() -> Node2D:
	if guard.is_empty() or not has_node(guard):
		print("Bottom Floor: Guard not found at path: ", guard)
		return null
		
	return get_node(guard)

# Called when a body enters the hiding area
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		print("Player entered BOTTOM floor hiding area")
		
		# Set global variable when player enters hiding area
		Global.player_in_hiding_area = true
		Global.bottom_floor_guard_leaving_timer_active = true
		
		# Start timer for guard to leave
		guard_leave_timer.start()
		print("Bottom floor guard leave timer started: 5 seconds")

# Called when a body exits the hiding area
func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		print("Player exited BOTTOM floor hiding area")
		
		# Update global variable when player exits hiding area
		Global.player_in_hiding_area = false
		
		# If timer is still active, player is caught!
		if Global.bottom_floor_guard_leaving_timer_active:
			var guard_node = _get_guard()
			if guard_node and guard_node.has_method("catch_player"):
				print("Player exited bottom floor too early - guard caught them!")
				guard_node.catch_player()
				guard_node.global_position = body.global_position
		
		# Force player to unhide when leaving area
		if Global.player_is_hidden:
			Global.player_is_hidden = false

# Timer to make guard leave after player enters hiding area
func _on_guard_leave_timer_timeout() -> void:
	print("Bottom floor guard leave timer timeout!")
	Global.bottom_floor_guard_leaving_timer_active = false
	
	# Find guard node and make it leave
	var guard_node = _get_guard()
	if guard_node:
		print("Making bottom floor guard leave")
		
		# Calculate target position (move right)
		var target_position = guard_node.global_position + Vector2(500, 0)
		
		# Create tween for movement
		var leave_tween = create_tween()
		leave_tween.tween_property(guard_node, "global_position", target_position, 2.0)
		leave_tween.tween_callback(func(): 
			print("Bottom floor guard deleted")
			guard_node.queue_free()
		)
	else:
		print("No bottom floor guard found to make leave")
