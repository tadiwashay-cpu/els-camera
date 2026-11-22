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

WOOD = (0.45, 0.3, 0.16)
DARK = (0.18, 0.15, 0.13)
STEEL = (0.84, 0.87, 0.92)
IRON = (0.32, 0.34, 0.38)
GOLD = (0.92, 0.7, 0.22)
WHITE = (0.95, 0.95, 0.95)

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


# id, name, family, stats, parts, extra
WEAPONS = [
    # Blades
    ("sword", "Sword", "blade", dict(base_damage=16, ref_speed=9, knockback=5.5, throw_damage=26, rarity="common"), [
        P((0.045, 0.2, 0.045), (0, 0, 0), (0.28, 0.16, 0.08)), P((0.07, 0.05, 0.07), (0, -0.12, 0), GOLD),
        P((0.26, 0.045, 0.07), (0, 0.12, 0), GOLD), P((0.075, 0.8, 0.022), (0, 0.54, 0), STEEL),
        P((0.045, 0.08, 0.02), (0, 0.98, 0), STEEL), P((0.022, 0.62, 0.026), (0, 0.48, 0), (0.55, 0.6, 0.7))]),
    ("katana", "Katana", "blade", dict(base_damage=15, ref_speed=8.5, knockback=4.5, attack_speed=1.12, throw_damage=24), [
        P((0.04, 0.28, 0.04), (0, 0.0, 0), DARK), P((0.11, 0.03, 0.11), (0, 0.15, 0), GOLD),
        P((0.05, 0.86, 0.02), (0, 0.6, 0), STEEL), P((0.035, 0.1, 0.02), (0.006, 1.06, 0), STEEL)]),
    ("dagger", "Dagger", "dagger", dict(base_damage=10, ref_speed=7, knockback=3.0, throw_damage=22, throw_speed=28), [
        P((0.04, 0.14, 0.04), (0, 0, 0), DARK), P((0.14, 0.03, 0.05), (0, 0.08, 0), IRON),
        P((0.05, 0.3, 0.018), (0, 0.25, 0), STEEL)]),
    ("rapier", "Rapier", "rapier", dict(base_damage=13, ref_speed=7.5, knockback=3.5, attack_speed=1.1), [
        P((0.035, 0.16, 0.035), (0, 0, 0), DARK), P((0.13, 0.06, 0.13), (0, 0.1, 0), GOLD),
        P((0.022, 0.96, 0.022), (0, 0.6, 0), STEEL)]),
    ("hand_axe", "Hand Axe", "blade", dict(base_damage=18, ref_speed=9, knockback=6.5, attack_speed=0.95, throw_damage=30), [
        P((0.05, 0.62, 0.05), (0, 0.2, 0), WOOD), P((0.26, 0.18, 0.05), (-0.1, 0.44, 0), STEEL),
        P((0.06, 0.2, 0.06), (0.04, 0.44, 0), IRON)]),
    ("plasma_blade", "Plasma Blade", "blade", dict(base_damage=24, ref_speed=9, knockback=7, rarity="rare", glow=(0.3, 0.9, 1.0),
                                                   throw_damage=34), [
        P((0.05, 0.26, 0.05), (0, 0, 0), IRON), P((0.09, 0.05, 0.09), (0, 0.14, 0), DARK),
        P((0.06, 1.0, 0.06), (0, 0.66, 0), (0.45, 0.95, 1.0))]),
    # Heavy (two hands)
    ("hammer", "Hammer", "heavy", dict(base_damage=22, ref_speed=8, knockback=9, throw_damage=30, throw_speed=20), [
        P((0.06, 1.0, 0.06), (0, 0.2, 0), WOOD), P((0.34, 0.2, 0.2), (0, 0.72, 0), IRON),
        P((0.36, 0.04, 0.22), (0, 0.72, 0), (0.5, 0.52, 0.56))]),
    ("battle_axe", "Battle Axe", "heavy", dict(base_damage=25, ref_speed=8, knockback=8, throw_damage=32, throw_speed=20), [
        P((0.06, 1.05, 0.06), (0, 0.22, 0), WOOD), P((0.5, 0.3, 0.05), (0, 0.62, 0), STEEL),
        P((0.08, 0.36, 0.07), (0, 0.62, 0), IRON)]),
    ("pickaxe", "Pickaxe", "heavy", dict(base_damage=20, ref_speed=8, knockback=7, throw_damage=28), [
        P((0.06, 0.95, 0.06), (0, 0.18, 0), WOOD), P((0.7, 0.08, 0.08), (0, 0.62, 0), IRON),
        P((0.12, 0.06, 0.06), (0.38, 0.6, 0), STEEL), P((0.12, 0.06, 0.06), (-0.38, 0.6, 0), STEEL)]),
    ("anchor", "Ship Anchor", "heavy", dict(base_damage=34, ref_speed=8, knockback=12, slam_radius=3.6, move_speed=0.8,
                                            rarity="rare", throw_damage=40, throw_speed=17), [
        P((0.1, 1.1, 0.1), (0, 0.25, 0), IRON), P((0.5, 0.08, 0.08), (0, 0.62, 0), IRON),
        P((0.8, 0.1, 0.12), (0, 0.84, 0), IRON), P((0.12, 0.2, 0.12), (0.4, 0.76, 0), IRON),
        P((0.12, 0.2, 0.12), (-0.4, 0.76, 0), IRON), P((0.16, 0.12, 0.05), (0, -0.32, 0), (0.6, 0.6, 0.62))]),
    ("lollipop", "Giant Lollipop", "heavy", dict(base_damage=14, ref_speed=8, knockback=13, family="joke", throw_damage=20), [
        P((0.05, 1.0, 0.05), (0, 0.2, 0), WHITE), P((0.52, 0.52, 0.1), (0, 0.9, 0), (1.0, 0.4, 0.7)),
        P((0.36, 0.08, 0.11), (0, 0.9, 0), WHITE, 30), P((0.36, 0.08, 0.11), (0, 0.9, 0), (0.5, 0.9, 1.0), -30)]),
    # Polearms
    ("spear", "Spear", "polearm", dict(base_damage=17, ref_speed=8, knockback=5.5, throw_damage=30, throw_speed=28), [
        P((0.045, 1.9, 0.045), (0, 0.25, 0), WOOD), P((0.09, 0.25, 0.03), (0, 1.32, 0), STEEL)]),
    ("bo_staff", "Bo Staff", "polearm", dict(base_damage=13, ref_speed=8, knockback=7.5, attack_speed=1.1, throw_damage=20), [
        P((0.055, 1.9, 0.055), (0, 0.2, 0), WOOD), P((0.07, 0.12, 0.07), (0, 1.12, 0), DARK),
        P((0.07, 0.12, 0.07), (0, -0.72, 0), DARK)]),
    ("trident", "Trident", "polearm", dict(base_damage=22, ref_speed=8, knockback=6.5, rarity="rare", throw_damage=34, throw_speed=28), [
        P((0.05, 1.8, 0.05), (0, 0.25, 0), GOLD), P((0.32, 0.05, 0.05), (0, 1.14, 0), GOLD),
        P((0.04, 0.32, 0.04), (-0.13, 1.32, 0), STEEL), P((0.04, 0.38, 0.04), (0, 1.35, 0), STEEL),
        P((0.04, 0.32, 0.04), (0.13, 1.32, 0), STEEL)]),
    # Fists
    ("fists", "Fists", "fists", dict(base_damage=8, ref_speed=5.5, knockback=3.5), []),
    ("boxing_gloves", "Boxing Gloves", "fists", dict(base_damage=11, ref_speed=5.5, knockback=6.5, both_hands=True), [
        P((0.2, 0.18, 0.2), (0, 0.02, 0), (0.85, 0.12, 0.1)), P((0.15, 0.08, 0.15), (0, -0.1, 0), WHITE)]),
    ("power_gauntlet", "Power Gauntlet", "fists", dict(base_damage=16, ref_speed=5.5, knockback=10, both_hands=True, rarity="rare",
                                                       glow=(1.0, 0.6, 0.2)), [
        P((0.22, 0.24, 0.22), (0, 0.0, 0), IRON), P((0.24, 0.06, 0.06), (0, 0.06, 0.1), (1.0, 0.65, 0.25))]),
    # Thrown
    ("shuriken", "Shuriken", "thrown", dict(base_damage=12, ammo=5, throw_damage=13, throw_speed=32, throw_spin=30,
                                            catchable=True, keep_on_land=False), [
        P((0.24, 0.05, 0.02), (0, 0, 0), STEEL, 45), P((0.24, 0.05, 0.02), (0, 0, 0), STEEL, -45),
        P((0.07, 0.07, 0.03), (0, 0, 0), DARK)]),
    ("throwing_knives", "Throwing Knives", "thrown", dict(base_damage=14, ammo=4, throw_damage=17, throw_speed=30, throw_spin=24,
                                                          keep_on_land=False), [
        P((0.03, 0.1, 0.03), (0, 0, 0), DARK), P((0.04, 0.22, 0.015), (0, 0.15, 0), STEEL)]),
    ("bomb", "Bomb", "thrown", dict(base_damage=10, ammo=2, throw_damage=10, throw_speed=17, throw_spin=6, explosive=True,
                                    catchable=True, light_moves=["Bomb_Lob"], heavy_move="Bomb_Lob", keep_on_land=False), [
        P((0.26, 0.26, 0.26), (0, 0.05, 0), (0.12, 0.12, 0.14)), P((0.03, 0.1, 0.03), (0, 0.22, 0), WOOD),
        P((0.05, 0.05, 0.05), (0, 0.28, 0), (1.0, 0.6, 0.1))]),
    ("boomerang", "Boomerang", "thrown", dict(base_damage=12, ammo=1, throw_damage=18, throw_speed=24, throw_spin=22, returns=True), [
        P((0.08, 0.36, 0.03), (0.08, 0.12, 0), (0.85, 0.55, 0.2), 35), P((0.08, 0.36, 0.03), (-0.08, 0.12, 0), (0.85, 0.55, 0.2), -35)]),
    # Ranged
    ("blaster", "Blaster", "ranged", dict(base_damage=10, ammo=14, projectile_speed=55, projectile_damage=9, throw_damage=12), [
        P((0.08, 0.26, 0.12), (0, 0.1, 0), (0.3, 0.32, 0.38)), P((0.05, 0.16, 0.05), (0, 0.3, 0), DARK),
        P((0.06, 0.06, 0.16), (0, -0.02, -0.08), DARK), P((0.03, 0.03, 0.03), (0, 0.39, 0), (0.4, 1.0, 0.6))]),
    ("bow", "Bow", "ranged", dict(base_damage=10, ammo=8, projectile_speed=40, projectile_damage=16, hand="left", rarity="rare",
                                  light_moves=["Bow_Release"], heavy_charge="Bow_Draw", heavy_move="Bow_Release", idle_clip="",
                                  throw_damage=12), [
        P((0.05, 0.2, 0.07), (0, 0, 0), WOOD), P((0.04, 0.46, 0.05), (0, 0.32, -0.03), WOOD, 0),
        P((0.04, 0.46, 0.05), (0, -0.32, -0.03), WOOD, 0), P((0.01, 1.08, 0.01), (0, 0, -0.1), WHITE)]),
    # Joke
    ("frying_pan", "Frying Pan", "blade", dict(base_damage=12, ref_speed=8.5, knockback=9, family="joke", hit_sound="clang",
                                               throw_damage=20), [
        P((0.04, 0.36, 0.03), (0, 0.08, 0), DARK), P((0.34, 0.34, 0.05), (0, 0.44, 0), (0.25, 0.26, 0.28)),
        P((0.28, 0.28, 0.055), (0, 0.44, 0), (0.15, 0.15, 0.17))]),
    ("rubber_chicken", "Rubber Chicken", "blade", dict(base_damage=6, ref_speed=8, knockback=15, family="joke", hit_sound="squeak",
                                                       throw_damage=8), [
        P((0.13, 0.5, 0.11), (0, 0.38, 0), (1.0, 0.85, 0.2)), P((0.11, 0.13, 0.1), (0, 0.69, 0.03), (1.0, 0.85, 0.2)),
        P((0.05, 0.05, 0.08), (0, 0.69, 0.1), (1.0, 0.5, 0.1)), P((0.04, 0.14, 0.04), (0, 0.06, 0), (1.0, 0.5, 0.1))]),
]


