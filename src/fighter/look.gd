class_name Look
extends RefCounted
## Fighter customisation (Locker screen): skin tone, clothes colours, hair,
## a hat and a face. Colours are free; some hair, hats and faces cost coins.
## A look is a small Dictionary of palette indices and part ids (the save's
## "look"; online it rides the roster) that becomes a SkinData; BlockBody
## builds the head parts with build_head (all boxes in the one body mesh).

const SKIN_TONES: Array[Color] = [Color(1.0, 0.86, 0.72), Color(0.96, 0.78, 0.6), Color(0.88, 0.66, 0.46),
	Color(0.74, 0.52, 0.34), Color(0.56, 0.38, 0.24), Color(0.4, 0.27, 0.17), Color(0.3, 0.2, 0.13),
	Color(0.62, 0.85, 0.55)]
const CLOTH: Array[Color] = [Color(0.95, 0.45, 0.12), Color(0.9, 0.18, 0.16), Color(1.0, 0.8, 0.15),
	Color(0.3, 0.75, 0.3), Color(0.15, 0.6, 0.55), Color(0.25, 0.55, 0.95), Color(0.2, 0.25, 0.6),
	Color(0.55, 0.3, 0.85), Color(0.95, 0.45, 0.7), Color(0.2, 0.22, 0.3), Color(0.92, 0.92, 0.9),
	Color(0.12, 0.12, 0.14), Color(0.5, 0.36, 0.24), Color(0.55, 0.57, 0.6)]
const HAIR_COLORS: Array[Color] = [Color(0.12, 0.09, 0.07), Color(0.32, 0.2, 0.12), Color(0.6, 0.38, 0.18),
	Color(0.9, 0.75, 0.42), Color(0.75, 0.25, 0.1), Color(0.85, 0.85, 0.88), Color(0.2, 0.5, 0.95),
	Color(0.95, 0.35, 0.65), Color(0.3, 0.8, 0.4), Color(0.55, 0.3, 0.85)]

## part id -> [menu name, price]
const HAIR := {&"band": ["Headband", 0], &"short": ["Short", 0], &"bald": ["Bald", 0], &"spiky": ["Spiky", 150],
	&"bob": ["Bob", 150], &"ponytail": ["Ponytail", 200], &"mohawk": ["Mohawk", 250]}
const HATS := {&"none": ["No hat", 0], &"bandana": ["Bandana", 150], &"cap": ["Cap", 200], &"beanie": ["Beanie", 200],
	&"headphones": ["Headphones", 300], &"helmet": ["Helmet", 400], &"crown": ["Crown", 800]}
const FACES := {&"fierce": ["Fierce", 0], &"happy": ["Happy", 0], &"calm": ["Calm", 0], &"grin": ["Grin", 150],
	&"surprised": ["Surprised", 150], &"shades": ["Shades", 300]}
const KINDS := {&"hair": HAIR, &"hat": HATS, &"face": FACES}

const DEFAULT := {"skin": 1, "shirt": 0, "pants": 9, "shoes": 11, "hair": "band", "hair_color": 0,
	"hat": "none", "hat_color": 0, "face": "fierce"}


## Your look, from the save.
static func mine() -> Dictionary:
	return clean(Save.data.get("look", {}))


## A look from anywhere (save, network) made safe.
static func clean(raw: Variant) -> Dictionary:
	var d: Dictionary = raw if raw is Dictionary else {}
	var out := DEFAULT.duplicate()
	for key: String in ["skin", "shirt", "pants", "shoes", "hair_color", "hat_color"]:
		var v: Variant = d.get(key, out[key])
		out[key] = int(v) if (v is int or v is float) else int(out[key])
	out["skin"] = posmod(int(out["skin"]), SKIN_TONES.size())
	for key: String in ["shirt", "pants", "shoes", "hat_color"]:
		out[key] = posmod(int(out[key]), CLOTH.size())
	out["hair_color"] = posmod(int(out["hair_color"]), HAIR_COLORS.size())
	for kind: StringName in KINDS:
		var v := StringName(str(d.get(String(kind), out[String(kind)])))
		out[String(kind)] = String(v) if (KINDS[kind] as Dictionary).has(v) else str(DEFAULT[String(kind)])
	return out


