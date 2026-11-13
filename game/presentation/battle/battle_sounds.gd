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
## 战斗演出 C (DECISIONS「战斗演出 C」): what a weapon lays over its hit — an edge's slice, a blunt
## weapon's thock (a whip's is the crack) — by battle_stage.json's moves.
const SLICE: StringName = &"slice"
const THOCK: StringName = &"thock"
## Who a sound is for: a blow between two others (their misses only when a voice is free), one
## the player is in, one never cut short (a felling blow's drum, a seal).
const PRIORITY_IDLE: int = 0
const PRIORITY_OTHERS: int = 1
const PRIORITY_MINE: int = 2
const PRIORITY_KEPT: int = 3
## A blow between two others: its miss this much quieter.
const OTHERS_MISS_DB: float = -6.0
const FILES: Dictionary[StringName, String] = {
	CLAPPER: "clapper.wav", WHOOSH: "whoosh.wav", THUD: "thud.wav", CRACK: "crack.wav",
	CLANG: "clang.wav", DRUM: "drum.wav", SEAL: "seal.wav",
	BRICK_WOOD: "brick_wood.wav", BRICK_STONE: "brick_stone.wav", GONG: "gong.wav", SCRAPE: "scrape.wav",
	SLICE: "slice.wav", THOCK: "thock.wav",
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

## The sounds of the fight shown now (the battle panel's); cue() goes through it: the one that
## entered the tree last and is still in it. Continue and Load build the session aside and move
## it into its place (reparent: no second _ready), so it is claimed on entering the tree, and a
## session that leaves gives it back to the one before (a load that failed keeps the old one's).
static var current: BattleSounds
static var _in_tree: Array[BattleSounds] = []

## What played, as [kind, pitch, db] (tests, kits).
var played: Array[Array] = []
var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary[StringName, AudioStream] = {}
## Each voice's priority and when it began (a voice is taken from the least of them).
var _voice_priority: Array[int] = []
var _voice_started: Array[int] = []
var _jitter := RandomNumberGenerator.new()


func _ready() -> void:
	_jitter.randomize()
	for index: int in VOICES:
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % index
		player.bus = &"Master"
		add_child(player)
		_players.append(player)
		_voice_priority.append(PRIORITY_IDLE)
		_voice_started.append(0)


func _enter_tree() -> void:
	_in_tree.erase(self)
	_in_tree.append(self)
	current = self


func _exit_tree() -> void:
	_in_tree.erase(self)
	if current != self:
		return
	current = null
	for index: int in range(_in_tree.size() - 1, -1, -1):
		if is_instance_valid(_in_tree[index]):
			current = _in_tree[index]
			return


## One sound at `pitch` (1: as recorded) and `db` (0: as recorded), the jitter over it. 战斗演出 C:
## a free voice if there is one, else the oldest of the lowest priority below `priority`; a seal
## is never cut short; PRIORITY_IDLE plays only on a free voice. Nothing free: not played.
func play(kind: StringName, pitch: float = 1.0, db: float = 0.0, priority: int = PRIORITY_MINE) -> void:
	if kind == SEAL:
		priority = PRIORITY_KEPT
	var stream: AudioStream = _stream(kind)
	if stream == null or _players.is_empty():
		_record(kind, pitch, db)
		return
	var voice: int = _voice_for(priority)
	if voice < 0:
		return
	_record(kind, pitch, db)
	var player: AudioStreamPlayer = _players[voice]
	_voice_priority[voice] = priority
	_voice_started[voice] = Time.get_ticks_usec()
	player.stop()
	player.stream = stream
	player.pitch_scale = pitch * (1.0 + _jitter.randf_range(-PITCH_JITTER, PITCH_JITTER))
	player.volume_db = db
	player.play()


## Each of `cues` ([kind, pitch, db]) in turn, at `priority` (a felling blow's drum kept, a miss
## between two others idle).
func play_all(cues: Array[Array], priority: int = PRIORITY_MINE) -> void:
	for cue_entry: Array in cues:
		var at: int = priority
		if cue_entry[0] == DRUM and float(cue_entry[2]) >= FATAL_DRUM_DB:
			at = PRIORITY_KEPT
		elif cue_entry[0] == WHOOSH and priority == PRIORITY_OTHERS:
			at = PRIORITY_IDLE
		play(cue_entry[0], cue_entry[1], cue_entry[2], at)


func _record(kind: StringName, pitch: float, db: float) -> void:
	played.append([kind, pitch, db])
	if played.size() > PLAYED_KEPT:
		played.pop_front()


## The voice a sound of `priority` takes: a free one, else the oldest of the lowest priority
## under it — the player's own and a kept sound may also cut the oldest of their own priority
## (a newer blow of theirs over an older one); a kept sound is cut only by another; -1 when none
## may be taken.
func _voice_for(priority: int) -> int:
	for index: int in _players.size():
		if not _players[index].playing:
			return index
	if priority <= PRIORITY_IDLE:
		return -1
	var best: int = -1
	for index: int in _players.size():
		var below: bool = _voice_priority[index] < priority
		var same: bool = _voice_priority[index] == priority and priority >= PRIORITY_MINE
		if not below and not same:
			continue
		if best < 0 or _voice_priority[index] < _voice_priority[best] or (_voice_priority[index] == _voice_priority[best] and _voice_started[index] < _voice_started[best]):
			best = index
	return best


## The priority of `line`'s sounds: a felling blow kept, the player's own fight theirs, else
## others'.
static func priority_of(line: BattleNarrationLine, fatal: bool, player_id: StringName) -> int:
	if fatal:
		return PRIORITY_KEPT
	return PRIORITY_MINE if mine(line, player_id) else PRIORITY_OTHERS


## Whether `line` is the player's own blow or one at them (no player id: as if it were).
static func mine(line: BattleNarrationLine, player_id: StringName) -> bool:
	return player_id.is_empty() or line.actor_id == player_id or line.target_id == player_id


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
## 战斗演出 C: `mine_too` false (a blow between two others): its hit the thud alone (the drum
## only when it fells), its miss quieter, no weapon's layer. The player's own: the weapon's layer
## (battle_stage.json moves) over a hit and, quieter, over a parry; a whip's or a thrown
## weapon's miss at its own pitch.
static func for_line(line: BattleNarrationLine, fatal: bool, first_earned: bool, mine_too: bool = true) -> Array[Array]:
	var cues: Array[Array] = []
	if line.cue == BattleNarrationLine.CUE_EARNED:
		cues.append([CLAPPER, EARNED_PITCH, EARNED_FIRST_DB if first_earned else EARNED_AGAIN_DB])
		return cues
	if not line.has_blow:
		return cues
	var arms: Dictionary = weapon_look(line.weapon_skill)
	match line.outcome:
		CombatAttackResult.Outcome.DODGE:
			var pitch: float = float(arms["miss_pitch"]) if arms.has("miss_pitch") and mine_too else whoosh_pitch(line.tag)
			cues.append([WHOOSH, pitch, 0.0 if mine_too else OTHERS_MISS_DB])
		CombatAttackResult.Outcome.PARRY:
			cues.append([CLANG, 1.0, 0.0])
			var parry_layer: Array = layer_of(line)
			if mine_too and not parry_layer.is_empty():
				cues.append([parry_layer[0], parry_layer[1], float(BattleArena.data().get("moves", {}).get("parry_layer_db", -8.0))])
		CombatAttackResult.Outcome.HIT:
			var heavy: bool = line.tag == CombatMoveTags.HEAVY or line.in_special or fatal
			if not mine_too:
				cues.append([THUD, 1.0, PLAIN_HIT_DB])
				if fatal:
					cues.append([DRUM, 1.0, FATAL_DRUM_DB])
				return cues
			var layer: Array = layer_of(line)
			if not layer.is_empty():
				cues.append(layer)
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


## 战斗演出 C: battle_stage.json's look for the weapon's skill (bare-handed: "").
static func weapon_look(skill: StringName) -> Dictionary:
	var weapons: Dictionary = BattleArena.data().get("moves", {}).get("weapons", {})
	return weapons.get(String(skill), weapons.get("", {}))


## The layer the blow's weapon lays over its hit, [kind, pitch, db] (a bare-handed 抓伤: the
## claw's), [] for none.
static func layer_of(line: BattleNarrationLine) -> Array:
	var moves: Dictionary = BattleArena.data().get("moves", {})
	var look: Dictionary = weapon_look(line.weapon_skill)
	if line.weapon_skill.is_empty() and line.damage_type == "抓伤":
		look = moves.get("claw", {})
	var kind: String = String(look.get("layer", ""))
	if kind.is_empty():
		return []
	return [StringName(kind), float(look.get("pitch", 1.0)), float(look.get("db", -4.0))]
