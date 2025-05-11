extends Node2D

# Explosion parameters
@export var shake_intensity := 15.0
@export var shake_duration := 0.5
@export var explosion_radius := 60.0
@export var explosion_duration := 1.0
@export var explosion_color_1 := Color(1.0, 0.7, 0.0, 1.0)  # Orange-yellow
@export var explosion_color_2 := Color(1.0, 0.3, 0.0, 1.0)  # Orange-red
@onready var camera_2d = $Player/Camera2D

@export var fade_duration: float = 1.0

var fade_overlay: ColorRect

func _ready():
	# Set camera limits
	camera_2d.limit_left = 0
	camera_2d.limit_top = 0
	camera_2d.limit_right = 7000
	camera_2d.limit_bottom = 1100
	# Ensure we have an Area2D child for collision detection
	var mine_area = $Area2D if has_node("Area2D") else null
	if not mine_area:
		push_error("Mines node needs an Area2D child for collision detection!")
		return
		
	# Connect the signal if not already connected
	if not mine_area.body_entered.is_connected(_on_mines_body_entered):
		mine_area.body_entered.connect(_on_mines_body_entered)
	
	print("Mines initialized and ready")

# Called when a body enters the mines area
func _on_mines_body_entered(body):
	# Check if the body is the player
	if body.is_in_group("player") or body.name == "Player":
		print("Player entered mines area - BOOM!")
		trigger_explosion(body)

# Trigger the explosion effect and game over
func trigger_explosion(player):
	# Prevent multiple explosions
	var mine_area = $Area2D
	if mine_area:
		mine_area.monitoring = false
		mine_area.monitorable = false
	
	# Create explosion at the mine's position
	spawn_explosion()
	
	# Shake the camera
	shake_camera()
	
	# Play explosion sound
	play_explosion_sound()
	
	# Small delay before game over for dramatic effect
	await get_tree().create_timer(0.5).timeout
	
	# Trigger game over
	if player.has_method("game_over"):
		# Use the player's game over function if available
		player.game_over("You were blown up by a mine! Game Over.")
	else:
		# Otherwise use our own game over implementation
		show_game_over("You were blown up by a mine! Game Over.")

