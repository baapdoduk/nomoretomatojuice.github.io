# Architecture & Module Contracts

Godot **4.7.2 stable** (tested). GDScript only, no addons. Project root: `game/` (the repo root is a separate Nuxt website — do not touch it).
Base resolution 640×360 (`canvas_items`, window 1280×720), physics 60 Hz, nearest filtering, GL Compatibility renderer.
Syntax target: Godot 4.4+ (no `@abstract`, no variadic functions). Newer engine APIs (joy light / motion sensors) are called through `has_method` guards.

## 1. Layout

```
scenes/core/{autoload,player,interaction,ui,level}   reusable core scenes
scenes/combat/   boss, projectile, telegraph, attack area, dummy
scenes/puzzles/  mirror, emitter, receiver, switch, plate, gate, state-driven
scenes/tests/    test_hub + *_lab scenes (kept as regression fixtures)
scripts/<same tree>        scripts for the scenes above
scripts/resources/         Resource class scripts (PlayerConfig, ItemData, AttackPattern, BossConfig, PuzzleConfig)
resources/{player,items,combat,puzzles}/   .tres instances (tuning data)
assets/placeholder/        placeholder art only
tests/{unit,integration,smoke}/test_*.gd  automated tests (TestCase)
tools/                     run_tests.sh, check_scripts, gen_input_map
docs/                      this file, guides, checklists
```

## 2. Autoloads (only these three)

| Autoload | File | Owns |
|---|---|---|
| `GameState` | scripts/core/game_state.gd | player health, items, flags, checkpoint/chapter/scene-entry snapshots, settings, JSON save (P1), `notify()` toast event |
| `SceneRouter` | scripts/core/scene_router.gd | fade → load → spawn → fade; respawn / restart chapter / hub; tree is **paused** during transitions (blocks input & interactions) |
| `InputFeedback` | scenes/core/autoload/input_feedback.tscn | joypad connect/disconnect, last input kind (prompt glyphs), rumble presets, dead-zone, DS4 extras behind capability checks; hosts the PauseMenu UI child |

Key APIs (read the scripts for full docs):
- `GameState`: `apply_damage/heal/refill_health`, `add_item(ItemData)->bool` (duplicate guard), `has_item/remove_item/get_item_count`, `set_flag/get_flag/has_flag/clear_flag`, `save_checkpoint(scene_path, spawn_id, refill=true)`, `begin_chapter(id, scene, spawn)`, `make_snapshot/restore_snapshot`, `get_combat_timing_scale()`, `get_setting/set_setting`, `notify(text, duration)`. Signals: `health_changed, player_died, item_added, item_removed, inventory_changed, flag_changed, checkpoint_saved, state_restored, notification_requested, settings_changed`.
- `SceneRouter`: `change_scene(path, spawn_id=&"", fade=0.25)`, `respawn_at_checkpoint()`, `restart_chapter()`, `go_to_hub()`, `reload_current_scene()`, `place_player_at_spawn(id)`, `get_player()`, `is_transitioning`. Signals: `transition_started, scene_loaded, transition_finished`.
- `InputFeedback`: `rumble(weak, strong, dur, device=-1)`, `rumble_preset(&"light"|&"medium"|&"heavy"|&"player_hurt"|&"hit_confirm"|&"boss_slam"|&"ui")`, `stop_all_rumble()`, `get_action_glyph(action)`, `last_input_kind`, `set_stick_deadzone(v)`, `supports_feature(&"vibration"|&"light"|&"motion")`, `set_light_color(c)`. Signals: `device_connected, device_disconnected, input_kind_changed`.

## 3. Physics layers (`Layers` constants in scripts/core/layers.gd)

| # | Name | Used by | Typical mask |
|---|---|---|---|
| 1 | World | walls, floors, gates, mirrors, receivers, light blockers | – |
| 2 | Player | player body, player Hurtbox | body: World(+Enemy) |
| 3 | Enemy | enemy/boss bodies, their Hurtboxes | body: World |
| 4 | PlayerAttack | player Hitbox | Enemy |
| 5 | EnemyAttack | boss attack areas, projectiles | Player |
| 6 | Interactable | Interactable areas | – (player Interactor masks 6) |

Groups: `player`, `spawn_point`, `hud`, `boss`, `pushable`, `pause_menu`, `no_disconnect_pause` (scenes that only toast on pad disconnect: hub, controller lab), `light_emitters`, `state_driven`.

Note: an Area2D only detects World StaticBody2D walls reliably when it is also `monitorable` (Projectile sets this). Pressure plates detect `CharacterBody2D`/`AnimatableBody2D` (PushBox), not StaticBody2D.

