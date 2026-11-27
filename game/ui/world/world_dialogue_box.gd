class_name WorldDialogueBox
extends Control

## The dialogue box at the foot of the screen (DECISIONS「对话框」): what the player reads
## goes here, line by line, the speaker's name above it; what only sets the mood stays in
## the bubbles over people's heads. A scene's lines and a told story come as pages (say()),
## each waiting for 继续; 打听 hosts its topics under the text (host()). While it shows, the
## world holds still and the player does not walk: reading takes nobody's time.
## 界面重做 3: the box is a deep planked slab, the speaker on a lacquer name plate over its
## top edge (GameTheme's DialoguePanel and PlatePanel).
## 人物立绘 (DECISIONS「人物外观」): the speaking NPC's bust stands behind the box's right end,
## the player's behind its left (PersonPortraits), the one who speaks now lit, the other dimmed;
## the name plate goes beside the speaker's. Someone without a picture shows none.
## 过场演出 A (DECISIONS「过场读法」「关键信息高亮」): a page (what is told: a scene, a story) goes on
## by itself once typed out and read (FeelDefinition.dialogue_read_seconds(), the setting
## 对白自动继续), and one press of E / A / a click takes it on at once, typed out or not. What the
## box hosts (打听's answers, a question's answers) never goes on by itself. The words the player
## acts on after are lit (DialogueText, KeySpans).

## The box closed: what `teller` was telling goes on (the HUD hurries its next line).
signal read_out(teller: StringName)
## The box was shut before it was read out (a fight, a fall, 走开): no read_out follows.
signal closed_unread

const HOLD: StringName = &"dialogue"
const WIDTH_SHARE: float = 0.62
const MIN_WIDTH: float = 560.0
const MAX_WIDTH: float = 900.0
const BOTTOM_MARGIN: float = 18.0
const NAME_SIZE: int = 18
const TEXT_SIZE: int = 18
const TEXT_COLOR: Color = UiPalette.BONE
## What the speaker does rather than says.
const DEED_COLOR: Color = UiPalette.MUTED
## The name plate's left edge in from the box's, and how far it rises over the box's top.
const PLATE_INSET: float = 22.0
const PLATE_OVERLAP: float = 12.0
## How far a bust stands in from the box's end, and how far its foot goes behind the box.
const BUST_INSET: float = 10.0
const BUST_SINK: float = 10.0
## The bust of whoever is not speaking now.
const BUST_DIM := Color(0.58, 0.56, 0.6)

var _ui: SharedGameplayUI
var _panel: PanelContainer
## The speaker's lacquer plate over the box's top edge (shown while a name is).
var _plate: PanelContainer
var _name: Label
var _text: DialogueText
var _hint: Button
var _mount: VBoxContainer
## The busts behind the box's ends (人物立绘).
var _npc_bust: TextureRect
var _player_bust: TextureRect
## The NPC the box speaks with now (its bust), null for none.
var _who: NpcRuntimeState
## Pages still to read, the one shown first: [speaker, text, is it said, the NPC saying it, its
## marked words (ColoredLine.keys)].
var _pages: Array[Array] = []
var _hosted: Control
var _hosted_parent: Node
## Whose told sequence the pages are ("" none).
var _teller: StringName = &""
## Characters shown so far of the page.
var _typed: float = 0.0
## Seconds the page still stays up once typed out, before it goes on by itself (auto_left()).
var _read_left: float = 0.0
## Seconds a press is still not taken: the line came by itself a moment ago, and the press was
## meant for the one that went (FeelDefinition.dialogue_press_guard_seconds()).
var _guard: float = 0.0
## What takes the focus once the guard is over (a question hosted the moment a line went by
## itself: its first answer is not under the key until then).
var _focus_later: Control


func configure(ui: SharedGameplayUI) -> void:
	_ui = ui


