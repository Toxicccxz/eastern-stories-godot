class_name LoadingScreenDefinition
extends RefCounted

## What covers the view while a map's voxel world is built (data/common/loading_screen.json;
## DECISIONS「加载画面」). New art is a file and these numbers: `sheet` holds the animation's
## frames row by row, `backdrop` is an optional full-screen picture under it; a still picture
## is a sheet of one frame. WorldLoadingScreen shows it. With `voxel` cubes it shows those
## instead (VoxelLoader: they drop in one by one and build a little shape, then rise away), and
## so do the shell's waits (存档, 回到主菜单, 检查存档) and the title's white while a journey
## starts.

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
## The voxel animation: each cube's place on the grid (x, y, z up) in the order it drops in,
## its colour, a cube's half width in UI pixels and the length of one round.
var voxel_cubes: Array[Vector3i] = []
var voxel_colours: Array[Color] = []
var voxel_cube_px: int = 10
var voxel_cycle_ms: int = 2400


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
	var voxel: ContentRecordReader = reader.child("voxel")
	if voxel != null:
		definition.voxel_cube_px = voxel.integer("cube_px", definition.voxel_cube_px)
		definition.voxel_cycle_ms = voxel.integer("cycle_ms", definition.voxel_cycle_ms)
		var colours: Dictionary[String, String] = voxel.text_map("colours")
		for cube: ContentRecordReader in voxel.children("cubes"):
			var at: Array[int] = cube.integer_list("at")
			var colour: String = cube.text("colour")
			if at.size() != 3:
				cube.fail("at", "expected [x, y, z]")
			elif not colours.has(colour) or not Color.html_is_valid(colours[colour]):
				cube.fail("colour", "names no colour of `colours`")
			else:
				definition.voxel_cubes.append(Vector3i(at[0], at[1], at[2]))
				definition.voxel_colours.append(Color(colours[colour]))
			cube.finish()
		if definition.voxel_cube_px < 2:
			voxel.fail("cube_px", "must be at least 2")
		if definition.voxel_cycle_ms < 500:
			voxel.fail("cycle_ms", "must be at least 500")
		if definition.voxel_cubes.is_empty():
			voxel.fail("cubes", "needs at least one cube")
		voxel.finish()
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
