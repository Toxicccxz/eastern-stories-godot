class_name BuildIdentity
extends RefCounted

## What is running: the version tools/build/build.py writes into the staged project's
## application/config/version (the short commit, with the tag when there is one), or "dev"
## for a development run, which has none. Shown small on the main menu and on 系统, written
## into every save (metadata.build_commit) and logged once at start with the renderer.

const VERSION_SETTING: String = "application/config/version"
## A development run's version.
const DEVELOPMENT: String = "dev"


static func version() -> String:
	var value: String = str(ProjectSettings.get_setting(VERSION_SETTING, "")).strip_edges()
	return DEVELOPMENT if value.is_empty() else value


## What a save records as the build that wrote it.
static func save_tag() -> GameSaveValueTypes.OptionalText:
	return GameSaveValueTypes.OptionalText.some(version())


## The version as the player sees it, small, under the menu.
static func shown() -> String:
	# TRANSLATORS: the game's build, small on the main menu and on 系统; %s is e.g. "dev" or "1a2b3c4d".
	return TranslationServer.translate("版本 %s") % version()


## The one start-up line of the log: the version, the engine and the renderer in use.
static func log_line() -> String:
	return "Eastern Stories %s · Godot %s · %s driver, %s method, %s (%s)" % [
		version(), Engine.get_version_info().get("string", "?"),
		RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_current_rendering_method(),
		RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_api_version(),
	]
