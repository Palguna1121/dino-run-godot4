extends CharacterBody2D

const GRAVITY: int = 4200
const JUMP_SPEED: int = -1500

func _physics_process(delta):
	velocity.y += GRAVITY * delta
	if is_on_floor():
		if not get_parent().game_running:
			$AnimatedSprite2D.play("idle")
			$duck_coll.disabled = true
		else:
			$run_coll.disabled = false
			if Input.is_action_just_pressed("ui_accept"):
				velocity.y = JUMP_SPEED
				$jump_sound.play()
			elif Input.is_action_pressed("ui_down"):
				$AnimatedSprite2D.play("duck")
				$run_coll.disabled = true
				$duck_coll.disabled = false
			else:
				$AnimatedSprite2D.play("run")
	else:
		$AnimatedSprite2D.play("jump")
	move_and_slide()
