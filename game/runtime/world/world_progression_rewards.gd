class_name WorldProgressionRewards
extends RefCounted

## Native (owner, A2 经验节奏; DECISIONS「经验节奏」): where in the world the player earns
## the one-time 历练 rewards, and the player's catch-up and potential cap for any gain. The
## rules are MilestoneRewards' and ProgressionGain's; pacing.json says whether they apply.
## Owned by the session.

var _session: WorldSessionController
## A reward's cut was said since the fight began: fight_ended() says nothing more.
var _cut_said: bool = false


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
		_give(ProgressionRules.Kind.BOOK, item_definition_id, tr(item.display_name), true, book_level(item))


## A quest ended whose reward is a 历练 (任务系统): given once, for the quest.
func quest_done(quest: StoryQuestDefinition) -> void:
	if quest != null:
		_give(ProgressionRules.Kind.QUEST, quest.quest_id, tr(quest.title), false)


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
		_give(ProgressionRules.Kind.CHAIN, chain.chain_id, tr(chain.title), false, chain_level(chain.chain_id))
	# 打坐's steps (前两小时 A, owner Q5): each max_force number first reached, lowest first.
	for threshold: int in _rules().force_milestones:
		if player.state.recovery.inner_force.maximum >= threshold:
			_give(ProgressionRules.Kind.FORCE, StringName(str(threshold)), str(threshold), false)
	var location: WorldLocationState = player.world_location()
	# A ghost's way through 阴间 is no journey of the living: dying is never rewarded.
	if location == null or player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or player.state.ghost:
		return
	var region: RegionDefinition = GameContent.catalog().region(location.region_id)
	var level: int = -1 if region == null or region.recommended_exp <= 0 else region.recommended_exp
	if region != null:
		_give(ProgressionRules.Kind.REGION, region.region_id, tr(region.display_name), false, level)
	if _rules().places.has(location.zone_id):
		var zone: ZoneDefinition = GameContent.catalog().zone(location.zone_id)
		_give(ProgressionRules.Kind.PLACE, location.zone_id, tr(zone.display_name), false, level)


## A fight began: what its rewards' cuts say starts afresh.
func fight_began() -> void:
	_cut_said = false


## A fight ended: when its blows filled the player's potential (from below the cap), the
## player is told once, as a reward's cut is.
func fight_ended(unspent_before: int) -> void:
	var player: WorldPlayerRuntimeState = _session.player_runtime()
	if player == null or player.state == null:
		return
	var cap: int = potential_cap(player.state)
	var unspent: int = player.state.progression.potential - player.state.progression.potential_spent
	var said: bool = _cut_said
	_cut_said = false
	if unspent_before < cap and unspent >= cap and not said and _session.shared_ui() != null:
		# TRANSLATORS: native (A2): the fight's blows filled the player's potential ({cap} unspent at most).
		_session.shared_ui().append_after_fight([ColoredLine.new(tr("潜能已满（最多 {cap} 点未用），再打下去潜能不会增长。先去请教师父或自学，用掉一些潜能吧。").format({"cap": cap}))])


func _beaten(npc: NpcRuntimeState) -> void:
	var player: WorldPlayerRuntimeState = _session.player_runtime()
	if npc == null or player == null or player.state == null or _rules() == null:
		return
	var definition: NpcDefinition = npc.definition()
	if not MilestoneRewards.opponent_counts(player.state.progression.combat_experience, npc.character_state.progression.combat_experience):
		return
	var kind: ProgressionRules.Kind = ProgressionRules.Kind.DEFEAT if _rules().notable_npcs.has(definition.definition_id) else ProgressionRules.Kind.SPAR
	_give(kind, definition.definition_id, tr(definition.display_name), true, npc.character_state.progression.combat_experience)


## The level a chain's content is of (pacing milestone_stage_headroom): progression.json's
## `chain_level` for one whose last step asks more than its region (green.maze: the 八卦阵's wind),
## else its region's recommended_exp, the region named by the chain id's first part (snow.newcomer:
## 雪亭镇); -1 when there is none.
static func chain_level(chain_id: StringName) -> int:
	var levels: Dictionary[StringName, int] = GameContent.catalog().progression().chain_levels
	if levels.has(chain_id):
		return levels[chain_id]
	return region_level(StringName(String(chain_id).get_slice(".", 0)))


## The level a book's read-through is of (pacing milestone_stage_headroom): the highest of what it
## asks to start (study.exp_required), what a martial skill asks to be learnt up to the book's depth
## (learn.c's gate at max_skill - 1: the read-through is the study past max_skill), and the level of
## the region the book belongs to (its id's path: es2:d/<region>/..., es2:u/<region>/...,
## native:<region>/...); -1 for an item that is no book.
static func book_level(item: ItemContentDefinition) -> int:
	if item == null or item.study == null:
		return -1
	var level: int = maxi(item.study.exp_required, region_level(item_region(item.item_definition_id)))
	var skill: SkillDefinition = GameContent.catalog().skill(item.study.skill_id)
	if skill != null and skill.skill_type == SkillDefinition.Type.MARTIAL and item.study.max_skill > 0:
		level = maxi(level, LearnService.required_combat_experience(item.study.max_skill - 1))
	return level


## The region an item's id names (es2:d/choyin/... and native:guanbei/...: the region of that name), or
## &"" (es2:obj/..., one of no region).
static func item_region(definition_id: StringName) -> StringName:
	var id: String = String(definition_id)
	for prefix: String in ["es2:d/", "es2:u/", "native:"]:
		if id.begins_with(prefix):
			return StringName(id.substr(prefix.length()).get_slice("/", 0))
	return &""


## A region's recommended_exp as a content level; -1 when there is no such region or it has none.
static func region_level(region_id: StringName) -> int:
	var region: RegionDefinition = null if region_id.is_empty() else GameContent.catalog().region(region_id)
	return -1 if region == null or region.recommended_exp <= 0 else region.recommended_exp


## Gives the reward of `kind` for `id` (`name` shown); `content_exp` the level of the content it is
## for (pacing milestone_stage_headroom; -1: none, the player's own stage).
func _give(kind: ProgressionRules.Kind, id: StringName, name: String, after_fight: bool, content_exp: int = -1) -> void:
	var player: WorldPlayerRuntimeState = _session.player_runtime()
	if not _enabled() or player == null or player.state == null:
		return
	var state: CharacterState = player.state
	var location: WorldLocationState = player.world_location()
	var zone_id: StringName = &"" if location == null else location.zone_id
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	var grant: MilestoneRewards.Grant = MilestoneRewards.grant(state, _rules(), kind, id, catch_up_percent(state, zone_id), pacing.staged_potential_cap, content_exp, pacing.milestone_stage_headroom)
	var hud: SharedGameplayUI = _session.shared_ui()
	if grant == null or hud == null:
		return
	var lines: Array[ColoredLine] = MilestoneRewards.lines(grant, name)
	_cut_said = _cut_said or grant.potential_cut > 0
	if after_fight:
		hud.append_after_fight(lines)
	else:
		hud.append_colored_lines(lines)


func _enabled() -> bool:
	return GameContent.catalog().pacing().milestone_rewards and _rules() != null


func _rules() -> ProgressionRules:
	return GameContent.catalog().progression()
