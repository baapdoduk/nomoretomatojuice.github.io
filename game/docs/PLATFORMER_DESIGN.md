# Side-View Platformer: Presentation, Feel & Level Design Brief (v2, advisor-reviewed)

Reference = the *methodology* of modern Nintendo 2D platformers (NSMB Wii / U, Wonder): camera behaviour, framing, readability, game feel, level structure.
**Never copy** their names, characters, art, music, levels or iconic objects. Explicitly forbidden look-alikes: floating bump-from-below blocks ("?"/brick patterns), green cylinders/pipes, mushroom or turtle silhouettes, stomp-flattened enemies, flag-on-pole checkpoint/goal, iris-to-black on death, three big round gold coins on the HUD, hills/clouds with faces, blue-sky/green-grass/orange-brick palette, "course clear" fanfare structure, node world map.
Original vocabulary for this game: currency **Fizz** (pale-cyan bubbles), checkpoint **Catnap Cushion** (the cat curls on it), goal **Memory Door**, per-level collectibles **Memory shards** (polaroid-frame HUD slots), basic enemy **Cork** (wobbling cork blob, sword only). Palette: **dusk cellar** — amber / teal / plum, desaturated background.

## A. Screen methodology
- **Grid 16 px; side-view camera zoom 1.5** on the 640×360 viewport → 427×240 px ≈ **27 × 15 tiles** visible (integer at 720p/1080p). UI layers are not zoomed. Re-check existing side-view rooms at this framing.
- **Camera rig** (separate `top_level` node updated in `_physics_process`, never a jittery child):
  - Horizontal **lead from velocity** (not facing), clamped to move speed so the dash doesn't yank it: lead ≈ **2.5–3 tiles (40–48 px)** → player at ~39–41 % from the trailing edge. Lead pans at most **~80 px/s** (a full reversal takes ~1 s). Small dead zone.
  - **Vertical platform snap**: rest line with the player's feet at **~70 %** of the screen height. While grounded the camera eases to the new ground height over **0.25–0.35 s**. While airborne it holds unless the head goes above **~22 %** from the top (a full 4.6-tile jump peaks ≈ 31 % → normal jumps never scroll) or the feet drop below rest line + 1 tile; downward catch-up ≥ fall speed.
  - Limits from `CameraBounds`; rooms smaller than the view are centred. **Hard snap** on spawn/respawn/door/teleport (no swoop).
  - Trauma **shake** (setting toggle). Zoom override per level (LevelInfo).
- **Layering**: sky gradient → far parallax (0.15) → mid parallax (0.45) → playable layer (outlined, **lit top rim** on standable surfaces) → sparse foreground/SecretArea overlay. Hazards red/white spiky; pickups bright with sparkle; background desaturated.
- **HUD**: top-left hearts; Fizz counter; top-right 3 polaroid slots for the current level. **Debug overlays off by default** (F3).
- **Transitions**: fade (default). The iris style exists in SceneRouter but is not used for death.

## B. Game feel (side view) — retune targets
| Param | Old | New |
|---|---|---|
| fall gravity multiplier | 1.0 | **1.4** |
| apex hang | – | gravity × **0.6** while |vy| < 40 px/s and jump held |
| jump cut multiplier | 0.4 | **0.5** (min hop ≈ 1.2 tiles) |
| max fall speed | 600 | **320** |
| ground accel / decel / turn decel | 1800/2200/– | **900 / 1200 / 2200** (+ skid dust) |
| move speed | 180 | 180 (spec default; documented option 160) |
Keep apex ≈ 4.5–5 tiles, airtime ≈ 0.8 s. **Corner correction** 4 px on head bumps; **ledge step-up** ≤ 3 px. **Surface modifier API** on Player for level gimmicks (e.g. sticky puddles): `set_surface_modifier(source: Object, speed_mult, jump_mult, accel_mult)` / `clear_surface_modifier(source)`.
Juice: squash & stretch (jump/land), landing/jump/skid dust (CPUParticles2D), dash after-images, **50 ms hit-stop + small shake on sword hits** (settings toggles `screen_shake`, `hit_stop`; disabled when tests need exact timing). No stomp in this round.

## C. Level kit (small)
Code-drawn tile atlas (no autotile requirement): ground (lit rim/fill/edges), shelf (one-way), solid block, spikes → TileSet on layer World. Components: Fizz pickup + `FizzTrail` (places pickups along a jump arc), MemoryShard (flags `shard.<level_id>.<n>`, commits progress), Spikes (damage + knockback), KillPlane (existing KillZone), Cork walker (patrol, turns at walls/ledges, sword only, contact damage), Catnap Cushion (checkpoint visual), Memory Door (goal: input lock, short celebration, `level.<id>.clear` milestone, return to hub), SecretArea (foreground fades when inside), StickyPuddle (surface modifier), DripEmitter (makes/removes puddles on a rhythm), LevelInfo (level_id, name, shard count, camera zoom). Deferred: moving/falling platforms, springs, crates, stomp, level-clear tally, camera zones.

## D. Level design methodology
- One core idea per level in **four beats** (introduce safely → develop/combine → twist → finale) with breathers; 2–4 min; checkpoint at ~50 %; goal at the end.
- Teach without text (first encounter on safe flat ground; camera reveals the next challenge first). Fizz trails trace arcs and hint secrets.
- 3 shards per level: on-path, skill (off-path), hidden (SecretArea).
- **Metrics must include the dash**: jump + air-dash ≈ 11.5–12.5 tiles horizontally, so gaps meant to require a plain jump must be guarded (ceilings/hazards) or be ≤ jump length. Early platforms ≥ 3 tiles wide; ≥ 4 tiles headroom over jumps; first pits ≤ 3 tiles.
- Acceptance: screenshot of every beat (tools/capture_screens), metric table in LEVEL_DESIGN_GUIDE.md, automated traversal of the critical path.

### Showcase: "The Cellar Shelf" (core idea: sticky juice puddles slow the run and shorten jumps; clean shelves let the dash carry you)
Introduce: flat floor, one harmless puddle, a Fizz arc that visibly falls short when jumping from inside it, then a 2-tile pit with clean run-up. Develop: ≥3-tile shelves alternating clean/sticky, a Cork patrolling a sticky stretch, first dash-over-puddle gap (6 tiles) with the landing in view. Breather: Catnap Cushion at ~50 % under a window. Twist: a leaking bottle overhead drips puddles on and off a rhythm; a vertical one-way shelf climb. Finale: three chained jump–dash gaps over spikes with timed drips and one Cork, then a clean runway to the Memory Door. Shards: (1) at the apex of the first taught arc, (2) high shelf reachable by jump + air-dash from a clean tile between puddles, (3) hidden behind a foreground crate stack via a drop-through shelf into a SecretArea.
