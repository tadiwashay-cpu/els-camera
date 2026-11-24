class_name ButtonIcons
extends RefCounted
## Little pictures for the touch buttons (TouchControls), drawn as vector
## shapes so they stay sharp at any button size: a sword (or the held
## weapon's kind) for ATTACK, an arrow for JUMP, a curved throw for THROW,
## a cup for CATCH, chevrons for DODGE, a crosshair for LOCK, a shield for
## BLOCK, a lightning bolt for POWER, two arrows for SWAP, a sparkle for
## SKILL. Shapes live in a -1..1 box (y down), scaled by `size`.

## Draws `icon` centred at `c`, `size` = half the box in pixels.
static func draw(ci: CanvasItem, icon: StringName, c: Vector2, size: float, col: Color) -> void:
	var w := maxf(size * 0.13, 2.0)          # line width
	match icon:
		&"sword":
			_sword(ci, c, size, col, -PI * 0.25)
		&"hammer":
			var rot := -PI * 0.2
			_poly(ci, c, size, rot, col, _rect(-0.08, -0.3, 0.08, 0.95))
			_poly(ci, c, size, rot, col, _rect(-0.55, -0.82, 0.55, -0.3))
		&"spear":
			var rot := -PI * 0.25
			_poly(ci, c, size, rot, col, _rect(-0.06, -0.45, 0.06, 1.0))
			_poly(ci, c, size, rot, col, PackedVector2Array([Vector2(0, -1.0), Vector2(0.2, -0.4), Vector2(-0.2, -0.4)]))
		&"gun":
			_poly(ci, c, size, 0.0, col, _rect(-0.75, -0.4, 0.85, -0.08))
			_poly(ci, c, size, 0.0, col, PackedVector2Array([Vector2(-0.7, -0.1), Vector2(-0.3, -0.1), Vector2(-0.45, 0.65), Vector2(-0.85, 0.65)]))
			_poly(ci, c, size, 0.0, col, _rect(0.55, -0.52, 0.72, -0.4))
		&"bow":
			ci.draw_arc(c + Vector2(0.15, 0) * size, size * 0.85, PI * 0.5, PI * 1.5, 20, col, w, true)
			ci.draw_line(c + Vector2(0.15, -0.85) * size, c + Vector2(0.15, 0.85) * size, col, w * 0.5, true)
			ci.draw_line(c + Vector2(-0.6, 0) * size, c + Vector2(0.85, 0) * size, col, w * 0.7, true)
			_poly(ci, c, size, 0.0, col, PackedVector2Array([Vector2(1.0, 0), Vector2(0.7, -0.18), Vector2(0.7, 0.18)]))
		&"fist":
			_poly(ci, c, size, 0.0, col, _rect(-0.55, -0.45, 0.45, 0.45))
			_poly(ci, c, size, 0.0, col, _rect(-0.75, -0.05, -0.45, 0.4))
			for x: float in [-0.25, 0.05]:
				ci.draw_line(c + Vector2(x + 0.12, -0.45) * size, c + Vector2(x + 0.12, 0.0) * size, Color(0, 0, 0, col.a * 0.6), w * 0.5)
			for y: float in [-0.25, 0.1]:
				ci.draw_line(c + Vector2(0.6, y) * size, c + Vector2(0.95, y) * size, col, w * 0.6, true)
		&"jump":
			_poly(ci, c, size, 0.0, col, PackedVector2Array([Vector2(0, -0.95), Vector2(0.62, -0.25), Vector2(0.2, -0.25),
				Vector2(0.2, 0.45), Vector2(-0.2, 0.45), Vector2(-0.2, -0.25), Vector2(-0.62, -0.25)]))
			ci.draw_line(c + Vector2(-0.7, 0.78) * size, c + Vector2(0.7, 0.78) * size, col, w * 0.8, true)
		&"throw":
			ci.draw_arc(c + Vector2(-0.1, 0.55) * size, size * 0.95, -PI * 0.95, -PI * 0.25, 18, col, w, true)
			var tip := c + Vector2(-0.1, 0.55) * size + Vector2.from_angle(-PI * 0.25) * size * 0.95
			_poly_at(ci, tip, size, PI * 0.25, col, PackedVector2Array([Vector2(0.0, -0.35), Vector2(0.28, 0.15), Vector2(-0.28, 0.15)]))
			_sword(ci, c + Vector2(-0.62, 0.35) * size, size * 0.42, col, -PI * 0.25)
		&"catch":
			ci.draw_arc(c + Vector2(0, 0.1) * size, size * 0.62, 0.0, PI, 16, col, w, true)
			ci.draw_line(c + Vector2(0, -0.95) * size, c + Vector2(0, -0.05) * size, col, w, true)
			_poly(ci, c, size, 0.0, col, PackedVector2Array([Vector2(0, 0.15), Vector2(0.3, -0.2), Vector2(-0.3, -0.2)]))
		&"dodge":
			for x: float in [-0.45, 0.2]:
				_poly(ci, c, size, 0.0, col, PackedVector2Array([Vector2(x, -0.65), Vector2(x + 0.25, -0.65), Vector2(x + 0.7, 0.0),
					Vector2(x + 0.25, 0.65), Vector2(x, 0.65), Vector2(x + 0.45, 0.0)]))
			ci.draw_line(c + Vector2(-0.95, -0.3) * size, c + Vector2(-0.6, -0.3) * size, col, w * 0.5, true)
			ci.draw_line(c + Vector2(-0.95, 0.3) * size, c + Vector2(-0.6, 0.3) * size, col, w * 0.5, true)
		&"lock_on":
			ci.draw_arc(c, size * 0.62, 0.0, TAU, 28, col, w * 0.8, true)
			for a in 4:
				var d := Vector2.from_angle(a * PI * 0.5)
				ci.draw_line(c + d * size * 0.4, c + d * size * 0.98, col, w * 0.8, true)
			ci.draw_circle(c, size * 0.12, col)
		&"block":
			_poly(ci, c, size, 0.0, col, PackedVector2Array([Vector2(-0.7, -0.8), Vector2(0.7, -0.8), Vector2(0.7, -0.1),
				Vector2(0.45, 0.45), Vector2(0.0, 0.92), Vector2(-0.45, 0.45), Vector2(-0.7, -0.1)]))
			ci.draw_line(c + Vector2(0, -0.6) * size, c + Vector2(0, 0.55) * size, Color(0, 0, 0, col.a * 0.45), w * 0.7)
		&"power":
			_poly(ci, c, size, 0.0, col, PackedVector2Array([Vector2(0.2, -1.0), Vector2(-0.55, 0.12), Vector2(-0.05, 0.12),
				Vector2(-0.25, 1.0), Vector2(0.6, -0.18), Vector2(0.08, -0.18), Vector2(0.35, -1.0)]))
		&"swap":
			ci.draw_line(c + Vector2(-0.75, -0.35) * size, c + Vector2(0.55, -0.35) * size, col, w, true)
			_poly(ci, c, size, 0.0, col, PackedVector2Array([Vector2(0.95, -0.35), Vector2(0.5, -0.68), Vector2(0.5, -0.02)]))
			ci.draw_line(c + Vector2(0.75, 0.35) * size, c + Vector2(-0.55, 0.35) * size, col, w, true)
			_poly(ci, c, size, 0.0, col, PackedVector2Array([Vector2(-0.95, 0.35), Vector2(-0.5, 0.02), Vector2(-0.5, 0.68)]))
		&"skill":
			var pts := PackedVector2Array()
			for k in 8:
				var a := -PI * 0.5 + k * PI * 0.25
				pts.append(Vector2.from_angle(a) * (0.98 if k % 2 == 0 else 0.3))
			_poly(ci, c, size, 0.0, col, pts)
			ci.draw_circle(c + Vector2(0.72, -0.68) * size, size * 0.11, col)
			ci.draw_circle(c + Vector2(-0.7, 0.66) * size, size * 0.08, col)


