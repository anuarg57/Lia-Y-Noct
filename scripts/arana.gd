extends CharacterBody2D

class_name Spider

enum EnemyState { PATROL, JUMP, ATTACK, HURT, DEAD }

const SPEED = 100.0
const JUMP_SPEED = 150.0
const GRAVITY = 400.0
const ANIMATION_SPEED = 0.1
const PATROL_DISTANCE = 150.0
const DETECTION_RANGE = 200.0
const ATTACK_RANGE = 80.0
const JUMP_FORCE = -200.0
const TURN_COOLDOWN = 0.4

var state: EnemyState = EnemyState.PATROL
var animation_timer: float = 0.0
var current_frame: int = 0
var direction: int = 1
var start_position: Vector2 = Vector2.ZERO
var health: int = 100
var max_health: int = 100
var is_dead: bool = false
var attack_cooldown: float = 0.0
var attack_state_timer: float = 0.0
var turn_cooldown: float = 0.0

# Texturas
var texture_walk_der = null
var texture_walk_izq = null
var texture_jump_der = null
var texture_jump_izq = null
var texture_attack_der = null
var texture_attack_izq = null
var texture_hurt_der = null
var texture_hurt_izq = null
var texture_death_der = null
var texture_death_izq = null

# Frame counts para cada animación
var frame_counts = {
	"walk": 5,
	"jump": 5,
	"attack": 5,
	"hurt": 4,
	"death": 5
}

# Velocidad por estado
var speed_by_state = {
	EnemyState.PATROL: SPEED,
	EnemyState.JUMP: SPEED * 1.5,
	EnemyState.ATTACK: SPEED * 0.5,
	EnemyState.HURT: 0,
	EnemyState.DEAD: 0
}

@onready var enemy_visual = $EnemyVisual
@onready var ledge_detector = $LedgeDetector
@onready var player_detector = $PlayerDetector

func _ready():
	start_position = global_position
	load_textures()
	setup_sprite()
	connect_hitbox()
	
	# Configurar RayCast2D
	if ledge_detector:
		ledge_detector.add_exception(self)
		ledge_detector.position = Vector2(20, 10)
		ledge_detector.target_position = Vector2(20, 30)
		ledge_detector.force_raycast_update()

func load_textures():
	var base_path = "res://assets/sprites/enemies/arana/"
	texture_walk_der = _load_texture(base_path + "arana_caminar_der.png")
	texture_walk_izq = _load_texture(base_path + "arana_caminar_izq.png")
	texture_jump_der = _load_texture(base_path + "arana_saltar_der.png")
	texture_jump_izq = _load_texture(base_path + "arana_saltar_izq.png")
	texture_attack_der = _load_texture(base_path + "arana_atacar_der.png")
	texture_attack_izq = _load_texture(base_path + "arana_atacar_izq.png")
	texture_hurt_der = _load_texture(base_path + "arana_recibir_dano_der.png")
	texture_hurt_izq = _load_texture(base_path + "arana_recibir_dano_izq.png")
	texture_death_der = _load_texture(base_path + "arana_morir_der.png")
	texture_death_izq = _load_texture(base_path + "arana_morir_izq.png")

func _load_texture(path):
	if ResourceLoader.exists(path):
		return load(path)
	print("Spider texture not found: ", path)
	return null

func setup_sprite():
	if texture_walk_der:
		set_animation_texture("walk", "der")

func set_animation_texture(anim_type: String, direction_suffix: String):
	var texture_key = "texture_" + anim_type
	if direction_suffix:
		texture_key += "_" + direction_suffix
	
	var texture = get(texture_key)
	var frame_count = frame_counts.get(anim_type, 4)
	
	if texture:
		enemy_visual.texture = texture
		enemy_visual.hframes = frame_count
		enemy_visual.vframes = 1
		enemy_visual.region_enabled = false
		enemy_visual.scale = Vector2(1, 1)
		current_frame = 0
		enemy_visual.frame = current_frame

func connect_hitbox():
	var hitbox = $Hitbox
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)

func _physics_process(delta):
	if is_dead:
		return
	
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	
	update_state(delta)
	update_movement(delta)
	update_animation(delta)
	
	attack_cooldown = max(0, attack_cooldown - delta)
	turn_cooldown = max(0, turn_cooldown - delta)
	if state == EnemyState.ATTACK:
		attack_state_timer += delta
	move_and_slide()