def fmt(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(float(v)) if isinstance(v, float) else str(v)
    if isinstance(v, str):
        return '"%s"' % v
    raise TypeError(v)


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
    for k in ("knockdown_move", "heavy_charge", "heavy_move", "idle_clip", "hand", "hit_sound"):
        if k in fam:
            lines.append('%s = &"%s"' % (k, fam.pop(k)))
    lines.append("strikers = {%s}" % ", ".join('"%s": "%s"' % kv for kv in strikers.items()))
    for k, v in fam.items():
        lines.append("%s = %s" % (k, fmt(v)))
    if glow:
        lines.append("glow = Color(%s, %s, %s, 1)" % glow)
    sizes, centres, colors, yaws = [], [], [], []
    for size, centre, color, yaw in parts:
        sizes += size
        centres += centre
        colors += list(color) + [1.0]
        yaws.append(yaw)
    lines.append("part_sizes = PackedVector3Array(%s)" % ", ".join(str(x) for x in sizes))
    lines.append("part_centres = PackedVector3Array(%s)" % ", ".join(str(x) for x in centres))
    lines.append("part_colors = PackedColorArray(%s)" % ", ".join(str(x) for x in colors))
    lines.append("part_yaws = PackedFloat32Array(%s)" % ", ".join(str(x) for x in yaws))
    with open(os.path.join(OUT, wid + ".tres"), "w") as fh:
        fh.write("\n".join(lines) + "\n")


def main():
    os.makedirs(OUT, exist_ok=True)
    for wid, name, fam, stats, parts in WEAPONS:
        write(wid, name, fam, stats, parts)
    print("wrote %d weapons" % len(WEAPONS))


main()
