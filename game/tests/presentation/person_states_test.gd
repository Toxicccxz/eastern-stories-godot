extends RefCounted

## 状态挂在身上 (DECISIONS「战斗运功」): a figure wears its conditions for as long as they last —
## person_states.json's marks (each condition of daemon/condition/ a kind the library draws), an
## open wound's drip (stopped by a bandage), the stoop and the panting of one whose 气 is low, the
## rocking of one drunk, the trembling of one cold. In a real session the view reads all of it off
## the characters' own state, a few times a second, and takes it off again when it is gone.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Person := preload("res://presentation/voxel/actors/voxel_person.gd")
const States := preload("res://presentation/voxel/actors/voxel_states.gd")

var assertions: int = 0
var failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary:
	_check_data()
	_check_rules()
	await _check_marks(tree)
	await _check_bearing(tree)
	await _check_in_a_session(tree)
	return {"assertions": assertions, "failures": failures}


## Every condition the game has shows as a kind the library draws, in a colour.
func _check_data() -> void:
	var data: Dictionary = States.data()
	var marks: Dictionary = data.get("marks", {})
	for id: StringName in ConditionIds.ALL:
		var look: Dictionary = marks.get(String(id), {})
		check(States.KINDS.has(String(look.get("kind", ""))) and String(look.get("colour", "")).is_valid_html_color(), "%s: a kind the library draws, in a colour" % id)
	for key: String in marks:
		check(ConditionIds.ALL.has(StringName(key)), "%s is a condition of the game" % key)
	var wound: Dictionary = data.get("wound", {})
	check(States.KINDS.has(String(wound.get("kind", ""))) and String(wound.get("colour", "")).is_valid_html_color() and float(wound.get("below", -1.0)) >= 0.0 and float(wound["below"]) < 1.0, "an open wound: a kind, a colour, a share of 气's ceiling under one")
	check(ConditionIds.ALL.has(StringName(String(wound.get("stopped_by", "")))), "what stops it is a condition of the game")
	var weary: Dictionary = data.get("weary", {})
	check(float(weary.get("from", 0.0)) > float(weary.get("full", 1.0)) and float(weary["full"]) >= 0.0 and float(weary["from"]) < 1.0, "weary: from a share of 气 down to a lesser one")
	check(float(data.get("check_seconds", 0.0)) > 0.0, "the view reads the states every so often, not every frame")


## What the data makes of a character's state.
func _check_rules() -> void:
	var none: Array[StringName] = []
	var poisons: Array[StringName] = [ConditionIds.POISON, ConditionIds.SNAKE_POISON]
	var twice: Array[StringName] = [ConditionIds.DRUNK, ConditionIds.DRUNK]
	var bound: Array[StringName] = [ConditionIds.BANDAGED]
	check(States.marks_for(none, false).is_empty(), "no condition, no wound: no mark")
	var two: Array = States.marks_for(poisons, false)
	check(two.size() == 2 and two[0][0] == "bubbles" and two[1][0] == "bubbles" and two[0][1] != two[1][1], "two poisons: bubbles of two colours (%s)" % [two])
	check(States.marks_for(twice, false).size() == 1, "one look twice shows once")
	var open: Array = States.marks_for(none, true)
	check(open.size() == 1 and open[0][0] == "drip", "an open wound drips (%s)" % [open])
	var dressed: Array = States.marks_for(bound, true)
	check(dressed.size() == 1 and dressed[0][0] == "band", "bound up: the cloth, no drip (%s)" % [dressed])
	var below: float = float(States.data()["wound"]["below"])
	check(States.wounded(int(below * 100.0) - 5, 100) and not States.wounded(int(below * 100.0) + 5, 100) and not States.wounded(100, 100) and not States.wounded(0, 0), "a wound is open under the data's share of 气's ceiling")
	var from: float = float(States.data()["weary"]["from"])
	var full: float = float(States.data()["weary"]["full"])
	check(is_zero_approx(States.weariness(100, 100)) and is_zero_approx(States.weariness(int(from * 100.0), 100)) and is_equal_approx(States.weariness(int(full * 100.0), 100), 1.0) and is_equal_approx(States.weariness(0, 100), 1.0) and is_zero_approx(States.weariness(5, 0)), "worn from the data's share of 气 down to its least")
	var half: float = States.weariness(int((from + full) * 50.0), 100)
	check(half > 0.3 and half < 0.7, "half way between: half worn (%.2f)" % half)
	var drunk: Array[StringName] = [ConditionIds.DRUNK]
	var cold: Array[StringName] = [ConditionIds.ICE_SHOCK]
	var drugged: Array[StringName] = [ConditionIds.SLUMBER_DRUG]
	check(States.bearing(drunk)[0] > 0.0 and is_zero_approx(States.bearing(drunk)[1]), "one drunk rocks")
	check(States.bearing(cold)[1] > 0.0 and States.bearing(drugged)[2] > 0.0 and is_zero_approx(States.bearing(none)[0] + States.bearing(none)[1] + States.bearing(none)[2]), "one cold trembles, one drugged droops, one well does neither")


