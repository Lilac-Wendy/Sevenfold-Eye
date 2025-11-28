extends LimboState

@export var animation_player: AnimationPlayer
@export var idle_east: String = "IDLE_EAST"
@export var idle_west: String = "IDLE_WEST"

var player
var current_animation: String = ""

func _enter(_msg := {}) -> void:
	player = get_agent()
	_update_animation()

func _update(delta: float) -> void:
	var input_dir = Input.get_vector("left", "right", "up", "down")
	
	# CORREÇÃO: Só muda para move se houver input horizontal significativo
	if abs(input_dir.x) > player.move_threshold:
		dispatch("move")

func _update_animation() -> void:
	if not player or not animation_player:
		return
	
	var target_animation = idle_east if player.last_facing_direction_x > 0 else idle_west
	
	# Só troca a animação se for diferente da atual
	if target_animation != current_animation and animation_player.has_animation(target_animation):
		current_animation = target_animation
		animation_player.play(target_animation)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") and not event.is_echo():
		print("[IDLE] attack → dispatch('attack')")
		dispatch("attack")

func _exit() -> void:
	if animation_player.is_playing():
		animation_player.stop()
	current_animation = ""
