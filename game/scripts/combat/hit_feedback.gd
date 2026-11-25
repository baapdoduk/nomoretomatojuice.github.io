class_name HitFeedback
extends Node
## Hit presentation hooks: flash a CanvasItem, play a sound, rumble the pad.
## Subscribes to a Health (`damaged` -> "got hurt") and/or a Hitbox
## (`hit_landed` -> "hit confirmed"). Logic nodes stay unaware of it.

## Emitted for every reacted hit. kind: &"hurt" (Health) or &"confirm" (Hitbox).
signal feedback_played(kind: StringName)

## Health to watch (damage taken). Optional.
@export var health: Health
## Hitbox to watch (damage dealt). Optional.
@export var hitbox: Hitbox
## CanvasItem whose `modulate` flashes.
@export var flash_target: CanvasItem
@export var flash_color: Color = Color(2.5, 2.5, 2.5, 1.0)
@export_range(0.0, 2.0, 0.01) var flash_time: float = 0.12
## Number of on/off blinks during flash_time (>1 = blink, readable without colour).
@export_range(1, 10) var flash_blinks: int = 1
## AudioStreamPlayer or AudioStreamPlayer2D (anything with play()) for the hurt sound.
@export var hurt_sound: Node
## Sound when the watched Hitbox lands a hit.
@export var confirm_sound: Node
## InputFeedback rumble preset on hurt (empty = none), e.g. &"player_hurt" / &"hit_confirm".
@export var hurt_rumble: StringName = &""
## Rumble preset when the watched Hitbox lands a hit (empty = none).
@export var confirm_rumble: StringName = &""

var is_flashing: bool = false
var _base_modulate := Color.WHITE
var _flash_left := 0.0


func _ready() -> void:
	if health:
		health.damaged.connect(_on_damaged)
	if hitbox:
		hitbox.hit_landed.connect(_on_hit_landed)


func _process(delta: float) -> void:
	if not is_flashing:
		return
	_flash_left -= delta
	if _flash_left <= 0.0 or not is_instance_valid(flash_target):
		_end_flash()
		return
	var t := 1.0 - _flash_left / maxf(flash_time, 0.0001)
	var on := int(floor(t * float(flash_blinks * 2))) % 2 == 0
	flash_target.modulate = flash_color if on else _base_modulate


## Plays the hurt reaction manually.
func play_hurt() -> void:
	_flash()
	_play(hurt_sound)
	if hurt_rumble != &"":
		InputFeedback.rumble_preset(hurt_rumble)
	feedback_played.emit(&"hurt")

## Plays the hit-confirm reaction manually.
func play_confirm() -> void:
	_play(confirm_sound)
	if confirm_rumble != &"":
		InputFeedback.rumble_preset(confirm_rumble)
	feedback_played.emit(&"confirm")


func _on_damaged(_event: DamageEvent) -> void:
	play_hurt()

func _on_hit_landed(_hurtbox: Hurtbox, _event: DamageEvent) -> void:
	play_confirm()

func _flash() -> void:
	if flash_target == null or flash_time <= 0.0:
		return
	if not is_flashing:
		_base_modulate = flash_target.modulate
	is_flashing = true
	_flash_left = flash_time
	flash_target.modulate = flash_color

func _end_flash() -> void:
	is_flashing = false
	if is_instance_valid(flash_target):
		flash_target.modulate = _base_modulate

func _play(player: Node) -> void:
	if player and player.has_method(&"play"):
		var stream: Variant = player.get(&"stream")
		if stream != null:
			player.call(&"play")
