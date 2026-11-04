class_name UiPalette
extends RefCounted

## The interface's colours (界面重做, DECISIONS「界面样式」): the voxel world's own materials —
## ink, ebony, wood, iron, bronze, lacquer, gold, lantern light, bone paper — so a window reads
## as a thing made of what the maps are made of, and as old as they are (像素界面: rust,
## verdigris, worn-through lacquer). Every UI colour comes from here.

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
## A button's iron plate and its shadowed edge; rust on it.
const IRON := Color("5b605f")
const IRON_SIDE := Color("2b2e2f")
const RUST := Color("8f4a22")
## A secondary button's bronze and the verdigris on it.
const BRONZE := Color("7a6034")
const BRONZE_SIDE := Color("3d2d16")
const PATINA := Color("4f8f78")
## A speech bubble's paper and its darker edge; a key's bone tile.
const PAPER := Color("f1e6c8")
const PAPER_SIDE := Color("a38a5e")
const BONE_TILE := Color("d8cdb6")
const BONE_TILE_SIDE := Color("8f8574")
## Every sheet's outline.
const OUTLINE := Color("110b08")
## The focus rim and cursor.
const FOCUS := LANTERN
## A recess cut into the wood (a text field, a scroll track).
const WELL := Color("251b15")
## A name on a plate.
const LIGHT_TEXT := Color("fff3dc")
## The title's voxel letters: the face over two darker side layers.
const LETTER := Color("f1e4c6")
const SIDE_LIGHT := Color("6b3a22")
const SIDE_DARK := Color("2a160d")
## Full-screen dims behind a dialog: warm ink, not blue-black.
const SCRIM := Color(0.06, 0.04, 0.03, 0.9)
const SCRIM_LIGHT := Color(0.06, 0.04, 0.03, 0.72)
