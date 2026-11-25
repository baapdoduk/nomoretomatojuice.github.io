class_name LightBeam
extends Line2D
## Presentation only: draws a LightEmitter's beam. Subscribes to
## `emitter.beam_changed` (default emitter: the parent). Width / colour come from
## the emitter's PuzzleConfig unless `override_style` is set.

@export var emitter: LightEmitter
@export var override_style: bool = false


func _ready() -> void:
	if emitter == null:
		emitter = get_parent() as LightEmitter
	if emitter == null:
		return
	if not override_style:
		var cfg := emitter.get_config()
		width = cfg.beam_width
		default_color = cfg.beam_color
	begin_cap_mode = Line2D.LINE_CAP_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND
	emitter.beam_changed.connect(_on_beam_changed)
	_on_beam_changed(emitter.get_beam_points())


func _on_beam_changed(global_points: PackedVector2Array) -> void:
	var local := PackedVector2Array()
	local.resize(global_points.size())
	var inv := global_transform.affine_inverse()
	for i in global_points.size():
		local[i] = inv * global_points[i]
	points = local
