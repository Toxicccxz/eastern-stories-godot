class_name BattleModeLook
extends RefCounted

## 战斗演出 A (DECISIONS「战斗演出 A」): how a fight's mode looks — the word at the top of the
## screen, the line under it, the shade over the scene and the accent colour (the title's and
## the rule's under it). A 切磋 reads light and friendly, a 死斗 dark and blood-red, a guide's
## 拆招 as a 切磋 with gold. Presentation only: the mode is the encounter's.

# TRANSLATORS: the word at the top of the battle screen in a 切磋 (a friendly bout that stops short of harm).
const TITLE_SPAR: String = "切磋"
# TRANSLATORS: the word at the top of the battle screen in a fight to the death.
const TITLE_LETHAL: String = "死斗"
# TRANSLATORS: the word at the top of the battle screen while a guide's three harmless rounds run.
const TITLE_LESSON: String = "拆招"
# TRANSLATORS: the word at the top of the battle screen in a story fight.
const TITLE_SCRIPTED: String = "交手"
# TRANSLATORS: the line under 切磋 at the top of the battle screen.
const MOTTO_SPAR: String = "点到为止"
# TRANSLATORS: the line under 死斗 at the top of the battle screen.
const MOTTO_LETHAL: String = "生死各安天命"
# TRANSLATORS: the line under 拆招 at the top of the battle screen (the lesson ends after three rounds).
const MOTTO_LESSON: String = "三合为限"

var title: String = ""
var motto: String = ""
var scrim: Color = UiPalette.SCRIM_LETHAL
var title_color: Color = UiPalette.LACQUER
var accent: Color = UiPalette.LACQUER
## Whether the title carries the dark outline (the 死斗's, as the 胜 / 败 stamp).
var outlined: bool = true


## The look of `mode` (CombatEncounterMode.Value); untranslated words.
static func of(mode: int) -> BattleModeLook:
	var look := BattleModeLook.new()
	match mode:
		CombatEncounterMode.Value.SPAR, CombatEncounterMode.Value.LESSON:
			var lesson: bool = mode == CombatEncounterMode.Value.LESSON
			look.title = TITLE_LESSON if lesson else TITLE_SPAR
			look.motto = MOTTO_LESSON if lesson else MOTTO_SPAR
			look.scrim = UiPalette.SCRIM_SPAR
			look.title_color = UiPalette.BONE
			look.accent = UiPalette.GOLD if lesson else UiPalette.PATINA
			look.outlined = false
		CombatEncounterMode.Value.SCRIPTED:
			look.title = TITLE_SCRIPTED
		_:
			look.title = TITLE_LETHAL
			look.motto = MOTTO_LETHAL
	return look


## Whether `mode` shows as a friendly bout (the lighter look).
static func friendly(mode: int) -> bool:
	return mode in [CombatEncounterMode.Value.SPAR, CombatEncounterMode.Value.LESSON]
