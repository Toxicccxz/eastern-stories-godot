extends RefCounted

## 界面重做 3 (DECISIONS「界面样式」): the world's surfaces in GameTheme. The status card a
## slab, the name in voxel letters; the E prompt by the ring at his feet, clear of the player
## and of the name over his head; a said
## line on paper; the interaction popup the menu's window with the name once (its title, and
## the fight forecast's word on its plate beside it), its rows list rows, the open one held
## down; a page's heading without the name again; a dangerous choice in dark lacquer, its
## buttons under the question; the popup closing a conversation still in the box.

var assertions: int = 0
var failures: Array[String] = []

const WAITER_POINT: StringName = &"snow.inn.main_floor.inn.waiter.1"


func check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures.append(message)


func run_all(tree: SceneTree) -> Dictionary:
	_test_theme()
	_test_words()
	await _test_world(tree)
	return {"assertions": assertions, "failures": failures}


func _test_theme() -> void:
	var theme: GameTheme = GameTheme.shared()
	for variation: StringName in [&"HudCard", &"HudCardTouch", &"DialoguePanel", &"PaperPanel", &"BannerPanel", &"VerdictGood", &"VerdictEven", &"VerdictBad", &"PaperLabel", &"NameLabel", &"PlaceCaption"]:
		check(theme.is_type_variation(variation, theme.get_type_variation_base(variation)), "%s is a variation" % variation)
	check(GameTheme.verdict_plate(CombatForecast.Verdict.SURE_WIN) == &"VerdictGood" and GameTheme.verdict_plate(CombatForecast.Verdict.EVEN) == &"VerdictEven" and GameTheme.verdict_plate(CombatForecast.Verdict.SURE_LOSS) == &"VerdictBad", "a win jade, a loss dark lacquer, stone between")
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 9
	GameTheme.dress_bar(bar, UiPalette.LACQUER)
	var fill: StyleBoxFlat = bar.get_theme_stylebox("fill") as StyleBoxFlat
	check(fill != null and fill.corner_radius_top_left == 0 and fill.border_width_bottom == 3 and fill.bg_color == UiPalette.LACQUER, "a bar is square, its fill a block with a side")
	bar.free()


## The name said once: a page's heading and 查看's first line drop it when the title has it.
func _test_words() -> void:
	check(SharedGameplayLayout.page_heading("店小二 · 购买", "店小二") == "购买", "店小二 · 购买 under 店小二 is 购买")
	check(SharedGameplayLayout.page_heading("给予 · 店小二", "店小二") == "给予 · 店小二" and SharedGameplayLayout.page_heading("请确认", "店小二") == "请确认", "other headings stay")
	check(InteractionPanel.without_name_line("店小二\n这位店小二正笑咪咪地忙著。", "店小二") == "这位店小二正笑咪咪地忙著。", "查看 opens on him, not his name")
	check(InteractionPanel.without_name_line("店小二正笑咪咪地忙著。\n别的。", "店小二") == "店小二正笑咪咪地忙著。\n别的。", "a sentence that names him stays")


