class_name SharedGameplayUI
extends CanvasLayer
## The exploration HUD: the status card, the target's prompt and the interaction popup,
## the shared panel frame, the toasts (laid out by SharedGameplayLayout) and the menu
## window (GameMenu). This class keeps the Node lifecycle, the
## widgets the layout fills and the constants other scripts read; the rest lives in its
## components (message_log, card, selection, actions, ask, items, panels, questions), and
## every public method here forwards to one of them.

const MAX_LOG_LINES: int = 60
const WorldPlayerRuntimeType := preload(
	"res://runtime/characters/world_player_runtime_state.gd"
)

## The status card: the player's name, the place (world_title), 精/气/神 as bars with
## their numbers, and the conditions line (player_vitality_text, 蛇毒).
var player_name: Label
var world_title: Label
var player_essence: ProgressBar
var player_essence_text: Label
var player_vitality: ProgressBar
var player_vitality_value: Label
var player_spirit: ProgressBar
var player_spirit_text: Label
var player_vitality_text: Label
## The 目标 row (前两小时 A): a guide chain's next step.
var player_objective: Label
var selected_target_label: Label
var target_vitality: ProgressBar
var target_vitality_text: Label
var inspect_button: Button
var attack_button: Button
var spar_button: Button
var ask_button: Button
var portal_button: Button
var open_loot_button: Button
## 驱尸 (necromancy/animate.c) on the selected corpse, when the player's spells reach it.
var animate_button: Button
## 疗伤他人 (lotusforce/lifeheal.c) on the selected NPC, when the player's force reaches it.
var lifeheal_button: Button
## 心识神通 (essencemagic/heart_sense.c) on the selected NPC lying unconscious, when the
## player's magic reaches it.
var heart_sense_button: Button
## 游识神通's question (DriftSensePanel), opened from the 武学 page.
var drift_panel: DriftSensePanel
## steal <item> from the selected NPC (cmds/std/steal.c): its list (StealPanel).
var steal_button: Button
var steal_panel: StealPanel
## bribe the constable leading the player (d/choyin/npc/yamen_po.c accept_bribery()): BribePanel.
var bribe_button: Button
var bribe_panel: BribePanel
## The menu window and its pages (角色, 武学, 背包 with 随身补给, 任务 with the log).
var menu: GameMenu
var character_sheet: CharacterSheet
var arts_page: MartialArtsPage
var inventory_page: VBoxContainer
var supplies_mount: VBoxContainer
var journal_page: VBoxContainer
## 任务: quest.c's lines for 朱鸿雪's task.
var quest_text: Label
## 任务: the story chains recorded (JournalLog).
var journal_stories: JournalStories
var codex_page: CodexPage
## How many entries the 任务 page showed when it was filled last.
var _journal_shown: int = -1
var inspection_text: RichTextLabel
var combat_log: RichTextLabel
var loot_panel: OldPineLootPanel
var inventory_panel: PlayerInventoryPanel
## Asked in the shared frame before an important or deadly choice (ask_first()).
var confirm_prompt: ConfirmPrompt

# TRANSLATORS: asked before 攻击 on the player's own master: killing them is killing one's master (killer_reward(), betrayal's cost). {master} the NPC, {family} the player's family (封山剑派), {score} the player's 综合评价 now, {next} the betrayals counted after it.
const MASTER_ATTACK_WARNING: String = "{master}是你的师父。攻击就是生死相搏；若你亲手杀了{master}，便是弑师，等同背叛师门：\n· 被逐出{family}，门派、师父和称号都没有了。\n· 综合评价清零（现在是 {score}）。\n· 背叛师门的次数变成 {next} 次。\n确定要攻击吗？"

var _player: WorldPlayerRuntimeType
const ALERT_COLOR: Color = Color(1.0, 0.38, 0.38)
## Plain log text is a light grey, so ES2's HIW (bright white) stands out from it
## (owner, modern fixes II); the log, the toasts and the battle log share it.
const PLAIN_LOG_COLOR: Color = Color(0.78, 0.79, 0.76)
## How include/ansi.h's bright colours look in the log and in the HUD's toasts.
const ES2_COLORS: Dictionary[StringName, Color] = {
	ColoredLine.HIR: ALERT_COLOR,
	ColoredLine.HIY: Color(1.0, 0.9, 0.35),
	ColoredLine.HIC: Color(0.45, 0.92, 1.0),
	ColoredLine.HIW: Color(1.0, 1.0, 1.0),
	ColoredLine.HIM: Color(1.0, 0.5, 1.0),
	ColoredLine.HIG: Color(0.45, 1.0, 0.45),
	ColoredLine.HIB: Color(0.5, 0.62, 1.0),
	ColoredLine.CYN: Color(0.3, 0.75, 0.8),
	ColoredLine.RED: Color(0.82, 0.24, 0.24),
	ColoredLine.GRN: Color(0.35, 0.78, 0.35),
}
var _presentation_layout: SharedGameplayLayout
var life_overlay: PlayerLifeOverlay
## The fade and the place's banner around a map change (DECISIONS「手感」).
var view_overlay: WorldViewOverlay
## The ring and prompt on what E / A goes to (DECISIONS「手感」,「说话和交互」).
var focus_marker: WorldFocusMarker
## The interaction popup (DECISIONS「说话和交互」): what the target is and offers.
var interaction_panel: InteractionPanel
## What NPCs say, over their heads (DECISIONS「手感」).
var speech_bubbles: WorldSpeechBubbles
var _session: WorldSessionController
var _bound_map: WorldResidentMapController
var _elapsed: float = 0.0

