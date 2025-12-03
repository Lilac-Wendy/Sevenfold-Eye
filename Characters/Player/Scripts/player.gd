extends CharacterBody3D

@export var move_speed: float = 1.0
@export var jump_force: float = 4.5
@export var gravity: float = 10.0
@export var move_threshold: float = 0.1
@export var attack_speed: float = 2.0

@export var cat_max_speed: float = 8.0
@export var cat_ground_accel: float = 80.0
@export var cat_ground_decel: float = 60.0
@export var cat_friction: float = 8.0
@export var cat_air_accel: float = 12.0
@export var cat_slope_accel: float = 20.0

enum AttackGravityMode { NORMAL, FLOAT, STALL, SUSPEND }

@export_group("Combat Gravity")
@export var attack_gravity_mode: AttackGravityMode = AttackGravityMode.NORMAL
@export_range(0.0, 1.0) var attack_float_factor: float = 0.15 
@export var attack_stall_base_duration: float = 0.08
@export var attack_air_horizontal_lock_factor: float = 0.8

var _current_stall_timer: float = 0.0

@export_group("Jump")
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12
@export var jump_cut_multiplier: float = 2.5

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0

@onready var platform_animation_player: AnimationPlayer = $PlatformSwitchPlayer
@onready var sprite_animation_player: AnimationPlayer = $SpriteSheetPlayer
@onready var anim_hsm: LimboHSM = $AnimationHSM
@onready var tail_container: Node3D = $TailContainer
@onready var tail_animation_player: AnimationPlayer = $TailPlayer
@onready var attack_state: Node = $AnimationHSM/Attack
@onready var component_container: Node = $ComponentContainer
@onready var AttackComboTimer: Timer = $AttackComboTimer
@onready var AttackCooldownTimer: Timer = $AttackCooldownTimer
@onready var SwitchCooldown: Timer = $SwitchCooldown

enum State { IDLE, MOVING, JUMPING, PLATFORM_SWITCH, ATTACK }
var current_state: State = State.IDLE

enum Platform { A = 0, B = 1, C = 2 }
var current_platform: Platform = Platform.B

var target_platform_index: int = -1

var is_transitioning: bool = false
var last_facing_direction_x := 1.0
var current_combo_index := 0

var cat_velocity_x: float = 0.0

var _hsm_ready: bool = false

func _ready() -> void:
	global_position.z = 0.0
	_setup_timers()

	call_deferred("_initialize_hsm")

	if SwitchCooldown and not SwitchCooldown.timeout.is_connected(_on_switch_cooldown_finished):
		SwitchCooldown.timeout.connect(_on_switch_cooldown_finished)

func _initialize_hsm() -> void:
	"""Inicializa o HSM de forma segura e conecta sinais necessários"""
	if anim_hsm:

		if anim_hsm.has_signal("state_changed"):
			if not anim_hsm.state_changed.is_connected(_on_hsm_state_changed):
				anim_hsm.state_changed.connect(_on_hsm_state_changed)
			print("Sinal state_changed conectado com sucesso")
		else:
			print("HSM não possui signal 'state_changed' — pulando conexão")
		_hsm_ready = true
		print("HSM inicializado com sucesso")
	else:
		push_warning("HSM não encontrado - verifique a cena do player")

func _setup_timers() -> void:
	AttackComboTimer.one_shot = true 
	AttackCooldownTimer.one_shot = true
	SwitchCooldown.one_shot = true

func set_hsm_active(active: bool) -> void:
	if anim_hsm and _hsm_ready:
		anim_hsm.set_active(active)
		print("HSM ", "ativado" if active else "desativado")

func can_switch_platform() -> bool:
	var ready := SwitchCooldown.time_left <= 0 and not is_transitioning

	if not ready:
		print("[PlatformSwitch] BLOQUEADO → cooldown=", SwitchCooldown.time_left, " | transitioning=", is_transitioning)
	else:
		print("[PlatformSwitch] ✔ Pode trocar de plataforma")

	return ready

