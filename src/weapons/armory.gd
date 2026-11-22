class_name Armory
extends RefCounted
## The Armory: a player buys a weapon with coins before they can use it
## (start with it, pick it up, catch it). The price follows the weapon's
## rank. The sword and fists are free. Bots can use every weapon.
## Owned weapons and the equipped one live in the save (Save.data).

const RANKS: Array[String] = ["S+", "S", "A", "B", "C"]
const PRICES := {"S+": 1500, "S": 1000, "A": 600, "B": 350, "C": 150}
const RANK_COLORS := {
	"S+": Color(1.0, 0.35, 0.45), "S": Color(1.0, 0.62, 0.2), "A": Color(0.75, 0.5, 1.0),
	"B": Color(0.35, 0.75, 1.0), "C": Color(0.6, 0.85, 0.55),
}
const FREE: Array[StringName] = [&"sword", &"fists"]
## Coins a match pays (Match._results).
const COINS_PER_KILL := 15
const COINS_FOR_WIN := 75
const COINS_FOR_PLAYING := 10


static func price(w: WeaponData) -> int:
	if w == null or FREE.has(w.id):
		return 0
	return int(PRICES.get(w.tier, PRICES["C"]))


static func rank_color(tier: String) -> Color:
	return RANK_COLORS.get(tier, Color.WHITE)


static func match_coins(kills: int, won: bool) -> int:
	return maxi(kills, 0) * COINS_PER_KILL + (COINS_FOR_WIN if won else 0) + COINS_FOR_PLAYING


## Every weapon on sale, best rank first, then by price and name.
static func catalogue() -> Array[WeaponData]:
	var out: Array[WeaponData] = []
	for w: WeaponData in Registry.weapons.values():
		out.append(w)
	out.sort_custom(func(a: WeaponData, b: WeaponData) -> bool:
		var ra := RANKS.find(a.tier)
		var rb := RANKS.find(b.tier)
		if ra != rb:
			return ra < rb
		return a.display_name < b.display_name)
	return out


# --------------------------------------------------------- the save's locker

## The ids this save owns (always including the free ones).
static func owned(d: Dictionary = Save.data) -> PackedStringArray:
	var out := PackedStringArray()
	for id in FREE:
		out.append(String(id))
	var list: Variant = d.get("owned", [])
	if list is Array:
		for v: Variant in list:
			var id := str(v)
			if not out.has(id) and Registry.weapons.has(StringName(id)):
				out.append(id)
	return out


static func owns(id: StringName, d: Dictionary = Save.data) -> bool:
	return FREE.has(id) or owned(d).has(String(id))


## The weapon "Your weapon" starts with (falls back to the sword).
static func equipped(d: Dictionary = Save.data) -> StringName:
	var id := StringName(str(d.get("equipped", "sword")))
	return id if owns(id, d) else &"sword"


static func can_afford(w: WeaponData, d: Dictionary = Save.data) -> bool:
	return int(d.get("coins", 0)) >= price(w)


## Buys `w`: takes the coins and adds it to the locker. False if it's
## already owned or too dear. Saves when `d` is the real save.
static func buy(w: WeaponData, d: Dictionary = Save.data) -> bool:
	if w == null or owns(w.id, d) or not can_afford(w, d):
		return false
	d["coins"] = int(d.get("coins", 0)) - price(w)
	var list: Array = d.get("owned", []) if d.get("owned", []) is Array else []
	list.append(String(w.id))
	d["owned"] = list
	if d == Save.data:
		Save.save_data()
	return true


static func equip(id: StringName, d: Dictionary = Save.data) -> bool:
	if not owns(id, d):
		return false
	d["equipped"] = String(id)
	if d == Save.data:
		Save.save_data()
	return true


## The weapon ids a hello / roster entry may use, cleaned up: only real
## weapons, always the free ones (what a joiner sends can't be trusted to
## be tidy).
static func clean_locker(list: Variant) -> PackedStringArray:
	return owned({"owned": list if list is Array or list is PackedStringArray else []})


## One line about what a weapon is like, for the Armory card.
static func traits(w: WeaponData) -> String:
	var parts: PackedStringArray = []
	match w.kind:
		&"ranged":
			parts.append("Shoots")
		&"thrown":
			parts.append("Thrown")
		_:
			parts.append("Melee" if not w.is_fists() else "Bare hands")
	if w.uses_ammo() and w.ammo > 1:
		parts.append("%d %s" % [w.ammo, "shots" if w.kind == &"ranged" else "throws"])
	if w.kind != &"thrown" and not w.is_fists():
		parts.append("can be thrown" if w.throwable else "can't be thrown")
	if w.block_mult < 1.0:
		parts.append("strong block")
	if w.ignites:
		parts.append("sets fire")
	return ", ".join(parts)
