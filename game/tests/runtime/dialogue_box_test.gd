extends RefCounted

## The dialogue box (DECISIONS「对话框」): 打听 and what is told are read in it, line by line,
## the world holding still; chat stays in the bubbles; a fight shuts it and 消息 keeps all.
## 过场演出 A (DECISIONS「过场读法」「过场黑边」「关键信息高亮」): a told line goes on by itself after
## its reading time, one press takes it on at once, a question never goes by itself, the setting
## turns it off; a scene's black bars come in and the HUD steps away; the words the player acts
## on after are lit, found in the shown language.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Still := preload("res://tests/runtime/snow_south_road_test.gd")
var assertions: int = 0
var failures: Array[String] = []


## Two told sequences at once, whatever the map says.
class TwoTellers extends SharedUiWaits:
	var hurried: Array[StringName] = []

	func _collect() -> Array[WorldWait]:
		var waits: Array[WorldWait] = []
		for id: StringName in [&"first", &"second"]:
			var wait := WorldWait.new("", 0.0, func() -> bool:
				hurried.append(id)
				return true)
			wait.teller = id
			waits.append(wait)
		return waits


func run_all(tree: SceneTree) -> Dictionary:
	_check_own_wait()
	_check_read_time()
	_check_spans()
	_check_toasts()
	await _check_text(tree)
	TestFeel.use()
	await _check_scene(tree)
	await _check_reading(tree)
	await _check_ask(tree)
	await _check_feel_off(tree)
	TestFeel.restore()
	return {"assertions": assertions, "failures": failures}


## A line's reading time: the base and so much a character, between the shortest and the longest;
## a language written in letters reads at its own speed; no base, no line goes by itself.
func _check_read_time() -> void:
	var feel: FeelDefinition = FeelDefinition.new().with_values({"dialogue_auto_ms": 800, "dialogue_auto_char_ms": 120, "dialogue_auto_char_ms_en": 55, "dialogue_auto_min_ms": 1500, "dialogue_auto_max_ms": 9000})
	_check(feel.dialogue_auto() and is_equal_approx(feel.dialogue_read_seconds(20), 3.2), "0.8 s and 0.12 s a character: %s" % feel.dialogue_read_seconds(20))
	_check(is_equal_approx(feel.dialogue_read_seconds(2), 1.5), "never under the shortest: %s" % feel.dialogue_read_seconds(2))
	_check(is_equal_approx(feel.dialogue_read_seconds(200), 9.0), "never over the longest: %s" % feel.dialogue_read_seconds(200))
	_check(is_equal_approx(feel.dialogue_read_seconds(20, "en"), 1.9), "English at its own speed: %s" % feel.dialogue_read_seconds(20, "en"))
	_check(is_equal_approx(feel.dialogue_read_seconds(20, "ko"), 3.2) and is_equal_approx(feel.dialogue_read_seconds(20, "zh"), 3.2), "a language without a speed of its own reads as 汉字")
	var off := FeelDefinition.new()
	_check(not off.dialogue_auto() and off.dialogue_read_seconds(20) == 0.0 and off.scene_bars_share() == 0.0, "the feel off: nothing goes by itself, no bars")
	var shipped: FeelDefinition = TestFeel.production
	_check(shipped.dialogue_auto() and shipped.dialogue_read_seconds(10, "ko") > shipped.dialogue_read_seconds(10, "en") and shipped.scene_bars_share() > 0.0, "pacing.json: lines go on by themselves, each language at its speed, bars in")
	_check(is_equal_approx(shipped.dialogue_char_seconds(), 0.012), "pacing.json types 12 ms a character: %s" % shipped.dialogue_char_seconds())
	_check(ApplicationSettingsSnapshot.defaults().dialogue_auto() and not ApplicationSettingsSnapshot.defaults().with_dialogue_auto(false).dialogue_auto(), "对白自动继续 is a setting, on by default")


