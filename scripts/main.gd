extends Node

# Preload scenes
var stump_scene = preload("res://scenes/stump.tscn")
var rock_scene = preload("res://scenes/rock.tscn")
var barrel_scene = preload("res://scenes/barrel.tscn")
var bird_scene = preload("res://scenes/bird.tscn")

# Obstacle configuration
var obstacle_types := [stump_scene, rock_scene, barrel_scene]
var obstacles: Array[Node] = []  # Explicitly type the array
var bird_heights := [200, 390]

# Game constants
const GAME_WIDTH := 1152  # Base game width
const GAME_HEIGHT := 648  # Base game height
const DINO_START_POS := Vector2(150, 485)
const CAM_START_POS := Vector2(576, 324)
const MAX_DIFFICULTY := 3
const SCORE_MODIFIER := 10
const FIX_SCORE := 10.0
const START_SPEED := 10.0
const MAX_SPEED := 25.0
const SPEED_MODIFIER := 5000
const MIN_OBSTACLE_DISTANCE := 300
const MAX_OBSTACLE_DISTANCE := 500
const OBSTACLE_CLEANUP_MARGIN := 1000

# Game variables
var difficulty := 0
var high_score := 0
var score := 0.0
var speed := START_SPEED
var screen_size: Vector2
var ground_height: int
var game_running := false
var last_obstacle_position := 0.0
var next_obstacle_distance := 0.0
var is_restarting := false

func _ready() -> void:
	# Setup window and viewport for both web and standalone
	var root = get_tree().root
	var window = get_window()
	
	# Set basic content scaling mode
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	
	# Set up viewport size
	get_viewport().set_content_scale_size(Vector2i(GAME_WIDTH, GAME_HEIGHT))
	
	# Handle window settings
	if OS.has_feature("web"):
		# Web-specific setup
		window.mode = Window.MODE_WINDOWED
		window.min_size = Vector2i(GAME_WIDTH, GAME_HEIGHT)
		
		# Center the viewport content
		root.set_content_scale_mode(Window.CONTENT_SCALE_MODE_CANVAS_ITEMS)
		root.set_content_scale_aspect(Window.CONTENT_SCALE_ASPECT_KEEP)
		
		# Add canvas layer for centering if needed
		if not has_node("CenterContainer"):
			var center_container = CenterContainer.new()
			center_container.name = "CenterContainer"
			center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
			add_child(center_container)
			
			# Move game content to center container if needed
			# Note: Adjust this based on your scene structure
			if has_node("game_content"):
				var game_content = get_node("game_content")
				remove_child(game_content)
				center_container.add_child(game_content)
		
		# Connect to window resize
		get_window().size_changed.connect(_on_window_resize)
		# Initial window resize handling
		_on_window_resize()
	else:
		# Standalone-specific setup
		window.size = Vector2i(GAME_WIDTH, GAME_HEIGHT)
		window.min_size = Vector2i(GAME_WIDTH, GAME_HEIGHT)
	
	# Common setup continues...
	randomize()
	screen_size = Vector2(GAME_WIDTH, GAME_HEIGHT)
	ground_height = $ground.get_node("Sprite2D").texture.get_height()
	$controller_btn.hide()
	$game_over.get_node("restart_btn").pressed.connect(restart_game)
	
	create_tap_area()
	new_game()

func _on_window_resize() -> void:
	if OS.has_feature("web"):
		var window = get_window()
		var viewport = get_viewport()
		var window_size = window.size
		
		# Calculate scale to fit window while maintaining aspect ratio
		var scale_x = window_size.x / float(GAME_WIDTH)
		var scale_y = window_size.y / float(GAME_HEIGHT)
		var scale = min(scale_x, scale_y)
		
		# Calculate centered position
		var margin_x = (window_size.x - (GAME_WIDTH * scale)) / 2
		var margin_y = (window_size.y - (GAME_HEIGHT * scale)) / 2
		
		# Apply centering via viewport canvas transform
		var transform = Transform2D()
		transform = transform.scaled(Vector2(scale, scale))
		transform = transform.translated(Vector2(margin_x/scale, margin_y/scale))
		viewport.canvas_transform = transform
		
func create_tap_area() -> void:
	if not has_node("tap_area"):
		var tap_area = Control.new()
		tap_area.set_anchors_preset(Control.PRESET_FULL_RECT)
		tap_area.mouse_filter = Control.MOUSE_FILTER_STOP
		tap_area.name = "tap_area"
		tap_area.gui_input.connect(_on_tap_area_input)
		add_child(tap_area)

func new_game() -> void:
	# Reset game state
	is_restarting = true
	get_tree().paused = false
	
	# Reset game variables
	score = 0.0
	speed = START_SPEED
	difficulty = 0
	game_running = false
	last_obstacle_position = 0.0
	next_obstacle_distance = randi_range(MIN_OBSTACLE_DISTANCE, MAX_OBSTACLE_DISTANCE)
	
	# Clean up existing obstacles with safety check
	clean_up_all_obstacles()
	
	# Reset physics state and position with safety delay
	await get_tree().physics_frame
	reset_game_positions()
	
	# Reset UI
	show_score()
	$custom_hud.get_node("tap_start_label").show()
	$game_over.hide()
	$controller_btn.hide()
	
	create_tap_area()
	is_restarting = false