static func price(kind: StringName, id: StringName) -> int:
	var table: Dictionary = KINDS.get(kind, {})
	return int(table[id][1]) if table.has(id) else 0


static func owns(kind: StringName, id: StringName) -> bool:
	return price(kind, id) == 0 or (Save.data.get("looks_owned", []) as Array).has("%s:%s" % [kind, id])


static func buy(kind: StringName, id: StringName) -> bool:
	if owns(kind, id):
		return true
	var cost := price(kind, id)
	if int(Save.data["coins"]) < cost:
		return false
	Save.data["coins"] = int(Save.data["coins"]) - cost
	(Save.data["looks_owned"] as Array).append("%s:%s" % [kind, id])
	Save.save_data()
	return true


## Keeps `look` as your look (only parts you own).
static func save_mine(look: Dictionary) -> void:
	var c := clean(look)
	for kind: StringName in KINDS:
		if not owns(kind, StringName(c[String(kind)])):
			c[String(kind)] = DEFAULT[String(kind)]
	Save.data["look"] = c
	Save.save_data()


## A bot's look: random but tidy (seeded, so every machine agrees).
static func random(rng: RandomNumberGenerator) -> Dictionary:
	var pick := func(table: Dictionary) -> String:
		var keys := table.keys()
		return String(keys[rng.randi() % keys.size()])
	var hat: String = pick.call(HATS) if rng.randf() < 0.5 else "none"
	return clean({"skin": rng.randi() % 7, "shirt": rng.randi() % CLOTH.size(), "pants": rng.randi() % CLOTH.size(),
		"shoes": [9, 11, 12, 10][rng.randi() % 4], "hair": pick.call(HAIR), "hair_color": rng.randi() % HAIR_COLORS.size(),
		"hat": hat, "hat_color": rng.randi() % CLOTH.size(), "face": pick.call(FACES)})


## The SkinData for a look.
static func skin_data(look: Dictionary, id: StringName = &"custom") -> SkinData:
	var c := clean(look)
	var s := SkinData.new()
	s.id = id
	s.display_name = "Custom"
	s.skin = SKIN_TONES[int(c["skin"])]
	s.shirt = CLOTH[int(c["shirt"])]
	s.sleeve = s.shirt.darkened(0.12)
	s.pants = CLOTH[int(c["pants"])]
	s.belt = s.pants.darkened(0.45)
	s.shoes = CLOTH[int(c["shoes"])]
	s.trail = s.shirt.lightened(0.3)
	s.hair = StringName(c["hair"])
	s.hair_color = HAIR_COLORS[int(c["hair_color"])]
	s.hat = StringName(c["hat"])
	s.hat_color = CLOTH[int(c["hat_color"])]
	s.face = StringName(c["face"])
	return s


# ------------------------------------------------------------- head parts

## Head, face, hair and hat boxes into `b` (skinned to `bone`). `at` maps a
## head-space point (head cube centred at (0, 0.14, 0.01), 0.3 wide; the
## face is at z 0.16, the top at y 0.29) to model space.
static func build_head(b: BoxBuilder, s: SkinData, bone: int, at: Callable, hs: float) -> void:
	var box := func(size: Vector3, centre: Vector3, color: Color, basis: Basis = Basis.IDENTITY) -> void:
		b.box(size * hs, at.call(centre), color, bone, basis)
	box.call(Vector3(0.3, 0.3, 0.3), Vector3(0, 0.14, 0.01), s.skin)
	_face(box, s)
	var hatted := s.hat != &"none" and s.hat != &""
	_hair(box, s, hatted)
	if hatted:
		_hat(box, s)


