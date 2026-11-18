extends SceneTree
## Bakes the title logo's ink masks (界面重做, DECISIONS「标题画面」): the four brush characters
## 东方故事 in 马善政楷书 and the English title in capitals in 霞鹜文楷 (both made bolder), and the
## seal's 侠 in 霞鹜文楷, rasterised at the
## voxel size TitleLogo builds them at and cropped to the ink. The game reads only these
## masks, so the brush font itself is not needed to run it.
## Windowed (it renders text):
##   <godot> --path game --script <abs>/tools/ui/bake_title_logo.gd -- <MaShanZheng-Regular.ttf>
## Writes game/assets/textures/title/logo_zh_CN.png, logo_en.png, seal_zh_CN.png.

const OUT: String = "res://assets/textures/title/"
## Glyph sizes in voxels (one font pixel = one voxel).
const ZH_SIZE: int = 90
const EN_SIZE: int = 72
const SEAL_SIZE: int = 30
## How many pixels the strokes are made bolder by all round (an outline in the ink's colour), so
## they carry the statue's big blocks.
const ZH_BOLD: int = 6
const EN_BOLD: int = 6
const SEAL_FONT: String = "res://assets/fonts/LXGWWenKaiLite-Medium.ttf"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: -- <MaShanZheng-Regular.ttf>")
		quit(1)
		return
	var brush := FontFile.new()
	if brush.load_dynamic_font(args[0]) != OK:
		printerr("cannot load ", args[0])
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var seal: FontFile = load(SEAL_FONT) as FontFile
	for job: Array in [["logo_zh_CN", "东方故事", brush, ZH_SIZE, ZH_BOLD], ["logo_en", "EASTERN STORIES", seal, EN_SIZE, EN_BOLD], ["seal_zh_CN", "侠", seal, SEAL_SIZE, 0]]:
		var mask: Image = await _mask(job[1], job[2], job[3], job[4])
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
