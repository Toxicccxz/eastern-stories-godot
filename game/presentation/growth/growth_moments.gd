class_name GrowthMoments
extends CanvasLayer

## 成长时刻 (DECISIONS「练功演出」): a gain of the player's marked for a moment — a brush stroke
## across the top of the screen with its words (the skill and its level, 习得, 拜入, 任务完成, 获得),
## a sound, and on the player's own figure an art of light (growth.json `moments`). What was
## gained is read off the player's state (GrowthWatch) every check_seconds, whatever gave it.
## One at a time, the others waiting their turn; during a fight they wait for its end (its own
## show has the screen). Over every window (a level gained in the menu is seen there too).
## Presentation only: it takes no input, holds nothing and changes nothing; with the feel's
## growth_moment_ms at 0 nothing is looked at or shown.

const Person = preload("res://presentation/voxel/actors/voxel_person.gd")

## Over the menu (60), the shared frame's dialogs (61) and a training run's band (62); under the
## touch controls (90) and the shell (100).
const LAYER: int = 63
## The gap between one moment and the next.
const GAP: float = 0.15
## The story's things are looked for every this many looks (the pack is put together for it).
const ITEMS_EVERY: int = 4
# TRANSLATORS: 成长时刻, a skill gained a level: {skill} its name, {level} the level now.
const TEXT_SKILL_LEVEL: String = "{skill}　{level} 级"
# TRANSLATORS: 成长时刻, a skill learned for the first time: {skill} its name.
const TEXT_SKILL_LEARNED: String = "习得　{skill}"
# TRANSLATORS: 成长时刻, the maximum of 内力 / 法力 / 灵力 raised: {power} which, {value} the maximum now.
const TEXT_MAXIMUM_UP: String = "{power}上限　{value}"
# TRANSLATORS: 成长时刻, the player became a family's pupil: {family} the family.
const TEXT_APPRENTICED: String = "拜入　{family}"
# TRANSLATORS: 成长时刻, the player took a master who has no family: {master} the master.
const TEXT_MASTER: String = "拜师　{master}"
# TRANSLATORS: 成长时刻, a quest ended: {title} its name.
const TEXT_QUEST_DONE: String = "任务完成　{title}"
# TRANSLATORS: 成长时刻, a thing a story turns on came into the player's hands: {item} its name.
const TEXT_KEY_ITEM: String = "获得　{item}"
const POWER_NAMES: Dictionary[StringName, String] = {
	GrowthWatch.INNER_FORCE: "内力", GrowthWatch.MANA: "法力", GrowthWatch.ATMAN: "灵力",
}

var watch := GrowthWatch.new()
var banner: BattleSpecialBanner
## Each moment shown so far, as [kind, text] (tests, kits), newest last.
var shown: Array[Array] = []
var _session: WorldSessionController
var _queue: Array[GrowthWatch.Moment] = []
var _wait: float = 0.0
var _busy: float = 0.0
var _looks: int = 0
## Whose state was looked at last: another one (a journey loaded) is taken in afresh.
var _state: CharacterState
var _key_items: Array[StringName] = []
var _effects: Array[Node] = []
var _pose: Tween
## The pose the figure was last given here (the bow): it is stood down only while it still has it.
var _posed: String = ""
var _rng := RandomNumberGenerator.new()


func configure(session: WorldSessionController) -> void:
	_session = session


func _ready() -> void:
	layer = LAYER
	# It goes on under the pause, unseen (see _process): a moment begun is not left standing
	# over 系统.
	process_mode = Node.PROCESS_MODE_ALWAYS
	banner = BattleSpecialBanner.new()
	banner.name = "Banner"
	add_child(banner)


func _exit_tree() -> void:
	GrowthFx.clear(_effects)


func _process(delta: float) -> void:
	# Under the pause (系统, the shell's windows) nothing of it is seen or begun.
	var paused: bool = get_tree().paused
	if visible == paused:
		visible = not paused
	if paused or not _on():
		return
	# A fight (or a scene) has the figure now: the bow lets go of it.
	if _pose != null and _pose.is_valid() and not _may_show():
		_pose.kill()
	_wait -= delta
	if _wait <= 0.0:
		look_now()
	_busy = maxf(0.0, _busy - delta)
	if _busy <= 0.0 and not _queue.is_empty() and _may_show():
		_show(_queue.pop_front())


