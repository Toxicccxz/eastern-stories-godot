class_name HockshopStaticValues
extends RefCounted

## Only missing immutable query("value") facts; NOT a universal item price.
## obj/cloth.c (unset), d/oldpine/obj/{short_sword,long_sword,leather}.c.
const VALUES: Dictionary[StringName, int] = {
	&"es2:obj/cloth": 0,
	&"es2:d/oldpine/obj/short_sword": 300,
	&"es2:d/oldpine/obj/long_sword": 700,
	&"es2:d/oldpine/obj/leather": 200,
}
