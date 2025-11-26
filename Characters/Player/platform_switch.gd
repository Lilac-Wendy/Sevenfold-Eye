extends LimboState

@export var platform_animation_player: AnimationPlayer  # Para as animações de plataforma (JUMP_NORTH, etc)
@export var normal_animation_player: AnimationPlayer    # AnimationPlayer normal do personagem
@export var player_ref: Node = null

enum Platform { A, B, C }
enum JumpDirection { NORTH, SOUTH, SOUTHEAST, SOUTHWEST, NORTHEAST, NORTHWEST }

var target_platform := -1
var last_input_direction := Vector2.ZERO

func _enter(msg := {}):
	if not player_ref:
		player_ref = msg.get("player_ref", null)
	if not player_ref:
		dispatch(EVENT_FINISHED)
		return

	player_ref.is_transitioning = true

	# Para a animação normal do personagem durante a transição
	if normal_animation_player and normal_animation_player.is_playing():
		normal_animation_player.stop()

	# Configura o platform_animation_player se não estiver exportado
	if not platform_animation_player:
		# Tenta encontrar por nomes comuns
		var possible_node_names = ["PlatformAnimationPlayer", "PlatformSpritePlayer", "SpriteAnimationPlayer"]
		for node_name in possible_node_names:
			if player_ref.has_node(node_name):
				platform_animation_player = player_ref.get_node(node_name)
				break
	
	# Fallback para o animation player original se o específico não existir
	if not platform_animation_player:
		if player_ref.has_node("PlatformSwitchPlayer"):
			platform_animation_player = player_ref.get_node("PlatformSwitchPlayer")
	
	# Último fallback: usa o animation player normal
	if not platform_animation_player:
		platform_animation_player = normal_animation_player
	
	if not platform_animation_player:
		push_error("PlatformSwitch: Nenhum AnimationPlayer encontrado!")
		_finish_instant()
		return

	print("PlatformSwitch: Usando AnimationPlayer: ", platform_animation_player.name)

	if not platform_animation_player.is_connected("animation_finished", Callable(self, "_on_finished")):
		platform_animation_player.animation_finished.connect(Callable(self, "_on_finished"))

	var current = int(player_ref.current_platform)
	var target = player_ref.target_platform_index
	player_ref.target_platform_index = -1

	if target == -1 or target == current:
		_finish_instant()
		return

	target_platform = target
	
	# Captura a direção do input atual para determinar a animação
	last_input_direction = Input.get_vector("left", "right", "up", "down")
	
	var anim = _get_directional_anim_name(current, target, last_input_direction)
	print("PlatformSwitch: Tentando animação: ", anim)
	
	if anim != "" and platform_animation_player.has_animation(anim):
		print("PlatformSwitch: Reproduzindo animação: ", anim)
		platform_animation_player.play(anim)
	else:
		# Fallback para animação padrão se a direcional não existir
		var fallback_anim = _get_fallback_anim_name(current, target)
		print("PlatformSwitch: Fallback para animação: ", fallback_anim)
		
		if fallback_anim != "" and platform_animation_player.has_animation(fallback_anim):
			platform_animation_player.play(fallback_anim)
		else:
			print("PlatformSwitch: Nenhuma animação encontrada, finalizando instantaneamente")
			_finalize_switch()

func _get_directional_anim_name(current_platform: int, target_platform_idx: int, input_dir: Vector2) -> String:
	# Determina a direção geral do salto (subindo ou descendo)
	var is_moving_up = target_platform_idx < current_platform
	
	# Normaliza e classifica a direção do input
	var jump_direction = _classify_jump_direction(input_dir, is_moving_up)
	
	# Constrói o nome da animação baseado na direção
	match jump_direction:
		JumpDirection.NORTH:
			return "JUMP_NORTH"
		JumpDirection.SOUTH:
			return "JUMP_SOUTH"
		JumpDirection.SOUTHEAST:
			return "JUMP_SOUTHEAST"
		JumpDirection.SOUTHWEST:
			return "JUMP_SOUTHWEST"
		JumpDirection.NORTHEAST:
			return "JUMP_NORTHEAST"
		JumpDirection.NORTHWEST:
			return "JUMP_NORTHWEST"
	
	return ""
func _classify_jump_direction(input_dir: Vector2, is_moving_up: bool) -> int:
	# Se não há input significativo, usa direção padrão baseada no movimento vertical
	if input_dir.length() < 0.1:
		return JumpDirection.NORTH if is_moving_up else JumpDirection.SOUTH
	
	# Normaliza a direção para classificação
	var normalized_dir = input_dir.normalized()
	var angle_deg = rad_to_deg(normalized_dir.angle())
	
	# Ajusta o ângulo para ficar entre 0-360
	if angle_deg < 0:
		angle_deg += 360
	
	# Classifica a direção baseada em setores angulares
	if angle_deg >= 337.5 or angle_deg < 22.5:
		return JumpDirection.NORTH  # Para cima/Up
	elif angle_deg >= 22.5 and angle_deg < 67.5:
		return JumpDirection.NORTHEAST  # Diagonal superior direita
	elif angle_deg >= 67.5 and angle_deg < 112.5:
		return JumpDirection.SOUTHEAST  # Para direita/Right (considerado sudeste)
	elif angle_deg >= 112.5 and angle_deg < 157.5:
		return JumpDirection.SOUTHEAST  # Diagonal inferior direita
	elif angle_deg >= 157.5 and angle_deg < 202.5:
		return JumpDirection.SOUTH  # Para baixo/Down
	elif angle_deg >= 202.5 and angle_deg < 247.5:
		return JumpDirection.SOUTHWEST  # Diagonal inferior esquerda
	elif angle_deg >= 247.5 and angle_deg < 292.5:
		return JumpDirection.NORTHWEST  # Para esquerda/Left (considerado noroeste)
	else: # 292.5 - 337.5
		return JumpDirection.NORTHWEST  # Diagonal superior esquerda

func _get_fallback_anim_name(current, target):
	# Fallback para as animações originais caso as direcionais não existam
	if current == Platform.A and target == Platform.B: return "Jump_A_to_B"
	if current == Platform.B and target == Platform.A: return "Jump_B_to_A"
	if current == Platform.B and target == Platform.C: return "Jump_B_to_C"
	if current == Platform.C and target == Platform.B: return "Jump_C_to_B"
	return ""

func _on_finished(anim_name):
	print("PlatformSwitch: Animação finalizada: ", anim_name)
	if anim_name.begins_with("JUMP_") or anim_name.begins_with("Jump_"):
		_finalize_switch()

func _finish_instant():
	print("PlatformSwitch: Finalização instantânea")
	_restore_player_physics()
	dispatch(EVENT_FINISHED)

func _finalize_switch() -> void:
	print("PlatformSwitch: Finalizando troca de plataforma")
	if player_ref and target_platform != -1:
		player_ref.current_platform = target_platform
		player_ref.is_transitioning = false
		
		# Para a animação de plataforma
		if platform_animation_player and platform_animation_player.is_playing():
			platform_animation_player.stop()
			
	dispatch(EVENT_FINISHED)

func _restore_player_physics():
	if player_ref:
		player_ref.is_transitioning = false
