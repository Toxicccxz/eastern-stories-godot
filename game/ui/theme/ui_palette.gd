class_name UiPalette
extends RefCounted

## The interface's colours (界面重做, DECISIONS「界面样式」): the voxel world's own materials —
## ink, ebony, wood, lacquer, gold, lantern light, bone paper — so a window reads as a thing
## made of what the maps are made of. Every UI colour comes from here.

const INK := Color("1d1612")
const EBONY := Color("2e2119")
const EBONY_SIDE := Color("1a120d")
const WOOD := Color("8a5a35")
const WOOD_SIDE := Color("5a3820")
const PLANK := Color("a06a3e")
const STONE := Color("6f7a80")
const STONE_SIDE := Color("454d52")
const LACQUER := Color("a3301f")
const LACQUER_SIDE := Color("6b1c12")
const DANGER := Color("4a1712")
const DANGER_SIDE := Color("2a0b08")
const GOLD := Color("e9b84c")
const LANTERN := Color("ffcf6a")
const BONE := Color("f1e4c6")
const MUTED := Color("b8a689")
const DIM := Color("7c6b58")
const WARNING := Color("ff9f86")
## The voxel letters' side (the pixel face's two darker layers).
const SIDE_LIGHT := Color("6b3a22")
const SIDE_DARK := Color("2a160d")
## Full-screen dims behind a dialog: warm ink, not blue-black.
const SCRIM := Color(0.06, 0.04, 0.03, 0.9)
const SCRIM_LIGHT := Color(0.06, 0.04, 0.03, 0.72)
