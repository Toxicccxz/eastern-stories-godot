class_name BattleArts
extends RefCounted

## 战斗运功 (DECISIONS「战斗运功」): what an exert function or a spell shows in the scene — a few
## glowing blocks built here and moved by a tween of the fight's show (battle_stage.json `arts`:
## each function its colour and one of the KINDS, as its ES2 lines tell it):
## - swirl: a spiral of 气 climbing round the body (恢复气 / 神 / 精: 深深吸了几口气);
## - mend: motes rising slowly through the one being healed (疗伤);
## - crown: 气 leaving the body and gathering over the head, then fading (灵神诀: 一股青气从身上
##   散出，汇聚在顶心，然後缓缓淡去);
## - surge: sparks popping all over the body and tongues of 气 leaping up from the feet (提升
##   战斗力: 全身骨节发出一阵爆豆般的声响);
## - sink: the 气 about the body settling down into the ground (压制杀气: 收敛自己的杀气);
## - roar: rings of sound spreading from the mouth (天邪虎啸);
## - gaze: two thin lines from the eyes to the one stared at, frost on them when it took (意寒睨);
## - bolt: a ball of light gathered in the hand, flown through the one aimed at (紫光 / 白光 /
##   青光: 透体而过): gone home, a streak dragged out of them into the ground beyond, and for one
##   that `returns` the light comes back into the caster's crown; missed, it sinks into the
##   ground without a sound;
## - descend: a shaft of light coming down beside the caster (召天将);
## - chant: paper slips circling the caster and flying up (a spell that only says its words);
## - vanish: a burst of smoke where the caster stood (遁).
## Presentation only: no body, no rule, no draw of the game's own.

const KINDS: Array[String] = ["swirl", "mend", "crown", "surge", "sink", "roar", "gaze", "bolt", "descend", "chant", "vanish"]
## How far into its `seconds` a kind reaches the one it is aimed at (0: it never does).
const REACHES: Dictionary[String, float] = {"bolt": 0.55, "gaze": 0.25}