# Spawn explosion visual effect using CPU particles
func spawn_explosion():
	# Create enhanced visual effects
	create_explosion_flash()  # Start with flash first for immediate visual feedback
	
	# Create a large fireball sprite for immediate visibility
	var fireball = create_fireball_sprite()
	
	# Create CPU Particles for explosion
	var particles = CPUParticles2D.new()
	get_tree().current_scene.add_child(particles)
	particles.global_position = global_position
	particles.z_index = 10  # Ensure particles are visible above other elements
	
	# Configure particle properties - increased values for better visibility
	particles.emitting = false  # Start off, we'll turn it on after setup
	particles.one_shot = true
	particles.explosiveness = 1.0  # Maximum explosiveness
	particles.amount = 150  # Increased particle count
	particles.lifetime = explosion_duration * 1.2
	particles.speed_scale = 2.0  # Faster animation
	particles.randomness = 0.5
	
	# Emission shape
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = explosion_radius * 0.3  # Larger emission radius
	
	# Particle movement
	particles.direction = Vector2(0, 0)
	particles.spread = 180
	particles.gravity = Vector2(0, -20)  # Slight upward drift for rising flame effect
	particles.initial_velocity_min = explosion_radius * 0.8  # Faster minimum velocity
	particles.initial_velocity_max = explosion_radius * 3.0  # Faster maximum velocity
	particles.damping_min = explosion_radius * 2.0
	particles.damping_max = explosion_radius * 4.0
	
	# Particle appearance - brighter colors and larger size
	particles.color = Color(1.0, 0.8, 0.2, 1.0)  # Brighter yellow
	particles.color_ramp = create_explosion_gradient()
	particles.scale_amount_min = 4.0  # Larger minimum size
	particles.scale_amount_max = 10.0  # Larger maximum size
	
	# Start emitting
	particles.emitting = true
	
	# Create a second particle system for smaller particles
	var small_particles = CPUParticles2D.new()
	get_tree().current_scene.add_child(small_particles)
	small_particles.global_position = global_position
	small_particles.z_index = 11  # Above the main particles
	
	# Configure small particles
	small_particles.emitting = false
	small_particles.one_shot = true
	small_particles.explosiveness = 1.0
	small_particles.amount = 100  # More particles
	small_particles.lifetime = explosion_duration * 0.9
	small_particles.speed_scale = 2.5
	
	# Emission shape for small particles
	small_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	small_particles.emission_sphere_radius = explosion_radius * 0.2
	
	# Small particle movement
	small_particles.direction = Vector2(0, 0)
	small_particles.spread = 180
	small_particles.gravity = Vector2(0, -10)  # Slight upward drift
	small_particles.initial_velocity_min = explosion_radius * 0.5
	small_particles.initial_velocity_max = explosion_radius * 2.5
	small_particles.damping_min = explosion_radius * 1.5
	small_particles.damping_max = explosion_radius * 3.0
	
	# Small particle appearance - brighter color
	small_particles.color = Color(1.0, 0.4, 0.0, 1.0)  # Bright orange-red
	small_particles.scale_amount_min = 2.0  # Larger
	small_particles.scale_amount_max = 6.0  # Larger
	
	# Start emitting small particles
	small_particles.emitting = true
	
	# Create smoke particles after a short delay
	create_smoke_particles()
	
	# Auto cleanup after particles finish
	await get_tree().create_timer(explosion_duration * 1.5).timeout
	particles.queue_free()
	small_particles.queue_free()
	if is_instance_valid(fireball):
		fireball.queue_free()

# Create a temporary fireball sprite for immediate visibility
func create_fireball_sprite() -> Sprite2D:
	var fireball = Sprite2D.new()
	get_tree().current_scene.add_child(fireball)
	fireball.global_position = global_position
	fireball.z_index = 9  # Ensure it's above the scene but below particles
	
	# Create a gradient texture for the fireball
	var texture = GradientTexture2D.new()
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 0.9, 0.3, 1.0))  # Bright yellow center
	gradient.add_point(0.6, Color(1.0, 0.4, 0.0, 0.8))  # Orange-red middle
	gradient.add_point(1.0, Color(0.7, 0.1, 0.0, 0.0))  # Fade out to transparent
	texture.gradient = gradient
	texture.width = int(explosion_radius * 3)
	texture.height = int(explosion_radius * 3)
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1, 0.5)
	
	fireball.texture = texture
	
	# Animate the fireball
	var tween = create_tween()
	tween.tween_property(fireball, "scale", Vector2(2.0, 2.0), 0.2)
	tween.parallel().tween_property(fireball, "modulate", Color(1, 1, 1, 1), 0.1)
	tween.tween_property(fireball, "scale", Vector2(1.5, 1.5), explosion_duration * 0.3)
	tween.parallel().tween_property(fireball, "modulate", Color(1, 0.7, 0.3, 0), explosion_duration * 0.5)
	
	return fireball

