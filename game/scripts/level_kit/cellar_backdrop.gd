@tool
class_name CellarBackdrop
extends Node2D
## Code-drawn, desaturated "dusk cellar" background layer, meant as the child of
## a Parallax2D (see scenes/level_kit/cellar_background.tscn). One strip of
## `strip_width` px is drawn (Parallax2D.repeat_size repeats it).
##   SKY: vertical wall gradient + soft vignette band.
##   FAR: tall shelving silhouettes with bottles + arched windows with light shafts.
##   MID: barrel stacks, wine racks and hanging lanterns.
## Horizon: y = 0 is roughly the playfield floor; shapes extend well below.

enum Kind { SKY, FAR, MID }

@export var kind: Kind = Kind.FAR:
	set(v):
		kind = v
		queue_redraw()
@export var strip_width: float = 640.0
@export var top: float = -420.0
@export var bottom: float = 600.0
@export var rng_seed: int = 7:
	set(v):
		rng_seed = v
		queue_redraw()
@export_group("Colours")
@export var sky_top: Color = Color(0.11, 0.08, 0.14)
@export var sky_bottom: Color = Color(0.2, 0.15, 0.2)
@export var silhouette: Color = Color(0.17, 0.14, 0.2):
	set(v):
		silhouette = v
		queue_redraw()
@export var detail: Color = Color(0.22, 0.19, 0.25):
	set(v):
		detail = v
		queue_redraw()
## Window / lantern light (keep it muted: the playfield must stay brighter).
@export var light: Color = Color(0.85, 0.62, 0.36, 0.55):
	set(v):
		light = v
		queue_redraw()
@export var glass: Color = Color(0.2, 0.3, 0.32):
	set(v):
		glass = v
		queue_redraw()


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	match kind:
		Kind.SKY:
			_draw_sky()
		Kind.FAR:
			_draw_far(rng)
		Kind.MID:
			_draw_mid(rng)


func _draw_sky() -> void:
	var bands := 24
	var h := (bottom - top) / bands
	for i in bands:
		var t := float(i) / float(bands - 1)
		draw_rect(Rect2(-strip_width, top + i * h, strip_width * 3.0, h + 1.0), sky_top.lerp(sky_bottom, t))


func _draw_far(rng: RandomNumberGenerator) -> void:
	# arched windows with diagonal light shafts
	for wx in [110.0, 430.0]:
		var win := Rect2(wx, -230, 34, 60)
		draw_colored_polygon(PackedVector2Array([win.position, win.position + Vector2(win.size.x, 0),
			Vector2(wx + 150, 40), Vector2(wx + 90, 40)]), Color(light, light.a * 0.18))
		draw_rect(win, Color(light, light.a * 0.8))
		draw_circle(Vector2(wx + 17, -230), 17.0, Color(light, light.a * 0.8))
		draw_rect(Rect2(wx + 16, -246, 2, 76), silhouette)
		draw_rect(Rect2(wx, -205, 34, 2), silhouette)
	# shelving units
	var x := 0.0
	while x < strip_width - 40.0:
		var w := rng.randf_range(70.0, 110.0)
		var h := rng.randf_range(150.0, 230.0)
		if rng.randf() < 0.8 and not _overlaps_window(x, w):
			draw_rect(Rect2(x, -h, w, bottom + h), silhouette)
			var y := -h + 10.0
			while y < -10.0:
				draw_rect(Rect2(x - 3, y, w + 6, 4), detail)
				# bottles standing on this plank
				var bx := x + 4.0
				while bx < x + w - 8.0:
					var bh := rng.randf_range(10.0, 22.0)
					var bw := rng.randf_range(4.0, 7.0)
					draw_rect(Rect2(bx, y - bh, bw, bh), glass if rng.randf() < 0.3 else detail)
					draw_rect(Rect2(bx + bw * 0.3, y - bh - 4, bw * 0.4, 4), detail)
					bx += bw + rng.randf_range(2.0, 9.0)
				y += rng.randf_range(34.0, 46.0)
		x += w + rng.randf_range(20.0, 60.0)
	draw_rect(Rect2(0, 0, strip_width, bottom), silhouette)


func _overlaps_window(x: float, w: float) -> bool:
	for wx in [110.0, 430.0]:
		if x < wx + 40.0 and x + w > wx - 6.0:
			return true
	return false


func _draw_mid(rng: RandomNumberGenerator) -> void:
	var x := 20.0
	while x < strip_width - 60.0:
		var pick := rng.randi() % 3
		if pick == 0:
			_barrel_stack(x, rng)
			x += 90.0
		elif pick == 1:
			_wine_rack(x, rng)
			x += 110.0
		else:
			_lantern(x + 20.0, rng)
			x += 60.0
		x += rng.randf_range(30.0, 70.0)
	draw_rect(Rect2(0, 0, strip_width, bottom), silhouette)


func _barrel_stack(x: float, rng: RandomNumberGenerator) -> void:
	var r := 18.0
	var rows := 2 + rng.randi() % 2
	for row in rows:
		for i in rows - row:
			var c := Vector2(x + r + i * r * 2.1 + row * r, -r - row * r * 1.9)
			draw_circle(c, r, silhouette)
			draw_arc(c, r - 4.0, 0.0, TAU, 16, detail, 2.0)
			draw_circle(c, 3.0, detail)


func _wine_rack(x: float, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(90.0, 140.0)
	draw_rect(Rect2(x, -h, 90, h), silhouette)
	var y := -h + 9.0
	while y < -6.0:
		var cx := x + 9.0
		while cx < x + 86.0:
			draw_circle(Vector2(cx, y), 5.0, detail)
			draw_circle(Vector2(cx, y), 2.0, glass if rng.randf() < 0.4 else silhouette)
			cx += 12.0
		y += 12.0


func _lantern(x: float, rng: RandomNumberGenerator) -> void:
	var y := rng.randf_range(-210.0, -160.0)
	draw_line(Vector2(x, top), Vector2(x, y - 8), detail, 1.0)
	draw_circle(Vector2(x, y + 6), 22.0, Color(light, light.a * 0.12))
	draw_rect(Rect2(x - 6, y - 8, 12, 4), silhouette)
	draw_rect(Rect2(x - 5, y - 4, 10, 14), Color(light, light.a * 0.9))
	draw_rect(Rect2(x - 6, y + 10, 12, 3), silhouette)