## Constants that moved with their components, still readable here.
const ARMED_SPAR_WARNING := SharedUiContextActions.ARMED_SPAR_WARNING
const DEADLY_SPAR_WARNING := SharedUiContextActions.DEADLY_SPAR_WARNING
const STRONGER_SPAR_WARNING := SharedUiContextActions.STRONGER_SPAR_WARNING
const ARMED_STRONGER_SPAR_WARNING := SharedUiContextActions.ARMED_STRONGER_SPAR_WARNING
const ANIMATE_FAINT_WARNING := SharedUiContextActions.ANIMATE_FAINT_WARNING
const LIFEHEAL_HINT := SharedUiContextActions.LIFEHEAL_HINT
const HEART_SENSE_HINT := SharedUiContextActions.HEART_SENSE_HINT
const HEART_SENSE_WARNING := SharedUiContextActions.HEART_SENSE_WARNING
const HEART_SURE_FAIL := SharedUiContextActions.HEART_SURE_FAIL
const HEART_MAY_FAIL := SharedUiContextActions.HEART_MAY_FAIL
const HEART_SPENT := SharedUiContextActions.HEART_SPENT
const STEAL_HINT := SharedUiContextActions.STEAL_HINT
const BRIBE_HINT := SharedUiContextActions.BRIBE_HINT
const STRONGER_STEAL_WARNING := SharedUiContextActions.STRONGER_STEAL_WARNING
const ANIMATE_HINT := SharedUiContextActions.ANIMATE_HINT
const ORDINATION_WARNING := SharedUiAskPanel.ORDINATION_WARNING
const DISSOLVE_WARNING := SharedUiInventory.DISSOLVE_WARNING
const HANG_WARNING := SharedUiInventory.HANG_WARNING
const SCRIBE_FAINT_WARNING := SharedUiInventory.SCRIBE_FAINT_WARNING
const SCRIBE_DEATH_WARNING := SharedUiInventory.SCRIBE_DEATH_WARNING
const HAUNT_MASTER_WARNING := SharedUiInventory.HAUNT_MASTER_WARNING
const GIVE_MONEY_ASK_AT := SharedUiInventory.GIVE_MONEY_ASK_AT
const GIVE_EQUIPPED_WARNING := SharedUiInventory.GIVE_EQUIPPED_WARNING
const GIVE_MONEY_WARNING := SharedUiInventory.GIVE_MONEY_WARNING
const VOID_FAINT_WARNING := SharedUiPanels.VOID_FAINT_WARNING
const DRIFT_FAINT_WARNING := SharedUiPanels.DRIFT_FAINT_WARNING

## The HUD's components (code moved out of this file; this class forwards to them).
var message_log: SharedUiMessageLog = SharedUiMessageLog.new(self)
var card: SharedUiStatusCard = SharedUiStatusCard.new(self)
var selection: SharedUiSelection = SharedUiSelection.new(self)
var actions: SharedUiContextActions = SharedUiContextActions.new(self)
var ask: SharedUiAskPanel = SharedUiAskPanel.new(self)
var items: SharedUiInventory = SharedUiInventory.new(self)
var panels: SharedUiPanels = SharedUiPanels.new(self)
var questions: SharedUiQuestions = SharedUiQuestions.new(self)
var nearby: SharedUiNearby = SharedUiNearby.new(self)
var waits: SharedUiWaits = SharedUiWaits.new(self)


