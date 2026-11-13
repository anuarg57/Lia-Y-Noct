extends CharacterBody2D

class_name EnemyChaser

const SPEED = 120.0
const GRAVITY = 400.0
const ANIMATION_SPEED = 0.1
const CHASE_RANGE = 300.0
const PATROL_DISTANCE = 100.0
const TURN_COOLDOWN = 0.4
# Configuración exacta del spritesheet del enemigo
const ENEMY_FRAME_WIDTH = 60.0
const ENEMY_FRAME_HEIGHT = 60.0
const ENEMY_FRAME_COUNT = 6

var animation_timer: float = 0.0
var current_frame: int = 0
var direction: int = 1
var start_position: Vector2 = Vector2.ZERO
var is_chasing: bool = false
var turn_cooldown: float = 0.0

@onready var enemy_visual = $EnemyVisual
@onready var ledge_detector = $LedgeDetector
var player_ref: CharacterBody2D = null

# Cargar textura del enemigo en runtime
var texture_walk = null

func _ready():
	start_position = global_position
	
	# Cargar textura en runtime
	texture_walk = _load_texture("res://assets/sprites/enemies/AnimacionDeCaminata.png")
	
	# Configurar sprite visual con valores explícitos
	if texture_walk:
		enemy_visual.texture = texture_walk
		enemy_visual.hframes = ENEMY_FRAME_COUNT
		enemy_visual.vframes = 1
		enemy_visual.region_enabled = false
		enemy_visual.scale = Vector2(1, 1)
		print("Chaser configured: Frame Width: ", ENEMY_FRAME_WIDTH, " Frame Count: ", ENEMY_FRAME_COUNT)
	
	# Configurar RayCast2D
	if ledge_detector:
		ledge_detector.add_exception(self)
		ledge_detector.position = Vector2(30, 10)
		ledge_detector.target_position = Vector2(30, 30)
		ledge_detector.force_raycast_update()
	
	# Conectar hitbox
	var hitbox = $Hitbox
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)

func _load_texture(path):
	if ResourceLoader.exists(path):
		return load(path)
	print("Chaser texture not found: ", path)
	return null

func _physics_process(delta):
	if not player_ref:
		player_ref = get_tree().get_first_node_in_group("player")
	
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	
	var distance_to_player = 9999.0
	if player_ref:
		distance_to_player = global_position.distance_to(player_ref.global_position)
	
	# Actualizar cooldown de giro
	turn_cooldown = max(0, turn_cooldown - delta)
	
	if player_ref and distance_to_player < CHASE_RANGE:
		is_chasing = true
		if player_ref.global_position.x > global_position.x:
			direction = 1
		else:
			direction = -1
	else:
		is_chasing = false
		
		var distance_from_start = global_position.x - start_position.x
		var should_turn = false
		
		# Solo verificar bordes cuando está en el suelo y no está en cooldown
		if is_on_floor() and turn_cooldown <= 0:
			# Verificar raycast
			if ledge_detector and not ledge_detector.is_colliding():
				should_turn = true
			# Verificar distancia máxima de patrulla
			elif abs(distance_from_start) >= PATROL_DISTANCE:
				should_turn = true
			# Verificar si está contra una pared
			if is_on_wall():
				should_turn = true
		
		if should_turn:
			direction *= -1
			turn_cooldown = TURN_COOLDOWN
			# Voltear el RayCast para que apunte en la nueva dirección
			if ledge_detector:
				ledge_detector.position.x = abs(ledge_detector.position.x) * direction
				ledge_detector.target_position.x = abs(ledge_detector.target_position.x) * direction
				ledge_detector.force_raycast_update()
			# Voltear el sprite
			enemy_visual.flip_h = (direction < 0)
	
	velocity.x = direction * SPEED
	animate_enemy(delta)
	move_and_slide()

func animate_enemy(delta):
	animation_timer += delta
	if animation_timer >= ANIMATION_SPEED:
		animation_timer = 0.0
		current_frame = (current_frame + 1) % enemy_visual.hframes
		enemy_visual.frame = current_frame

func _on_hitbox_body_entered(body):
	print("Chaser hitbox collision detected with: ", body)
	# Verificación robusta: grupo o método
	if body.is_in_group("player") or body.has_method("take_damage"):
		print("Calling take_damage on player from chaser")
		body.take_damage(25, global_position.x)
	else:
		print("Body is not in player group and has no take_damage method")