## Where the lit words stand in a shown line (KeySpans): marked ones first, at most two, none over
## another, each looked for in the shown language; one that is not there is simply not lit.
func _check_spans() -> void:
	var line: String = "他几个起落，往北面的老松岭去了，布条落在地上。"
	var spans: Array[Vector2i] = KeySpans.find(line, ["布条", "老松岭"])
	_check(spans.size() == 2 and _cut(line, spans[0]) == "老松岭" and _cut(line, spans[1]) == "布条", "both marked words, in reading order: %s" % [spans])
	_check(KeySpans.find(line, ["布条", "老松岭"], ["起落", "北面"]).size() == KeySpans.LIMIT, "two places a line at most")
	var found: Array[Vector2i] = KeySpans.find(line, [], ["他", "北面", "老松岭"])
	_check(found.size() == 2 and _cut(line, found[0]) == "北面" and _cut(line, found[1]) == "老松岭", "names found by themselves, never a single character: %s" % [found])
	_check(KeySpans.find(line, ["老松岭"], ["老松"]).size() == 1, "no place lit over another")
	_check(KeySpans.find(line, ["子时"]).is_empty() and KeySpans.missing(line, ["子时", "布条"]) == ["子时"], "a word the line does not have is not lit, and the check names it")
	_check(KeySpans.find("", ["布条"]).is_empty() and KeySpans.find(line, [""]).is_empty(), "nothing to find")
	# Letters: whole words, in any case.
	var english: String = "Li rode to old pine ridge under Lightning."
	var lettered: Array[Vector2i] = KeySpans.find(english, ["Old Pine Ridge", "Li"])
	_check(lettered.size() == 2 and lettered[0] == Vector2i(0, 2) and _cut(english, lettered[1]) == "old pine ridge", "letters match whole words in any case: %s" % [lettered])
	_check(KeySpans.find("Lightning struck.", ["Li"]).is_empty(), "not inside another word")
	# Another language: the word is translated, then looked for in the translated line.
	var translation := Translation.new()
	translation.locale = "en"
	translation.add_message("老松岭", "Old Pine Ridge")
	translation.add_message("子时", "the hour of the rat")
	var locale: String = TranslationServer.get_locale()
	TranslationServer.add_translation(translation)
	TranslationServer.set_locale("en")
	var shown: String = "He made for Old Pine Ridge."
	var translated: Array[Vector2i] = KeySpans.find(shown, ["老松岭", "子时"])
	_check(translated.size() == 1 and _cut(shown, translated[0]) == "Old Pine Ridge", "the shown language's word in the shown line: %s" % [translated])
	_check(KeySpans.missing(shown, ["老松岭", "子时"]) == ["子时"], "a translation that lost the word: listed, nothing breaks")
	# A line read in letters has their reading speed; one still in 汉字 there keeps the 汉字 speed.
	_check(WorldDialogueBox._read_language(shown) == "en" and WorldDialogueBox._read_language("他几个起落，往北面去了。") == "", "the reading speed follows what the line is written in")
	TranslationServer.set_locale(locale)
	TranslationServer.remove_translation(translation)
	# Korean: the word joiners that keep a word whole on a wrapped line take no part.
	var korean: String = KoreanText.keep_words("도사는 노송령으로 갔소.")
	var joined: Array[Vector2i] = KeySpans.find(korean, ["노송령"])
	_check(korean.contains(KoreanText.WORD_JOINER) and joined.size() == 1 and KoreanText.without_joiners(_cut(korean, joined[0])) == "노송령", "a Korean word through its joiners: %s" % [joined])


func _cut(line: String, span: Vector2i) -> String:
	return line.substr(span.x, span.y - span.x)


