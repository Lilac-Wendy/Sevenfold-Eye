extends LimboState
@export var animation_player: AnimationPlayer
@export var jump_east: String = "JUMP_EAST"
@export var jump_west: String = "JUMP_WEST"

var player: Node
var animation_finished: bool = false

func _enter(_msg := {}) -> void:
	player = get_agent()

	animation_finished = false

	if not animation_player.animation_finished.is_connected(self._on_finished):
		animation_player.animation_finished.connect(self._on_finished)

	var anim_name = jump_east if player.last_facing_direction_x > 0 else jump_west
	if animation_player.has_animation(anim_name):
		print("[Jumping] play anim=%s" % anim_name)
		animation_player.play(anim_name)
	else:
		push_warning("Jumping: animação %s não existe" % anim_name)
		dispatch(EVENT_FINISHED)

func _update(delta: float) -> void:
	if not player:
		return

	# Se já animou e pousou, termina
	if animation_finished and player.is_on_floor():
		print("[Jumping] Player pousou, finalizando")
		dispatch(EVENT_FINISHED)

func _on_finished(anim_name: String) -> void:
	print("[Jumping] Anim terminou:", anim_name)
	animation_finished = true

func _exit() -> void:
	if animation_player.animation_finished.is_connected(self._on_finished):
		animation_player.animation_finished.disconnect(self._on_finished)
