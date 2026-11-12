extends RefCounted

## The 试战台 (tests/dev/battle_lab.tscn, a dev tool): the families it offers, how a fighter is brought
## to a level, an N-against-M fight set up and fought to its end through the game's coordinator the
## same way twice from one seed, and the panel turning its rows into that setup. Nothing here is read
## by the game.

const LAB := preload("res://tests/dev/battle_lab.tscn")
const Roster := preload("res://tests/dev/battle_lab/battle_lab_roster.gd")
const Grown := preload("res://tests/support/grown_character.gd")

var assertions: int = 0
var failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary:
	_check_roster()
	await _check_fight(tree)
	await _check_panel(tree)
	return {"assertions": assertions, "failures": failures}


func _check_roster() -> void:
	var families: Array[BattleLabRoster.Family] = Roster.families()
	_check(families.size() >= 10, "most families can be fielded: %d" % families.size())
	var fonxan: BattleLabRoster.Family = Roster.family(&"family.fonxan")
	_check(fonxan != null and fonxan.template_id == &"common.npc.swordsman.master", "封山剑派 fights as its master 柳淳风")
	_check(families[0].family_id == &"family.fonxan", "families come in the game's order, 封山 first")
	for level: int in [1, 10, 30, 60]:
		var experience: int = Roster.experience_for(level)
		_check(Grown.level_for(experience) >= level and (experience == 0 or Grown.level_for(experience - 1) < level), "level %d is first reached at %d exp" % [level, experience])
	var template: NpcDefinition = GameContent.catalog().npc(fonxan.template_id)
	var state := CharacterState.new()
	state.skills.set_raw_level(&"blade", 50)
	Roster.level_player(state, template, 25, 14)
	_check(state.skills.raw_level(&"fonxansword") == 25 and state.skills.raw_level(&"sword") == 25 and state.skills.mapped_skill(&"sword") == &"fonxansword", "the player at 封山 25: its sword skills at 25, mapped as the master maps them")
	_check(not state.skills.has_raw_level(&"blade"), "the martial skills the player had before are dropped")
	_check(state.vitality.current == state.vitality.maximum and state.vitality.maximum > 100, "kee full and grown by the force: %d" % state.vitality.maximum)
	_check(Roster.weapon_of(template) != &"", "the master's weapon is what the player takes up")


## 2 against 2 (封山 player and a 北宗 helper against two 天邪), a few duels twice from the same seed.
func _check_fight(tree: SceneTree) -> void:
	var spec: Dictionary = {
		"player": {"family": "family.fonxan", "level": 25},
		"allies": [{"family": "family.fonxan_north", "level": 20}],
		"foes": [{"family": "family.celestial", "level": 20, "count": 2}],
		"seed": 5,
	}
	var fight := BattleLabFight.new(tree)
	_check(await fight.setup(spec), "the lab sets the fight up: %s" % fight.error)
	_check(fight.allies.size() == 1 and fight.foes.size() == 2, "one helper and two foes stand there")
	var map: WorldMapController = fight.map
	var strangers: Array = map.npcs.residents.filter(func(npc: NpcRuntimeState) -> bool: return npc.exists_in_map and not fight.allies.has(npc) and not fight.foes.has(npc))
	_check(strangers.is_empty(), "the place is cleared of its own people: %d left" % strangers.size())
	var first: BattleLabFight.Result = await fight.run(3, 11)
	_check(first.duels == 3 and first.stuck == 0, "three duels fought to their end (%d, stuck %d): %s" % [first.duels, first.stuck, first.notes])
	_check(first.ours_in == 2 and first.theirs_in == 2, "two on each side in the fight: %d / %d" % [first.ours_in, first.theirs_in])
	var again: BattleLabFight.Result = await fight.run(3, 11)
	_check(again.wins == first.wins and again.won_rounds == first.won_rounds and again.lost_rounds == first.lost_rounds, "the same seed fights the same: %d/%d %s %s" % [again.wins, first.wins, again.won_rounds, first.won_rounds])
	_check(not fight.session.combat_encounter_coordinator().has_active_encounter(), "no fight is left running")
	var weapon: EquippedWeaponRef = fight.session.player_runtime().state.equipment.primary_weapon()
	_check(weapon != null, "the player holds a weapon again after the duels")
	var kees: Array = fight.foes.map(func(npc: NpcRuntimeState) -> int: return npc.character_state.vitality.maximum)
	_check(await fight.setup(spec), "the same spec sets up again")
	var again_kees: Array = fight.foes.map(func(npc: NpcRuntimeState) -> int: return npc.character_state.vitality.maximum)
	_check(kees == again_kees, "the same seed makes the same foes: %s / %s" % [kees, again_kees])
	# An unknown fighter is refused, and says why.
	_check(not await fight.setup({"foes": [{"npc": "no.such.npc"}]}) and fight.error.contains("no.such.npc"), "an unknown NPC is refused: %s" % fight.error)
	_check(not await fight.setup({"foes": []}), "a fight needs a foe")
	await fight.close()


func _check_panel(tree: SceneTree) -> void:
	var lab: Node = LAB.instantiate()
	lab.set("remember", false)
	tree.root.add_child(lab)
	await lab.prepared
	var spec: Dictionary = lab.call("current_spec")
	_check(spec["player"]["family"] == "family.fonxan" and spec["foes"].size() == 1 and spec["foes"][0]["family"] == "family.celestial", "the panel starts at 封山 against 天邪: %s" % JSON.stringify(spec))
	lab.call("_add_row", lab.get("_foe_rows"), {"npc": "oldpine.npc.bandit", "count": 2})
	spec = lab.call("current_spec")
	_check(spec["foes"].size() == 2 and spec["foes"][1]["npc"] == "oldpine.npc.bandit" and spec["foes"][1]["count"] == 2, "a named NPC's row turns into its spec: %s" % JSON.stringify(spec["foes"]))
	_check(await lab.call("set_up"), "the panel's setup stands: %s" % lab.get("_status").text)
	var fight: BattleLabFight = lab.get("fight")
	_check(fight.foes.size() == 3, "one 天邪 and two 土匪 stand there: %d" % fight.foes.size())
	_check(fight.session.autosave_moment.get_connections().is_empty(), "nothing listens for an autosave moment: no save can be written")
	lab.queue_free()
	await tree.process_frame
	await tree.process_frame


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append("battle_lab: " + message)