## What comes while a scene holds the toasts waits for after it, a question in the scene included;
## outside a scene a panel that shows its own lines drops them as before.
func _check_toasts() -> void:
	var toasts := MessageToasts.new()
	toasts.held = true
	toasts.push("演出里得到的东西。")
	toasts.set_suppressed(true)
	toasts.push("问话时又来的一条。")
	toasts.set_suppressed(false)
	_check(toasts._waiting.size() == 2 and toasts.latest_text() == "问话时又来的一条。", "held by a scene: kept through its question: %d" % toasts._waiting.size())
	toasts.held = false
	toasts.set_suppressed(true)
	toasts.push("面板开着时来的一条。")
	_check(toasts._waiting.is_empty(), "outside a scene a panel's own lines are not toasted, as before")
	toasts.free()


## The box's line (DialogueText): wrapped to its width, typed a character at a time, its lit
## places known; a Korean line wraps between words only.
func _check_text(tree: SceneTree) -> void:
	var text := DialogueText.new()
	text.theme = GameTheme.shared()
	text.size = Vector2(300, 0)
	tree.root.add_child(text)
	text.text = "他几个起落，已经翻上山壁，往北面的老松岭去了。布条飘落在地，上头刻着老松寨的记号，你拾起来看看。"
	text.spans = KeySpans.find(text.text, ["老松岭", "布条"])
	await _frames(tree, 2)
	var narrow: int = text.line_count()
	_check(narrow >= 2 and text.get_combined_minimum_size().y > 30.0, "a long line wraps and the control is as tall: %d lines, %s" % [narrow, text.get_combined_minimum_size()])
	var at: int = text.text.find("老松岭")
	_check(text.lit(at) and text.lit(at + 2) and not text.lit(at + 3) and not text.lit(0), "the lit places, character by character")
	# A lit word flares as it has been typed, and a light keeps running along it for as long as the
	# line shows (owner, 2026-11-26): first its first character is the brightest, then its last.
	await _frames(tree, 2)
	_check(text.brightness(at) > 0.9 and text.brightness(at + 2) > 0.9 and text.brightness(0) == 0.0, "the word flares whole as it has been typed: %s" % text.brightness(at))
	await _frames(tree, 40)
	var first_lead: bool = false
	var last_lead: bool = false
	var rests: bool = false
	var unlit: bool = true
	for _i: int in 240:
		await tree.process_frame
		var head: float = text.brightness(at)
		var tail: float = text.brightness(at + 2)
		first_lead = first_lead or head - tail > 0.3
		last_lead = last_lead or (first_lead and tail - head > 0.3)
		rests = rests or (head == 0.0 and tail == 0.0)
		unlit = unlit and text.brightness(0) == 0.0
	_check(first_lead and last_lead and rests and unlit, "a light runs along the lit word again and again, and nowhere else: %s %s %s %s" % [first_lead, last_lead, rests, unlit])
	var tall: float = text.get_combined_minimum_size().y
	text.visible_characters = 3
	await _frames(tree, 2)
	_check(is_equal_approx(text.get_combined_minimum_size().y, tall), "typing out changes no size")
	text.spans = []
	_check(is_equal_approx(text.get_combined_minimum_size().y, tall), "nor does a line with nothing lit")
	text.size.x = 600.0
	await _frames(tree, 2)
	_check(text.line_count() < narrow and text.get_combined_minimum_size().y < tall, "wider, fewer lines: %d against %d" % [text.line_count(), narrow])
	# Korean: a line breaks between words only, never between a word's syllables (KoreanText's joiners).
	var words: String = KoreanText.keep_words("백도장이 천천히 고개를 끄덕이며 노송령으로 가는 길을 손가락으로 가리켰다.")
	text.size.x = 150.0
	text.text = words
	await _frames(tree, 2)
	var whole: bool = text.line_count() >= 3
	for index: int in range(1, text.line_count()):
		var start: int = text.line_range(index).x
		whole = whole and start > 0 and words[start - 1] == " "
	_check(whole, "Korean breaks between words only: %d lines" % text.line_count())
	text.queue_free()
	await _frames(tree, 2)


## Read out, a line brings on its own teller's next: not the first sequence on the card.
func _check_own_wait() -> void:
	var waits := TwoTellers.new(null)
	_check(waits.hurry_teller(&"second") and waits.hurried == [&"second"], "the second teller's sequence, though the first is listed first: %s" % [waits.hurried])
	_check(not waits.hurry_teller(&"") and not waits.hurry_teller(&"nobody") and waits.hurried.size() == 1, "nobody's line brings on nothing")


