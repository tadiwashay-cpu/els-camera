extends Arena
## Blockout Yard: the grey-box test arena. A 56 m deck over the void (fall
## off and it's a KO), three levels (ground, 2.5 m side decks, a 5 m tower),
## a mid-height bridge and 6 weapon spawners. Most cover can be smashed:
## crates, crate stacks, stone pillars, the edge railings (opening gaps for
## ring-outs) and explosive barrels.

const GROUND := Color(0.5, 0.55, 0.62)
const MID := Color(0.86, 0.54, 0.3)
const HIGH := Color(0.28, 0.6, 0.66)
const COVER := Color(0.74, 0.64, 0.45)
const WALL := Color(0.5, 0.54, 0.62)


func build() -> void:
	kill_y = -14.0
	bounds = 30.0
	# Ground deck with a skirt underneath so the edge reads as a drop.
	block(Vector3(56, 1, 56), Vector3(0, -0.5, 0), GROUND)
	block(Vector3(52, 6, 52), Vector3(0, -4.0, 0), WALL.darkened(0.25))
	# Breakable railings on the north and south edges (4.5 m segments, with
	# gaps): smash one and that stretch of edge is open for a ring-out.
	for z: float in [-27.5, 27.5]:
		for x: float in [-23.75, -19.25, -14.75, -10.25, 10.25, 14.75, 19.25, 23.75]:
			breakable(Breakable.Kind.RAIL, Vector3(4.4, 1.1, 0.7), Vector3(x, 0.55, z), WALL)

	# Side decks (mid level, 2.5 m) with ramps at both ends.
	for x: float in [-17.0, 17.0]:
		block(Vector3(8, 2.5, 18), Vector3(x, 1.25, 0), MID)
		ramp(Vector3(x, 0, 16.5), Vector3(x, 2.5, 9.0), 4.0, MID.darkened(0.1))
		ramp(Vector3(x, 0, -16.5), Vector3(x, 2.5, -9.0), 4.0, MID.darkened(0.1))

	# Central tower (high level, 5 m) reached from the east deck by a ramp.
	block(Vector3(7, 5, 7), Vector3(0, 2.5, 0), HIGH)
	ramp(Vector3(13.0, 2.5, -2.0), Vector3(3.5, 5.0, -2.0), 3.0, HIGH.darkened(0.1))
	# Mid bridge from deck to deck across the north side.
	block(Vector3(26, 0.5, 3), Vector3(0, 2.25, 7.5), MID.lightened(0.1))

	# Cover you can smash: big crates, crate stacks, stone pillars.
	for p: Vector3 in [Vector3(-8, 1, -12), Vector3(9, 1, 14), Vector3(-10, 1, 15), Vector3(7, 1, -15),
			Vector3(-23, 1, -20), Vector3(23, 1, 20)]:
		breakable(Breakable.Kind.CRATE, Vector3(2, 2, 2), p, COVER)
	for base: Vector3 in [Vector3(-10, 0, -5), Vector3(12, 0, 4), Vector3(-4, 0, 20), Vector3(22, 0, -8)]:
		breakable(Breakable.Kind.CRATE, Vector3(1, 1, 1), base + Vector3(-0.55, 0.5, 0), COVER.lightened(0.08))
		breakable(Breakable.Kind.CRATE, Vector3(1, 1, 1), base + Vector3(0.55, 0.5, 0.1), COVER.darkened(0.05))
		breakable(Breakable.Kind.CRATE, Vector3(1, 1, 1), base + Vector3(0.0, 1.5, 0.05), COVER)
	for p: Vector3 in [Vector3(-6, 2, 4), Vector3(6, 2, -6)]:
		breakable(Breakable.Kind.PILLAR, Vector3(1, 4, 1), p, WALL.lightened(0.1))
	breakable(Breakable.Kind.CRATE, Vector3(4, 1, 2), Vector3(0, 0.5, -18), COVER)
	breakable(Breakable.Kind.CRATE, Vector3(2, 1, 4), Vector3(-24, 0.5, 6), COVER)
	# Explosive barrels: hit one near your opponent.
	for p: Vector3 in [Vector3(4.5, 0.55, -11), Vector3(-5, 0.55, 13), Vector3(19.5, 3.05, 5), Vector3(-19.5, 3.05, -5),
			Vector3(-12, 0.55, 22), Vector3(14, 0.55, -21)]:
		breakable(Breakable.Kind.BARREL, Vector3(0.8, 1.1, 0.8), p, Color(0.85, 0.16, 0.12))

	spawn_points = [Vector3(-22, 0.1, -22), Vector3(22, 0.1, 22), Vector3(22, 0.1, -22), Vector3(-22, 0.1, 22),
		Vector3(0, 0.1, -24), Vector3(0, 0.1, 24), Vector3(-25, 0.1, -4), Vector3(25, 0.1, 4)]
	pickup_points = [Vector3(0, 0.0, 9.5), Vector3(-17, 2.5, 6), Vector3(17, 2.5, -6), Vector3(2.2, 5.0, 2.2),
		Vector3(-20, 0.0, -14), Vector3(20, 0.0, 14)]
	spawner_points = [Vector3(0, 5.0, 0), Vector3(-17, 2.5, 0), Vector3(17, 2.5, 0),
		Vector3(0, 0.0, -10), Vector3(0, 0.0, 16), Vector3(-12, 0.0, -2)]
