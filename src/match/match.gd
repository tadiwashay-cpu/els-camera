class_name Match
extends Node3D
## One Timed Kill Race. Builds the arena, the fighters (the player and
## bots), camera, HUD and touch controls, then runs the rules: respawns,
## weapon spawners, thrown weapons and pickups, hazard kills, killcams
## and the results screen.

signal ready_to_play

const BOT_NAMES := ["Rook", "Vex", "Bolt", "Juno", "Kite", "Nova", "Brick", "Pixel"]
## Most fighters in a match (you + 8 bots, or 4 phones + bots).
const MAX_FIGHTERS := 9
const RESPAWN_DELAY := 3.0

var config: MatchConfig
var arena: Arena
var fighters: Array[Fighter] = []
var projectiles: Array[ThrownWeapon] = []
var pickups: Array[WeaponPickup] = []
var race := KillRace.new()
var player: Fighter
var camera: CameraRig
var hud: Hud
var touch: TouchControls
var player_input: PlayerInput
var killcam: Killcam
var brains: Array[AIBrain] = []
var clock := 0.0
var started := false
var ended := false
var paused := false
var load_progress := 0.0

var _respawn_at: Dictionary = {}       # fighter id -> clock time
var _spawner_next: Array[float] = []
var _spawner_pickup: Array = []
var _last_tick := -1
var _last_kill: Dictionary = {}        # for the final replay
var powerups: Array = []               # PowerUp or null per pickup point
var _powerup_next: Array[float] = []
var _bullet_until := -1.0
var _bullet_by: Fighter
var _mystery: Breakable
var _mystery_next := 40.0
var _rng := RandomNumberGenerator.new()
## This phone runs the rules (offline, or hosting). Joiners only show.
var authority := true
## Network traffic of a LAN match (null offline).
var net: NetSync


func _ready() -> void:
	config = Game.match_config
	authority = Net.authority()
	if config.seed != 0:
		_rng.seed = config.seed
	else:
		_rng.randomize()
	var data := Registry.arena(config.arena_id)
	arena = (load(data.scene_path) as PackedScene).instantiate() as Arena
	add_child(arena)
	load_progress = 0.3
	killcam = Killcam.new()
	killcam.match_node = self
	add_child(killcam)
	_spawn_fighters()
	camera = CameraRig.new()
	add_child(camera)
	camera.target = player
	camera.yaw = player.rotation.y + PI
	Game.apply_to_world(arena.sun, arena.env, camera.camera)
	hud = Hud.new()
	hud.match_node = self
	hud.player = player
	add_child(hud)
	touch = TouchControls.new()
	hud.add_child(touch)
	player_input = PlayerInput.new()
	player_input.fighter = player
	player_input.camera = camera
	player_input.touch = touch
	add_child(player_input)
	arena.explosion.connect(func(at: Vector3, by: Fighter) -> void: explode(at, by, 5.0))
	arena.notice.connect(func(text: String, color: Color, sub: String) -> void:
		if not ended:
			hud.callout(text, color, sub, 1.3))
	hud.pause_pressed.connect(toggle_pause)
	hud.resume_pressed.connect(toggle_pause)
	hud.rematch_pressed.connect(func() -> void:
		if Net.active:
			if Net.is_host:
				Net.start_match()
		else:
			Game.start_match())
	hud.menu_pressed.connect(func() -> void:
		Net.leave()
		Game.goto_title())
	var ids: Array = []
	for f in fighters:
		ids.append(f.fighter_id)
	race.setup(ids, config.minutes, config.kill_target)
	hud.refresh_board()
	for i in arena.spawner_points.size():
		_spawner_next.append(0.0 if config.spawners else INF)
		_spawner_pickup.append(null)
	for i in arena.pickup_points.size():
		_powerup_next.append(8.0 + i * 1.5 if config.pickups else INF)
		powerups.append(null)
	for f in fighters:
		f.freeze(true)
	if Net.active:
		net = NetSync.new()
		add_child(net)
		net.setup(self)
		if not authority:
			for piece in arena.breakables:
				piece.net_puppet = true
	_prepare()


## Bakes the bot nav mesh and compiles effect shaders behind the loading
## screen (no first-hit stutter), then tells the loading screen we're ready.
func _prepare() -> void:
	arena.bake_navigation()
	_warm_up()
	await arena.nav_ready
	load_progress = 0.9
	for i in 3:
		await get_tree().process_frame
	load_progress = 1.0
	ready_to_play.emit()


