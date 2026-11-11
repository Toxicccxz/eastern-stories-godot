extends RefCounted

## 界面重做 3 (DECISIONS「界面样式」): the world's surfaces in GameTheme. The status card a
## slab, the name in voxel letters; the E prompt at his feet, clear of the player and of the
## name over his head; a said
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
	await _test_battle(tree)
	return {"assertions": assertions, "failures": failures}


## 界面重做 4: the battle panel in the same theme (its own BattleVisualTheme gone): the cards
## square slabs with the lantern for the target, the move and stance held in lacquer, 自动 a
## chip, a risky action asked in dark lacquer.
func _test_battle(tree: SceneTree) -> void:
	check(not ResourceLoader.exists("res://presentation/battle/battle_visual_theme.gd"), "no battle theme of its own")
	var card := BattleParticipantCard.new()
	tree.root.add_child(card)
	await tree.process_frame
	check(BattleParticipantCard.GOLD == UiPalette.LANTERN and card._current_border.border_color == UiPalette.LANTERN, "the target's edge is the lantern")
	check(card._ordinary_border.corner_radius_top_left == 0 and card._ordinary_border.border_width_bottom > card._ordinary_border.border_width_top, "a card is a square slab, thicker below")
	card.queue_free()
	var panel := BattleActionPanel.new()
	tree.root.add_child(panel)
	await tree.process_frame
	check(panel.stance_buttons.values().all(func(button: Button) -> bool: return button.theme_type_variation == &"ToggleButton") and panel.manual_button.theme_type_variation == &"ChipButton", "the stance held is lacquer, 自动 a chip")
	panel.confirm_text = func(_id: StringName) -> PackedStringArray: return PackedStringArray(["天邪虎啸会让所有人对你下杀手。", "确定"])
	panel._action_pressed(&"roar")
	check(panel.is_asking() and panel.prompt.confirm_button.theme_type_variation == &"DangerButton", "a risky action is asked in dark lacquer")
	var move := Button.new()
	BattleActionPanel._show_chosen(move, true)
	check(move.get_theme_stylebox("disabled") == GameTheme.shared().get_stylebox("pressed", &"ToggleButton"), "the chosen move keeps its lacquer while the round greys the row")
	BattleActionPanel._show_chosen(move, false)
	check(not move.has_theme_stylebox_override("disabled"), "the others grey")
	move.free()
	panel.queue_free()
	await tree.process_frame


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
	# A title too long for its row loses its front, from where a part begins, never its name.
	var chars: Callable = func(text: String) -> float: return float(text.length())
	check(SharedGameplayLayout.fitted_title(LONG_TITLE, 20.0, chars) == LONG_TITLE, "a title that fits stays whole")
	check(SharedGameplayLayout.fitted_title(LONG_TITLE, 17.0, chars) == "…「镇国大将军」严廷殷", "one too long drops its title, not half a word: %s" % SharedGameplayLayout.fitted_title(LONG_TITLE, 17.0, chars))
	check(SharedGameplayLayout.fitted_title(LONG_TITLE, 10.0, chars) == "…严廷殷", "shorter still, the name alone: %s" % SharedGameplayLayout.fitted_title(LONG_TITLE, 10.0, chars))
	check(SharedGameplayLayout.fitted_title("门房 刘安禄", 5.0, chars) == "…刘安禄", "a title before a space goes the same way")


## 天驼关 canyon.camp8's general: a family title and a nickname before the name.
const LONG_TITLE: String = "天邪派第十六代弟子「镇国大将军」严廷殷"
const LONG_NAME: String = "严廷殷"
## The window the world runs in here (人物外观 D's smoke shots).
const WINDOW := Vector2i(1920, 1080)


## The project's own size, which the window stretches.
static func _base_size() -> Vector2i:
	return Vector2i(int(ProjectSettings.get_setting("display/window/size/viewport_width")), int(ProjectSettings.get_setting("display/window/size/viewport_height")))


