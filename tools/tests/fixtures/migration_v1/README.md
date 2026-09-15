# Static room fixtures

`static_room.c` is a hand-authored minimal syntax example, not copied legacy game content.
Its logical source path in tests is `d/test/room.c`. The three target paths are declared to
exist in the test's source index; no Godot scene or LPC object is instantiated.

`static_room.expected.json` is a manually authored, reviewable projection golden. It was written
independently of the extractor; tests do not regenerate it. Full provenance is checked separately
against independently computed raw-byte spans, hashes and line/column expectations.

Real-source regression tests read the repository ES2 files in place, without modifying or copying
them. Their reference tree is `4106480ab28cce8cd7b55704f8ae9ae062d42d03`; P2's implementation
report records actual scan counts rather than making those counts parser behavior.