func _ready() -> void:
	name = "WorldDialogueBox"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = GameTheme.shared()
	# Before the box: their feet go behind it.
	_player_bust = _bust("PlayerBust")
	_npc_bust = _bust("NpcBust")
	_panel = PanelContainer.new()
	_panel.name = "Box"
	_panel.theme_type_variation = &"DialoguePanel"
	_panel.gui_input.connect(_on_panel_input)
	add_child(_panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	_panel.add_child(rows)
	# Room under the plate that rises over the box's top edge.
	var under_plate := Control.new()
	under_plate.name = "UnderPlate"
	under_plate.custom_minimum_size.y = 6
	under_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(under_plate)
	_plate = PanelContainer.new()
	_plate.name = "NamePlate"
	_plate.theme_type_variation = &"PlatePanel"
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate)
	_name = Label.new()
	_name.name = "Speaker"
	_name.add_theme_font_size_override("font_size", NAME_SIZE)
	_name.add_theme_color_override("font_color", Color("fff3dc"))
	# A name from the content, shown as given (the speaker's tr() was made).
	_name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_plate.add_child(_name)
	# Laid out whole: the box keeps its size and no word jumps as the line types out.
	_text = DialogueText.new()
	_text.name = "Line"
	_text.font_size = TEXT_SIZE
	rows.add_child(_text)
	_mount = VBoxContainer.new()
	_mount.name = "Choices"
	rows.add_child(_mount)
	_hint = Button.new()
	_hint.name = "Continue"
	# TRANSLATORS: at the foot of the dialogue box, after the key's glyph (E): goes to the next line.
	_hint.text = "下一句"
	_hint.flat = true
	_hint.add_theme_color_override("font_color", UiPalette.GOLD)
	_hint.add_theme_color_override("font_hover_color", UiPalette.LANTERN)
	_hint.focus_mode = Control.FOCUS_NONE
	_hint.size_flags_horizontal = Control.SIZE_SHRINK_END
	_hint.pressed.connect(advance)
	InputGlyphs.decorate(_hint, &"interact")
	rows.add_child(_hint)
	_panel.hide()
	_plate.hide()
	get_viewport().size_changed.connect(_place)
	_panel.minimum_size_changed.connect(_place)
	_place()


func is_open() -> bool:
	return _panel != null and _panel.visible


## 打听 and the like: the box stays until closed, its choices under the text.
func hosting() -> bool:
	return _hosted != null


func hosted() -> Control:
	return _hosted


## The speaker shown now ("" with none).
func speaker() -> String:
	return _name.text if is_open() else ""


## The page shown now, whole, however far it has been typed.
func line() -> String:
	return _text.text if is_open() else ""


## The words lit in the line shown now, in reading order (DECISIONS「关键信息高亮」).
func lit_words() -> Array[String]:
	var words: Array[String] = []
	if is_open():
		for span: Vector2i in _text.spans:
			words.append(KoreanText.without_joiners(_text.text.substr(span.x, span.y - span.x)))
	return words


## Whether the line shown now is still typing out.
func typing() -> bool:
	return is_open() and _typing()


## The pages after the one shown.
func pages_left() -> int:
	return maxi(_pages.size() - 1, 0)


## `speaker_name` (the NPC `who`, whose bust shows; null for none) says `lines` (as the log
## shows them) of `teller`'s story: a page each, after those still unread. `keys`: each line's
## marked words (ColoredLine.keys), line by line; none marked when left out.
func say(speaker_name: String, lines: Array[String], teller: StringName = &"", who: NpcRuntimeState = null, keys: Array[Array] = []) -> void:
	# Over 打听's topics a page would wait for a 下一句 that is not there.
	if hosting():
		answer(lines)
		return
	_teller = teller
	var unread: bool = not _pages.is_empty()
	for index: int in lines.size():
		var text: String = lines[index]
		var page: String = WorldSpeechBubbles.bubble_text(text)
		if not page.is_empty():
			var marked: Array[String] = []
			if index < keys.size():
				marked.assign(keys[index])
			_pages.append([speaker_name, page, WorldSpeechBubbles.is_speech(text), who, marked])
	if not _pages.is_empty() and not unread:
		_open()
		_show_page()


## `content` (its buttons) shows under the text until close(), the box speaking with `who`.
func host(speaker_name: String, content: Control, who: NpcRuntimeState = null) -> void:
	_release_hosted()
	_hosted = content
	_hosted_parent = content.get_parent()
	# Content made for the conversation alone has no home yet: the box takes it in and lets it
	# go again on close.
	if _hosted_parent == null:
		_mount.add_child(content)
	else:
		content.reparent(_mount, false)
	content.show()
	_name.text = speaker_name
	_name.show()
	_who = who
	_open()
	_hint.hide()
	# The player's turn: they choose what to ask.
	_show_busts(true, false)
	# The busts and the plate's place for this conversation, not the last one.
	_place()