## 4. Input Map (project.godot; regenerate with tools/gen_input_map.gd)

`move_left/right/up/down` (L-stick, D-pad, WASD, arrows; dead-zone 0.2), `jump` (Cross / Space), `dash` (Circle / Shift), `attack` (Square / J), `interact` (Triangle / E), `context_left/right` (L2/R2 analog, dead-zone 0.05 / Q, R), `pause` (Options / Esc).
Joypad indices are Godot's SDL-standard layout (A=Cross, B=Circle, X=Square, Y=Triangle, START=Options). Real-device verification happens in ControllerLab.
Read movement with `Input.get_vector("move_left","move_right","move_up","move_down")`; trigger depth with `Input.get_action_strength("context_left")`.

## 5. Shared contracts (architect-owned files)

### Combat core — scripts/combat/
- `DamageEvent` (RefCounted): `amount, source, hitbox, knockback, position, tags`.
- `Health` (Node): `max_health, invulnerability_time, use_game_state` (player = true → GameState is the source of truth). `apply_damage(event)->bool`, `heal`, `reset`, `set_invulnerable_for(s)`, `set_invulnerable_flag(reason, on)`, `is_invulnerable()`, `get_ratio()`. Signals `health_changed, damaged, healed, died, invulnerability_changed`.
- `Hurtbox` (Area2D): forwards to `health` (auto-finds sibling Health). `receive_hit(event)->bool`. Signals `hurt, hit_ignored`.
- `Hitbox` (Area2D): `damage, knockback_strength, knockback_direction, active, source, tags`. `activate()` starts a new attack instance — **a target (Health) is damaged at most once per activation**; only accepted hits are registered (an invulnerable target can be hit later in the same activation). Signal `hit_landed(hurtbox, event)`.

### Interaction — scripts/core/interaction/interactable.gd
`Interactable` (Area2D, layer 6): `prompt_text, prompt_action, enabled, interact_priority, lock_movement, one_shot, prompt_offset, required_item, consume_required_item, required_flags, blocked_message, locked_prompt_text`.
`can_focus(actor)`, `conditions_met()`, `get_prompt_text()`, `get_prompt_position()`, `set_focused(b)`, `interact(actor)` (coroutine). Subclasses override `_perform(actor)` (may await) and `_can_interact(actor)`. Signals `interacted, interaction_finished, focus_changed`.
Doors, switches, pickups, photo/dialog popups, item-use spots and context actions are all Interactables (or own a child Interactable).

### Puzzle input contract — scripts/puzzles/puzzle_device.gd
Any node with `signal activated_changed(active: bool)` + `func is_active() -> bool` can drive outputs. `PuzzleDevice` (Node2D) implements it plus `persist_flag` (state saved to GameState and restored on scene load), `start_active`, `set_active()`, `reset()`, `_apply_state(value, instant)`.
Outputs reference inputs through exported `Array[Node]` (drag & drop in the Inspector) and connect to their signals — no hard-coded node paths in code. Helpers: `PuzzleInputs` (evaluate/connect), `PuzzlePhysics` (anti-trap overlap queries).
Subclasses whose state depends on external inputs (LightReceiver, PressurePlate) override `reset()` to re-sync instead of forcing `start_active`.

### Light contract — scripts/puzzles/light/
Ray hits ask the collider (or its parent) `get_light_response(hit: Dictionary, dir: Vector2) -> LightTracer.Response` (BLOCK / REFLECT / ABSORB); anything without it blocks. Anything that changes beam paths calls `LightTracer.notify_changed(get_tree())`. Limits from `PuzzleConfig`: 12 reflections, cycle detection (reflector + hit point + outgoing direction), epsilon offset along the normal, distance cap.

### UI primitive — scripts/core/ui/button_glyph.gd
`ButtonGlyph` (Control): `action`, `force_kind`; draws DS4 face symbols / pills / key caps procedurally, follows `InputFeedback.last_input_kind`, texture overrides via `joypad_textures` / `keyboard_texture`.

### UI
`HUD` (group `hud`): `show_toast(text, duration)`; `show_status=false` hides hearts/items on menu scenes. `PauseMenu` (child of InputFeedback, group `pause_menu`): `open()/close()/is_open()`; restores the previous pause state; refuses during transitions; auto-pauses on active pad disconnect.

## 6. Policies