func _ready() -> void:
	_session = get_parent() as WorldSessionController
	if _session != null:
		_session.day_phase_began.connect(message_log.note_day_phase)
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	process_physics_priority = -100
	_presentation_layout = SharedGameplayLayout.new()
	_presentation_layout.name = "PresentationLayout"
	add_child(_presentation_layout)
	_presentation_layout.build(self)
	# Under the HUD's panels, over the map.
	focus_marker = WorldFocusMarker.new()
	focus_marker.configure(self)
	add_child(focus_marker)
	move_child(focus_marker, 0)
	speech_bubbles = WorldSpeechBubbles.new()
	speech_bubbles.configure(self)
	add_child(speech_bubbles)
	move_child(speech_bubbles, 1)
	inspect_button.pressed.connect(actions.inspect_context)
	attack_button.pressed.connect(actions.attack_context)
	spar_button.pressed.connect(actions.spar_context)
	ask_button.pressed.connect(actions.ask_context)
	portal_button.pressed.connect(actions.traverse_context)
	open_loot_button.pressed.connect(actions.loot_context)
	animate_button.pressed.connect(actions.animate_context)
	animate_button.tooltip_text = SharedUiContextActions.ANIMATE_HINT
	lifeheal_button.pressed.connect(actions.lifeheal_context)
	lifeheal_button.tooltip_text = SharedUiContextActions.LIFEHEAL_HINT
	heart_sense_button.pressed.connect(actions.heart_sense_context)
	heart_sense_button.tooltip_text = SharedUiContextActions.HEART_SENSE_HINT
	steal_button.pressed.connect(actions.steal_context)
	steal_button.tooltip_text = SharedUiContextActions.STEAL_HINT
	steal_panel.chosen.connect(actions.steal_choose)
	steal_panel.cancelled.connect(panels.close_panel_of.bind(steal_panel))
	bribe_button.pressed.connect(actions.bribe_context)
	bribe_button.tooltip_text = SharedUiContextActions.BRIBE_HINT
	bribe_panel.bribed.connect(actions.bribe)
	bribe_panel.cancelled.connect(panels.close_panel_of.bind(bribe_panel))
	drift_panel.chosen.connect(panels.drift_choose)
	drift_panel.cancelled.connect(panels.drift_cancel)
	loot_panel.take_requested.connect(actions.take_context)
	inventory_panel.inspect_requested.connect(items.inspect_item)
	inventory_panel.wield_requested.connect(items.wield_item)
	inventory_panel.unwield_requested.connect(items.unwield_item)
	inventory_panel.wear_requested.connect(items.wear_item)
	inventory_panel.remove_requested.connect(items.remove_item)
	inventory_panel.give_requested.connect(items.give_item)
	inventory_panel.drop_requested.connect(items.drop_item)
	inventory_panel.put_requested.connect(items.put_item)
	inventory_panel.play_requested.connect(items.play_item)
	inventory_panel.apply_requested.connect(items.apply_item)
	inventory_panel.act_requested.connect(items.act_with_item)
	inventory_panel.dissolve_requested.connect(items.dissolve_with)
	inventory_panel.hang_requested.connect(items.hang_with)
	inventory_panel.pour_requested.connect(items.pour_item)
	inventory_panel.take_out_requested.connect(items.take_out_item)
	inventory_panel.put_into_requested.connect(items.put_into_carried)
	inventory_panel.scribe_requested.connect(items.scribe_on)
	inventory_panel.attach_requested.connect(items.attach_sheet)
	interaction_panel = InteractionPanel.new()
	_presentation_layout.holding.add_child(interaction_panel)
	interaction_panel.hold_look(_presentation_layout.details)
	interaction_panel.chosen.connect(_on_interaction_chosen)
	confirm_prompt.confirmed.connect(questions.on_prompt_confirmed)
	confirm_prompt.cancelled.connect(questions.on_prompt_cancelled)
	_build_menu()
	arts_page.configure(_session)
	if _session != null:
		life_overlay = PlayerLifeOverlay.new()
		life_overlay.name = "PlayerLifeOverlay"
		life_overlay.configure(_session)
		_session.add_child.call_deferred(life_overlay)
		view_overlay = WorldViewOverlay.new()
		view_overlay.name = "WorldViewOverlay"
		view_overlay.configure(_session)
		_session.add_child.call_deferred(view_overlay)


## `speaker` says `lines` (DECISIONS「说话和交互」): into 消息, and over their head as
## `spoken` (what is said, in the alert red when `alert`); no toast while bubbles show.
## With no speaker (an item's act: the golden rope, a letter) they are the game's own
## message, toasted as ever.
func npc_says(speaker: NpcRuntimeState, lines: Array[ColoredLine], spoken: Array[String], alert: bool = false) -> void:
	if speaker == null:
		message_log.append_colored_lines(lines)
		return
	message_log.append_speech(lines)
	speech_bubbles.say(speaker, spoken, alert)


## The session this HUD shows (null in a bare fixture).
func session() -> WorldSessionController:
	return _session


## A card over the world with 继续 (PlayerLifeOverlay; 前两小时 A/B: 拜师, the opening):
## world time held while it shows. Nothing without the overlay (a bare fixture).
func show_card(text: String) -> void:
	if is_instance_valid(life_overlay):
		life_overlay.show_card(text)


## Where the status card is on the screen (what overlays keep clear of).
func card_rect() -> Rect2:
	return _presentation_layout.bar.get_global_rect()


## A panel (a shop, a question, 打听) has the shared frame.
func panel_open() -> bool:
	return _presentation_layout.frame.visible


