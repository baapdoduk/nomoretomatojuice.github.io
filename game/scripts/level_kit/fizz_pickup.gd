class_name FizzPickup
extends Area2D
## Fizz: currency bubble. Touch -> GameState.add_coins(value) once, short pop,
## then frees itself. Not a milestone: Fizz reverts with a death like other
## snapshot progress. Layer: none, mask: Player.
## Visuals live in the swappable `Visual` child (placeholder: FizzVisual), which
## reads `pop_progress` (-1 idle, 0..1 popping).

signal collected(value: int)

@export var value: int = 1
## Seconds of the pop before the node frees itself (0 = free at once).
@export var pop_time: float = 0.25

var is_collected: bool = false
var pop_progress: float = -1.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	monitoring = true
	monitorable = false
	KitUtil.ensure_rect_shape(self, Vector2(12, 12), Vector2.ZERO)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if pop_progress >= 0.0:
		pop_progress += delta / maxf(pop_time, 0.01)
		if pop_progress >= 1.0:
			queue_free()


func _on_body_entered(body: Node2D) -> void:
	if KitUtil.is_live_player(body):
		collect()


## Adds the Fizz (once) and starts the pop. Returns false when already collected.
func collect() -> bool:
	if is_collected:
		return false
	is_collected = true
	set_deferred(&"monitoring", false)
	GameState.add_coins(value)
	collected.emit(value)
	pop_progress = 0.0
	if pop_time <= 0.0:
		queue_free()
	return true
