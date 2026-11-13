extends Camera2D

func _ready():
	# La cámara es hija del jugador, así que no necesita buscar target
	print("Camera2D initialized as child of player")

func _physics_process(delta):
	# La cámara sigue automáticamente al padre (jugador)
	# No necesita código adicional
	pass