## 寻剑令's scene at 黄石隘口: each line waits in the box, the world stands still while it is
## read, E goes on and the next line comes at once; the scene ends after the last.
func _check_scene(tree: SceneTree) -> void:
	var session: WorldSessionController = Work.create_session(tree)
	session.configure_npc_ambience_random_source(Still.Still.new())
	await _frames(tree, 4)
	var hud: SharedGameplayUI = session.shared_ui()
	var box: WorldDialogueBox = hud.dialogue_box
	var map: WorldMapController = await _begin_scene(tree, session)
	_check(map != null and map.map_id() == &"canyon.pass", "on the pass")
	if map == null:
		session.free()
		return
	for _i: int in 900:
		await tree.process_frame
		if box.is_open():
			break
	_check(map.scene_running(), "the scene runs")
	# The black bars slide in and the HUD steps away (DECISIONS「过场黑边」).
	for _i: int in 90:
		await tree.process_frame
		if hud.scene_bars.progress >= 1.0:
			break
	_check(hud.scene_bars.progress >= 1.0 and hud.scene_bars.bar_height() > 0.0 and hud.scene_covered(), "the bars are in: %s" % hud.scene_bars.progress)
	_check(is_zero_approx(hud._presentation_layout.bar.modulate.a) and is_zero_approx(hud._presentation_layout.toasts.modulate.a) and hud._presentation_layout.toasts.held, "the status card and the toasts are away, the toasts keeping what comes")
	_check(is_equal_approx(hud.dialogue_box.modulate.a, 1.0) and box.is_open(), "the dialogue box stays")
	_check(box.is_open() and box.speaker().is_empty(), "what happens is told by nobody: no name over 一名武官捧出石匣: %s" % box.speaker())
	_check(hud._presentation_layout.toasts.lift > 0.0, "the toasts stand on the box")
	var focus: StringName = map.npc_life.scene_focus_id
	_check(hud.speech_bubbles.text_of(focus).is_empty(), "no bubble says it too")
	_check(session.presentation_frozen() and map.player_body.walk_paused, "the world holds still while it is read")
	var first: String = box.line()
	_check(not first.contains("道："), "without who says it: %s" % first)
	_check(hud.log_lines().any(func(line: String) -> bool: return line.contains(first)), "消息 has it")
	var minutes: float = session.day_clock().day_minutes()
	await tree.create_timer(0.4).timeout
	_check(box.line() == first and is_equal_approx(session.day_clock().day_minutes(), minutes), "it waits for the player")
	_check(box.auto_left() < 0.0, "the suites' feel: no line goes on by itself")
	var read: int = 1
	var spoken: Array[String] = []
	var lit: Dictionary[String, Array] = {}
	var tail_bars: float = -1.0
	for _i: int in 200:
		if not box.is_open() and not map.scene_running():
			break
		if box.is_open():
			var at: String = box.line()
			if not box.lit_words().is_empty():
				lit[at] = box.lit_words()
			# The scene's steps are done before its last line is read: the bars stay for it.
			if not map.scene_running():
				tail_bars = hud.scene_bars.progress
			# One press, one line (DECISIONS「过场读法」), typed out or not.
			_press(hud)
			await _frames(tree, 3)
			if box.is_open() and box.line() != at:
				read += 1
				spoken.append(box.speaker())
		else:
			await tree.process_frame
	_check(read >= 10, "one press a line, every line read: %d" % read)
	_check(spoken.has(tr("白道长")) and spoken.has(tr("冯策")), "each line under who says it: %s" % [spoken])
	_check(not map.scene_running() and not session.scene_held() and not session.presentation_frozen(), "over, and the world runs again")
	_check(hud._presentation_layout.toasts.lift == 0.0, "the toasts back at the foot")
	# The marked words were lit as the lines were read, and are lit in 消息 (DECISIONS「关键信息高亮」).
	var words: Array = []
	for each: Array in lit.values():
		words.append_array(each)
	_check(lit.size() >= 2 and words.has("布条") and words.has("老松岭") and words.has("老松寨"), "the scene's marked lines lit their words: %s" % [lit])
	var log: Array[String] = hud.log_lines()
	var log_spans: Array[Array] = hud.message_log.log_spans()
	var lit_in_log: int = 0
	var asked: Array[String] = []
	for index: int in log.size():
		if log_spans[index].is_empty():
			continue
		if log[index].contains("老松"):
			lit_in_log += 1
		else:
			# 打听's answers on the way here: lit for where the quest sent the player next.
			for span: Vector2i in log_spans[index]:
				asked.append(_cut(log[index], span))
	_check(log.size() == log_spans.size() and lit_in_log == 2 and hud.combat_log.text.contains("[u]老松寨[/u]"), "消息 lights the scene's same two lines: %d" % lit_in_log)
	_check(asked.has("广场"), "打听's answers lit the next step's place by themselves: %s" % [asked])
	_check(is_equal_approx(tail_bars, 1.0), "the bars stayed while the last line was read: %s" % tail_bars)
	for _i: int in 90:
		await tree.process_frame
		if hud.scene_bars.progress <= 0.0:
			break
	_check(hud.scene_bars.progress <= 0.0 and not hud.scene_covered() and is_equal_approx(hud._presentation_layout.bar.modulate.a, 1.0) and not hud._presentation_layout.toasts.held, "the bars slide out and the HUD is back")
	# What the next steps lead to is lit by itself (StoryKeyTerms): the strip the quest sends them for.
	var terms: Array[String] = hud.key_terms()
	_check(not terms.is_empty() and not terms.has("白道长"), "the next steps' names, not who stands here: %s" % [terms])
	session.free()
	await _frames(tree, 2)


