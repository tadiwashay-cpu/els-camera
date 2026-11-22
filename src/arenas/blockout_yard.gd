extends Arena
## Blockout Yard: the grey-box test arena for Phase 1. A 56 m deck over
## the void (fall off and it's a KO), three levels (ground, 2.5 m side
## decks, a 5 m tower), a mid-height bridge, cover blocks and 6 weapon
## spawners. Built from boxes so fights can be tuned before any art.

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
	# Low walls on the north and south edges, with gaps to fall through.
	for z: float in [-27.5, 27.5]:
		block(Vector3(18, 1.1, 1), Vector3(-17, 0.55, z), WALL)
		block(Vector3(18, 1.1, 1), Vector3(17, 0.55, z), WALL)

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

	# Cover.
	for p: Vector3 in [Vector3(-8, 1, -12), Vector3(9, 1, 14), Vector3(-10, 1, 15), Vector3(7, 1, -15),
			Vector3(-23, 1, -20), Vector3(23, 1, 20)]:
		block(Vector3(2, 2, 2), p, COVER)
	for p: Vector3 in [Vector3(-6, 2, 4), Vector3(6, 2, -6)]:
		block(Vector3(1, 4, 1), p, WALL)
	block(Vector3(4, 1, 2), Vector3(0, 0.5, -18), COVER)
	block(Vector3(2, 1, 4), Vector3(-24, 0.5, 6), COVER)

	spawn_points = [Vector3(-22, 0.1, -22), Vector3(22, 0.1, 22), Vector3(22, 0.1, -22), Vector3(-22, 0.1, 22),
		Vector3(0, 0.1, -24), Vector3(0, 0.1, 24), Vector3(-25, 0.1, -4), Vector3(25, 0.1, 4)]
	spawner_points = [Vector3(0, 5.0, 0), Vector3(-17, 2.5, 0), Vector3(17, 2.5, 0),
		Vector3(0, 0.0, -10), Vector3(0, 0.0, 16), Vector3(-12, 0.0, -2)]
