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
const OBSTACLE_CLEANUP_MARGIN := 1000  # Distance before camera to clean up obstacles

# Game variables
var difficulty := 0
var high_score := 0
var score := 0.0  # Changed to float for smoother increments
var speed := START_SPEED
var screen_size: Vector2
var ground_height: int
var game_running := false
var last_obstacle_position := 0.0
var next_obstacle_distance := 0.0

func _ready() -> void:
	randomize()  # Initialize random seed
	screen_size = get_window().size
	ground_height = $ground.get_node("Sprite2D").texture.get_height()
	$controller_btn.hide()
	$game_over.get_node("restart_btn").pressed.connect(new_game)
	
	# Tambahkan area untuk tap
	var tap_area = Control.new()
	tap_area.set_anchors_preset(Control.PRESET_FULL_RECT)  # Mengisi seluruh layar
	tap_area.mouse_filter = Control.MOUSE_FILTER_STOP  # Menangkap input mouse
	tap_area.name = "tap_area"
	tap_area.gui_input.connect(_on_tap_area_input)
	add_child(tap_area)
	
	new_game()

func new_game() -> void:
	score = 0.0
	speed = START_SPEED
	difficulty = 0
	game_running = false
	get_tree().paused = false
	last_obstacle_position = 0.0
	next_obstacle_distance = randi_range(MIN_OBSTACLE_DISTANCE, MAX_OBSTACLE_DISTANCE)
	
	# Clean up existing obstacles
	for obs in obstacles:
		if is_instance_valid(obs):  # Check if obstacle still exists
			obs.queue_free()
	obstacles.clear()
	
	# Reset positions
	$dino.position = DINO_START_POS
	$dino.velocity = Vector2.ZERO
	$Camera2D.position = CAM_START_POS
	$ground.position = Vector2.ZERO
	
	# Reset UI
	show_score()
	$custom_hud.get_node("tap_start_label").show()
	$game_over.hide()

func _process(delta: float) -> void:
	if game_running:
		update_game_state(delta)
		clean_up_obstacles()
		check_obstacle_generation()
		$controller_btn.show()
		if is_instance_valid($tap_area):
			$tap_area.queue_free()  # Hapus tap area saat game sudah running
	else:
		if Input.is_action_just_pressed("ui_accept"):
			start_game()

func _on_tap_area_input(event: InputEvent) -> void:
	if not game_running:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				start_game()
		elif event is InputEventScreenTouch:
			if event.pressed:
				start_game()

func start_game() -> void:
	game_running = true
	$custom_hud.get_node("tap_start_label").hide()

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
	if not is_instance_valid(obs):
		return
		
	obs.position = Vector2(x, y)
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

func adjust_difficulty() -> void:
	difficulty = mini(int(score / SPEED_MODIFIER), MAX_DIFFICULTY)

func hit_obs(body: Node) -> void:
	if body.name == "dino" and game_running:
		game_over()

func show_score() -> void:
	$custom_hud.get_node("score_label").text = "Score: " + str(int(score))

func check_high_score() -> void:
	if int(score) > high_score:
		high_score = int(score)
		$custom_hud.get_node("high_score_label").text = "High Score: " + str(high_score)

func game_over() -> void:
	check_high_score()
	get_tree().paused = true
	game_running = false
	$controller_btn.hide()
	$game_over.show()
