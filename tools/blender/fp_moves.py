"""First-person weapon moves: how the floating weapon moves in front of the
camera in first person (no arms, no body, just the weapon).

Every key is an offset from the weapon family's resting pose (the game
holds those, src/fighter/fp_view_model.gd), in CAMERA space as Godot has
it: x right, y up, z towards you (forward is -z).

The angles are an AIM, not a raw rotation, so a swing reads the way it
looks on screen (degrees, added to the family's rest aim):
  yaw    where the tip points sideways: + to the right, - to the left
  pitch  how high the tip points: 0 straight ahead, +90 straight up,
         -90 straight down (past 90 = leaning back over the shoulder)
  roll   spin about the weapon's own length (which way the flat faces)
A blade with pitch 0 and roll 0 lies flat, edges to the sides: right for a
sideways slash; roll 90 stands it on its edge for a chop.

Time runs 0..1 over the third-person move it shadows; `strike` is the part
of the swing that should line up with that move's hit (or release / fire)
window, so the game stretches the move to fit.

  FP_MOVES[name] = dict(loop, strike, keys=[(t, (x, y, z), (yaw, pitch, roll)), ...])
"""

REST = ((0.0, 0.0, 0.0), (0.0, 0.0, 0.0))


def move(keys, loop=False, strike=None):
    return {"loop": loop, "strike": strike, "keys": keys}


def held(pos, aim, shake=0.004, wobble=0.6):
    """A held pose (loop) that trembles a little."""
    p2 = (pos[0] + shake, pos[1] + shake, pos[2])
    a2 = (aim[0] + wobble, aim[1] + wobble, aim[2])
    return move([(0.0, pos, aim), (0.5, p2, a2), (1.0, pos, aim)], loop=True)