## Told lines go on by themselves (DECISIONS「过场读法」): after the line has typed out and its
## reading time has passed; a press right after is not taken; one press goes on even while the line
## types; the setting off, the open menu and a question hold it.
func _check_reading(tree: SceneTree) -> void:
	# 0.6 s a line whatever its length, typed 5 ms a character, a press not taken for 0.1 s.
	GameContent.catalog().pacing().feel = TestFeel.production.but({"map_loading_slice_ms": 0, "session_start_slice_ms": 0, "dialogue_char_ms": 5, "dialogue_auto_ms": 600, "dialogue_auto_char_ms": 0, "dialogue_auto_min_ms": 600, "dialogue_auto_max_ms": 600, "dialogue_press_guard_ms": 100})
	var was_on: bool = DialogueAuto.on
	DialogueAuto.on = true
	var session: WorldSessionController = Work.create_session(tree)
	session.configure_npc_ambience_random_source(Still.Still.new())
	await _frames(tree, 4)
	var hud: SharedGameplayUI = session.shared_ui()
	var box: WorldDialogueBox = hud.dialogue_box
	var map: WorldMapController = session.active_map() as WorldMapController
	var npc: NpcRuntimeState = _askable(map)
	var long: String = "第三句话很长，".repeat(12)
	var pages: Array[String] = ["第一句话。", "第二句话。", long, "第四句话。", "第五句话。", "第六句话。"]
	var read_out: Array[StringName] = []
	var on_read: Callable = func(teller: StringName) -> void: read_out.append(teller)
	box.read_out.connect(on_read)
	box.say(tr(npc.definition().display_name), pages, &"told", npc)
	_check(box.line() == pages[0] and is_equal_approx(box.auto_left(), 0.6), "a told line has its reading time: %s" % box.auto_left())
	var frames: int = await _until_line(tree, box, pages[1], 120)
	# 5 characters typed 5 ms each, then 0.6 s read: about 38 frames at 60 a second.
	_check(box.line() == pages[1] and frames >= 34 and frames <= 44, "the next line came by itself after the reading time: %d frames" % frames)
	_press(hud)
	await _frames(tree, 1)
	_check(box.line() == pages[1], "a press right after a line came by itself is not taken")
	await _frames(tree, 8)
	_press(hud)
	_check(box.line() == pages[2], "one press: the next line")
	await _frames(tree, 3)
	_check(box.typing(), "the long line is still typing")
	_press(hud)
	_check(box.line() == pages[3], "one press goes on even while the line types: no press spent on showing it whole")
	# The setting off: each line waits for its press.
	DialogueAuto.on = false
	_check(box.auto_left() < 0.0, "对白自动继续 off: the line waits")
	await _frames(tree, 70)
	_check(box.line() == pages[3], "and stays however long")
	_press(hud)
	_check(box.line() == pages[4], "one press still takes it on")
	DialogueAuto.on = true
	# The open menu holds the box as it stands.
	hud.open_menu()
	await _frames(tree, 70)
	_check(hud.menu.is_presented() and box.line() == pages[4], "the menu open: the line stays")
	hud.close_menu()
	frames = await _until_line(tree, box, pages[5], 120)
	_check(box.line() == pages[5], "the menu closed: it goes on: %d frames" % frames)
	# A question waits behind the last line (问话, 三选一): read out by itself, the line brings it up,
	# and the press meant for that line picks no answer — nothing is under the key until the guard is over.
	var answers: Array[String] = ["一", "二"]
	var picked: Array[int] = []
	hud.ask_choices(npc, "问题", answers, func(chosen: int) -> void: picked.append(chosen))
	_check(not box.hosting(), "the question waits for the last line")
	for _i: int in 120:
		await tree.process_frame
		if box.hosting():
			break
	_check(box.hosting() and read_out == [&"told"] and box.guarded(), "the last line read out by itself, the question up: %s" % [read_out])
	var focused: Control = tree.root.gui_get_focus_owner()
	_check(focused == null or not hud.confirm_prompt.is_ancestor_of(focused), "no answer under the key yet")
	_press(hud)
	var accept := InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = true
	hud._unhandled_input(accept)
	await _frames(tree, 1)
	_check(picked.is_empty() and box.hosting(), "the press meant for the line that went picks nothing")
	await _frames(tree, 12)
	focused = tree.root.gui_get_focus_owner()
	_check(not box.guarded() and focused != null and hud.confirm_prompt.is_ancestor_of(focused), "the guard over: the first answer has the focus")
	# A question never goes by itself.
	_check(box.auto_left() < 0.0, "a question waits for the player")
	await _frames(tree, 90)
	_check(box.hosting() and hud.is_asking() and picked.is_empty(), "however long: nothing is chosen for them")
	hud.confirm_prompt.cancel()
	await _frames(tree, 2)
	if box.is_open():
		box.close()
	box.read_out.disconnect(on_read)
	DialogueAuto.on = was_on
	session.free()
	await _frames(tree, 2)
	TestFeel.use()


