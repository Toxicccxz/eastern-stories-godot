class_name AutosaveNotice
extends RefCounted

## The 自动存档提示 setting (现代基线 A; DECISIONS「自动存档」): a setting, not the save, as
## ObjectiveHints is. Off, the 已自动存档 line does not show; the autosave goes on, and a
## failed one is told either way. The application settings set it once loaded and on 应用.

static var shown: bool = true