## The marks' node: built when the marks change, moved by the clock, taken down with them.
func _check_marks(tree: SceneTree) -> void:
	var root := Node3D.new()
	tree.root.add_child(root)
	var body := Node3D.new()
	root.add_child(body)
	var worn := States.new()
	worn.body = body
	root.add_child(worn)
	await tree.process_frame
	check(worn.get_child_count() == 0 and not worn.is_processing(), "nothing worn: nothing drawn, nothing run")
	worn.wear([["bubbles", "7cc24a"], ["band", "efe6d2"]])
	check(worn.get_child_count() == 5 and body.get_child_count() == 2 and worn.is_processing(), "poisoned and bound: bubbles about the figure, the cloth on its body (%d, %d)" % [worn.get_child_count(), body.get_child_count()])
	var first: MeshInstance3D = worn.get_child(0) as MeshInstance3D
	var was: Vector3 = first.position
	for step: int in 12:
		await tree.process_frame
	check(not first.position.is_equal_approx(was), "the bubbles rise")
	var cloth: MeshInstance3D = body.get_child(0) as MeshInstance3D
	var cloth_at: Vector3 = cloth.position
	worn.wear([["bubbles", "7cc24a"], ["band", "efe6d2"]])
	check(worn.get_child(0) == first and body.get_child(0) == cloth, "the same again: nothing built anew")
	for step: int in 6:
		await tree.process_frame
	check(cloth.position.is_equal_approx(cloth_at), "the cloth stays where it is bound")
	for kind: String in States.KINDS:
		worn.wear([[kind, "ffffff"]])
		check(worn.shown.size() == 1 and worn.get_child_count() + body.get_child_count() >= 2, "%s: its blocks stand (%d)" % [kind, worn.get_child_count() + body.get_child_count()])
		var far: int = 0
		for block: Node in worn.get_children() + body.get_children():
			far += 1 if (block as Node3D).position.length() > 2.6 else 0
		check(far == 0, "%s: all of it on or about the figure" % kind)
		await tree.process_frame
	# A child's and a tall one's cloth sits on their own heads.
	for build: String in ["child", "tall"]:
		var figure := Person.new()
		figure.configure({"coat": "397c87", "height": build})
		root.add_child(figure)
		var theirs := States.new()
		theirs.body = figure.torso
		theirs.height = figure.head_point(Vector3(0.0, 1.68, 0.035)).y / 1.68
		theirs.head_lift = figure.head_point(Vector3(0.0, 1.2, 0.035)).y - 1.2
		theirs.head_scale = figure.head_scale()
		figure.add_child(theirs)
		theirs.wear([["band", "efe6d2"], ["flush", "f08a7a"]])
		var bound: MeshInstance3D = figure.torso.get_child(figure.torso.get_child_count() - 2) as MeshInstance3D
		var brow: float = figure.head_point(Vector3(0.0, 1.53, 0.035)).y
		check(bound != null and is_equal_approx(bound.position.y, brow) and (theirs.get_child(0) as Node3D).position.y < figure.head_point(Vector3(0.0, 1.7, 0.035)).y, "%s: the cloth round its own brow (%.2f at %.2f), the flush by its own head" % [build, bound.position.y if bound != null else -1.0, brow])
		check((build == "child") == (brow < 1.4), "%s: its brow is %s the plain figure's" % [build, "under" if build == "child" else "over"])
		figure.queue_free()
	var headless := States.new()
	headless.body = body
	headless.headless = true
	root.add_child(headless)
	headless.wear([["band", "efe6d2"]])
	check(headless.shown.size() == 1 and body.get_child_count() == 0 and headless.get_child_count() == 0, "one with no head: no cloth to bind (%d)" % body.get_child_count())
	headless.queue_free()
	# A beast's sit lower and smaller.
	var low := States.new()
	low.height = 0.4
	root.add_child(low)
	low.wear([["bubbles", "7cc24a"]])
	var highest: float = 0.0
	for block: Node in low.get_children():
		highest = maxf(highest, (block as Node3D).position.y)
	check(highest < 1.0 and ((low.get_child(0) as MeshInstance3D).mesh as BoxMesh).size.x < 0.06, "a low figure's marks: lower and smaller (%.2f)" % highest)
	worn.wear([])
	await tree.process_frame
	check(worn.get_child_count() == 0 and body.get_child_count() == 0 and not worn.is_processing(), "well again: all of it gone")
	root.queue_free()
	await tree.process_frame