## Frames until the box shows `line` (`most` at most).
func _until_line(tree: SceneTree, box: WorldDialogueBox, line: String, most: int) -> int:
	for frame: int in most:
		if box.line() == line:
			return frame
		await tree.process_frame
	return most


## 打听 from the popup: the box takes over from it, topics under the text, the answer in
## place; 告辞 leaves it, the world running again.
func _check_ask(tree: SceneTree) -> void:
	var session: WorldSessionController = Work.create_session(tree)
	session.configure_npc_ambience_random_source(Still.Still.new())
	await _frames(tree, 4)
	var hud: SharedGameplayUI = session.shared_ui()
	var box: WorldDialogueBox = hud.dialogue_box
	var map: WorldMapController = session.active_map() as WorldMapController
	var npc: NpcRuntimeState = _askable(map)
	_check(npc != null, "someone to ask")
	if npc == null:
		session.free()
		return
	map.select_npc(npc.character_id)
	hud.open_ask()
	await _frames(tree, 2)
	_check(box.hosting() and box.speaker() == tr(npc.definition().display_name), "打听 opens in the box")
	_check(not hud.panel_open(), "not in the shared frame")
	var topics: Array[String] = hud.ask_topics_shown()
	_check(not topics.is_empty(), "the topics: %s" % [topics])
	_check(session.presentation_frozen(), "the world holds still")
	await tree.create_timer(0.3).timeout
	_check(map.selected_npc() == npc, "the box holds the selection while the HUD refreshes")
	var topic: Button = box.hosted().find_child("Topic", true, false) as Button
	topic.pressed.emit()
	# The answer typing out, the next press only finishes it: nothing is asked again.
	var asked: int = hud.log_lines().size()
	topic.pressed.emit()
	_check(hud.log_lines().size() == asked, "the press that finishes the typing asks nothing")
	await _frames(tree, 2)
	_check(box.hosting() and not box.line().is_empty() and box.line() != tr("你可以打听这些事情："), "the answer shows above the topics: %s" % box.line())
	_check(not box.line().contains("打听有关"), "from the answer, not ask.c's own line")
	var waited: float = session.day_clock().day_minutes()
	await _frames(tree, 3)
	_check(hud.ask_answer_text() != "" and is_equal_approx(session.day_clock().day_minutes(), waited), "the answer stays, time does not pass")
	box.answer_as_written(["你说道：必有妖孽"])
	_check(box.line() == "你说道：必有妖孽", "the player's own line is not taken for the speaker's")
	(box.hosted().find_child("Leave", true, false) as Button).pressed.emit()
	await _frames(tree, 2)
	_check(not box.is_open() and not session.presentation_frozen(), "告辞: back in the world")
	# A scripted question with answers (番坊 B's 火前问话) speaks with its asker: their bust.
	var answers: Array[String] = ["一", "二"]
	hud.ask_choices(npc, "问题", answers, func(_picked: int) -> void: pass)
	await _frames(tree, 2)
	_check(box.hosting() and box.who() == npc, "a question with answers speaks with its asker")
	hud.confirm_prompt.cancel()
	await _frames(tree, 2)
	if box.is_open():
		box.close()
		await _frames(tree, 2)
	# A question waiting for the box to be read out goes when the box is shut unread (a fight,
	# a fall): a later dialogue read out does not bring it up (审查修补 M).
	var first: Array[String] = ["先说一句。"]
	box.say(npc.definition().display_name, first)
	hud.ask_choices(npc, "旧问题", answers, func(_picked: int) -> void: pass)
	_check(box.is_open() and not box.hosting(), "the question waits for the box")
	box.close()
	var later: Array[String] = ["后来的话。"]
	box.say(npc.definition().display_name, later)
	box.finish_typing()
	box.advance()
	await _frames(tree, 2)
	_check(not box.hosting() and not hud.confirm_prompt.is_asking(), "shut unread, the old question never comes up after a later dialogue")
	if box.is_open():
		box.close()
		await _frames(tree, 2)
	# Chat stays over the head; what is told is read; a fight shuts the box.
	var said: Array[ColoredLine] = [ColoredLine.new("%s说道：今天天气不错。" % npc.definition().display_name)]
	hud.npc_says(npc, said, ["%s说道：今天天气不错。" % npc.definition().display_name])
	_check(not box.is_open() and hud.speech_bubbles.text_of(npc.character_id) == "今天天气不错。", "chat: a bubble, no box")
	hud.speech_bubbles.forget(npc.character_id)
	map.npc_life.teller = npc.character_id
	hud.npc_says(npc, said, ["%s说道：今天天气不错。" % npc.definition().display_name, "%s说道：第二句。" % npc.definition().display_name])
	map.npc_life.teller = &""
	_check(box.is_open() and box.line() == "今天天气不错。" and box.pages_left() == 1, "a told line: a page each")
	_check(hud.speech_bubbles.text_of(npc.character_id).is_empty(), "told: no bubble")
	# Not by the selection: with the box shut a HUD refresh may have dropped one out of reach.
	map.npc_kills_player(npc)
	_check(session.combat_encounter_coordinator().has_active_encounter(), "a fight begins under the box")
	await _frames(tree, 3)
	_check(not box.is_open() and box.pages_left() == 0, "a fight shuts the box")
	session.free()
	await _frames(tree, 2)


