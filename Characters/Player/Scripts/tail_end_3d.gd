extends AnimatableBody3D
@export var player: Node3D
func _physics_process(_delta):
	if player == null:
		return
	var to_player = player.global_position - global_position
	to_player.z = 0
	if to_player.length() < 0.001:
		return
	var angle = atan2(to_player.y, to_player.x)
	var facing = player.last_facing_direction_x 
	if facing < 0:
		angle = PI - angle   
	angle += PI
	rotation.z = angle
