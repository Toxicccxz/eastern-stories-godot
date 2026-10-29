class_name SharedUiNearby
extends RefCounted
## What the player stands by and what can be done with it (owner, 2026-10-17; DECISIONS
## 「说话和交互」): the things in reach (WorldMapSelection.nearby()), the one E / A goes to
## (the target: the nearest, or a near one the player faces; Tab / Y and LB / RB step
## through the others) and everything each offers (options_for()), greyed with the reason
## where the rules refuse it now. A thing that does one thing (a door, an item on the floor,
## a room's service, a sign) does it at once (direct()); the others open the interaction
## popup (InteractionPanel). Clicking or tapping a thing in reach makes it the target and
## interacts with it.
##
## While no panel is open the selection is the NPC the player stands by (the constable
## leading them first, else the nearest), nothing when no NPC is near: the 背包's 给 and
## 画符 go to it. A landmark, corpse or floor item chosen stays while it is in reach.

## A thing the player faces counts as this share of its distance.
const FACING_SHARE: float = 0.6
## Faced: within 60° of where the player looks.
const FACING_DOT: float = 0.5
## The target moves to another thing on its own only when that one is clearly nearer.
const SWITCH_SHARE: float = 0.8

var _ui: SharedGameplayUI
## The things in reach now, nearest first.
var _things: Array[WorldNearbyThing] = []
## The target's key ("kind:id"); "" for none.
var _target_key: String = ""
## The player stepped to the target (Tab, a click): it stays while in reach.
var _chosen: bool = false
## [display name, [labels that can be done]] per thing in reach, for tests and the walk.
var _shown: Array[Array] = []

# The HUD's authorities, read as SharedGameplayUI reads them.
var _session: WorldSessionController:
	get: return _ui._session
var _presentation_layout: SharedGameplayLayout:
	get: return _ui._presentation_layout
var _player: WorldPlayerRuntimeState:
	get: return _ui._player


func _init(ui: SharedGameplayUI) -> void:
	_ui = ui


## The things in reach now, as [shown name, [labels that can be done]], nearest first.
func groups() -> Array[Array]:
	return _shown.duplicate(true)


## The labels the thing named `display_name` (as shown) can do now; [] when none.
func actions_of(display_name: String) -> Array[String]:
	for group: Array in _shown:
		if group[0] == display_name:
			var labels: Array[String] = []
			labels.assign(group[1])
			return labels
	return []


## Does `label` on the thing named `display_name` (as shown), as its popup row would.
## False when it offers no such thing now.
func press(display_name: String, label: String) -> bool:
	var map: WorldMapController = _map()
	for thing: WorldNearbyThing in _things:
		if shown_name(thing) != display_name:
			continue
		for option: InteractionOption in options_for(map, thing):
			if option.label == label and option.available():
				option.action.call()
				return true
	return false


## Called with the card's refresh: the selection follows reach, then the target.
func refresh() -> void:
	var map: WorldMapController = _map()
	# Nothing is offered while a scene holds the player (DECISIONS「剧情演出」).
	if map == null or (_session != null and _session.scene_held()):
		_things.clear()
	else:
		_things = map.selection.nearby()
	# A panel or the menu holds the selection (背包's 给 and 画符 act on it).
	if map != null and not _presentation_layout.frame.visible and not _ui.menu.is_presented():
		_follow_reach(map, _things)
	_pick_target()
	_shown.clear()
	for thing: WorldNearbyThing in _things:
		var labels: Array[String] = []
		for option: InteractionOption in options_for(map, thing):
			if option.available():
				labels.append(option.label)
		if not labels.is_empty():
			_shown.append([shown_name(thing), labels])


## The thing with `id` in reach, or null.
func find(id: StringName) -> WorldNearbyThing:
	for thing: WorldNearbyThing in _things:
		if thing.id == id:
			return thing
	return null


## What E / A goes to now, or null.
func target() -> WorldNearbyThing:
	for thing: WorldNearbyThing in _things:
		if _key(thing) == _target_key:
			return thing
	return null