## The selected thing's details (目标详情) are open.
func details_shown() -> bool:
	return panel_open() and _presentation_layout.details.is_visible_in_tree()


## The overlays join the session a frame late; free them if the session never got them.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if is_instance_valid(life_overlay) and life_overlay.get_parent() == null:
			life_overlay.free()
		if is_instance_valid(view_overlay) and view_overlay.get_parent() == null:
			view_overlay.free()
	elif what == NOTIFICATION_TRANSLATION_CHANGED and _presentation_layout != null and is_inside_tree():
		# The selection's name and an open panel were put together in the old language;
		# the heading and the status line follow on the next refresh, the log keeps its lines.
		selected_target_label.text = selection.selection_text()
		_presentation_layout.close_frame()
		# The card shows behind 系统 too, where the language is changed (设置): its lines now.
		if _player != null:
			card.refresh_exploration()
		if menu != null and menu.is_presented():
			menu_tab_shown(menu.current_tab())


func configure(player: WorldPlayerRuntimeType) -> bool:
	if player == null or not player.is_valid():
		return false
	_player = player
	selection.set_selected_target(null)
	selection.refresh_live_state()
	return true


## The HUD's input while the player walks (keys and pad; DECISIONS「说话和交互」): interact
## (E, A) or Enter / Space does what the target offers (SharedUiNearby: a door opens, a
## thing with several options opens the interaction popup), or 继续 when someone is telling
## the player something and only people stand by; nearby_focus (Tab, Y), Q / LB and RB
## step the target through what is in reach; a menu key (C, K, I, J) opens that tab,
## menu_open (M, Start) the menu on its last tab, look_around (L, X) is 观察. The open menu
## and the popup take their own keys.
func _unhandled_input(event: InputEvent) -> void:
	if not visible or _presentation_layout.frame.visible or menu.is_presented() or event.is_echo() or not event.is_pressed():
		return
	var tab: int = GameMenu.tab_for_event(event)
	if event.is_action_pressed(&"interact") or event.is_action_pressed("ui_accept"):
		var focused: Control = get_viewport().gui_get_focus_owner()
		if focused != null and focused.is_visible_in_tree():
			# A button takes A on its release: the press is not the place's action.
			return
		get_viewport().set_input_as_handled()
		var thing: WorldNearbyThing = nearby.target()
		# Someone is telling the player something line by line and only people stand by:
		# A is 继续 (DECISIONS「响应性」); the row's button always is.
		if (thing == null or thing.kind == WorldNearbyThing.Kind.NPC) and waits.hurry():
			return
		interact()
	elif tab >= 0:
		get_viewport().set_input_as_handled()
		if _session.portable_inventory_available():
			menu.open(tab)
	elif event.is_action_pressed(&"menu_open"):
		get_viewport().set_input_as_handled()
		if _session.portable_inventory_available():
			menu.open()
	elif event.is_action_pressed(&"nearby_focus") or (event is InputEventJoypadButton and event.is_action_pressed(&"menu_tab_next")):
		get_viewport().set_input_as_handled()
		nearby.cycle(1)
	elif event.is_action_pressed(&"menu_tab_previous"):
		get_viewport().set_input_as_handled()
		nearby.cycle(-1)
	elif event.is_action_pressed(&"look_around"):
		get_viewport().set_input_as_handled()
		open_look()


## Tab is the GUI's "next control" before _unhandled_input sees it: while the player walks
## with nothing focused it steps the target here.
func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"nearby_focus") or event.is_echo() or not visible or _presentation_layout.frame.visible or menu.is_presented():
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused == null or not focused.is_visible_in_tree():
		get_viewport().set_input_as_handled()
		nearby.cycle(1)


# --- interacting (DECISIONS「说话和交互」) ---

const INTERACTION_TIME_HOLD: StringName = &"interaction"
## The option the popup's right column shows by itself.
const LOOK: String = "查看"
## The thing the interaction popup shows, while it shows.
var _interacting: WorldNearbyThing


## E / A on the target: what a thing that does one thing does, else its popup. False when
## nothing is in reach (or the player cannot act).
func interact() -> bool:
	var thing: WorldNearbyThing = nearby.target()
	if thing == null or _session == null or not _session.portable_inventory_available():
		return false
	var single: InteractionOption = nearby.direct(thing)
	if single != null:
		single.action.call()
		return true
	open_interaction(thing)
	return true


## A click or tap on the thing with `id`: it becomes the target and E / A goes to it.
func interact_with(id: StringName) -> bool:
	if not visible or _presentation_layout.frame.visible or menu.is_presented() or not nearby.choose(id):
		return false
	return interact()


