#!/usr/bin/env python3
"""Writes src/weapons/data/<id>.tres for every weapon in the roster below.

Each weapon is a WeaponData resource: stats, which moves it uses, how it is
thrown or fired, and its look as boxes in socket space (+Y runs from the
grip towards the tip). Edit the table and rerun:
    python3 tools/gen_weapons.py
"""

import math
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "src", "weapons", "data")

# Finishes ride in the colour's alpha (see src/weapons/weapon.gdshader):
# 1.0 matte, 0.5 polished metal, 0.0 glowing.
M, G = 0.5, 0.0
WOOD = (0.45, 0.3, 0.16)
DARKWOOD = (0.28, 0.18, 0.1)
LEATHER = (0.3, 0.17, 0.08)
WRAP = (0.16, 0.11, 0.08)
DARK = (0.18, 0.15, 0.13)
BLACK = (0.08, 0.08, 0.09)
WHITE = (0.95, 0.95, 0.95)
RED = (0.82, 0.14, 0.12)
BLUE = (0.18, 0.38, 0.85)
STEEL = (0.84, 0.87, 0.92, M)
STEEL_D = (0.58, 0.62, 0.68, M)
EDGE = (0.97, 0.98, 1.0, M)
IRON = (0.34, 0.36, 0.4, M)
GUNMETAL = (0.26, 0.28, 0.32, M)
GOLD = (0.95, 0.72, 0.25, M)
BRASS = (0.8, 0.6, 0.28, M)

# Families: moves and handling shared by their weapons.
FAMILY = {
    "blade": dict(light_moves=["Slash_A", "Slash_B", "Slash_C"], knockdown_move="Slash_C", heavy_charge="Heavy_Charge",
                  heavy_move="Heavy_Release", hit_from=0.15, hit_to=1.0, hit_radius=0.13),
    "dagger": dict(light_moves=["Stab_A", "Stab_B", "Stab_C"], knockdown_move="", heavy_charge="Heavy_Charge",
                   heavy_move="Heavy_Release", hit_from=0.08, hit_to=0.42, hit_radius=0.14, attack_speed=1.15),
    "rapier": dict(light_moves=["Thrust", "Thrust_B", "Thrust"], knockdown_move="", heavy_charge="Heavy_Charge",
                   heavy_move="Heavy_Release", hit_from=0.2, hit_to=1.08, hit_radius=0.12),
    "heavy": dict(light_moves=["Smash_A", "Smash_B"], knockdown_move="Smash_B", heavy_charge="Smash_Charge",
                  heavy_move="Smash_Release", hit_from=0.45, hit_to=0.85, hit_radius=0.2, idle_clip="Heavy_Idle",
                  slam_radius=2.6, move_speed=0.88, attack_speed=0.95),
    "polearm": dict(light_moves=["Spear_Thrust_A", "Spear_Thrust_B", "Spear_Sweep"], knockdown_move="Spear_Sweep",
                    heavy_charge="", heavy_move="Spear_Lunge", hit_from=0.5, hit_to=1.45, hit_radius=0.13,
                    idle_clip="Spear_Idle", lunge=4.0, heavy_lunge=10.0),
    "fists": dict(light_moves=["Jab", "Cross"], knockdown_move="", heavy_charge="", heavy_move="Kick",
                  strikers={"Jab": "LeftHand", "Cross": "RightHand", "Kick": "RightFoot"}, hit_from=0.0, hit_to=0.0,
                  hit_radius=0.16, throwable=False, catchable=False),
    "thrown": dict(kind="thrown", light_moves=["Toss"], knockdown_move="", heavy_charge="", heavy_move="Toss"),
    "ranged": dict(kind="ranged", light_moves=["Shoot"], knockdown_move="", heavy_charge="", heavy_move="Shoot",
                   idle_clip="Aim", throwable=True),
}


def P(size, centre, color, yaw=0.0):
    """A box part; yaw (degrees) turns it about the socket's Z axis."""
    return (size, centre, color, yaw)


def rings(ys, w, color=WRAP, h=0.018):
    """Grip wraps: thin collars around a handle."""
    return [P((w, h, w), (0, y, 0), color) for y in ys]


def point(y, w, t, color=STEEL, x=0.0):
    """A pointed tip: a square turned 45 degrees."""
    return P((w, w, t), (x, y, 0), color, 45)


