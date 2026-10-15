class_name DeathWorldDefinitions
extends RefCounted

## IDs the runtime refers to by name in 阴间 (d/death). The map, its zones and its people
## are data (death/world.json, death/rooms.json).
const MAP_ID: StringName = &"death.realm"
## include/login.h DEATH_ROOM (/d/death/gate): the dead arrive here, before the white gargoyle.
const GATE_ZONE_ID: StringName = &"death.gate"
const ARRIVAL_SPAWN_ID: StringName = &"death.gate.arrival"
