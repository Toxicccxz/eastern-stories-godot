extends WorldLandmarkPolicy

## weapon_storage.c do_push(): `push <direction>` moves the shelf and it
## springs back; the right number of pushes opens the floor (WorldHiddenPassages).
## `push shelf` only hints that it slides; the button names the push itself.


func use(map: WorldMapController, landmark: WorldLandmarkDefinition) -> RefCounted:
	if map.session == null or landmark == null or not map.landmark_available(landmark):
		return HiddenPassagePushResult.new()
	return map.session.hidden_passages().push(landmark)