## The suites' feel: no box, as before.
func _check_feel_off(tree: SceneTree) -> void:
	TestFeel.restore()
	var session: WorldSessionController = Work.create_session(tree)
	session.configure_npc_ambience_random_source(Still.Still.new())
	await _frames(tree, 4)
	var hud: SharedGameplayUI = session.shared_ui()
	var map: WorldMapController = session.active_map() as WorldMapController
	var npc: NpcRuntimeState = _askable(map)
	if npc != null:
		map.select_npc(npc.character_id)
		hud.open_ask()
		await _frames(tree, 2)
		_check(hud.panel_open() and not hud.dialogue_box.is_open(), "the feel off: 打听 in the shared frame")
		hud.dismiss_current_panel()
	# No bars either: a scene leaves the HUD where it is, and 消息 lights nothing.
	session.hold_scene(true)
	await _frames(tree, 30)
	_check(is_zero_approx(hud.scene_bars.progress) and not hud.scene_covered() and is_equal_approx(hud._presentation_layout.bar.modulate.a, 1.0), "the feel off: no bars, the status card stays")
	session.hold_scene(false)
	if npc != null:
		var said := ColoredLine.new("%s说道：往老松岭去。" % npc.definition().display_name)
		said.keys = ["老松岭"]
		var lines: Array[ColoredLine] = [said]
		hud.npc_says(npc, lines, [said.text])
		_check(hud.message_log.log_spans()[-1].is_empty(), "the feel off: nothing is lit")
	session.free()
	await _frames(tree, 2)
	TestFeel.use()


