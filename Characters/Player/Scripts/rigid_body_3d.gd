extends RigidBody3D

@export var target: Node3D # Arraste o nó do Player aqui no editor
@onready var hinge_joint: HingeJoint3D = $"../HingeJoint3D" # Ajuste o caminho

func _physics_process(delta):
	if target and is_instance_valid(hinge_joint):
		# 1. Calcular a direção e o ângulo alvo em Y (o eixo da dobradiça)
		var direction_to_target = (target.global_position - global_position).normalized()
		var target_angle_rad = atan2(direction_to_target.x, direction_to_target.z)
		
		# 2. Obter o ângulo atual do objeto (BodyB_Object)
		var current_angle_rad = rotation.y
		
		# 3. Calcular a diferença de ângulo
		var angle_difference = target_angle_rad - current_angle_rad
		# Normalizar o ângulo entre -PI e PI para a rotação mais curta
		angle_difference = fposmod(angle_difference + PI, 2 * PI) - PI
		
		# 4. Ajustar a velocidade do motor para girar em direção ao alvo
		var motor_speed = 10.0 # Velocidade de rotação (ajuste conforme necessário)
		var motor_velocity = motor_speed * sign(angle_difference)

		# A HingeJoint não tem um 'set_target_angle' direto. 
		# Você ajusta a velocidade para que ela gire em direção ao alvo.

		# Se o ângulo for muito pequeno, pare o motor
		if abs(angle_difference) < deg_to_rad(1.0):
			motor_velocity = 0.0
		
		hinge_joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, motor_velocity)
		
		# Opcional: Para impedir que o objeto tombe, force a rotação X e Z a zero
		# para manter o objeto na vertical, dependendo do seu RigidBody3D.
		# global_rotation.x = 0
		# global_rotation.z = 0
