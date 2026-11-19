class_name BattleSchoolMotifs
extends RefCounted

## 战斗绝招 (DECISIONS「战斗绝招」): the figure a school's special leaves where its blow lands — a
## few glowing blocks in the school's colour (battle_stage.json `schools`: each skill its colour
## and one of the KINDS), built here and moved by a tween of the fight's show:
## - ring: a ring of blocks spreading over the ground round the one struck (a weight pressed down);
## - pillars: bars of light dropping round them and standing a moment (封: shut in);
## - petals: flakes drifting down about them (snow, blossom);
## - shards: slivers bursting out from the chest (a claw's marks, a cut that scatters);
## - wave: a row of blocks sweeping along the blow's way, over the ground (a wind);
## - slips: paper slips circling them, then flying off upward (a 道士's talismans).
## Presentation only: no body, no rule, no draw of the game's own.

const KINDS: Array[String] = ["ring", "pillars", "petals", "shards", "wave", "slips"]


## The motif `kind` in `colour` built under `parent` at `at` (the parent's space: the feet of the
## one struck), the blow going `toward`, and its `seconds` of motion laid on `tween` (a parallel
## one; the caller ends it and frees the node). `rng`: the show's own stream.
static func play(parent: Node3D, tween: Tween, kind: String, colour: Color, at: Vector3, toward: Vector3, seconds: float, rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.name = "Motif"
	root.position = at
	parent.add_child(root)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color(colour, 0.9)
	glow.render_priority = VoxelBackdrop.OVER_BACKDROP
	var side := Vector3(-toward.z, 0.0, toward.x)
	match kind:
		"pillars":
			for index: int in 5:
				var angle: float = TAU * float(index) / 5.0 + rng.randf_range(-0.2, 0.2)
				var foot := Vector3(cos(angle) * 0.62, 0.0, sin(angle) * 0.62)
				var bar: MeshInstance3D = _block(root, glow, Vector3(0.07, 1.9, 0.07), foot + Vector3.UP * 3.2)
				tween.tween_property(bar, "position", foot + Vector3.UP * 0.95, seconds * 0.28).set_delay(seconds * 0.05 * index).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
				tween.tween_property(bar, "scale", Vector3(0.2, 1.0, 0.2), seconds * 0.3).set_delay(seconds * 0.7)
		"petals":
			for index: int in 10:
				var from := Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(1.6, 2.4), rng.randf_range(-0.8, 0.8))
				var flake: MeshInstance3D = _block(root, glow, Vector3.ONE * rng.randf_range(0.06, 0.1), from)
				flake.rotation = Vector3(rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU), 0.0)
				var drift := Vector3(rng.randf_range(-0.35, 0.35), -from.y + 0.05, rng.randf_range(-0.35, 0.35))
				tween.tween_property(flake, "position", from + drift, seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
				tween.tween_property(flake, "rotation:x", flake.rotation.x + TAU, seconds)
				tween.tween_property(flake, "scale", Vector3.ONE * 0.2, seconds * 0.35).set_delay(seconds * 0.65)
		"shards":
			for index: int in 8:
				var angle: float = TAU * float(index) / 8.0 + rng.randf_range(-0.25, 0.25)
				var out := (side * cos(angle) + Vector3.UP * sin(angle)).normalized()
				var shard: MeshInstance3D = _block(root, glow, Vector3(0.05, 0.05, 0.42), Vector3.UP * 1.0 + out * 0.2)
				shard.look_at_from_position(shard.position, shard.position + out + toward * 0.25, Vector3.UP if absf(out.y) < 0.95 else Vector3.RIGHT)
				tween.tween_property(shard, "position", Vector3.UP * 1.0 + out * rng.randf_range(0.9, 1.3) + toward * 0.3, seconds * 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
				tween.tween_property(shard, "scale", Vector3(0.3, 0.3, 0.1), seconds * 0.5).set_delay(seconds * 0.5)
		"wave":
			for index: int in 7:
				var across: float = (float(index) - 3.0) * 0.22
				var start: Vector3 = -toward * 0.9 + side * across + Vector3.UP * 0.12
				var crest: MeshInstance3D = _block(root, glow, Vector3(0.16, 0.24 + 0.1 * (3.0 - absf(float(index) - 3.0)), 0.1), start)
				tween.tween_property(crest, "position", start + toward * 2.2, seconds * 0.8).set_delay(seconds * 0.02 * absf(float(index) - 3.0)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
				tween.tween_property(crest, "scale", Vector3(1.0, 0.1, 1.0), seconds * 0.35).set_delay(seconds * 0.65)
		"slips":
			for index: int in 6:
				var angle: float = TAU * float(index) / 6.0
				var hub := Node3D.new()
				hub.rotation.y = angle
				root.add_child(hub)
				var slip: MeshInstance3D = _block(hub, glow, Vector3(0.1, 0.24, 0.02), Vector3(0.7, 0.9 + 0.12 * (index % 3), 0.0))
				tween.tween_property(hub, "rotation:y", angle + TAU * 0.75, seconds * 0.7).set_ease(Tween.EASE_OUT)
				tween.tween_property(slip, "position", Vector3(0.25, 2.6, 0.0), seconds * 0.3).set_delay(seconds * 0.7).set_ease(Tween.EASE_IN)
				tween.tween_property(slip, "scale", Vector3.ONE * 0.2, seconds * 0.3).set_delay(seconds * 0.7)
		_:
			for index: int in 12:
				var angle: float = TAU * float(index) / 12.0
				var out := Vector3(cos(angle), 0.0, sin(angle))
				var stone: MeshInstance3D = _block(root, glow, Vector3(0.13, 0.1, 0.13), out * 0.25 + Vector3.UP * 0.07)
				tween.tween_property(stone, "position", out * 1.15 + Vector3.UP * 0.07, seconds * 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
				tween.tween_property(stone, "scale", Vector3(1.0, 0.15, 1.0), seconds * 0.4).set_delay(seconds * 0.6)
	tween.tween_property(glow, "albedo_color:a", 0.0, seconds * 0.4).set_delay(seconds * 0.6)
	return root


static func _block(parent: Node3D, material: Material, size: Vector3, at: Vector3) -> MeshInstance3D:
	var block := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	block.mesh = mesh
	block.material_override = material
	block.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	block.position = at
	parent.add_child(block)
	return block