## The target steps to the next thing in reach (`step` 1) or the one before (-1), by how
## near and faced each is.
func cycle(step: int) -> bool:
	var ranked: Array[WorldNearbyThing] = _ranked()
	if ranked.size() < 2:
		return false
	var at: int = 0
	for index: int in ranked.size():
		if _key(ranked[index]) == _target_key:
			at = index
	_target_key = _key(ranked[posmod(at + step, ranked.size())])
	_chosen = true
	return true


## The thing with `id` (an NPC, a corpse, an item, a landmark) becomes the target when it
## is in reach. False otherwise.
func choose(id: StringName) -> bool:
	for thing: WorldNearbyThing in _things:
		if thing.id == id:
			_target_key = _key(thing)
			_chosen = true
			return true
	return false


## What a thing that does one thing does (a door, an item on the floor, a room's service,
## a sign that is only looked at); null for one whose popup lists its options (an NPC, a
## corpse, a landmark with an action: 放弃 or 抓住藤蔓 is never done by a stray click).
func direct(thing: WorldNearbyThing) -> InteractionOption:
	if thing == null or thing.kind in [WorldNearbyThing.Kind.NPC, WorldNearbyThing.Kind.CORPSE]:
		return null
	var look: InteractionOption = null
	var doing: Array[InteractionOption] = []
	for option: InteractionOption in options_for(_map(), thing):
		if option.label == "查看":
			look = option
		elif option.available():
			doing.append(option)
	if thing.kind == WorldNearbyThing.Kind.LANDMARK:
		return look if doing.is_empty() else null
	return doing[0] if doing.size() == 1 else null


## The prompt over the target: what E / A does there (开门, 拾取, a service's own title) or 交互.
func prompt_text(thing: WorldNearbyThing) -> String:
	var option: InteractionOption = direct(thing)
	if option == null:
		return tr("交互")
	match thing.kind:
		WorldNearbyThing.Kind.SERVICE:
			return thing.services[0].context_title()
		WorldNearbyThing.Kind.DOOR, WorldNearbyThing.Kind.ITEM:
			# TRANSLATORS: the prompt over a door or an item on the floor: {action} what E / A does (打开, 拾取), {thing} its name.
			return tr("{action}{thing}").format({"action": tr(option.label), "thing": tr(thing.display_name)})
	return tr(option.label)


## The ring and prompt's place for the target, or null.
func target_focus() -> WorldFocus:
	var map: WorldMapController = _map()
	var thing: WorldNearbyThing = target()
	if map == null or thing == null:
		return null
	return map.selection.focus_of(thing, prompt_text(thing))


## No panel open: the selection is the NPC the player stands by (`things` is nearest
## first; the constable leading them comes first), or nothing; a landmark, corpse or
## floor item chosen stays while it is in reach.
func _follow_reach(map: WorldMapController, things: Array[WorldNearbyThing]) -> void:
	var selected: WorldInteractionTarget = map.selection.selected_target
	if selected != null and selected.kind != WorldInteractionTarget.Kind.CHARACTER:
		for thing: WorldNearbyThing in things:
			if thing.id == selected.target_id:
				return
	var wanted: WorldNearbyThing = null
	for thing: WorldNearbyThing in things:
		if thing.kind != WorldNearbyThing.Kind.NPC:
			continue
		if map.patrols.can_bribe(thing.npc):
			wanted = thing
			break
		if wanted == null:
			wanted = thing
	if wanted != null:
		if selected == null or selected.target_id != wanted.id:
			map.select_npc(wanted.id)
	elif selected != null:
		map.selection.selected_target = null
		_ui.set_selected_target(null)


## Keeps the target while it is in reach (and, unless the player chose it, while nothing
## is clearly nearer), else the nearest.
func _pick_target() -> void:
	var ranked: Array[WorldNearbyThing] = _ranked()
	if ranked.is_empty():
		_target_key = ""
		_chosen = false
		return
	var current: WorldNearbyThing = target()
	if current == null:
		_target_key = _key(ranked[0])
		_chosen = false
	elif not _chosen and ranked[0] != current and _score(ranked[0]) < _score(current) * SWITCH_SHARE:
		_target_key = _key(ranked[0])