## The popup's title too long for its row beside the forecast's plate (人物外观 D's smoke at
## 1920×1080: the plate covered half of 严廷殷): at every 界面缩放, scaled as the game scales it
## (whole pixel steps), the plate sits after the text, inside the row, and the name shows
## whole; the whole title is the hover. A short one stays as it was.
func _test_long_title(tree: SceneTree, layout: SharedGameplayLayout, short_title: String) -> void:
	var title: Label = layout.frame_title
	var font: Font = title.get_theme_font("font")
	var font_size: int = title.get_theme_font_size("font_size")
	var original_size: Vector2i = tree.root.size
	var original_factor: float = tree.root.content_scale_factor
	layout.set_title(LONG_TITLE)
	layout.set_badge(CombatForecast.verdict_word(CombatForecast.Verdict.SURE_LOSS), CombatForecast.Verdict.SURE_LOSS, "")
	var cut: int = 0
	for window: Vector2i in [WINDOW, Vector2i(2560, 1440)]:
		for percent: int in ApplicationUiScale.PERCENTS:
			tree.root.size = window
			tree.root.content_scale_factor = ApplicationUiScale.pixel_factor(percent, window, _base_size())
			for i: int in 4:
				await tree.process_frame
			var at: String = "%dx%d at %d%%" % [window.x, window.y, percent]
			var shown: String = title.text
			var text_end: float = font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var plate := Rect2(layout.frame_badge.position, layout.frame_badge.size)
			check(shown.ends_with(LONG_NAME) and text_end <= title.size.x, "%s: the name ends the title, whole in its row: %s (%.0f of %.0f)" % [at, shown, text_end, title.size.x])
			check(layout.frame_badge.visible and plate.position.x >= text_end and plate.end.x <= title.size.x + 0.5, "%s: the plate after the text, inside the row: text to %.0f, plate %s, row %.0f" % [at, text_end, plate, title.size.x])
			check(shown == LONG_TITLE or (shown.begins_with(SharedGameplayLayout.TITLE_CUT) and title.tooltip_text == LONG_TITLE), "%s: cut at its front, the whole title the hover" % at)
			check(plate.position == plate.position.round(), "%s: the plate on whole pixels" % at)
			cut += 1 if shown != LONG_TITLE else 0
	check(cut > 0, "the rows are narrow enough to cut it somewhere (the case is tested)")
	tree.root.size = original_size
	tree.root.content_scale_factor = original_factor
	layout.set_title(short_title)
	for i: int in 4:
		await tree.process_frame
	var short_end: float = font.get_string_size(short_title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	check(title.text == short_title and title.tooltip_text.is_empty() and is_equal_approx(layout.frame_badge.position.x, roundf(short_end + SharedGameplayLayout.BADGE_GAP)), "a short title whole, the plate just after it: %s at %.0f" % [title.text, layout.frame_badge.position.x])


func _test_world(tree: SceneTree) -> void:
	# Bubbles and the dialogue box are the feel's (suites run with it off).
	TestFeel.use()
	# A real window (the headless one is 64×64), 界面缩放 100% as the game scales it.
	var original_size: Vector2i = tree.root.size
	var original_factor: float = tree.root.content_scale_factor
	tree.root.size = WINDOW
	tree.root.content_scale_factor = ApplicationUiScale.pixel_factor(ApplicationUiScale.DEFAULT, WINDOW, _base_size())
	var session: WorldSessionController = load("res://scenes/world/oldpine/oldpine_world_session.tscn").instantiate()
	check(session.configure_source_entry("界面", CharacterState.GENDER_FEMALE), "source setup")
	tree.root.add_child(session)
	await tree.process_frame
	await tree.process_frame
	var hud: SharedGameplayUI = session.shared_ui()
	var layout: SharedGameplayLayout = hud._presentation_layout
	var map: WorldMapController = session.active_map() as WorldMapController
	session.set_process(false) # TEST-ONLY: nobody wanders while the player is placed
	check(layout.overlay.theme == GameTheme.shared() and layout.bar.theme_type_variation == &"HudCard" and hud.player_name.theme_type_variation == &"HudNameLabel", "the HUD wears the theme: the card a slab, the name in voxel letters")
	var waiter: NpcRuntimeState = null
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.spawn_point_id == WAITER_POINT:
			waiter = npc
	check(waiter != null, "the waiter in the Inn")
	if waiter == null:
		session.queue_free()
		tree.root.size = original_size
		tree.root.content_scale_factor = original_factor
		TestFeel.restore()
		return
	var body: Node2D = map.runtime_body_for_character(waiter.character_id)
	map.runtime_player_body().global_position = body.global_position + Vector2(0, 50)
	await tree.physics_frame
	await tree.physics_frame
	hud.refresh_exploration()
	hud.focus_marker._process(0.2)
	var prompt: Control = hud.focus_marker.get_node("FocusPrompt") as Control
	var feet: Vector2 = map.screen_position(hud.focus_marker.focus().at())
	var prompt_rect := Rect2(prompt.position, prompt.size)
	var player_rect: Rect2 = hud.focus_marker._player_rect(map)
	check(prompt.visible and prompt.theme_type_variation == &"ToastPanel" and prompt_rect.end.y > feet.y and not prompt_rect.grow(-1.0).intersects(player_rect), "the E prompt at his feet (not over his name), clear of the player south of him, on a dark plate: %s, feet %s, player %s" % [prompt_rect, feet, player_rect])
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
	await _test_long_title(tree, layout, name)
	if outlook.forecast != null:
		layout.set_badge(CombatForecast.verdict_word(outlook.forecast.verdict), outlook.forecast.verdict, "")
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
	tree.root.size = original_size
	tree.root.content_scale_factor = original_factor
	TestFeel.restore()
