class_name BossFightTrigger
extends Area2D
## Starts a Boss fight when the player (body or Hurtbox on layer PLAYER) enters.
## One-shot. Put it at the arena entrance, after the pre-boss checkpoint.

signal triggered

@export var boss: Boss
## Disabled triggers ignore the player.
@export var enabled: bool = true

var has_triggered: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	monitoring = true
	monitorable = false
	body_entered.connect(_on_entered)
	area_entered.connect(_on_entered)


## Starts the fight (also callable from scripts / tests).
func trigger() -> void:
	if has_triggered or not enabled:
		return
	has_triggered = true
	if boss and is_instance_valid(boss):
		boss.start_fight()
	triggered.emit()


func _on_entered(node: Node) -> void:
	if node.is_in_group(Layers.GROUP_PLAYER) or (node.owner and node.owner.is_in_group(Layers.GROUP_PLAYER)) \
			or (node.get_parent() and node.get_parent().is_in_group(Layers.GROUP_PLAYER)):
		trigger()
