class_name VoxelRenderQuality
extends RefCounted

## How much work the voxel view asks of the GPU, one profile per platform class in
## data/common/voxel_render.json: phones draw fewer pixels, shadows and grass blades than
## desktops. Presentation only; no rule, position, save or RNG reads it.
const PATH: String = "res://data/common/voxel_render.json"
## A profile name tests (or a probe) choose; empty picks by platform.
static var forced: String = ""
static var _profiles: Dictionary = {}
var name: String = "desktop"
var msaa: Viewport.MSAA = Viewport.MSAA_4X
## The 3D view's resolution against the screen's; the UI keeps the full resolution.
var scale_3d: float = 1.0
var upscale: Viewport.Scaling3DMode = Viewport.SCALING_3D_MODE_BILINEAR
## The sun's shadow cascades (1, 2 or 4) and how far from the camera they reach.
var sun_shadow_splits: int = 4
var sun_shadow_distance: float = 80.0
## Lamps that cast shadows: -1 every lamp; otherwise at most this many, the nearest to
## the player within `lamp_shadow_reach` (world units).
var lamp_shadow_limit: int = -1
var lamp_shadow_reach: float = 0.0
## Outdoor lamps that light at all: -1 every lamp; otherwise the N nearest the player.
var lamp_light_limit: int = -1
## Plain colours share batches (a colour per instance) and shadow casters share shadow-only
## batches whatever their colour: far fewer draws for the same picture.
var merged_batches: bool = false
## The share of meadow tufts drawn (1 every tuft).
var foliage_density: float = 1.0

static func current() -> VoxelRenderQuality:
	if forced != "":
		return named(forced)
	return named("mobile" if OS.has_feature("android") or OS.has_feature("ios") else "desktop")

static func named(profile: String) -> VoxelRenderQuality:
	if _profiles.is_empty():
		_profiles = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	var settings: Dictionary = _profiles[profile]
	var quality := VoxelRenderQuality.new()
	quality.name = profile
	quality.msaa = {0:Viewport.MSAA_DISABLED,2:Viewport.MSAA_2X,4:Viewport.MSAA_4X,8:Viewport.MSAA_8X}[int(settings["msaa"])]
	quality.scale_3d = float(settings["scale_3d"])
	quality.upscale = {"bilinear":Viewport.SCALING_3D_MODE_BILINEAR,"fsr":Viewport.SCALING_3D_MODE_FSR,"fsr2":Viewport.SCALING_3D_MODE_FSR2}[String(settings["upscale"])]
	quality.sun_shadow_splits = int(settings["sun_shadow_splits"])
	quality.sun_shadow_distance = float(settings["sun_shadow_distance"])
	quality.lamp_shadow_limit = int(settings["lamp_shadow_limit"])
	quality.lamp_shadow_reach = float(settings["lamp_shadow_reach"])
	quality.lamp_light_limit = int(settings["lamp_light_limit"])
	quality.merged_batches = bool(settings["merged_batches"])
	quality.foliage_density = float(settings["foliage_density"])
	return quality

func sun_shadow_mode() -> DirectionalLight3D.ShadowMode:
	match sun_shadow_splits:
		1:
			return DirectionalLight3D.SHADOW_ORTHOGONAL
		2:
			return DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	return DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
