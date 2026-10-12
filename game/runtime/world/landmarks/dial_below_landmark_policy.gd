extends WorldLandmarkPolicy

## The 地下密室's way up (owner, 京师 plan Q2 (a)): opens the altar's passage from below for
## as long as a press above would (WorldHiddenPassages.open_from_below()).


func use(map: WorldMapController, landmark: WorldLandmarkDefinition) -> RefCounted:
	if map.session == null or landmark == null or not map.landmark_available(landmark):
		return HiddenPassagePushResult.new()
	return map.session.hidden_passages().open_from_below(landmark)
