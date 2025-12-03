extends LimboState
class_name AttackState

@export var combo_sequence := ["THRUST", "SLASH", "SMASH"]
@export var base_lock_duration := 1.0
@export var animation_player: AnimationPlayer

var player
var queued_next_attack: bool = false

var connected := false

func _enter(_msg := {}) -> void:
	player = get_agent()
	queued_next_attack = false

	if not _validate_timers():
		dispatch(EVENT_FINISHED)
		return

	if not connected:
		_connect_timers()
		connected = true

	_start_attack()


func _exit() -> void:
	if player and is_instance_valid(player.AttackComboTimer):
		player.AttackComboTimer.stop()

	if player and is_instance_valid(player.AttackCooldownTimer):
		player.AttackCooldownTimer.stop()


func _validate_timers() -> bool:
	if not (player
		and is_instance_valid(player.AttackComboTimer)
		and is_instance_valid(player.AttackCooldownTimer)):
		
		push_error("[AttackState] Timers inválidos no player.")
		return false

	return true


func _connect_timers() -> void:
	player.AttackComboTimer.timeout.connect(_on_combo_timeout)
	player.AttackCooldownTimer.timeout.connect(_on_cooldown_finished)


# -------------------------
# CORE DO COMBO
# -------------------------
func _start_attack() -> void:
	var idx = player.current_combo_index

	if idx < 0 or idx >= combo_sequence.size():
		idx = 0
		player.current_combo_index = 0

	var anim = combo_sequence[idx]

	print("[AttackState] START ATTACK → (%d) %s" % [idx, anim])

	if not animation_player.has_animation(anim):
		push_error("[AttackState] Animação não encontrada: %s" % anim)
		dispatch(EVENT_FINISHED)
		return

	animation_player.speed_scale = float(player.attack_speed) if "attack_speed" in player else 1.0
	animation_player.play(anim)
	animation_player.seek(0.0, true)

	# janela do combo
	player.AttackComboTimer.stop()
	player.AttackComboTimer.wait_time = 0.8
	player.AttackComboTimer.start()

	# cooldown
	player.AttackCooldownTimer.stop()
	player.AttackCooldownTimer.wait_time = base_lock_duration
	player.AttackCooldownTimer.start()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") and not event.is_echo():
		if player.AttackComboTimer.time_left > 0.0:
			queued_next_attack = true
			print("[AttackState] Queued combo!")
		else:
			print("[AttackState] Combo window fechada")


func _on_combo_timeout() -> void:
	print("[AttackState] Combo window expirou")


func _on_cooldown_finished() -> void:
	print("[AttackState] Cooldown terminou | queued =", queued_next_attack)

	if queued_next_attack:
		queued_next_attack = false

		var last_index := combo_sequence.size() - 1

		if player.current_combo_index < last_index:
			player.current_combo_index += 1
		else:
			player.current_combo_index = 0  # loop

		_start_attack()
		return

	# sem combo → fim
	print("[AttackState] COMBO FINALIZADO")
	player.current_combo_index = 0
	dispatch(EVENT_FINISHED)
