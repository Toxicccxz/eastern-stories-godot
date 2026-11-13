extends Node

## Dev only: drives the normal game's own main menu to a New Game and, once its session runs, sets
## it up with ChapterStart for `spec` — then frees itself and the game goes on as any other. Put on
## the tree's root (it outlives the scene change to the main scene) by the F6 scene and by
## run_chapter_start.gd. The New Game asks the shell as a player would (新游戏, a name, a gender,
## 开始; over saves, the shell's own 新游戏 confirmation is answered), so a save made later is an
## ordinary one, in the development slot like any dev run.

const Start := preload("res://tests/dev/chapter_start/chapter_start.gd")
const NAMES: Dictionary[StringName, String] = {CharacterState.GENDER_FEMALE: "凌雪", CharacterState.GENDER_MALE: "凌风"}

enum Phase { MENU, SETUP, PLAYING, DONE }

var spec: ChapterStart.Spec = ChapterStart.Spec.new()
var _phase: Phase = Phase.MENU


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	var shell := get_tree().current_scene as ApplicationShellController
	if shell == null or shell.runtime_host() == null or not shell.interaction_allowed():
		return
	var mode: ApplicationShellState.Mode = shell.shell_state().mode()
	match _phase:
		Phase.MENU:
			if mode == ApplicationShellState.Mode.MAIN_MENU and shell.request_new_game_from_menu():
				_phase = Phase.SETUP
		Phase.SETUP:
			if mode == ApplicationShellState.Mode.RESULT:
				shell.confirm_current_result() # 新游戏 over saves: the shell's own question, answered yes.
			elif mode == ApplicationShellState.Mode.NEW_GAME_SETUP:
				# 序章 is the New Game itself, its opening card too; a later chapter opens on its own step.
				shell.runtime_host().opening_card = spec.quest == &"main.prologue"
				shell.player_name_edit.text = NAMES.get(spec.gender, "凌雪")
				shell.select_new_game_gender(spec.gender)
				if shell.submit_new_game_setup():
					_phase = Phase.PLAYING
		Phase.PLAYING:
			var session: WorldSessionController = shell.runtime_host().current_session()
			if mode != ApplicationShellState.Mode.PLAYING or session == null or not session.is_initialized():
				return
			_phase = Phase.DONE
			var problem: String = Start.apply(session, spec)
			var line: String = "（开发：从「%s」开始，实战经验 %d。）" % [spec.describe(), session.player_runtime().state.progression.combat_experience]
			if not problem.is_empty():
				line = "（开发：从「%s」开始没有成功：%s）" % [spec.describe(), problem]
				push_error("chapter start: " + problem)
			print(line)
			session.shared_ui().append_log_lines([line])
			queue_free()


## The command line's words as a spec: `<chapter> [fist] [chase] [pulled] [side=expose|deal|uncle]
## [who=self|uncle|xiao] [explore] [male]` (chapter: prologue, 1 … 10, finale). Null when the chapter is
## unknown or a word is.
static func parse(words: PackedStringArray) -> ChapterStart.Spec:
	if words.is_empty():
		return null
	var out := ChapterStart.Spec.new()
	out.quest = ChapterStart.quest_of(words[0])
	if out.quest.is_empty():
		return null
	for word: String in words.slice(1):
		var value: String = word.get_slice("=", 1)
		match word.get_slice("=", 0):
			"fist": out.sword = false
			"sword": out.sword = true
			"chase": out.chased = true
			"rescue": out.chased = false
			"pulled": out.pulled = true
			"keep": out.pulled = false
			"explore": out.exploring = true
			"male": out.gender = CharacterState.GENDER_MALE
			"female": out.gender = CharacterState.GENDER_FEMALE
			"side" when value in ["expose", "deal", "uncle"]: out.side = value
			"who" when value in ["self", "uncle", "xiao"]: out.who = value
			_: return null
	return out