## The things E / A can go to, best first: the nearest, a faced one counting nearer; the
## constable leading the player from afar (his 行贿 only) after everything at hand.
func _ranked() -> Array[WorldNearbyThing]:
	var ranked: Array[WorldNearbyThing] = []
	for thing: WorldNearbyThing in _things:
		if not options_for(_map(), thing).is_empty():
			ranked.append(thing)
	ranked.sort_custom(func(a: WorldNearbyThing, b: WorldNearbyThing) -> bool: return [a.bribe_only, _score(a)] < [b.bribe_only, _score(b)])
	return ranked


func _score(thing: WorldNearbyThing) -> float:
	var map: WorldMapController = _map()
	var focus: WorldFocus = null if map == null else map.selection.focus_of(thing, "")
	var body: WorldCharacterBody2D = null if map == null else map.runtime_player_body()
	if focus == null or body == null or not focus.at().is_finite():
		return thing.distance
	var toward: Vector2 = focus.at() - body.global_position
	if toward.length() > 1.0 and body.facing.dot(toward.normalized()) >= FACING_DOT:
		return thing.distance * FACING_SHARE
	return thing.distance


static func _key(thing: WorldNearbyThing) -> String:
	return "%d:%s" % [thing.kind, thing.id]


func shown_name(thing: WorldNearbyThing) -> String:
	match thing.kind:
		WorldNearbyThing.Kind.NPC:
			return thing.npc.short_name()
		WorldNearbyThing.Kind.CORPSE:
			# The corpse's name at its stage, shown (WorldMapCorpses.corpse_name()).
			return thing.display_name
	return tr(thing.display_name)


## The lines under the popup's title: how the thing is now (warmer) and what it is to the
## player, as look.c says them.
func about(thing: WorldNearbyThing) -> Array[Array]:
	var status: Array[String] = []
	var lines: Array[String] = []
	var map: WorldMapController = _map()
	match thing.kind:
		WorldNearbyThing.Kind.NPC:
			var npc: NpcRuntimeState = thing.npc
			if npc.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS:
				# TRANSLATORS: the HUD's line under an NPC lying unconscious: {n} seconds until it comes to (damage.c revive), rounded up.
				status.append(tr("昏迷不醒，约 {n} 秒后醒来").format({"n": ceili(npc.revive_in_ms / 1000.0)}) if npc.revive_in_ms > 0 else tr("昏迷不醒"))
			if map != null and map.hostilities.toll_pending(npc):
				# TRANSLATORS: the popup's line under a toll-taker about to attack the player (gangster.c's 买路财).
				status.append(tr("正等着你留下买路财"))
			# Above 查看 (its look.c text replaces the lines below once shown): how many of a
			# master's conditions the player meets.
			var conditions: String = _conditions_count(map, thing)
			if not conditions.is_empty():
				status.append(conditions)
			var gender: StringName = npc.character_state.gender
			var pronoun: String = tr(Es2CombatMessages.pronoun(gender))
			if _player != null:
				var relation: String = FamilyRelation.of_npc(_player.state, npc.definition(), gender)
				if not relation.is_empty():
					# TRANSLATORS: look.c: {pronoun} is 他/她/它, {relation} what the NPC is to the player (师父, 同门师兄 …).
					lines.append(tr("{pronoun}是你的{relation}。").format({"pronoun": pronoun, "relation": tr(relation)}))
				var strength: String = RelativeStrength.line(_player.state.progression.combat_experience, npc.character_state.progression.combat_experience)
				if not strength.is_empty():
					lines.append(tr(strength).format({"pronoun": pronoun}))
		WorldNearbyThing.Kind.CORPSE:
			var corpse: CorpseState = null if map == null else map.corpses.find_corpse(thing.id)
			if corpse != null:
				# TRANSLATORS: the popup's line under a corpse: how many things it holds.
				lines.append(tr("里面有{count}件物品。").format({"count": map.corpses.corpse_content_count(corpse)}))
	return [status, lines]


