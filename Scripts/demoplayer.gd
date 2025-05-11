extends CharacterBody2D

# Movement
const SPEED = 200.0
const JUMP_VELOCITY = -400.0
const AUTO_MOVE_DISTANCE = 1000.0

const GRAVITY = 980.0
var gravity_enabled := false

# Animation variables
@onready var animated_sprite = $AnimatedSprite2D
var facing_right = true
var is_walking = false

# State
var auto_move_enabled := false
var auto_move_direction := 1
var start_position_x := 0.0
var can_jump := true

# Tools
var has_tool := false
var tool_in_range = null
var current_tool = null
var dropped_tools = []  # Track dropped tools

# NEW: Export variable for tools in the scene
@export var scene_tools: Array[NodePath] = []

# Tool Drop Zone
@export_node_path("Area2D") var tool_drop_zone_path
var tool_drop_zone: Area2D

# Level completion indicator
@export var next_level_indicator: ColorRect
@export var next_level_area: Area2D
var is_blinking := false
var blink_time := 0.0
var blink_duration := 0.5
var blink_total_time := 3.0

# Scene transition
var transition_timer: Timer
var fade_overlay: ColorRect
var is_transitioning := false
const TRANSITION_DURATION := 2.0

# Camera System Properties
@export var left_angle_deg := -45.0
@export var right_angle_deg := 45.0
@export var rotation_speed := 45.0  # degrees per second
@export var pause_duration := 3.0  # seconds to pause at ends
@export_node_path("Area2D") var camera_area_path
@export_node_path("Area2D") var toolbox_area_path
@export_node_path("CharacterBody2D") var player_path

# Camera node reference
@export var surveillance_camera: Node2D

# Camera State
var rotating_right := true
var target_angle := 0.0
var is_paused := false
var camera_area: Area2D
var toolbox_area: Area2D
var player: CharacterBody2D
var player_in_camera_view := false
var toolbox_in_camera_view := false
var is_game_over := false
var tool_in_camera_view := false  # Track if any tool is in camera view

var can_proceed_to_next_level := false
var tool_pickup_successful := false
var attempting_pickup := false  # Flag to track if player is attempting to pick up a tool

# NEW: Track scene tools references
var available_scene_tools = []

func _ready():
	# Animation setup - check if the AnimatedSprite2D node exists
	if has_node("AnimatedSprite2D"):
		animated_sprite = $AnimatedSprite2D
		
		# Check if animations exist and play idle
		if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("idle"):
			animated_sprite.play("idle")
		else:
			push_error("Missing sprite_frames or 'idle' animation in AnimatedSprite2D")
	else:
		push_error("Critical: AnimatedSprite2D node missing! Add it to your player scene.")
	
	# Player setup
	add_to_group("tools")
	
	var current_scene = get_tree().current_scene.name
	if current_scene in ["L3S1"]:
		gravity_enabled = true
		print("Gravity enabled for scene: ", current_scene)
	
	if not has_node("Hand"):
		push_error("Critical: Hand node missing!")
		get_tree().quit()
	
	# NEW: Get references to all scene tools
	for tool_path in scene_tools:
		if has_node(tool_path):
			var tool_node = get_node(tool_path)
			available_scene_tools.append(tool_node)
			print("Found scene tool: ", tool_node.name)
			
			# Make sure it's in the tools group
			if not tool_node.is_in_group("tools"):
				tool_node.add_to_group("tools")
	
	# Setup transition timer
	transition_timer = Timer.new()
	transition_timer.one_shot = true
	transition_timer.wait_time = TRANSITION_DURATION
	transition_timer.timeout.connect(_on_transition_timer_timeout)
	add_child(transition_timer)
	
	# Setup fade overlay
	create_fade_overlay()
	
	# Connect the tool drop zone area
	setup_tool_drop_zone()
	
	# Camera system setup
	setup_camera_system()
	
	# Important: First initialize the next level area in the disabled state
	if next_level_indicator:
		next_level_indicator.visible = false
	
	if next_level_area:
		# Make sure we're connected to the signal
		if not next_level_area.body_entered.is_connected(_on_next_level_area_body_entered):
			next_level_area.body_entered.connect(_on_next_level_area_body_entered)
			
		# Initially disable it until we check the scene conditions
		next_level_area.process_mode = Node.PROCESS_MODE_DISABLED
		next_level_area.visible = false
	
	# Check current scene and give tool if needed
	var current_scene_name = get_tree().current_scene.name
	print("Current scene name: ", current_scene_name)
	
	if current_scene_name == "L2S1":
		print("This is the scene where the player should have a tool!")
		give_player_tool("Wrench")  # Or whatever tool you want to give
		
		# Fix: Make sure next level indicator starts blinking
		start_next_level_indicator()
		
		# Fix: Force enable the next level area with a small delay
		var t = Timer.new()
		t.wait_time = 0.1
		t.one_shot = true
		t.timeout.connect(func(): enable_next_level_area())
		add_child(t)
		t.start()
	# NEW: Add check for L2S2 scene
	elif current_scene_name == "L2S2":
		print("L2S2 scene - giving player a tool!")
		give_player_tool("Wrench")  # You can change this to any tool you want
		
		# Enable next level indicator and area
		start_next_level_indicator()
		
		# Force enable the next level area with a small delay
		var t = Timer.new()
		t.wait_time = 0.1
		t.one_shot = true
		t.timeout.connect(func(): enable_next_level_area())
		add_child(t)
		t.start()
	else:
		print("This scene does not need to give the player a tool")
		
	if has_ancestor_named("L1S1"):
		auto_move_enabled = true
		start_position_x = global_position.x