## The body under them: worn it stoops and pants, drunk it rocks, cold it trembles — standing
## about and on guard alike; fresh it stands as it always did.
func _check_bearing(tree: SceneTree) -> void:
	var root := Node3D.new()
	tree.root.add_child(root)
	var fresh := Person.new()
	fresh.configure({"coat": "397c87"})
	root.add_child(fresh)
	var spent := Person.new()
	spent.configure({"coat": "397c87"})
	spent.position.x = 2.0
	root.add_child(spent)
	spent.weary = 1.0
	for step: int in 90:
		await tree.process_frame
	check(is_zero_approx(fresh.torso.rotation.x) and is_zero_approx(fresh.torso.rotation.z) and is_zero_approx(fresh.torso.position.x), "one fresh stands straight")
	check(spent.torso.rotation.x > 0.15, "one spent stoops (%.2f)" % spent.torso.rotation.x)
	var breaths: Array[float] = [0.0, 0.0]
	for step: int in 120:
		await tree.process_frame
		breaths[0] = maxf(breaths[0], absf(fresh.torso.position.y))
		breaths[1] = maxf(breaths[1], absf(spent.torso.position.y))
	check(breaths[1] > breaths[0] + 0.005, "and breathes deeper (%.3f against %.3f)" % [breaths[1], breaths[0]])
	# On guard: over its weapon, the arms sunk.
	fresh.take_guard("sword")
	spent.take_guard("sword")
	for step: int in 20:
		await tree.process_frame
	check(spent.torso.rotation.x > fresh.torso.rotation.x + 0.15 and spent.arms[0].rotation.x > fresh.arms[0].rotation.x + 0.2, "on guard: stooped over it, the arms sunk (%.2f / %.2f, %.2f / %.2f)" % [spent.torso.rotation.x, fresh.torso.rotation.x, spent.arms[0].rotation.x, fresh.arms[0].rotation.x])
	spent.weary = 0.0
	for step: int in 60:
		await tree.process_frame
	check(is_equal_approx(spent.torso.rotation.x, fresh.torso.rotation.x), "its 气 back: it straightens")
	fresh.stand_down()
	spent.stand_down()
	spent.sway = 0.1
	spent.shiver = 0.02
	var rocked: float = 0.0
	var trembled: float = 0.0
	for step: int in 150:
		await tree.process_frame
		rocked = maxf(rocked, absf(spent.torso.rotation.z))
		trembled = maxf(trembled, absf(spent.torso.position.x))
	check(rocked > 0.05 and trembled > 0.01 and is_zero_approx(fresh.torso.rotation.z) and is_zero_approx(fresh.torso.position.x), "drunk it rocks, cold it trembles (%.2f, %.3f)" % [rocked, trembled])
	spent.sway = 0.0
	spent.shiver = 0.0
	for step: int in 6:
		await tree.process_frame
	check(is_zero_approx(spent.torso.rotation.z) and is_zero_approx(spent.torso.position.x), "sober and warm: still")
	# The new stances are whole poses.
	for pose: String in ["gather", "cast", "roar"]:
		check(Person.REACTIONS.has(pose) and (Person.REACTIONS[pose] as Array).size() == 11, "%s: a pose of the eleven angles" % pose)
	root.queue_free()
	await tree.process_frame


