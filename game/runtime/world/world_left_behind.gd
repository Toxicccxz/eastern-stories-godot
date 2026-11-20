class_name WorldLeftBehind
extends RefCounted

## Native (全项目审查 补充 D; DECISIONS「尸体和走散的同伴」): what the player left on the road, read
## from the world as it stands, and so from a save as it was loaded: their own corpses with
## something still in them, and those who follow them every way (NpcHooks.follows_every_way) and
## stand apart from them. Nothing of it is saved of its own; a corpse emptied or a follower back
## at the player's side is gone from it. The 任务 page, the 沙盘, the hint after the return to
## life and the quest arrow read it.


## One thing left behind.
class Place:
	extends RefCounted
	## MapAtlas.CORPSE or MapAtlas.FOLLOWER.
	var kind: StringName
	## The corpse's item instance ID, the follower's character ID.
	var id: StringName
	## The follower's NPC definition (none for a corpse).
	var definition_id: StringName
	## The follower's display name, untranslated (none for a corpse).
	var who: String
	var map_id: StringName
	var zone_id: StringName
	## The follower lies unconscious.
	var down: bool = false


## The player's own corpses with something still in them, wherever they lie.
static func corpses(session: WorldSessionController) -> Array[Place]:
	var found: Array[Place] = []
	var player: WorldPlayerRuntimeState = null if session == null else session.player_runtime()
	if player == null:
		return found
	for map: WorldMapController in session.world_maps():
		for corpse: CorpseState in map.corpses.corpse_states():
			if corpse.victim_character_id != player.character_id or map.corpses.corpse_content_count(corpse) <= 0:
				continue
			var location: WorldLocationState = map.corpses.corpse_world_location(corpse.corpse_item_instance_id)
			if location == null:
				continue
			var place := Place.new()
			place.kind = MapAtlas.CORPSE
			place.id = corpse.corpse_item_instance_id
			place.map_id = map.map_id()
			place.zone_id = location.zone_id
			found.append(place)
	return found


## Who follows the player every way and does not stand with them: on another map, or in another
## room of this one (lying where they fell, kept back by a shut door, left behind by a move that
## took nobody along).
static func followers_apart(session: WorldSessionController) -> Array[Place]:
	var found: Array[Place] = []
	var player: WorldPlayerRuntimeState = null if session == null else session.player_runtime()
	var here: WorldLocationState = null if player == null else player.world_location()
	if here == null:
		return found
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			if not follows_every_way(npc):
				continue
			var location: WorldLocationState = npc.world_location()
			if location == null or (map.map_id() == here.map_id and location.zone_id == here.zone_id):
				continue
			var place := Place.new()
			place.kind = MapAtlas.FOLLOWER
			place.id = npc.character_id
			place.definition_id = npc.definition().definition_id
			place.who = npc.definition().display_name
			place.map_id = map.map_id()
			place.zone_id = location.zone_id
			place.down = npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE
			found.append(place)
	return found


## Whether `npc` is one of those who follow the player every way now (its follow mark kept),
## alive, in the world: standing or knocked down.
static func follows_every_way(npc: NpcRuntimeState) -> bool:
	var hooks: NpcHooks = npc.definition().hooks()
	return (
		hooks != null and hooks.follows_every_way and npc.has_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER)
		and npc.exists_in_map and npc.life_status != CharacterRuntimeLifeStatus.Value.DEAD
	)


## Both, the corpses first.
static func all(session: WorldSessionController) -> Array[Place]:
	var found: Array[Place] = corpses(session)
	found.append_array(followers_apart(session))
	return found


## The 沙盘's marks for them (MapAtlas.Mark: a corpse is 你的尸体, a follower named).
static func marks(session: WorldSessionController) -> Array[MapAtlas.Mark]:
	var result: Array[MapAtlas.Mark] = []
	for place: Place in all(session):
		var mark := MapAtlas.Mark.new()
		mark.kind = place.kind
		# TRANSLATORS: a mark on the 地图 page: where the player's own corpse lies, with their things.
		mark.who = "你的尸体" if place.kind == MapAtlas.CORPSE else place.who
		mark.map_id = place.map_id
		mark.zone_id = place.zone_id
		result.append(mark)
	return result


