class_name WorldPlayerRuntimeState
extends RefCounted

var _character_id: StringName
var _state: CharacterState
var _relationship: CombatRelationshipState
var _busy: ActionBusyState
var _armor: ArmorState
var _world_location: WorldLocationState
var _life_status: int
var _exists_in_world: bool
var _combat_available: bool
var _body_facts: PlayerBodyFacts
var _facts: PlayerIdentityFacts
var apprenticeship_request: NpcApprenticeship = NpcApprenticeship.new()
## set_temp("mind_bug", bug) (necromancy.c practice_skill()): the character ID of the NPC
## the player's practice conjured, until it dies. A temp: Continue forgets it, as a
## save keeps no conjured NPC.
var conjured_npc_id: StringName = &""
## The player's set_temp() flags that NPCs and rooms read (d/latemoon's latemoon/茶):
## not saved, so Continue forgets them as ES2's relogin did (DECISIONS 晚月庄 A).
var temp_marks: Dictionary[String, int] = {}

var facts: PlayerIdentityFacts:
	get: return _facts

var character_id: StringName:
	get: return _character_id
var state: CharacterState:
	get: return _state
var relationship: CombatRelationshipState:
	get: return _relationship
var busy: ActionBusyState:
	get: return _busy
var armor: ArmorState:
	get: return _armor
var life_status: int:
	get: return _life_status
var exists_in_world: bool:
	get: return _exists_in_world
var combat_available: bool:
	get: return _combat_available
var maximum_encumbrance: int:
	get: return _body_facts.maximum_encumbrance
var body_facts: PlayerBodyFacts:
	get: return _body_facts


func _init(
	p_character_id: StringName = &"",
	p_state: CharacterState = null,
	p_relationship: CombatRelationshipState = null,
	p_busy: ActionBusyState = null,
	p_armor: ArmorState = null,
	p_world_location: WorldLocationState = null,
	p_life_status: int = CharacterRuntimeLifeStatus.Value.ACTIVE,
	p_exists_in_world: bool = true,
	p_combat_available: bool = true,
	p_body_facts: PlayerBodyFacts = null,
	p_facts: PlayerIdentityFacts = null,
) -> void:
	_character_id = p_character_id
	_state = p_state
	_relationship = p_relationship
	_busy = p_busy
	_armor = p_armor
	_world_location = (
		null if p_world_location == null else p_world_location.duplicate_snapshot()
	)
	_life_status = p_life_status
	_exists_in_world = p_exists_in_world
	_combat_available = p_combat_available
	_body_facts = p_body_facts
	_facts = PlayerIdentityFacts.legacy_technical() if p_facts == null else p_facts


## The production Player death projection; source fixtures use this same path.
func death_context(destination: InventoryTransferDestination, has_killer: bool) -> DeathContext:
	return DeathContext.new(
		_character_id, false, false, destination,
		ItemLifecycleOwnerContext.new(_character_id, _state.equipment, _armor),
		_facts.display_name, _state.gender, _facts.age,
		_body_facts.body_weight,
		_body_facts.maximum_encumbrance,
		false, destination.endpoint if has_killer else null, _state.gender, has_killer,
	)


func world_location() -> WorldLocationState:
	return null if _world_location == null else _world_location.duplicate_snapshot()


## apprentice <master>. Only successful recruitment may replace the read-only
## identity title (feature/apprentice.c assign_apprentice()). Body, CharacterState
## and character ID retain their existing authorities. `answer_due`: the master's answer
## to an earlier request is still to come (NpcApprenticeship.request()).
func request_apprenticeship(master: NpcDefinition, family: FamilyDefinition, entry_time_utc: int, answer_due: bool = false) -> NpcApprenticeship.Outcome:
	return _after_recruit(apprenticeship_request.request(
		_state, master, family, entry_time_utc, _respect(), _facts.title, shown_title(), _facts.display_name, answer_due,
	), family)


## The master's answer when it is due (taolord.c do_recruit()), with the player before it
## (`awake` false: lying unconscious).
func apprenticeship_answer(master: NpcDefinition, family: FamilyDefinition, entry_time_utc: int, awake: bool = true) -> NpcApprenticeship.Outcome:
	return _after_recruit(apprenticeship_request.answer(_state, master, family, entry_time_utc, _respect(), awake), family)


## juechen/master.c would take the player for a traitor if they asked it now.
func would_be_attacked_by(master: NpcDefinition) -> bool:
	return apprenticeship_request.would_attack(_state, master, _facts.title)


## 拜师 with `master` would take the player at once (NpcApprenticeship.takes_at_once()).
func would_be_taken_by(master: NpcDefinition) -> bool:
	return apprenticeship_request.takes_at_once(_state, master, _facts.title)


## swear to a master that asked for an oath (master.c do_swear()).
func swear_oath(master: NpcDefinition, family: FamilyDefinition, entry_time_utc: int) -> NpcApprenticeship.Outcome:
	return _after_recruit(apprenticeship_request.swear(_state, master, family, entry_time_utc, _respect()), family)


## The master's own recruit after its test (champion.c command("recruit")).
func recruited_by(master: NpcDefinition, family: FamilyDefinition, entry_time_utc: int) -> NpcApprenticeship.Outcome:
	return _after_recruit(apprenticeship_request.npc_recruit(_state, master, family, entry_time_utc), family)


func _respect() -> String:
	return RankWords.query_respect(_state.gender, _facts.age, _state.affiliation.class_id)


func _after_recruit(outcome: NpcApprenticeship.Outcome, family: FamilyDefinition) -> NpcApprenticeship.Outcome:
	if outcome == NpcApprenticeship.Outcome.RECRUITED:
		var title: String = NpcApprenticeship.family_title(family.display_name, _state.family.generation, _state.affiliation.family_title)
		_facts = PlayerIdentityFacts.new(_facts.display_name, title, _facts.age)
	return outcome


## combatd.c killer_reward(): set("title", ...) for one who killed their master.
func take_title(title: String) -> void:
	_facts = PlayerIdentityFacts.new(_facts.display_name, title, _facts.age)


## The title as the player reads it. A family member's is assign_apprentice()'s put
## together again in the shown language; the one kept (and saved) stays as ES2 wrote it.
func shown_title() -> String:
	if _state.family.has_family() and _state.affiliation.has_family_rank:
		var family: FamilyDefinition = GameContent.catalog().family(_state.family.family_id)
		if family != null:
			return NpcApprenticeship.shown_family_title(family.display_name, _state.family.generation, _state.affiliation.family_title)
	return TranslationServer.translate(_facts.title)


func set_world_location(value: WorldLocationState) -> bool:
	if value == null or not value.is_valid():
		return false
	_world_location = value.duplicate_snapshot()
	return true


func set_life_status(value: int) -> bool:
	if not CharacterRuntimeLifeStatus.is_valid(value):
		return false
	_life_status = value
	return true


func set_exists_in_world(value: bool) -> void:
	_exists_in_world = value


func set_combat_available(value: bool) -> void:
	_combat_available = value


func is_valid() -> bool:
	return (
		not _character_id.is_empty()
		and _state != null
		and _relationship != null
		and _relationship.is_valid()
		and _relationship.owner_character_id == _character_id
		and _busy != null
		and _armor != null
		and _body_facts != null
		and _facts != null and _facts.is_valid()
		and _world_location != null
		and _world_location.is_valid()
		and CharacterRuntimeLifeStatus.is_valid(_life_status)
	)