## The art `kind` in `colour` built under `parent` — `at` the feet of the one who does it, `to`
## the feet of the one it is aimed at (`at` itself when it has no aim), both in the parent's
## space — and its `seconds` of motion laid on `tween` (a parallel one; the caller ends it and
## frees the node). `landed`: it took. `look`: the art's own data (`streak`: the colour of what a
## bolt drags out, `returns`: the light comes back to the caster). `rng`: the show's own stream.
static func play(parent: Node3D, tween: Tween, kind: String, colour: Color, at: Vector3, to: Vector3, seconds: float, rng: RandomNumberGenerator, landed: bool = true, look: Dictionary = {}) -> Node3D:
	if kind == "chant":
		return BattleSchoolMotifs.play(parent, tween, "slips", colour, at, Vector3.FORWARD, seconds, rng)
	var root := Node3D.new()
	root.name = "Art"
	root.position = at
	parent.add_child(root)
	var glow: StandardMaterial3D = _glow(colour, 0.9)
	var aim: Vector3 = to - at
	var way: Vector3 = Vector3(aim.x, 0.0, aim.z).normalized() if Vector2(aim.x, aim.z).length_squared() > 0.0001 else Vector3.FORWARD
	match kind:
		"mend":
			for index: int in 10:
				var angle: float = rng.randf_range(0.0, TAU)
				var from := Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(0.2, 0.5) + Vector3.UP * rng.randf_range(0.15, 0.9)
				var mote: MeshInstance3D = _block(root, glow, Vector3.ONE * rng.randf_range(0.05, 0.09), from)
				mote.scale = Vector3.ONE * 0.2
				var delay: float = seconds * 0.04 * index
				tween.tween_property(mote, "scale", Vector3.ONE, seconds * 0.2).set_delay(delay)
				tween.tween_property(mote, "position", from + Vector3.UP * rng.randf_range(0.8, 1.2), seconds * 0.6).set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		"crown":
			var top := Vector3.UP * 2.05
			for index: int in 9:
				var angle: float = TAU * float(index) / 9.0
				var from := Vector3(cos(angle) * 0.2, rng.randf_range(0.7, 1.3), sin(angle) * 0.2)
				var out := Vector3(cos(angle) * 0.6, from.y + 0.15, sin(angle) * 0.6)
				var wisp: MeshInstance3D = _block(root, glow, Vector3.ONE * 0.08, from)
				tween.tween_property(wisp, "position", out, seconds * 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
				tween.tween_property(wisp, "position", top, seconds * 0.3).set_delay(seconds * 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
				tween.tween_property(wisp, "scale", Vector3.ONE * 0.3, seconds * 0.15).set_delay(seconds * 0.5)
			var orb: MeshInstance3D = _block(root, glow, Vector3.ONE * 0.2, top)
			orb.scale = Vector3.ONE * 0.05
			tween.tween_property(orb, "scale", Vector3.ONE, seconds * 0.2).set_delay(seconds * 0.45).set_ease(Tween.EASE_OUT)
			tween.tween_property(orb, "scale", Vector3.ONE * 0.4, seconds * 0.35).set_delay(seconds * 0.65)
		"surge":
			for index: int in 12:
				var angle: float = rng.randf_range(0.0, TAU)
				var spot := Vector3(cos(angle) * 0.36, rng.randf_range(0.35, 1.7), sin(angle) * 0.36)
				var spark: MeshInstance3D = _block(root, glow, Vector3.ONE * 0.1, spot)
				spark.scale = Vector3.ONE * 0.01
				var delay: float = seconds * 0.045 * index
				tween.tween_property(spark, "scale", Vector3.ONE * 1.3, seconds * 0.06).set_delay(delay)
				tween.tween_property(spark, "scale", Vector3.ONE * 0.01, seconds * 0.1).set_delay(delay + seconds * 0.06)
			for index: int in 7:
				var angle: float = TAU * float(index) / 7.0
				var foot := Vector3(cos(angle) * 0.5, 0.1, sin(angle) * 0.5)
				var tongue: MeshInstance3D = _block(root, glow, Vector3(0.09, 0.5, 0.09), foot)
				tongue.scale = Vector3(1.0, 0.1, 1.0)
				var delay: float = seconds * 0.35 + seconds * 0.02 * index
				tween.tween_property(tongue, "scale", Vector3(1.0, 1.6, 1.0), seconds * 0.25).set_delay(delay).set_ease(Tween.EASE_OUT)
				tween.tween_property(tongue, "position", foot + Vector3.UP * 1.5, seconds * 0.5).set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		"sink":
			for index: int in 10:
				var angle: float = TAU * float(index) / 10.0
				var out := Vector3(cos(angle), 0.0, sin(angle))
				var from: Vector3 = out * 0.62 + Vector3.UP * rng.randf_range(1.2, 1.8)
				var veil: MeshInstance3D = _block(root, glow, Vector3(0.1, 0.3, 0.1), from)
				tween.tween_property(veil, "position", out * 0.38 + Vector3.UP * 0.05, seconds * 0.7).set_delay(seconds * 0.02 * index).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
				tween.tween_property(veil, "scale", Vector3(1.0, 0.1, 1.0), seconds * 0.3).set_delay(seconds * 0.6)
		"roar":
			for ring: int in 3:
				for index: int in 14:
					var angle: float = TAU * float(index) / 14.0 + 0.2 * ring
					var out := Vector3(cos(angle), 0.0, sin(angle))
					var mouth: Vector3 = Vector3.UP * 1.45 + way * 0.15
					var note: MeshInstance3D = _block(root, glow, Vector3(0.11, 0.2, 0.11), mouth + out * 0.25)
					note.scale = Vector3.ONE * 0.01
					var delay: float = seconds * 0.16 * ring
					tween.tween_property(note, "scale", Vector3.ONE, seconds * 0.05).set_delay(delay)
					tween.tween_property(note, "position", mouth + out * 2.3 - Vector3.UP * 0.5, seconds * 0.5).set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
					tween.tween_property(note, "scale", Vector3(0.6, 0.1, 0.6), seconds * 0.25).set_delay(delay + seconds * 0.3)
		"gaze":
			var eyes: Vector3 = Vector3.UP * 1.55 + way * 0.2
			var theirs: Vector3 = aim + Vector3.UP * 1.5
			var reach: float = maxf(0.3, eyes.distance_to(theirs))
			var side := Vector3(-way.z, 0.0, way.x)
			for eye: int in 2:
				var hub := Node3D.new()
				hub.position = eyes + side * (0.07 if eye == 0 else -0.07)
				root.add_child(hub)
				hub.basis = Basis.looking_at((theirs - eyes).normalized(), Vector3.UP)
				_block(hub, glow, Vector3(0.025, 0.025, reach), Vector3(0, 0, -reach * 0.5))
				hub.scale = Vector3(1.0, 1.0, 0.02)
				tween.tween_property(hub, "scale", Vector3.ONE, seconds * REACHES["gaze"]).set_ease(Tween.EASE_OUT)
				tween.tween_property(hub, "scale", Vector3(0.2, 0.2, 1.0), seconds * 0.3).set_delay(seconds * 0.7)
			if landed:
				for index: int in 7:
					var angle: float = TAU * float(index) / 7.0
					var out := Vector3(cos(angle) * 0.32, rng.randf_range(0.5, 1.6), sin(angle) * 0.32)
					var chip: MeshInstance3D = _block(root, glow, Vector3.ONE * 0.07, aim + out)
					chip.scale = Vector3.ONE * 0.01
					tween.tween_property(chip, "scale", Vector3.ONE, seconds * 0.1).set_delay(seconds * REACHES["gaze"] + seconds * 0.03 * index)
					tween.tween_property(chip, "position", aim + out + Vector3.DOWN * 0.25, seconds * 0.4).set_delay(seconds * 0.5)
		"bolt":
			var side := Vector3(-way.z, 0.0, way.x)
			var hand: Vector3 = Vector3.UP * 1.25 + way * 0.45 + side * 0.18
			var chest: Vector3 = aim + Vector3.UP * 1.0
			var gather: float = seconds * 0.3
			var flight: float = seconds * (REACHES["bolt"] - 0.3)
			var ball := Node3D.new()
			ball.position = hand
			root.add_child(ball)
			_block(ball, _glow(colour.lightened(0.6), 0.95), Vector3.ONE * 0.15, Vector3.ZERO)
			var shell: MeshInstance3D = _block(ball, _glow(colour, 0.5), Vector3.ONE * 0.3, Vector3.ZERO)
			shell.rotation = Vector3(0.6, 0.8, 0.0)
			ball.scale = Vector3.ONE * 0.1
			tween.tween_property(ball, "scale", Vector3.ONE, gather).set_ease(Tween.EASE_OUT)
			tween.tween_property(shell, "rotation:y", 0.8 + TAU * 2.0, seconds)
			tween.tween_property(ball, "position", chest, flight).set_delay(gather).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			# The motes drawn into the hand while it gathers.
			for index: int in 6:
				var angle: float = TAU * float(index) / 6.0
				var mote: MeshInstance3D = _block(root, glow, Vector3.ONE * 0.05, hand + Vector3(cos(angle), sin(angle), 0.0).rotated(Vector3.UP, atan2(way.x, way.z)) * 0.45)
				tween.tween_property(mote, "position", hand, gather).set_ease(Tween.EASE_IN)
				tween.tween_property(mote, "scale", Vector3.ONE * 0.1, gather)
			var passed: float = seconds * REACHES["bolt"]
			var beyond: Vector3 = aim + way * 1.7 + Vector3.UP * 0.04
			if landed:
				# Through them, and what it drags out goes into the ground beyond.
				tween.tween_property(ball, "position", beyond, seconds * 0.2).set_delay(passed).set_ease(Tween.EASE_OUT)
				tween.tween_property(ball, "scale", Vector3.ONE * 0.1, seconds * 0.2).set_delay(passed)
				var streak_glow: StandardMaterial3D = _glow(Color(String(look.get("streak", colour.to_html(false)))), 0.85)
				var reach: float = chest.distance_to(beyond)
				var hub := Node3D.new()
				hub.position = chest
				root.add_child(hub)
				hub.basis = Basis.looking_at((beyond - chest).normalized(), Vector3.UP)
				_block(hub, streak_glow, Vector3(0.05, 0.05, reach), Vector3(0, 0, -reach * 0.5))
				hub.scale = Vector3(1.0, 1.0, 0.01)
				tween.tween_property(hub, "scale", Vector3.ONE, seconds * 0.15).set_delay(passed).set_ease(Tween.EASE_OUT)
				tween.tween_property(hub, "scale", Vector3(0.1, 0.1, 1.0), seconds * 0.25).set_delay(passed + seconds * 0.2)
				tween.tween_property(streak_glow, "albedo_color:a", 0.0, seconds * 0.25).set_delay(passed + seconds * 0.2)
				if bool(look.get("returns", false)):
					# 光气绕了回转过来又从顶门注入体内: back over their heads into the caster's crown.
					for index: int in 5:
						var mote: MeshInstance3D = _block(root, streak_glow, Vector3.ONE * 0.07, beyond)
						mote.scale = Vector3.ONE * 0.01
						var delay: float = passed + seconds * 0.15 + seconds * 0.025 * index
						tween.tween_property(mote, "scale", Vector3.ONE, seconds * 0.05).set_delay(delay)
						tween.tween_method(_arc.bind(mote, beyond, Vector3.UP * 2.0, 1.4), 0.0, 1.0, seconds * 0.28).set_delay(delay)
			else:
				# 无声无息地钻入地下.
				tween.tween_property(ball, "position", aim + way * 0.7 - Vector3.UP * 0.2, seconds * 0.2).set_delay(passed)
				tween.tween_property(ball, "scale", Vector3.ONE * 0.05, seconds * 0.2).set_delay(passed)
		"descend":
			var side := Vector3(-way.z, 0.0, way.x)
			var foot: Vector3 = side * 0.95 + way * 0.2
			var shaft: MeshInstance3D = _block(root, _glow(colour, 0.45), Vector3(0.5, 4.4, 0.5), foot + Vector3.UP * 7.0)
			tween.tween_property(shaft, "position", foot + Vector3.UP * 2.2, seconds * 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			tween.tween_property(shaft, "scale", Vector3(0.1, 1.0, 0.1), seconds * 0.35).set_delay(seconds * 0.65)
			for index: int in 10:
				var angle: float = TAU * float(index) / 10.0
				var out := Vector3(cos(angle), 0.0, sin(angle))
				var stone: MeshInstance3D = _block(root, glow, Vector3(0.11, 0.09, 0.11), foot + out * 0.2 + Vector3.UP * 0.06)
				stone.scale = Vector3.ONE * 0.01
				tween.tween_property(stone, "scale", Vector3.ONE, seconds * 0.05).set_delay(seconds * 0.3)
				tween.tween_property(stone, "position", foot + out * 0.95 + Vector3.UP * 0.06, seconds * 0.45).set_delay(seconds * 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		"vanish":
			for index: int in 14:
				var angle: float = rng.randf_range(0.0, TAU)
				var from := Vector3(cos(angle) * 0.15, rng.randf_range(0.2, 1.6), sin(angle) * 0.15)
				var puff: MeshInstance3D = _block(root, glow, Vector3.ONE * rng.randf_range(0.16, 0.28), from)
				tween.tween_property(puff, "position", from + Vector3(cos(angle) * 0.7, rng.randf_range(0.3, 0.9), sin(angle) * 0.7), seconds * 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
				tween.tween_property(puff, "scale", Vector3.ONE * 1.8, seconds * 0.8).set_ease(Tween.EASE_OUT)
		_:
			# swirl: each block on a hub turning about the body, climbing as it turns.
			for index: int in 14:
				var angle: float = TAU * float(index) / 7.0
				var hub := Node3D.new()
				hub.rotation.y = angle
				root.add_child(hub)
				var low := Vector3(0.62, 0.08 + 0.03 * index, 0.0)
				var wisp: MeshInstance3D = _block(hub, glow, Vector3(0.08, 0.08, 0.16), low)
				wisp.scale = Vector3.ONE * 0.01
				var delay: float = seconds * 0.025 * index
				tween.tween_property(wisp, "scale", Vector3.ONE, seconds * 0.08).set_delay(delay)
				tween.tween_property(hub, "rotation:y", angle + TAU * 1.4, seconds * 0.85).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
				tween.tween_property(wisp, "position", Vector3(0.26, 1.85, 0.0), seconds * 0.6).set_delay(delay).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
				tween.tween_property(wisp, "scale", Vector3.ONE * 0.2, seconds * 0.2).set_delay(seconds * 0.75)
	tween.tween_property(glow, "albedo_color:a", 0.0, seconds * 0.3).set_delay(seconds * 0.7)
	return root


## One moment `t` (0..1) of a mote's way from `from` to `to` over an arc `height` high (`mote`
## may be gone with the fight by then).
static func _arc(t: float, mote: Variant, from: Vector3, to: Vector3, height: float) -> void:
	if is_instance_valid(mote):
		(mote as Node3D).position = from.lerp(to, t) + Vector3.UP * height * sin(t * PI)


static func _glow(colour: Color, alpha: float) -> StandardMaterial3D:
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color(colour, alpha)
	glow.render_priority = VoxelBackdrop.OVER_BACKDROP
	return glow


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
