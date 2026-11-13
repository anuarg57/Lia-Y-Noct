extends Node2D

func _process(delta):
	position.y += 100 * delta
	if position.y > 800:
		queue_free()
