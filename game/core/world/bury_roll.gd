class_name BuryRoll
extends RefCounted

## cave5.c do_bury(), after the bones are buried: ikar = random(kar + 10). Above 25
## a book falls from the roof and the player stays; above 20 a few scraps of paper
## flutter down and the floor gives way all the same; otherwise it just gives way.
enum Outcome { BOOK, PAPER, FALL }

const BOOK_ABOVE: int = 25
const PAPER_ABOVE: int = 20


static func roll(karma: int, random_source: WorldInteractionRandomSource) -> Outcome:
	var ikar: int = random_source.legacy_random(karma + 10)
	if ikar > BOOK_ABOVE:
		return Outcome.BOOK
	if ikar > PAPER_ABOVE:
		return Outcome.PAPER
	return Outcome.FALL