func setup_tool_drop_zone():
	# Get tool drop zone reference from exported path
	if tool_drop_zone_path and has_node(tool_drop_zone_path):
		tool_drop_zone = get_node(tool_drop_zone_path)
		print("Connected to tool drop zone: ", tool_drop_zone.name)
		
		# Connect signals for body entered/exited
		if not tool_drop_zone.body_entered.is_connected(_on_tool_drop_zone_body_entered):
			tool_drop_zone.body_entered.connect(_on_tool_drop_zone_body_entered)
		if not tool_drop_zone.body_exited.is_connected(_on_tool_drop_zone_body_exited):
			tool_drop_zone.body_exited.connect(_on_tool_drop_zone_body_exited)
	else:
		push_warning("Tool drop zone path not valid or not set! Tools will drop at current location.")

func setup_camera_system():
	# Get node references from exported paths
	if camera_area_path and has_node(camera_area_path):
		camera_area = get_node(camera_area_path)
		print("Connected to camera area: ", camera_area.name)
		
		# Connect signals for tool detection
		if not camera_area.area_entered.is_connected(_on_camera_detect_area_entered):
			camera_area.area_entered.connect(_on_camera_detect_area_entered)
		if not camera_area.body_entered.is_connected(_on_camera_detect_body_entered):
			camera_area.body_entered.connect(_on_camera_detect_body_entered)
	else:
		push_error("Camera area path not valid or not set!")
	
	if toolbox_area_path and has_node(toolbox_area_path):
		toolbox_area = get_node(toolbox_area_path)
		print("Connected to toolbox area: ", toolbox_area.name)
	else:
		push_error("Toolbox area path not valid or not set!")
	
	if player_path and has_node(player_path):
		player = get_node(player_path)
		print("Connected to player: ", player.name)
	else:
		# Default to self if no player path specified
		player = self
		print("Using self as player reference")
	
	# Check for surveillance camera node
	if not surveillance_camera:
		# Create camera node if not assigned
		surveillance_camera = Node2D.new()
		surveillance_camera.name = "SurveillanceCamera"
		add_child(surveillance_camera)
		print("Created new surveillance camera node")
	
	# Set initial rotation and target for the camera
	surveillance_camera.rotation_degrees = left_angle_deg
	target_angle = right_angle_deg
	
	# Start rotation sequence
	rotate_to_target()
	
	# Debug print to confirm connections
	print("Camera controller initialized")

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
	
	# Initially invisible
	fade_overlay.visible = false

