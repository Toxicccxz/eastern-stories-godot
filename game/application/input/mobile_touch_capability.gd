class_name MobileTouchCapability
extends RefCounted


func enabled() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios")
