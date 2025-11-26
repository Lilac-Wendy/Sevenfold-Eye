extends LimboState

@export var animation_player: AnimationPlayer
@export var walk_east: String = "WALK_EAST"
@export var walk_west: String = "WALK_WEST"

var player
var current_animation: String = ""

func _enter(_msg := {}) -> void:
	player = get_agent()
	_update_animation()

func _update(delta: float) -> void:
	var input_x := (
		int(Input.is_action_pressed("right"))
		- int(Input.is_action_pressed("left"))
	)

	# Atualiza a animação sempre que a direção mudar
	_update_animation()

	if input_x == 0:
		dispatch(EVENT_FINISHED)

func _update_animation() -> void:
	if not player or not animation_player:
		return
	
	var target_animation = walk_east if player.last_facing_direction_x > 0 else walk_west
	
	# Só troca a animação se for diferente da atual
	if target_animation != current_animation and animation_player.has_animation(target_animation):
		current_animation = target_animation
		animation_player.play(target_animation)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") and not event.is_echo():
		print("[MOVE] attack → dispatch('attack')")
		dispatch("attack")

func _exit() -> void:
	if animation_player.is_playing():
		animation_player.stop()
	current_animation = ""
