class_name LoadingScreenDefinition
extends RefCounted

## What covers the view while a map's voxel world is built (data/common/loading_screen.json;
## DECISIONS「加载画面」). New art is a file and these numbers: `sheet` holds the animation's
## frames row by row, `backdrop` is an optional full-screen picture under it; a still picture
## is a sheet of one frame. WorldLoadingScreen shows it.

## The screen's colour under everything (RRGGBB).
var background: String = "000000"
## Full-screen picture, cut to fill ("": the colour alone).
var backdrop: String = ""
## The frames' picture ("": no animation).
var sheet: String = ""
var columns: int = 1
var rows: int = 1
## How many of the sheet's cells are frames, left to right, then down.
var frames: int = 1
var fps: int = 12
## The side the animation shows at, in UI pixels.
var side_px: int = 96
## Where its middle stands, in percent of the screen's width and height.
var center_percent: Array[int] = [50, 50]
## The screen says 载入中 under it.
var caption: bool = false


static func from_record(reader: ContentRecordReader) -> LoadingScreenDefinition:
	var definition := LoadingScreenDefinition.new()
	definition.background = reader.text("background", definition.background)
	definition.backdrop = reader.text("backdrop")
	definition.sheet = reader.text("sheet")
	definition.columns = reader.integer("columns", definition.columns)
	definition.rows = reader.integer("rows", definition.rows)
	definition.frames = reader.integer("frames", definition.frames)
	definition.fps = reader.integer("fps", definition.fps)
	definition.side_px = reader.integer("side_px", definition.side_px)
	if reader.has("center_percent"):
		definition.center_percent = reader.integer_list("center_percent")
	definition.caption = reader.boolean("caption", definition.caption)
	if not Color.html_is_valid(definition.background):
		reader.fail("background", "expected RRGGBB")
	if definition.columns < 1 or definition.rows < 1:
		reader.fail("columns", "the sheet needs at least one column and one row")
	if definition.frames < 1 or definition.frames > definition.columns * definition.rows:
		reader.fail("frames", "must fit the sheet's cells")
	if definition.fps < 1:
		reader.fail("fps", "must be positive")
	if definition.side_px < 1:
		reader.fail("side_px", "must be positive")
	if definition.center_percent.size() != 2:
		reader.fail("center_percent", "expected [x, y]")
	reader.finish()
	return definition