# Create smoke particles for after the explosion
func create_smoke_particles():
	var smoke = CPUParticles2D.new()
	get_tree().current_scene.add_child(smoke)
	smoke.global_position = global_position
	smoke.z_index = 8  # Below the main explosion
	
	# Configure smoke properties
	smoke.emitting = false
	smoke.one_shot = true
	smoke.explosiveness = 0.3  # Less explosive for a smoke cloud effect
	smoke.amount = 50
	smoke.lifetime = explosion_duration * 2.0  # Smoke lasts longer
	smoke.speed_scale = 0.7  # Slower for a smoke effect
	
	# Emission shape
	smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = explosion_radius * 0.3
	
	# Smoke movement
	smoke.direction = Vector2(0, -1)  # Slight upward tendency
	smoke.spread = 90
	smoke.gravity = Vector2(0, -15)  # Rises up
	smoke.initial_velocity_min = explosion_radius * 0.2
	smoke.initial_velocity_max = explosion_radius * 0.5
	smoke.damping_min = explosion_radius * 0.5
	smoke.damping_max = explosion_radius * 1.0
	
	# Smoke appearance
	var smoke_gradient = Gradient.new()
	smoke_gradient.add_point(0.0, Color(0.5, 0.5, 0.5, 0.7))  # Gray smoke
	smoke_gradient.add_point(0.5, Color(0.3, 0.3, 0.3, 0.5))  # Darker
	smoke_gradient.add_point(1.0, Color(0.1, 0.1, 0.1, 0.0))  # Fade to transparent
	
	smoke.color = Color(0.5, 0.5, 0.5, 0.7)
	smoke.color_ramp = smoke_gradient
	smoke.scale_amount_min = 8.0
	smoke.scale_amount_max = 15.0
	
	# Small delay before smoke starts
	await get_tree().create_timer(0.2).timeout
	smoke.emitting = true
	
	# Auto-cleanup
	await get_tree().create_timer(explosion_duration * 2.5).timeout
	smoke.queue_free()

# Create a gradient for the explosion particles
func create_explosion_gradient() -> Gradient:
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 1.0, 0.8, 1.0))  # Bright white-yellow center
	gradient.add_point(0.2, Color(1.0, 0.9, 0.2, 1.0))  # Bright yellow
	gradient.add_point(0.5, explosion_color_1)  # Orange-yellow
	gradient.add_point(0.8, explosion_color_2)  # Orange-red
	gradient.add_point(1.0, Color(0.5, 0.0, 0.0, 0.0))  # Fade to transparent red
	return gradient

# Create a flash effect at the start of the explosion
func create_explosion_flash():
	var flash = Sprite2D.new()
	get_tree().current_scene.add_child(flash)
	flash.global_position = global_position
	flash.z_index = 100  # Ensure flash is on top of everything
	
	# Create a white circle texture for the flash
	var texture = GradientTexture2D.new()
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1, 1, 1, 1))
	gradient.add_point(0.7, Color(1, 0.95, 0.8, 0.8))
	gradient.add_point(1.0, Color(1, 0.8, 0.5, 0))
	texture.gradient = gradient
	texture.width = int(explosion_radius * 8)  # Much larger flash
	texture.height = int(explosion_radius * 8)
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1, 1)
	
	flash.texture = texture
	# Start small and then expand
	flash.scale = Vector2(0.1, 0.1)
	flash.modulate = Color(1, 1, 1, 1)  # Pure white for maximum brightness
	
	# Enhanced flash animation
	var tween = create_tween()
	tween.tween_property(flash, "scale", Vector2(2.0, 2.0), 0.15)  # Expand quickly
	tween.parallel().tween_property(flash, "modulate", Color(1, 0.9, 0.5, 0.9), 0.05)  # Bright yellow-white
	tween.tween_property(flash, "modulate", Color(1, 0.8, 0.3, 0), 0.25)  # Fade out to orange then transparent
	tween.tween_callback(func(): flash.queue_free())
	
	# Create secondary flash ring
	var ring_flash = Sprite2D.new()
	get_tree().current_scene.add_child(ring_flash)
	ring_flash.global_position = global_position
	ring_flash.z_index = 99
	
	# Create ring texture
	var ring_texture = GradientTexture2D.new()
	var ring_gradient = Gradient.new()
	ring_gradient.add_point(0.7, Color(1, 0.9, 0.4, 0))  # Inner transparent
	ring_gradient.add_point(0.8, Color(1, 0.8, 0.2, 1))  # Bright ring
	ring_gradient.add_point(0.9, Color(1, 0.5, 0.1, 0.7))  # Fading edge
	ring_gradient.add_point(1.0, Color(1, 0.3, 0.0, 0))  # Outer transparent
	ring_texture.gradient = ring_gradient
	ring_texture.width = int(explosion_radius * 6)
	ring_texture.height = int(explosion_radius * 6)
	ring_texture.fill = GradientTexture2D.FILL_RADIAL
	ring_texture.fill_from = Vector2(0.5, 0.5)
	ring_texture.fill_to = Vector2(1, 1)
	
	ring_flash.texture = ring_texture
	ring_flash.scale = Vector2(0.5, 0.5)
	
	# Animate the ring
	var ring_tween = create_tween()
	ring_tween.tween_property(ring_flash, "scale", Vector2(3.0, 3.0), 0.4)
	ring_tween.parallel().tween_property(ring_flash, "modulate", Color(1, 1, 1, 0), 0.4)
	ring_tween.tween_callback(func(): ring_flash.queue_free())

