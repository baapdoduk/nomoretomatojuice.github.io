class_name Layers
extends RefCounted
## Physics layer bit values (match [layer_names] in project.godot).
## Use these instead of magic numbers when configuring collision in code.

const WORLD := 1 << 0          ## Layer 1: static level geometry, walls, gates, mirrors.
const PLAYER := 1 << 1         ## Layer 2: player body + player Hurtbox.
const ENEMY := 1 << 2          ## Layer 3: enemy / boss bodies + their Hurtboxes.
const PLAYER_ATTACK := 1 << 3  ## Layer 4: player Hitboxes (mask ENEMY).
const ENEMY_ATTACK := 1 << 4   ## Layer 5: enemy Hitboxes / projectiles (mask PLAYER).
const INTERACTABLE := 1 << 5   ## Layer 6: Interactable areas (player Interactor masks this).

const GROUP_PLAYER := &"player"
const GROUP_SPAWN_POINT := &"spawn_point"
const GROUP_HUD := &"hud"
const GROUP_BOSS := &"boss"
const GROUP_PUSHABLE := &"pushable"