## Everything `thing` offers, in the popup's order; one the rules refuse now carries why.
func options_for(map: WorldMapController, thing: WorldNearbyThing) -> Array[InteractionOption]:
	var offered: Array[InteractionOption] = []
	if map == null or thing == null:
		return offered
	var player_available: bool = (
		_player != null and _player.exists_in_world and _player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
	)
	var actions: SharedUiContextActions = _ui.actions
	match thing.kind:
		WorldNearbyThing.Kind.NPC:
			offered = _npc_options(map, thing, player_available)
		WorldNearbyThing.Kind.CORPSE:
			var corpse: CorpseState = map.corpses.find_corpse(thing.id)
			var view: CombatSliceCorpseView = map.corpses.corpse_view_for(thing.id)
			var pick: Callable = map.select_corpse.bind(thing.id)
			if player_available:
				var reach: bool = view != null and view.is_body_in_loot_range(map.player_body)
				# TRANSLATORS: why 拾取 on a corpse is greyed: the player stands too far from it.
				offered.append(InteractionOption.new("拾取", _after(pick, actions.loot_context), "", false, "" if reach else tr("离得太远，够不着。")))
				if map.spells.corpse_animatable(corpse) != null:
					offered.append(InteractionOption.new(AnimateSpell.WORLD_LABEL, _after(pick, actions.animate_context), SharedUiContextActions.ANIMATE_HINT))
			offered.append(InteractionOption.new("查看", _after(pick, actions.inspect_context)))
		WorldNearbyThing.Kind.ITEM:
			var pick_item: Callable = map.select_floor_item.bind(thing.id)
			if player_available:
				offered.append(InteractionOption.new("拾取", _after(pick_item, actions.loot_context)))
			offered.append(InteractionOption.new("查看", _after(pick_item, actions.inspect_context)))
		WorldNearbyThing.Kind.LANDMARK:
			var landmark: WorldLandmarkDefinition = GameContent.catalog().landmark(thing.id)
			var pick_landmark: Callable = map.select_landmark.bind(thing.id)
			# A dial's turns come before its own action (jitan.c: turn, then press).
			for turn: WorldLandmarkDefinition.Turn in landmark.turns:
				if player_available:
					offered.append(InteractionOption.new(turn.action, _after(pick_landmark, _confirm_landmark.bind(landmark, turn.action, actions.landmark_action_context.bind(turn.count)))))
			# A sign is only looked at.
			if player_available and not landmark.action_label.is_empty():
				offered.append(InteractionOption.new(landmark.action_label, _after(pick_landmark, _confirm_landmark.bind(landmark, landmark.action_label, actions.traverse_context))))
			offered.append(InteractionOption.new("查看", _after(pick_landmark, actions.inspect_context)))
		WorldNearbyThing.Kind.DOOR:
			var door_open: bool = map.doors_by_id[thing.id].is_open()
			offered.append(InteractionOption.new("关闭" if door_open else "打开", (map.close_door if door_open else map.open_door).bind(thing.id)))
		WorldNearbyThing.Kind.SERVICE:
			for service: WorldService in thing.services:
				offered.append(InteractionOption.new(service.verb(), service.interact, "", true))
	return offered


