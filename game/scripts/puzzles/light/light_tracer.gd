class_name LightTracer
extends RefCounted
## Stateless beam tracer + light-update notification.
##
## Hit classification: the tracer asks the hit collider - or, if it does not
## implement it, the collider's parent - for
##     func get_light_response(hit: Dictionary, direction: Vector2) -> int  # LightTracer.Response
## (`hit` is the intersect_ray result). Anything that doesn't answer BLOCKs.
##  - REFLECT: Mirror (front face, or either face when double-sided).
##  - ABSORB:  LightReceiver; the absorbing node is reported in Result.targets
##             (the node that answered, i.e. the receiver, not its child body).
##  - BLOCK:   walls, gates, boxes, mirror edges / backs.
##
## Robustness: at most `max_bounces` reflections; total length capped at
## `max_distance`; every reflection restarts `epsilon` px off the surface along the
## hit normal AND excludes the just-hit collider for the next segment; a repeated
## (reflector, quantized hit point, quantized direction) state ends the beam as CYCLE.
##
## Update model: emitters recompute only when told. Anything that changes the beam
## path (mirror rotated, gate opened, state switched, box moved) calls
## LightTracer.notify_changed(get_tree()); emitters with `continuous_update`
## recompute every physics frame instead.

enum Response { BLOCK, REFLECT, ABSORB }
enum EndReason { OPEN, BLOCKED, ABSORBED, MAX_BOUNCES, CYCLE, MAX_DISTANCE }

const EMITTER_GROUP := &"light_emitters"


## Result of one trace.
class Result extends RefCounted:
	## Global beam polyline: origin, every hit point, end point.
	var points: PackedVector2Array = PackedVector2Array()
	## Nodes that absorbed the beam (0 or 1 entry).
	var targets: Array[Node] = []
	## Mirrors (or other reflectors) hit, in order.
	var reflectors: Array[Node] = []
	var bounces: int = 0
	var end_reason: EndReason = EndReason.OPEN


## Asks every emitter in the tree to recompute (next physics frames).
static func notify_changed(tree: SceneTree) -> void:
	if tree:
		tree.call_group(EMITTER_GROUP, &"request_update")


## Traces a beam from `origin` along `direction`. `space` must be accessible
## (physics frame). `exclude` = RIDs ignored for the whole trace.
static func trace(space: PhysicsDirectSpaceState2D, origin: Vector2, direction: Vector2,
		cfg: PuzzleConfig, exclude: Array[RID] = []) -> Result:
	var result := Result.new()
	cfg = PuzzleConfig.resolve(cfg)
	result.points.append(origin)
	if space == null or direction == Vector2.ZERO:
		return result
	var dir := direction.normalized()
	var pos := origin
	var remaining := cfg.max_distance
	var seen := {}
	var segment_exclude: Array[RID] = []
	while true:
		if remaining <= 0.0:
			result.end_reason = EndReason.MAX_DISTANCE
			break
		var to := pos + dir * remaining
		var ex: Array[RID] = exclude.duplicate()
		ex.append_array(segment_exclude)
		var query := PhysicsRayQueryParameters2D.create(pos, to, cfg.light_collision_mask, ex)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		query.hit_from_inside = false
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			result.points.append(to)
			result.end_reason = EndReason.MAX_DISTANCE if remaining < cfg.max_distance else EndReason.OPEN
			break
		var p: Vector2 = hit["position"]
		result.points.append(p)
		remaining -= pos.distance_to(p)
		var responder := get_responder(hit.get("collider"))
		var response: int = Response.BLOCK
		if responder:
			response = int(responder.call(&"get_light_response", hit, dir))
		if response == Response.ABSORB:
			result.targets.append(responder)
			result.end_reason = EndReason.ABSORBED
			break
		if response != Response.REFLECT:
			result.end_reason = EndReason.BLOCKED
			break
		if result.bounces >= cfg.max_bounces:
			result.end_reason = EndReason.MAX_BOUNCES
			break
		var normal: Vector2 = hit["normal"]
		if normal.dot(dir) > 0.0:
			normal = -normal
		dir = dir.bounce(normal).normalized()
		# State = reflector + hit point (1 px) + outgoing direction (1e-3): a true loop
		# repeats all three, a zig-zag between long parallel mirrors does not.
		var key := "%d|%d|%d|%d|%d" % [responder.get_instance_id(), roundi(p.x), roundi(p.y),
			roundi(dir.x * 1000.0), roundi(dir.y * 1000.0)]
		if seen.has(key):
			result.end_reason = EndReason.CYCLE
			break
		seen[key] = true
		result.bounces += 1
		result.reflectors.append(responder)
		pos = p + normal * cfg.epsilon
		segment_exclude = [hit["rid"]]
	return result


## The node that classifies hits on `collider` (itself or its parent), or null.
static func get_responder(collider: Object) -> Node:
	if collider == null or not collider is Node:
		return null
	var node := collider as Node
	if node.has_method(&"get_light_response"):
		return node
	var parent := node.get_parent()
	if parent and parent.has_method(&"get_light_response"):
		return parent
	return null
