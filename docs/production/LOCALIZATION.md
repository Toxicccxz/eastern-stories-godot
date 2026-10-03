# Localization

Simplified Chinese (zh_CN) is the source language: every message's ID is its source text
(gettext). No translations ship yet; the decisions behind this setup are in
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
   Hant for Chinese), `translation` (`res://locale/<code>.po`) and the system `fonts` to try.
   Settings shows a 语言 choice once there are two languages.
3. When the source text changes later, regenerate the template and update each `.po` from it
   (Poedit: Update from POT; `msgmerge`); changed messages come back fuzzy.

A system's language is matched by `LanguageResolver`: Chinese by script (Hans for CN, SG, MY or
no region; Hant for TW, HK, MO), others by language; anything not listed reads Simplified.
