class_name DialogueAuto
extends RefCounted

## The 对白自动继续 setting (过场演出 A; DECISIONS「过场读法」): a setting, not the save, as
## AutosaveNotice is. On, a told line (a scene's, a told story's) goes on by itself after its
## reading time (FeelDefinition.dialogue_read_seconds()); off, each waits for E / A / a click.
## The application settings set it once loaded and on 应用.

static var on: bool = true