## The NPC the box speaks with now (null for none).
func who() -> NpcRuntimeState:
	return _who if is_open() else null


## Whether the bust behind the box's `left` (the player's) or right end shows a picture.
func bust_shown(left: bool) -> bool:
	var bust: TextureRect = _player_bust if left else _npc_bust
	return bust != null and bust.visible and bust.texture != null


## The picture behind the box's `left` or right end (null for none).
func bust_texture(left: bool) -> Texture2D:
	return (_player_bust if left else _npc_bust).texture if bust_shown(left) else null


## Whether the bust behind the box's `left` or right end is lit (its owner speaks now).
func bust_lit(left: bool) -> bool:
	return bust_shown(left) and (_player_bust if left else _npc_bust).modulate == Color.WHITE


## `lines` show above the hosted choices (the NPC's answer), without who says them; the NPC's
## bust lit.
func answer(lines: Array[String]) -> void:
	var said: Array[String] = []
	for text: String in lines:
		var page: String = WorldSpeechBubbles.bubble_text(text)
		if not page.is_empty():
			said.append(page)
	_write_answer(said)
	_show_busts(false, true)


## `lines` above the hosted choices as they stand (你向…打听, 你说道：…, the topics' prompt: the
## player's own words or turn, not the NPC's); the player's bust lit.
func answer_as_written(lines: Array[String]) -> void:
	_write_answer(lines)
	_show_busts(true, false)


func _write_answer(lines: Array[String]) -> void:
	# Each line lit for itself (KeySpans.LIMIT a line), then set one under the other.
	var found: Array[String] = _found_terms()
	var shown: String = ""
	var spans: Array[Vector2i] = []
	for line: String in lines:
		var each: String = KoreanText.shown(line)
		if not shown.is_empty():
			shown += "\n"
		for span: Vector2i in KeySpans.find(each, [], found):
			spans.append(span + Vector2i(shown.length(), shown.length()))
		shown += each
	_text.text = shown
	_text.spans = spans
	_text.color = TEXT_COLOR
	_start_typing()
	_text.visible = not lines.is_empty()


## The page still typing shows whole. False when it already did.
func finish_typing() -> bool:
	if not is_open() or not _typing():
		return false
	_finish_typing()
	return true


## A hosted box turns to telling: its choices go, `lines` of `teller`'s read on as pages.
func tell(speaker_name: String, lines: Array[String], teller: StringName = &"") -> void:
	var who: NpcRuntimeState = _who
	_release_hosted()
	_text.text = ""
	_pages.clear()
	say(speaker_name, lines, teller, who)
	if _pages.is_empty():
		close()


## 下一句 (E / A / a click; DECISIONS「过场读法」): the next page at once, typed out or not, else
## the box closes. A press right after a line came by itself is not taken (it was meant for the
## line that went). False when shut, or hosting (its choices take the key).
func advance() -> bool:
	if not is_open() or hosting():
		return false
	if _guard > 0.0:
		return true
	_next_page()
	return true


## A line went by itself a moment ago: the press that comes now was meant for it and takes
## nothing on — not the next line, not a question's answer, not what the place offers (the HUD
## asks before it hands the key to anything).
func guarded() -> bool:
	return _guard > 0.0


## `control` (a hosted question's first answer) takes the focus: now, or once the guard is over.
func give_focus(control: Control) -> void:
	if guarded():
		_focus_later = control
	else:
		FocusNav.give(control)


## Seconds until the page goes on by itself; -1 when it waits for the player (nothing told, the
## setting off, no reading time in the feel).
func auto_left() -> float:
	if not is_open() or hosting() or _pages.is_empty() or not _auto():
		return -1.0
	return _read_left


func _next_page() -> void:
	_pages.pop_front()
	if _pages.is_empty():
		var teller: StringName = _teller
		_shut()
		read_out.emit(teller)
	else:
		_show_page()


## Closes it at once: what was unread stays in 消息.
func close() -> void:
	_shut()
	closed_unread.emit()


func _shut() -> void:
	_pages.clear()
	_teller = &""
	_who = null
	_release_hosted()
	if _panel != null:
		_panel.hide()
		_place()
	var session: WorldSessionController = null if _ui == null else _ui.session()
	if session != null:
		session.hold_presentation(HOLD, false)


