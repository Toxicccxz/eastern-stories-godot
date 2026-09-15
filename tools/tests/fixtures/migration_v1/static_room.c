// Hand-authored syntax fixture, not copied ES2 gameplay content.
inherit ROOM;
void create()
{
    set("short", "Test room");
    set("name", "Source name");
    set("long", @TEXT
Two imaginary guards are text only.
TEXT
    );
    set("no_fight", 0);
    set("outdoors", "test");
    set("exits", ([
        "east": "/d/test/east",
        "west": __DIR__"west",
        "north": __DIR__ + "north",
    ]));
}
