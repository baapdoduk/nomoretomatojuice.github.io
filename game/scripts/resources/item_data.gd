class_name ItemData
extends Resource
## Data for any collectible / usable item. Create one .tres per item under
## res://resources/items/. Gameplay code refers to items by `id` only.

enum ItemType {
	MEMORY,       ## Collectible memento (photo, keepsake). Never consumed.
	PROGRESSION,  ## Key-like item that opens gates / unlocks progress.
	CONSUMABLE,   ## Stackable, can be used up (see max_stack).
}

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var type: ItemType = ItemType.MEMORY
## Only for CONSUMABLE items; others are always unique (1).
@export_range(1, 99) var max_stack: int = 1
## Flags that must be set before this item can be picked up / used.
@export var required_flags: Array[StringName] = []
## Placeholder tint used by UI / pickups when `icon` is null.
@export var placeholder_color: Color = Color(1.0, 0.85, 0.3)

func get_stack_limit() -> int:
	return max_stack if type == ItemType.CONSUMABLE else 1

func requirements_met() -> bool:
	for flag in required_flags:
		if not GameState.has_flag(flag):
			return false
	return true