FP_MOVES = {
    # Right to left across the view: wind up on the right, the blade flat
    # through the middle, follow through low on the left.
    "FP_SlashA": move([
        (0.0, *REST),
        (0.30, (0.10, 0.08, 0.04), (70.0, -5.0, -20.0)),
        (0.42, (-0.06, 0.02, -0.12), (-25.0, -48.0, 0.0)),
        (0.52, (-0.32, 0.10, -0.10), (-95.0, -55.0, 10.0)),
        (0.70, (-0.28, 0.02, -0.04), (-90.0, -70.0, 10.0)),
        (1.0, *REST),
    ], strike=(0.30, 0.52)),
    # The backhand, left to right.
    "FP_SlashB": move([
        (0.0, *REST),
        (0.30, (-0.30, 0.06, 0.02), (-95.0, -20.0, 0.0)),
        (0.42, (0.0, 0.0, -0.14), (-10.0, -50.0, 0.0)),
        (0.52, (0.14, 0.08, -0.12), (75.0, -55.0, 0.0)),
        (0.70, (0.12, 0.0, -0.04), (70.0, -70.0, 0.0)),
        (1.0, *REST),
    ], strike=(0.30, 0.52)),
    # Overhead chop: up and back over the shoulder, down through the middle.
    "FP_Chop": move([
        (0.0, *REST),
        (0.36, (-0.14, 0.55, 0.25), (10.0, 60.0, 90.0)),
        (0.47, (-0.12, 0.12, -0.10), (10.0, -20.0, 90.0)),
        (0.56, (-0.12, 0.0, -0.18), (10.0, -95.0, 90.0)),
        (0.75, (-0.10, -0.06, -0.12), (10.0, -92.0, 90.0)),
        (1.0, *REST),
    ], strike=(0.36, 0.56)),
    # Point it ahead, draw back, stab.
    "FP_Stab": move([
        (0.0, *REST),
        (0.30, (0.02, -0.02, 0.10), (8.0, -40.0, 0.0)),
        (0.46, (-0.06, 0.04, -0.28), (8.0, -45.0, 0.0)),
        (0.70, (-0.05, 0.03, -0.20), (8.0, -42.0, 0.0)),
        (1.0, *REST),
    ], strike=(0.30, 0.46)),
    # Spear thrust: back, then a long reach.
    "FP_Thrust": move([
        (0.0, *REST),
        (0.30, (0.0, 0.0, 0.16), (0.0, -5.0, 0.0)),
        (0.50, (-0.06, 0.04, -0.60), (3.0, -12.0, 0.0)),
        (0.72, (-0.05, 0.03, -0.45), (2.0, -10.0, 0.0)),
        (1.0, *REST),
    ], strike=(0.30, 0.50)),
    "FP_Lunge": move([
        (0.0, *REST),
        (0.25, (0.0, 0.02, 0.22), (0.0, -4.0, 0.0)),
        (0.45, (-0.08, 0.05, -0.85), (4.0, -12.0, 0.0)),
        (0.75, (-0.06, 0.04, -0.70), (3.0, -10.0, 0.0)),
        (1.0, *REST),
    ], strike=(0.25, 0.45)),
    # Polearm sweep: the tip from far right to far left.
    "FP_Sweep": move([
        (0.0, *REST),
        (0.30, (0.12, 0.06, 0.08), (35.0, 5.0, 0.0)),
        (0.45, (0.0, 0.06, -0.05), (-5.0, -5.0, 0.0)),
        (0.60, (-0.30, 0.10, -0.06), (-60.0, -8.0, 0.0)),
        (0.78, (-0.26, 0.06, -0.02), (-55.0, -12.0, 0.0)),
        (1.0, *REST),
    ], strike=(0.30, 0.60)),
    # Two-handed overhead smash.
    "FP_Smash": move([
        (0.0, *REST),
        (0.40, (-0.08, 0.75, 0.10), (15.0, 70.0, 0.0)),
        (0.50, (-0.10, 0.20, -0.15), (15.0, -10.0, 0.0)),
        (0.58, (-0.16, 0.02, -0.25), (15.0, -70.0, 0.0)),
        (0.80, (-0.16, 0.0, -0.22), (15.0, -68.0, 0.0)),
        (1.0, *REST),
    ], strike=(0.40, 0.58)),
    # Releasing a charged smash: it starts up high.
    "FP_Slam": move([
        (0.0, (-0.08, 0.75, 0.10), (15.0, 65.0, 0.0)),
        (0.10, (-0.10, 0.20, -0.15), (15.0, -10.0, 0.0)),
        (0.20, (-0.16, 0.0, -0.28), (15.0, -74.0, 0.0)),
        (0.60, (-0.16, 0.0, -0.26), (15.0, -72.0, 0.0)),
        (1.0, *REST),
    ], strike=(0.0, 0.20)),
    # The heavy spin: the weapon whips across twice, coming back round
    # from the right under the view.
    "FP_Spin": move([
        (0.0, *REST),
        (0.12, (0.25, 0.08, 0.05), (80.0, -30.0, 0.0)),
        (0.30, (-0.10, 0.08, -0.12), (0.0, -35.0, 0.0)),
        (0.40, (-0.50, 0.08, 0.10), (-110.0, -35.0, 0.0)),
        (0.42, (-0.50, -0.60, 0.20), (-110.0, -35.0, 0.0)),
        (0.44, (0.50, -0.60, 0.20), (110.0, -35.0, 0.0)),
        (0.46, (0.50, 0.08, 0.10), (110.0, -35.0, 0.0)),
        (0.60, (-0.10, 0.08, -0.12), (0.0, -35.0, 0.0)),
        (0.72, (-0.45, 0.06, 0.0), (-100.0, -35.0, 0.0)),
        (1.0, *REST),
    ], strike=(0.12, 0.80)),
    # Held while charging a heavy: drawn back, trembling.
    "FP_Charge": held((0.10, 0.12, 0.12), (35.0, 15.0, -20.0)),
    "FP_SmashCharge": held((-0.08, 0.75, 0.10), (15.0, 65.0, 0.0)),
    # Throw: wind back, fling, then gone below the view until the next one.
    "FP_Throw": move([
        (0.0, *REST),
        (0.32, (0.10, 0.20, 0.22), (20.0, 40.0, 0.0)),
        (0.42, (0.0, 0.05, -0.45), (0.0, -40.0, 0.0)),
        (0.48, (0.10, -0.75, 0.0), (0.0, -40.0, 0.0)),
        (0.85, (0.10, -0.75, 0.0), (0.0, -40.0, 0.0)),
        (1.0, *REST),
    ], strike=(0.38, 0.42)),
    # Gun kick: muzzle up, back into the hand.
    "FP_Recoil": move([
        (0.0, *REST),
        (0.10, (0.0, 0.03, 0.08), (0.0, 14.0, 0.0)),
        (0.50, *REST),
        (1.0, *REST),
    ], strike=(0.0, 0.08)),
    "FP_BowDraw": held((0.10, 0.04, 0.04), (0.0, -2.0, 0.0), shake=0.002, wobble=0.4),
    "FP_BowRelease": move([
        (0.0, (0.10, 0.04, 0.04), (0.0, -2.0, 0.0)),
        (0.10, (0.08, 0.06, 0.10), (0.0, 6.0, 0.0)),
        (0.50, *REST),
        (1.0, *REST),
    ], strike=(0.0, 0.10)),
    # Guard: the blade across the view, tip to the left.
    "FP_Block": held((-0.16, 0.14, -0.02), (-80.0, -45.0, 0.0), shake=0.003, wobble=0.5),
    "FP_Parry": move([
        (0.0, (-0.16, 0.14, -0.02), (-80.0, -45.0, 0.0)),
        (0.22, (-0.06, 0.18, -0.14), (-40.0, -20.0, 0.0)),
        (1.0, *REST),
    ], strike=(0.0, 0.22)),
    # Shield: shove it out; bring it to the middle for a block; lift it
    # high and drive it down.
    "FP_ShieldBash": move([
        (0.0, *REST),
        (0.30, (0.0, 0.0, 0.10), (-10.0, 0.0, 0.0)),
        (0.48, (0.14, 0.02, -0.34), (30.0, 0.0, 0.0)),
        (0.70, (0.12, 0.02, -0.26), (28.0, 0.0, 0.0)),
        (1.0, *REST),
    ], strike=(0.30, 0.48)),
    "FP_ShieldBlock": held((0.24, 0.14, 0.10), (33.0, 0.0, 0.0), shake=0.003, wobble=0.5),
    "FP_ShieldRaise": held((0.25, 0.32, 0.0), (35.0, 0.0, 0.0)),
    "FP_ShieldSlam": move([
        (0.0, (0.25, 0.32, 0.0), (35.0, 0.0, 0.0)),
        (0.20, (0.25, -0.20, -0.30), (35.0, -40.0, 0.0)),
        (0.60, (0.25, -0.18, -0.28), (35.0, -38.0, 0.0)),
        (1.0, *REST),
    ], strike=(0.0, 0.20)),
    # Weapon power: raise it, then thrust it out.
    "FP_Cast": move([
        (0.0, *REST),
        (0.30, (0.0, 0.18, 0.06), (0.0, 25.0, 0.0)),
        (0.55, (-0.06, 0.06, -0.30), (-5.0, -35.0, 0.0)),
        (0.80, (-0.04, 0.03, -0.22), (-4.0, -30.0, 0.0)),
        (1.0, *REST),
    ], strike=(0.30, 0.55)),
    # Calling the sky (and powering up): dip, then the weapon held straight
    # up in the middle of the view.
    "FP_CastSky": move([
        (0.0, *REST),
        (0.20, (0.0, -0.20, 0.05), (0.0, -30.0, 0.0)),
        (0.38, (-0.10, 0.30, -0.05), (10.0, 30.0, 0.0)),
        (0.65, (-0.10, 0.29, -0.05), (10.0, 29.0, 0.0)),
        (1.0, *REST),
    ], strike=(0.30, 0.38)),
    # Pull: reach out, then yank it back towards you.
    "FP_Pull": move([
        (0.0, *REST),
        (0.12, (-0.06, 0.04, -0.35), (5.0, -40.0, 0.0)),
        (0.22, (-0.06, 0.04, -0.37), (5.0, -41.0, 0.0)),
        (0.42, (0.04, -0.06, 0.18), (10.0, 10.0, -20.0)),
        (0.62, (0.04, -0.06, 0.17), (10.0, 9.0, -20.0)),
        (1.0, *REST),
    ], strike=(0.18, 0.24)),
    # Snapping a caught weapon into the hand; a new weapon coming up.
    "FP_Catch": move([
        (0.0, (0.0, -0.45, 0.10), (0.0, -30.0, 0.0)),
        (0.35, (0.0, 0.03, -0.02), (0.0, 5.0, 0.0)),
        (1.0, *REST),
    ]),
    "FP_Equip": move([
        (0.0, (0.05, -0.55, 0.10), (10.0, -45.0, 20.0)),
        (0.6, (0.0, 0.02, 0.0), (0.0, 3.0, 0.0)),
        (1.0, *REST),
    ]),
    # Flinch or landing: a dip.
    "FP_Dip": move([
        (0.0, *REST),
        (0.25, (0.0, -0.10, 0.03), (0.0, -8.0, 0.0)),
        (1.0, *REST),
    ]),
}