# id, name, family, stats, parts
WEAPONS = [
    # Blades -------------------------------------------------------------------
    ("sword", "Sword", "blade", dict(base_damage=16, ref_speed=9, knockback=5.5, throw_damage=26, rarity="common"), [
        P((0.045, 0.2, 0.045), (0, 0, 0), LEATHER), *rings((-0.07, 0.0, 0.07), 0.052),
        P((0.075, 0.055, 0.075), (0, -0.125, 0), GOLD), P((0.045, 0.03, 0.045), (0, -0.165, 0), GOLD),
        P((0.3, 0.045, 0.07), (0, 0.12, 0), GOLD), P((0.045, 0.08, 0.08), (0.16, 0.135, 0), GOLD),
        P((0.045, 0.08, 0.08), (-0.16, 0.135, 0), GOLD), P((0.04, 0.04, 0.085), (0, 0.12, 0), (0.75, 0.08, 0.15)),
        P((0.08, 0.76, 0.022), (0, 0.52, 0), STEEL), P((0.022, 0.6, 0.026), (0, 0.45, 0), STEEL_D),
        P((0.012, 0.74, 0.024), (0.036, 0.53, 0), EDGE), P((0.012, 0.74, 0.024), (-0.036, 0.53, 0), EDGE),
        point(0.9, 0.058, 0.022)]),
    ("katana", "Katana", "blade", dict(base_damage=15, ref_speed=8.5, knockback=4.5, attack_speed=1.12, throw_damage=24), [
        P((0.042, 0.3, 0.04), (0, -0.02, 0), BLACK), *rings((-0.13, -0.07, -0.01, 0.05), 0.047, (0.85, 0.82, 0.74), 0.022),
        P((0.05, 0.03, 0.045), (0, -0.18, 0), GOLD), P((0.12, 0.025, 0.12), (0, 0.15, 0), GOLD),
        P((0.05, 0.06, 0.03), (0, 0.19, 0), GOLD),
        P((0.048, 0.32, 0.018), (0.0, 0.37, 0), STEEL), P((0.046, 0.3, 0.018), (0.012, 0.67, 0), STEEL, -3),
        P((0.044, 0.24, 0.018), (0.03, 0.93, 0), STEEL, -7), P((0.012, 0.84, 0.02), (0.021, 0.6, 0), EDGE, -2),
        P((0.035, 0.08, 0.018), (0.046, 1.07, 0), STEEL, -25)]),
    ("dagger", "Dagger", "dagger", dict(base_damage=10, ref_speed=7, knockback=3.0, throw_damage=22, throw_speed=28), [
        P((0.04, 0.14, 0.04), (0, 0, 0), LEATHER), *rings((-0.03, 0.03), 0.046),
        P((0.06, 0.04, 0.06), (0, -0.09, 0), IRON), P((0.15, 0.03, 0.05), (0, 0.08, 0), IRON),
        P((0.03, 0.05, 0.05), (0.075, 0.1, 0), IRON), P((0.03, 0.05, 0.05), (-0.075, 0.1, 0), IRON),
        P((0.055, 0.26, 0.016), (0, 0.23, 0), STEEL), P((0.015, 0.18, 0.02), (0, 0.2, 0), STEEL_D),
        point(0.36, 0.04, 0.016)]),
    ("rapier", "Rapier", "rapier", dict(base_damage=13, ref_speed=7.5, knockback=3.5, attack_speed=1.1), [
        P((0.035, 0.16, 0.035), (0, 0, 0), WRAP), *rings((-0.05, 0.0, 0.05), 0.042, GOLD, 0.012),
        P((0.055, 0.05, 0.055), (0, -0.105, 0), GOLD), P((0.14, 0.035, 0.14), (0, 0.1, 0), GOLD),
        P((0.015, 0.2, 0.015), (0.075, 0.0, 0), GOLD), P((0.26, 0.02, 0.02), (0, 0.12, 0), GOLD),
        P((0.03, 0.08, 0.02), (0, 0.16, 0), STEEL_D), P((0.022, 0.96, 0.016), (0, 0.62, 0), STEEL),
        point(1.1, 0.018, 0.016)]),
    ("hand_axe", "Hand Axe", "blade", dict(base_damage=18, ref_speed=9, knockback=6.5, attack_speed=0.95, throw_damage=30), [
        P((0.05, 0.62, 0.05), (0, 0.2, 0), WOOD), P((0.056, 0.16, 0.056), (0, -0.02, 0), LEATHER),
        P((0.06, 0.04, 0.06), (0, -0.12, 0), IRON), P((0.07, 0.14, 0.07), (0, 0.46, 0), IRON),
        P((0.2, 0.12, 0.035), (-0.12, 0.45, 0), STEEL), P((0.06, 0.24, 0.03), (-0.21, 0.45, 0), STEEL),
        P((0.015, 0.24, 0.036), (-0.24, 0.45, 0), EDGE), P((0.08, 0.04, 0.04), (0.07, 0.46, 0), IRON)]),
    ("plasma_blade", "Plasma Blade", "blade", dict(base_damage=24, ref_speed=9, knockback=7, rarity="rare", glow=(0.3, 0.9, 1.0),
                                                   throw_damage=34), [
        P((0.05, 0.26, 0.05), (0, 0, 0), GUNMETAL), *rings((-0.07, -0.02, 0.03), 0.056, BLACK, 0.02),
        P((0.07, 0.06, 0.07), (0, 0.15, 0), STEEL_D), P((0.08, 0.02, 0.08), (0, 0.185, 0), (0.3, 0.9, 1.0, G)),
        P((0.02, 0.03, 0.03), (0.03, 0.05, 0), (1.0, 0.2, 0.2, G)), P((0.06, 0.04, 0.06), (0, -0.14, 0), STEEL_D),
        P((0.062, 1.0, 0.062), (0, 0.7, 0), (0.45, 0.9, 1.0, G)), P((0.044, 0.05, 0.044), (0, 1.22, 0), (0.8, 1.0, 1.0, G))]),
    # Heavy (two hands) ---------------------------------------------------------
    ("hammer", "Hammer", "heavy", dict(base_damage=22, ref_speed=8, knockback=9, throw_damage=30, throw_speed=20), [
        P((0.06, 1.0, 0.06), (0, 0.2, 0), WOOD), P((0.068, 0.3, 0.068), (0, -0.12, 0), LEATHER),
        P((0.08, 0.05, 0.08), (0, -0.32, 0), IRON), P((0.08, 0.08, 0.08), (0, 0.6, 0), IRON),
        P((0.34, 0.22, 0.22), (0, 0.74, 0), IRON), P((0.04, 0.25, 0.25), (0.19, 0.74, 0), STEEL_D),
        P((0.04, 0.25, 0.25), (-0.19, 0.74, 0), STEEL_D), P((0.35, 0.04, 0.23), (0, 0.66, 0), STEEL),
        P((0.35, 0.04, 0.23), (0, 0.82, 0), STEEL)]),
    ("battle_axe", "Battle Axe", "heavy", dict(base_damage=25, ref_speed=8, knockback=8, throw_damage=32, throw_speed=20), [
        P((0.06, 1.1, 0.06), (0, 0.22, 0), WOOD), P((0.068, 0.32, 0.068), (0, -0.12, 0), LEATHER),
        P((0.05, 0.1, 0.05), (0, -0.38, 0), IRON), P((0.09, 0.36, 0.08), (0, 0.64, 0), IRON),
        P((0.2, 0.28, 0.04), (0.14, 0.64, 0), STEEL), P((0.2, 0.28, 0.04), (-0.14, 0.64, 0), STEEL),
        P((0.05, 0.44, 0.035), (0.25, 0.64, 0), STEEL), P((0.05, 0.44, 0.035), (-0.25, 0.64, 0), STEEL),
        P((0.015, 0.44, 0.04), (0.278, 0.64, 0), EDGE), P((0.015, 0.44, 0.04), (-0.278, 0.64, 0), EDGE),
        point(0.86, 0.08, 0.05, IRON)]),
    ("pickaxe", "Pickaxe", "heavy", dict(base_damage=20, ref_speed=8, knockback=7, throw_damage=28), [
        P((0.06, 0.95, 0.06), (0, 0.18, 0), WOOD), P((0.066, 0.26, 0.066), (0, -0.14, 0), LEATHER),
        P((0.1, 0.12, 0.1), (0, 0.62, 0), IRON), P((0.36, 0.08, 0.08), (0.2, 0.61, 0), IRON, -8),
        P((0.36, 0.08, 0.08), (-0.2, 0.61, 0), IRON, 8), P((0.13, 0.06, 0.06), (0.42, 0.56, 0), STEEL, -20),
        P((0.13, 0.06, 0.06), (-0.42, 0.56, 0), STEEL, 20)]),
    ("anchor", "Ship Anchor", "heavy", dict(base_damage=34, ref_speed=8, knockback=12, slam_radius=3.6, move_speed=0.8,
                                            rarity="rare", throw_damage=40, throw_speed=17), [
        P((0.1, 1.1, 0.1), (0, 0.25, 0), IRON), P((0.5, 0.07, 0.07), (0, -0.05, 0), DARKWOOD),
        P((0.13, 0.12, 0.13), (0, 0.05, 0), (0.75, 0.65, 0.45)), P((0.16, 0.12, 0.12), (0, 0.84, 0), IRON),
        P((0.36, 0.1, 0.11), (0.2, 0.8, 0), IRON, -20), P((0.36, 0.1, 0.11), (-0.2, 0.8, 0), IRON, 20),
        P((0.14, 0.22, 0.06), (0.4, 0.68, 0), STEEL_D, -15), P((0.14, 0.22, 0.06), (-0.4, 0.68, 0), STEEL_D, 15),
        P((0.2, 0.04, 0.05), (0, -0.3, 0), IRON), P((0.2, 0.04, 0.05), (0, -0.46, 0), IRON),
        P((0.04, 0.2, 0.05), (0.08, -0.38, 0), IRON), P((0.04, 0.2, 0.05), (-0.08, -0.38, 0), IRON)]),
    ("lollipop", "Giant Lollipop", "heavy", dict(base_damage=14, ref_speed=8, knockback=13, family="joke", throw_damage=20), [
        P((0.05, 1.0, 0.05), (0, 0.2, 0), WHITE), P((0.52, 0.52, 0.1), (0, 0.9, 0), (1.0, 0.4, 0.7)),
        P((0.52, 0.52, 0.1), (0, 0.9, 0), (1.0, 0.45, 0.72), 45),
        P((0.4, 0.07, 0.11), (0, 0.9, 0), WHITE, 30), P((0.4, 0.07, 0.11), (0, 0.9, 0), (0.5, 0.9, 1.0), -30),
        P((0.4, 0.07, 0.11), (0, 0.9, 0), (1.0, 0.9, 0.3), 90), P((0.1, 0.1, 0.12), (0, 0.9, 0), WHITE, 45),
        P((0.16, 0.05, 0.03), (0, 0.62, 0), (0.6, 0.85, 1.0))]),
    ("shovel", "Shovel", "heavy", dict(base_damage=18, ref_speed=8, knockback=9.5, slam_radius=2.4, throw_damage=24,
                                       hit_sound="clang", hit_from=0.75, hit_to=1.1), [
        P((0.05, 1.0, 0.05), (0, 0.2, 0), WOOD), P((0.16, 0.035, 0.05), (0, -0.36, 0), BLACK),
        P((0.035, 0.12, 0.05), (0.07, -0.3, 0), BLACK), P((0.035, 0.12, 0.05), (-0.07, -0.3, 0), BLACK),
        P((0.06, 0.1, 0.06), (0, 0.72, 0), IRON), P((0.28, 0.03, 0.04), (0, 0.77, 0), IRON),
        P((0.26, 0.3, 0.025), (0, 0.92, 0), STEEL_D), P((0.18, 0.08, 0.025), (0, 1.08, 0), STEEL_D),
        point(1.08, 0.13, 0.025, STEEL)]),
    ("guitar", "Guitar", "heavy", dict(base_damage=15, ref_speed=8, knockback=14, family="joke", hit_sound="strum",
                                       throw_damage=20, hit_from=0.35, hit_to=0.8, hit_radius=0.24), [
        P((0.055, 0.62, 0.035), (0, 0.05, 0), DARKWOOD), P((0.08, 0.14, 0.03), (0, -0.32, 0), BLACK),
        *[P((0.03, 0.02, 0.02), (sx * 0.05, -0.36 + i * 0.05, 0), STEEL) for sx in (-1, 1) for i in range(3)],
        *[P((0.06, 0.008, 0.038), (0, -0.2 + i * 0.08, 0), STEEL) for i in range(6)],
        P((0.32, 0.2, 0.08), (0, 0.4, 0), RED), P((0.26, 0.08, 0.08), (0, 0.52, 0), RED),
        P((0.42, 0.3, 0.08), (0, 0.66, 0), RED), P((0.3, 0.08, 0.08), (0, 0.84, 0), RED),
        P((0.12, 0.2, 0.085), (0.1, 0.62, 0), BLACK), P((0.14, 0.03, 0.09), (0, 0.72, 0), BLACK),
        P((0.1, 0.04, 0.086), (0, 0.5, 0), WHITE), P((0.1, 0.04, 0.086), (0, 0.6, 0), WHITE),
        P((0.03, 0.92, 0.004), (0, 0.27, 0.044), (0.85, 0.85, 0.8, M))]),
    # Polearms ------------------------------------------------------------------
    ("spear", "Spear", "polearm", dict(base_damage=17, ref_speed=8, knockback=5.5, throw_damage=30, throw_speed=28), [
        P((0.045, 1.9, 0.045), (0, 0.25, 0), WOOD), P((0.052, 0.18, 0.052), (0, 0.0, 0), LEATHER),
        P((0.052, 0.18, 0.052), (0, 0.6, 0), LEATHER), P((0.055, 0.06, 0.055), (0, -0.72, 0), IRON),
        P((0.06, 0.14, 0.06), (0, 1.2, 0), IRON), P((0.06, 0.1, 0.06), (0, 1.1, 0), RED),
        P((0.1, 0.24, 0.025), (0, 1.38, 0), STEEL), P((0.02, 0.3, 0.032), (0, 1.38, 0), STEEL_D),
        point(1.5, 0.07, 0.025)]),
    ("bo_staff", "Bo Staff", "polearm", dict(base_damage=13, ref_speed=8, knockback=7.5, attack_speed=1.1, throw_damage=20), [
        P((0.055, 1.9, 0.055), (0, 0.2, 0), DARKWOOD), P((0.065, 0.12, 0.065), (0, 1.12, 0), BRASS),
        P((0.065, 0.12, 0.065), (0, -0.72, 0), BRASS), P((0.062, 0.2, 0.062), (0, 0.0, 0), RED),
        P((0.062, 0.2, 0.062), (0, 0.5, 0), RED), *rings((0.95, 1.0, -0.55, -0.6), 0.064, BRASS, 0.015)]),
    ("trident", "Trident", "polearm", dict(base_damage=22, ref_speed=8, knockback=6.5, rarity="rare", throw_damage=34, throw_speed=28), [
        P((0.05, 1.8, 0.05), (0, 0.25, 0), GOLD), P((0.058, 0.2, 0.058), (0, 0.0, 0), (0.15, 0.35, 0.5)),
        P((0.34, 0.05, 0.05), (0, 1.14, 0), GOLD), P((0.1, 0.1, 0.1), (0, 1.08, 0), (0.2, 0.85, 0.9, G), 45),
        P((0.04, 0.4, 0.04), (0, 1.36, 0), STEEL), P((0.04, 0.3, 0.04), (-0.15, 1.31, 0), STEEL),
        P((0.04, 0.3, 0.04), (0.15, 1.31, 0), STEEL), point(1.58, 0.06, 0.03), point(1.48, 0.06, 0.03, STEEL, -0.15),
        point(1.48, 0.06, 0.03, STEEL, 0.15), P((0.06, 0.03, 0.03), (-0.12, 1.42, 0), STEEL, 45),
        P((0.06, 0.03, 0.03), (0.12, 1.42, 0), STEEL, -45)]),
    ("scythe", "Scythe", "polearm", dict(base_damage=17, ref_speed=12, knockback=6.5, attack_speed=0.95, throw_damage=26,
                                         light_moves=["Spear_Sweep", "Spear_Thrust_B", "Spear_Sweep"], heavy_lunge=6.0,
                                         hit_from=0.9, hit_to=1.25, hit_radius=0.32), [
        P((0.05, 1.9, 0.05), (0, 0.25, 0), DARKWOOD), P((0.06, 0.1, 0.06), (0, 0.0, 0), WOOD),
        P((0.12, 0.05, 0.05), (0.05, 0.5, 0), WOOD), P((0.06, 0.06, 0.06), (0, -0.72, 0), IRON),
        P((0.1, 0.14, 0.045), (0, 1.18, 0), IRON), P((0.36, 0.15, 0.022), (0.2, 1.19, 0), STEEL_D, -8),
        P((0.3, 0.12, 0.022), (0.49, 1.13, 0), STEEL_D, -18), P((0.22, 0.08, 0.022), (0.72, 1.04, 0), STEEL_D, -32),
        P((0.36, 0.025, 0.026), (0.21, 1.12, 0), EDGE, -8), P((0.3, 0.025, 0.026), (0.49, 1.07, 0), EDGE, -18),
        P((0.2, 0.02, 0.026), (0.71, 1.0, 0), EDGE, -32)]),
    ("lance", "Lance", "polearm", dict(base_damage=18, ref_speed=8, knockback=10, throw_damage=28, move_speed=0.92,
                                       light_moves=["Spear_Thrust_A", "Spear_Thrust_B", "Spear_Thrust_A"], knockdown_move="",
                                       heavy_lunge=14.0, hit_from=0.4, hit_to=1.5, hit_radius=0.12), [
        P((0.05, 0.3, 0.05), (0, -0.1, 0), LEATHER), P((0.06, 0.05, 0.06), (0, -0.27, 0), STEEL_D),
        P((0.28, 0.04, 0.28), (0, 0.1, 0), STEEL), P((0.16, 0.3, 0.16), (0, 0.28, 0), BLUE),
        P((0.12, 0.35, 0.12), (0, 0.6, 0), BLUE), P((0.085, 0.35, 0.085), (0, 0.95, 0), BLUE),
        P((0.05, 0.3, 0.05), (0, 1.27, 0), STEEL), P((0.03, 0.12, 0.03), (0, 1.47, 0), STEEL),
        P((0.165, 0.04, 0.165), (0, 0.36, 0), WHITE), P((0.125, 0.04, 0.125), (0, 0.7, 0), WHITE),
        P((0.09, 0.04, 0.09), (0, 1.04, 0), WHITE)]),
    # One-handed swingers ---------------------------------------------------------
    ("flail", "Flail", "blade", dict(base_damage=20, ref_speed=8.5, knockback=9, attack_speed=0.88, throw_damage=26,
                                     hit_from=0.5, hit_to=0.8, hit_radius=0.2), [
        P((0.05, 0.36, 0.05), (0, 0.0, 0), WOOD), P((0.056, 0.16, 0.056), (0, -0.07, 0), LEATHER),
        P((0.065, 0.05, 0.065), (0, 0.2, 0), IRON), P((0.06, 0.04, 0.06), (0, -0.18, 0), IRON),
        P((0.03, 0.07, 0.014), (0, 0.26, 0), IRON), P((0.014, 0.07, 0.03), (0, 0.32, 0), IRON),
        P((0.03, 0.07, 0.014), (0, 0.38, 0), IRON), P((0.014, 0.07, 0.03), (0, 0.44, 0), IRON),
        P((0.03, 0.07, 0.014), (0, 0.5, 0), IRON),
        P((0.19, 0.19, 0.19), (0, 0.66, 0), IRON), P((0.19, 0.19, 0.19), (0, 0.66, 0), IRON, 45),
        P((0.3, 0.04, 0.04), (0, 0.66, 0), STEEL), P((0.04, 0.3, 0.04), (0, 0.66, 0), STEEL),
        P((0.04, 0.04, 0.3), (0, 0.66, 0), STEEL)]),
    ("nunchucks", "Nunchucks", "blade", dict(base_damage=9, ref_speed=9, knockback=4.5, attack_speed=1.35, throw_damage=14,
                                             hit_from=0.25, hit_to=0.6, hit_radius=0.14), [
        P((0.045, 0.32, 0.045), (0, 0.0, 0), BLACK), *rings((-0.12, 0.1), 0.05, GOLD, 0.02),
        P((0.05, 0.02, 0.05), (0, 0.17, 0), GOLD), P((0.015, 0.06, 0.03), (0.01, 0.21, 0), IRON),
        P((0.03, 0.06, 0.015), (0.03, 0.26, 0), IRON, -15),
        P((0.045, 0.32, 0.045), (0.1, 0.44, 0), BLACK, -25), P((0.05, 0.02, 0.05), (0.04, 0.31, 0), GOLD, -25),
        P((0.05, 0.02, 0.05), (0.15, 0.55, 0), GOLD, -25)]),
    ("wrench", "Wrench", "blade", dict(base_damage=14, ref_speed=8.5, knockback=7.5, throw_damage=22, hit_sound="clang",
                                       hit_from=0.3, hit_to=0.58, hit_radius=0.13), [
        P((0.05, 0.5, 0.025), (0, 0.15, 0), STEEL_D), P((0.058, 0.22, 0.035), (0, -0.01, 0), RED),
        P((0.06, 0.03, 0.036), (0, -0.13, 0), RED), P((0.2, 0.08, 0.035), (0, 0.45, 0), STEEL),
        P((0.05, 0.13, 0.035), (-0.075, 0.53, 0), STEEL), P((0.05, 0.1, 0.035), (0.075, 0.52, 0), STEEL),
        P((0.04, 0.04, 0.05), (0.03, 0.42, 0), BRASS)]),
    ("umbrella", "Umbrella", "blade", dict(base_damage=9, ref_speed=8, knockback=8, family="joke", glide=True, throw_damage=14,
                                           hit_from=0.3, hit_to=0.92, hit_radius=0.14), [
        P((0.035, 0.1, 0.035), (0, -0.08, 0), BLACK), P((0.09, 0.03, 0.035), (-0.03, -0.14, 0), BLACK),
        P((0.025, 0.8, 0.025), (0, 0.35, 0), STEEL_D), P((0.15, 0.2, 0.15), (0, 0.42, 0), (0.15, 0.55, 0.9)),
        P((0.12, 0.2, 0.12), (0, 0.62, 0), (0.15, 0.55, 0.9)), P((0.07, 0.15, 0.07), (0, 0.79, 0), (0.15, 0.55, 0.9)),
        P((0.155, 0.05, 0.155), (0, 0.38, 0), (0.95, 0.85, 0.2)), P((0.125, 0.04, 0.125), (0, 0.6, 0), (0.95, 0.85, 0.2)),
        P((0.02, 0.08, 0.02), (0, 0.9, 0), STEEL)]),
    ("ice_cream", "Ice Cream", "blade", dict(base_damage=6, ref_speed=8, knockback=5, family="joke", effect="chill",
                                             effect_time=2.5, throw_damage=10, hit_from=0.25, hit_to=0.6, hit_radius=0.17), [
        P((0.07, 0.12, 0.07), (0, 0.0, 0), (0.85, 0.62, 0.32)), P((0.1, 0.12, 0.1), (0, 0.12, 0), (0.85, 0.62, 0.32)),
        P((0.13, 0.12, 0.13), (0, 0.24, 0), (0.85, 0.62, 0.32)), P((0.135, 0.015, 0.135), (0, 0.2, 0), (0.6, 0.4, 0.18)),
        P((0.105, 0.015, 0.105), (0, 0.08, 0), (0.6, 0.4, 0.18)),
        P((0.2, 0.16, 0.2), (0, 0.38, 0), (0.55, 0.95, 0.85)), P((0.2, 0.16, 0.2), (0, 0.38, 0), (0.55, 0.95, 0.85), 45),
        P((0.16, 0.14, 0.16), (0, 0.5, 0), (1.0, 0.6, 0.75)), P((0.05, 0.05, 0.05), (0, 0.6, 0), RED),
        P((0.04, 0.08, 0.04), (0.08, 0.3, 0.06), (0.55, 0.95, 0.85))]),
    # Fists -----------------------------------------------------------------------
    ("fists", "Fists", "fists", dict(base_damage=8, ref_speed=5.5, knockback=3.5), []),
    ("boxing_gloves", "Boxing Gloves", "fists", dict(base_damage=11, ref_speed=5.5, knockback=6.5, both_hands=True), [
        P((0.2, 0.2, 0.2), (0, 0.02, 0), (0.85, 0.12, 0.1)), P((0.17, 0.17, 0.22), (0, 0.04, 0), (0.85, 0.12, 0.1)),
        P((0.07, 0.12, 0.08), (0.1, 0.0, 0.04), (0.85, 0.12, 0.1)), P((0.17, 0.1, 0.17), (0, -0.1, 0), WHITE),
        P((0.04, 0.1, 0.18), (0, -0.1, 0), (0.85, 0.12, 0.1))]),
    ("power_gauntlet", "Power Gauntlet", "fists", dict(base_damage=16, ref_speed=5.5, knockback=10, both_hands=True, rarity="rare",
                                                       glow=(1.0, 0.6, 0.2)), [
        P((0.22, 0.22, 0.22), (0, 0.0, 0), IRON), P((0.24, 0.06, 0.08), (0, 0.1, 0.08), STEEL),
        P((0.2, 0.14, 0.2), (0, -0.14, 0), GUNMETAL), P((0.08, 0.08, 0.04), (0, 0.0, 0.115), (1.0, 0.6, 0.2, G)),
        P((0.21, 0.02, 0.21), (0, -0.07, 0), (1.0, 0.6, 0.2, G)), P((0.05, 0.12, 0.05), (0.12, 0.0, 0), STEEL)]),
    ("shield", "Shield", "fists", dict(base_damage=11, ref_speed=5.5, knockback=10, hand="left",
                                       light_moves=["Shield_Bash", "Shield_Bash_B"], heavy_charge="Shield_Raise",
                                       heavy_move="Shield_Slam", idle_clip="Shield_Idle", block_clip="Shield_Block",
                                       parry_clip="Shield_Parry", slam_radius=2.4, heavy_multiplier=1.9,
                                       strikers={"Shield_Bash": "LeftHand", "Shield_Bash_B": "LeftHand",
                                                 "Shield_Slam": "LeftHand", "Kick": "RightFoot"}, hit_radius=0.42,
                                       block_mult=0.15, parry_bonus=0.12, throwable=True, catchable=True, throw_damage=18,
                                       throw_spin=14), [
        *[P((0.12, h, 0.03), (x, 0, 0.07), c) for x, h, c in ((-0.18, 0.36, WOOD), (-0.06, 0.5, DARKWOOD),
                                                                 (0.06, 0.5, WOOD), (0.18, 0.36, DARKWOOD))],
        P((0.26, 0.04, 0.045), (0, 0.25, 0.07), IRON), P((0.26, 0.04, 0.045), (0, -0.25, 0.07), IRON),
        P((0.04, 0.26, 0.045), (0.25, 0, 0.07), IRON), P((0.04, 0.26, 0.045), (-0.25, 0, 0.07), IRON),
        *[P((0.2, 0.04, 0.045), (sx * 0.187, sy * 0.187, 0.07), IRON, -45 * sx * sy) for sx in (-1, 1) for sy in (-1, 1)],
        P((0.5, 0.06, 0.033), (0, 0, 0.07), RED), P((0.13, 0.13, 0.06), (0, 0, 0.1), IRON, 45),
        P((0.06, 0.06, 0.04), (0, 0, 0.13), STEEL)]),
    # Thrown ----------------------------------------------------------------------
    ("shuriken", "Shuriken", "thrown", dict(base_damage=12, ammo=5, throw_damage=13, throw_speed=32, throw_spin=30,
                                            catchable=True, keep_on_land=False), [
        P((0.24, 0.04, 0.02), (0, 0, 0), STEEL), P((0.04, 0.24, 0.02), (0, 0, 0), STEEL),
        point(0, 0.08, 0.02, STEEL, 0.1), point(0, 0.08, 0.02, STEEL, -0.1), point(0.1, 0.08, 0.02), point(-0.1, 0.08, 0.02),
        P((0.08, 0.08, 0.03), (0, 0, 0), DARK, 45), P((0.03, 0.03, 0.032), (0, 0, 0), BLACK)]),
    ("throwing_knives", "Throwing Knives", "thrown", dict(base_damage=14, ammo=4, throw_damage=17, throw_speed=30, throw_spin=24,
                                                          keep_on_land=False), [
        P((0.03, 0.1, 0.03), (0, 0, 0), WRAP), *rings((-0.03, 0.03), 0.034, RED, 0.012),
        P((0.04, 0.22, 0.015), (0, 0.15, 0), STEEL), P((0.012, 0.18, 0.02), (0, 0.14, 0), STEEL_D),
        point(0.26, 0.03, 0.015)]),
    ("kunai", "Kunai", "thrown", dict(base_damage=13, ammo=3, throw_damage=18, throw_speed=33, throw_spin=22, catchable=True), [
        P((0.07, 0.015, 0.02), (0, -0.115, 0), IRON), P((0.015, 0.06, 0.02), (0.03, -0.085, 0), IRON),
        P((0.015, 0.06, 0.02), (-0.03, -0.085, 0), IRON), P((0.032, 0.12, 0.032), (0, 0.0, 0), (0.15, 0.15, 0.18)),
        *rings((-0.03, 0.01, 0.05), 0.036, (0.7, 0.15, 0.15), 0.012),
        P((0.07, 0.14, 0.016), (0, 0.14, 0), STEEL), P((0.05, 0.08, 0.016), (0, 0.24, 0), STEEL),
        P((0.012, 0.18, 0.02), (0, 0.18, 0), STEEL_D), point(0.29, 0.04, 0.016)]),
    ("bomb", "Bomb", "thrown", dict(base_damage=10, ammo=2, throw_damage=10, throw_speed=17, throw_spin=6, explosive=True,
                                    catchable=True, light_moves=["Bomb_Lob"], heavy_move="Bomb_Lob", keep_on_land=False), [
        P((0.26, 0.22, 0.26), (0, 0.05, 0), (0.12, 0.12, 0.14)), P((0.22, 0.26, 0.22), (0, 0.05, 0), (0.12, 0.12, 0.14)),
        P((0.22, 0.22, 0.27), (0, 0.05, 0), (0.12, 0.12, 0.14), 45), P((0.05, 0.05, 0.02), (-0.06, 0.12, 0.13), (0.5, 0.5, 0.55)),
        P((0.1, 0.05, 0.1), (0, 0.19, 0), IRON), P((0.025, 0.1, 0.025), (0.01, 0.25, 0), (0.75, 0.65, 0.45), -10),
        P((0.05, 0.05, 0.05), (0.02, 0.31, 0), (1.0, 0.6, 0.1, G), 45)]),
    ("snowball", "Snowball", "thrown", dict(base_damage=6, ammo=6, throw_damage=7, throw_speed=22, throw_spin=4, effect="chill",
                                            effect_time=2.0, catchable=True, keep_on_land=False), [
        P((0.18, 0.15, 0.18), (0, 0, 0), (0.94, 0.97, 1.0)), P((0.15, 0.18, 0.15), (0, 0, 0), (0.94, 0.97, 1.0)),
        P((0.16, 0.16, 0.19), (0, 0, 0), (0.9, 0.95, 1.0), 45), P((0.04, 0.04, 0.04), (0.07, 0.06, 0.06), (0.7, 0.85, 1.0))]),
    ("saw_blade", "Saw Blade", "thrown", dict(base_damage=12, ammo=2, throw_damage=20, throw_speed=26, throw_spin=40, bounces=3,
                                              catchable=True), [
        P((0.32, 0.32, 0.02), (0, 0, 0), STEEL), P((0.32, 0.32, 0.02), (0, 0, 0), STEEL, 45),
        *[P((0.06, 0.06, 0.022), (0.19 * math.cos(math.radians(a)), 0.19 * math.sin(math.radians(a)), 0), STEEL_D, a + 45)
          for a in range(0, 360, 45)],
        P((0.1, 0.1, 0.03), (0, 0, 0), IRON), P((0.04, 0.04, 0.032), (0, 0, 0), BLACK)]),
    ("thunderbolt", "Thunderbolt", "thrown", dict(base_damage=10, ammo=1, throw_damage=20, throw_speed=26, throw_spin=2,
                                                  lightning=True, catchable=False, keep_on_land=False, rarity="rare"), [
        P((0.05, 0.1, 0.04), (0, -0.02, 0), (0.6, 0.45, 0.15, M)), P((0.08, 0.22, 0.04), (0.03, 0.12, 0), (1.0, 0.9, 0.3, G), -25),
        P((0.07, 0.2, 0.04), (-0.02, 0.27, 0), (1.0, 0.95, 0.5, G), 30), P((0.06, 0.22, 0.04), (0.03, 0.42, 0), (1.0, 0.9, 0.3, G), -25),
        P((0.04, 0.12, 0.04), (-0.01, 0.56, 0), (1.0, 1.0, 0.7, G), 30)]),
    ("boomerang", "Boomerang", "thrown", dict(base_damage=12, ammo=1, throw_damage=18, throw_speed=24, throw_spin=22, returns=True), [
        P((0.08, 0.36, 0.03), (0.08, 0.12, 0), (0.85, 0.55, 0.2), 35), P((0.08, 0.36, 0.03), (-0.08, 0.12, 0), (0.85, 0.55, 0.2), -35),
        P((0.085, 0.06, 0.032), (0.12, 0.18, 0), BLUE, 35), P((0.085, 0.06, 0.032), (-0.12, 0.18, 0), BLUE, -35),
        P((0.1, 0.1, 0.031), (0, -0.02, 0), (0.7, 0.42, 0.15), 45)]),
    ("yoyo", "Yo-yo", "thrown", dict(base_damage=10, ammo=1, throw_damage=14, throw_speed=30, throw_spin=30, returns=True,
                                     return_after=0.28, family="joke"), [
        P((0.2, 0.2, 0.05), (0, 0, 0.035), RED), P((0.2, 0.2, 0.05), (0, 0, 0.035), RED, 45),
        P((0.2, 0.2, 0.05), (0, 0, -0.035), RED), P((0.2, 0.2, 0.05), (0, 0, -0.035), RED, 45),
        P((0.06, 0.06, 0.03), (0, 0, 0), WHITE), P((0.08, 0.08, 0.004), (0, 0, 0.061), (1.0, 0.85, 0.2)),
        P((0.008, 0.2, 0.008), (0, -0.12, 0), WHITE)]),
    ("rocket_fist", "Rocket Fist", "thrown", dict(base_damage=14, ammo=1, throw_damage=24, throw_speed=30, throw_spin=0,
                                                  returns=True, return_after=0.32, catchable=False, light_moves=["Rocket_Punch"],
                                                  heavy_move="Rocket_Punch", idle_clip="Idle"), [
        P((0.22, 0.22, 0.24), (0, 0.04, 0), IRON), P((0.24, 0.07, 0.1), (0, 0.14, 0.06), STEEL),
        P((0.07, 0.12, 0.08), (0.12, 0.04, 0.04), IRON), P((0.16, 0.14, 0.16), (0, -0.14, 0), GUNMETAL),
        P((0.1, 0.06, 0.1), (0, -0.24, 0), (1.0, 0.55, 0.15, G)), P((0.04, 0.1, 0.1), (0.1, -0.17, 0), RED),
        P((0.04, 0.1, 0.1), (-0.1, -0.17, 0), RED)]),
    # Ranged ----------------------------------------------------------------------
    ("blaster", "Blaster", "ranged", dict(base_damage=10, ammo=14, projectile_speed=55, projectile_damage=9, throw_damage=12,
                                          hit_to=0.42), [
        P((0.08, 0.26, 0.12), (0, 0.1, 0), GUNMETAL), P((0.05, 0.18, 0.05), (0, 0.3, 0), IRON),
        P((0.065, 0.03, 0.065), (0, 0.39, 0), (0.4, 1.0, 0.6, G)), P((0.06, 0.06, 0.16), (0, -0.02, -0.08), BLACK),
        P((0.02, 0.06, 0.04), (0, 0.05, -0.07), BLACK), P((0.084, 0.12, 0.02), (0, 0.12, 0.061), (0.4, 1.0, 0.6, G)),
        P((0.02, 0.04, 0.03), (0, 0.18, 0.075), BLACK)]),
    ("plasma_pistols", "Plasma Pistols", "ranged", dict(base_damage=8, ammo=24, projectile="plasma", projectile_speed=50,
                                                        projectile_damage=6, fire_cooldown=0.12, both_hands=True,
                                                        throw_damage=10, hit_to=0.28), [
        P((0.06, 0.2, 0.09), (0, 0.06, 0), (0.85, 0.3, 0.2, M)), P((0.045, 0.12, 0.06), (0, 0.2, 0), GUNMETAL),
        P((0.05, 0.08, 0.065), (0, 0.14, 0), (1.0, 0.35, 0.75, G)), P((0.04, 0.03, 0.04), (0, 0.27, 0), (1.0, 0.5, 0.85, G)),
        P((0.045, 0.05, 0.12), (0, -0.02, -0.08), BLACK)]),
    ("slingshot", "Slingshot", "ranged", dict(base_damage=6, ammo=12, projectile="pebble", projectile_speed=30,
                                              projectile_damage=11, fire_cooldown=0.35, throw_damage=8, hit_to=0.22), [
        P((0.04, 0.16, 0.04), (0, -0.02, 0), WOOD), P((0.035, 0.16, 0.035), (0.05, 0.12, 0), WOOD, -20),
        P((0.035, 0.16, 0.035), (-0.05, 0.12, 0), WOOD, 20), P((0.012, 0.012, 0.14), (0.08, 0.2, -0.06), RED),
        P((0.012, 0.012, 0.14), (-0.08, 0.2, -0.06), RED), P((0.06, 0.03, 0.03), (0, 0.2, -0.13), LEATHER),
        *rings((-0.06, 0.02), 0.046, LEATHER, 0.02)]),
    ("bazooka", "Bazooka", "ranged", dict(base_damage=10, ammo=3, projectile="rocket", projectile_speed=24, projectile_damage=0,
                                          fire_cooldown=1.2, move_speed=0.85, rarity="rare", throw_damage=20, hit_to=0.7), [
        P((0.14, 0.9, 0.14), (0, 0.2, 0), (0.35, 0.4, 0.28)), P((0.16, 0.05, 0.16), (0, -0.15, 0), DARK),
        P((0.16, 0.05, 0.16), (0, 0.55, 0), DARK), P((0.18, 0.08, 0.18), (0, 0.64, 0), IRON),
        P((0.17, 0.1, 0.17), (0, -0.26, 0), IRON), P((0.05, 0.05, 0.14), (0, 0.0, -0.09), BLACK),
        P((0.05, 0.05, 0.12), (0, 0.25, -0.09), BLACK), P((0.03, 0.06, 0.04), (0, 0.25, 0.1), BLACK),
        P((0.1, 0.06, 0.1), (0, 0.67, 0), RED), P((0.145, 0.25, 0.145), (0, 0.3, 0), (0.95, 0.75, 0.2))]),
    ("sniper", "Sniper Rifle", "ranged", dict(base_damage=10, ammo=4, projectile="slug", projectile_speed=140,
                                              projectile_damage=42, fire_cooldown=1.1, rarity="rare", throw_damage=14,
                                              hit_to=0.96), [
        P((0.06, 0.24, 0.1), (0, -0.1, -0.02), DARKWOOD), P((0.07, 0.3, 0.09), (0, 0.16, 0), GUNMETAL),
        P((0.035, 0.6, 0.035), (0, 0.6, 0), IRON), P((0.05, 0.07, 0.05), (0, 0.92, 0), BLACK),
        P((0.05, 0.24, 0.05), (0, 0.2, 0.08), BLACK), P((0.06, 0.02, 0.06), (0, 0.08, 0.08), (0.3, 0.6, 1.0, G)),
        P((0.06, 0.02, 0.06), (0, 0.32, 0.08), (0.3, 0.6, 1.0, G)), P((0.04, 0.08, 0.06), (0, 0.12, -0.08), BLACK),
        P((0.04, 0.05, 0.12), (0, 0.02, -0.09), BLACK)]),
    ("scepter", "Magic Scepter", "ranged", dict(base_damage=10, ammo=8, projectile="orb", projectile_speed=16,
                                                projectile_damage=16, fire_cooldown=0.45, rarity="rare", throw_damage=14,
                                                hit_to=0.66), [
        P((0.04, 0.7, 0.04), (0, 0.15, 0), (0.2, 0.25, 0.65)), *rings((0.0, 0.3, 0.48), 0.05, GOLD, 0.03),
        P((0.06, 0.06, 0.06), (0, -0.22, 0), GOLD, 45), P((0.025, 0.12, 0.025), (0.05, 0.56, 0), GOLD, 20),
        P((0.025, 0.12, 0.025), (-0.05, 0.56, 0), GOLD, -20), P((0.1, 0.1, 0.1), (0, 0.64, 0), (0.8, 0.6, 1.0, G), 45),
        P((0.07, 0.15, 0.07), (0, 0.64, 0), (0.9, 0.75, 1.0, G))]),
    ("grapple", "Grapple Gun", "ranged", dict(base_damage=8, ammo=6, projectile="hook", projectile_speed=40,
                                              projectile_damage=5, fire_cooldown=0.7, throw_damage=10, hit_to=0.3), [
        P((0.09, 0.22, 0.11), (0, 0.08, 0), (0.25, 0.3, 0.45, M)), P((0.12, 0.08, 0.12), (0, 0.04, 0.05), DARK),
        P((0.05, 0.1, 0.05), (0, 0.24, 0), IRON), P((0.14, 0.03, 0.03), (0, 0.3, 0), STEEL),
        P((0.03, 0.06, 0.03), (0.06, 0.33, 0), STEEL), P((0.03, 0.06, 0.03), (-0.06, 0.33, 0), STEEL),
        P((0.05, 0.05, 0.13), (0, 0.0, -0.09), BLACK)]),
    ("fan", "Gust Fan", "ranged", dict(base_damage=6, ammo=10, projectile="wind", projectile_speed=30, projectile_damage=0,
                                       fire_cooldown=0.5, family="joke", throw_damage=8, hit_to=0.3), [
        P((0.03, 0.12, 0.02), (0, -0.02, 0), DARKWOOD),
        *[P((0.02, 0.34, 0.012), (0.17 * math.sin(math.radians(a)), 0.1 + 0.17 * math.cos(math.radians(a)), 0), DARKWOOD, -a)
          for a in (-50, -25, 0, 25, 50)],
        *[P((0.13, 0.22, 0.008), (0.2 * math.sin(math.radians(a)), 0.12 + 0.2 * math.cos(math.radians(a)), 0.012),
            RED if i % 2 == 0 else WHITE, -a) for i, a in enumerate((-37, -12, 12, 37))]]),
    ("bow", "Bow", "ranged", dict(base_damage=10, ammo=8, projectile="arrow", projectile_speed=40, projectile_damage=16,
                                  hand="left", rarity="rare", light_moves=["Bow_Release"], heavy_charge="Bow_Draw",
                                  heavy_move="Bow_Release", idle_clip="", throw_damage=12), [
        P((0.05, 0.2, 0.07), (0, 0, 0), LEATHER), P((0.04, 0.3, 0.05), (0, 0.24, -0.02), WOOD),
        P((0.035, 0.22, 0.045), (0, 0.48, -0.05), WOOD), P((0.03, 0.08, 0.04), (0, 0.6, -0.03), DARKWOOD),
        P((0.04, 0.3, 0.05), (0, -0.24, -0.02), WOOD), P((0.035, 0.22, 0.045), (0, -0.48, -0.05), WOOD),
        P((0.03, 0.08, 0.04), (0, -0.6, -0.03), DARKWOOD), P((0.008, 1.24, 0.008), (0, 0, -0.1), WHITE),
        *rings((-0.06, 0.06), 0.056, (0.75, 0.6, 0.3), 0.015)]),
    # Joke ------------------------------------------------------------------------
    ("frying_pan", "Frying Pan", "blade", dict(base_damage=12, ref_speed=8.5, knockback=9, family="joke", hit_sound="clang",
                                               throw_damage=20), [
        P((0.04, 0.36, 0.03), (0, 0.08, 0), BLACK), P((0.05, 0.04, 0.04), (0, -0.08, 0), IRON),
        P((0.34, 0.34, 0.03), (0, 0.44, 0), IRON), P((0.36, 0.035, 0.07), (0, 0.27, 0.02), IRON),
        P((0.36, 0.035, 0.07), (0, 0.61, 0.02), IRON), P((0.035, 0.36, 0.07), (0.17, 0.44, 0.02), IRON),
        P((0.035, 0.36, 0.07), (-0.17, 0.44, 0.02), IRON), P((0.29, 0.29, 0.032), (0, 0.44, 0.003), (0.15, 0.15, 0.17))]),
    ("rubber_chicken", "Rubber Chicken", "blade", dict(base_damage=6, ref_speed=8, knockback=15, family="joke", hit_sound="squeak",
                                                       throw_damage=8), [
        P((0.13, 0.5, 0.11), (0, 0.38, 0), (1.0, 0.85, 0.2)), P((0.11, 0.13, 0.1), (0, 0.69, 0.03), (1.0, 0.85, 0.2)),
        P((0.05, 0.05, 0.08), (0, 0.69, 0.1), (1.0, 0.5, 0.1)), P((0.03, 0.08, 0.06), (0, 0.78, 0.02), RED),
        P((0.02, 0.02, 0.02), (0.05, 0.71, 0.07), BLACK), P((0.02, 0.02, 0.02), (-0.05, 0.71, 0.07), BLACK),
        P((0.04, 0.14, 0.04), (0, 0.06, 0), (1.0, 0.5, 0.1)), P((0.12, 0.03, 0.05), (0, -0.02, 0.02), (1.0, 0.5, 0.1)),
        P((0.03, 0.2, 0.09), (0.08, 0.38, 0), (1.0, 0.8, 0.15), -10), P((0.03, 0.2, 0.09), (-0.08, 0.38, 0), (1.0, 0.8, 0.15), 10)]),
]