## The interaction popup on `thing`, in the shared frame, opened on its 查看: opening it
## looks at the thing (look.c), as 查看 did. It closes when the thing leaves reach.
func open_interaction(thing: WorldNearbyThing) -> void:
	_interacting = thing
	# The target stays on it while the popup shows (time runs on a page; others walk by).
	nearby.choose(thing.id)
	_fill_interaction()
	var key: StringName = thing.id
	_presentation_layout.open_panel(nearby.shown_name(thing), interaction_panel, func() -> bool: return nearby.target() != null and nearby.target().id == key)
	if not interaction_open():
		return
	var look: InteractionOption = null
	for option: InteractionOption in nearby.options_for(_session.active_map() as WorldMapController, thing):
		if option.label == LOOK:
			look = option
	inspection_text.text = ""
	if look != null:
		# Selects it and shows the details: the popup keeps their text as its 查看.
		look.action.call()
	interaction_panel.set_look(inspection_text.get_parsed_text().strip_edges() if look != null else "")


## The popup shows the target as it is now (its options greyed or not); 查看 is its right
## column, not a row.
func _fill_interaction() -> void:
	var thing: WorldNearbyThing = nearby.target()
	if thing == null or _interacting == null or thing.id != _interacting.id:
		return
	_interacting = thing
	var lines: Array[Array] = nearby.about(thing)
	var status: Array[String] = []
	status.assign(lines[0])
	var about: Array[String] = []
	about.assign(lines[1])
	var options: Array[InteractionOption] = []
	for option: InteractionOption in nearby.options_for(_session.active_map() as WorldMapController, thing):
		if option.label != LOOK:
			options.append(option)
	interaction_panel.show_thing(status, about, options)


## A row chosen: it is done with the popup open. What it opens (打听, a shop, 给予, its
## question first) is the popup's page; one that opens nothing (a fight begun, a dial
## turned, 疗伤他人) is done and the popup closes, as before.
func _on_interaction_chosen(option: InteractionOption) -> void:
	option.action.call()
	if interaction_open() and _presentation_layout.page() == null:
		_presentation_layout.close_frame()
	_hold_for_interaction()


## What `panel` was opened for is done (偷窃 begun, a bribe taken): it closes; shown as the
## interaction popup's page, the popup closes with it, as after a row that opens nothing
## (world time then runs for what follows: the theft's moment).
func panel_done(panel: Control) -> void:
	if _presentation_layout._content != panel:
		return
	if interaction_open():
		_presentation_layout.close_frame()
	else:
		_presentation_layout.close_panel()


## The popup shows now (its 查看 or a page).
func interaction_open() -> bool:
	return _presentation_layout.hosting() and _presentation_layout._frame_content == interaction_panel


## World time stands still while the popup shows, its pages too (owner, 2026-10-17): what
## needs it (an NPC's answer, a story told, a theft's moment) comes after the popup closes,
## which every act that starts one does.
func _hold_for_interaction() -> void:
	if _session == null:
		return
	if interaction_open():
		_session.hold_world_time(INTERACTION_TIME_HOLD)
	else:
		_interacting = null
		_session.release_world_time(INTERACTION_TIME_HOLD)


## Where the focus was on the frame's panel or the menu's page: [that root, the path
## of child places to the focused control].
var _focus_place: Array = []


## Keys and pad keep a focus while a panel or the menu is up: a focused row that went away
## (the 背包 after using an item, a shop's list after a purchase) hands it to the same
## place in the rebuilt list, so the next A does not hit another item.
func _keep_focus() -> void:
	if InputDevices.shared().is_touch() or not is_inside_tree():
		return
	if is_instance_valid(life_overlay) and life_overlay.is_blocking():
		return # 继续 on the death screen has it.
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null and focused.is_visible_in_tree():
		var surface: Control = _focus_surface()
		_focus_place = [] if surface == null or not surface.is_ancestor_of(focused) else [surface, FocusNav.place_of(surface, focused)]
		return
	if not _focus_place.is_empty() and is_instance_valid(_focus_place[0]) and _focus_place[0] == _focus_surface() and FocusNav.give(FocusNav.at_place(_focus_place[0], _focus_place[1])):
		return
	refocus()


## The panel or page keys and pad move in now, or null.
func _focus_surface() -> Control:
	if _presentation_layout.frame.visible:
		return _presentation_layout.mount
	if menu.is_presented() and not menu.in_pause_view():
		return menu.pages[menu.current_tab()]
	return null


## The focus goes to the top surface's first control: the frame's panel or the menu's page.
func refocus() -> void:
	if _presentation_layout.frame.visible:
		_presentation_layout.focus_content()
	elif menu.is_presented() and not menu.in_pause_view():
		menu.focus_page()


