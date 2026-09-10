extends RefCounted

const Fixture := preload("res://tests/support/beast_combat_fixture.gd")

var _assertions: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_forward_branches()
	_test_defender_wound_boundary()
	_test_npc_progression()
	_test_npc_parry_progression()
	_test_live_riposte()
	_test_reverse_hit_damage()
	return {"assertions": _assertions, "failures": _failures.duplicate()}


func _test_forward_branches() -> void:
	# combatd: fight cps*3; action; limb; dodge; parry; damage; strength;
	# defense loop; wound; defender progression. Literal bounds are LPC-derived.
	var f: RefCounted = Fixture.new()
	var rng: ScriptedCombatRandomSource = ScriptedCombatRandomSource.new([0, 0, 2, 500, 500, 0, 0, 0, 1, 1000])
	var result: CombatSliceOpportunityResult = f.execute(f.serpent, rng)
	_check_complete(result, rng, [60, 1, 16, 322500, 322500, 20, 40, 1000, 32, 1968], "forward hit")
	var base: CombatAttackResult = result.forward_result.ordinary_attack_result.base_result
	_eq(base.outcome, CombatAttackResult.Outcome.HIT, "ordinary bite hit")
	var c: CombatAttackCalculation = base.calculation
	_eq([c.attack_power, c.dodge_power, c.parry_power], [322000, 500, 500], "60^3/3/500*500+250000 AP; human exp/2 DP/PP")
	_eq(c.selected_limb, &"胸口", "target human limb draw after bite selection")
	_eq(c.base_apply_damage, 20, "intrinsic apply damage once")
	_eq(c.requested_damage, 32, "(20+0)/2=10; bite adds2; (40+0)/2 adds20")
	_eq(c.wound_amount, 32, "lethal armor0 wound")
	_eq([f.human.state.vitality.current, f.human.state.vitality.effective], [968, 968], "damage then wound")
	_eq(result.forward_result.selected_action_id, BeastCombatActionDefinitions.BITE_ACTION_ID, "forward bite ID")
	_eq(result.random_draws(), [0, 0, 2, 500, 500, 0, 0, 0, 1, 1000], "forward exact draws")
	f = Fixture.new()
	rng = ScriptedCombatRandomSource.new([0, 0, 0, 0, 0])
	result = f.execute(f.serpent, rng)
	_check_complete(result, rng, [60, 1, 16, 322500, 120], "forward dodge")
	_eq(result.forward_result.ordinary_attack_result.base_result.outcome, CombatAttackResult.Outcome.DODGE, "dodge not skipped")
	_eq(f.human.state.vitality.current, 1000, "dodged no damage")
	f = Fixture.new()
	rng = ScriptedCombatRandomSource.new([0, 0, 0, 500, 0, 0])
	result = f.execute(f.serpent, rng)
	_check_complete(result, rng, [60, 1, 16, 322500, 322500, 120], "forward parry")
	_eq(result.forward_result.ordinary_attack_result.base_result.outcome, CombatAttackResult.Outcome.PARRY, "ordinary parry retained")
	f = Fixture.new()
	f.human.busy.start_busy(2, 3) # feature/action.c: strict busy < interrupt.
	rng = ScriptedCombatRandomSource.new([0, 0, 166, 166, 0, 0, 0, 0, 1000])
	result = f.execute(f.serpent, rng)
	_check_complete(result, rng, [1, 16, 322166, 322166, 20, 40, 1000, 32, 1968], "busy target quick hit")
	_eq(f.human.busy.is_busy(), false, "positive damage interrupts existing busy authority")


