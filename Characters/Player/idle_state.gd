extends LimboState

@export var animation_player: AnimationPlayer
@export var idle_east: String = "IDLE_EAST"
@export var idle_west: String = "IDLE_WEST"

var player

func _enter(_msg := {}) -> void:
	player = get_agent()
	var anim_name = idle_east if player.last_facing_direction_x > 0 else idle_west
	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)

func _update(delta: float) -> void:
	var input_dir = Input.get_vector("left", "right", "up", "down")
	if input_dir.length() > player.move_threshold:
		dispatch("move")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") and not event.is_echo():
		print("[IDLE] attack → dispatch('attack')")
		dispatch("attack")

func _exit() -> void:
	if animation_player.is_playing():
		animation_player.stop()
