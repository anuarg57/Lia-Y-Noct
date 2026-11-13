extends CharacterBody2D

class_name Player

const SPEED = 300.0
const JUMP_VELOCITY = -550.0
const ACCELERATION = 2000.0
const FRICTION = 2000.0
const COYOTE_TIME = 0.1
const JUMP_BUFFER = 0.1
const ANIMATION_SPEED = 0.1
const IDLE_ANIMATION_SPEED = 2.0  # 2 segundos por frame cuando está parado
const IDLE_DELAY = 2.0
const CROUCH_SPEED = 150.0

enum State {
	NORMAL,
	HURT,
	KNOCKBACK,
	DEAD,
	ATTACKING
}

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var coyote_timer = 0.0
var jump_buffer_timer = 0.0
var can_attack: bool = true
var is_attacking: bool = false
var animation_timer: float = 0.0
var current_frame: int = 0
var idle_timer: float = 0.0
var is_crouching: bool = false
var current_state: State = State.NORMAL
var health: int = 100
var max_health: int = 100
var is_dead: bool = false
var is_invincible: bool = false
var invincibility_timer: float = 0.0
var invincibility_duration: float = 2.0  # Aumentado de 1.0 a 2.0 segundos

@onready var player_visual = $PlayerVisual
@onready var collision_shape = $CollisionShape2D
@onready var weapon = $Weapon
@onready var hurtbox = $Hurtbox

# Cargar texturas en runtime (no preload para evitar errores de importación)
var texture_idle = null
var texture_crouch = null
var texture_run_right = null
var texture_run_left = null
var texture_jump = null
var texture_jump_right = null
var texture_jump_left = null
var texture_hurt = null
var texture_knockback_right = null
var texture_knockback_left = null
var texture_death = null
var texture_attack = null

# Mapa de frames por textura (basado en dimensiones exactas)
var texture_frames = {}
# Mapa explícito de frame widths por textura (basado en inspección de archivos)
var texture_frame_widths = {}

func _ready():
	# Agregar explícitamente al grupo player
	add_to_group("player")
	
	# Cargar texturas en runtime
	texture_idle = _load_texture("res://assets/sprites/noct/normal_animations/AnimacionReposo.png")
	texture_crouch = _load_texture("res://assets/sprites/noct/normal_animations/AnimacionAgacharse.png")
	texture_run_right = _load_texture("res://assets/sprites/noct/normal_animations/CaminarDerecha.png")
	texture_run_left = _load_texture("res://assets/sprites/noct/normal_animations/CaminarIzquierda.png")
	texture_jump = _load_texture("res://assets/sprites/noct/normal_animations/salto.png")
	
	# Si la textura no cargó, usar un ColorRect como fallback
	if texture_idle == null:
		print("Texture failed to load, using fallback")
		# El ColorRect ya está en la escena como PlayerDebugVisual
	texture_jump_right = _load_texture("res://assets/sprites/noct/normal_animations/SaltarDerecha.png")
	texture_jump_left = _load_texture("res://assets/sprites/noct/normal_animations/SaltarIzquierda.png")
	texture_hurt = _load_texture("res://assets/sprites/noct/combat_animations/Dano.png")
	texture_knockback_right = _load_texture("res://assets/sprites/noct/combat_animations/EmpujonDerecha.png")
	texture_knockback_left = _load_texture("res://assets/sprites/noct/combat_animations/EmpujonIzquierda.png")
	texture_death = _load_texture("res://assets/sprites/noct/combat_animations/Muerte.png")
	texture_attack = _load_texture("res://assets/sprites/noct/combat_animations/AtaquePalo.png")
	
	print("Texture idle loaded: ", texture_idle != null)
	
	# Calcular frames dinámicamente para cada textura
	_calculate_frames(texture_idle)
	_calculate_frames(texture_crouch)
	_calculate_frames(texture_run_right)
	_calculate_frames(texture_run_left)
	_calculate_frames(texture_jump)
	_calculate_frames(texture_jump_right)
	_calculate_frames(texture_jump_left)
	_calculate_frames(texture_hurt)
	_calculate_frames(texture_knockback_right)
	_calculate_frames(texture_knockback_left)
	_calculate_frames(texture_death)
	_calculate_frames(texture_attack)
	
	# Configurar sprite visual
	player_visual.region_enabled = false
	
	# Conectar hurtbox
	if hurtbox:
		hurtbox.body_entered.connect(_on_hurtbox_body_entered)
		print("Hurtbox connected")
	
	# Configurar textura inicial
	if texture_idle:
		player_visual.texture = texture_idle
		player_visual.hframes = texture_frames[texture_idle]
		player_visual.vframes = 1
		player_visual.region_enabled = false
		print("Initial texture set: ", texture_idle)
		print("Texture size: ", texture_idle.get_size())
		print("Frame count: ", texture_frames[texture_idle])
		print("Frame width: ", texture_frame_widths[texture_idle])
	else:
		print("ERROR: texture_idle is null!")
		# Crear una textura de respaldo para debug
		var fallback_texture = ImageTexture.new()
		var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(Color.RED)
		fallback_texture.set_image(img)
		player_visual.texture = fallback_texture
		player_visual.hframes = 1
		player_visual.vframes = 1
		print("Using fallback red texture for debug")