func _npc_options(map: WorldMapController, thing: WorldNearbyThing, player_available: bool) -> Array[InteractionOption]:
	var offered: Array[InteractionOption] = []
	var npc: NpcRuntimeState = thing.npc
	var actions: SharedUiContextActions = _ui.actions
	var select: Callable = map.select_npc.bind(thing.id)
	if thing.bribe_only:
		# The constable leading the player from afar: his 行贿 only (yamen_po.c
		# accept_bribery() asks nothing of where he is).
		if player_available and map.patrols.can_bribe(npc):
			offered.append(InteractionOption.new("行贿", _after(select, actions.bribe_context), SharedUiContextActions.BRIBE_HINT))
		return offered
	var alive: bool = npc.exists_in_map and npc.life_status != CharacterRuntimeLifeStatus.Value.DEAD
	if not alive:
		return offered
	if not player_available:
		offered.append(InteractionOption.new("查看", _after(select, actions.inspect_context)))
		return offered
	var definition: NpcDefinition = npc.definition()
	var name: String = tr(definition.display_name)
	var awake: bool = npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
	var here: bool = map.selection.npc_here(npc) == npc
	if map.selection.can_ask(npc):
		offered.append(InteractionOption.new("打听", _after(select, actions.ask_context)))
	for service: WorldService in thing.services:
		offered.append(InteractionOption.new(service.verb(), _after(select, service.interact), "", true))
		var teacher: TeacherService = service as TeacherService
		if teacher != null and teacher.takes_apprentices():
			# apprentice.c with one's own master is a greeting (向师父请安).
			var own: bool = PlayerKillerReward.is_own_master(_player.state, definition)
			offered.append(InteractionOption.new(
				"请安" if own else "拜师", _after(select, _greet.bind(teacher) if own else _apprentice.bind(teacher)), "", false,
				"" if awake else tr("你必须先把%s弄醒。") % name,
			))
			# What follows a 拜师: the teacher panel's own buttons, here rows on their pages.
			if teacher.awaits_oath():
				offered.append(InteractionOption.new("发誓恪守门规", _after(select, _oath.bind(teacher))))
			if teacher.offers_trial():
				offered.append(InteractionOption.new("接受测试", _after(select, _trial.bind(teacher))))
			if _player.apprenticeship_request.is_pending():
				offered.append(InteractionOption.new("取消拜师请求", _after(select, _cancel_request.bind(teacher))))
	if here:
		# TRANSLATORS: why 给予 is greyed: the NPC ({npc}) lies unconscious and takes nothing (give.c says 这里没有这个人。, which reads wrong beside him; DECISIONS「说话和交互」).
		offered.append(InteractionOption.new("给予", _after(select, _give), "", false, "" if awake else tr("{npc}昏迷不醒，收不了东西。").format({"npc": name})))
	# Fights with an NPC whose skills are not ported yet would abort (fight_deferred, DECISIONS 4E).
	var fightable: bool = not definition.dealings().is_fight_deferred()
	var catalog: ContentCatalog = GameContent.catalog()
	if fightable and definition.can_speak():
		var spar_refusal: String = ""
		if catalog.zone_forbids_fighting(_player.world_location().zone_id):
			spar_refusal = tr("这里禁止战斗。")
		elif not awake:
			spar_refusal = tr("%s已经无法战斗了。") % name
		offered.append(InteractionOption.new("切磋", _after(select, actions.spar_context), "", false, spar_refusal))
	if fightable:
		var forbids: bool = catalog.zone_forbids_fighting(_player.world_location().zone_id) or catalog.zone_forbids_fighting(npc.world_location().zone_id)
		var refusal: String = tr("这里不准战斗。") if forbids else ""
		if definition.spar_only():
			refusal = tr(WorldMapSelection.SPAR_ONLY)
		offered.append(InteractionOption.new("攻击", _after(select, actions.attack_context), "", false, refusal))
	if here and map.thefts.can_steal(npc):
		offered.append(InteractionOption.new("偷窃", _after(select, actions.steal_context), SharedUiContextActions.STEAL_HINT))
	if map.patrols.can_bribe(npc):
		offered.append(InteractionOption.new("行贿", _after(select, actions.bribe_context), SharedUiContextActions.BRIBE_HINT))
	# meloner.c do_return(): the one who caught the player, paid off where he stands.
	if map.debts.can_settle(npc):
		var settle: NpcSettle = definition.dealings().settle
		# TRANSLATORS: a button's hover: {action} its label (还瓜钱), {what} what it does.
		# TRANSLATORS: the interaction popup's confirm page before an NPC's own deal ({action}: 还瓜钱).
		var settle_now: Callable = actions.confirm_in_popup.bind(tr("确定{action}吗？").format({"action": tr(settle.label)}), settle.label, map.debts.settle_here.bind(npc), func() -> bool: return map.debts.can_settle(npc), tr(settle.hint))
		offered.append(InteractionOption.new(settle.label, _after(select, settle_now), tr("{action}：{what}").format({"action": tr(settle.label), "what": tr(settle.hint)})))
	if here and _session.martial_arts().exert_at_functions().has(&"lifeheal"):
		offered.append(InteractionOption.new(ExertFunctions.LABELS[&"lifeheal"], _after(select, actions.lifeheal_context), SharedUiContextActions.LIFEHEAL_HINT))
	if _session.essence_magic().heart_target_for(npc) == npc:
		offered.append(InteractionOption.new(HeartSenseConjure.LABEL, _after(select, actions.heart_sense_context), SharedUiContextActions.HEART_SENSE_HINT))
	offered.append(InteractionOption.new("查看", _after(select, actions.inspect_context)))
	return offered


