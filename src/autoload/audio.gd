extends Node
## Sound: an SFX bus, pooled players and the game's sound effects.
##
## The effects are synthesised here at startup (filtered noise, sine and
## metal partials), so the game ships without audio files for now. Recorded
## or generated sounds can replace any of them later: put an .ogg/.wav in
## assets/audio/sfx/ named like the effect and it's used instead.

const RATE := 22050
const POOL_3D := 14
const POOL_2D := 6

var _streams: Dictionary = {}          # name -> Array[AudioStream] (variants)
var _pool3d: Array[AudioStreamPlayer3D] = []
var _pool2d: Array[AudioStreamPlayer] = []
var _next3d := 0
var _next2d := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index(&"SFX") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, &"SFX")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, &"Master")
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = &"SFX"
		p.unit_size = 8.0
		p.max_distance = 70.0
		p.attenuation_filter_cutoff_hz = 9000.0
		add_child(p)
		_pool3d.append(p)
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_pool2d.append(p)
	_build()
	set_master_volume(float(Save.setting("master_volume")))


func set_master_volume(v: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(v, 0.0001, 1.0)))


## Plays an effect at a world position (3D) or, with `at` = null, flat.
func play(sound: StringName, at: Variant = null, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var variants: Array = _streams.get(sound, [])
	if variants.is_empty():
		return
	var stream: AudioStream = variants[_rng.randi() % variants.size()]
	var jitter := _rng.randf_range(0.94, 1.06)
	if at is Vector3:
		var p := _pool3d[_next3d]
		_next3d = (_next3d + 1) % POOL_3D
		p.stream = stream
		p.global_position = at
		p.volume_db = volume_db
		p.pitch_scale = pitch * jitter
		p.play()
	else:
		var p := _pool2d[_next2d]
		_next2d = (_next2d + 1) % POOL_2D
		p.stream = stream
		p.volume_db = volume_db
		p.pitch_scale = pitch
		p.play()


# ------------------------------------------------------------- synthesis

func _build() -> void:
	_rng.seed = 1234
	_add("swing", [_whoosh(0.22, 700.0, 2600.0, 0.9), _whoosh(0.2, 900.0, 3200.0, 0.85), _whoosh(0.24, 600.0, 2200.0, 0.95)])
	_add("swing_heavy", [_whoosh(0.4, 300.0, 1500.0, 1.0)])
	_add("throw", [_whoosh(0.3, 500.0, 2800.0, 0.8)])
	_add("hit", [_thump(0.2, 110.0, 55.0, 0.5), _thump(0.18, 130.0, 60.0, 0.6), _thump(0.22, 95.0, 50.0, 0.55)])
	_add("hit_heavy", [_thump(0.38, 80.0, 34.0, 0.9)])
	_add("clang", [_metal(0.45, [520.0, 1310.0, 2150.0, 3390.0]), _metal(0.4, [610.0, 1490.0, 2480.0, 3720.0])])
	_add("catch", [_chirp(0.09, 700.0, 1500.0, 0.5, true)])
	_add("land", [_thump(0.16, 70.0, 40.0, 0.35)])
	_add("death", [_thump(0.5, 60.0, 28.0, 1.0)])
	_add("pickup", [_notes([1046.5, 1568.0], 0.07, 0.5)])
	_add("kill", [_notes([783.99, 1174.66, 1567.98], 0.08, 0.55)])
	_add("ui_click", [_chirp(0.03, 2200.0, 1800.0, 0.35, false)])
	_add("ui_confirm", [_notes([880.0, 1318.5], 0.06, 0.4)])
	_add("beep", [_notes([880.0], 0.13, 0.45)])
	_add("go", [_notes([1318.5], 0.4, 0.5)])
	_add("tick", [_chirp(0.025, 3000.0, 2600.0, 0.3, false)])
	_add("buzzer", [_buzz(0.9, 196.0)])
	_add("respawn", [_chirp(0.3, 300.0, 1000.0, 0.4, false)])
	_add("crash_wood", [_crash(0.45, 900.0, 0.8, true), _crash(0.4, 1100.0, 0.75, true)])
	_add("crash_stone", [_crash(0.6, 500.0, 0.9, false)])
	_add("boom", [_boom(1.1)])
	_add("squeak", [_squeak(0.22), _squeak(0.18)])
	_add("splash", [_crash(0.7, 2200.0, 0.75, false), _crash(0.6, 2600.0, 0.7, false)])
	_add("chomp", [_thump(0.14, 160.0, 70.0, 0.9), _crash(0.25, 700.0, 0.8, true)])
	_add("cannon", [_boom(0.8)])
	_add("alarm", [_buzz(0.5, 330.0)])
	_add("clunk", [_metal(0.5, [180.0, 410.0, 760.0, 1210.0])])
	_add("shot", [_crash(0.35, 5000.0, 0.9, false)])
	_add("zap", [_zap(0.45)])
	_add("strum", [_notes([196.0, 246.9, 293.7, 392.0], 0.05, 0.5)])
	# Recorded replacements win where present.
	for sound_name: String in _streams.keys():
		for ext in ["ogg", "wav"]:
			var path := "res://assets/audio/sfx/%s.%s" % [sound_name, ext]
			if ResourceLoader.exists(path):
				_streams[sound_name] = [load(path)]


func _add(sound: String, samples_list: Array) -> void:
	var out: Array = []
	for samples: PackedFloat32Array in samples_list:
		out.append(_to_wav(samples))
	_streams[StringName(sound)] = out


func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w


func _env(t: float, length: float, attack: float) -> float:
	if t < attack:
		return t / attack
	return pow(1.0 - (t - attack) / maxf(length - attack, 0.001), 2.0)


## Air rushing past a blade: noise through a band-pass that sweeps up and down.
func _whoosh(length: float, f_lo: float, f_hi: float, gain: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var low := 0.0
	var band := 0.0
	for i in n:
		var t := float(i) / RATE
		var u := t / length
		var f := lerpf(f_lo, f_hi, sin(PI * u))
		var fc := 2.0 * sin(PI * f / RATE)
		var x := _rng.randf_range(-1.0, 1.0)
		low += fc * band
		var high := x - low - 0.6 * band
		band += fc * high
		out[i] = band * gain * 0.9 * _env(t, length, length * 0.35)
	return out


## A body hit: a falling sine "thump" plus a short burst of filtered noise.
func _thump(length: float, f0: float, f1: float, gain: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(f0, f1, minf(t / length * 2.0, 1.0))
		phase += TAU * f / RATE
		var body := sin(phase) * exp(-t * 14.0)
		lp += 0.25 * (_rng.randf_range(-1.0, 1.0) - lp)
		var crack := lp * exp(-t * 60.0) * 1.4
		out[i] = tanh((body + crack) * 1.6) * gain
	return out


## Metal: inharmonic partials that ring out.
func _metal(length: float, partials: Array) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		for k in partials.size():
			var f: float = partials[k]
			s += sin(TAU * f * t) * exp(-t * (6.0 + k * 4.0)) / (1.0 + k * 0.6)
		s += _rng.randf_range(-1.0, 1.0) * exp(-t * 90.0) * 0.6
		out[i] = s * 0.45
	return out


func _chirp(length: float, f0: float, f1: float, gain: float, click: bool) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += TAU * lerpf(f0, f1, t / length) / RATE
		var s := sin(phase) * _env(t, length, 0.004)
		if click and t < 0.006:
			s += _rng.randf_range(-1.0, 1.0)
		out[i] = s * gain
	return out


func _notes(freqs: Array, each: float, gain: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for f: float in freqs:
		var n := int(each * RATE)
		for i in n:
			var t := float(i) / RATE
			var s := (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t)) * _env(t, each, 0.005)
			out.append(s * gain)
	return out


func _buzz(length: float, f: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := f * (1.0 + 0.02 * sin(TAU * 6.0 * t))
		var s := signf(sin(TAU * v * t)) * 0.5 + sin(TAU * v * 2.0 * t) * 0.3
		out[i] = s * 0.35 * _env(t, length, 0.01)
	return out


## Something smashing: a burst of filtered noise, with wood clacks or a stony rumble.
func _crash(length: float, cutoff: float, gain: float, wood: bool) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var a := clampf(TAU * cutoff / RATE, 0.0, 1.0)
	var clack_at: Array[int] = []
	if wood:
		for k in 5:
			clack_at.append(int(_rng.randf_range(0.0, length * 0.6) * RATE))
	for i in n:
		var t := float(i) / RATE
		lp += a * (_rng.randf_range(-1.0, 1.0) - lp)
		var s := lp * 2.2 * exp(-t * (7.0 if wood else 5.0))
		s += sin(TAU * (70.0 if wood else 45.0) * t) * exp(-t * 18.0) * 0.6
		for c in clack_at:
			var dt := i - c
			if dt >= 0 and dt < 400:
				s += sin(TAU * 1400.0 * float(dt) / RATE) * exp(-float(dt) / 60.0) * 0.5
		out[i] = tanh(s * 1.4) * gain
	return out


## An explosion: deep thump plus a long noisy roar.
func _boom(length: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += 0.08 * (_rng.randf_range(-1.0, 1.0) - lp)
		phase += TAU * lerpf(60.0, 28.0, minf(t * 2.0, 1.0)) / RATE
		var s := sin(phase) * exp(-t * 4.0) * 1.2 + lp * 3.0 * exp(-t * 3.0)
		out[i] = tanh(s * 1.8) * 0.9
	return out


## Electricity: crackling noise bursts over a falling buzz.
func _zap(length: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += TAU * lerpf(900.0, 120.0, t / length) / RATE
		var crackle := _rng.randf_range(-1.0, 1.0) * (1.0 if _rng.randf() < 0.3 else 0.15)
		var s := (signf(sin(phase)) * 0.35 + crackle) * exp(-t * 6.0)
		out[i] = tanh(s * 1.5) * 0.8
	return out


## A rubber chicken: a wobbling squeal that rises and falls.
func _squeak(length: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var u := t / length
		var f := 900.0 + 900.0 * sin(PI * u) + 60.0 * sin(TAU * 38.0 * t)
		phase += TAU * f / RATE
		var s := (sin(phase) + 0.4 * sin(phase * 2.0)) * _env(t, length, 0.01)
		out[i] = s * 0.45
	return out