func _warm_up() -> void:
	var at := camera.global_position + Vector3(0, 1.5, -3)
	Fx.sparks(self, at, Color.WHITE)
	Fx.dust(self, at)
	Fx.burst(self, at, Color.ORANGE)
	Fx.damage_number(self, at, 10, Color.WHITE)
	var w := Registry.weapon(&"sword")
	var mi := MeshInstance3D.new()
	mi.mesh = w.mesh()
	add_child(mi)
	mi.global_position = at
	get_tree().create_timer(0.3).timeout.connect(mi.queue_free)


func _spawn_fighters() -> void:
	var starts := arena.spawn_points.duplicate()
	var entries: Array = []
	if Net.active and not Net.roster.is_empty():
		entries = Net.roster
	else:
		var count := 1 + clampi(config.bots, 1, MAX_FIGHTERS - 1)
		for i in count:
			var e := {"id": i, "name": str(Save.setting("player_name")) if i == 0 else BOT_NAMES[(i - 1) % BOT_NAMES.size()],
				"skin": i, "peer": 1 if i == 0 else 0,
				"power": String(config.power if i == 0 else FighterPowers.IDS[(i * 2 + _rng.randi()) % FighterPowers.IDS.size()])}
			if i == 0:
				e["owned"] = Armory.owned()
				e["loadout"] = String(Armory.equipped())
			else:
				e["loadout"] = String(bot_loadout(_rng))
			entries.append(e)
	var me := Net.my_id()
	for e: Dictionary in entries:
		var i := int(e["id"])
		var peer := int(e["peer"])
		var f := Fighter.new()
		f.fighter_id = i
		f.is_player = peer == me
		f.puppet = not authority
		f.display_name = str(e["name"])
		f.skin = Registry.skin(int(e["skin"]))
		f.world = self
		f.set_locker(e.get("owned", []))
		f.loadout = StringName(str(e.get("loadout", "")))
		f.weapon_data = start_weapon(f)
		f.powers.power = StringName(str(e["power"]))
		f.set_meta("peer", peer)
		add_child(f)
		# Spread the start: every spawn point once, then rings around them.
		var spot: Vector3 = starts[(i * 3) % starts.size()] if entries.size() <= starts.size() else starts[i % starts.size()]
		var lap := i / starts.size()
		if lap > 0:
			spot += Vector3(cos(i * 2.1), 0, sin(i * 2.1)) * 1.6 * lap
		f.global_position = spot
		var to_centre := -spot
		f.rotation.y = atan2(to_centre.x, to_centre.z)
		f.died.connect(_on_died)
		f.hurt.connect(_on_hurt)
		f.went_limp.connect(_on_limp)
		fighters.append(f)
		if f.is_player:
			player = f
		elif peer == 0 and authority:
			brains.append(AIBrain.new(f, self, config.difficulty))


## Host: a body went limp; every phone plays the same ragdoll.
func _on_limp(f: Fighter, impulse: Vector3, vel: Vector3, bone: StringName, dead: bool) -> void:
	if net:
		net.event("death" if dead else "down", [f.fighter_id, impulse, vel, String(bone)])


## Called by the loading screen once it has faded out.
func begin() -> void:
	if Net.active:
		Net.report_loaded()          # the host starts everyone's countdown together
		return
	countdown()


func countdown() -> void:
	if started:
		return
	for n in [3, 2, 1]:
		hud.callout(str(n), Color.WHITE, "", 0.5)
		Audio.play(&"beep")
		await get_tree().create_timer(0.8).timeout
	hud.callout("FIGHT!", UiTheme.ACCENT, "Most kills when the clock hits zero wins", 0.9)
	Audio.play(&"go")
	started = true
	for f in fighters:
		f.freeze(false)