func _load_texture(path):
	if ResourceLoader.exists(path):
		return load(path)
	print("Texture not found: ", path)
	return null

func _calculate_frames(texture):
	if texture:
		var total_width = texture.get_width()
		var total_height = texture.get_height()
		
		# Determinar el ancho de frame basado en la altura (frames son cuadrados)
		var frame_size = total_height
		var frame_count = int(total_width / frame_size)
		
		texture_frames[texture] = frame_count
		texture_frame_widths[texture] = frame_size
		
		print("Texture: ", texture, " Width: ", total_width, " Height: ", total_height, " Frame Size: ", frame_size, " Frames: ", frame_count)
	else:
		texture_frames[texture] = 1
		texture_frame_widths[texture] = 64

func _physics_process(delta):
	# Debug print cada 60 frames (1 segundo)
	if Engine.get_physics_frames() % 60 == 0:
		print("=== PLAYER PHYSICS DEBUG ===")
		print("global_position: ", global_position)
		print("visible: ", visible)
		print("modulate.a: ", modulate.a)
		print("z_index: ", z_index)
		print("player_visual.texture: ", player_visual.texture)
		print("player_visual.hframes: ", player_visual.hframes)
		print("player_visual.frame: ", player_visual.frame)
		print("player_visual.visible: ", player_visual.visible)
		print("player_visual.modulate: ", player_visual.modulate)
		print("is_on_floor: ", is_on_floor())
		print("velocity: ", velocity)
		var camera = get_viewport().get_camera_2d()
		print("camera: ", camera)
		print("camera.enabled: ", camera.enabled if camera else "null")
		print("=== END DEBUG ===")
	
	if is_crouching and Input.is_action_just_released("crouch"):
		is_crouching = false
	
	if Input.is_action_pressed("crouch") and is_on_floor():
		is_crouching = true
	
	# Manejar i-frames (invincibilidad después de recibir daño)
	if is_invincible:
		invincibility_timer -= delta
		if invincibility_timer <= 0:
			is_invincible = false
			player_visual.modulate = Color.WHITE  # Restaurar color normal
		else:
			# Flicker visual durante i-frames
			var flicker = sin(invincibility_timer * 20.0) > 0
			player_visual.modulate = Color.WHITE if flicker else Color(1, 1, 1, 0.5)
	
	animate_player(delta)
	
	# Aplicar gravedad SIEMPRE, independientemente del estado
	if not is_on_floor():
		velocity.y += gravity * delta
		coyote_timer -= delta
	else:
		coyote_timer = COYOTE_TIME

	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
		jump_buffer_timer = JUMP_BUFFER
	else:
		jump_buffer_timer -= delta

	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0.0
		coyote_timer = 0.0

	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= 0.5

	if Input.is_action_just_pressed("attack") and can_attack:
		perform_attack()

	var direction = Input.get_axis("move_left", "move_right")
	var current_speed = CROUCH_SPEED if is_crouching else SPEED

	if direction:
		velocity.x = move_toward(velocity.x, direction * current_speed, ACCELERATION * delta)
		if direction < 0:
			player_visual.scale = Vector2(-1, 1)
			weapon.scale.x = -1
		else:
			player_visual.scale = Vector2(1, 1)
			weapon.scale.x = 1
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

	# Movimiento y colisión SIEMPRE se ejecutan, independientemente del estado
	move_and_slide()
	
	# Verificar colisiones usando el sistema nativo de Godot
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider and collider.is_in_group("enemies"):
			if not is_invincible and current_state == State.NORMAL:
				var knockback_dir = 1 if collider.global_position.x > global_position.x else -1
				print("COLLISION DETECTED with enemy! Taking damage. Direction: ", knockback_dir)
				take_damage(25, knockback_dir)
	
	# Límite de muerte por caída al vacío (void kill)
	if global_position.y > 1000:
		print("Player fell into void, triggering death")
		health = 0
		die()