def fmt(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(float(v)) if isinstance(v, float) else str(v)
    if isinstance(v, str):
        return '"%s"' % v
    raise TypeError(v)


# Crane magnets grab these (Harbor Factory); IGNITES set oil alight.
METAL = {"sword", "katana", "dagger", "rapier", "hand_axe", "plasma_blade", "hammer", "battle_axe", "pickaxe",
         "anchor", "spear", "trident", "power_gauntlet", "shuriken", "throwing_knives", "blaster", "frying_pan",
         "scythe", "lance", "flail", "wrench", "shovel", "kunai", "saw_blade", "rocket_fist", "plasma_pistols",
         "bazooka", "sniper", "grapple"}
# Each weapon's power (src/weapons/weapon_skills.gd) and its Armory rank.
SKILLS = {
    "sword": "sky_cleaver", "katana": "flash_step", "dagger": "shadow_step", "rapier": "needle_storm",
    "hand_axe": "axe_volley", "plasma_blade": "plasma_nova", "hammer": "earthshaker", "battle_axe": "cyclone_cleave",
    "pickaxe": "rockslide", "anchor": "undertow", "lollipop": "sugar_rush", "shovel": "dirt_kick", "guitar": "power_chord",
    "spear": "skewer", "bo_staff": "pole_vault", "trident": "tidal_surge", "scythe": "grim_harvest", "lance": "joust",
    "flail": "meteor_swing", "nunchucks": "whirlwind", "wrench": "overclock", "umbrella": "updraft",
    "ice_cream": "brain_freeze", "fists": "haymaker", "boxing_gloves": "uppercut", "power_gauntlet": "gravity_smash",
    "shield": "bulwark", "shuriken": "star_fan", "throwing_knives": "knife_storm", "kunai": "kunai_warp",
    "bomb": "cluster_bomb", "snowball": "snowstorm", "saw_blade": "saw_storm", "thunderbolt": "storm_call",
    "boomerang": "twin_return", "yoyo": "yoyo_snare", "rocket_fist": "fist_barrage", "blaster": "scatter_shot",
    "plasma_pistols": "overdrive", "slingshot": "big_rock", "bazooka": "rocket_jump", "sniper": "rail_shot",
    "scepter": "starfall", "grapple": "reel_slam", "fan": "cyclone", "bow": "arrow_rain", "frying_pan": "pan_slam",
    "rubber_chicken": "mega_squawk",
}
TIERS = {
    "S+": ["thunderbolt", "scepter", "bazooka", "power_gauntlet"],
    "S": ["plasma_blade", "anchor", "trident", "sniper", "bow", "scythe", "lance", "grapple", "plasma_pistols", "saw_blade"],
    "A": ["katana", "battle_axe", "hammer", "spear", "flail", "shield", "shuriken", "kunai", "bomb", "blaster", "fan",
          "rocket_fist", "guitar"],
    "B": ["rapier", "hand_axe", "pickaxe", "bo_staff", "boxing_gloves", "nunchucks", "wrench", "shovel", "throwing_knives",
          "boomerang", "slingshot", "snowball", "yoyo", "umbrella"],
    "C": ["sword", "dagger", "ice_cream", "lollipop", "frying_pan", "rubber_chicken", "fists"],
}
TIER_OF = {w: t for t, ws in TIERS.items() for w in ws}

# Weapons you can't throw (THROW does nothing): heavy two-handers, long
# polearms, guns, bows, shields, gauntlets, and the odd ones.
NOT_THROWABLE = {"hammer", "battle_axe", "pickaxe", "anchor", "lollipop", "shovel", "guitar", "bo_staff", "scythe",
                 "lance", "rapier", "plasma_blade", "flail", "nunchucks", "umbrella", "ice_cream", "shield", "blaster",
                 "plasma_pistols", "slingshot", "bazooka", "sniper", "scepter", "grapple", "fan", "bow"}
IGNITES = {"plasma_blade", "blaster", "bomb", "plasma_pistols", "bazooka", "thunderbolt"}


def write(wid, name, family_key, stats, parts):
    fam = dict(FAMILY[family_key])
    fam.update(stats)
    family_label = fam.pop("family", family_key if family_key not in ("dagger", "rapier") else "blades")
    if family_label == "blade":
        family_label = "blades"
    if family_label == "polearm":
        family_label = "heavy"
    fields = {
        "id": "&\"%s\"" % wid, "display_name": fmt(name), "family": fmt(family_label),
        "kind": "&\"%s\"" % fam.pop("kind", "melee"), "rarity": "&\"%s\"" % fam.pop("rarity", "common"),
    }
    lists = {k: fam.pop(k) for k in ("light_moves",) if k in fam}
    strikers = fam.pop("strikers", {})
    glow = fam.pop("glow", None)
    lines = ["[gd_resource type=\"Resource\" script_class=\"WeaponData\" load_steps=2 format=3]", "",
             "[ext_resource type=\"Script\" path=\"res://src/weapons/weapon_data.gd\" id=\"1\"]", "", "[resource]",
             "script = ExtResource(\"1\")"]
    for k, v in fields.items():
        lines.append("%s = %s" % (k, v))
    lines.append("light_moves = Array[StringName]([%s])" % ", ".join('&"%s"' % m for m in lists.get("light_moves", [])))
    for k in ("knockdown_move", "heavy_charge", "heavy_move", "idle_clip", "block_clip", "parry_clip", "hand", "hit_sound",
              "effect", "projectile"):
        if k in fam:
            lines.append('%s = &"%s"' % (k, fam.pop(k)))
    lines.append("strikers = {%s}" % ", ".join('"%s": "%s"' % kv for kv in strikers.items()))
    for k, v in fam.items():
        lines.append("%s = %s" % (k, fmt(v)))
    if glow:
        lines.append("glow = Color(%s, %s, %s, 1)" % glow)
    if wid in SKILLS:
        lines.append('skill = &"%s"' % SKILLS[wid])
    lines.append('tier = "%s"' % TIER_OF.get(wid, "C"))
    if wid in NOT_THROWABLE:
        lines = [l for l in lines if not l.startswith("throwable =")]
        lines.append("throwable = false")
    if wid in METAL:
        lines.append("metal = true")
    if wid in IGNITES:
        lines.append("ignites = true")
    sizes, centres, colors, yaws = [], [], [], []
    for size, centre, color, yaw in parts:
        sizes += size
        centres += centre
        colors += list(color) + ([1.0] if len(color) == 3 else [])
        yaws.append(yaw)
    lines.append("part_sizes = PackedVector3Array(%s)" % ", ".join(str(x) for x in sizes))
    lines.append("part_centres = PackedVector3Array(%s)" % ", ".join(str(x) for x in centres))
    lines.append("part_colors = PackedColorArray(%s)" % ", ".join(str(x) for x in colors))
    lines.append("part_yaws = PackedFloat32Array(%s)" % ", ".join(str(x) for x in yaws))
    with open(os.path.join(OUT, wid + ".tres"), "w") as fh:
        fh.write("\n".join(lines) + "\n")


def main():
    os.makedirs(OUT, exist_ok=True)
    missing = [w[0] for w in WEAPONS if w[0] not in TIER_OF or w[0] not in SKILLS]
    assert not missing, "no tier/skill for %s" % missing
    for wid, name, fam, stats, parts in WEAPONS:
        write(wid, name, fam, stats, parts)
    print("wrote %d weapons" % len(WEAPONS))


main()