func _test_defender_wound_boundary() -> void:
	# Test-only strength200 makes the armor boundary reachable without rebalance.
	# CXR9's already-approved unarmed zero-apply path skips random(0).
	for wound_draw: int in [90, 91]:
		var f: RefCounted = Fixture.new()
		f.human.state.attributes.strength = 200
		var rng: ScriptedCombatRandomSource = ScriptedCombatRandomSource.new([0, 0, 2, 420500, 125000, 0, 0, wound_draw, 0, 1000])
		var result: CombatSliceOpportunityResult = f.execute(f.human, rng)
		_check_complete(result, rng, [15, 1, 3, 421000, 125500, 200, 250000, 100, 120, 3500], "serpent defender")
		var c: CombatAttackCalculation = result.forward_result.ordinary_attack_result.base_result.calculation
		_eq([c.attack_power, c.dodge_power, c.parry_power], [500, 420500, 125000], "80^3/3/500*500+250000 DP; PP exp/2 no Beast ban")
		_eq(c.selected_limb, &"尾巴", "three Beast limbs, index2 tail")
		_eq([c.armor, c.requested_damage], [90, 100], "armor does not subtract current damage")
		_eq(c.wound_roll_performed, true, "ordinary wound gate")
		_eq(c.wound_amount, 0 if wound_draw == 90 else 10, "strict roll > armor; wound is damage-armor")
		_eq(f.serpent.state.vitality.current, 1700, "current loses100 at both boundaries")
		_eq(f.serpent.state.vitality.effective, 1800 if wound_draw == 90 else 1790, "effective only loses wound")
		_eq(f.serpent.state.skills.raw_level(&"dodge"), 0, "intrinsic dodge not a raw skill")


func _test_npc_progression() -> void:
	var f: RefCounted = Fixture.new()
	f.human.state.skills.set_raw_level(&"dodge", 200) # DP334000 > serpentAP322000.
	for amount: int in [2, 5]:
		var rng: ScriptedCombatRandomSource = ScriptedCombatRandomSource.new([0, 0, 0, 0, 0, amount])
		var result: CombatSliceOpportunityResult = f.execute(f.serpent, rng)
		_check_complete(result, rng, [60, 1, 16, 656000, 10, 10], "NPC miss progression")
		_eq(f.serpent.state.progression.combat_experience, 250000, "NPC random(int10) cannot exceed15")
		_eq(f.serpent.state.skills.raw_level(&"unarmed"), 1 if amount == 2 else 2, "strict learned threshold one level per call")
		_eq(f.serpent.state.skills.learned_progress(&"unarmed"), 0, "learned reset without carry")
	_eq(f.serpent.is_user, false, "NPC branch, not player potential branch")
	_eq(f.project(f.serpent, f.human).attacker.effective_attack_skill_level, 1, "live raw2/2 next projection")
	var next_rng: ScriptedCombatRandomSource = ScriptedCombatRandomSource.new([0, 0, 0, 0, 0, 0])
	var next: CombatSliceOpportunityResult = f.execute(f.serpent, next_rng)
	_check_complete(next, next_rng, [60, 1, 16, 659500, 10, 10], "post-progression opportunity")
	_eq(next.forward_result.ordinary_attack_result.base_result.calculation.attack_power, 325500, "(60+1)^3/3/500*500+250000; no cached raw0")
	_eq(f.serpent.state.skills.raw_level(&"dodge"), 0, "no synthetic dodge80")


func _test_live_riposte() -> void:
	for guard_draw: int in [0, 19]:
		var f: RefCounted = Fixture.new()
		f.human.state.progression.combat_experience = 500000
		f.human.state.skills.set_raw_level(&"unarmed", 200) # AP833000.
		f.serpent.state.skills.set_raw_level(&"dodge", 1)
		f.serpent.state.skills.improve_skill(&"dodge", 4, 20, false, false) # learned4 == (1+1)^2.
		f.serpent.relationship.set_guarding(true)
		var rng: ScriptedCombatRandomSource = ScriptedCombatRandomSource.new([0, 0, 0, 0, 51, guard_draw, 0, 0, 0, 0])
		var result: CombatSliceOpportunityResult = f.execute(f.human, rng)
		_check_complete(result, rng, [15, 1, 3, 1253500, 110, 20, 1, 16, 572001, 120], "guarding reverse")
		_eq(result.reverse_projection_built, true, "reverse projected after forward")
		_eq(result.reverse_attacker_experience_at_projection, 250001, "forward dodge success exp+1 visible")
		_eq(f.serpent.state.skills.raw_level(&"dodge"), 2, "forward learned+1 levels live NPC dodge")
		_eq(result.chain_result.reverse_selected_action_id, BeastCombatActionDefinitions.BITE_ACTION_ID, "reverse bite not human action")
		_eq(result.chain_result.reverse_ordinary_result.base_result.calculation.attack_power, 322001, "reverse uses updated exp plus intrinsic60")
		_eq(result.chain_result.reverse_ordinary_result.base_result.outcome, CombatAttackResult.Outcome.DODGE, "reverse resolves ordinary body")
		_eq(f.serpent.relationship.guarding, false, "source clears guarding once")
		_eq(f.project(f.human, f.serpent).defender.effective_dodge_skill_level, 81, "forward raw2 contributes1 beyond intrinsic80")
		_eq(result.random_draws(), [0, 0, 0, 0, 51, guard_draw, 0, 0, 0, 0], "reverse same RNG stream, exactly one extra random1")


