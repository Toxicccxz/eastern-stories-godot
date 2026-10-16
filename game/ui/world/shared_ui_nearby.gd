class_name SharedUiNearby
extends RefCounted
## The status card's actions for what is near (owner, 2026-10-11): one list item per thing
## in reach (WorldMapSelection.nearby()), its name on top and its own buttons below; a thing that leaves
## reach takes its group with it. Groups keep their places while their things stay near
## (a newcomer joins at the end, nearest first), so a button does not move under the
## pointer as NPCs walk about. Clicking the world selects nothing: a button selects its
## thing, then does what the old context button did. While no panel is open the
## selection is the NPC the player stands by (the constable leading them first, else the
## nearest), nothing when no NPC is near: the 背包's 给 and 画符 go to it. A landmark,
## corpse or floor item the player chose stays selected while it is in reach.
##
## Keys and pad move through the groups' buttons in this order (SharedGameplayUI's card
## list); the groups are rebuilt only when what they offer changes, and a rebuild keeps
## the focus on the same place in the list.

var _ui: SharedGameplayUI
## What the shown groups offer ("kind:id:label,label|..."): unchanged, nothing is rebuilt.
var _shown_signature: String = ""
## The shown groups' keys ("kind:id") in their order on the card.
var _order: Array[String] = []
## [display name, [labels]] per shown group, for tests and the walk.
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


## The groups now, as [shown name, [button labels]], nearest first.
func groups() -> Array[Array]:
	return _shown.duplicate(true)


## The labels the group of the thing named `display_name` (as shown) offers; [] when none.
func actions_of(display_name: String) -> Array[String]:
	for group: Array in _shown:
		if group[0] == display_name:
			var labels: Array[String] = []
			labels.assign(group[1])
			return labels
	return []


## Presses the button `label` in the group named `display_name` (as shown). False when
## there is no such button.
func press(display_name: String, label: String) -> bool:
	for row: Node in _presentation_layout.nearby.get_children():
		if row.is_queued_for_deletion() or String(row.get_meta(&"shown_name", "")) != display_name:
			continue
		for child: Node in row.find_children("*", "Button", true, false):
			var button := child as Button
			if button != null and button.text == label:
				button.pressed.emit()
				return true
	return false


## Called with the card's refresh: the selection follows reach, then the groups.
func refresh() -> void:
	# The session's map now (the HUD binds a new one only on its next _process).
	var map: WorldMapController = null
	if _session != null and _session.is_initialized() and _session.active_map_child_count() > 0:
		map = _session.active_map() as WorldMapController
	var things: Array[WorldNearbyThing] = [] if map == null else map.selection.nearby()
	# A panel or the menu holds the selection (背包's 给 and 画符 act on it).
	if map != null and not _presentation_layout.frame.visible and not _ui.menu.is_presented():
		_follow_reach(map, things)
	things = _keep_order(things)
	var commands: Array[Array] = []
	for thing: WorldNearbyThing in things:
		var offered: Array[Array] = _commands(map, thing)
		if not offered.is_empty():
			commands.append([thing, offered])
	var signature: PackedStringArray = []
	for entry: Array in commands:
		var thing: WorldNearbyThing = entry[0]
		var labels: PackedStringArray = []
		for command: Array in entry[1]:
			labels.append(command[0])
		signature.append("%d:%s:%s:%s" % [thing.kind, thing.id, shown_name(thing), ",".join(labels)])
	var joined: String = "|".join(signature)
	_presentation_layout.nearby.visible = not commands.is_empty()
	if joined != _shown_signature:
		_shown_signature = joined
		_rebuild(commands)
	_refresh_states(map)


## How each NPC listed is now, refreshed with the card (DECISIONS「响应性」: waits are seen):
## one lying unconscious says when it comes to (damage.c's revive call_out); a toll-taker
## about to attack has its name in red.
func _refresh_states(map: WorldMapController) -> void:
	for row: Node in _presentation_layout.nearby.get_children():
		if row.is_queued_for_deletion() or not row.has_meta(&"npc_id") or map == null:
			continue
		var npc: NpcRuntimeState = map.npcs.find_resident_npc(row.get_meta(&"npc_id"))
		var status: Label = row.get_node_or_null("Item/Status")
		var name_label: Label = row.get_node_or_null("Item/Name")
		if npc == null or status == null or name_label == null:
			continue
		var text: String = ""
		if npc.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS and npc.revive_in_ms > 0:
			# TRANSLATORS: the HUD's line under an NPC lying unconscious: {n} seconds until it comes to (damage.c revive), rounded up.
			text = tr("昏迷不醒，约 {n} 秒后醒来").format({"n": ceili(npc.revive_in_ms / 1000.0)})
		status.text = text
		status.visible = not text.is_empty()
		var color: Color = SharedGameplayUI.ALERT_COLOR if map.hostilities.toll_pending(npc) else SharedGameplayLayout.ACCENT_COLOR
		name_label.add_theme_color_override("font_color", color)


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