func start_switch_cooldown() -> void:
	print("[PlatformSwitch] Cooldown iniciado (", SwitchCooldown.wait_time, "s)")
	SwitchCooldown.start()

func _on_switch_cooldown_finished() -> void:
	print("[PlatformSwitch] Cooldown encerrado — troca permitida novamente")

func play_platform_transition_animation(current_platform: int, target_platform: int, input_dir: Vector2) -> bool:

	start_switch_cooldown()

	set_hsm_active(false)

	var anim_name = ""
	if current_platform == Platform.A and target_platform == Platform.B:
		anim_name = "Jump_A_to_B"
	elif current_platform == Platform.B and target_platform == Platform.A:
		anim_name = "Jump_B_to_A"
	elif current_platform == Platform.B and target_platform == Platform.C:
		anim_name = "Jump_B_to_C"
	elif current_platform == Platform.C and target_platform == Platform.B:
		anim_name = "Jump_C_to_B"

	if anim_name == "":
		print("✗ Nenhuma animação encontrada para esta transição")
		set_hsm_active(true)
		return false

	if sprite_animation_player and sprite_animation_player.is_playing():
		sprite_animation_player.stop()

	if platform_animation_player and platform_animation_player.is_playing():
		platform_animation_player.stop()

	var sprite_success = false
	var sprite_anim_name = _get_sprite_animation_name(current_platform, target_platform, input_dir)
	if sprite_animation_player and sprite_animation_player.has_animation(sprite_anim_name):
		sprite_animation_player.play(sprite_anim_name)
		sprite_success = true
	else:

		if sprite_animation_player and sprite_animation_player.has_animation(anim_name):
			sprite_animation_player.play(anim_name)
			sprite_success = true

	var physics_success = false
	if platform_animation_player and platform_animation_player.has_animation(anim_name):
		platform_animation_player.play(anim_name)
		physics_success = true

		if not platform_animation_player.animation_finished.is_connected(_on_platform_animation_finished):
			platform_animation_player.animation_finished.connect(_on_platform_animation_finished)
	else:
		set_hsm_active(true)

	return sprite_success or physics_success

func _get_sprite_animation_name(current_platform: int, target_platform: int, input_dir: Vector2) -> String:
	var is_moving_up = target_platform > current_platform

	var horizontal = 0
	if input_dir.x > 0.1:
		horizontal = 1
	elif input_dir.x < -0.1:
		horizontal = -1

	if is_moving_up:
		match horizontal:
			1:  return "JUMP_NORTHEAST"
			-1: return "JUMP_NORTHWEST"
			_:   return "JUMP_NORTH"
	else:
		match horizontal:
			1:  return "JUMP_SOUTHEAST"
			-1: return "JUMP_SOUTHWEST"
			_:   return "JUMP_SOUTH"

func _on_platform_animation_finished(anim_name: String):

	if platform_animation_player and platform_animation_player.animation_finished.is_connected(_on_platform_animation_finished):
		platform_animation_player.animation_finished.disconnect(_on_platform_animation_finished)

	set_hsm_active(true)

	if is_transitioning and target_platform_index != -1:
		current_platform = target_platform_index
		target_platform_index = -1
		is_transitioning = false
		current_state = State.IDLE