func _test_npc_parry_progression() -> void:
	var f: Fixture = Fixture.new()
	f.human.state.progression.combat_experience = 500000
	f.human.state.skills.set_raw_level(&"unarmed", 200)
	f.serpent.state.skills.set_raw_level(&"parry", 1)
	f.serpent.state.skills.improve_skill(&"parry", 4, 20, false, false)
	var rng: ScriptedCombatRandomSource = ScriptedCombatRandomSource.new([0, 0, 0, 420500, 0, 51])
	var result: CombatSliceOpportunityResult = f.execute(f.human, rng)
	_check_complete(result, rng, [15, 1, 3, 1253500, 958000, 110], "NPC parry progression")
	_eq(result.forward_result.ordinary_attack_result.base_result.outcome, CombatAttackResult.Outcome.PARRY, "serpent can parry under ordinary rules")
	_eq(f.serpent.state.skills.raw_level(&"parry"), 2, "existing NPC parry improves past strict threshold")
	_eq(f.project(f.human, f.serpent).defender.effective_parry_skill_level, 1, "next projection reads live raw parry2/2")
	_eq(f.project(f.human, f.serpent).defender.effective_unarmed_skill_level, 0, "parry progression does not create unarmed")


func _check_complete(result: CombatSliceOpportunityResult, rng: ScriptedCombatRandomSource, bounds: Array[int], label: String) -> void:
	_eq(result.outcome, CombatSliceOpportunityResult.Outcome.ATTACK_CHAIN_COMPLETE, "%s completed" % label)
	_eq(rng.requested_bounds(), bounds, "%s source RNG bounds/order" % label)
	_eq(result.random_upper_bounds(), bounds, "%s result carries same RNG timeline" % label)


func _test_reverse_hit_damage() -> void:
	var f: Fixture = Fixture.new()
	f.human.state.progression.combat_experience = 500000
	f.human.state.skills.set_raw_level(&"unarmed", 200)
	f.serpent.relationship.set_guarding(true)
	# Both empty-handed: combatd uses defender UNARMED (not parry) for PP.
	# raw200 -> effective100 -> 100^3/3/1000*1000+500000 = 833000.
	var rng: ScriptedCombatRandomSource = ScriptedCombatRandomSource.new([0, 0, 0, 0, 51, 19, 0, 0, 250000, 833000, 0, 0, 0, 0, 1000])
	var result: CombatSliceOpportunityResult = f.execute(f.human, rng)
	_check_complete(result, rng, [15, 1, 3, 1253500, 110, 20, 1, 16, 572001, 1155001, 20, 40, 500000, 32, 1968], "reverse bite hit")
	var base: CombatAttackResult = result.chain_result.reverse_ordinary_result.base_result
	_eq(base.outcome, CombatAttackResult.Outcome.HIT, "reverse ordinary bite hits")
	_eq([base.calculation.attack_power, base.calculation.base_apply_damage, base.calculation.requested_damage], [322001, 20, 32], "reverse live AP/intrinsic20/bite20%/strength40 once")
	_eq(f.human.state.vitality.current, 968, "reverse damages original forward attacker")
	_eq(f.serpent.state.vitality.current, 1800, "forward dodge leaves serpent kee intact")


func _eq(actual: Variant, expected: Variant, label: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, expected, actual])