## `things` (nearest first) in the card's order: those already shown keep their places,
## newcomers follow, nearest first.
func _keep_order(things: Array[WorldNearbyThing]) -> Array[WorldNearbyThing]:
	var by_key: Dictionary[String, WorldNearbyThing] = {}
	for thing: WorldNearbyThing in things:
		by_key["%d:%s" % [thing.kind, thing.id]] = thing
	var ordered: Array[WorldNearbyThing] = []
	var keys: Array[String] = []
	for key: String in _order:
		if by_key.has(key):
			ordered.append(by_key[key])
			keys.append(key)
			by_key.erase(key)
	for thing: WorldNearbyThing in things:
		var key: String = "%d:%s" % [thing.kind, thing.id]
		if by_key.has(key):
			ordered.append(thing)
			keys.append(key)
	_order = keys
	return ordered


func shown_name(thing: WorldNearbyThing) -> String:
	match thing.kind:
		WorldNearbyThing.Kind.NPC:
			return thing.npc.short_name()
		WorldNearbyThing.Kind.CORPSE:
			return tr("%s的尸体") % tr(thing.display_name)
	return tr(thing.display_name)


## [label, action, tooltip(, accent)] for each button the thing offers now, in the HUD's
## order; a service's (the old context button) keeps its accent.
func _commands(map: WorldMapController, thing: WorldNearbyThing) -> Array[Array]:
	var offered: Array[Array] = []
	var player_available: bool = (
		_player != null and _player.exists_in_world and _player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
	)
	match thing.kind:
		WorldNearbyThing.Kind.NPC:
			var npc: NpcRuntimeState = thing.npc
			if thing.bribe_only:
				# The constable leading the player from afar: his 行贿 only (yamen_po.c
				# accept_bribery() asks nothing of where he is).
				if player_available and map.patrols.can_bribe(npc):
					offered.append(["行贿", _after(map.select_npc.bind(thing.id), _ui.actions.bribe_context), SharedUiContextActions.BRIBE_HINT])
				return offered
			for service: WorldService in thing.services:
				offered.append([service.verb(), service.interact, "", true])
			var alive: bool = npc.exists_in_map and npc.life_status != CharacterRuntimeLifeStatus.Value.DEAD
			var select: Callable = map.select_npc.bind(thing.id)
			var actions: SharedUiContextActions = _ui.actions
			# Fights with an NPC whose skills are not ported yet would abort (fight_deferred, DECISIONS 4E).
			var fightable: bool = alive and not npc.definition().dealings().is_fight_deferred() and player_available
			var here: bool = alive and player_available and map.selection.npc_here(npc) == npc
			if alive:
				offered.append(["查看", _after(select, actions.inspect_context), ""])
			if fightable:
				offered.append(["攻击", _after(select, actions.attack_context), ""])
			if fightable and npc.definition().can_speak():
				offered.append(["切磋", _after(select, actions.spar_context), ""])
			if player_available and map.selection.can_ask(npc):
				offered.append(["打听", _after(select, actions.ask_context), ""])
			if here and _session.martial_arts().exert_at_functions().has(&"lifeheal"):
				offered.append([ExertFunctions.LABELS[&"lifeheal"], _after(select, actions.lifeheal_context), SharedUiContextActions.LIFEHEAL_HINT])
			if alive and player_available and _session.essence_magic().heart_target_for(npc) == npc:
				offered.append([HeartSenseConjure.LABEL, _after(select, actions.heart_sense_context), SharedUiContextActions.HEART_SENSE_HINT])
			if here and map.thefts.can_steal(npc):
				offered.append(["偷窃", _after(select, actions.steal_context), SharedUiContextActions.STEAL_HINT])
			if alive and player_available and map.patrols.can_bribe(npc):
				offered.append(["行贿", _after(select, actions.bribe_context), SharedUiContextActions.BRIBE_HINT])
			# meloner.c do_return(): the one who caught the player, paid off where he stands.
			if alive and player_available and map.debts.can_settle(npc):
				var settle: NpcSettle = npc.definition().dealings().settle
				# TRANSLATORS: a button's hover: {action} its label (还瓜钱), {what} what it does.
				offered.append([settle.label, _after(select, map.debts.settle_here.bind(npc)), tr("{action}：{what}").format({"action": tr(settle.label), "what": tr(settle.hint)})])
		WorldNearbyThing.Kind.CORPSE:
			var corpse: CorpseState = map.corpses.find_corpse(thing.id)
			var view: CombatSliceCorpseView = map.corpses.corpse_view_for(thing.id)
			var pick: Callable = map.select_corpse.bind(thing.id)
			offered.append(["查看", _after(pick, _ui.actions.inspect_context), ""])
			if player_available and view != null and view.is_body_in_loot_range(map.player_body):
				offered.append(["拾取", _after(pick, _ui.actions.loot_context), ""])
			if player_available and map.spells.corpse_animatable(corpse) != null:
				offered.append([AnimateSpell.WORLD_LABEL, _after(pick, _ui.actions.animate_context), SharedUiContextActions.ANIMATE_HINT])
		WorldNearbyThing.Kind.ITEM:
			var pick_item: Callable = map.select_floor_item.bind(thing.id)
			offered.append(["查看", _after(pick_item, _ui.actions.inspect_context), ""])
			if player_available:
				offered.append(["拾取", _after(pick_item, _ui.actions.loot_context), ""])
		WorldNearbyThing.Kind.LANDMARK:
			var landmark: WorldLandmarkDefinition = GameContent.catalog().landmark(thing.id)
			var pick_landmark: Callable = map.select_landmark.bind(thing.id)
			offered.append(["查看", _after(pick_landmark, _ui.actions.inspect_context), ""])
			# A dial's turns come before its own action (jitan.c: turn, then press).
			for turn: WorldLandmarkDefinition.Turn in landmark.turns:
				if player_available:
					offered.append([turn.action, _after(pick_landmark, _ui.actions.landmark_action_context.bind(turn.count)), ""])
			# A sign is only looked at.
			if player_available and not landmark.action_label.is_empty():
				offered.append([landmark.action_label, _after(pick_landmark, _ui.actions.traverse_context), ""])
		WorldNearbyThing.Kind.DOOR:
			var door_open: bool = map.doors_by_id[thing.id].is_open()
			offered.append(["关闭" if door_open else "打开", (map.close_door if door_open else map.open_door).bind(thing.id), ""])
		WorldNearbyThing.Kind.SERVICE:
			for service: WorldService in thing.services:
				offered.append([service.verb(), service.interact, "", true])
	return offered


