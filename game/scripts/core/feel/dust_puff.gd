class_name DustPuff
extends CPUParticles2D
## One-shot dust burst (CPUParticles2D, works in the Compatibility renderer).
## Spawned with DustPuff.spawn(); frees itself when finished. Placed in world
## space (top_level) so it stays where the event happened.

## Presets for spawn(): amount, speed, spread direction.
enum Kind { JUMP, LAND, SKID, RUN }


## Spawns a burst at `global_pos` under `parent`. `dir_x` (-1/1) biases skid /
## run puffs backwards. `strength` (0..1+) scales the amount and speed.
static func spawn(parent: Node, global_pos: Vector2, kind: Kind, dir_x: float = 0.0,
		strength: float = 1.0, color: Color = Color(0.85, 0.78, 0.68, 0.85)) -> DustPuff:
	if parent == null or not parent.is_inside_tree():
		return null
	var p := DustPuff.new()
	p.top_level = true
	p.one_shot = true
	p.explosiveness = 0.9
	p.lifetime = 0.35
	p.gravity = Vector2(0, -20)
	p.damping_min = 60.0
	p.damping_max = 90.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = color
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0.3))
	p.scale_amount_curve = curve
	match kind:
		Kind.JUMP:
			p.amount = 6
			p.direction = Vector2(0, -1)
			p.spread = 70.0
			p.initial_velocity_min = 25.0
			p.initial_velocity_max = 45.0
		Kind.LAND:
			p.amount = 10
			p.direction = Vector2(0, -0.2)
			p.spread = 90.0
			p.initial_velocity_min = 40.0
			p.initial_velocity_max = 70.0
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			p.emission_rect_extents = Vector2(5, 0.5)
		Kind.SKID:
			p.amount = 7
			p.direction = Vector2(-dir_x, -0.6)
			p.spread = 25.0
			p.initial_velocity_min = 40.0
			p.initial_velocity_max = 70.0
		Kind.RUN:
			p.amount = 3
			p.lifetime = 0.25
			p.direction = Vector2(-dir_x, -0.5)
			p.spread = 30.0
			p.initial_velocity_min = 15.0
			p.initial_velocity_max = 30.0
	p.amount = maxi(1, int(round(p.amount * clampf(strength, 0.3, 2.0))))
	p.initial_velocity_max *= clampf(strength, 0.5, 1.5)
	parent.add_child(p)
	p.global_position = global_pos
	p.finished.connect(p.queue_free)
	p.emitting = true
	return p