func _test_world(tree: SceneTree) -> void:
	# Bubbles and the dialogue box are the feel's (suites run with it off).
	TestFeel.use()
	var session: WorldSessionController = load("res://scenes/world/oldpine/oldpine_world_session.tscn").instantiate()
	check(session.configure_source_entry("界面", CharacterState.GENDER_FEMALE), "source setup")
	tree.root.add_child(session)
	await tree.process_frame
	await tree.process_frame
	var hud: SharedGameplayUI = session.shared_ui()
	var layout: SharedGameplayLayout = hud._presentation_layout
	var map: WorldMapController = session.active_map() as WorldMapController
	session.set_process(false) # TEST-ONLY: nobody wanders while the player is placed
	check(layout.overlay.theme == GameTheme.shared() and layout.bar.theme_type_variation == &"HudCard" and hud.player_name.theme_type_variation == &"TitleLabel", "the HUD wears the theme: the card a slab, the name in voxel letters")
	var waiter: NpcRuntimeState = null
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.spawn_point_id == WAITER_POINT:
			waiter = npc
	check(waiter != null, "the waiter in the Inn")
	if waiter == null:
		session.queue_free()
		TestFeel.restore()
		return
	var body: Node2D = map.runtime_body_for_character(waiter.character_id)
	map.runtime_player_body().global_position = body.global_position + Vector2(0, 50)
	await tree.physics_frame
	await tree.physics_frame
	hud.refresh_exploration()
	hud.focus_marker._process(0.2)
	var prompt: Control = hud.focus_marker.get_node("FocusPrompt") as Control
	var ring: Vector2 = map.screen_position(hud.focus_marker.focus().at())
	var prompt_rect := Rect2(prompt.position, prompt.size)
	var player_rect: Rect2 = hud.focus_marker._player_rect(map)
	check(prompt.visible and prompt.theme_type_variation == &"ToastPanel" and prompt_rect.end.y > ring.y and not prompt_rect.grow(-1.0).intersects(player_rect), "the E prompt by the ring at his feet (not over his name), clear of the player south of him, on a dark plate: %s, ring %s, player %s" % [prompt_rect, ring, player_rect])
	hud.speech_bubbles.say(waiter, ["店小二说道：客官里边请。"])
	var entry: Array = hud.speech_bubbles._bubbles.get(waiter.character_id, [null])
	var bubble: PanelContainer = entry[0] as PanelContainer
	check(bubble != null and bubble.theme_type_variation == &"PaperPanel" and hud.speech_bubbles.text_of(waiter.character_id) == "客官里边请。", "what he says is on paper")
	hud.speech_bubbles.forget(waiter.character_id)

	check(hud.interact() and hud.interaction_open(), "E opens his popup")
	var name: String = waiter.definition().short_name()
	check(layout.frame.theme_type_variation == &"MenuWindow" and layout.frame_title.text == name and layout.frame_title.theme_type_variation == &"TitleLabel", "the menu's window, his name in voxel letters")
	var outlook: CombatOutlook = map.combat_outlook(waiter)
	if outlook.forecast != null:
		check(layout.frame_badge.visible and layout.frame_badge_text.text == CombatForecast.verdict_word(outlook.forecast.verdict) and layout.frame_badge.theme_type_variation == GameTheme.verdict_plate(outlook.forecast.verdict) and not layout.frame_badge.tooltip_text.is_empty(), "the forecast's word beside it: %s" % layout.frame_badge_text.text)
	check(not hud.interaction_panel.look_text().begins_with(name + "\n"), "查看 does not open with his name again: %s" % hud.interaction_panel.look_text().left(30))
	var buy: Button = hud.interaction_panel.button_of("购买")
	check(buy != null and buy.theme_type_variation == &"RowButton" and not buy.button_pressed, "his rows are list rows")
	check(hud.interaction_panel.press("购买") and buy.button_pressed and hud.interaction_panel.current() == "购买", "购买's row held down while its page shows")
	var heading: Label = hud.interaction_panel.find_child("Heading", true, false) as Label
	check(heading.text == "购买" and heading.theme_type_variation == &"HeadingLabel", "its heading without his name: %s" % heading.text)
	var page: Control = layout.page()
	check(page is PanelContainer and page.has_theme_stylebox_override("panel") and page.get_theme_stylebox("panel") is StyleBoxEmpty, "the shop has the window for its box")
	hud.dismiss_current_panel()
	check(not buy.button_pressed, "back on 查看: no row held")
	# 攻击: dark lacquer, the buttons under the question from its left.
	check(hud.interaction_panel.press("攻击") and hud.is_asking(), "攻击 asks first")
	check(hud.confirm_prompt.confirm_button.theme_type_variation == &"DangerButton" and (hud.confirm_prompt.find_child("Actions", false, false) as HFlowContainer).alignment == FlowContainer.ALIGNMENT_BEGIN, "确定攻击 is dark lacquer, under the question")
	hud.confirm_prompt.cancel_button.pressed.emit()
	await tree.process_frame
	hud.dismiss_current_panel()
	await tree.process_frame
	# 打听 in the box, then his popup again: the box closes first, one window.
	hud.interact()
	check(hud.interaction_panel.press("打听") and hud.dialogue_box.is_open() and not hud.interaction_open(), "打听: the conversation in the box")
	var plate: Control = hud.dialogue_box.get_node("NamePlate") as Control
	check(plate.visible and plate.theme_type_variation == &"PlatePanel" and plate.global_position.y < (hud.dialogue_box.get_node("Box") as Control).global_position.y, "his name on a lacquer plate over the box's edge")
	hud.interact()
	check(hud.interaction_open() and not hud.dialogue_box.is_open(), "his popup again: the box closed, one window and one Esc")
	hud.dismiss_current_panel()
	session.queue_free()
	await tree.process_frame
	TestFeel.restore()