func _physics_process(delta: float) -> void:
	if not started or ended:
		return
	if not authority:
		# A joiner: the host's snapshots move everything; the arena's looks
		# (water, gulls, neon) still run here.
		arena.tick(self, delta)
		var near: WeaponData = net.pickup_near(player.global_position, 1.3) if net and player.alive else null
		hud.set_locked(near if near != null and not player.can_use(near) else null)
		if touch.visible:
			touch.set_power_ready(player.powers.ready_to_use())
			touch.set_swap(player.armed() and near != null and player.can_use(near))
			_touch_skill()
		return
	clock += delta
	for ev in race.tick(delta):
		match ev:
			"final":
				hud.callout("30 SECONDS", Color(1, 0.4, 0.3), "Kills count double", 1.4)
				Audio.play(&"buzzer", null, -6.0, 1.4)
			"overtime":
				hud.callout("SUDDEN DEATH", UiTheme.ACCENT, "Next kill wins", 1.6)
				Audio.play(&"buzzer")
			"end":
				_end_match()
				return
	var sec := int(ceil(race.time_left))
	if sec <= 10 and sec != _last_tick and not race.overtime:
		_last_tick = sec
		Audio.play(&"tick", null, -2.0)
	for b in brains:
		b.update(delta)
	arena.tick(self, delta)
	for f in fighters:
		var y := f.global_position.y
		if f.alive and y < arena.kill_y:
			f.die(null, Vector3.ZERO)
	for id: int in _respawn_at.keys():
		if clock >= float(_respawn_at[id]):
			_respawn_at.erase(id)
			_respawn(fighter_by_id(id))
	_tick_spawners()
	_tick_powerups()
	if config.spawners and arena.mystery_point != Vector3.INF and _mystery == null and clock >= _mystery_next:
		_drop_mystery()
	if _bullet_until > 0.0 and clock >= _bullet_until:
		_end_bullet_time()
	killcam.record(clock)
	if touch.visible:
		var incoming := incoming_projectile(player, 0.6)
		touch.set_catch_hint(incoming != null and incoming.data.catchable and player.can_use(incoming.data))
		touch.set_power_ready(player.powers.ready_to_use())
		touch.set_swap(player.armed() and player.state == Fighter.State.MOVE and pickup_near(player.global_position, 1.3, player) != null)
		_touch_skill()
	if player:
		var locked := pickup_near(player.global_position, 1.3) if player.alive else null
		hud.set_locked(locked.data if locked and not player.can_use(locked.data) else null)


func _tick_powerups() -> void:
	for i in arena.pickup_points.size():
		var p: PowerUp = powerups[i]
		if p == null:
			if clock >= _powerup_next[i]:
				var roll := _rng.randf()
				var kind: StringName = &"health" if roll < 0.3 else (&"speed" if roll < 0.5 else (&"damage" if roll < 0.7 else (&"shield" if roll < 0.85 else &"battery")))
				p = PowerUp.new()
				add_child(p)
				p.setup(kind, arena.pickup_points[i], i)
				powerups[i] = p
			continue
		for f in fighters:
			if f.alive and (f.global_position + Vector3.UP).distance_to(p.global_position) < 1.25:
				var text := f.apply_pickup(p.kind)
				var color: Color = FighterPowers.PICKUPS[p.kind]["color"]
				Audio.play(&"pickup", p.global_position, 0.0, 1.2)
				Fx.sparks(self, p.global_position, color, 16)
				callout_for(f, text, color)
				powerups[i] = null
				_powerup_next[i] = clock + 22.0
				p.queue_free()
				break


## The nearest map pickup (optionally only some kinds), for bots.
func nearest_powerup(pos: Vector3, radius: float, kinds: Array = []) -> PowerUp:
	var best: PowerUp
	var best_d := radius
	for p in powerups:
		if p == null or not is_instance_valid(p):
			continue
		if not kinds.is_empty() and not kinds.has((p as PowerUp).kind):
			continue
		var d := (p as PowerUp).global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = p
	return best


## Big words for the player, or floating words over a bot.
func callout_for(f: Fighter, text: String, color: Color) -> void:
	if net:
		net.event("float", [f.fighter_id, text, color])
	if f == player:
		hud.callout(text, color, "", 0.6)
	else:
		Fx.floating_text(self, f.global_position + Vector3.UP * 2.5, text, color)


## Bullet Time: everyone but `by` at half speed for `seconds`.
func bullet_time(by: Fighter, seconds: float) -> void:
	_bullet_by = by
	_bullet_until = clock + seconds
	by.powers.add_effect(&"bullet_time", seconds)
	for f in fighters:
		var scale := 1.0 if f == by else 0.5
		f.time_scale = scale
		f.body.set_time_scale(scale)
	hud.set_tint(Color(0.35, 0.5, 1.0, 0.16))


func _end_bullet_time() -> void:
	_bullet_until = -1.0
	for f in fighters:
		f.time_scale = 1.0
		f.body.set_time_scale(1.0)
	hud.set_tint(Color(0, 0, 0, 0))