static func _face(box: Callable, s: SkinData) -> void:
	var z := 0.168
	var ink := s.eyes
	match s.face:
		&"happy":
			for x: float in [0.07, -0.07]:
				box.call(Vector3(0.055, 0.07, 0.018), Vector3(x, 0.16, z), ink)
				box.call(Vector3(0.07, 0.02, 0.018), Vector3(x, 0.228, z), ink)
				box.call(Vector3(0.025, 0.03, 0.018), Vector3(x * 0.72, 0.09, z), ink)
			box.call(Vector3(0.08, 0.022, 0.018), Vector3(0, 0.075, z), ink)
		&"calm":
			for x: float in [0.07, -0.07]:
				box.call(Vector3(0.06, 0.035, 0.018), Vector3(x, 0.155, z), ink)
				box.call(Vector3(0.075, 0.018, 0.018), Vector3(x, 0.21, z), ink)
			box.call(Vector3(0.06, 0.02, 0.018), Vector3(0, 0.075, z), ink)
		&"grin":
			for x: float in [0.07, -0.07]:
				box.call(Vector3(0.055, 0.07, 0.018), Vector3(x, 0.165, z), ink)
				box.call(Vector3(0.08, 0.02, 0.018), Vector3(x, 0.222, z), ink, Basis(Vector3.BACK, 0.18 * signf(x)))
			box.call(Vector3(0.15, 0.055, 0.018), Vector3(0, 0.072, z), ink)
			box.call(Vector3(0.13, 0.026, 0.018), Vector3(0, 0.078, z + 0.004), Color(0.97, 0.96, 0.92))
		&"surprised":
			for x: float in [0.072, -0.072]:
				box.call(Vector3(0.06, 0.09, 0.018), Vector3(x, 0.16, z), ink)
				box.call(Vector3(0.07, 0.02, 0.018), Vector3(x, 0.24, z), ink)
			box.call(Vector3(0.05, 0.055, 0.018), Vector3(0, 0.07, z), ink)
		&"shades":
			box.call(Vector3(0.26, 0.065, 0.022), Vector3(0, 0.168, z + 0.002), Color(0.05, 0.05, 0.07))
			box.call(Vector3(0.02, 0.02, 0.24), Vector3(0.15, 0.18, 0.05), Color(0.05, 0.05, 0.07))
			box.call(Vector3(0.02, 0.02, 0.24), Vector3(-0.15, 0.18, 0.05), Color(0.05, 0.05, 0.07))
			box.call(Vector3(0.07, 0.02, 0.018), Vector3(0.02, 0.07, z), ink, Basis(Vector3.BACK, 0.18))
		_:   # fierce
			for x: float in [0.07, -0.07]:
				box.call(Vector3(0.055, 0.075, 0.018), Vector3(x, 0.16, z), ink)
				box.call(Vector3(0.085, 0.02, 0.018), Vector3(x * 1.03, 0.215, z), ink, Basis(Vector3.BACK, 0.32 * signf(x)))
			box.call(Vector3(0.1, 0.022, 0.018), Vector3(0, 0.07, z), ink)


## Hair; under a hat only the parts that show below it.
static func _hair(box: Callable, s: SkinData, hatted: bool) -> void:
	var c := s.hair_color
	match s.hair:
		&"band":
			if not hatted:
				box.call(Vector3(0.32, 0.07, 0.32), Vector3(0, 0.29, 0.0), s.shirt.darkened(0.35))
		&"short":
			if not hatted:
				box.call(Vector3(0.32, 0.06, 0.32), Vector3(0, 0.3, -0.005), c)
				box.call(Vector3(0.32, 0.04, 0.04), Vector3(0, 0.27, 0.155), c)
			box.call(Vector3(0.32, 0.14, 0.04), Vector3(0, 0.22, -0.15), c)
		&"spiky":
			if not hatted:
				box.call(Vector3(0.31, 0.04, 0.31), Vector3(0, 0.3, 0.0), c)
				for p: Array in [[0.09, 0.06, -0.35], [-0.09, 0.06, 0.35], [0.0, -0.02, 0.0], [0.09, -0.09, -0.3],
						[-0.09, -0.09, 0.3], [0.0, 0.08, 0.1]]:
					var tilt := Basis(Vector3.BACK, p[2]) * Basis(Vector3.RIGHT, -0.35 if p[1] < 0.0 else 0.25)
					box.call(Vector3(0.07, 0.13, 0.07), Vector3(p[0], 0.35, p[1]), c, tilt)
			box.call(Vector3(0.31, 0.12, 0.04), Vector3(0, 0.23, -0.15), c)
		&"mohawk":
			if not hatted:
				box.call(Vector3(0.08, 0.15, 0.31), Vector3(0, 0.35, -0.01), c)
		&"bob":
			if not hatted:
				box.call(Vector3(0.33, 0.06, 0.33), Vector3(0, 0.3, 0.0), c)
				box.call(Vector3(0.33, 0.05, 0.04), Vector3(0, 0.27, 0.16), c)
			box.call(Vector3(0.04, 0.2, 0.3), Vector3(0.165, 0.2, -0.01), c)
			box.call(Vector3(0.04, 0.2, 0.3), Vector3(-0.165, 0.2, -0.01), c)
			box.call(Vector3(0.33, 0.24, 0.04), Vector3(0, 0.19, -0.16), c)
		&"ponytail":
			if not hatted:
				box.call(Vector3(0.32, 0.06, 0.32), Vector3(0, 0.3, -0.005), c)
				box.call(Vector3(0.32, 0.04, 0.04), Vector3(0, 0.27, 0.155), c)
			box.call(Vector3(0.32, 0.12, 0.04), Vector3(0, 0.23, -0.15), c)
			box.call(Vector3(0.08, 0.22, 0.08), Vector3(0, 0.15, -0.22), c, Basis(Vector3.RIGHT, -0.45))
		_:   # bald
			pass


