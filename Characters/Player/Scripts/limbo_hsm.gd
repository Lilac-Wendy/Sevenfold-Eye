extends LimboHSM

@export var idle_state: LimboState
@export var move_state: LimboState
@export var jumping_state: LimboState
@export var falling_state: LimboState
@export var attack_state: LimboState
@export var platform_state: LimboState

func _ready() -> void:
	call_deferred("_init_hsm")

func _init_hsm() -> void:
	if not (idle_state and move_state and jumping_state and attack_state and platform_state):
		push_error("HSM: estados não atribuídos")
		return

	set_initial_state(idle_state)

	# transições normais
	add_transition(idle_state, move_state, "move")
	add_transition(idle_state, jumping_state, "jump")
	add_transition(idle_state, attack_state, "attack")
	add_transition(move_state, idle_state, move_state.EVENT_FINISHED)
	add_transition(move_state, jumping_state, "jump")
	add_transition(move_state, attack_state, "attack")
	add_transition(jumping_state, idle_state, jumping_state.EVENT_FINISHED)
	add_transition(jumping_state, attack_state, "attack")
	add_transition(attack_state, idle_state, attack_state.EVENT_FINISHED)

	# transições para plataforma
	add_transition(idle_state, platform_state, "platform_switch")
	add_transition(move_state, platform_state, "platform_switch")
	add_transition(jumping_state, platform_state, "platform_switch")
	add_transition(attack_state, platform_state, "platform_switch")
	add_transition(falling_state, platform_state, "platform_switch")

	# quando platform_state terminar, voltar para idle
	add_transition(platform_state, idle_state, platform_state.EVENT_FINISHED)

	initialize(get_parent())
	set_active(true)

	# Conectar mudança de estado para debug, se quiser
	self.connect("active_state_changed", Callable(self, "_on_state_changed"))
