extends LimboState

@export var player_ref: Node = null

func _enter(msg := {}):
	if not player_ref:
		player_ref = msg.get("player_ref", null)
	if not player_ref:
		dispatch(EVENT_FINISHED)
		return
	
	print("PlatformSwitch: Estado iniciado (apenas como fallback)")
	
	# Este estado agora é apenas um fallback
	# A animação real é controlada pelo player.gd diretamente
	
	# Espera um pouco e finaliza
	await get_tree().create_timer(0.1).timeout
	dispatch(EVENT_FINISHED)

func _exit():
	# Limpeza se necessário
	pass