## Whether moments are shown at all now: the feel asks for them and a journey is under way.
func _on() -> bool:
	return _session != null and _session.is_initialized() and _session.player_runtime() != null and GameContent.catalog().pacing().feel.growth_moment_seconds > 0.0


## The player's state looked at now (a continuous run that just ended on a gain does not wait
## for the next look): what was gained joins the queue.
func look_now() -> void:
	if not _on():
		return
	var data: Dictionary = GrowthFx.moments()
	_wait = maxf(0.05, float(data.get("check_seconds", 0.25)))
	var state: CharacterState = _session.player_runtime().state
	if state != _state:
		_state = state
		watch.reset()
		_queue.clear()
		_looks = 0
	if _looks % ITEMS_EVERY == 0:
		_key_items = _held_key_items()
	_looks += 1
	for moment: GrowthWatch.Moment in watch.look(state, _key_items, int(data.get("bulk", 3))):
		_enqueue(moment, int(data.get("queue", 4)))


## What the player is now is taken in afresh and nothing waits: a state made over by hand (the
## 试战台's fighter) is no gain.
func take_in() -> void:
	watch.reset()
	_queue.clear()


## The story's things in the player's pack now (items.json `quest`), by definition id.
func _held_key_items() -> Array[StringName]:
	var held: Array[StringName] = []
	for row: PlayerInventoryRowProjection in _session.player_inventory_rows():
		var content: ItemContentDefinition = GameContent.catalog().item(row.item_definition_id)
		if content != null and content.quest_item and not held.has(row.item_definition_id):
			held.append(row.item_definition_id)
	return held


## `moment` waits its turn. The same skill's level told twice keeps the later; past `most`, the
## oldest small one makes way (else the oldest).
func _enqueue(moment: GrowthWatch.Moment, most: int) -> void:
	if not GrowthFx.moments().get("kinds", {}).has(String(moment.kind)):
		return
	for index: int in _queue.size():
		if _queue[index].kind == moment.kind and _queue[index].subject == moment.subject:
			_queue[index] = moment
			return
	_queue.append(moment)
	while _queue.size() > maxi(1, most):
		var drop: int = 0
		for index: int in _queue.size():
			if _tier_of(_queue[index].kind) == "small":
				drop = index
				break
		_queue.remove_at(drop)


## How many wait (tests).
func waiting() -> int:
	return _queue.size()


static func _tier_of(kind: StringName) -> String:
	return String(GrowthFx.moments().get("kinds", {}).get(String(kind), {}).get("tier", "small"))


## A moment may be shown now: the player is up, and nothing else has the screen — no fight (its
## panel still up over its last lines is the fight still), no scene or fade holding the
## presentation, no closing pages.
func _may_show() -> bool:
	var player: WorldPlayerRuntimeState = _session.player_runtime()
	if player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or player.relationship.is_fighting():
		return false
	var fights: CombatEncounterCoordinator = _session.combat_encounter_coordinator()
	if fights != null and fights.has_active_encounter():
		return false
	return not _session.battle_panel_shown() and not _session.presentation_frozen() and not _session.epilogue_running()