func animate_player(delta):
	var direction = Input.get_axis("move_left", "move_right")
	
	# Estados de combate (usan animaciones de combat_animations/)
	if current_state == State.DEAD:
		return
	elif current_state == State.HURT:
		_set_texture(texture_hurt)  # Desde combat_animations/
		animate_sprite(delta)
		return
	elif current_state == State.KNOCKBACK:
		if direction > 0:
			_set_texture(texture_knockback_right)  # Desde combat_animations/
		else:
			_set_texture(texture_knockback_left)  # Desde combat_animations/
		animate_sprite(delta)
		return
	elif current_state == State.ATTACKING:
		_set_texture(texture_attack)  # Desde combat_animations/
		animate_sprite(delta)
		return

	# Estados normales (usan animaciones de assets/sprites/noct/)
	if is_crouching:
		_set_texture(texture_crouch)  # Desde carpeta principal
		animate_sprite(delta)
		idle_timer = 0.0
		return

	if not is_on_floor():
		if direction < 0:
			# Intentar usar animación izquierda específica
			if texture_jump_left:
				_set_texture(texture_jump_left)  # SaltarIzquierda.png desde normal_animations/
				player_visual.scale = Vector2(1, 1)  # SIN flip - el spritesheet ya está dibujado mirando a la izquierda
			else:
				# Fallback: usar animación derecha con flip
				_set_texture(texture_jump_right)  # SaltarDerecha.png desde normal_animations/
				player_visual.scale = Vector2(-1, 1)  # Flip horizontal para mirar a la izquierda
				print("Using right jump animation with flip for left jump")
			player_visual.frame = 0
		elif direction > 0:
			_set_texture(texture_jump_right)  # SaltarDerecha.png desde normal_animations/
			player_visual.scale = Vector2(1, 1)
			player_visual.frame = 0
		else:
			_set_texture(texture_jump)  # salto.png desde normal_animations/
			player_visual.scale = Vector2(1, 1)
			player_visual.frame = 0
		idle_timer = 0.0
	elif velocity.x != 0:
		if direction < 0:
			# Intentar usar animación izquierda específica
			if texture_run_left:
				_set_texture(texture_run_left)  # CaminarIzquierda.png desde normal_animations/
				player_visual.scale = Vector2(1, 1)  # SIN flip - el spritesheet ya está dibujado mirando a la izquierda
			else:
				# Fallback: usar animación derecha con flip
				_set_texture(texture_run_right)  # CaminarDerecha.png desde normal_animations/
				player_visual.scale = Vector2(-1, 1)  # Flip horizontal para mirar a la izquierda
		else:
			_set_texture(texture_run_right)  # CaminarDerecha.png desde normal_animations/
			player_visual.scale = Vector2(1, 1)
		animate_sprite(delta)
		idle_timer = 0.0
	else:
		idle_timer += delta
		if idle_timer >= IDLE_DELAY:
			_set_texture(texture_idle)  # Desde carpeta principal
			player_visual.scale = Vector2(1, 1)
			animate_sprite(delta, IDLE_ANIMATION_SPEED)  # Animación lenta de 2 segundos
		else:
			_set_texture(texture_idle)  # Desde carpeta principal
			player_visual.scale = Vector2(1, 1)
			player_visual.frame = 0

func _set_texture(texture):
	if texture and player_visual.texture != texture:
		player_visual.texture = texture
		player_visual.hframes = texture_frames[texture]
		player_visual.vframes = 1
		player_visual.region_enabled = false  # Asegurar que no haya recorte manual incorrecto

