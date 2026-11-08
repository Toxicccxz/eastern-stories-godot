class_name BattleSounds
extends Node

## 战斗拍数 C (DECISIONS「战斗拍数 C」): the fight's sounds, the project's first audio — seven
## project-made files under assets/audio/battle/ (tools/audio/synth_battle_sounds.py writes
## them; LICENSE_PROVENANCE「Audio」): the 拍板 clap of a beat landing and of a move pressed
## (the game's signature, an octave up for a beat won), the whoosh of a miss (higher for a
## 快, lower for a 重), the dull thud of a hit (a bright crack over it when the ring says 克,
## the thud alone and quieter when it says 被克), the clang of a parry, the deep drum under a
## 重 that lands, a special's blow or a felling blow, and the dull stamp of a seal (封成, 忙,
## 胜 / 败, 倒 / 亡). Every sound plays ±5 % off its pitch. Rationed by weight (纪要 §九):
## 普通 < 克制 < 绝招 < 致命; a beat won gets the whole ceremony only the first time in a
## fight. No music. The 总音量 setting is the Master bus (ApplicationSettingsService).
## Presentation only: what to play is read off the told line (for_line()); nothing here
## touches a rule, a number or the fight's random source (the pitch jitter has its own).

const DIRECTORY: String = "res://assets/audio/battle/"
const CLAPPER: StringName = &"clapper"
const WHOOSH: StringName = &"whoosh"
const THUD: StringName = &"thud"
const CRACK: StringName = &"crack"
const CLANG: StringName = &"clang"
const DRUM: StringName = &"drum"
const SEAL: StringName = &"seal"
## 战斗演出 B (DECISIONS「战斗演出 B」): the stage's — a row of 切磋 boards or 死斗 stones set down,
## the 切磋's gong, the 死斗's scrape of steel (BattleArena plays them; battle_stage.json names them).
const BRICK_WOOD: StringName = &"brick_wood"
const BRICK_STONE: StringName = &"brick_stone"
const GONG: StringName = &"gong"
const SCRAPE: StringName = &"scrape"
const FILES: Dictionary[StringName, String] = {
	CLAPPER: "clapper.wav", WHOOSH: "whoosh.wav", THUD: "thud.wav", CRACK: "crack.wav",
	CLANG: "clang.wav", DRUM: "drum.wav", SEAL: "seal.wav",
	BRICK_WOOD: "brick_wood.wav", BRICK_STONE: "brick_stone.wav", GONG: "gong.wav", SCRAPE: "scrape.wav",
}
## How many sounds may overlap.
const VOICES: int = 8
## Every sound plays this far off its pitch, either way.
const PITCH_JITTER: float = 0.05
## A beat won: the clap an octave up.
const EARNED_PITCH: float = 2.0
## The whoosh of a 快 and of a 重.
const WHOOSH_QUICK_PITCH: float = 1.3
const WHOOSH_HEAVY_PITCH: float = 0.75
## The ration, in dB: a plain hit under a 克 hit, a 被克 hit under that; the drum louder on
## a felling blow; the clap of a beat won after the first, quieter.
const PLAIN_HIT_DB: float = -2.0
const COUNTERED_HIT_DB: float = -6.0
const DRUM_DB: float = -2.0
const FATAL_DRUM_DB: float = 2.0
const EARNED_FIRST_DB: float = 2.0
const EARNED_AGAIN_DB: float = -8.0
## The kit's and the suites' record of what played, newest last, this many at most.
const PLAYED_KEPT: int = 64

## The sounds of the fight shown now (the battle panel's); cue() goes through it.
static var current: BattleSounds

## What played, as [kind, pitch, db] (tests, kits).
var played: Array[Array] = []
var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary[StringName, AudioStream] = {}
var _next: int = 0
var _jitter := RandomNumberGenerator.new()


func _ready() -> void:
	_jitter.randomize()
	for index: int in VOICES:
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % index
		player.bus = &"Master"
		add_child(player)
		_players.append(player)
	if current == null or not is_instance_valid(current):
		current = self