func restart_game() -> void:
	if is_restarting:
		return  # Prevent multiple restarts
	
	# Ensure we're not in paused state
	get_tree().paused = false
	
	# Wait for physics frame to ensure clean state
	await get_tree().physics_frame
	new_game()
	
	# Wait another physics frame before starting
	await get_tree().physics_frame
	start_game()

func _process(delta: float) -> void:
	if is_restarting:
		return
		
	if game_running:
		update_game_state(delta)
		clean_up_obstacles()
		check_obstacle_generation()
		$controller_btn.show()
		if has_node("tap_area"):
			$tap_area.queue_free()
	else:
		if Input.is_action_just_pressed("ui_accept") and not is_restarting:
			start_game()

func start_game() -> void:
	if is_restarting:
		return
		
	game_running = true
	$custom_hud.get_node("tap_start_label").hide()
	if has_node("tap_area"):
		$tap_area.queue_free()

func _on_tap_area_input(event: InputEvent) -> void:
	if not game_running and not is_restarting:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				start_game()
		elif event is InputEventScreenTouch:
			if event.pressed:
				start_game()

func update_game_state(delta: float) -> void:
	# Update speed based on score
	speed = min(START_SPEED + score / SPEED_MODIFIER, MAX_SPEED)
	
	# Update positions
	$dino.position.x += speed * delta * 60  # Make movement frame-rate independent
	$Camera2D.position.x += speed * delta * 60
	
	# Update score
	score += speed * delta * (60.0 / FIX_SCORE)  # Smooth score increment
	show_score()
	
	# Update ground
	if $Camera2D.position.x - $ground.position.x > screen_size.x * 1.5:
		$ground.position.x += screen_size.x
	
	adjust_difficulty()

func check_obstacle_generation() -> void:
	var camera_x = $Camera2D.position.x
	if last_obstacle_position == 0.0 or camera_x + screen_size.x > last_obstacle_position + next_obstacle_distance:
		generate_obstacles()
		next_obstacle_distance = randi_range(MIN_OBSTACLE_DISTANCE, MAX_OBSTACLE_DISTANCE)

func generate_obstacles() -> void:
	var base_x = $Camera2D.position.x + screen_size.x + 350
	
	# Generate ground obstacles
	var obs_type = obstacle_types[randi() % obstacle_types.size()]
	var max_obs = difficulty + 1
	var obs_count = randi() % max_obs + 1
	
	for i in range(obs_count):
		var obs = obs_type.instantiate()
		var obs_sprite = obs.get_node("Sprite2D")
		var obs_height = obs_sprite.texture.get_height()
		var obs_scale = obs_sprite.scale
		
		var obs_x = base_x + (i * 100)
		var obs_y = screen_size.y - ground_height - (obs_height * obs_scale.y / 2) + 5
		
		add_obstacle(obs, obs_x, obs_y)
		last_obstacle_position = obs_x
	
	# Generate bird with increasing probability based on difficulty
	if difficulty >= 1 and randf() < 0.3 + (difficulty * 0.1):
		var bird = bird_scene.instantiate()
		var bird_x = base_x + randi_range(0, 200)
		var bird_y = bird_heights[randi() % bird_heights.size()]
		add_obstacle(bird, bird_x, bird_y)

func add_obstacle(obs: Node, x: float, y: float) -> void:
	if not is_instance_valid(obs) or is_restarting:
		return
		
	obs.position = Vector2(x, y)
	if not obs.body_entered.is_connected(hit_obs):
		obs.body_entered.connect(hit_obs)
	add_child(obs)
	obstacles.append(obs)

func clean_up_obstacles() -> void:
	var camera_x = $Camera2D.position.x
	var i = obstacles.size() - 1
	
	while i >= 0:
		var obs = obstacles[i]
		if is_instance_valid(obs) and obs.position.x < (camera_x - OBSTACLE_CLEANUP_MARGIN):
			obstacles.remove_at(i)
			obs.queue_free()
		i -= 1

func clean_up_all_obstacles() -> void:
	for obs in obstacles:
		if is_instance_valid(obs):
			obs.body_entered.disconnect(hit_obs)  # Disconnect signal first
			obs.queue_free()
	obstacles.clear()

func reset_game_positions() -> void:
	if is_instance_valid($dino):
		$dino.position = DINO_START_POS
		$dino.velocity = Vector2.ZERO
		# Reset any dino-specific states if needed
		if $dino.has_method("reset_state"):
			$dino.reset_state()
	
	$Camera2D.position = CAM_START_POS
	$ground.position = Vector2.ZERO

func adjust_difficulty() -> void:
	difficulty = mini(int(score / SPEED_MODIFIER), MAX_DIFFICULTY)

func hit_obs(body: Node) -> void:
	if body.name == "dino" and game_running and not is_restarting:
		game_over()

func show_score() -> void:
	$custom_hud.get_node("score_label").text = "Score: " + str(int(score))

func check_high_score() -> void:
	if int(score) > high_score:
		high_score = int(score)
		$custom_hud.get_node("high_score_label").text = "High Score: " + str(high_score)

func game_over() -> void:
	if is_restarting:
		return
		
	check_high_score()
	game_running = false
	$controller_btn.hide()
	$game_over.show()
	get_tree().paused = true
