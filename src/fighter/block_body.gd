class_name BlockBody
extends Node3D
## A block fighter's body: the rig and moves from block_fighter.glb (made
## in Blender by tools/blender/build_fighter.py), one skinned box mesh built
## from SkinData (a single draw call per fighter), the animation tree, the
## weapon socket and the ragdoll.
##
## Animation tree:
##   loco (crossfade between loops) -> loco_speed -> upper (upper-body
##   one-shot: attack while the legs keep running) -> act (crossfade to any
##   full-body move and back) -> output

const RIG := preload("res://assets/fighters/block_fighter.glb")
const MOVES_JSON := "res://assets/fighters/block_fighter.moves.json"

## bone, size, centre (model space, metres; the fighter faces +Z), colour role
const PARTS := [
	[&"Hips", Vector3(0.34, 0.16, 0.22), Vector3(0, 0.98, 0), &"pants"],
	[&"Spine", Vector3(0.31, 0.14, 0.2), Vector3(0, 1.12, 0), &"belt"],
	[&"Chest", Vector3(0.37, 0.16, 0.23), Vector3(0, 1.26, 0), &"shirt"],
	[&"UpperChest", Vector3(0.44, 0.17, 0.25), Vector3(0, 1.4, 0), &"shirt"],
	[&"Neck", Vector3(0.11, 0.1, 0.11), Vector3(0, 1.52, 0), &"skin"],
	[&"LeftUpperArm", Vector3(0.26, 0.12, 0.12), Vector3(0.32, 1.44, 0), &"shirt"],
	[&"LeftLowerArm", Vector3(0.25, 0.1, 0.1), Vector3(0.59, 1.44, 0), &"sleeve"],
	[&"LeftHand", Vector3(0.12, 0.11, 0.11), Vector3(0.78, 1.44, 0), &"skin"],
	[&"RightUpperArm", Vector3(0.26, 0.12, 0.12), Vector3(-0.32, 1.44, 0), &"shirt"],
	[&"RightLowerArm", Vector3(0.25, 0.1, 0.1), Vector3(-0.59, 1.44, 0), &"sleeve"],
	[&"RightHand", Vector3(0.12, 0.11, 0.11), Vector3(-0.78, 1.44, 0), &"skin"],
	[&"LeftUpperLeg", Vector3(0.15, 0.42, 0.15), Vector3(0.11, 0.73, 0), &"pants"],
	[&"LeftLowerLeg", Vector3(0.13, 0.42, 0.13), Vector3(0.11, 0.31, 0), &"pants"],
	[&"LeftFoot", Vector3(0.13, 0.09, 0.24), Vector3(0.11, 0.05, 0.05), &"shoes"],
	[&"RightUpperLeg", Vector3(0.15, 0.42, 0.15), Vector3(-0.11, 0.73, 0), &"pants"],
	[&"RightLowerLeg", Vector3(0.13, 0.42, 0.13), Vector3(-0.11, 0.31, 0), &"pants"],
	[&"RightFoot", Vector3(0.13, 0.09, 0.24), Vector3(-0.11, 0.05, 0.05), &"shoes"],
]
const HEAD_ORIGIN := Vector3(0, 1.58, 0)

## Loops the locomotion layer can hold.
const LOCO: Array[StringName] = [&"Idle", &"Sword_Idle", &"Walk", &"Walk_Sword", &"Run", &"Run_Sword",
	&"Sprint", &"Sprint_Sword", &"Strafe_L", &"Strafe_L_Sword", &"Strafe_R", &"Strafe_R_Sword",
	&"Backpedal", &"Backpedal_Sword", &"Fall", &"Heavy_Charge", &"Victory"]
## Bones an upper-body move drives.
const UPPER: Array[StringName] = [&"Spine", &"Chest", &"UpperChest", &"Neck", &"Head",
	&"LeftShoulder", &"LeftUpperArm", &"LeftLowerArm", &"LeftHand", &"WeaponL",
	&"RightShoulder", &"RightUpperArm", &"RightLowerArm", &"RightHand", &"WeaponR"]

static var _moves: Dictionary = {}

var skin: SkinData
var rig: Node3D
var skeleton: Skeleton3D
var anim: AnimationPlayer
var tree: AnimationTree
var mesh_instance: MeshInstance3D
var material: StandardMaterial3D
var socket_r: BoneAttachment3D
var ragdoll: Ragdoll

var loco := &""
var action := &""             # full-body or upper-body move playing
var action_upper := false
var action_time := 0.0        # seconds into the clip (clip time)
var action_speed := 1.0
var _flash := 0.0
var _act_nodes: Dictionary = {}
## Final bone poses (after the ragdoll), refreshed on every skeleton update.
var final_pose: Array = []
var keep_final_pose := false


static func moves() -> Dictionary:
	if _moves.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MOVES_JSON))
		_moves = (parsed as Dictionary)["moves"] if parsed is Dictionary else {}
	return _moves


static func move_info(clip: StringName) -> Dictionary:
	return moves().get(String(clip), {"length": 0.5, "loop": false, "events": {}, "speed": 0.0})


static func move_length(clip: StringName) -> float:
	return float(move_info(clip)["length"])


