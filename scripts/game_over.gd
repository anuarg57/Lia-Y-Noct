extends Control

func _ready():
	var restart_button = find_child("RestartButton", true, false)
	var main_menu_button = find_child("MainMenuButton", true, false)
	
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_pressed)

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_on_restart_pressed()
		elif event.keycode == KEY_M or event.keycode == KEY_ESCAPE:
			_on_main_menu_pressed()

func _on_restart_pressed():
	print("Reiniciando nivel...")
	get_tree().reload_current_scene()

func _on_main_menu_pressed():
	print("Volviendo al menú principal...")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