func _tick_spawners() -> void:
	if Engine.get_physics_frames() % 60 == 0:
		_prune_pickups()
	for i in arena.spawner_points.size():
		var p: WeaponPickup = _spawner_pickup[i]
		if p != null and is_instance_valid(p):
			continue
		_spawner_pickup[i] = null
		if clock >= _spawner_next[i]:
			var pool := Registry.weapon_pool(false)
			var pick := drop_pickup(pool[_rng.randi() % pool.size()], arena.spawner_points[i] + Vector3.UP * 0.6, Vector3.ZERO)
			pick.spawner = i
			_spawner_pickup[i] = pick
			_spawner_next[i] = INF


# ------------------------------------------------------------------ deaths

func _on_hurt(victim: Fighter, attacker: Fighter, damage: float, at: Vector3, heavy: bool) -> void:
	if net:
		net.event("hit", [victim.fighter_id, attacker.fighter_id if attacker else -1, damage, at, heavy])
	Fx.sparks(self, at, Color(1, 0.85, 0.55) if not heavy else Color(1, 0.55, 0.3), 16 if heavy else 10)
	Fx.damage_number(self, at + Vector3.UP * 0.3, damage, Color(1, 0.95, 0.6) if attacker == player else Color(1, 0.45, 0.4))
	Audio.play(&"hit_heavy" if heavy else &"hit", at, 0.0 if heavy else -2.0)
	if attacker and attacker.armed() and attacker.weapon_data.hit_sound != &"":
		Audio.play(attacker.weapon_data.hit_sound, at, 3.0)
	if heavy:
		Game.hit_stop(40)
	if victim == player or attacker == player:
		camera.shake(0.45 if heavy else 0.22)
		Game.vibrate(40 if heavy else 18)


func _on_died(victim: Fighter, killer: Fighter) -> void:
	var last := victim.last_hitter
	var age := clock - victim.last_hit_time
	var res := race.register_death(victim.fighter_id, killer.fighter_id if killer else -1,
		last.fighter_id if last and last != victim else -1, age)
	var credited := fighter_by_id(int(res["id"])) if int(res["points"]) > 0 else null
	var cause := victim.death_cause
	victim.death_cause = ""
	if killer == null and credited and cause == "":
		cause = "knocked off"
	_last_kill = {"t": clock, "victim": victim.fighter_id, "killer": credited.fighter_id if credited else -1}
	if net:
		net.event("kill", [victim.fighter_id, credited.fighter_id if credited else -1, int(res["points"]), cause])
	present_death(victim, credited, int(res["points"]), cause)
	if race.finished:
		_end_match()
		return
	_respawn_at[victim.fighter_id] = clock + RESPAWN_DELAY


## What everyone sees of a death (host and joiners): feed, callouts, stats.
func present_death(victim: Fighter, credited: Fighter, points: int, cause: String) -> void:
	if victim == null:
		return
	hud.refresh_board()
	Fx.burst(self, victim.global_position + Vector3.UP, victim.body.skin.shirt)
	if victim == player:
		Save.add_stat("deaths")
	if credited == player:
		Save.add_stat("kills")
	if credited:
		var how := "knocked off" if cause == "knocked off" else ">"
		var tag := "  (%s)" % cause if cause != "" and cause != "knocked off" else ""
		hud.feed("%s  %s  %s%s" % [credited.display_name, how, victim.display_name, tag], credited.body.skin.shirt.lightened(0.3))
	else:
		hud.feed("%s  %s  -1" % [victim.display_name, "(%s)" % cause if cause != "" else "fell"], Color(1, 0.5, 0.45))
	if credited == player:
		hud.callout("KILL +%d" % points, UiTheme.ACCENT, victim.display_name, 0.8)
		Audio.play(&"kill", null, 0.0)
		Game.slow_motion(0.3, 0.45)
		camera.shake(0.5)
	if victim == player and not ended and not race.finished:
		if credited:
			hud.callout("KILLED BY %s" % credited.display_name.to_upper(), Color(1, 0.4, 0.35), "", 1.0)
		else:
			hud.callout("YOU FELL", Color(1, 0.4, 0.35), "-1", 1.0)
		Game.slow_motion(0.35, 0.5)
		if Net.active:
			return                 # no killcam online: the match keeps running
		player_input.enabled = false
		# Let the fall play out (and be recorded) before replaying it.
		await get_tree().create_timer(1.0, true, false, true).timeout
		if credited and not ended:
			await _replay(victim, credited, 0.8, 0.55, 0.55, "KILLCAM   %s got you" % credited.display_name)
		player_input.enabled = true


