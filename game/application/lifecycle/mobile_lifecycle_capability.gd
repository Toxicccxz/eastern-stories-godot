class_name MobileLifecycleCapability
extends RefCounted


## The platform's own lifecycle (background, foreground, focus): phones and tablets.
func enabled() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios")


## A desktop window, whose focus alone counts (切出窗口时暂停, DECISIONS「切出窗口」); not the
## headless runs, which have no window to lose.
func desktop_focus() -> bool:
	return not enabled() and DisplayServer.get_name() != "headless"
