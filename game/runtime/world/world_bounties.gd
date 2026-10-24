class_name WorldBounties
extends RefCounted

## Native (owner, A2 经验节奏; DECISIONS「经验节奏」): the 雪亭驿 board in the world. Its
## postings (BountyBoard on the player's BountyState) fill on play time; a bounty taken
## brings its outlaw out beside the player when they walk into its place; the outlaw
## killed by the player, or spared (放过: taken to the 驿站, no 杀气), pays the bounty: a
## 历练 reward (MilestoneRewards.award, kind BOUNTY) and the tier's silver. Owned by the
## session; pacing.json bounty_board says whether there is a board at all.

## The 任务 page's marks (journal.json, chain native.bounty).
const MARK_TAKEN: String = "a2_bounty_taken"
const MARK_DONE: String = "a2_bounty_done"

var _session: WorldSessionController
var _remainder_ms: float = 0.0
## Outlaws to take away once no fight holds them (a spared one, one given up).
var _escorts: Array[StringName] = []


## One posting as the board shows it.
class Posting:
	extends RefCounted
	var slot: int
	var tier: BountyRules.Tier
	var place: BountyRules.Place
	var taken: bool


func _init(session: WorldSessionController) -> void:
	_session = session


func enabled() -> bool:
	return GameContent.catalog().pacing().bounty_board and GameContent.catalog().bounties() != null and GameContent.catalog().progression() != null


## Play time passes: empty slots fill once due (BountyBoard.tick()), once the board was read.
func advance(delta_seconds: float) -> void:
	var state: CharacterState = _state()
	# A board nobody has read yet is put up when it first is (postings()): until then play
	# time changes nothing, and a save holds no board.
	if not enabled() or state == null or state.bounty.is_default():
		return
	var elapsed: float = _remainder_ms + delta_seconds * 1000.0
	var whole: int = int(elapsed)
	_remainder_ms = elapsed - whole
	BountyBoard.tick(state.bounty, GameContent.catalog().bounties(), state.progression.combat_experience, whole, _outlaw_exp)


## The postings now, in slot order (the board fills them first on a look).
func postings() -> Array[Posting]:
	var result: Array[Posting] = []
	var state: CharacterState = _state()
	if not enabled() or state == null:
		return result
	var rules: BountyRules = GameContent.catalog().bounties()
	BountyBoard.tick(state.bounty, rules, state.progression.combat_experience, 0, _outlaw_exp)
	if not BountyBoard.fits(state.bounty, rules):
		return result
	for slot: int in state.bounty.tiers.size():
		if state.bounty.tiers[slot] < 0:
			continue
		var posting := Posting.new()
		posting.slot = slot
		posting.tier = rules.tiers[state.bounty.tiers[slot]]
		posting.place = rules.places[state.bounty.places[slot]]
		posting.taken = slot == state.bounty.active
		result.append(posting)
	return result


## The posting taken, or null.
## The posting taken, or null. It only reads: an unread board stays unposted (and out of
## a save) until postings() is called for the board itself.
func taken() -> Posting:
	var state: CharacterState = _state()
	var rules: BountyRules = GameContent.catalog().bounties()
	if not enabled() or state == null or state.bounty.active < 0 or not BountyBoard.fits(state.bounty, rules):
		return null
	var slot: int = state.bounty.active
	var posting := Posting.new()
	posting.slot = slot
	posting.tier = rules.tiers[state.bounty.tiers[slot]]
	posting.place = rules.places[state.bounty.places[slot]]
	posting.taken = true
	return posting


## 揭榜: the bounty in `slot` is the player's (one at a time).
func take(slot: int) -> bool:
	var state: CharacterState = _state()
	if not enabled() or state == null or not BountyBoard.take(state.bounty, slot):
		return false
	state.marks[MARK_TAKEN] = 1
	var posting: Posting = taken()
	# TRANSLATORS: native (A2): the player took the 雪亭驿 bounty on {outlaw}, last seen in {place} ({region}).
	_say([ColoredLine.new(tr("你揭下了雪亭驿的悬赏告示：{outlaw}，最近在{region}的{place}一带出没。").format({
		"outlaw": tr(_npc_name(posting.tier.npc_id)), "place": tr(_zone_name(posting.place.zone_id)), "region": tr(_region_name(posting.place.zone_id)),
	}), ColoredLine.HIY)])
	return true


## 放弃: the bounty taken is given up; its outlaw slips away, its slot waits for a new one.
func give_up() -> bool:
	var state: CharacterState = _state()
	var posting: Posting = taken()
	if state == null or posting == null:
		return false
	var outlaw: NpcRuntimeState = _standing_outlaw(posting)
	if outlaw != null:
		_escorts.append(outlaw.character_id)
		_escort()
	BountyBoard.close(state.bounty, _refresh_ms())
	# TRANSLATORS: native (A2): the player gave up the 雪亭驿 bounty on {outlaw}.
	_say([ColoredLine.new(tr("你放弃了捉拿{outlaw}的悬赏。").format({"outlaw": tr(_npc_name(posting.tier.npc_id))}))])
	return true