func _replay(victim: Fighter, killer: Fighter, before: float, after: float, speed: float, caption: String) -> void:
	get_tree().paused = true
	hud.visible = false
	touch.release_all()
	var t: float = _last_kill.get("t", clock)
	killcam.play(t, before, after, speed, [victim.fighter_id, killer.fighter_id] as Array[int], caption)
	await killcam.finished
	hud.visible = true
	if not paused:
		get_tree().paused = false


## An arena hazard got `f` (a shark, the crusher, the harbour): the kill
## goes to whoever hit them last (doc: environmental kills), with `cause`
## in the kill feed ("fed to a shark").
func hazard_kill(f: Fighter, cause: String, impulse: Vector3 = Vector3.ZERO) -> void:
	if not f.alive or ended:
		return
	f.death_cause = cause
	f.die(null, impulse)


## The SKILL button: the power's colour, its cooldown ring.
func _touch_skill() -> void:
	var s := WeaponSkills.info(player.skill_id())
	if s.is_empty():
		touch.set_skill(Color(0.4, 0.4, 0.45), 0.0, "")
		return
	var left := player.skill_left()
	touch.set_skill(s["color"], 1.0 - clampf(left / float(s["cd"]), 0.0, 1.0), str(s["name"]))


## Things about to hit `f` within `horizon` seconds (danger sense):
## [{"id", "pos", "t"}]. Works on the host and on joiners (from mirrors).
func threats_to(f: Fighter, horizon: float) -> Array:
	var out: Array = []
	var me := f.global_position + Vector3.UP * 1.1
	if authority:
		for p in projectiles:
			if is_instance_valid(p) and p.harmful and p.thrower != f:
				_add_threat(out, p.get_instance_id(), p.global_position, p.velocity, me, horizon)
		for c in get_children():
			var b := c as Bolt
			if b and b.owner_fighter != f:
				_add_threat(out, b.get_instance_id(), b.global_position, b.velocity, me, horizon)
	elif net:
		for item: Array in net.flying():
			_add_threat(out, item[0], item[1], item[2], me, horizon)
	return out


func _add_threat(out: Array, id: Variant, pos: Vector3, vel: Vector3, me: Vector3, horizon: float) -> void:
	var speed2 := vel.length_squared()
	if speed2 < 4.0:
		return
	var to := me - pos
	var t := to.dot(vel) / speed2
	if t <= 0.0 or t > horizon:
		return
	if (to - vel * t).length() > 1.3:
		return                         # it'll miss
	out.append({"id": id, "pos": pos, "t": t})


## Something blew up (a barrel, a bomb): blast everyone and everything
## nearby (the kill goes to whoever set it off; nearby barrels chain).
func explode(at: Vector3, by: Fighter, radius: float = 5.0) -> void:
	if not authority:
		return
	var RADIUS := radius
	if net:
		net.event("boom", [at, RADIUS])
	Fx.explosion(self, at, RADIUS)
	Audio.play(&"boom", at, 2.0)
	arena.ignite(at, RADIUS * 0.8, by)
	Game.hit_stop(60)
	var to_cam := camera.global_position.distance_to(at)
	camera.shake(clampf(1.2 - to_cam / 25.0, 0.2, 1.0))
	Game.vibrate(60)
	for f in fighters:
		if not f.alive:
			continue
		var c := f.global_position + Vector3.UP
		var d := c.distance_to(at)
		if d > RADIUS:
			continue
		var k := 1.0 - d / RADIUS
		var dir := f.global_position - at
		dir.y = 0.0
		f.take_hit(48.0 * k + 8.0, dir.normalized(), by, true, c, 9.0 * k + 5.0)
	for piece in arena.breakables:
		if piece.is_broken:
			continue
		var d := piece.global_position.distance_to(at)
		if d < RADIUS:
			# A short fuse so chains ripple instead of all popping at once.
			get_tree().create_timer(0.08 + d * 0.03).timeout.connect(func() -> void:
				piece.hit(80.0 * (1.0 - d / RADIUS) + 10.0, piece.global_position, (piece.global_position - at).normalized() * 6.0, by))