func _open() -> void:
	_panel.show()
	_hint.visible = not hosting()
	_ui.session().hold_presentation(HOLD, true)
	_place()


func _show_page() -> void:
	var page: Array = _pages[0]
	# What happens is told by nobody (一名武官捧出石匣): no name over it.
	_name.text = page[0] if page[2] else ""
	_name.visible = page[2]
	_text.text = page[1]
	var marked: Array[String] = []
	marked.assign(page[4])
	_text.spans = KeySpans.find(page[1], marked, _found_terms())
	_text.visible = true
	_text.color = TEXT_COLOR if page[2] else DEED_COLOR
	_read_left = GameContent.catalog().pacing().feel.dialogue_read_seconds(_read_length(page[1]), _read_language(page[1]))
	if page[3] != null:
		_who = page[3]
	_show_busts(false, page[2])
	_start_typing()
	_place()


## The busts for the box now: the NPC's (its face by its attitude) and the player's, when the
## box speaks with someone who has a picture (with someone who has none, neither shows: not the
## player alone). Lit: the player's when `player_lit`, the NPC's when `npc_lit`.
func _show_busts(player_lit: bool, npc_lit: bool) -> void:
	var npc_picture: Texture2D = null
	var player_picture: Texture2D = null
	if _who != null:
		npc_picture = PersonPortraits.bust(PersonPortraits.npc_id(_who), PersonPortraits.expression(_who))
	if npc_picture != null:
		var session: WorldSessionController = null if _ui == null else _ui.session()
		var player: WorldPlayerRuntimeState = null if session == null or session.active_map() == null else (session.active_map() as WorldMapController).player_runtime()
		if player != null:
			player_picture = PersonPortraits.bust(PersonPortraits.player_id(String(player.state.gender)))
	_npc_bust.texture = npc_picture
	_player_bust.texture = player_picture
	_npc_bust.modulate = Color.WHITE if npc_lit else BUST_DIM
	_player_bust.modulate = Color.WHITE if player_lit else BUST_DIM


func _bust(node_name: String) -> TextureRect:
	var bust := TextureRect.new()
	bust.name = node_name
	bust.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bust.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bust.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bust.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bust.hide()
	add_child(bust)
	return bust


func _start_typing() -> void:
	_typed = 0.0
	_text.visible_characters = 0 if GameContent.catalog().pacing().feel.dialogue_char_seconds() > 0.0 else -1


func _typing() -> bool:
	return _text.visible_characters >= 0


func _finish_typing() -> void:
	_text.visible_characters = -1


func _process(delta: float) -> void:
	# The guard runs down whether the box shows or not: the next box takes its first press.
	if _guard > 0.0:
		_guard = maxf(_guard - delta, 0.0)
		if _guard <= 0.0 and is_instance_valid(_focus_later):
			if hosting() and _hosted.is_ancestor_of(_focus_later) and _focus_later.is_visible_in_tree():
				FocusNav.give(_focus_later)
			_focus_later = null
	if not is_open():
		return
	# A fight, a fall or a death takes the screen: the lines are in 消息.
	var session: WorldSessionController = _ui.session()
	if session == null or session.combat_encounter_coordinator().has_active_encounter() or session.player_runtime().life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
		close()
		return
	# 系统, the focus pause and a question over the box hold it as it stands.
	if _held():
		return
	if _typing():
		_typed += delta / maxf(GameContent.catalog().pacing().feel.dialogue_char_seconds(), 0.001)
		# A Korean line's word joiners take no time (KoreanText).
		var typed: int = KoreanText.index_after(_text.text, int(_typed))
		_text.visible_characters = -1 if typed >= _text.text.length() else typed
	elif not hosting() and not _pages.is_empty() and _auto():
		_read_left -= delta
		if _read_left <= 0.0:
			_guard = GameContent.catalog().pacing().feel.dialogue_press_guard_seconds()
			_next_page()


## Whether told pages go on by themselves: the feel gives a reading time and the setting is on.
func _auto() -> bool:
	return DialogueAuto.on and GameContent.catalog().pacing().feel.dialogue_auto()