func _physics_process(delta):
	handle_tool_interaction()
	
	if Global.guard_caught_player:
		game_over("You were caught by the guard!")
		return
	
	if gravity_enabled and not is_on_floor():
		velocity.y += GRAVITY * delta
	# NEW: Debug for listing available scene tools with the T key
	if Input.is_action_just_pressed("ui_focus_next"):  # Usually the Tab key
		print("DEBUG: Listing available scene tools")
		for tool_node in available_scene_tools:
			if is_instance_valid(tool_node):
				print("Scene tool: ", tool_node.name, " at position ", tool_node.global_position)
				var distance = global_position.distance_to(tool_node.global_position)
				print("Distance to player: ", distance)
	
	if Input.is_action_just_pressed("ui_accept"):  # Space bar typically
		print("DEBUG: Listing all tools in scene")
		var all_tools = get_tree().get_nodes_in_group("tools")
		print("Found ", all_tools.size(), " tools in the scene")
		for tool in all_tools:
			print("Tool: ", tool.name, " at position ", tool.global_position)
			var distance = global_position.distance_to(tool.global_position)
			print("Distance to player: ", distance)
		
		print("DEBUG: Listing dropped tools")
		print("Dropped tools count: ", dropped_tools.size())
		for tool in dropped_tools:
			if is_instance_valid(tool):
				print("Dropped tool: ", tool.name, " at position ", tool.global_position)
	
	if is_game_over:
		return
	
	if not is_transitioning:
		if auto_move_enabled:
			handle_auto_movement()
		else:
			handle_manual_movement()
			
		# Update animation based on current movement
		update_animation()
	
	if is_blinking and next_level_indicator:
		blink_time += delta
		var should_be_visible = int(blink_time / blink_duration) % 2 == 0
		next_level_indicator.visible = should_be_visible
		next_level_indicator.color = Color(0, 1, 0, 0.7)
		
		if blink_time >= blink_total_time:
			is_blinking = false
			next_level_indicator.visible = true
			if next_level_area and has_tool:
				# Only enable next level area if player has a tool
				next_level_area.process_mode = Node.PROCESS_MODE_INHERIT
				next_level_area.visible = true
				print("Next level area enabled")
			print("Blinking completed")
	
	# Handle fade transition animation
	if is_transitioning and fade_overlay:
		var progress = 1.0 - (transition_timer.time_left / TRANSITION_DURATION)
		fade_overlay.color = Color(0, 0, 0, min(progress, 1.0))
	
	# Handle camera rotation and detection
	handle_camera_system(delta)
	
	move_and_slide()

# New function to handle animation updates
func update_animation():
	# Check if we have a valid animated sprite
	if not is_instance_valid(animated_sprite):
		return
		
	# Determine if we're walking based on horizontal velocity
	is_walking = abs(velocity.x) > 1.0
	
	# Update sprite direction based on movement
	if velocity.x > 1.0:
		facing_right = true
		animated_sprite.flip_h = false
	elif velocity.x < -1.0:
		facing_right = false
		animated_sprite.flip_h = true
	
	# Play appropriate animation
	if is_walking:
		if animated_sprite.animation != "walk_right":
			animated_sprite.play("walk_right")
	else:
		if animated_sprite.animation != "idle":
			animated_sprite.play("idle")

func handle_camera_system(delta):
	if is_paused or not surveillance_camera:
		return
	
	# Smoothly rotate the camera toward target angle
	var step = rotation_speed * delta
	surveillance_camera.rotation_degrees = move_toward(surveillance_camera.rotation_degrees, target_angle, step)
	
	# Check if reached the target angle
	if abs(surveillance_camera.rotation_degrees - target_angle) <= 0.5:
		is_paused = true
		rotating_right = !rotating_right
		target_angle = right_angle_deg if rotating_right else left_angle_deg
		
		# Pause before continuing rotation
		await get_tree().create_timer(pause_duration).timeout
		rotate_to_target()
	
	# Only used as a backup detection method
	if not is_game_over:
		# Double check our state variables match reality
		if camera_area and player:
			player_in_camera_view = camera_area.get_overlapping_bodies().has(player)
		
		if camera_area and toolbox_area:
			toolbox_in_camera_view = camera_area.get_overlapping_areas().has(toolbox_area)
			
		# Check for tools in camera view
		tool_in_camera_view = false
		if camera_area:
			# Check if any dropped tools are in camera view
			for tool_node in dropped_tools:
				if is_instance_valid(tool_node) and camera_area.get_overlapping_bodies().has(tool_node):
					tool_in_camera_view = true
					break
			
			# NEW: Also check if any scene tools are in camera view
			for tool_node in available_scene_tools:
				if is_instance_valid(tool_node) and camera_area.get_overlapping_bodies().has(tool_node):
					tool_in_camera_view = true
					break
		
		# Check for caught conditions
		check_player_caught()

func rotate_to_target():
	is_paused = false

func handle_tool_interaction():
	if Input.is_action_just_pressed("pick_tool"):
		print("Pick tool action pressed")
		
		# If holding a tool, drop it regardless of location
		if has_tool:
			print("Dropping currently held tool")
			safe_drop_tool()
			return
			
		# Not holding a tool, check if there's one in range to pick up
		var potential_tool = find_nearest_tool()
		print("Potential tool found: ", potential_tool)
		
		if potential_tool:
			print("Setting tool_in_range to: ", potential_tool.name)
			tool_in_range = potential_tool
			
			# Set attempting pickup flag before checking camera status
			attempting_pickup = true
			
			# Check if player is in camera view during pickup attempt
			if player_in_camera_view:
				print("Player caught attempting to pick up tool while visible to camera!")
				game_over("You were caught trying to pick up a tool! Game Over.")
				attempting_pickup = false
				return
			
			# Check if tool is in camera view during pickup attempt
			if tool_in_camera_view:
				print("Tool is in camera view during pickup attempt!")
				game_over("You tried to pick up a tool that was visible to a camera! Game Over.")
				attempting_pickup = false
				return
				
			# If we got here, it's safe to pick up the tool
			safe_pick_up_tool()
			attempting_pickup = false
		else:
			print("No tool in range to pick up")

