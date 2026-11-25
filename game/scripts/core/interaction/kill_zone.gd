class_name KillZone
extends Area2D
## Bottomless pit / hazard volume: kills the player on touch, which starts the
## death -> respawn flow (Player.kill()). Layer: none, mask: Player.

signal player_killed(player: Player)


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	var p := body as Player
	if p and not p.is_dead():
		p.kill()
		player_killed.emit(p)