func _respawn(f: Fighter) -> void:
	if f == null or ended:
		return
	var enemies: Array[Vector3] = []
	for o in fighters:
		if o != f and o.alive:
			enemies.append(o.global_position)
	var i := Arena.farthest_spawn(arena.spawn_points, enemies)
	var p := arena.spawn_points[i]
	f.respawn(p, atan2(-p.x, -p.z))
	Fx.burst(self, p + Vector3.UP, f.body.skin.trail)
	if f == player:
		camera.yaw = f.rotation.y + PI
		camera.snap()
		hud.callout("BACK IN!", Color.WHITE, "2 s of protection", 0.6)


func _end_match() -> void:
	if ended:
		return
	ended = true
	started = false
	player_input.enabled = false
	touch.release_all()
	var winner := fighter_by_id(race.winner)
	if net:
		net.event("end", [race.winner])
	for f in fighters:
		f.freeze(true)
	Audio.play(&"buzzer")
	hud.callout("TIME!" if race.time_left <= 0.0 else "FINISH!", UiTheme.ACCENT, "", 1.0)
	await get_tree().create_timer(1.0, true, false, true).timeout
	if not Net.active and not _last_kill.is_empty() and int(_last_kill["killer"]) >= 0:
		var v := fighter_by_id(int(_last_kill["victim"]))
		var k := fighter_by_id(int(_last_kill["killer"]))
		if v and k:
			await _replay(v, k, 1.0, 0.7, 0.4, "FINAL KILL   %s" % k.display_name)
	_results(winner)


## A joiner's match ends when the host says so.
func end_for_joiner(winner_id: int) -> void:
	if ended:
		return
	ended = true
	started = false
	race.winner = winner_id
	race.finished = true
	player_input.enabled = false
	touch.release_all()
	Audio.play(&"buzzer")
	hud.callout("TIME!" if race.time_left <= 0.0 else "FINISH!", UiTheme.ACCENT, "", 1.0)
	await get_tree().create_timer(1.0, true, false, true).timeout
	_results(fighter_by_id(winner_id))


func _results(winner: Fighter) -> void:
	if Net.active:
		Net.end_match()
	if winner:
		if winner.alive and authority:
			winner.celebrate()
		camera.target = winner
	var rows: Array = []
	for id: int in race.ranking():
		var f := fighter_by_id(id)
		rows.append([f.display_name, "%d kills" % int(race.scores[id]), f.body.skin.shirt.lightened(0.35)])
	var my_kills: int = maxi(int(race.scores.get(player.fighter_id, 0)), 0)
	var coins := Armory.match_coins(my_kills, winner == player)
	Save.add_coins(coins)
	Save.add_stat("matches")
	if winner == player:
		Save.add_stat("wins")
	Save.save_data()
	player_input.release_mouse()
	hud.show_results(winner, rows, coins)


func toggle_pause() -> void:
	if ended or killcam.playing:
		return
	paused = not paused
	if not Net.active:
		get_tree().paused = paused          # online the match keeps going
	hud.show_pause(paused)
	if paused:
		player_input.release_mouse()
		touch.release_all()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		toggle_pause()
	elif killcam.playing and (event is InputEventScreenTouch or event is InputEventMouseButton) and event.is_pressed():
		killcam.skip()


# ------------------------------------------------------- weapons in the world

func spawn_projectile(by: Fighter, data: WeaponData, origin: Vector3, dir: Vector3, speed: float, boosted: bool, ammo_left: int = -1) -> ThrownWeapon:
	var p := ThrownWeapon.new()
	p.world = self
	add_child(p)
	p.launch(by, data, origin, dir, speed, boosted, ammo_left)
	projectiles.append(p)
	return p


func spawn_bolt(by: Fighter, origin: Vector3, dir: Vector3, speed: float, damage: float, style: StringName = &"bolt") -> Bolt:
	var b := Bolt.new()
	b.world = self
	add_child(b)
	b.launch(by, origin, dir, speed, damage, style)
	return b


## A fan's gust: everyone in a cone in front is blown back (handy near water).
func gust(by: Fighter, origin: Vector3, dir: Vector3) -> void:
	if not authority:
		return
	var flat := Vector3(dir.x, 0, dir.z).normalized()
	if net:
		net.event("gust", [origin, flat])
	Fx.gust(self, origin, flat)
	for f in fighters:
		if f == by or not f.alive:
			continue
		var to := f.global_position + Vector3.UP - origin
		var d := to.length()
		if d > 8.0 or flat.dot(Vector3(to.x, 0, to.z).normalized()) < 0.8:
			continue
		var k := 1.0 - d / 8.0
		f.take_hit(2.0, flat, by, false, f.global_position + Vector3.UP, 9.0 + 9.0 * k)
		f.velocity += Vector3.UP * (3.0 + 3.0 * k)
	for p in projectiles:
		if is_instance_valid(p) and p.global_position.distance_to(origin) < 7.0:
			p.velocity += flat * 10.0