## The quest arrow's goal while a follower stands apart (DECISIONS「尸体和走散的同伴」): the first
## one apart, null when none is.
static func follower_goal(session: WorldSessionController) -> MapAtlas.Goal:
	var apart: Array[Place] = followers_apart(session)
	if apart.is_empty():
		return null
	var goal := MapAtlas.Goal.new()
	goal.map_id = apart[0].map_id
	goal.zone_id = apart[0].zone_id
	goal.npc_ids = [apart[0].definition_id]
	return goal


## One line for the 任务 page and the hint after the return to life, in the shown language.
static func line(session: WorldSessionController, place: Place) -> String:
	var where: String = _place_name(session, place)
	if place.kind == MapAtlas.CORPSE:
		# TRANSLATORS: where the player's corpse lies with their things ({place}: region · room).
		return TranslationServer.translate("你的尸体和留在上面的东西还在：{place}").format({"place": where})
	if place.down:
		# TRANSLATORS: a follower ({name}) lies knocked down where the player left them ({place}).
		return TranslationServer.translate("{name}倒在{place}，没能跟上你。").format({"name": TranslationServer.translate(place.who), "place": where})
	# TRANSLATORS: a follower ({name}) who follows the player waits apart from them ({place}).
	return TranslationServer.translate("{name}还在{place}等你。").format({"name": TranslationServer.translate(place.who), "place": where})


## Whether someone who attacks the player on sight stands, up and free, where corpse `corpse_id`
## lies: an empty-handed return there means a fight first.
static func corpse_guarded(session: WorldSessionController, corpse_id: StringName) -> bool:
	var player: WorldPlayerRuntimeState = null if session == null else session.player_runtime()
	if player == null or corpse_id.is_empty():
		return false
	for map: WorldMapController in session.world_maps():
		if map.corpses.find_corpse(corpse_id) == null:
			continue
		var lies: WorldLocationState = map.corpses.corpse_world_location(corpse_id)
		if lies == null:
			return false
		var parley: bool = GameContent.catalog().pacing().story_parley
		for npc: NpcRuntimeState in map.npc_runtimes():
			var location: WorldLocationState = npc.world_location()
			if (
				npc.exists_in_map and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
				and location != null and location.shares_combat_location(lies)
				and (npc.definition().attacks_on_sight(npc.flags(), player.state, parley) or _attacks_on_arrival(npc.definition()))
			):
				return true
		return false
	return false


## LPC attitude killer, or an act on the player's arrival that asks nothing and starts a fight
## (淳于怀太's 呔！ then kill_ob()): one who will fall on the player coming back.
static func _attacks_on_arrival(definition: NpcDefinition) -> bool:
	if definition.attitude == NpcDefinition.Attitude.KILLER:
		return true
	var hooks: NpcHooks = definition.hooks()
	if hooks == null:
		return false
	for call: NpcHooks.Call in hooks.calls:
		var act: ScriptedAct = call.act
		if (
			act != null and act.mark.is_empty() and act.marks.is_empty() and act.when == null and act.temp.is_empty()
			and act.steps.any(func(step: ScriptedAct.Step) -> bool: return step.kind == ScriptedAct.Kind.KILL)
		):
			return true
	return false


## "老松岭 · 南坡林道" (WorldSessionController.place_name()), by the zone alone.
static func _place_name(_session: WorldSessionController, place: Place) -> String:
	var catalog: ContentCatalog = GameContent.catalog()
	var zone: ZoneDefinition = catalog.zone(place.zone_id)
	var map: MapDefinition = null if zone == null else catalog.map(zone.map_id)
	var region: RegionDefinition = null if map == null else catalog.region(map.region_id)
	if region == null:
		return ""
	return "%s · %s" % [TranslationServer.translate(region.display_name), TranslationServer.translate(zone.display_name)]