static func _hat(box: Callable, s: SkinData) -> void:
	var c := s.hat_color
	match s.hat:
		&"cap":
			box.call(Vector3(0.33, 0.1, 0.33), Vector3(0, 0.31, 0.0), c)
			box.call(Vector3(0.3, 0.025, 0.15), Vector3(0, 0.27, 0.22), c.darkened(0.15))
		&"beanie":
			box.call(Vector3(0.33, 0.13, 0.33), Vector3(0, 0.33, 0.0), c)
			box.call(Vector3(0.34, 0.06, 0.34), Vector3(0, 0.27, 0.0), c.darkened(0.2))
			box.call(Vector3(0.08, 0.08, 0.08), Vector3(0, 0.43, 0.0), c.lightened(0.35))
		&"bandana":
			box.call(Vector3(0.32, 0.07, 0.32), Vector3(0, 0.27, 0.0), c)
			box.call(Vector3(0.32, 0.05, 0.32), Vector3(0, 0.31, -0.01), c.darkened(0.1))
			box.call(Vector3(0.05, 0.14, 0.03), Vector3(0.04, 0.2, -0.17), c, Basis(Vector3.BACK, 0.3))
			box.call(Vector3(0.05, 0.14, 0.03), Vector3(-0.04, 0.2, -0.17), c, Basis(Vector3.BACK, -0.3))
		&"headphones":
			box.call(Vector3(0.32, 0.035, 0.06), Vector3(0, 0.31, 0.0), c)
			for x: float in [0.17, -0.17]:
				box.call(Vector3(0.03, 0.12, 0.05), Vector3(x, 0.25, 0.0), c)
				box.call(Vector3(0.05, 0.11, 0.11), Vector3(x * 1.06, 0.15, 0.0), c.darkened(0.3))
		&"helmet":
			box.call(Vector3(0.34, 0.16, 0.34), Vector3(0, 0.3, 0.0), c)
			box.call(Vector3(0.35, 0.03, 0.35), Vector3(0, 0.235, 0.0), c.darkened(0.25))
			box.call(Vector3(0.04, 0.17, 0.35), Vector3(0, 0.31, 0.0), c.lightened(0.25))
		&"crown":
			var gold := Color(1.0, 0.78, 0.2)
			box.call(Vector3(0.3, 0.07, 0.3), Vector3(0, 0.325, 0.0), gold)
			for p: Vector2 in [Vector2(0.12, 0.12), Vector2(-0.12, 0.12), Vector2(0.12, -0.12), Vector2(-0.12, -0.12)]:
				box.call(Vector3(0.05, 0.08, 0.05), Vector3(p.x, 0.39, p.y), gold)
			box.call(Vector3(0.045, 0.045, 0.012), Vector3(0, 0.325, 0.152), c)