## The words of `moment`, in the shown language.
static func text_of(moment: GrowthWatch.Moment) -> String:
	var catalog: ContentCatalog = GameContent.catalog()
	match moment.kind:
		GrowthWatch.SKILL_LEVEL, GrowthWatch.SKILL_LEARNED:
			var skill: SkillDefinition = catalog.skill(moment.subject)
			var name: String = _t(skill.display_name) if skill != null else String(moment.subject)
			if moment.kind == GrowthWatch.SKILL_LEARNED:
				return _t(TEXT_SKILL_LEARNED).format({"skill": name})
			return _t(TEXT_SKILL_LEVEL).format({"skill": name, "level": moment.value})
		GrowthWatch.MAXIMUM_UP:
			return _t(TEXT_MAXIMUM_UP).format({"power": _t(POWER_NAMES.get(moment.subject, "")), "value": moment.value})
		GrowthWatch.APPRENTICED:
			var family: FamilyDefinition = catalog.family(moment.family_id) if not moment.family_id.is_empty() else null
			if family != null and not family.display_name.is_empty():
				return _t(TEXT_APPRENTICED).format({"family": _t(family.display_name)})
			return _t(TEXT_MASTER).format({"master": _t(moment.master_name)})
		GrowthWatch.QUEST_DONE:
			for quest: StoryQuestDefinition in catalog.story_quests():
				if quest.quest_id == moment.subject:
					return _t(TEXT_QUEST_DONE).format({"title": _t(quest.title)})
			return ""
		GrowthWatch.KEY_ITEM:
			var item: ItemContentDefinition = catalog.item(moment.subject)
			return _t(TEXT_KEY_ITEM).format({"item": _t(item.display_name)}) if item != null else ""
	return ""


func _show(moment: GrowthWatch.Moment) -> void:
	var data: Dictionary = GrowthFx.moments()
	var look: Dictionary = data.get("kinds", {}).get(String(moment.kind), {})
	var tier: Dictionary = data.get("tiers", {}).get(String(look.get("tier", "small")), {})
	var seconds: float = float(tier.get("seconds", 1.0)) * GameContent.catalog().pacing().feel.growth_moment_seconds
	var text: String = text_of(moment)
	if text.is_empty() or seconds <= 0.0:
		return
	var size: Array = tier.get("size", [260, 40])
	var area: Vector2 = banner.get_size()
	var middle := Vector2(area.x / 2.0, area.y * float(data.get("y", 0.2)))
	banner.present(text, middle, Vector2(float(size[0]), float(size[1])), seconds, true, Color(String(look.get("stroke", "3a2a14"))), Color(String(look.get("ink", "ffe6a0"))), int(tier.get("font", 26)))
	shown.append([moment.kind, text])
	_busy = seconds + GAP
	var sound := StringName(String(look.get("sound", "")))
	if not sound.is_empty():
		BattleSounds.cue(sound, float(look.get("pitch", 1.0)), float(look.get("db", 0.0)))
	var model: Node3D = _figure()
	if model == null:
		return
	_effects = GrowthFx.live(_effects)
	_effects.append_array(GrowthFx.play(self, model, String(look.get("art", "")), Color(String(look.get("colour", "ffd98a"))), seconds * 0.9, data.get("light", {}), _rng))
	var person: Person = model as Person
	var pose: String = String(look.get("pose", ""))
	if person != null and Person.REACTIONS.has(pose) and not person.fighting and not person.sitting and not person.walking:
		if _pose != null and _pose.is_valid():
			_pose.kill()
		_posed = pose
		person.take_guard("", seconds * 0.12)
		person.react = pose
		person.react_amount = 0.0
		_pose = create_tween()
		_pose.tween_property(person, "react_amount", 1.0, seconds * 0.2).set_ease(Tween.EASE_OUT)
		_pose.tween_interval(seconds * 0.45)
		_pose.tween_property(person, "react_amount", 0.0, seconds * 0.25).set_ease(Tween.EASE_IN_OUT)
		_pose.tween_callback(_stand.bind(person))


func _stand(person: Variant) -> void:
	# Something else has the figure meanwhile (a fight, a training run begun at once): its guard
	# is theirs, and they have taken the bow off it.
	if is_instance_valid(person) and _on() and _may_show() and (person as Person).react == _posed:
		(person as Person).stand_down(0.2)


## The player's figure on the map shown now, unless a fight has placed the figures (null then).
func _figure() -> Node3D:
	var map: Node = _session.active_map()
	var view: WorldVoxelView = map.get_node_or_null(^"MapView") as WorldVoxelView if map != null else null
	if view == null or view.placing():
		return null
	var actor: Node3D = view.actors.get(_session.player_runtime().character_id)
	return actor.get_child(0) as Node3D if actor != null and actor.get_child_count() > 0 else null


static func _t(text: String) -> String:
	return TranslationServer.translate(text) if not text.is_empty() else ""