func update_state(delta):
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Estado DEAD tiene prioridad
	if health <= 0 and state != EnemyState.DEAD:
		change_state(EnemyState.DEAD)
		return
	
	# Si está en HURT, no cambiar estado hasta que termine
	if state == EnemyState.HURT:
		if animation_timer >= frame_counts["hurt"] * ANIMATION_SPEED:
			change_state(EnemyState.PATROL)
		return
	
	# Si está en ATTACK, no cambiar hasta que termine (usar timer de estado)
	if state == EnemyState.ATTACK:
		if attack_state_timer >= 1.0:  # Duración fija del ataque
			change_state(EnemyState.PATROL)
		return
	
	# Si está en JUMP, no cambiar hasta que aterrice
	if state == EnemyState.JUMP and is_on_floor():
		change_state(EnemyState.PATROL)
		return
	
	# Detectar jugador
	if distance_to_player < DETECTION_RANGE:
		# Saltar hacia el jugador si está lejos y en el suelo
		if distance_to_player > ATTACK_RANGE and is_on_floor():
			if state != EnemyState.JUMP:
				change_state(EnemyState.JUMP)
		# Atacar si está cerca
		elif distance_to_player <= ATTACK_RANGE and attack_cooldown <= 0:
			change_state(EnemyState.ATTACK)
			attack_cooldown = 1.0
	else:
		if state != EnemyState.PATROL:
			change_state(EnemyState.PATROL)

func update_movement(delta):
	velocity.x = 0
	
	match state:
		EnemyState.PATROL:
			velocity.x = direction * speed_by_state[state]
			
			# Verificar borde de plataforma solo cuando está en el suelo y no está en cooldown
			if is_on_floor() and turn_cooldown <= 0:
				if should_turn_at_edge():
					direction *= -1
					turn_cooldown = TURN_COOLDOWN
					# Voltear el RayCast para que apunte en la nueva dirección
					if ledge_detector:
						ledge_detector.position.x = abs(ledge_detector.position.x) * direction
						ledge_detector.target_position.x = abs(ledge_detector.target_position.x) * direction
						ledge_detector.force_raycast_update()
					# Voltear el sprite
					enemy_visual.flip_h = (direction < 0)
				# Verificar si está contra una pared
				if is_on_wall():
					direction *= -1
					turn_cooldown = TURN_COOLDOWN
					if ledge_detector:
						ledge_detector.position.x = abs(ledge_detector.position.x) * direction
						ledge_detector.target_position.x = abs(ledge_detector.target_position.x) * direction
						ledge_detector.force_raycast_update()
					enemy_visual.flip_h = (direction < 0)
				
		EnemyState.JUMP:
			var player = get_tree().get_first_node_in_group("player")
			if player:
				# Saltar hacia el jugador
				var direction_to_player = sign(player.global_position.x - global_position.x)
				velocity.x = direction_to_player * JUMP_SPEED
				if is_on_floor():
					velocity.y = JUMP_FORCE
				
		EnemyState.ATTACK:
			# No moverse durante ataque
			velocity.x = 0
			
		EnemyState.HURT:
			# No moverse durante daño
			velocity.x = 0
			
		EnemyState.DEAD:
			# No moverse cuando está muerto
			velocity.x = 0

func should_turn_at_edge() -> bool:
	var distance_from_start = global_position.x - start_position.x
	
	# Verificar distancia máxima de patrulla
	if abs(distance_from_start) >= PATROL_DISTANCE:
		return true
	
	# Verificar raycast solo cerca del límite de patrulla
	if abs(distance_from_start) >= PATROL_DISTANCE - 20:
		if ledge_detector and not ledge_detector.is_colliding():
			return true
	
	return false

func change_state(new_state: EnemyState):
	if state == new_state:
		return
	
	state = new_state
	animation_timer = 0.0
	current_frame = 0
	
	# Resetear timer de ataque cuando entra al estado ATTACK
	if new_state == EnemyState.ATTACK:
		attack_state_timer = 0.0
	
	# Configurar textura según estado y dirección
	var direction_suffix = "der" if direction >= 0 else "izq"
	var anim_type = ""
	
	match state:
		EnemyState.PATROL:
			anim_type = "walk"
		EnemyState.JUMP:
			anim_type = "jump"
		EnemyState.ATTACK:
			anim_type = "attack"
		EnemyState.HURT:
			anim_type = "hurt"
		EnemyState.DEAD:
			anim_type = "death"
	
	if anim_type:
		set_animation_texture(anim_type, direction_suffix)

func update_animation(delta):
	animation_timer += delta
	
	# Determinar velocidad de animación según estado
	var animation_speed = ANIMATION_SPEED
	match state:
		EnemyState.DEAD:
			animation_speed = ANIMATION_SPEED * 0.5  # Más lento para muerte
		EnemyState.HURT:
			animation_speed = ANIMATION_SPEED * 1.5  # Más rápido para daño
	
	if animation_timer >= animation_speed:
		animation_timer = 0.0
		current_frame = (current_frame + 1) % enemy_visual.hframes
		enemy_visual.frame = current_frame

func take_damage(amount: int, direction: int = 1):
	if is_dead:
		return
	
	health -= amount
	
	if health <= 0:
		change_state(EnemyState.DEAD)
		is_dead = true
	else:
		change_state(EnemyState.HURT)

func _on_hitbox_body_entered(body):
	if body.is_in_group("player") or body.has_method("take_damage"):
		body.take_damage(25, global_position.x)