## Up 寻剑令 as far as 黄石隘口, as sword_decree_test walks it, onto the pass.
func _begin_scene(tree: SceneTree, session: WorldSessionController) -> WorldMapController:
	var state: CharacterState = session.player_runtime().state
	PlayerEssenceMagic.meet(state, _npc_of(session, &"snow.npc.waiter"), false)
	session.record_journal()
	var map: WorldMapController = session.active_map() as WorldMapController
	map.place_player(&"snow.inn.main_floor", MapPlaces.spot(map, &"snow.inn.main_floor", map.runtime_body_for_character(_npc_of(session, &"snow.npc.waiter").character_id).global_position))
	await _frames(tree, 3)
	map.select_npc(_npc_of(session, &"snow.npc.waiter").character_id)
	map.ask_selected("官爷")
	map = MapPlaces.enter(session, &"snow.square", &"snow.square.inn_entry")
	if map == null:
		return null
	await _frames(tree, 3)
	var feng: NpcRuntimeState = _npc_of(session, &"native.npc.feng_ce")
	map.place_player(&"snow.square", MapPlaces.spot(map, &"snow.square", map.runtime_body_for_character(feng.character_id).global_position))
	await _frames(tree, 3)
	map.select_npc(feng.character_id)
	map.ask_selected("寻剑")
	return MapPlaces.enter(session, &"canyon.canyon1", &"canyon.canyon1.chain_arrival")


func _npc_of(session: WorldSessionController, id: StringName) -> NpcRuntimeState:
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			if npc.definition().definition_id == id and npc.exists_in_map:
				return npc
	return null


func _askable(map: WorldMapController) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.exists_in_map and not npc.definition().talk().inquiry_topics().is_empty():
			return npc
	return null


func _press(hud: SharedGameplayUI) -> void:
	var key := InputEventAction.new()
	key.action = &"interact"
	key.pressed = true
	hud._unhandled_input(key)


func _frames(tree: SceneTree, count: int) -> void:
	for _i: int in count:
		await tree.process_frame


func _check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures.append(label)
