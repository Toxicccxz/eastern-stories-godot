extends SceneTree
## Bakes the title logo's ink masks (DECISIONS「标题画面」): 东方故事, the English title in capitals
## (EASTERN STORIES) and the seal's 侠, all in 霞鹜文楷 (the project's own font) and the title made
## bolder, rasterised and cropped to the ink. TitleMonument cuts them into voxels (CELL pixels
## each); the game reads only these masks.
## Windowed (it renders text):
##   <godot> --path game --script <abs>/tools/ui/bake_title_logo.gd
## Writes game/assets/textures/title/logo_zh_CN.png, logo_en.png, seal_zh_CN.png.

const OUT: String = "res://assets/textures/title/"
const FONT: String = "res://assets/fonts/LXGWWenKaiLite-Medium.ttf"
## Glyph sizes in pixels.
const ZH_SIZE: int = 96
const EN_SIZE: int = 72
const SEAL_SIZE: int = 30
## How many pixels the strokes are made bolder by all round (an outline in the ink's colour): the
## characters are cut from rock, thick enough to read from afar.
const ZH_BOLD: int = 2
const EN_BOLD: int = 3


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var font: FontFile = load(FONT) as FontFile
	for job: Array in [["logo_zh_CN", "东方故事", ZH_SIZE, ZH_BOLD], ["logo_en", "EASTERN STORIES", EN_SIZE, EN_BOLD], ["seal_zh_CN", "侠", SEAL_SIZE, 0]]:
		var mask: Image = await _mask(job[1], font, job[2], job[3])
		var path: String = ProjectSettings.globalize_path(OUT + String(job[0]) + ".png")
		mask.save_png(path)
		print("BAKED %s %dx%d" % [path, mask.get_width(), mask.get_height()])
	quit(0)


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
