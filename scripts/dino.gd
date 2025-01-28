extends CharacterBody2D

@onready var jump_btn: Button = $"/root/main/controller_btn/jump_btn"
@onready var crouch_btn: Button = $"/root/main/controller_btn/crouch_btn"

const GRAVITY: int = 4200
const JUMP_SPEED: int = -1500

var is_crouching: bool = false
var can_jump: bool = true

func _ready() -> void:
	jump_btn.button_down.connect(_on_jump_btn_down)
	crouch_btn.button_down.connect(_on_crouch_btn_down)
	crouch_btn.button_up.connect(_on_crouch_btn_up)

func _physics_process(delta: float) -> void:
	velocity.y += GRAVITY * delta
	
	if is_on_floor():
		can_jump = true
		
		if not get_parent().game_running:
			$AnimatedSprite2D.play("idle")
			$duck_coll.disabled = true
			$run_coll.disabled = false
		else:
			handle_floor_state()
	else:
		$AnimatedSprite2D.play("jump")
	
	move_and_slide()

func handle_floor_state() -> void:
	if Input.is_action_just_pressed("ui_accept") and can_jump:
		jump()
	elif Input.is_action_pressed("ui_down"):
		$AnimatedSprite2D.play("duck")
		$run_coll.disabled = true
		$duck_coll.disabled = false
	elif is_crouching:
		crouch()
	else:
		stand()

func jump() -> void:
	if can_jump and is_on_floor():
		velocity.y = JUMP_SPEED
		$jump_sound.play()
		can_jump = false

func crouch() -> void:
	is_crouching = true
	$AnimatedSprite2D.play("duck")
	$run_coll.disabled = true
	$duck_coll.disabled = false

func stand() -> void:
	is_crouching = false
	$AnimatedSprite2D.play("run")
	$run_coll.disabled = false
	$duck_coll.disabled = true

# Button signal handlers
func _on_jump_btn_down() -> void:
	if is_on_floor() and can_jump:
		jump()

func _on_crouch_btn_down() -> void:
	is_crouching = true
	crouch()

func _on_crouch_btn_up() -> void:
	is_crouching = false
	stand()