## The [start, end] hit window of a move, in clip seconds.
static func hit_window(clip: StringName) -> Vector2:
	var ev: Dictionary = move_info(clip)["events"]
	if ev.has("hit"):
		return Vector2(ev["hit"][0], ev["hit"][1])
	return Vector2(-1, -1)


static func event_time(clip: StringName, event: String) -> float:
	var ev: Dictionary = move_info(clip)["events"]
	return float(ev.get(event, -1.0))


func setup(skin_data: SkinData, with_tree: bool = true) -> void:
	skin = skin_data
	rig = RIG.instantiate() as Node3D
	add_child(rig)
	skeleton = rig.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	anim = rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for mi in skeleton.find_children("*", "MeshInstance3D", false, false):
		mi.queue_free()           # the Blender preview body
	_fix_loops()
	_build_mesh()
	skeleton.skeleton_updated.connect(_on_skeleton_updated)
	socket_r = BoneAttachment3D.new()
	socket_r.name = "SocketR"
	socket_r.bone_name = "WeaponR"
	skeleton.add_child(socket_r)
	if with_tree:
		_build_tree()
	else:
		anim.play(&"Sword_Idle")


func _fix_loops() -> void:
	for clip in anim.get_animation_list():
		var a := anim.get_animation(clip)
		a.loop_mode = Animation.LOOP_LINEAR if bool(move_info(clip)["loop"]) else Animation.LOOP_NONE


# ------------------------------------------------------------------ mesh

func _build_mesh() -> void:
	var b := BoxBuilder.new(true)
	var skin_res := Skin.new()
	var bind_of: Dictionary = {}
	var hs := skin.head_scale
	var bulk := skin.bulk

	var bind := func(bone: StringName) -> int:
		if not bind_of.has(bone):
			var idx := skeleton.find_bone(bone)
			bind_of[bone] = skin_res.get_bind_count()
			skin_res.add_named_bind(bone, skeleton.get_bone_global_rest(idx).affine_inverse())
		return bind_of[bone]

	for p: Array in PARTS:
		var size: Vector3 = p[1]
		if String(p[0]).contains("Arm"):        # arms run along X: thicken Y and Z
			size *= Vector3(1.0, bulk, bulk)
		elif p[0] != &"Neck":
			size *= Vector3(bulk, 1.0, bulk)
		b.box(size, p[2], skin.color(p[3]), bind.call(p[0]))
	# Head, face and hair: scaled about the head bone.
	var head: int = bind.call(&"Head")
	var h := func(v: Vector3) -> Vector3: return HEAD_ORIGIN + v * hs
	b.box(Vector3(0.3, 0.3, 0.3) * hs, h.call(Vector3(0, 0.14, 0.01)), skin.skin, head)
	var front := 0.01 + 0.15 + 0.008
	b.box(Vector3(0.055, 0.075, 0.018) * hs, h.call(Vector3(0.07, 0.16, front)), skin.eyes, head)
	b.box(Vector3(0.055, 0.075, 0.018) * hs, h.call(Vector3(-0.07, 0.16, front)), skin.eyes, head)
	b.box(Vector3(0.085, 0.02, 0.018) * hs, h.call(Vector3(0.072, 0.215, front)), skin.eyes, head, Basis(Vector3.BACK, -0.32))
	b.box(Vector3(0.085, 0.02, 0.018) * hs, h.call(Vector3(-0.072, 0.215, front)), skin.eyes, head, Basis(Vector3.BACK, 0.32))
	b.box(Vector3(0.1, 0.022, 0.018) * hs, h.call(Vector3(0, 0.07, front)), skin.eyes, head)
	b.box(Vector3(0.32, 0.07, 0.32) * hs, h.call(Vector3(0, 0.29, 0.0)), skin.shirt.darkened(0.35), head)   # headband / hair block
	material = BoxBuilder.vertex_color_material(0.7)
	material.emission_enabled = true
	material.emission = Color.BLACK
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Body"
	mesh_instance.mesh = b.commit(material)
	mesh_instance.skin = skin_res
	skeleton.add_child(mesh_instance)
	mesh_instance.skeleton = mesh_instance.get_path_to(skeleton)


# ------------------------------------------------------------------ tree

