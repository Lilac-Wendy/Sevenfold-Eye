extends CharacterBody3D

# ==========================
# === CONFIGURAÇÕES
# ==========================
@export var move_speed: float = 1.0
@export var jump_force: float = 4.5
@export var gravity: float = 10.0
@export var move_threshold: float = 0.1
@export var attack_speed: float = 2.0

# --- Cat Physics
@export var cat_max_speed: float = 8.0
@export var cat_ground_accel: float = 80.0
@export var cat_ground_decel: float = 60.0
@export var cat_friction: float = 8.0
@export var cat_air_accel: float = 12.0
@export var cat_slope_accel: float = 20.0

# ==========================
# === COMBAT GRAVITY (NOVO)
# ==========================
enum AttackGravityMode { NORMAL, FLOAT, STALL, SUSPEND }

@export_group("Combat Gravity")
@export var attack_gravity_mode: AttackGravityMode = AttackGravityMode.NORMAL
@export_range(0.0, 1.0) var attack_float_factor: float = 0.15 
@export var attack_stall_base_duration: float = 0.08
@export var attack_air_horizontal_lock_factor: float = 0.8

var _current_stall_timer: float = 0.0

# ==========================
# === JUMP TWEAKS
# ==========================
@export_group("Jump")
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12
@export var jump_cut_multiplier: float = 2.5

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0

# ==========================
# === REFERÊNCIAS
# ==========================
@onready var platform_animation_player: AnimationPlayer = $PlatformSwitchPlayer
@onready var anim_hsm: LimboHSM = $AnimationHSM
@onready var tail_container: Node3D = $TailContainer
@onready var tail_animation_player: AnimationPlayer = $TailPlayer
@onready var attack_state: Node = $AnimationHSM/Attack

@onready var AttackComboTimer: Timer = $AttackComboTimer
@onready var AttackCooldownTimer: Timer = $AttackCooldownTimer

# ==========================
# === ESTADO DO JOGO
# ==========================
enum State { IDLE, WALK, JUMP, FALL, ATTACK, TRANSITION }
var current_state: State = State.IDLE

enum Platform { A = 0, B = 1, C = 2 }
var current_platform: Platform = Platform.B

# Intenção de trocar de plataforma
var target_platform_index: int = -1

var is_transitioning: bool = false
var last_facing_direction_x := 1.0
var current_combo_index := 0

# Física interna
var cat_velocity_x: float = 0.0

func _ready() -> void:
	global_position.z = 0.0
	_setup_timers()

func _setup_timers() -> void:
	AttackComboTimer.one_shot = true
	AttackCooldownTimer.one_shot = true