func _process(delta: float) -> void:
	if _session == null or not _session.is_initialized() or _session.active_map_child_count() == 0:
		visible = false
		if _presentation_layout != null:
			_presentation_layout.close_frame()
			menu.dismiss()
		return
	var current: WorldResidentMapController = _session.active_map()
	# A new map or a HUD that just reappeared refreshes now, not 0.1 s later.
	if current != _bound_map:
		_presentation_layout.close_frame()
		if not menu.in_pause_view():
			menu.dismiss()
		selection.set_selected_target(null)
		_bound_map = current
		_elapsed = INF
	# 系统 is the shell's pause: the card stays behind the menu there, as behind its other tabs.
	var running: bool = (_session.can_process() and _session.application_gameplay_allows_encounter_advance()) or (menu.in_pause_view() and get_tree().paused)
	var available: bool = not _session.is_restore_candidate_staged() and not _session.is_session_swap_suspended() and running
	# The battle panel still up (a finished fight's last lines) is the fight still.
	var fighting: bool = _session.combat_encounter_coordinator().has_active_encounter() or _session.battle_panel_shown()
	if not visible and available and not fighting:
		_elapsed = INF
	visible = available and not fighting
	if menu.in_pause_view():
		# 系统 holds the world (the shell's pause): only its questions stay checked.
		_presentation_layout.validate_open_panel()
		return
	if not visible:
		_presentation_layout.close_frame()
		# A fight closes the menu as it closed the HUD's panels (the interaction popup too).
		menu.dismiss()
		_hold_for_interaction()
		# A fight clears the toasts from before it.
		message_log.refresh_toasts()
		return
	if menu.is_presented() and not _session.portable_inventory_available():
		# The player cannot act now (unconscious, dying, taken elsewhere): the menu would
		# cover what happens.
		menu.dismiss()
	_presentation_layout.validate_open_panel()
	_hold_for_interaction()
	_keep_focus()
	if _presentation_layout._content == _presentation_layout.details:
		if (selection.selected_target != null and (not selection.selected_target.exists_in_map or selection.selected_target.life_status == CharacterRuntimeLifeStatus.Value.DEAD)) or (selection.selected_landmark != null and not selection.selected_landmark_source_available) or (selection.selected_corpse_available and not selection.selected_corpse_in_range and not selection.selected_floor_item):
			_presentation_layout.close_panel()
	_elapsed += delta
	if _elapsed < 0.1:
		return
	_elapsed = 0.0
	selection.refresh_live_state()
	card.refresh_exploration()
	if interaction_open():
		_fill_interaction()
	if menu.is_presented():
		_refresh_menu_page()


func _physics_process(_delta: float) -> void:
	if _presentation_layout != null and (_presentation_layout.frame.visible or (menu.is_presented() and not menu.in_pause_view())):
		quarantine_movement()


func quarantine_movement() -> void:
	if _session != null and _session.is_initialized() and _session.active_map_child_count() > 0 and _session.active_map() != null:
		_session.active_map().runtime_player_body().quarantine_current_movement_input()


# --- the menu window ---

const MENU_TIME_HOLD: StringName = &"game_menu"


func _build_menu() -> void:
	character_sheet = CharacterSheet.new()
	arts_page = MartialArtsPage.new()
	arts_page.name = "MartialArtsPage"
	inventory_page = VBoxContainer.new()
	inventory_page.name = "InventoryPage"
	inventory_page.add_theme_constant_override("separation", 12)
	inventory_panel.reparent(inventory_page, false)
	# The tab names it and the window closes it: the panel's own title and 关闭 go.
	inventory_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	for path: String in ["Margin/VBox/Title", "Margin/VBox/Separator", "Margin/VBox/PlayerInventoryCloseButton"]:
		inventory_panel.get_node(path).queue_free()
	supplies_mount = VBoxContainer.new()
	supplies_mount.name = "Supplies"
	supplies_mount.add_theme_constant_override("separation", 8)
	inventory_page.add_child(supplies_mount)
	_heading(supplies_mount, "随身补给")
	journal_page = VBoxContainer.new()
	journal_page.name = "JournalPage"
	journal_page.add_theme_constant_override("separation", 10)
	_heading(journal_page, "朱鸿雪的任务")
	quest_text = Label.new()
	quest_text.name = "Quest"
	quest_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# quest.c's lines, already in the shown language.
	quest_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	journal_page.add_child(quest_text)
	_heading(journal_page, "江湖见闻")
	journal_stories = JournalStories.new()
	journal_page.add_child(journal_stories)
	_heading(journal_page, "消息记录")
	_presentation_layout.messages.reparent(journal_page, false)
	_presentation_layout.messages.show()
	menu = GameMenu.new()
	add_child(menu)
	codex_page = CodexPage.new()
	codex_page.blocked = func() -> bool: return _presentation_layout.frame.visible
	menu.build(self, character_sheet, arts_page, inventory_page, journal_page, codex_page)


