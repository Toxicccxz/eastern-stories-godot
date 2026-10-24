class_name WorldProgressionRewards
extends RefCounted

## Native (owner, A2 经验节奏; DECISIONS「经验节奏」): where in the world the player earns
## the one-time 历练 rewards, and the player's catch-up and potential cap for any gain. The
## rules are MilestoneRewards' and ProgressionGain's; pacing.json says whether they apply.
## Owned by the session.

var _session: WorldSessionController


func _init(session: WorldSessionController) -> void:
	_session = session


## The region `zone_id` lies in, or null.
static func region_of_zone(zone_id: StringName) -> RegionDefinition:
	var catalog: ContentCatalog = GameContent.catalog()
	var zone: ZoneDefinition = catalog.zone(zone_id)
	var map: MapDefinition = null if zone == null else catalog.map(zone.map_id)
	return null if map == null else catalog.region(map.region_id)


## 落后补偿 for a gain the player makes in `zone_id` (percent; 0 when the knob is ES2's).
static func catch_up_percent(state: CharacterState, zone_id: StringName) -> int:
	var max_percent: int = GameContent.catalog().pacing().catch_up_max_percent
	if state == null or max_percent <= 0:
		return 0
	var region: RegionDefinition = region_of_zone(zone_id)
	if region == null:
		return 0
	return ProgressionGain.catch_up_percent(state.progression.combat_experience, region.recommended_exp, max_percent)


## The most potential the player keeps unspent now (100 when the knob is ES2's).
static func potential_cap(state: CharacterState) -> int:
	if state == null:
		return ProgressionRules.ES2_POTENTIAL_CAP
	return ProgressionGain.potential_cap(
		GameContent.catalog().progression(), state.progression.combat_experience,
		GameContent.catalog().pacing().staged_potential_cap,
	)


## The player won a spar against `npc` (their blow ended it, combatd.c's winner).
func spar_won(npc: NpcRuntimeState) -> void:
	_beaten(npc)


## The player knocked `npc` out or killed it (its last damage was theirs).
func defeated(npc: NpcRuntimeState) -> void:
	if npc != null and _rules() != null and _rules().notable_npcs.has(npc.definition().definition_id):
		_beaten(npc)


## A study of `item_definition_id` took the skill past what the book teaches
## (study.c's max_skill: it is too shallow from now on).
func book_read_through(item_definition_id: StringName) -> void:
	var item: ItemContentDefinition = GameContent.catalog().item(item_definition_id)
	if item != null:
		_give(ProgressionRules.Kind.BOOK, item_definition_id, tr(item.display_name), true)


## New Game: the region the player is born in is no first arrival (written down, no reward).
func note_birthplace() -> void:
	var player: WorldPlayerRuntimeState = _session.player_runtime()
	var location: WorldLocationState = null if player == null else player.world_location()
	if not _enabled() or location == null or player.state == null:
		return
	var key: String = MilestoneRewards.key_of(ProgressionRules.Kind.REGION, location.region_id)
	if not player.state.milestones.has(key):
		player.state.milestones[key] = player.state.milestones.size() + 1


## The chains seen through and the place the player stands in (on the journal's beat).
func look() -> void:
	var player: WorldPlayerRuntimeState = _session.player_runtime()
	if not _enabled() or player == null or player.state == null:
		return
	for chain: JournalChainDefinition in JournalLog.finished_chains(player.state, GameContent.catalog().journal_chains()):
		_give(ProgressionRules.Kind.CHAIN, chain.chain_id, tr(chain.title), false)
	var location: WorldLocationState = player.world_location()
	# A ghost's way through 阴间 is no journey of the living: dying is never rewarded.
	if location == null or player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or player.state.ghost:
		return
	var region: RegionDefinition = GameContent.catalog().region(location.region_id)
	if region != null:
		_give(ProgressionRules.Kind.REGION, region.region_id, tr(region.display_name), false)
	if _rules().places.has(location.zone_id):
		var zone: ZoneDefinition = GameContent.catalog().zone(location.zone_id)
		_give(ProgressionRules.Kind.PLACE, location.zone_id, tr(zone.display_name), false)


## A fight ended: when its blows filled the player's potential (from below the cap), the
## player is told once, as a reward's cut is.
func fight_ended(unspent_before: int) -> void:
	var player: WorldPlayerRuntimeState = _session.player_runtime()
	if player == null or player.state == null:
		return
	var cap: int = potential_cap(player.state)
	var unspent: int = player.state.progression.potential - player.state.progression.potential_spent
	if unspent_before < cap and unspent >= cap and _session.shared_ui() != null:
		# TRANSLATORS: native (A2): the fight's blows filled the player's potential ({cap} unspent at most).
		_session.shared_ui().append_after_fight([ColoredLine.new(tr("潜能已满（最多 {cap} 点未用），再打下去潜能不会增长。先去请教师父或研读书籍，用掉一些潜能吧。").format({"cap": cap}))])


func _beaten(npc: NpcRuntimeState) -> void:
	var player: WorldPlayerRuntimeState = _session.player_runtime()
	if npc == null or player == null or player.state == null or _rules() == null:
		return
	var definition: NpcDefinition = npc.definition()
	if not MilestoneRewards.opponent_counts(player.state.progression.combat_experience, npc.character_state.progression.combat_experience):
		return
	var kind: ProgressionRules.Kind = ProgressionRules.Kind.DEFEAT if _rules().notable_npcs.has(definition.definition_id) else ProgressionRules.Kind.SPAR
	_give(kind, definition.definition_id, tr(definition.display_name), true)


func _give(kind: ProgressionRules.Kind, id: StringName, name: String, after_fight: bool) -> void:
	var player: WorldPlayerRuntimeState = _session.player_runtime()
	if not _enabled() or player == null or player.state == null:
		return
	var state: CharacterState = player.state
	var location: WorldLocationState = player.world_location()
	var zone_id: StringName = &"" if location == null else location.zone_id
	var grant: MilestoneRewards.Grant = MilestoneRewards.grant(state, _rules(), kind, id, catch_up_percent(state, zone_id), potential_cap(state))
	var hud: SharedGameplayUI = _session.shared_ui()
	if grant == null or hud == null:
		return
	var lines: Array[ColoredLine] = MilestoneRewards.lines(grant, name)
	if after_fight:
		hud.append_after_fight(lines)
	else:
		hud.append_colored_lines(lines)


func _enabled() -> bool:
	return GameContent.catalog().pacing().milestone_rewards and _rules() != null


func _rules() -> ProgressionRules:
	return GameContent.catalog().progression()
