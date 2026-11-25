class_name ParallelWorldSwitch
extends StateLever
## P1 parallel world: two layers at the same coordinates, each a StateDriven node
## on the same `state_flag` (layer A: active_values [0], layer B: [1], typically
## with inactive_display = GHOST). Only the active layer's collision is enabled.
## Switching reuses StateLever validation: it is refused with a message when the
## player (or a pushable) would end up inside the target layer's collision.
##
## Triggered through its Interactable, or from code / another device via switch_world().

func _init() -> void:
	mode = Mode.CYCLE
	cycle_values = [0, 1]
	blocked_message = "Can't shift here - you would be stuck inside the other world."


## Validated switch to the other layer. Physics frame only. Returns success.
func switch_world() -> bool:
	return request_next()

## Index of the currently active layer.
func get_active_layer() -> int:
	return get_value()