## Lightning strikes `at`: damage and knockdowns nearby, oil catches fire.
func lightning(at: Vector3, by: Fighter, radius: float = 3.4) -> void:
	if not authority:
		return
	if net:
		net.event("zap", [at])
	Fx.lightning(self, at)
	Audio.play(&"zap", at, 4.0, 0.8)
	Audio.play(&"boom", at, -4.0, 1.6)
	Game.hit_stop(50)
	camera.shake(clampf(1.0 - camera.global_position.distance_to(at) / 30.0, 0.15, 0.6))
	arena.ignite(at, radius, by)
	for f in fighters:
		if not f.alive:
			continue
		var d := (f.global_position + Vector3.UP).distance_to(at)
		if d > radius:
			continue
		var dir := f.global_position - at
		dir.y = 0.0
		f.take_hit(34.0 * (1.0 - d / radius) + 12.0, dir.normalized() if dir.length() > 0.1 else Vector3.FORWARD, by, true,
			f.global_position + Vector3.UP, 5.0)
	for piece in arena.breakables:
		if not piece.is_broken and piece.global_position.distance_to(at) < radius:
			piece.hit(40.0, piece.global_position, Vector3.UP * 3.0, by)


func remove_projectile(p: ThrownWeapon) -> void:
	projectiles.erase(p)
	p.queue_free()


func incoming_projectile(f: Fighter, horizon: float) -> ThrownWeapon:
	var best: ThrownWeapon
	var best_t := horizon
	for p in projectiles:
		if not is_instance_valid(p) or not p.harmful or p.thrower == f or p.phantom:
			continue
		var t := p.time_to(f)
		if t <= best_t and p.global_position.distance_to(f.global_position + Vector3.UP) < 14.0:
			best_t = t
			best = p
	return best


func time_to_reach(p: ThrownWeapon, f: Fighter) -> float:
	return p.time_to(f)


func catch_projectile(p: ThrownWeapon, _by: Fighter) -> void:
	projectiles.erase(p)
	p.queue_free()


func projectile_landed(p: ThrownWeapon, at: Vector3) -> void:
	projectiles.erase(p)
	var by := p.thrower if p.thrower and is_instance_valid(p.thrower) else null
	if p.warp and by and by.alive:
		by.global_position = at + Vector3.UP * 0.1
		Fx.burst(self, at + Vector3.UP, Color(0.6, 0.35, 0.9))
	if p.phantom and not p.data.explosive:
		Fx.dust(self, at, 0.4)
		p.queue_free()
		return
	if p.data.explosive:
		explode(at, by, 4.0)
	elif p.data.ignites:
		arena.ignite(at, 1.5, by)
	if p.data.explosive:
		pass
	elif at.y > arena.kill_y and p.data.keep_on_land:
		drop_pickup(p.data, at + Vector3.UP * 0.3, Vector3.ZERO, p.ammo)
	else:
		Fx.dust(self, at, 0.4)
	p.queue_free()


func drop_pickup(data: WeaponData, at: Vector3, vel: Vector3, ammo_left: int = -1) -> WeaponPickup:
	var pick := WeaponPickup.new()
	add_child(pick)
	pick.setup(data, at, vel, ammo_left)
	pickups.append(pick)
	return pick


## A weapon on the ground within `radius`; with `for_fighter`, only one
## that fighter may hold (Armory).
func pickup_near(pos: Vector3, radius: float, for_fighter: Fighter = null) -> WeaponPickup:
	for p in pickups:
		if is_instance_valid(p) and p.can_take() and p.global_position.distance_to(pos + Vector3.UP * 0.6) <= radius:
			if for_fighter == null or for_fighter.can_use(p.data):
				return p
	return null


func nearest_pickup(pos: Vector3, radius: float) -> WeaponPickup:
	var best: WeaponPickup
	var best_d := radius
	for p in pickups:
		if is_instance_valid(p) and p.global_position.y > arena.kill_y:
			var d := p.global_position.distance_to(pos)
			if d < best_d:
				best_d = d
				best = p
	return best


