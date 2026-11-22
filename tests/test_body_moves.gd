extends GutTest
## The body never gets stuck on a move: one-off moves hand back to
## locomotion by themselves (regression: fighters slid around frozen after
## a jump or dodge roll, most visibly when unarmed).

var body: BlockBody


func before_each() -> void:
	body = BlockBody.new()
	add_child_autofree(body)
	body.setup(Registry.skin(0))


func test_one_off_moves_return_to_locomotion() -> void:
	for clip: StringName in [&"Dodge_Roll", &"Jump_Start", &"Land", &"Double_Jump"]:
		body.play(clip)
		assert_eq(body.action, clip)
		await wait_seconds(BlockBody.move_length(clip) + 0.35)
		assert_true(body.action_over(), "%s finished" % clip)
		assert_eq(String(body.tree.get(&"parameters/act/current_state")), "loco", "%s back to locomotion" % clip)


func test_unarmed_locomotion_moves_the_legs() -> void:
	body.set_loco(&"Run", 1.0)
	await wait_seconds(0.3)
	var sk := body.skeleton
	var leg := sk.find_bone(&"LeftUpperLeg")
	var seen: Array[float] = []
	for i in 12:
		await wait_physics_frames(3)
		seen.append(sk.get_bone_pose(leg).basis.get_euler().x)
	assert_gt(seen.max() - seen.min(), 0.4, "the running legs swing")
