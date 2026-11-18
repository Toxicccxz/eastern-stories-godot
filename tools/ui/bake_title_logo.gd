extends SceneTree
## Bakes the title logo's ink masks (DECISIONS「标题画面」): 东方故事 and Eastern Stories in
## 志莽行书 (a free running hand), every character (or word) at its own size, made bolder and
## set side by side on one foot line; and the seal's 侠 in 霞鹜文楷. TitleMonument cuts them into
## voxels (CELL pixels each); the game reads only these masks.
## Windowed (it renders text):
##   <godot> --path game --script <abs>/tools/ui/bake_title_logo.gd
## Writes game/assets/textures/title/logo_zh_CN.png, logo_en.png, seal_zh_CN.png.

const OUT: String = "res://assets/textures/title/"
const BRUSH: String = "res://assets/fonts/ZhiMangXing-Regular.ttf"
const SEAL_FONT: String = "res://assets/fonts/LXGWWenKaiLite-Medium.ttf"
## Each title as [text, size in pixels] pieces, set left to right: no two the same size.
const ZH: Array = [["东", 196], ["方", 150], ["故", 172], ["事", 216]]
const EN: Array = [["Eastern", 132], ["Stories", 156]]
const SEAL_SIZE: int = 30
## How many pixels the strokes are made bolder by all round (an outline in the ink's colour), so
## the brush's thin strokes still carry blocks.
const BOLD: int = 6
## Pixels between two pieces (more than TitleMonument's gap between characters).
const GAP: int = 24


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var brush: FontFile = load(BRUSH) as FontFile
	var plain: FontFile = load(SEAL_FONT) as FontFile
	for job: Array in [["logo_zh_CN", ZH], ["logo_en", EN]]:
		var pieces: Array[Image] = []
		for piece: Array in job[1]:
			pieces.append(await _mask(piece[0], brush, piece[1], BOLD))
		_save(_side_by_side(pieces), job[0])
	_save(await _mask("侠", plain, SEAL_SIZE, 0), "seal_zh_CN")
	quit(0)


func _save(mask: Image, file: String) -> void:
	var path: String = ProjectSettings.globalize_path(OUT + file + ".png")
	mask.save_png(path)
	print("BAKED %s %dx%d" % [path, mask.get_width(), mask.get_height()])


## The pieces left to right, GAP apart, their feet on one line.
static func _side_by_side(pieces: Array[Image]) -> Image:
	var width: int = GAP * (pieces.size() - 1)
	var height: int = 0
	for piece: Image in pieces:
		width += piece.get_width()
		height = maxi(height, piece.get_height())
	var out := Image.create_empty(width, height, false, Image.FORMAT_L8)
	out.fill(Color.BLACK)
	var x: int = 0
	for piece: Image in pieces:
		out.blit_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()), Vector2i(x, height - piece.get_height()))
		x += piece.get_width() + GAP
	return out


## The text in white on clear, cropped to its ink, as an 8-bit grey mask (ink = 255).
func _mask(text: String, font: Font, size: int, bold: int) -> Image:
	var paper := SubViewport.new()
	paper.transparent_bg = true
	paper.size = Vector2i(size * text.length() + size, int(size * 2.2))
	paper.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(paper)
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color.WHITE)
	if bold > 0:
		label.add_theme_color_override("font_outline_color", Color.WHITE)
		label.add_theme_constant_override("outline_size", bold * 2)
	label.position = Vector2(size * 0.3, size * 0.4)
	paper.add_child(label)
	for i: int in 4:
		await process_frame
	var image: Image = paper.get_texture().get_image()
	paper.queue_free()
	image = image.get_region(image.get_used_rect())
	var grey := Image.create_empty(image.get_width(), image.get_height(), false, Image.FORMAT_L8)
	for y: int in image.get_height():
		for x: int in image.get_width():
			grey.set_pixel(x, y, Color.WHITE if image.get_pixel(x, y).a > 0.5 else Color.BLACK)
	return grey