# Shake the camera for effect
func shake_camera():
	# Find the camera
	var camera = get_viewport().get_camera_2d()
	if camera:
		# If camera has a shake method, use it
		if camera.has_method("shake"):
			camera.shake(shake_duration, shake_intensity)
		else:
			# Simple camera shake implementation
			var original_pos = camera.offset
			var tween = create_tween()
			
			# Shake several times
			for i in range(5):
				var rand_offset = Vector2(
					randf_range(-1, 1) * shake_intensity,
					randf_range(-1, 1) * shake_intensity
				)
				tween.tween_property(camera, "offset", original_pos + rand_offset, 0.1)
			
			# Return to original position
			tween.tween_property(camera, "offset", original_pos, 0.1)

# Play explosion sound
func play_explosion_sound():
	if has_node("ExplosionSound"):
		$ExplosionSound.play()
	else:
		# Create audio player if needed
		var audio = AudioStreamPlayer.new()
		add_child(audio)
		
		# Check if we can find an explosion sound in the project
		var explosion_sound = load("res://Sounds/explosion.wav") if ResourceLoader.exists("res://Sounds/explosion.wav") else null
		
		if explosion_sound:
			audio.stream = explosion_sound
			audio.volume_db = 5.0
			audio.play()
			audio.finished.connect(func(): audio.queue_free())

# Custom game over screen implementation (used if player doesn't have its own)
func show_game_over(message: String):
	# Stop gameplay
	get_tree().paused = true
	
	# Create overlay
	var fade_overlay = ColorRect.new()
	fade_overlay.color = Color(0, 0, 0, 0)  # Start transparent
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_overlay.size = get_viewport_rect().size
	fade_overlay.global_position = Vector2.ZERO
	
	# Add to canvas layer to show on top
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	canvas_layer.add_child(fade_overlay)
	get_tree().root.add_child(canvas_layer)
	
	# Fade in animation
	var tween = create_tween()
	tween.tween_property(fade_overlay, "color", Color(0, 0, 0, 0.8), 1.0)
	
	# Game over text
	var game_over_label = Label.new()
	game_over_label.text = "GAME OVER\n" + message
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 32)
	game_over_label.size = get_viewport_rect().size
	game_over_label.position = Vector2.ZERO
	canvas_layer.add_child(game_over_label)
	
	# Restart button
	var restart_button = Button.new()
	restart_button.text = "Restart Level"
	restart_button.size = Vector2(200, 50)
	restart_button.position = Vector2(
		(get_viewport_rect().size.x - restart_button.size.x) / 2,
		game_over_label.position.y + game_over_label.size.y / 2 + 50
	)
	restart_button.pressed.connect(func(): _restart_level())
	canvas_layer.add_child(restart_button)

# Restart level function
func _restart_level():
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_next_level_body_entered(body):
	if body.is_in_group("Player"):
		get_tree().change_scene_to_file("res://Scenes/L4S4.tscn")