# Find the closest tool that can be picked up
func find_nearest_tool():
	var closest_tool = null
	var closest_distance = 50.0  # Maximum pickup distance
	
	# Check all dropped tools to find closest one
	for tool_node in dropped_tools:
		if is_instance_valid(tool_node):
			var distance = global_position.distance_to(tool_node.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_tool = tool_node
	
	# NEW: Check all scene tools to find closest one
	for tool_node in available_scene_tools:
		if is_instance_valid(tool_node):
			var distance = global_position.distance_to(tool_node.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_tool = tool_node
				
	# If no tool found above, try checking for tool nodes directly in the scene
	if closest_tool == null:
		# Look for tools in the scene (they might not be in the dropped_tools array yet)
		var potential_tools = get_tree().get_nodes_in_group("tools")
		for tool_node in potential_tools:
			if tool_node != self and is_instance_valid(tool_node):  # Skip self (the player)
				var distance = global_position.distance_to(tool_node.global_position)
				if distance < closest_distance:
					closest_distance = distance
					closest_tool = tool_node
					
	return closest_tool

func safe_pick_up_tool():
	print("DEBUG: Attempting to pick up tool")
	print("DEBUG: tool_in_range = ", tool_in_range)
	
	# Early exit with better error message if no tool in range
	if not tool_in_range:
		print("No tool in range to pick up")
		return
		
	if not is_instance_valid(tool_in_range):
		print("Tool reference is invalid")
		return
	
	var hand = $Hand
	if not hand:
		push_error("Hand node not found")
		return
	
	print("Picking up tool: ", tool_in_range.name)
	var tool_ref = tool_in_range
	
	# Remove from dropped tools list if it's there
	if dropped_tools.has(tool_ref):
		dropped_tools.erase(tool_ref)
		print("Tool removed from dropped tools list")
	
	# NEW: Remove from available scene tools if it's there
	if available_scene_tools.has(tool_ref):
		available_scene_tools.erase(tool_ref)
		print("Tool removed from available scene tools list")
	
	# Store original parent for debugging
	var original_parent = null
	if tool_ref.get_parent():
		original_parent = tool_ref.get_parent()
		original_parent.remove_child(tool_ref)
		print("Tool removed from parent: ", original_parent.name)
	
	# Add to hand with additional checks
	print("Adding tool to hand...")
	hand.add_child(tool_ref)
	
	# Verify the tool was added successfully
	if not tool_ref.is_inside_tree():
		push_error("Tool failed to attach to hand")
		# Try to restore it to original parent if possible
		if original_parent and is_instance_valid(original_parent):
			print("Attempting to restore tool to original parent")
			original_parent.add_child(tool_ref)
		return
	
	print("Tool added to hand successfully")
	tool_ref.position = Vector2.ZERO
	tool_ref.rotation = 0
	
	# Check if disable_collision method exists before calling
	if tool_ref.has_method("disable_collision"):
		tool_ref.disable_collision()
		print("Tool collision disabled")
	else:
		print("WARNING: Tool does not have disable_collision method")
	
	has_tool = true
	current_tool = tool_ref
	tool_in_range = null
	
	# Set flag that tool pickup was successful and start the indicator
	tool_pickup_successful = true
	
	# Check if method exists
	if has_method("start_next_level_indicator"):
		start_next_level_indicator()
		print("Next level indicator started")
	else:
		print("WARNING: start_next_level_indicator method not found")
	
	# Enable next level area with check
	if has_method("enable_next_level_area"):
		enable_next_level_area()
		print("Next level area enabled")
	else:
		print("WARNING: enable_next_level_area method not found")
	
	print("Tool pickup process completed")

func handle_auto_movement():
	var moved_distance = abs(global_position.x - start_position_x)
	if moved_distance >= AUTO_MOVE_DISTANCE:
		auto_move_direction *= -1
		start_position_x = global_position.x
	
	velocity.x = auto_move_direction * SPEED
	
	# Update sprite direction for auto movement
	if auto_move_direction > 0:
		facing_right = true
		if animated_sprite:
			animated_sprite.flip_h = false
	else:
		facing_right = false
		if animated_sprite:
			animated_sprite.flip_h = true

func handle_manual_movement():
	if gravity_enabled:
		# Gravity movement - horizontal only + jumping
		var horizontal_input = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
		velocity.x = horizontal_input * SPEED
		
		# Jumping
		if Input.is_action_just_pressed("ui_up") and is_on_floor():
			velocity.y = JUMP_VELOCITY
	else:
		# Original 4-directional movement
		var input_vector = Vector2(
			Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
			Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
		).normalized()
		velocity = input_vector * SPEED

func enable_next_level_area():
	if not next_level_area:
		push_error("Next level area reference is missing!")
		return
	
	print("Forcibly enabling next level area collision and visibility")
	next_level_area.process_mode = Node.PROCESS_MODE_INHERIT
	next_level_area.visible = true
	
	# Make sure collision is enabled
	for child in next_level_area.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.disabled = false
			print("Enabled collision on: " + child.name)
	
	# Make sure monitoring is enabled if it's an Area2D
	if next_level_area is Area2D:
		next_level_area.monitoring = true
		next_level_area.monitorable = true
		
		# DEBUG: Print all bodies currently overlapping with the next level area
		var overlapping_bodies = next_level_area.get_overlapping_bodies()
		print("Bodies currently overlapping with next level area: ", overlapping_bodies.size())
		for body in overlapping_bodies:
			print("  - ", body.name)
	
	can_proceed_to_next_level = true
	print("Next level area fully enabled and ready")
	
	# DEBUG: Check if player is already inside the area
	if next_level_area.get_overlapping_bodies().has(self):
		print("Player is already inside the next level area!")
		if has_tool:
			print("Player has tool - should trigger transition!")
			# Call with small delay to ensure physics updates
			await get_tree().create_timer(0.1).timeout
			_on_next_level_area_body_entered(self)
	else:
		print("Player is not yet inside the next level area")

func _on_next_level_area_body_entered(body):
	print("Something entered next level area: " + body.name)
	
	# Only proceed if the body is the player AND they have a tool
	if body == self and has_tool and tool_pickup_successful:
		print("Player entered next level area with successfully retrieved tool!")
		start_level_transition()
	elif body == self and not has_tool:
		print("Player entered next level area without a tool - can't proceed")
		# Show feedback message
		display_message("You need a tool to proceed!")
	elif body == self and has_tool and not tool_pickup_successful:
		print("Player has a tool but pickup wasn't successful - can't proceed")
		display_message("You need to pick up a tool properly!")
	else:
		print("Non-player body entered next level area: " + body.name)
		
	# DEBUG: Print all bodies currently overlapping with the next level area
	if next_level_area is Area2D:
		var overlapping_bodies = next_level_area.get_overlapping_bodies()
		print("Bodies currently overlapping with next level area: ", overlapping_bodies.size())
		for b in overlapping_bodies:
			print("  - ", b.name)

func start_next_level_indicator():
	if next_level_indicator:
		print("Starting indicator blinking")
		next_level_indicator.visible = true
		next_level_indicator.color = Color(0, 1, 0, 0.7)
		is_blinking = true
		blink_time = 0.0
		
		# ADDED: Create a timer to force-enable the next level area after blinking
		var enable_timer = get_tree().create_timer(blink_total_time + 0.1)
		enable_timer.timeout.connect(func(): enable_next_level_area())
		
		print("Next level area will be forcibly enabled after blinking completes")
	else:
		push_error("Next level indicator not assigned! Please connect the ColorRect in the Inspector.")
		# Even without indicator, enable the next level area
		enable_next_level_area()

func safe_drop_tool():
	print("safe_drop_tool() called")
	
	if not has_tool or not is_instance_valid(current_tool):
		print("ERROR: No valid tool to drop!")
		return
	
	var hand = $Hand
	if not hand or not current_tool.get_parent() == hand:
		print("ERROR: Hand not found or tool not in hand!")
		return
	
	var drop_position
	var parent_node = get_parent()
	var is_in_drop_zone = false
	
	# Check if we're in a drop zone and use its position if available
	if tool_drop_zone and tool_drop_zone.get_overlapping_bodies().has(self):
		print("Dropping tool in designated drop zone")
		drop_position = hand.global_position
		is_in_drop_zone = true
	else:
		# Otherwise drop at hand position
		print("Dropping tool at current location")
		drop_position = hand.global_position
	
	# Store tool reference
	var tool_ref = current_tool
	
	# Remove tool from hand
	hand.remove_child(tool_ref)
	
	# Add to scene
	parent_node.add_child(tool_ref)
	
	# Make sure the tool is visible
	tool_ref.visible = true
	tool_ref.modulate.a = 1.0  # Ensure full opacity
	
	# Set the position
	tool_ref.global_position = drop_position
	
	if tool_ref.has_method("enable_collision"):
		tool_ref.enable_collision()
		print("Tool collision enabled")
	
	# Add to dropped tools list for camera detection
	dropped_tools.append(tool_ref)
	print("Tool added to dropped tools list")
	
	# Check immediately if the dropped tool is in camera view
	if camera_area and camera_area.get_overlapping_bodies().has(tool_ref):
		tool_in_camera_view = true
		check_player_caught()
	
	has_tool = false
	current_tool = null
	tool_pickup_successful = false
	
	# Disable next level area when dropping the tool
	disable_next_level_area()
	print("Tool drop complete")
	
	# Disable the drop zone if we dropped the tool in it
	if is_in_drop_zone and tool_drop_zone:
		disable_tool_drop_zone()
		
func disable_tool_drop_zone():
	print("Disabling tool drop zone after use")
	
	if tool_drop_zone:
		# Disable collision detection
		tool_drop_zone.monitoring = false
		tool_drop_zone.monitorable = false
		
		# Disconnect signals
		if tool_drop_zone.body_entered.is_connected(_on_tool_drop_zone_body_entered):
			tool_drop_zone.body_entered.disconnect(_on_tool_drop_zone_body_entered)
		if tool_drop_zone.body_exited.is_connected(_on_tool_drop_zone_body_exited):
			tool_drop_zone.body_exited.disconnect(_on_tool_drop_zone_body_exited)
		
		# Visual indication that the drop zone is used
		update_drop_zone_appearance()
		
		print("Tool drop zone disabled successfully")

func update_drop_zone_appearance():
	# Find any visual elements in the drop zone and update them
	for child in tool_drop_zone.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			# Change color to indicate used state
			child.modulate = Color(0.5, 0.5, 0.5, 0.5)  # Gray out
		
		# If you have a specific indicator node
		if child.name == "DropIndicator":
			# Stop any active tweens
			var active_tweens = child.get_meta("active_tweens", [])
			for tween in active_tweens:
				if is_instance_valid(tween):
					tween.kill()
			
			# Create a "used" appearance
			var tween = create_tween()
			tween.tween_property(child, "modulate", Color(0.5, 0.5, 0.5, 0.3), 0.5)
			
	# Optional: Add a "used" label
	var label = Label.new()
	label.text = "Used"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(-20, -20)  # Adjust as needed
	tool_drop_zone.add_child(label)

func flash_tool(tool_node):
	if not is_instance_valid(tool_node):
		return
		
	# Create a tween for flashing effect
	var tween = create_tween()
	tween.set_loops(3)  # Flash 3 times
	
	# Flash sequence
	tween.tween_property(tool_node, "modulate", Color(2, 2, 2, 1), 0.3)  # Brighter
	tween.tween_property(tool_node, "modulate", Color(1, 1, 1, 1), 0.3)  # Normal

func disable_next_level_area():
	if next_level_indicator:
		next_level_indicator.visible = false
	
	if next_level_area:
		next_level_area.process_mode = Node.PROCESS_MODE_DISABLED
		next_level_area.visible = false
		print("Next level area disabled")
	
	is_blinking = false
	can_proceed_to_next_level = false


func display_message(text: String, duration: float = 2.0):
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	
	# Position in center of screen
	var viewport_size = get_viewport_rect().size
	label.size = Vector2(viewport_size.x, 100)
	label.position = Vector2(0, viewport_size.y * 0.4)
	
	# Add to a canvas layer
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	canvas.add_child(label)
	
	# Fade out and remove
	var tween = create_tween()
	tween.tween_interval(duration - 0.5)
	tween.tween_property(label, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(func(): canvas.queue_free())

func show_message(text: String, duration: float = 2.0):
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.modulate = Color(1, 1, 1, 1)
	
	# Position centered in viewport
	var viewport_size = get_viewport_rect().size
	label.size = Vector2(viewport_size.x, 100)
	label.position = Vector2(0, viewport_size.y * 0.4)
	
	# Add to a CanvasLayer to ensure visibility
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 99  # High layer but below the fade overlay
	add_child(canvas_layer)
	canvas_layer.add_child(label)
	
	# Fade out and remove after duration
	var tween = create_tween()
	tween.tween_interval(duration - 0.5)  # Wait before fading
	tween.tween_property(label, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(func(): canvas_layer.queue_free())

func start_level_transition():
	if is_transitioning:
		print("Already in transition, ignoring duplicate request")
		return
	
	print("Starting level transition with fade effect")
	is_transitioning = true
	
	# Ensure fade overlay exists and is properly configured
	if not fade_overlay or not is_instance_valid(fade_overlay):
		print("Recreating fade overlay as it was invalid!")
		create_fade_overlay()
	
	fade_overlay.visible = true
	fade_overlay.color = Color(0, 0, 0, 0)  # Start fully transparent
	
	# Create a tween for smooth fade instead of relying solely on physics_process
	var tween = create_tween()
	tween.tween_property(fade_overlay, "color", Color(0, 0, 0, 1.0), TRANSITION_DURATION)
	tween.tween_callback(func(): load_next_level())
	
	# Also start the timer as a backup
	transition_timer.start()
	
	# Save the tool state before transition
	if has_tool and is_instance_valid(current_tool):
		if "Global" in get_tree().root.get_children():
			print("Saving tool: " + current_tool.name + " to Global singleton")
			Global.set_player_tool(current_tool.name)
		else:
			print("WARNING: Global singleton not found!")
	
	# Freeze player movement during transition
	set_physics_process(false)

func _on_transition_timer_timeout():
	print("Transition timer completed - loading next level")
	# Only load if we haven't already (the tween might have done it already)
	if is_transitioning:
		load_next_level()

func load_next_level():
	# Get current scene name to determine next scene
	var current_scene_name = get_tree().current_scene.name
	print("Loading next level from current scene: " + current_scene_name)
	
	var next_scene_path = ""
	
	# Determine next scene based on current scene
	match current_scene_name:
		"L1S1":
			next_scene_path = "res://Scenes/L1S2.tscn"
		"L1S2":
			next_scene_path = "res://Scenes/L1S3.tscn"
		"L1S3":
			next_scene_path = "res://Scenes/L2S1.tscn"
		"L2S1":
			next_scene_path = "res://Scenes/L2S2.tscn"  # Update to go to L2S2 instead of L1S2
		"L2S2":
			next_scene_path = "res://Scenes/L3S1.tscn"  # Add path to next scene after L2S2
		"L2S3":
			next_scene_path = "res://Scenes/L3S2.tscn"
		
		# Add more scene transitions as needed
		_:
			# Default to L1S2 if unknown
			print("WARNING: Unknown current scene, defaulting to L1S2")
			next_scene_path = "res://Scenes/L1S2.tscn"
			next_scene_path = "res://Scenes/L3S2.tscn"
	
	print("Transitioning to: " + next_scene_path)
	
	# Check if the file exists before trying to load it
	if ResourceLoader.exists(next_scene_path):
		get_tree().change_scene_to_file(next_scene_path)
	else:
		push_error("Scene path does not exist: " + next_scene_path)
		# Show error message and reset transition state
		is_transitioning = false
		set_physics_process(true)
		
		if fade_overlay and is_instance_valid(fade_overlay):
			fade_overlay.visible = false
			
		show_message("Error: Next scene not found!", 5.0)


func toggle_hide() -> void:
	# Check if player can hide based on guard position
	var can_hide = get_tree().get_first_node_in_group("guard").can_hide_from_guard()
	
	if not Global.player_is_hidden and not can_hide:
		# Can't hide if guard would detect player
		print("Cannot hide - guard would see you!")
		return
	
	# Toggle hidden state
	Global.player_is_hidden = !Global.player_is_hidden
	
	# Update visibility and collision
	visible = !Global.player_is_hidden
	$CollisionShape2D.disabled = Global.player_is_hidden
	
	print("Player hidden state: ", Global.player_is_hidden)

# Called when player is caught by guard
func caught() -> void:
	# Player got caught by guard
	print("Player caught!")
	visible = true  # Ensure player is visible when caught
	
	# Stop player movement
	velocity = Vector2.ZERO

func has_ancestor_named(name_to_check: String) -> bool:
	var current = get_parent()
	while current:
		if current.name == name_to_check:
			return true
		current = current.get_parent()
	return false

# Camera detection functions
func _on_camera_detect_body_entered(body):
	print("Camera detected body: ", body.name)
	
	if body == player:
		print("Camera is now seeing the player")
		player_in_camera_view = true
		
		# If player is attempting to pick up a tool while visible, they're caught immediately
		if attempting_pickup:
			game_over("You were caught trying to pick up a tool! Game Over.")
			return
			
		check_player_caught()
	
	# Check if the body is a dropped tool
	elif dropped_tools.has(body):
		print("Camera detected dropped tool!")
		tool_in_camera_view = true
		
		# If player is attempting to pick up this tool while it's visible, they're caught
		if attempting_pickup and tool_in_range == body:
			game_over("Tool was spotted by the camera while you tried to pick it up! Game Over.")
			return
			
		check_player_caught()

func _on_camera_detect_area_entered(area):
	print("Camera detected area: ", area.name)
	
	if area == toolbox_area:
		print("Camera is now seeing the toolbox area")
		toolbox_in_camera_view = true
		check_player_caught()

func check_player_caught():
	# Check if both conditions are met: camera sees both player and toolbox
	# AND player is inside toolbox
	if player_in_camera_view and toolbox_in_camera_view and toolbox_area.get_overlapping_bodies().has(player):
		is_paused = true
		game_over("Player was caught hiding in the toolbox! Game Over.")
	elif player_in_camera_view and not toolbox_area.get_overlapping_bodies().has(player):
		# Optional: Handle case where player is in camera view but not hiding
		print("Camera sees player in the open.")
		# You could trigger game over here if player should not be visible
	
	# Check if a tool was caught in camera view
	elif tool_in_camera_view:
		if attempting_pickup:
			is_paused = true
			game_over("You tried to pick up a tool that was visible to the camera! Game Over.")
		else:
			is_paused = true
			game_over("Tool was spotted by the camera! Game Over.")

func game_over(message: String):
	if is_game_over:
		return
		
	is_game_over = true
	print(message)
	
	Global.guard_caught_player = true
	# Stop all movement
	velocity = Vector2.ZERO
	set_physics_process(false)
	
	# Show game over screen
	fade_overlay.visible = true
	var tween = create_tween()
	tween.tween_property(fade_overlay, "color", Color(0, 0, 0, 0.8), 1.0)
	
	# Create game over text
	var game_over_label = Label.new()
	game_over_label.text = "GAME OVER\n" + message
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 32)
	game_over_label.size = get_viewport_rect().size
	game_over_label.position = Vector2.ZERO
	
	var canvas_layer = fade_overlay.get_parent()
	canvas_layer.add_child(game_over_label)
	
	# Add restart button
	var restart_button = Button.new()
	restart_button.text = "Restart Level"
	restart_button.size = Vector2(200, 50)
	restart_button.position = Vector2(
		(get_viewport_rect().size.x - restart_button.size.x) / 2,
		game_over_label.position.y + game_over_label.size.y / 2 + 50
	)
	restart_button.pressed.connect(_on_restart_button_pressed)
	
	canvas_layer.add_child(restart_button)

func _on_restart_button_pressed():
	Global.guard_caught_player = false
	# Reload current scene
	get_tree().reload_current_scene()

# Tool drop zone handlers
func _on_tool_drop_zone_body_entered(body):
	if body == self and has_tool:
		print("Player entered tool drop zone with tool - automatically dropping tool")
		safe_drop_tool()  # Automatically drop the tool when entering the zone
	elif body == self and not has_tool:
		print("Player entered tool drop zone without tool")
	elif dropped_tools.has(body):
		print("Dropped tool entered tool drop zone")

func _on_tool_drop_zone_body_exited(body):
	if body == self:
		print("Player exited tool drop zone")
	elif dropped_tools.has(body):
		print("Dropped tool exited tool drop zone")

# Modify the give_player_tool function to explicitly enable the next level area
func give_player_tool(tool_name: String):
	# Find the hand node
	var hand = $Hand
	if not hand:
		push_error("Hand node not found! Cannot give tool to player.")
		return
	
	# Create the tool instance based on the tool name
	var tool_instance
	
	# Determine which tool to create based on the name
	match tool_name:
		"Wrench":
			tool_instance = load("res://Scenes/tool.tscn").instantiate()
		"Hammer":
			tool_instance = load("res://Path/To/Hammer.tscn").instantiate()
		"Screwdriver":
			tool_instance = load("res://Path/To/Screwdriver.tscn").instantiate()
		# Add more tools as needed
		_:
			push_error("Unknown tool type: " + tool_name)
			return
	
	# Add the tool to the hand
	hand.add_child(tool_instance)
	tool_instance.position = Vector2.ZERO
	tool_instance.rotation = 0
	
	# Disable tool collision while being carried
	if tool_instance.has_method("disable_collision"):
		tool_instance.disable_collision()
	
	# Update the player state
	has_tool = true
	current_tool = tool_instance
	tool_pickup_successful = true  # This tool was given directly, so mark as successful
	
	print("Tool given to player: ", tool_name)
	
	# IMPORTANT FIX: Explicitly enable the next level area after giving the tool
	enable_next_level_area()
	
	# Start the next level indicator if needed
	start_next_level_indicator()
