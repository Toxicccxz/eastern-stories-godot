extends RefCounted

## 修补 Z (DECISIONS「倒在你这边的人手里」): a death a story waits on (NpcHooks.die_marks) counts whoever on the
## player's side struck last: a helper fells the 小屋's courier (who vanishes in smoke) and 程不平's 密信 follows;
## a murderer's mark (die_marks_killer: xiaojuan2.c's murder) is still the player's own blow only.

const COURIER: StringName = &"native.npc.niling_courier"
const MURDERED: StringName = &"chuenyu.npc.xiaojuan2"
const HELPER: StringName = &"common.npc.swordsman.master"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var catalog: ContentCatalog = GameContent.catalog()
	_check(catalog.npc(COURIER).hooks().die_marks == "小屋的信使倒了" and catalog.npc(COURIER).hooks().die_marks_killer.is_empty(), "the courier's fall moves the story on, whoever fells him")
	_check(catalog.npc(MURDERED).hooks().die_marks_killer == "murder" and catalog.npc(MURDERED).hooks().die_marks.is_empty(), "小娟's death names its murderer (xiaojuan2.c)")
	TestFeel.turn_off()
	TestAway.turn_off()
	TestAlert.turn_off()
	TestDay.turn_off()
	TestDeath.turn_off()
	var paces: Array = [BattlePace.manual_turns, BattlePace.after_knockout, BattlePace.opening]
	BattlePace.manual_turns = false
	BattlePace.after_knockout = BattlePace.AfterKnockout.ASK
	BattlePace.opening = BattlePace.Opening.OFF
	var fight := BattleLabFight.new(tree)
	for case: Array in [[COURIER, "小屋的信使倒了", true], [MURDERED, "murder", false]]:
		var ready: bool = await fight.setup({"player": {"family": "", "level": 5}, "allies": [{"npc": String(HELPER), "level": 0, "count": 1}], "foes": [{"npc": String(case[0]), "level": 0, "count": 1}], "seed": 11})
		_check(ready, "set up: %s" % fight.error)
		if not ready:
			continue
		var session: WorldSessionController = fight.session
		var state: CharacterState = session.player_runtime().state
		state.marks.erase(case[1])
		state.applies["attack"] = -5000 # TEST-ONLY: the player lands nothing; the helper strikes every blow
		state.applies["defense"] = 5000
		_check(fight.start(), "the fight opens")
		var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
		var steps: int = 0
		while coordinator.has_active_encounter() and steps < 3000:
			session.player_runtime().busy.start_busy(5) # TEST-ONLY: the player never acts
			for victim: StringName in coordinator.held_victims():
				coordinator.spare_downed(victim) # TEST-ONLY: the player spares; only the helper's blow can kill
			coordinator.advance_scheduler(1.0)
			steps += 1
		session.shared_ui().dismiss_current_panel()
		state.applies.erase("attack")
		state.applies.erase("defense")
		var foe: NpcRuntimeState = fight.foes[0] if not fight.foes.is_empty() else null
		_check(foe != null and foe.life_status == CharacterRuntimeLifeStatus.Value.DEAD, "%s fell to the helper (%d steps)" % [case[0], steps])
		_check(state.marks.has(case[1]) == case[2], "%s: %s" % [case[1], "written for the player's side" if case[2] else "a murderer's mark stays the player's own"])
	await fight.close()
	BattlePace.manual_turns = paces[0]
	BattlePace.after_knockout = paces[1]
	BattlePace.opening = paces[2]
	return {"assertions": _count, "failures": _failures.duplicate()}


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
