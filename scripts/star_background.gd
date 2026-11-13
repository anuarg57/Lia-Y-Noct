extends Node2D

const STAR_COUNT = 50

func _ready():
	for i in range(STAR_COUNT):
		var star = preload("res://scenes/star.tscn").instantiate()
		add_child(star)
		star.position = Vector2(randi() % 1280, randi() % 720)
		star.z_index = randi() % 10 - 10