## On the journal's beat: with a bounty taken and the player in its place, its outlaw comes
## out beside them unless it already stands there.
func look() -> void:
	_escort()
	var player: WorldPlayerRuntimeState = _session.player_runtime()
	var posting: Posting = taken()
	if posting == null or player == null or player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or player.state.ghost:
		return
	var location: WorldLocationState = player.world_location()
	if location == null or location.zone_id != posting.place.zone_id or _standing_outlaw(posting) != null:
		return
	if _session.combat_encounter_coordinator() != null and _session.combat_encounter_coordinator().has_active_encounter():
		return
	var map: WorldMapController = _session.active_map() as WorldMapController
	# Not behind the menu, a fade or a passage under way: when the player walks in.
	if map == null or map.map_id() != posting.place.map_id or not map.gameplay_open():
		return
	if map.npcs.bring_outlaw(posting.tier.npc_id) != null:
		# TRANSLATORS: native (A2): the bounty's outlaw ({outlaw}) jumps out where the player walks.
		_say([ColoredLine.new(tr("路旁人影一晃，{outlaw}跳了出来！").format({"outlaw": tr(_npc_name(posting.tier.npc_id))}), ColoredLine.HIR)])


## The player's own blow killed `npc`: when it is the bounty's outlaw, the bounty is paid.
func outlaw_killed(npc: NpcRuntimeState) -> void:
	_pay(npc, false)


## The player spared `npc` (放过) as it lay: when it is the bounty's outlaw it is taken to the
## 驿站 and the bounty is paid; no 杀气, no kill counted.
func outlaw_spared(npc: NpcRuntimeState) -> void:
	if _pay(npc, true):
		_escorts.append(npc.character_id)


## The outlaws waiting to be taken away go once no fight holds them.
func _escort() -> void:
	if _escorts.is_empty() or (_session.combat_encounter_coordinator() != null and _session.combat_encounter_coordinator().has_active_encounter()):
		return
	for character_id: StringName in _escorts:
		var npc: NpcRuntimeState = _session.resident_npc(character_id)
		if npc != null and npc.life_status != CharacterRuntimeLifeStatus.Value.DEAD:
			var map: WorldMapController = _session.world_map_of(npc.world_location().map_id)
			if map != null:
				map.npcs.escort_away(npc)
	_escorts.clear()


func _pay(npc: NpcRuntimeState, spared: bool) -> bool:
	var state: CharacterState = _state()
	var posting: Posting = taken()
	if npc == null or state == null or posting == null or npc.definition().definition_id != posting.tier.npc_id:
		return false
	var rules: ProgressionRules = GameContent.catalog().progression()
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	var location: WorldLocationState = _session.player_runtime().world_location()
	var catch_up: int = WorldProgressionRewards.catch_up_percent(state, &"" if location == null else location.zone_id)
	var grant: MilestoneRewards.Grant = MilestoneRewards.award(state, rules, ProgressionRules.Kind.BOUNTY, catch_up, pacing.staged_potential_cap)
	BountyBoard.close(state.bounty, _refresh_ms())
	state.marks[MARK_DONE] = 1
	var lines: Array[ColoredLine] = []
	if spared:
		# TRANSLATORS: native (A2): the player spared the bounty's outlaw ({outlaw}); it is taken to the 驿站.
		lines.append(ColoredLine.new(tr("你把{outlaw}捆了个结实，托路过的官差押往雪亭驿。").format({"outlaw": tr(_npc_name(posting.tier.npc_id))})))
	lines.append_array(MilestoneRewards.lines(grant, tr(_npc_name(posting.tier.npc_id))))
	var paid: int = _give_silver(posting.tier.silver)
	if paid > 0:
		# TRANSLATORS: native (A2): the bounty's silver ({silver}, e.g. 五) the 驿站 pays the player.
		lines.append(ColoredLine.new(tr("雪亭驿付给你{silver}两银子的赏银。").format({"silver": ChineseNumber.of(paid)})))
	var hud: SharedGameplayUI = _session.shared_ui()
	if hud != null:
		hud.append_after_fight(lines)
	return true


## The tier's silver in the player's hands (or at their feet when too heavy).
func _give_silver(amount: int) -> int:
	var map: WorldMapController = _session.active_map() as WorldMapController
	var silver: ItemContentDefinition = GameContent.catalog().currency_item(CurrencyDenomination.Value.SILVER)
	if map == null or silver == null:
		return 0
	var given: int = 0
	for coin: int in amount:
		if not map.give_new_item_to_player(silver.item_definition_id).is_empty():
			given += 1
	return given


func _standing_outlaw(posting: Posting) -> NpcRuntimeState:
	for npc: NpcRuntimeState in _session.world_npcs():
		if npc.definition().definition_id == posting.tier.npc_id and npc.life_status != CharacterRuntimeLifeStatus.Value.DEAD and npc.exists_in_map:
			return npc
	return null


func _outlaw_exp(npc_id: StringName) -> int:
	var npc: NpcDefinition = GameContent.catalog().npc(npc_id)
	return 0 if npc == null else npc.combat_experience


func _refresh_ms() -> int:
	return GameContent.catalog().pacing().bounty_refresh_seconds * 1000


func _state() -> CharacterState:
	var player: WorldPlayerRuntimeState = _session.player_runtime()
	return null if player == null else player.state


func _npc_name(npc_id: StringName) -> String:
	var npc: NpcDefinition = GameContent.catalog().npc(npc_id)
	return "" if npc == null else npc.display_name


func _zone_name(zone_id: StringName) -> String:
	var zone: ZoneDefinition = GameContent.catalog().zone(zone_id)
	return "" if zone == null else zone.display_name


func _region_name(zone_id: StringName) -> String:
	var region: RegionDefinition = WorldProgressionRewards.region_of_zone(zone_id)
	return "" if region == null else region.display_name


func _say(lines: Array[ColoredLine]) -> void:
	var hud: SharedGameplayUI = _session.shared_ui()
	if hud != null:
		hud.append_colored_lines(lines)
