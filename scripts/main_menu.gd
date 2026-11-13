extends Control

func _ready():
	$MenuContainer/NewGameButton.pressed.connect(_on_new_game_pressed)
	$MenuContainer/LoadGameButton.pressed.connect(_on_load_game_pressed)
	$MenuContainer/OptionsButton.pressed.connect(_on_options_pressed)
	$MenuContainer/ExitButton.pressed.connect(_on_exit_pressed)

func _on_new_game_pressed():
	get_tree().change_scene_to_file("res://scenes/test_level.tscn")

func _on_load_game_pressed():
	print("Load Game - not implemented")

func _on_options_pressed():
	print("Options - not implemented")

func _on_exit_pressed():
	get_tree().quit()