## 拜师 from the popup, on its confirm page: who the master is (his family, what he
## teaches), his conditions with the player's values (ApprenticeConditions; DECISIONS
## 「上限预览和拜师条件」), the teacher panel's own question when it has one (a betrayal, a
## first master, a change of master), 确认; the answer comes once the popup has closed.
func _apprentice(teacher: TeacherService) -> void:
	var question: Array[String] = teacher.ui.apprentice_question()
	# TRANSLATORS: the 拜师 page's question when no warning applies: {npc} the master.
	var text: String = question[0] if not question[0].is_empty() else tr("确定要拜{npc}为师吗？").format({"npc": tr(teacher.npc.definition().display_name)})
	var choice: String = question[1] if not question[1].is_empty() else "确定拜师"
	var about: String = _profile(teacher)
	var conditions: String = conditions_text(teacher)
	if not conditions.is_empty():
		about += "\n" + conditions
	_ui.questions.ask_first(text, choice, teacher.ui.request_apprentice_now, teacher.can_teach, Callable(), about)


## A master's conditions as the 拜师 page lists them: a heading, then a row each, met (✓)
## or not (✗), or told no more (a test, an oath). "" for none.
func conditions_text(teacher: TeacherService) -> String:
	var rows: Array[ApprenticeConditions.Row] = _player.apprentice_conditions(teacher.npc.definition(), _map().player_can_afford)
	if rows.is_empty():
		return ""
	# TRANSLATORS: the heading of a master's conditions on his 拜师 page.
	var lines: PackedStringArray = [tr("收徒条件：")]
	for row: ApprenticeConditions.Row in rows:
		match row.state:
			ApprenticeConditions.State.MET:
				# TRANSLATORS: a 拜师 condition the player meets: {condition} the condition.
				lines.append(tr("· {condition} ✓").format({"condition": row.text}))
			ApprenticeConditions.State.UNMET:
				# TRANSLATORS: a 拜师 condition the player does not meet.
				lines.append(tr("· {condition} ✗").format({"condition": row.text}))
			_:
				# TRANSLATORS: a 拜师 condition told no more before (a test, an oath).
				lines.append(tr("· {condition}").format({"condition": row.text}))
	return "\n".join(lines)


## 查看's line for a master who takes apprentices (not the player's own): how many of his
## conditions the player meets; the 拜师 page lists them. "" for none.
func _conditions_count(map: WorldMapController, thing: WorldNearbyThing) -> String:
	for service: WorldService in thing.services:
		var teacher: TeacherService = service as TeacherService
		if teacher == null or not teacher.takes_apprentices() or map == null:
			continue
		if teacher.teaching().apprentice.kind == NpcTeaching.Kind.REFUSES:
			# TRANSLATORS: 查看's line for one who takes no apprentice (annihi.c).
			return tr("不收徒。")
		var counts: Array[int] = ApprenticeConditions.counts(_player.apprentice_conditions(thing.npc.definition(), map.player_can_afford))
		if counts[1] == 0:
			return ""
		if counts[0] == counts[1]:
			# TRANSLATORS: 查看's line for a master whose told conditions the player all meets (the 拜师 page lists them).
			return tr("拜师条件都已满足（详见拜师）。")
		# TRANSLATORS: 查看's line for a master: {missing} of his told conditions the player does not meet.
		return tr("拜师条件还差 {missing} 项（详见拜师）。").format({"missing": counts[1] - counts[0]})
	return ""


