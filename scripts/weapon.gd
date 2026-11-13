extends Area2D

signal attack_finished

func attack():
	print("Weapon attack")
	await get_tree().create_timer(0.2).timeout
	attack_finished.emit()