- **State persistence across scene re-entry**: anything that must survive reloading a scene lives in GameState flags/items. Devices without `persist_flag` reset on reload. Pickups hide themselves if already owned (or their `collected_flag` is set). Solved puzzles / opened shortcuts write flags.
- **Checkpoint/respawn**: Checkpoint → `GameState.save_checkpoint()` (refills health by default). Death → player calls `SceneRouter.respawn_at_checkpoint()` → snapshot restored (health, items AND flags together, so no item duplication/loss) → scene reloaded at the checkpoint's spawn. Without a checkpoint the scene-entry snapshot is used. `begin_chapter()` defines "restart chapter".
- **Input locking**: transitions pause the tree; the player additionally has named input locks (`add_input_lock(reason)`), used by interactions, popups, death, cutscenes.
- **Rumble stops** on scene transition (router), pause (PauseMenu) and disconnect (InputFeedback). Unsupported hardware = silent no-op.
- **Presentation vs logic**: gameplay scripts emit signals; visuals/SFX nodes subscribe. Placeholder visuals are Polygon2D/ColorRect/_draw nodes named `Visual` so they can be swapped for Sprite2D/AnimatedSprite2D without touching logic. No asset paths in gameplay code — use exported Texture2D/AudioStream/PackedScene properties.
- **Data-driven**: tuning lives in Resources (`PlayerConfig`, `AttackPattern`, `BossConfig`, `PuzzleConfig`, `ItemData`) and `@export`s.
- **Spec interpretation** (source spec lost "~" characters): telegraph 1.5–2.0 s, boss recovery 3–4 s, coyote/buffer 0.12 s, attack interval 0.35 s.

## 7. Module ownership (parallel work)

| Module | Owns (create/edit) |
|---|---|
| Architect | project.godot, scripts/core/{game_state,scene_router,input_feedback,layers}.gd, scenes/core/autoload/input_feedback.tscn (root node only), scripts/resources/item_data.gd, scripts/combat/{damage_event,health,hurtbox,hitbox}.gd, scripts/core/interaction/interactable.gd, scripts/puzzles/puzzle_device.gd, scripts/core/ui/button_glyph.gd, tests/test_case.gd, tests/test_runner.*, tools/**, docs/ARCHITECTURE.md |
| A Exploration | scripts/core/{player,interaction,level}/** (except interactable.gd), scenes/core/{player,interaction,level}/**, scripts/core/ui/{popup_panel,interaction_prompt}.gd + their scenes, scripts/resources/player_config.gd, resources/{player,items}/**, scenes/tests/{side_view_lab,top_down_lab}.tscn, scripts/tests/{side_view_lab,top_down_lab}*.gd, tests/*/test_player_*.gd, test_exploration_*.gd |
| B Combat | scripts/combat/** (except the 4 core files), scenes/combat/**, scripts/resources/{attack_pattern,boss_config,boss_phase}.gd, resources/combat/**, scenes/tests/combat_lab.tscn, scripts/tests/combat_lab*.gd, tests/*/test_combat_*.gd |
| C Puzzles | scripts/puzzles/** (except puzzle_device.gd), scenes/puzzles/**, scripts/resources/puzzle_config.gd, resources/puzzles/**, scenes/tests/puzzle_lab*.tscn, scripts/tests/puzzle_lab*.gd, tests/*/test_puzzle_*.gd, test_light_*.gd |
| D UI/Controller | scripts/core/ui/** (except button_glyph/popup_panel/interaction_prompt), scenes/core/ui/** (same exceptions), PauseMenu child inside input_feedback.tscn, scenes/tests/{test_hub,controller_lab}.tscn, scripts/tests/{test_hub,controller_lab}*.gd, tests/*/test_ui_*.gd, tests/smoke/**, docs/HARDWARE_CHECKLIST.md |

Shared files are not edited by modules; needed changes are reported to the architect with a proposed diff.

## 8. Fixed scene paths & ids

- Hub (main scene): `res://scenes/tests/test_hub.tscn`
- Labs: `controller_lab.tscn`, `side_view_lab.tscn`, `top_down_lab.tscn`, `combat_lab.tscn`, `puzzle_lab.tscn`, `integration_overworld.tscn`, `integration_interior.tscn` (all in `res://scenes/tests/`)
- Spawn ids: `start` (default), `from_<scene_name>` for door arrivals, `cp_<name>` for checkpoints.

## 9. Verification

```
cd game && ./tools/run_tests.sh            # import + load check of every script/scene + all tests
cd game && ./tools/run_tests.sh light      # filter by file/method substring
```
The runner fails a test on any engine/script error raised during it (Logger capture). Tests needing a respawn must first load a real scene via `change_scene_and_wait()`. Use unique `user://` file names in tests (user data dir is shared between checkouts).