## `select` first (the thing is the one the action works on), then `action` if it took.
static func _after(select: Callable, action: Callable) -> Callable:
	return func() -> void:
		if select.call():
			action.call()


func _rebuild(commands: Array[Array]) -> void:
	var container: VBoxContainer = _presentation_layout.nearby
	# Where the keys' or pad's focus was in the list: it stays there.
	var focused: Control = container.get_viewport().gui_get_focus_owner() if container.is_inside_tree() else null
	var place := Vector2i(-1, -1)
	if focused != null and container.is_ancestor_of(focused):
		place = Vector2i(focused.get_parent().get_parent().get_parent().get_index(), focused.get_index())
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
	_shown.clear()
	for entry: Array in commands:
		var thing: WorldNearbyThing = entry[0]
		var title: String = shown_name(thing)
		var row: PanelContainer = _presentation_layout.nearby_row(title)
		row.set_meta(&"shown_name", title)
		if thing.kind == WorldNearbyThing.Kind.NPC:
			row.set_meta(&"npc_id", thing.id)
		var labels: Array[String] = []
		for command: Array in entry[1]:
			var button: Button = _presentation_layout.nearby_button(row, command[0], command[1])
			# The source text: the button translates it itself.
			button.tooltip_text = command[2]
			if command.size() > 3 and command[3]:
				button.theme_type_variation = &"AccentButton"
			labels.append(button.text)
		container.add_child(row)
		_shown.append([title, labels])
	if _ui.card_nav_active() and container.is_inside_tree() and (place.x >= 0 or container.get_viewport().gui_get_focus_owner() == null):
		if commands.is_empty():
			_ui.leave_card_nav()
		else:
			_ui.focus_card(maxi(place.x, 0), maxi(place.y, 0))
