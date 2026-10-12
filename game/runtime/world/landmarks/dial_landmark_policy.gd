extends WorldLandmarkPolicy

## jitan.c's button: its turns (do_turn() forward, backward) count, its press (do_press())
## opens the floor when they are right (WorldHiddenPassages). turn button alone and a wrong
## direction only explained the typed command: the buttons name both ways.


func use(map: WorldMapController, landmark: WorldLandmarkDefinition) -> RefCounted:
	if map.session == null or landmark == null or not map.landmark_available(landmark):
		return HiddenPassagePushResult.new()
	return map.session.hidden_passages().press(landmark)


func use_action(map: WorldMapController, landmark: WorldLandmarkDefinition, action: String) -> RefCounted:
	if action.is_empty():
		return use(map, landmark)
	var result := HiddenPassagePushResult.new()
	if map.session == null or landmark == null or not map.landmark_available(landmark):
		return result
	for turn: WorldLandmarkDefinition.Turn in landmark.turns:
		if turn.count == action:
			result.pushed = map.session.hidden_passages().turn(landmark, turn)
	return result
