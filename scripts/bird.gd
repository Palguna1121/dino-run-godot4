extends Area2D

var bird_speed: float = 5.0  # Kecepatan default burung

func set_speed(new_speed: float) -> void:
	bird_speed = min(new_speed, 10.0)  # Batasi kecepatan maksimal burung

func _process(delta: float) -> void:
	position.x -= bird_speed  # Gunakan kecepatan burung yang sudah diatur