func _build_tree() -> void:
	var bt := AnimationNodeBlendTree.new()
	var loco_node := AnimationNodeTransition.new()
	loco_node.xfade_time = 0.16
	loco_node.input_count = LOCO.size()
	bt.add_node(&"loco", loco_node)
	for i in LOCO.size():
		loco_node.set_input_name(i, String(LOCO[i]))
		var a := AnimationNodeAnimation.new()
		a.animation = LOCO[i]
		bt.add_node(StringName("l_" + LOCO[i]), a)
		bt.connect_node(&"loco", i, StringName("l_" + LOCO[i]))
	bt.add_node(&"loco_speed", AnimationNodeTimeScale.new())
	bt.connect_node(&"loco_speed", 0, &"loco")

	var upper := AnimationNodeOneShot.new()
	upper.fadein_time = 0.08
	upper.fadeout_time = 0.18
	upper.filter_enabled = true
	var skel_path := String(rig.get_path_to(skeleton))
	for bone in UPPER:
		upper.set_filter_path(NodePath(skel_path + ":" + bone), true)
	bt.add_node(&"upper", upper)
	bt.add_node(&"upper_anim", AnimationNodeAnimation.new())
	bt.add_node(&"upper_ts", AnimationNodeTimeScale.new())
	bt.connect_node(&"upper_ts", 0, &"upper_anim")
	bt.connect_node(&"upper", 0, &"loco_speed")
	bt.connect_node(&"upper", 1, &"upper_ts")

	var acts: Array[StringName] = []
	for clip in anim.get_animation_list():
		if not LOCO.has(clip) and clip != &"RESET":
			acts.append(clip)
	var act := AnimationNodeTransition.new()
	act.xfade_time = 0.08
	act.allow_transition_to_self = true
	act.input_count = acts.size() + 1
	act.set_input_name(0, "loco")
	bt.add_node(&"act", act)
	bt.connect_node(&"act", 0, &"upper")
	for i in acts.size():
		var clip := acts[i]
		act.set_input_name(i + 1, String(clip))
		var a := AnimationNodeAnimation.new()
		a.animation = clip
		bt.add_node(StringName("a_" + clip), a)
		bt.add_node(StringName("ts_" + clip), AnimationNodeTimeScale.new())
		bt.connect_node(StringName("ts_" + clip), 0, StringName("a_" + clip))
		bt.connect_node(&"act", i + 1, StringName("ts_" + clip))
		_act_nodes[clip] = true
	bt.connect_node(&"output", 0, &"act")

	tree = AnimationTree.new()
	tree.name = "Tree"
	rig.add_child(tree)
	tree.anim_player = tree.get_path_to(anim)
	tree.root_node = tree.get_path_to(rig)
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	tree.tree_root = bt
	tree.active = true
	set_loco(&"Sword_Idle", 1.0)


## Holds a locomotion loop, scaled to `speed` (1 = the clip's own pace).
func set_loco(clip: StringName, speed: float = 1.0) -> void:
	if tree == null:
		if anim.current_animation != clip:
			anim.play(clip, 0.16)
		anim.speed_scale = speed
		return
	if clip != loco:
		loco = clip
		tree.set(&"parameters/loco/transition_request", String(clip))
	tree.set(&"parameters/loco_speed/scale", speed)


## Plays a move. `upper_only` keeps the legs on the locomotion layer.
func play(clip: StringName, upper_only: bool = false, speed: float = 1.0, fade: float = 0.08) -> void:
	if tree == null:
		anim.play(clip, fade)
		anim.speed_scale = speed
		action = clip
		action_time = 0.0
		action_speed = speed
		return
	action = clip
	action_upper = upper_only
	action_time = 0.0
	action_speed = speed
	if upper_only:
		(tree.tree_root.get_node(&"upper_anim") as AnimationNodeAnimation).animation = clip
		tree.set(&"parameters/upper_ts/scale", speed)
		tree.set(&"parameters/upper/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		if tree.get(&"parameters/act/current_state") != "loco":
			tree.set(&"parameters/act/transition_request", "loco")
	else:
		if not _act_nodes.has(clip):
			return
		(tree.tree_root.get_node(&"act") as AnimationNodeTransition).xfade_time = fade
		tree.set(StringName("parameters/ts_%s/scale" % clip), speed)
		tree.set(&"parameters/act/transition_request", String(clip))
		if tree.get(&"parameters/upper/active"):
			tree.set(&"parameters/upper/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)


## Back to locomotion.
func stop_action(fade: float = 0.15) -> void:
	action = &""
	if tree == null:
		return
	(tree.tree_root.get_node(&"act") as AnimationNodeTransition).xfade_time = fade
	if tree.get(&"parameters/act/current_state") != "loco":
		tree.set(&"parameters/act/transition_request", "loco")
	if tree.get(&"parameters/upper/active"):
		tree.set(&"parameters/upper/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)


## Advances the move clock; true once the move has finished.
func tick_action(delta: float) -> bool:
	if action == &"":
		return true
	action_time += delta * action_speed
	return action_time >= move_length(action)


func _on_skeleton_updated() -> void:
	if not keep_final_pose:
		return
	var n := skeleton.get_bone_count()
	if final_pose.size() != n:
		final_pose.resize(n)
	for i in n:
		final_pose[i] = skeleton.get_bone_global_pose(i)


func bone_index(bone: StringName) -> int:
	return skeleton.find_bone(bone)


func bone_global(bone: StringName) -> Transform3D:
	return skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone))


func bone_position(bone: StringName) -> Vector3:
	return bone_global(bone).origin


## White flash (spawn protection, hits).
func flash(amount: float) -> void:
	_flash = maxf(_flash, amount)


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 4.0, 0.0)
		material.emission = Color(1, 1, 1) * _flash * 0.8
	elif material and material.emission != Color.BLACK:
		material.emission = Color.BLACK


func build_ragdoll() -> Ragdoll:
	ragdoll = Ragdoll.new()
	ragdoll.build(skeleton, skin.head_scale)
	return ragdoll