func animate_sprite(delta, custom_speed = ANIMATION_SPEED):
	animation_timer += delta
	if animation_timer >= custom_speed:
		animation_timer = 0.0
		current_frame = (current_frame + 1) % player_visual.hframes
		player_visual.frame = current_frame

# Función llamada SOLO cuando el jugador colisiona con un enemigo
func take_damage(amount: int, knockback_direction: int = 0):
	if is_dead or is_invincible:
		return
	
	health -= amount
	print("Jugador recibió daño. Salud: ", health, "/", max_health)
	
	# Activar i-frames
	is_invincible = true
	invincibility_timer = invincibility_duration
	
	if health <= 0:
		die()
	else:
		# Activar estado de knockback inmediatamente
		current_state = State.KNOCKBACK
		if knockback_direction > 0:
			# Enemigo está a la derecha, empujar a la izquierda
			_set_texture(texture_knockback_left)  # EmpujonIzquierda.png
		else:
			# Enemigo está a la izquierda, empujar a la derecha
			_set_texture(texture_knockback_right)  # EmpujonDerecha.png
		
		current_frame = 0
		
		# Aplicar knockback con fuerza hacia ARRIBA y horizontal más fuerte
		velocity.x = knockback_direction * 600.0  # Aumentado de 400 a 600
		velocity.y = -400.0  # Aumentado de -300 a -400 para saltar más alto
		
		# Programar retorno al estado normal después de 0.5 segundos
		await get_tree().create_timer(0.5).timeout
		current_state = State.NORMAL  # Volver a animaciones normales

# Función llamada SOLO cuando el jugador recibe knockback de un enemigo
func apply_knockback(direction: int):
	if is_dead:
		return
	current_state = State.KNOCKBACK
	velocity.x = direction * 500.0
	velocity.y = -300.0
	if direction > 0:
		_set_texture(texture_knockback_right)  # Animación de combate desde combat_animations/
	else:
		_set_texture(texture_knockback_left)  # Animación de combate desde combat_animations/
	current_frame = 0
	await get_tree().create_timer(0.5).timeout
	current_state = State.NORMAL  # Volver a animaciones normales

# Función llamada SOLO cuando la salud llega a 0 por daño de enemigos
func die():
	if is_dead:
		return
	is_dead = true
	current_state = State.DEAD
	print("Jugador murió")
	_set_texture(texture_death)  # Animación de combate desde combat_animations/
	current_frame = 0
	var death_frames = texture_frames[texture_death]
	for i in range(death_frames):
		await get_tree().create_timer(ANIMATION_SPEED).timeout
		current_frame = i
		player_visual.frame = current_frame
	# Congelar en el último frame
	current_frame = death_frames - 1
	player_visual.frame = current_frame
	set_physics_process(false)
	show_game_over()

# Función llamada SOLO cuando el jugador ataca (activada por input de ataque)
func perform_stick_attack():
	if is_dead or current_state == State.ATTACKING:
		return
	current_state = State.ATTACKING
	can_attack = false
	_set_texture(texture_attack)  # Animación de combate desde combat_animations/
	current_frame = 0
	var attack_frames = texture_frames[texture_attack]
	for i in range(attack_frames):
		await get_tree().create_timer(ANIMATION_SPEED).timeout
		current_frame = i
		player_visual.frame = current_frame
	current_state = State.NORMAL  # Volver a animaciones normales
	can_attack = true

func perform_attack():
	if weapon:
		can_attack = false
		is_attacking = true
		var tween = create_tween()
		tween.tween_property(player_visual, "rotation_degrees", 15.0, 0.05)
		tween.tween_property(player_visual, "rotation_degrees", 0.0, 0.05)
		weapon.attack()
		await weapon.attack_finished
		is_attacking = false
		can_attack = true

func show_game_over():
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		enemy.set_physics_process(false)
	
	# Cambiar directamente a la escena de Game Over
	get_tree().change_scene_to_file("res://scenes/game_over.tscn")

func _on_hurtbox_body_entered(body):
	if body and (body.is_in_group("enemies")):
		if current_state == State.NORMAL and not is_invincible:
			var knockback_dir = 1 if body.global_position.x > global_position.x else -1
			take_damage(25, knockback_dir)
