extends Camera3D

@export_category("Target")
## Nó que a câmera deve seguir
@export var player: Node3D

@export_category("Follow Settings")
## Quanto maior, mais rápido a câmera chega no alvo
@export var follow_speed := 6.0

@export_category("Deadzone Settings")
## Tamanho da deadzone em unidades do mundo (X = horizontal, Z = profundidade, Y = altura)
@export var deadzone_size := Vector3(3.0, 2.0, 2.0)  # X, Z, Y
## Se true, ativa a deadzone (recomendado para platformers)
@export var use_deadzone := true

## Altura mínima da câmera em relação ao mundo
@export var min_height: float = 2.0
## Altura máxima da câmera em relação ao mundo
@export var max_height: float = 10.0

var _current_spring_arm_pos: Vector3 = Vector3.ZERO

func _ready() -> void:
	# Armazena a posição inicial do SpringArm3D (pai)
	_current_spring_arm_pos = get_parent().global_transform.origin

func _physics_process(delta: float) -> void:
	if not player:
		return

	# Posição atual do SpringArm3D (pai da câmera)
	var current_pos := _current_spring_arm_pos
	# Posição desejada do player
	var target := player.global_transform.origin

	# =========================================
	# Sem deadzone → seguir suavizado direto (incluindo Y)
	# =========================================
	if not use_deadzone:
		# Segue o player em todos os eixos
		var smooth = current_pos.lerp(target, follow_speed * delta)
		# Limita a altura da câmera
		smooth.y = clamp(smooth.y, min_height, max_height)
		_update_spring_arm_position(smooth)
		return

	# =============================
	# COM DEADZONE 3D
	# =============================
	var dx = target.x - current_pos.x
	var dy = target.y - current_pos.y
	var dz = target.z - current_pos.z

	var half_w = deadzone_size.x * 0.5
	var half_h = deadzone_size.z * 0.5  # Z para profundidade
	var half_v = deadzone_size.y * 0.5  # Y para altura

	var move_x := 0.0
	var move_z := 0.0
	var move_y := 0.0

	# Deadzone horizontal (X)
	if dx > half_w:
		move_x = dx - half_w
	elif dx < -half_w:
		move_x = dx + half_w

	# Deadzone vertical (Y - altura)
	if dy > half_v:
		move_y = dy - half_v
	elif dy < -half_v:
		move_y = dy + half_v

	# Deadzone profundidade (Z)
	if dz > half_h:
		move_z = dz - half_h
	elif dz < -half_h:
		move_z = dz + half_h

	# Novo ponto ideal para o SpringArm3D
	var desired_pos := current_pos + Vector3(move_x, move_y, move_z)
	
	# Limita a altura da câmera
	desired_pos.y = clamp(desired_pos.y, min_height, max_height)
	
	# Suavização
	var final_pos = current_pos.lerp(desired_pos, follow_speed * delta)
	
	# Aplica ao SpringArm3D
	_update_spring_arm_position(final_pos)

func _update_spring_arm_position(position: Vector3) -> void:
	# Atualiza a posição do SpringArm3D (pai)
	get_parent().global_transform.origin = position
	_current_spring_arm_pos = position
