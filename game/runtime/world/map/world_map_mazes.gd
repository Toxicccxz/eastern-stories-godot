class_name WorldMapMazes
extends RefCounted
## Rooms whose ways all lead back into them, and the note that names the way out
## (WorldLandmarkDefinition policy note_maze, d/choyin/taolin.c): which note each shows and
## how a way taken counts. The note is the room's (msg_no, drawn by create() and anew after
## each go): not saved, as room counters are not; it is drawn when first read or walked by,
## so a map that is only made draws nothing. The steps are the character's (set("taolin_steps"),
## CharacterState.counters: saved).

var _map: WorldMapController
## The note each note_maze shows now, by landmark: an index into its notes.
var _shown: Dictionary[StringName, int] = {}


func _init(controller: WorldMapController) -> void:
	_map = controller


## The note_maze landmark of `zone_id` on this map, or null.
func maze_in(zone_id: StringName) -> WorldLandmarkDefinition:
	for landmark: WorldLandmarkDefinition in GameContent.catalog().landmarks_for_map(_map.map_id()):
		if landmark.policy == &"note_maze" and landmark.zone_id == zone_id:
			return landmark
	return null


## The note `maze` shows: msg_no = random(sizeof(Note_Msg)) the first time it is needed.
func note(maze: WorldLandmarkDefinition) -> WorldLandmarkDefinition.MazeNote:
	var notes: Array[WorldLandmarkDefinition.MazeNote] = maze.notes
	if not _shown.has(maze.landmark_id):
		_redraw(maze)
	return notes[_shown[maze.landmark_id]]


func _redraw(maze: WorldLandmarkDefinition) -> void:
	var drawn: int = _map.world_interaction_random_source().legacy_random(maze.notes.size())
	_shown[maze.landmark_id] = clampi(drawn, 0, maze.notes.size() - 1)


## entrance.c valid_leave() going east: the player's counter is set to the maze's steps.
func entering(portal: PortalDefinition, state: CharacterState) -> void:
	for landmark: WorldLandmarkDefinition in GameContent.catalog().landmarks_for_map(portal.destination_map_id):
		if landmark.policy == &"note_maze" and landmark.enter_portal_id == portal.portal_id:
			state.counters[landmark.counter] = landmark.setting("steps")


## taolin.c do_go(dir) for a way `portal` out of a maze's zone: the way the note names counts
## a step nearer, any other further, and the note is drawn anew. Returns the portal the player
## then goes through: the way itself, or the maze's own out portal when it leads out (the
## counter deleted, the mark given, `out` told first). null when the zone is no maze.
func take_way(portal: PortalDefinition, state: CharacterState) -> PortalDefinition:
	var maze: WorldLandmarkDefinition = maze_in(portal.source_zone_id)
	if maze == null or portal.portal_id == maze.portal_id:
		return null
	var right: bool = StringName(portal.legacy_command) == note(maze).way
	var steps: int = state.counters.get(maze.counter, 0)
	_redraw(maze)
	if maze.leads_out(steps, right):
		state.counters.erase(maze.counter)
		state.marks[maze.mark] = 1
		if _map.hud() != null:
			_map.hud().append_log_lines([TranslationServer.translate(maze.message("out"))])
		return GameContent.catalog().portal(maze.portal_id)
	state.counters[maze.counter] = maze.steps_after(steps, right)
	return portal