## The box stands as it is: the game is paused (系统, the window left), the menu is open, a
## question lies over it in the shared frame, or a card covers the world and has the key (the
## opening card, 拜师, a death; the rest and the 切磋 summary).
func _held() -> bool:
	if get_tree().paused:
		return true
	if _ui == null:
		return false
	if _ui.menu.is_presented() or _ui.panel_open():
		return true
	if is_instance_valid(_ui.life_overlay) and (_ui.life_overlay.card_shown() or _ui.life_overlay.is_blocking()):
		return true
	return (is_instance_valid(_ui.rest_overlay) and _ui.rest_overlay.shown()) or (is_instance_valid(_ui.spar_summary) and _ui.spar_summary.shown())


## The characters of `text` a reader reads: no spaces, no joiners.
static func _read_length(text: String) -> int:
	var count: int = 0
	for index: int in text.length():
		if not text[index] in [" ", "\n", "\t", "　", KoreanText.WORD_JOINER]:
			count += 1
	return count


## The language `text` is read in: the shown language's, unless the line is still in 汉字 there
## (a line not translated yet reads at the 汉字 speed, not at a letter's).
static func _read_language(text: String) -> String:
	var language: String = TranslationServer.get_locale().get_slice("_", 0)
	if language == "ja" or not language in FeelDefinition.AUTO_LANGUAGES:
		return language
	var han: int = 0
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		if code >= 0x4E00 and code <= 0x9FFF:
			han += 1
	return "" if han * 2 >= _read_length(text) else language


## The names the next quest steps lead to (StoryKeyTerms): lit wherever a line says one.
func _found_terms() -> Array[String]:
	var found: Array[String] = []
	if _ui != null:
		found = _ui.key_terms()
	return found


func _release_hosted() -> void:
	var content: Control = _hosted
	var parent: Node = _hosted_parent
	_hosted = null
	_hosted_parent = null
	if is_instance_valid(content):
		var focused: Control = get_viewport().gui_get_focus_owner()
		if focused != null and content.is_ancestor_of(focused):
			focused.release_focus()
		content.hide()
		if is_instance_valid(parent):
			content.reparent(parent, false)
		elif content.get_parent() == _mount:
			_mount.remove_child(content)


func _on_panel_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		advance()


func _place() -> void:
	if _panel == null:
		return
	var view: Rect2 = get_viewport_rect()
	var width: float = clampf(view.size.x * WIDTH_SHARE, minf(MIN_WIDTH, view.size.x - 16.0), MAX_WIDTH)
	_panel.custom_minimum_size = Vector2(width, 0.0)
	_panel.reset_size()
	_panel.size.x = width
	var height: float = _panel.get_combined_minimum_size().y
	_panel.position = Vector2((view.size.x - width) / 2.0, view.size.y - height - BOTTOM_MARGIN)
	# The busts at whole multiples of their pixels, standing on the box's top edge.
	var scale: float = get_viewport().get_final_transform().get_scale().x if is_inside_tree() else 1.0
	var bust_size: Vector2 = PersonPortraits.fitted(PersonPortraits.BUST_SIZE, Vector2(PersonPortraits.BUST_SIZE) * maxf(1.0, roundf(scale)), scale)
	for bust: TextureRect in [_player_bust, _npc_bust]:
		bust.visible = _panel.visible and bust.texture != null
		bust.size = bust_size
		var left: bool = bust == _player_bust
		var x: float = _panel.position.x + BUST_INSET if left else _panel.position.x + width - BUST_INSET - bust_size.x
		bust.position = Vector2(x, _panel.position.y - bust_size.y + BUST_SINK).round()
	_plate.visible = _panel.visible and _name.visible and not _name.text.is_empty()
	if _plate.visible:
		_plate.reset_size()
		var inset: float = PLATE_INSET
		if _npc_bust.visible:
			# Beside the speaker's bust, at the box's right end.
			inset = width - BUST_INSET - bust_size.x - 8.0 - _plate.size.x
		elif _player_bust.visible:
			inset = BUST_INSET + bust_size.x + 8.0
		_plate.position = (_panel.position + Vector2(inset, PLATE_OVERLAP - _plate.size.y)).round()
	if _ui != null:
		# The toasts (bottom left) stand on the box, and on the player's bust when it shows
		# there, so a new message never covers the player's face.
		var standing: float = bust_size.y - BUST_SINK if _player_bust.visible else 0.0
		_ui.toasts_lift(height + BOTTOM_MARGIN + standing if _panel.visible else 0.0)