## 请安 to one's own master: done at once.
static func _greet(teacher: TeacherService) -> void:
	teacher.ui.request_apprentice_now()


## The oath a master waits for (萧辟尘), on its confirm page.
func _oath(teacher: TeacherService) -> void:
	var question: Array[String] = teacher.ui.oath_question()
	# TRANSLATORS: the oath page's question when no warning applies: {npc} the master.
	var text: String = question[0] if not question[0].is_empty() else tr("确定向{npc}发誓恪守门规吗？").format({"npc": tr(teacher.npc.definition().display_name)})
	_ui.questions.ask_first(text, "确定发誓", teacher.ui.swear_now, teacher.awaits_oath, Callable(), _profile(teacher))


## The master's accept test (三招, 三鞭), on its confirm page; told once the popup closes.
func _trial(teacher: TeacherService) -> void:
	var question: Array[String] = teacher.ui.trial_question()
	_ui.questions.ask_first(question[0], question[1], teacher.ui.take_trial_now, teacher.offers_trial, Callable(), _profile(teacher))


## Withdrawing a 拜师 request still waiting (apprentice.c's cancel), on its confirm page.
func _cancel_request(teacher: TeacherService) -> void:
	var request: NpcApprenticeship = _player.apprenticeship_request
	# TRANSLATORS: the confirm page before withdrawing a 拜师 request that still waits for an answer.
	_ui.actions.confirm_in_popup(tr("确定取消拜师请求吗？"), "确定取消", teacher.cancel_apprentice, request.is_pending, _profile(teacher))


## Who a master is, above his pages: his name and title, his family, what he teaches.
func _profile(teacher: TeacherService) -> String:
	var catalog: ContentCatalog = GameContent.catalog()
	var lines: PackedStringArray = [teacher.npc.short_name()]
	var family: FamilyDefinition = catalog.family(teacher.teaching().family_id)
	if family != null:
		# TRANSLATORS: a master's family on his 拜师 page.
		lines.append(tr("门派：{family}").format({"family": tr(family.display_name)}))
	var skills: PackedStringArray = []
	for skill_id: StringName in teacher.teachable_skills():
		skills.append(tr(catalog.skill(skill_id).display_name))
	if not skills.is_empty():
		# TRANSLATORS: what a master teaches, on his 拜师 page: {skills} the skills, joined by 、.
		# TRANSLATORS: joins the skills a master teaches on his 拜师 page (基本拳脚、基本招架).
		lines.append(tr("传授：{skills}").format({"skills": tr("、").join(skills)}))
	return "\n".join(lines)


## A landmark's action in the popup, on its confirm page: the landmark as it is described,
## then the action.
func _confirm_landmark(landmark: WorldLandmarkDefinition, label: String, act: Callable) -> void:
	# TRANSLATORS: the interaction popup's confirm page before a landmark's action ({action}: 抓住藤蔓, 顺时针转).
	_ui.actions.confirm_in_popup(tr("确定{action}吗？").format({"action": tr(label)}), label, act, Callable(), tr(landmark.description).strip_edges())


## 给予 from the popup: its page, the things carried with 给 to the selected NPC.
func _give() -> void:
	_ui.items.open_give()


## `select` first (the thing is the one the action works on), then `action` if it took.
static func _after(select: Callable, action: Callable) -> Callable:
	return func() -> void:
		if select.call():
			action.call()


## The session's map now (the HUD binds a new one only on its next _process).
func _map() -> WorldMapController:
	if _session != null and _session.is_initialized() and _session.active_map_child_count() > 0:
		return _session.active_map() as WorldMapController
	return null