## The ATTACK picture for what you hold.
static func attack_icon(w: WeaponData) -> StringName:
	match FPViewModel.family(w):
		&"": return &"fist"
		&"fist": return &"fist"
		&"heavy": return &"hammer"
		&"polearm": return &"spear"
		&"ranged": return &"gun"
		&"bow": return &"bow"
		&"shield": return &"block"
	return &"sword"


static func _sword(ci: CanvasItem, c: Vector2, size: float, col: Color, rot: float) -> void:
	_poly(ci, c, size, rot, col, PackedVector2Array([Vector2(0, -1.0), Vector2(0.13, -0.78), Vector2(0.13, 0.28),
		Vector2(-0.13, 0.28), Vector2(-0.13, -0.78)]))
	_poly(ci, c, size, rot, col, _rect(-0.42, 0.28, 0.42, 0.42))
	_poly(ci, c, size, rot, col, _rect(-0.08, 0.42, 0.08, 0.8))
	_poly(ci, c, size, rot, col, _rect(-0.14, 0.8, 0.14, 0.96))


static func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])


static func _poly(ci: CanvasItem, c: Vector2, size: float, rot: float, col: Color, pts: PackedVector2Array) -> void:
	_poly_at(ci, c, size, rot, col, pts)


static func _poly_at(ci: CanvasItem, c: Vector2, size: float, rot: float, col: Color, pts: PackedVector2Array) -> void:
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + p.rotated(rot) * size)
	ci.draw_colored_polygon(out, col)