func _on_hsm_state_changed(new_state, old_state) -> void:

	if new_state and new_state is Object and new_state.has_method("get_name"):
		print("HSM mudou para estado: ", new_state.get_name())
	elif new_state:
		print("HSM mudou para estado: ", str(new_state))
	else:
		print("HSM mudou para estado: nulo")

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

	if is_transitioning:
		velocity.y = 0

		if Input.is_action_just_pressed("ui_accept"):
			_jump_buffer_timer = jump_buffer_time

		handle_tail_flip(input_dir, is_moving)
		update_facing(input_dir)
		move_and_slide()
		return

	if Input.is_action_just_pressed("attack") and current_state != State.ATTACK:
		_attack()

	if Input.is_action_just_pressed("up"):
		print("[Input] Tentando subir plataforma…")
	if Input.is_action_just_pressed("down"):
		print("[Input] Tentando descer plataforma…")

	if Input.is_action_just_pressed("up") and current_state != State.ATTACK:
		if can_switch_platform():
			var attempt = int(current_platform) + 1
			if attempt <= 2:
				print("[PlatformSwitch] Subida permitida")
				target_platform_index = attempt
				velocity.y = 0
				is_transitioning = true
				current_state = State.PLATFORM_SWITCH

				var anim_success = play_platform_transition_animation(int(current_platform), attempt, input_dir)
				if not anim_success:

					current_platform = attempt
					is_transitioning = false
					current_state = State.IDLE
			else:
				print("[PlatformSwitch] ❌ Subida negada — tentativa fora de limites")
		else:
			print("[PlatformSwitch] ❌ Subida negada — cooldown ativo")

	elif Input.is_action_just_pressed("down") and current_state != State.ATTACK:
		if can_switch_platform():
			var attempt2 = int(current_platform) - 1
			if attempt2 >= 0:
				print("[PlatformSwitch] Descida permitida")
				target_platform_index = attempt2
				velocity.y = 0
				is_transitioning = true
				current_state = State.PLATFORM_SWITCH

				var anim_success2 = play_platform_transition_animation(int(current_platform), attempt2, input_dir)
				if not anim_success2:
					current_platform = attempt2
					is_transitioning = false
					current_state = State.IDLE
			else:
				print("[PlatformSwitch] ❌ Descida negada — tentativa fora de limites")
		else:
			print("[PlatformSwitch] ❌ Descida negada — cooldown ativo")

	if not is_transitioning:
		match current_state:
			State.IDLE, State.MOVING:
				if Input.is_action_just_pressed("ui_accept"):
					_jump_buffer_timer = jump_buffer_time
				if (_jump_buffer_timer > 0.0) and on_floor:
					_jump_buffer_timer = 0.0
					_jump()
				elif is_moving and on_floor:
					if current_state != State.MOVING:
						current_state = State.MOVING
						_play_hsm("move")
				elif not is_moving and on_floor:
					if current_state != State.IDLE:
						current_state = State.IDLE
						_play_hsm("idle")
				elif not on_floor:
					current_state = State.JUMPING
					_play_hsm("jump")

			State.JUMPING:
				if on_floor:
					current_state = State.MOVING if is_moving else State.IDLE
					_play_hsm("move" if is_moving else "idle")

			State.ATTACK:
				if Input.is_action_just_pressed("ui_accept") and on_floor:
					_jump()

	if Input.is_action_just_pressed("ui_accept"):
		_jump_buffer_timer = jump_buffer_time

	if on_floor:
		_coyote_timer = coyote_time
	else:
		_coyote_timer = max(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)

	handle_tail_flip(input_dir, is_moving)
	update_facing(input_dir)
	_apply_hybrid_cat_physics(input_dir, on_floor, delta)

	if not is_transitioning and _jump_buffer_timer > 0.0:
		if on_floor or _coyote_timer > 0.0:
			_jump_buffer_timer = 0.0
			_jump()

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
	elif not on_floor and not is_transitioning:
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
		current_state = State.JUMPING
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
		if tail_animation_player and tail_animation_player.has_animation("IDLE"):
			if not tail_animation_player.is_playing() or tail_animation_player.current_animation != "IDLE":
				tail_animation_player.play("IDLE")
	if is_moving and abs(input_dir.x) > move_threshold:
		var new_facing = sign(input_dir.x)
		if new_facing != sign(tail_container.scale.x):
			tail_container.scale.x = new_facing
			tail_container.position.x += 0.02 * new_facing
		last_facing_direction_x = new_facing

func _play_hsm(event_name: String, cargo: Dictionary = {}) -> void:
	if not anim_hsm or not _hsm_ready:
		return
	cargo["player_ref"] = self

	if anim_hsm.has_method("dispatch"):
		anim_hsm.dispatch(event_name, cargo)
	else:
		print("[HSM] dispatch não disponível para evento:", event_name)

func register_component(node: Node) -> void:
	if not node:
		return
	component_container.add_child(node)
	if node.has_method("on_component_registered"):
		node.on_component_registered(self)
