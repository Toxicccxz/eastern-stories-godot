# Localization

Simplified Chinese (zh_CN) is the source language: every message's ID is its source text
(gettext). Traditional Chinese (`game/locale/zh_Hant.po`), English (`game/locale/en.po`), Korean
(`game/locale/ko.po`), Japanese (`game/locale/ja.po`), Russian (`game/locale/ru.po`), Latin
American Spanish (`game/locale/es_419.po`) and Brazilian Portuguese (`game/locale/pt_BR.po`) are in
preview; the decisions behind this setup are in
[DECISIONS](../migration/DECISIONS.md#localization-the-source-text-is-the-key-2026-10-03).

## Writing player text

* A sentence is one template. Node code uses `tr("…")`, other code
  `TranslationServer.translate("…")`. A template with more than one slot names them,
  `tr("你给{npc}{item}。").format({"npc": …, "item": …})`, so a translator can reorder or drop
  them; one slot may stay `%s`/`%d`. Never `tr()` a sentence that is already put together.
* Data text (names, descriptions, lines, topics, units) stays as authored in definitions,
  state and saves, and is translated where it is shown or put into a sentence. Logic keeps
  comparing the authored text.
* A control showing a fixed text gets the source literal (`label.text = "关闭"`): it translates
  itself and follows a language switch. A control showing composed text is filled again when
  its panel opens.
* Count phrases (一个牛皮酒袋, 十文钱) go through `HeldItemFacts`; numbers in Chinese characters
  through `ChineseNumber.of()`. A language without measure words needs its own rule there.
* Chinese glued to other text with `+` fails `tools/tests` (`lint_concatenation`). A Chinese
  literal that is never shown takes `# NO_TRANSLATE`; `# TRANSLATORS: …` above a line is a
  note for the translator.

## The template

`python tools/l10n/extract_pot.py` writes `game/locale/eastern_stories.pot` from the scripts,
scenes and the content files in `content_manifest.json` (fields listed in the tool). Run it
after changing player text; `verify.py` step 1 fails while the committed template is out of
date. Godot's own POT generation is not used: it misses `TranslationServer.translate()`,
const tables and the JSON content, and cannot run from the command line.

A new text key in the data must be taught to the extractor: `tools/tests/test_extract_pot.py`
(`CompletenessTest`) fails on any string with Chinese text anywhere in `game/data` that is not
in the template, unless its key is listed there in `NOT_SHOWN` (marks, temps, ids, comments,
name parts). Developer output (`push_error`, `push_warning`, `print`…) is never extracted.

## The pseudo-locale check

`snow_main_path_pseudo_test` plays Snow's main path, switches to a test language built from
the template in Settings after the first leg, and from then on fails on any text on screen
that did not go through a translation (`tests/support/pseudo_locale.gd`,
`visible_text_scan.gd`). `localization_test` covers the shell's own screens, the language
choice and the Settings language.

## Adding a language

1. Make `game/locale/<code>.po` from the template (Poedit: New from POT; Weblate or msginit
   work too) and translate. Untranslated messages show the Simplified source.
2. Add the language to `game/locale/languages.json`: `code`, its own `name`, `script` (Hans or
   Hant for Chinese), `translation` (`res://locale/<code>.po`) and the system `fonts` to try; a
   language with glyph forms of its own names its pixel face in `face` (繁體中文: 缝合像素 zh_tw),
   which `LocalizationService` puts into the theme's face while the language shows.
   Settings lists it under 语言 (跟随系统 and each language by its own name). While it is still
   being translated add `"preview": true`: players can choose it, but a system in that language
   is not given it on its own.
3. When the source text changes later, regenerate the template and update each `.po` from it
   (Poedit: Update from POT; `msgmerge`); changed messages come back fuzzy.
4. `python tools/l10n/check_po.py` checks every `.po` against the template (slots kept, no stale
   messages, grammar marks well formed, no full-width “ ” … in a Latin language; in Korean a
   particle pair only after a slot, no Han character, no Chinese punctuation; in Japanese every
   kanji a Japanese form and no Chinese punctuation; in Russian and Spanish the grammar marks well
   formed and a name slot inside a sentence marked; in Spanish ¿? ¡! paired and no word from the
   style guide's never list; in Portuguese the same with its own marks, no ¿ ¡ and its never list);
   `tools/tests/test_translations.py` runs it in the gate.

## Working on a translation

The `.po` is the one home of a language's text: nothing regenerates it, so an edit in Poedit or
by hand stays. Batches go in with `tools/l10n/po_batch.py`, which changes only the entries it is
given and keeps every other line as it was:

* `po_batch.py todo game/locale/en.po --from data/oldpine` lists what is not translated yet
  (missing, empty or fuzzy) where it is used, one line each: key, source, where, notes;
* `po_batch.py apply game/locale/en.po batch.tsv` writes a batch of `key<TAB>translation` lines
  (`=source<TAB>translation` also works; `\n` is a line break): changed in place, new ones at
  the end, a fuzzy flag cleared;
* `po_batch.py sync game/locale/en.po` turns what the template dropped into obsolete entries,
  after which `todo` lists the changed line again.

Keep batches and scratch lists under `build/`, then run `check_po.py`.

English: style, names, terms and the grammar marks ES2's templates need are in
[english_style.md](english_style.md).

Korean: style, registers, names, the particle pairs after a slot (`을(를)`, resolved by
`KoreanParticles` once a line is filled) and word-whole wrapping (`KoreanText`) are in
[korean_style.md](korean_style.md). A place that shows filled text without the control
translating it calls `ShownText.of()` (Korean, Russian and Spanish finish a filled line; their catalogs are
wrapped in `FinishedTranslation`); `korean_lines_test` fills every template and fails on a pair
left over.

Russian: style, ты and вы, names (Palladius; places T/П), terms, and the grammar marks are in
[russian_style.md](russian_style.md). A name changes with its case and verbs agree with its gender
and number, so the translation marks the case after a slot (`{npc}{:вин}`), the agreement
(`{~:…}`, `{#:…}`, `{игрок:…}`) and `$N/$n` forms (`{N:бьёте|бьёт}`); `RussianText` resolves them
once the line is filled, from the noun table `game/locale/ru_nouns.json`
(`tools/l10n/ru_nouns.py draft|prune|check`; drafting needs `pip install pymorphy3`). Names in
ru.po open with a capital; a name slot inside a sentence always carries a mark. `russian_lines_test`
fills every template and fails on a mark left over.

Spanish (es_419; Godot calls the locale es, so every Spanish system matches it): style, tú and
usted, names (pinyin; places as in English), terms and the grammar marks are in
[spanish_style.md](spanish_style.md). A common noun takes an article that agrees with it and
adjectives agree with a name's gender and number, so the translation marks the article after a slot
(`{npc}{:el}`, `{:un}`, `{:los}`, `{:unos}`, `{:0}`, `{count} {item}{:pl}`), the agreement
(`{~:herido|herida}`, `{#:día|días}`, `{jugador:cansado|cansada}`) and `$N/$n` forms
(`{N:golpeas|golpea}`, `{n:te|lo|la}`); `SpanishText` resolves them once the line is filled, from
the noun table `game/locale/es_nouns.json` (gender, plural, and the article for el hacha or el Paso
del Camello), contracts a el and de el and leaves out the subject tú. `spanish_lines_test` fills
every template and fails on a mark left over or a «a tú».

Brazilian Portuguese (pt_BR): style, você and o senhor, names (pinyin; places as in English), terms
and the grammar marks are in [portuguese_style.md](portuguese_style.md). It shares Spanish's layer:
`RomanceText` and `RomanceNouns` hold the mechanism, configured per language (`SpanishText`,
`PortugueseText`: the marks, the contractions, whether the subject you is left out, the noun table).
The translation marks the article after a slot (`{npc}{:o}`, `{:um}`, `{:os}`, `{:uns}`, `{:0}`,
`{count} {item}{:pl}`) and writes the bare preposition before it: the game adds o/a/os/as and
contracts it (de o → do, em a → na, a a → à, por o → pelo), from `game/locale/pt_BR_nouns.json`;
agreement and numbers as in Spanish (`{~:ferido|ferida}`, `{#:dia|dias}`,
`{jogador:cansado|cansada}`); the player is você, whose verb is the third person's, so `$N` needs no
form, and the player as an object is te (`{n:te golpeia|golpeia $n{:o}}`). `portuguese_lines_test`
fills every template and fails on a mark left over or a doubled contraction («de do», «no o»).

Japanese: style, voices, the forms of address `{self}` and `{respect}` take, names (kanji in
Japanese forms), the words Chinese and Japanese write alike but mean differently, numbers and
typography are in [japanese_style.md](japanese_style.md). Japanese needs no grammar marks: its
particles do not change with the name before them, and it breaks lines between any two characters.
A rare kanji outside JIS X 0208 (a name's) goes on check_po's `JAPANESE_EXTRA_KANJI` once the ja
face is seen to draw it.

Traditional Chinese is drafted, not translated by hand: one Taiwan-standard text, the story's words
unchanged, Taiwan's words in the interface (DECISIONS「繁體中文 (preview)」). After the template
changes, `python tools/l10n/po_batch.py sync game/locale/zh_Hant.po`, then

    python tools/l10n/zh_hant.py draft game/locale/zh_Hant.po > build/l10n/zh_hant_batch.tsv
    python tools/l10n/po_batch.py apply game/locale/zh_Hant.po build/l10n/zh_hant_batch.tsv
    python tools/l10n/zh_hant.py check game/locale/zh_Hant.po

`draft` converts what is not translated yet with OpenCC s2tw (`pip install opencc`, a development
tool: the game reads the .po) and `tools/l10n/zh_hant_rules.tsv`: the phrases s2tw gets wrong
here, one standard form for the variants it mixes, and the interface words. Read the new lines'
one-to-many characters (干 乾 幹, 里 裡, 只 隻, 发 髮, 后 後, 台 臺 檯…) and add a phrase rule for
any it gets wrong, so the next draft gets it right too. `check` converts every message back
(tw2s) and fails on one that no longer says what its source says.

A system's language is matched by `LanguageResolver`: Chinese by script (Hans for CN, SG, MY or
no region; Hant for TW, HK, MO), others by language; anything not listed reads Simplified.
