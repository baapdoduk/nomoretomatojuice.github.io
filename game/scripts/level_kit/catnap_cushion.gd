class_name CatnapCushion
extends Checkpoint
## Checkpoint skin: a cushion with a sleeping cat. Touching it saves the
## checkpoint (see Checkpoint); while it is the active checkpoint the cat is
## awake. Visuals: swappable `Visual` child (placeholder: CushionVisual) that
## reads `awake_amount` (0 asleep .. 1 awake, eased over `wake_time`).

@export var wake_time: float = 0.35

## 0 = asleep, 1 = fully awake (animated toward is_active_checkpoint).
var awake_amount: float = 0.0


func _init() -> void:
	toast_text = "Catnap Cushion"


func _ready() -> void:
	super._ready()
	awake_amount = 1.0 if is_active_checkpoint else 0.0


func is_cat_awake() -> bool:
	return is_active_checkpoint


func _process(delta: float) -> void:
	var target := 1.0 if is_active_checkpoint else 0.0
	awake_amount = move_toward(awake_amount, target, delta / maxf(wake_time, 0.01))