func _heading(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.name = "Heading"
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", SharedGameplayLayout.ACCENT_COLOR)
	parent.add_child(label)
	return label


## The 菜单 button: the menu on its last tab.
func open_menu() -> void:
	menu.open()


## Closes the menu (an act that moves the player, a drift).
func close_menu() -> void:
	if menu.is_presented():
		menu.close()


## The menu's own questions, shown over it rather than in its place.
func is_menu_dialog(content: Control) -> bool:
	return content == confirm_prompt or content == drift_panel


## The menu opened: the frame's panel closes, its questions now show over the menu. Over
## the running world the player stops walking; the shell's pause freezes things itself.
func menu_presented() -> void:
	_presentation_layout.close_frame()
	_presentation_layout.lift_frame(menu.root)
	# The world stands still while the menu is open (owner, 2026-10-15).
	if _session != null:
		_session.hold_world_time(MENU_TIME_HOLD)
	if not menu.in_pause_view():
		quarantine_movement()


func menu_dismissed(from_pause: bool) -> void:
	_presentation_layout.close_frame()
	_presentation_layout.lower_frame()
	if _session != null:
		_session.release_world_time(MENU_TIME_HOLD)
	if not from_pause:
		quarantine_movement()
	_elapsed = INF


## A tab is shown: its page is filled now.
func menu_tab_shown(tab: int) -> void:
	match tab:
		GameMenu.Tab.CHARACTER, GameMenu.Tab.MARTIAL_ARTS:
			panels.refresh_character()
		GameMenu.Tab.INVENTORY:
			items.fill_shown_page()
			panels.show_supplies()
		GameMenu.Tab.JOURNAL:
			quest_text.text = "" if _player == null else "\n".join(QuestStatus.lines(_player.state.quest))
			if _session != null:
				_session.record_journal()
			journal_stories.fill(null if _player == null else _player.state, _player_respect())
			_journal_shown = -1 if _player == null else _player.state.journal.size()
		GameMenu.Tab.CODEX:
			if _session != null:
				_session.record_journal()
			codex_page.fill(null if _player == null else _player.state)


## Every page hides (another tab, the menu closed): the 背包 no longer counts as open.
func menu_pages_hidden() -> void:
	items.close_inventory()


func _refresh_menu_page() -> void:
	match menu.current_tab():
		GameMenu.Tab.CHARACTER, GameMenu.Tab.MARTIAL_ARTS:
			panels.refresh_character()
		GameMenu.Tab.JOURNAL:
			# quest.c's time left changes; the stories only when something new was recorded.
			quest_text.text = "" if _player == null else "\n".join(QuestStatus.lines(_player.state.quest))
			if _player != null and _player.state.journal.size() != _journal_shown:
				menu_tab_shown(GameMenu.Tab.JOURNAL)
	message_log.collect_feedback()


## Everything the 角色 page shows (tests).
func character_sheet_text() -> String:
	panels.refresh_character()
	return character_sheet.text()


## How NPCs address the player (rankd.c query_respect(), as NpcInquiry asks it).
func _player_respect() -> String:
	if _player == null:
		return ""
	return tr(RankWords.query_respect(_player.state.gender, _player.facts.age, _player.state.affiliation.class_id))


## The 任务 page's 朱鸿雪 lines (tests).
func journal_quest_text() -> String:
	menu_tab_shown(GameMenu.Tab.JOURNAL)
	return quest_text.text


# --- forwarded to SharedUiMessageLog (message_log) ---


func show_combat_result(text: String) -> void:
	message_log.show_combat_result(text)


func append_after_fight(lines: Array[ColoredLine]) -> void:
	message_log.append_after_fight(lines)


func append_log_lines(lines: Array[String], alert: bool = false) -> void:
	message_log.append_log_lines(lines, alert)


func append_colored_lines(lines: Array[ColoredLine]) -> void:
	message_log.append_colored_lines(lines)


func toasts() -> MessageToasts:
	return message_log.toasts()


func refresh_toasts() -> void:
	message_log.refresh_toasts()


func panel_opened() -> void:
	message_log.panel_opened()


func log_lines() -> Array[String]:
	return message_log.log_lines()


static func room_prose(text: String) -> String:
	return SharedUiMessageLog.room_prose(text)


func describe_arrival() -> void:
	message_log.describe_arrival()


func describe_again() -> void:
	message_log.describe_again()


func open_messages() -> void:
	message_log.open_messages()


# --- forwarded to SharedUiStatusCard (card) ---


func refresh_exploration() -> void:
	card.refresh_exploration()


func current_zone() -> ZoneDefinition:
	return card.current_zone()


func location_name() -> String:
	return card.location_name()


# --- forwarded to SharedUiSelection (selection) ---


func set_selected_target(target: NpcRuntimeState) -> void:
	selection.set_selected_target(target)


func set_selected_landmark(landmark: WorldLandmarkDefinition, source_available: bool) -> void:
	selection.set_selected_landmark(landmark, source_available)


func set_selected_landmark_source_available(value: bool) -> void:
	selection.set_selected_landmark_source_available(value)


## `corpse_name`: the corpse's name at its stage, shown (WorldMapCorpses.corpse_name()).
func set_selected_corpse(corpse_name: String, content_count: int, in_range: bool, clear_inspection: bool = true) -> void:
	selection.set_selected_corpse(corpse_name, content_count, in_range, clear_inspection)


func set_selected_floor_item(display_name: String, in_range: bool, clear_inspection: bool = true) -> void:
	selection.set_selected_floor_item(display_name, in_range, clear_inspection)


func show_inspection(definition: NpcDefinition, relation: String = "", gender: StringName = &"", strength: String = "", title: String = "") -> void:
	selection.show_inspection(definition, relation, gender, strength, title)


func show_landmark_inspection(definition: WorldLandmarkDefinition, text: String = "") -> void:
	selection.show_landmark_inspection(definition, text)


func show_item_inspection(display_name: String, description: String) -> void:
	selection.show_item_inspection(display_name, description)


func show_corpse_inspection(corpse_name: String, content_count: int, long: String = "") -> void:
	selection.show_corpse_inspection(corpse_name, content_count, long)


func refresh_live_state() -> void:
	selection.refresh_live_state()


func selected_target_text() -> String:
	return selection.selected_target_text()


func inspection_display() -> String:
	return selection.inspection_display()


func attack_is_enabled() -> bool:
	return selection.attack_is_enabled()


func spar_is_enabled() -> bool:
	return selection.spar_is_enabled()


func ask_is_enabled() -> bool:
	return selection.ask_is_enabled()


func portal_action_is_enabled() -> bool:
	return selection.portal_action_is_enabled()


func portal_action_text() -> String:
	return selection.portal_action_text()


func open_loot_is_enabled() -> bool:
	return selection.open_loot_is_enabled()


# --- forwarded to SharedUiContextActions (actions) ---


func context_title() -> String:
	return actions.context_title()


func open_current_context() -> void:
	actions.open_current_context()


# --- forwarded to SharedUiAskPanel (ask) ---


func open_ask() -> void:
	ask.open_ask()


func ask_topics_shown() -> Array[String]:
	return ask.ask_topics_shown()


func ask_answer_text() -> String:
	return ask.ask_answer_text()


func ask_verbs_shown() -> Array[String]:
	return ask.ask_verbs_shown()


func relay_buttons_shown() -> Array[String]:
	return ask.relay_buttons_shown()


# --- forwarded to SharedUiInventory (items) ---


func show_loot(title: String, rows: Array[WorldItemRowProjection]) -> void:
	items.show_loot(title, rows)


func close_loot() -> void:
	items.close_loot()


func loot_is_open() -> bool:
	return items.loot_is_open()


func loot_rows() -> Array[WorldItemRowProjection]:
	return items.loot_rows()


func show_inventory(rows: Array[PlayerInventoryRowProjection]) -> void:
	items.show_inventory(rows)


## The 背包 goes away (the player is taken elsewhere, dies, the map resets): the menu
## closes when it shows it.
func close_inventory() -> void:
	if menu.is_presented() and menu.current_tab() == GameMenu.Tab.INVENTORY and not menu.in_pause_view():
		menu.close()
	items.close_inventory()


func inventory_is_open() -> bool:
	return items.inventory_is_open()


func inventory_rows() -> Array[PlayerInventoryRowProjection]:
	return items.inventory_rows()


func show_inventory_inspection(row: PlayerInventoryRowProjection) -> void:
	items.show_inventory_inspection(row)


func open_inventory() -> void:
	items.open_inventory()


# --- forwarded to SharedUiPanels (panels) ---


func initialize_supplies() -> void:
	panels.initialize_supplies()


func refresh_panel_rows() -> void:
	panels.refresh_panel_rows()


func open_look() -> void:
	panels.open_look()


func open_business(title: String, form: Control, validate: Callable) -> void:
	panels.open_business(title, form, validate)


func open_character() -> void:
	panels.open_character()


func open_martial_arts() -> void:
	panels.open_martial_arts()


func martial_arts_page() -> MartialArtsPage:
	return arts_page


func open_supplies() -> void:
	panels.open_supplies()


func conjure_void_sense() -> void:
	panels.conjure_void_sense()


func open_drift_sense() -> void:
	panels.open_drift_sense()


func cast_self(function_id: StringName) -> void:
	panels.cast_self(function_id)


func dismiss_current_panel() -> void:
	panels.dismiss_current_panel()


func close_business(form: Control) -> void:
	panels.close_business(form)


# --- forwarded to SharedUiQuestions (questions) ---


func ask_first(text: String, choice: String, action: Callable, still_valid: Callable = Callable(), on_cancel: Callable = Callable(), about: String = "") -> void:
	questions.ask_first(text, choice, action, still_valid, on_cancel, about)


func is_asking() -> bool:
	return questions.is_asking()