## A real session: the view reads the player's and an NPC's own state and dresses their figures.
func _check_in_a_session(tree: SceneTree) -> void:
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	var map := session.active_map() as WorldMapController
	var view: WorldVoxelView = map.get_node_or_null("MapView") as WorldVoxelView
	if not check(view != null, "the session's map has its voxel view"):
		session.free()
		return
	for step: int in 400:
		await tree.process_frame
		if view.actors.has(session.player_runtime().character_id):
			break
	var me: StringName = session.player_runtime().character_id
	var state: CharacterState = session.player_runtime().state
	if not check(view.actors.has(me), "the player's figure stands"):
		session.free()
		return
	var model: Person = view.actors[me].get_child(0) as Person
	await tree.create_timer(0.6).timeout
	check(model != null and model.get_node_or_null(^"States") == null and is_zero_approx(model.weary), "well: nothing worn, nothing made for it")
	var vitality: Array[int] = [state.vitality.current, state.vitality.effective]
	# Bound up.
	state.conditions.add_or_replace_duration(ConditionIds.BANDAGED, 30)
	await tree.create_timer(0.6).timeout
	var worn: States = model.get_node_or_null(^"States") as States
	check(worn != null and worn.shown.size() == 1 and worn.shown[0][0] == "band" and worn.body == model.torso, "bandaged: the cloth on the figure (%s)" % [worn.shown if worn != null else []])
	check(worn != null and worn.height > 0.6 and worn.height < 1.2, "a person's marks go by its own height (%.2f)" % (worn.height if worn != null else -1.0))
	# Every figure of the map: its kind's height beside a person, its own scale not counted twice.
	var heights_fine: int = 0
	for id: StringName in view.actors:
		var kind_height: float = float(view.actors[id].get_meta("mark_height", -1.0))
		heights_fine += 1 if kind_height > 0.2 and kind_height <= 1.0 else 0
	check(heights_fine == view.actors.size(), "every figure has its kind's height for its marks, none over a person's (%d of %d)" % [heights_fine, view.actors.size()])
	state.conditions.remove_condition(ConditionIds.BANDAGED)
	# An open wound, and 气 low.
	state.vitality.apply_wound(state.vitality.maximum * 6 / 10)
	state.vitality.apply_damage(state.vitality.current * 9 / 10)
	await tree.create_timer(0.6).timeout
	check(worn != null and worn.shown.size() == 1 and worn.shown[0][0] == "drip" and model.weary > 0.5, "wounded and spent: it drips and stoops (%s, %.2f)" % [worn.shown if worn != null else [], model.weary])
	state.vitality.cure(vitality[1] - state.vitality.effective)
	state.vitality.heal(vitality[0] - state.vitality.current)
	check(state.vitality.current == vitality[0] and state.vitality.effective == vitality[1], "TEST-ONLY: the player's 气 put back")
	# Drunk: the mark, and the body rocks.
	state.conditions.add_or_replace_duration(ConditionIds.DRUNK, 2)
	await tree.create_timer(0.6).timeout
	check(worn != null and worn.shown.size() == 1 and worn.shown[0][0] == "flush" and model.sway > 0.0 and is_zero_approx(model.weary), "drunk: the flush, the rocking; healed: no drip, no stoop (%s)" % [worn.shown if worn != null else []])
	state.conditions.remove_condition(ConditionIds.DRUNK)
	await tree.create_timer(0.6).timeout
	check(worn != null and worn.shown.is_empty() and is_zero_approx(model.sway), "sober: nothing worn")
	# Someone of the town, poisoned.
	var poisoned: bool = false
	for npc: NpcRuntimeState in map.npc_runtimes():
		if not view.actors.has(npc.character_id) or npc.character_state == null or npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
			continue
		# TEST-ONLY: a poison put on by hand, taken off again below.
		npc.character_state.conditions.add_or_replace_duration(ConditionIds.SNAKE_POISON, 30)
		await tree.create_timer(0.6).timeout
		var theirs: States = view.actors[npc.character_id].get_child(0).get_node_or_null(^"States") as States
		check(theirs != null and theirs.shown.size() == 1 and theirs.shown[0][0] == "bubbles", "%s poisoned: bubbles off its figure" % npc.character_id)
		npc.character_state.conditions.remove_condition(ConditionIds.SNAKE_POISON)
		await tree.create_timer(0.6).timeout
		check(theirs != null and theirs.shown.is_empty(), "cured: gone")
		poisoned = true
		break
	check(poisoned, "someone of the map stood to be looked at")
	session.free()
	await tree.process_frame


func check(condition: bool, message: String) -> bool:
	assertions += 1
	if not condition:
		failures.append(message)
	return condition