func _exit_tree() -> void:
	if current == self:
		current = null


## One sound at `pitch` (1: as recorded) and `db` (0: as recorded), the jitter over it.
func play(kind: StringName, pitch: float = 1.0, db: float = 0.0) -> void:
	played.append([kind, pitch, db])
	if played.size() > PLAYED_KEPT:
		played.pop_front()
	var stream: AudioStream = _stream(kind)
	if stream == null or _players.is_empty():
		return
	var player: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	player.stop()
	player.stream = stream
	player.pitch_scale = pitch * (1.0 + _jitter.randf_range(-PITCH_JITTER, PITCH_JITTER))
	player.volume_db = db
	player.play()


## Each of `cues` ([kind, pitch, db]) in turn.
func play_all(cues: Array[Array]) -> void:
	for cue_entry: Array in cues:
		play(cue_entry[0], cue_entry[1], cue_entry[2])


## A sound through the fight's sounds now, from anywhere (the cards' stamps); nothing
## without a fight shown.
static func cue(kind: StringName, pitch: float = 1.0, db: float = 0.0) -> void:
	if current != null and is_instance_valid(current):
		current.play(kind, pitch, db)


## The sounds a told line asks for, as [kind, pitch, db] each, by the ration: a blow's
## outcome and the ring's verdict on it, the drum under a 重 landing / a special's blow /
## a felling blow (`fatal`), the whoosh of a miss at the tag's pitch, the clang of a parry;
## a beat won (the line's cue) as the clap an octave up, loud the first time (`first_earned`),
## quiet after; nothing for a special's opening line (its blows sound) or plain words.
static func for_line(line: BattleNarrationLine, fatal: bool, first_earned: bool) -> Array[Array]:
	var cues: Array[Array] = []
	if line.cue == BattleNarrationLine.CUE_EARNED:
		cues.append([CLAPPER, EARNED_PITCH, EARNED_FIRST_DB if first_earned else EARNED_AGAIN_DB])
		return cues
	if not line.has_blow:
		return cues
	match line.outcome:
		CombatAttackResult.Outcome.DODGE:
			cues.append([WHOOSH, whoosh_pitch(line.tag), 0.0])
		CombatAttackResult.Outcome.PARRY:
			cues.append([CLANG, 1.0, 0.0])
		CombatAttackResult.Outcome.HIT:
			var heavy: bool = line.tag == CombatMoveTags.HEAVY or line.in_special or fatal
			if line.ring < 0:
				cues.append([THUD, 1.0, COUNTERED_HIT_DB])
			elif line.ring > 0:
				cues.append([THUD, 1.0, 0.0])
				cues.append([CRACK, 1.0, 0.0])
			else:
				cues.append([THUD, 1.0, 0.0 if heavy else PLAIN_HIT_DB])
			if heavy:
				cues.append([DRUM, 1.0, FATAL_DRUM_DB if fatal else DRUM_DB])
	return cues


## The whoosh's pitch for a move's tag: 快 high, 重 low, the rest as recorded.
static func whoosh_pitch(tag: StringName) -> float:
	if tag == CombatMoveTags.QUICK:
		return WHOOSH_QUICK_PITCH
	if tag == CombatMoveTags.HEAVY:
		return WHOOSH_HEAVY_PITCH
	return 1.0


## The kinds of what played (tests).
func played_kinds() -> Array[StringName]:
	var kinds: Array[StringName] = []
	for entry: Array in played:
		kinds.append(entry[0])
	return kinds


func _stream(kind: StringName) -> AudioStream:
	if _streams.has(kind):
		return _streams[kind]
	var path: String = DIRECTORY + String(FILES.get(kind, ""))
	var stream: AudioStream = load(path) as AudioStream if FILES.has(kind) and ResourceLoader.exists(path) else null
	_streams[kind] = stream
	return stream
