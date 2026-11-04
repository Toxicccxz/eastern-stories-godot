class_name UiPalette
extends RefCounted

## The interface's colours. 像素界面 (DECISIONS「像素界面」): parchment sheets with a dark
## brown outline and ink-brown text, vermilion lacquer for what matters, a deep red focus.
## The names keep their roles from 界面重做 (EBONY is a window's face, BONE the text on it),
## so every user follows. Every UI colour comes from here.

const INK := Color("1d1612")
## A window's face (parchment) and its outline.
const EBONY := Color("e3d8ae")
const EBONY_SIDE := Color("3f3224")
## A button's face and the shade under it.
const WOOD := Color("ece3c0")
const WOOD_SIDE := Color("b4a474")
## A chosen tab or row.
const PLANK := Color("cdbb8a")
const STONE := Color("cfc7a8")
const STONE_SIDE := Color("8f8668")
const LACQUER := Color("a3301f")
const LACQUER_SIDE := Color("6b1c12")
const DANGER := Color("6e2016")
const DANGER_SIDE := Color("3a0e09")
## Accent text on parchment (titles, a chosen value, 下一步).
const GOLD := Color("8e3b1f")
## Highlighted text on parchment (a story's name, a lit row).
const LANTERN := Color("b0441c")
## Text on parchment, then quieter, then out of reach.
const BONE := Color("43392a")
const MUTED := Color("7b6b4d")
const DIM := Color("a7987a")
const WARNING := Color("b0301c")
## Every sheet's and pill's outline.
const OUTLINE := Color("3f3224")
## The focus rim and cursor.
const FOCUS := Color("b3341c")
## A recess (a text field, a scroll track).
const WELL := Color("d3c596")
## Text on a dark plate (a name plate, a toast's key) and on the world (a bubble).
const LIGHT_TEXT := Color("f6eed3")
## The title's voxel letters: the face over two darker side layers.
const LETTER := Color("f1e4c6")
const SIDE_LIGHT := Color("6b3a22")
const SIDE_DARK := Color("2a160d")
## Full-screen dims behind a dialog: warm ink, not blue-black.
const SCRIM := Color(0.06, 0.04, 0.03, 0.9)
const SCRIM_LIGHT := Color(0.06, 0.04, 0.03, 0.72)