func take_pickup(pick: WeaponPickup, f: Fighter) -> void:
	pickups.erase(pick)
	if pick.spawner >= 0:
		_spawner_next[pick.spawner] = clock + config.spawner_seconds
		_spawner_pickup[pick.spawner] = null
	f.equip(pick.data, pick.ammo)
	f.body.play(&"Pickup", true, 1.5, 0.05)
	Audio.play(&"pickup", pick.global_position, -2.0)
	Fx.sparks(self, pick.global_position, Color(1, 0.85, 0.3), 12)
	pick.queue_free()
	_prune_pickups()


func _prune_pickups() -> void:
	var keep: Array[WeaponPickup] = []
	for p in pickups:
		if is_instance_valid(p) and not p.is_queued_for_deletion():
			keep.append(p)
	pickups = keep


## Armed and standing on another weapon: drop ours, take that one.
func swap_pickup(pick: WeaponPickup, f: Fighter) -> void:
	var old := f.unequip()
	if old:
		drop_pickup(old, f.global_position + f.forward() * 0.5 + Vector3.UP, Vector3.UP * 3.0, f._dropped_ammo)
	take_pickup(pick, f)


## Once a minute a gold crate lands on the tower with a rare weapon inside.
func _drop_mystery() -> void:
	var at := arena.mystery_point + Vector3.UP * 0.6
	var crate := arena.breakable(Breakable.Kind.CRATE, Vector3(1.2, 1.2, 1.2), at + Vector3.UP * 14.0, Color(1.0, 0.78, 0.2))
	crate.rebuilds = false
	crate.max_hp = 20.0
	crate.hp = 20.0
	_mystery = crate
	var tw := crate.create_tween()
	tw.tween_property(crate, "position", at, 0.8).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		Fx.dust(self, at, 1.8)
		Audio.play(&"land", at, 6.0)
		arena.request_rebake())
	crate.broken.connect(func(piece: Breakable, _by: Fighter) -> void:
		var rare := Registry.weapon_pool(true)
		drop_pickup(rare[_rng.randi() % rare.size()], piece.global_position + Vector3.UP * 0.4, Vector3.UP * 4.0)
		_mystery = null
		_mystery_next = clock + 60.0)
	hud.callout("MYSTERY CRATE", Color(1.0, 0.8, 0.25), "A rare weapon, on top of the tower", 1.2)
	Audio.play(&"ui_confirm", null, 0.0)


## The enemy the thrower is most likely aiming at, if any (cone shrinks
## as aim assist goes down).
func aim_assist_target(f: Fighter, strength: float) -> Fighter:
	if strength <= 0.01:
		return null
	var aim := f.forward()
	if f.is_player:
		aim = Vector3(-sin(f.input.aim_yaw), 0, -cos(f.input.aim_yaw))
	var best: Fighter
	var best_dot := 1.0 - 0.35 * strength
	for o in fighters:
		if o == f or not o.alive:
			continue
		var to := o.global_position - f.global_position
		to.y = 0.0
		if to.length() > 30.0:
			continue
		var d := aim.dot(to.normalized())
		if d > best_dot:
			best_dot = d
			best = o
	return best


## What a fighter (re)spawns holding: the setup's choice, or a random
## common weapon when it's "random".
## What `f` starts each life with, by the match's "Start with" setting:
## its own pick (loadout), a random weapon it may hold, the sword or fists.
func start_weapon(f: Fighter = null) -> WeaponData:
	match config.start_weapon:
		&"random":
			var pool: Array[WeaponData] = []
			for w in Registry.weapon_pool(false):
				if f == null or f.can_use(w):
					pool.append(w)
			return pool[_rng.randi() % pool.size()] if not pool.is_empty() else Registry.weapon(&"sword")
		&"loadout":
			var w := Registry.weapon(f.loadout) if f and f.loadout != &"" else null
			return w if w and f.can_use(w) else Registry.weapon(&"sword")
	return Registry.weapon(config.start_weapon)


## A bot's own weapon for "Your weapon" matches: any common one, now and then a rare.
static func bot_loadout(rng: RandomNumberGenerator) -> StringName:
	var pool := Registry.weapon_pool(rng.randf() < 0.15)
	return pool[rng.randi() % pool.size()].id if not pool.is_empty() else &"sword"


func fighter_by_id(id: int) -> Fighter:
	for f in fighters:
		if f.fighter_id == id:
			return f
	return null