func _apply_hybrid_cat_physics(input_dir: Vector2, on_floor: bool, delta: float) -> void:
	var desired: float = input_dir.x * cat_max_speed

	if current_state == State.ATTACK and not on_floor and attack_air_horizontal_lock_factor > 0.0:
		var lock_strength = clamp(attack_air_horizontal_lock_factor, 0.0, 1.0)
		var effective_air_accel = cat_air_accel * (1.0 - lock_strength)
		cat_velocity_x = move_toward(cat_velocity_x, desired, effective_air_accel * delta)
		cat_velocity_x = move_toward(cat_velocity_x, 0, cat_friction * lock_strength * delta)
		velocity.x = cat_velocity_x
		return

	if on_floor:
		if is_on_floor():
			var floor_normal = get_floor_normal()
			cat_velocity_x += -floor_normal.x * cat_slope_accel * delta

		if abs(desired) > abs(cat_velocity_x):
			cat_velocity_x = move_toward(cat_velocity_x, desired, cat_ground_accel * delta)
		else:
			cat_velocity_x = move_toward(cat_velocity_x, desired, cat_ground_decel * delta)

		if abs(input_dir.x) < move_threshold:
			cat_velocity_x = move_toward(cat_velocity_x, 0, cat_friction * delta)
	else:
		cat_velocity_x = move_toward(cat_velocity_x, desired, cat_air_accel * delta)
		
	velocity.x = cat_velocity_x


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	var input_dir: Vector2 = Input.get_vector("left", "right", "up", "down")
	var is_moving: bool = input_dir.length() > move_threshold

	# Se estiver em transição de plataforma, bloqueia a lógica normal
	if is_transitioning:
		# CORREÇÃO: Zera a velocidade Y durante a transição para evitar voos/caídas
		velocity.y = 0
		
		# Captura input de pulo DURANTE transição
		if Input.is_action_just_pressed("ui_accept"):
			_jump_buffer_timer = jump_buffer_time
			
		handle_tail_flip(input_dir, is_moving)
		update_facing(input_dir)
		move_and_slide()
		return

	# Input de ataque
	if Input.is_action_just_pressed("attack") and current_state != State.ATTACK:
		_attack()
	
	# Lógica normal (sem transição)
	# --- TROCA DE PLATAFORMA ---
	if Input.is_action_just_pressed("up") and current_state != State.ATTACK:
		var attempt = int(current_platform) - 1
		if attempt >= 0:
			target_platform_index = attempt
			# CORREÇÃO: Zera velocidade Y ao iniciar transição
			velocity.y = 0
			is_transitioning = true
			current_state = State.TRANSITION
			_play_hsm("platform_switch")
			
	elif Input.is_action_just_pressed("down") and current_state != State.ATTACK:
		var attempt2 = int(current_platform) + 1
		if attempt2 <= 2:
			target_platform_index = attempt2
			# CORREÇÃO: Zera velocidade Y ao iniciar transição
			velocity.y = 0
			current_state = State.TRANSITION
			is_transitioning = true
			_play_hsm("platform_switch")
	else:
		# resto dos estados (movimento, pulo etc)
		match current_state:
			State.IDLE, State.WALK:
				if Input.is_action_just_pressed("ui_accept"):
					_jump_buffer_timer = jump_buffer_time
				if (_jump_buffer_timer > 0.0) and on_floor:
					_jump_buffer_timer = 0.0
					_jump()
				elif is_moving and on_floor:
					if current_state != State.WALK:
						current_state = State.WALK
						_play_hsm("move")
				elif not is_moving and on_floor:
					if current_state != State.IDLE:
						current_state = State.IDLE
						_play_hsm("idle")
				elif not on_floor:
					current_state = State.JUMP if velocity.y > 0 else State.FALL
					_play_hsm("jump" if velocity.y > 0 else "fall")

			State.JUMP, State.FALL:
				if on_floor:
					current_state = State.WALK if is_moving else State.IDLE
					_play_hsm("move" if is_moving else "idle")

			State.ATTACK:
				if Input.is_action_just_pressed("ui_accept") and on_floor:
					_jump()

	# ADICIONAR: Buffer de pulo GLOBAL (captura input em qualquer estado)
	if Input.is_action_just_pressed("ui_accept"):
		_jump_buffer_timer = jump_buffer_time
	
	# Atualiza timers de pulo
	if on_floor:
		_coyote_timer = coyote_time
	else:
		_coyote_timer = max(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)

	handle_tail_flip(input_dir, is_moving)
	update_facing(input_dir)
	_apply_hybrid_cat_physics(input_dir, on_floor, delta)

	# CORREÇÃO MELHORADA: Verificação de pulo APÓS transição de plataforma
	# Usando um sistema mais robusto que verifica se acabou de sair de uma transição
	if not is_transitioning and _jump_buffer_timer > 0.0:
		# Pequeno delay para garantir que a física esteja estabilizada
		if on_floor or _coyote_timer > 0.0:
			_jump_buffer_timer = 0.0
			_jump()

	
	# Gravidade customizada durante ataque
	if current_state == State.ATTACK and not on_floor:
		match attack_gravity_mode:
			AttackGravityMode.NORMAL:
				velocity.y -= gravity * delta
			AttackGravityMode.FLOAT:
				if velocity.y > 0:
					velocity.y = -0.1
				velocity.y -= gravity * attack_float_factor * delta
			AttackGravityMode.SUSPEND:
				velocity.y = 0
				velocity.x = 0
			AttackGravityMode.STALL:
				if _current_stall_timer > 0.0:
					velocity.y = 0
					velocity.x = 0
					_current_stall_timer -= delta
				else:
					velocity.y -= gravity * delta
	elif not on_floor and not is_transitioning:  # CORREÇÃO: Não aplica gravidade durante transição
		if velocity.y > 0 and not Input.is_action_pressed("ui_accept"):
			velocity.y -= gravity * jump_cut_multiplier * delta
		else:
			velocity.y -= gravity * delta
	else:
		velocity.y = max(velocity.y, 0)

	move_and_slide()
	
func _jump() -> void:
	if _coyote_timer > 0.0 or is_on_floor():
		velocity.y = jump_force
		current_state = State.JUMP
		_play_hsm("jump")
		_coyote_timer = 0.0
		_jump_buffer_timer = 0.0

func _attack() -> void:
	if current_state == State.ATTACK:
		return
	if attack_gravity_mode == AttackGravityMode.STALL:
		_current_stall_timer = attack_stall_base_duration / max(attack_speed, 0.1)
	else:
		_current_stall_timer = 0.0
	current_combo_index = 0
	current_state = State.ATTACK
	_play_hsm("attack", {"combo_start_index": current_combo_index})

func update_facing(input_dir: Vector2) -> void:
	if abs(input_dir.x) > 0.01:
		last_facing_direction_x = sign(input_dir.x)

func handle_tail_flip(input_dir: Vector2, is_moving: bool) -> void:
	if current_state != State.ATTACK:
		if tail_animation_player.has_animation("IDLE"):
			if not tail_animation_player.is_playing() or tail_animation_player.current_animation != "IDLE":
				tail_animation_player.play("IDLE")
	if is_moving and abs(input_dir.x) > move_threshold:
		var new_facing = sign(input_dir.x)
		if new_facing != sign(tail_container.scale.x):
			tail_container.scale.x = new_facing
			tail_container.position.x += 0.02 * new_facing
		last_facing_direction_x = new_facing

func _play_hsm(event_name: String, cargo: Dictionary = {}) -> void:
	if not anim_hsm:
		return
	cargo["player_ref"] = self
	anim_hsm.dispatch(event_name, cargo)
