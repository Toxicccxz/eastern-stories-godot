class_name TitleSand
extends Control

## The 沙盘 behind the title (DECISIONS「标题画面」): the 地图 page's own baked pictures — land,
## roads, mist, every place's miniature, drifting cloud shadows — under a camera that breathes
## slowly round `centre` and flies when TitleScreen tweens `centre` and `zoom`. A glowing
## marker sits on the place the camera settled on.

## Where the focused place stands on screen, in parts of it (right of the menu).
const FOCUS := Vector2(0.68, 0.6)

## The point of the stage the camera looks at, and its scale.
var centre: Vector2 = Vector2.ZERO
var zoom: float = 0.58
## 1: the camera drifts round centre; 0: it holds still (diving at a place).
var drift_on: float = 1.0
var clock: float = 0.0

var _pictures: AtlasPictures
var _stage: Node2D
var _clouds: Sprite2D
var marker: Sprite2D


func _init() -> void:
	name = "TitleSand"
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var ground := ColorRect.new()
	ground.name = "Ground"
	ground.color = Color("6c8294")
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ground)
	_stage = Node2D.new()
	_stage.name = "Stage"
	_stage.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_stage)
	_pictures = AtlasPictures.read()
	if _pictures != null:
		_dress()
	marker = Sprite2D.new()
	marker.name = "Marker"
	marker.texture = _soft_dot(48, Color(1.0, 0.86, 0.55))
	marker.modulate.a = 0.0
	add_child(marker)
	centre = stage_size() / 2.0


func _dress() -> void:
	var whole: Vector2 = _pictures.stage_size()
	_layer("land").scale = whole / _layer_size("land")
	var roads := Node2D.new()
	roads.name = "Roads"
	_stage.add_child(roads)
	for road: AtlasPictures.Road in _pictures.roads:
		var sprite := Sprite2D.new()
		sprite.texture = _pictures.layer(road.file)
		sprite.centered = false
		sprite.position = road.at
		roads.add_child(sprite)
	var mist: Sprite2D = _layer("mist")
	mist.scale = whole / _layer_size("mist")
	mist.modulate.a = 0.3
	var cells: Array[AtlasCell] = GameContent.catalog().atlas().cells()
	cells.sort_custom(func(a: AtlasCell, b: AtlasCell) -> bool: return a.at.x + a.at.y < b.at.x + b.at.y)
	for cell: AtlasCell in cells:
		if _pictures.has_picture(cell.map_id):
			var mini := Sprite2D.new()
			mini.texture = _pictures.texture(cell.map_id)
			mini.centered = false
			mini.position = _pictures.corner(cell.map_id, cell.at)
			mini.modulate = Color(1.18, 1.14, 1.08)
			_stage.add_child(mini)
	_clouds = _layer("clouds")
	_clouds.scale = whole / _layer_size("clouds")
	_clouds.modulate = Color(1.3, 1.22, 1.14, 0.3)


func _layer(file: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = file.capitalize()
	sprite.texture = _pictures.layer(file)
	sprite.centered = false
	_stage.add_child(sprite)
	return sprite


func _layer_size(file: String) -> Vector2:
	var texture: Texture2D = _pictures.layer(file)
	return Vector2.ONE if texture == null else texture.get_size().max(Vector2.ONE)


func stage_size() -> Vector2:
	return Vector2(1024, 1024) if _pictures == null else _pictures.stage_size()


## The stage point of `map_id`'s place: its miniature's middle, or its cell; a map that is no
## place goes to the place it belongs to. The stage's middle when it has none.
func place_of(map_id: StringName) -> Vector2:
	var catalog: ContentCatalog = GameContent.catalog()
	var atlas: AtlasTable = catalog.atlas()
	var cell: AtlasCell = atlas.cell(map_id)
	if cell == null and map_id != &"":
		cell = atlas.cell(atlas.home_of(catalog, map_id))
	if cell == null or _pictures == null:
		return stage_size() / 2.0
	if _pictures.has_picture(cell.map_id):
		return _pictures.corner(cell.map_id, cell.at) + _pictures.texture(cell.map_id).get_size() / 2.0
	return _pictures.to_stage(cell.at)


## The place's display name ("" when it has none).
static func place_name(map_id: StringName) -> String:
	var catalog: ContentCatalog = GameContent.catalog()
	var atlas: AtlasTable = catalog.atlas()
	var cell: AtlasCell = atlas.cell(map_id)
	if cell == null and map_id != &"":
		cell = atlas.cell(atlas.home_of(catalog, map_id))
	return "" if cell == null else cell.name


## Where the camera's centre shows on screen.
func centre_on_screen() -> Vector2:
	return _stage.position + centre * zoom


func _process(delta: float) -> void:
	clock += delta
	var view: Vector2 = size
	var drift := Vector2(sin(clock * 0.21) * 26.0, cos(clock * 0.17) * 16.0) * drift_on
	var focus_at: Vector2 = view * FOCUS
	var whole: Vector2 = stage_size()
	var look: Vector2 = centre + drift
	var low: Vector2 = focus_at / zoom
	var high: Vector2 = whole - (view - focus_at) / zoom
	look = Vector2(clampf(look.x, low.x, maxf(low.x, high.x)), clampf(look.y, low.y, maxf(low.y, high.y)))
	_stage.scale = Vector2(zoom, zoom)
	_stage.position = focus_at - look * zoom
	if _clouds != null:
		_clouds.position.x = sin(clock / 40.0 * TAU) * 220.0
	marker.position = centre_on_screen()
	marker.scale = Vector2.ONE * (1.0 + sin(clock * 3.0) * 0.12)


static func _soft_dot(side: int, colour: Color) -> ImageTexture:
	var image := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	for y: int in side:
		for x: int in side:
			var r: float = Vector2(x + 0.5 - side / 2.0, y + 0.5 - side / 2.0).length() / (side / 2.0)
			image.set_pixel(x, y, Color(colour, clampf(1.0 - r, 0.0, 1.0) ** 1.6))
	return ImageTexture.create_from_image(image)
