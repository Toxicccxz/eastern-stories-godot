"""The translations in game/locale against the template (tools/l10n/check_po.py)."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

REPOSITORY = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPOSITORY / "tools/l10n"))

import check_keys  # noqa: E402
import check_po  # noqa: E402


def _po(entries: list[tuple[str, str]], code: str = "en") -> Path:
    lines = ['msgid ""', 'msgstr ""', f'"Language: {code}\\n"', ""]
    for msgid, msgstr in entries:
        lines += [f'msgid "{msgid}"', f'msgstr "{msgstr}"', ""]
    handle = tempfile.NamedTemporaryFile("w", prefix=f"{code}_", suffix=".po", delete=False, encoding="utf-8")
    handle.write("\n".join(lines))
    handle.close()
    return Path(handle.name)


class LitWordsTest(unittest.TestCase):
    """tools/l10n/check_keys.py: the lit words (关键信息高亮) a translation's line does not have."""

    def test_every_marked_word_stands_in_its_line(self) -> None:
        lines = check_keys.marked_lines()
        self.assertTrue(lines, "the content marks some lines")
        self.assertEqual(check_keys.lost_in_source(lines), [])

    def test_the_listing_names_what_a_translation_lost(self) -> None:
        lines = [("native/npcs.json", "一块布条飘落在地，往老松岭去了。", ["布条", "老松岭"])]
        # The item's own name is not how the line says it: listed; the place's name is: not listed.
        po = _po([("一块布条飘落在地，往老松岭去了。", "A strip of cloth falls; he is off to Old Pine Ridge."), ("布条", "Cloth Strip"), ("老松岭", "Old Pine Ridge")])
        problems = check_keys.lost_in(po, lines)
        self.assertEqual(len(problems), 1, problems)
        self.assertIn("布条", problems[0])
        # The word's form under the context "lit" is the one looked for.
        text = po.read_text(encoding="utf-8") + '\nmsgctxt "lit"\nmsgid "布条"\nmsgstr "strip"\n'
        po.write_text(text, encoding="utf-8")
        self.assertEqual(check_keys.lost_in(po, lines), [])
        # A line not translated shows in Chinese, its words too: nothing to list.
        self.assertEqual(check_keys.lost_in(_po([("布条", "Cloth Strip")]), lines), [])

    def test_letters_match_whole_words_in_any_case(self) -> None:
        self.assertTrue(check_keys.stands_in("He made for old pine ridge.", "Old Pine Ridge"))
        self.assertFalse(check_keys.stands_in("Lightning struck.", "Li"))
        self.assertTrue(check_keys.stands_in("도사는 노\u2060송\u2060령으로 갔소.", "노송령"))
        self.assertFalse(check_keys.stands_in("He left.", ""))

    def test_shipped_translations_light_every_marked_word(self) -> None:
        # Not a rule of the game (a word a line lacks is simply not lit): the shipped translations
        # are kept clean so that a new miss shows up here and is looked at.
        lines = check_keys.marked_lines()
        for path in sorted((REPOSITORY / "game/locale").glob("*.po")):
            with self.subTest(path=path.name):
                self.assertEqual(check_keys.lost_in(path, lines), [])


class TranslationsTest(unittest.TestCase):
    def test_shipped_translations_are_clean(self) -> None:
        for path in sorted((REPOSITORY / "game/locale").glob("*.po")):
            with self.subTest(path=path.name):
                self.assertEqual(check_po.problems_in(path), [])

    def test_the_checker_catches_slips(self) -> None:
        cases = {
            "not in the template": ("没有这句话的原文", "Nothing"),
            "lost $l": ("$N挥拳攻击$n的$l", "$N {N:punch|punches} $n"),
            "$P/$p": ("结果只是轻轻地划破$p的皮肉。", "It barely breaks $p skin."),
            "bad form": ("$N挥拳攻击$n的$l", "$N {N:punch|punches|x} $n's $l"),
            "unknown pronoun": ("$N挥拳攻击$n的$l", "$N {N:hers} punches $n's $l"),
            "invents the slot": ("{npc}{action}", "{npc} {action} {mood}"),
            "slots differ": ("%s摇摇头，说道：没听说过。", "“Never heard of it.”"),
            "full-width": ("新游戏", "“New…”"),
            "a modern word": ("新游戏", "New game, okay?"),
            "opens with a form of address": ("这位$RESPECT，进来喝几盅小店的红酒吧，这几天才从窖子里开封的哟。", "$RESPECT, come in."),
        }
        for label, entry in cases.items():
            with self.subTest(label=label):
                problems = check_po.problems_in(_po([entry]))
                self.assertTrue(any(label in problem for problem in problems), problems)

    def test_chinese_keeps_every_slot(self) -> None:
        cases = {
            "$p differs": ("结果只是轻轻地划破$p的皮肉。", "結果只是輕輕地劃破皮肉。"),
            "{slots} differ": ("你向{npc}打听有关『{topic}』的消息。", "你向{npc}打聽消息。"),
        }
        for label, entry in cases.items():
            with self.subTest(label=label):
                problems = check_po.problems_in(_po([entry], "zh_Hant"))
                self.assertTrue(any(label in problem for problem in problems), problems)
        clean = [("结果只是轻轻地划破$p的皮肉。", "結果只是輕輕地劃破$p的皮肉。"), ("$RESPECT饶命！小的这就离开！", "$RESPECT饒命！小的這就離開！")]
        self.assertEqual(check_po.problems_in(_po(clean, "zh_Hant")), [])

    def test_korean_rules(self) -> None:
        cases = {
            "after written text": ("你给{npc}{item}。", "점소이을(를) 불렀다."),
            "a Han character": ("店小二", "店小二"),
            "Chinese punctuation": ("新游戏", "새 게임。"),
            "invents the slot": ("{npc}{action}", "{npc}{action}{mood}"),
            "lost $N": ("$N挥拳攻击$n的$l", "$n의 $l을(를) 친다."),
        }
        for label, entry in cases.items():
            with self.subTest(label=label):
                problems = check_po.problems_in(_po([entry], "ko"))
                self.assertTrue(any(label in problem for problem in problems), problems)
        clean = [
            ("你给{npc}{item}。", "{npc}에게 {item}을(를) 건넸다."),
            ("结果只是轻轻地划破$p的皮肉。", "$p의 살갗을 살짝 베었을 뿐이다."),
            ("$N挥拳攻击$n的$l", "$N은(는) $n의 $l(으)로 주먹을 날린다."),
            ("你向{npc}打听有关『{topic}』的消息。", "{npc}에게 ‘{topic}’에 대해 물었다."),
            ("看见你，放下了手里的扫帚。", "이(가) 당신을 보고 빗자루를 내려놓는다."),
            ("{npc}对你哈哈一笑：{npc}便是{self}！", "{npc}이(가) 껄껄 웃는다. “내가 바로 {self}요!”"),
        ]
        self.assertEqual(check_po.problems_in(_po(clean, "ko")), [])

    def test_japanese_writes_japanese_forms(self) -> None:
        cases = {
            "not a Japanese kanji form": ("颜违，零票。", "顔違、零票。长"),
            "Chinese punctuation": ("颜违，一票。", "顔違，一票。"),
            "ASCII ...": ("多谢啦.....", "かたじけない..."),
            "invents the slot": ("{npc}太累了", "{npc}は{item}に疲れ果てた"),
            "English grammar mark": ("$N挥拳攻击$n的$l", "$Nは{N:punch|punches}$nの$lを殴る。"),
        }
        for label, entry in cases.items():
            with self.subTest(label=label):
                problems = check_po.problems_in(_po([entry], "ja"))
                self.assertTrue(any(label in problem for problem in problems), problems)
        clean = [("结果只是轻轻地划破$p的皮肉。", "だが$pの皮膚を浅く裂いただけだった。"), ("多谢啦.....", "かたじけない……"), ("颜违，两票。", "顔違、二票。")]
        self.assertEqual(check_po.problems_in(_po(clean, "ja")), [])

    def test_russian_rules(self) -> None:
        cases = {
            "after written text": ("你给{npc}{item}。", "Вы даёте бандит{:дат} {item}{:вин}."),
            "unknown case mark": ("你给{npc}{item}。", "Вы даёте {npc}{:д} {item}{:вин}."),
            "no case-marked name": ("看见你，放下了手里的扫帚。", "{~:увидели|увидел|увидела} вас."),
            "bad agreement": ("你给{npc}{item}。", "{npc}{:им} {~:взял|взяла} {item}{:вин}."),
            "with no number before it": ("你打坐 {count} 次", "Медитация: {#:раз|раза|раз} {count}"),
            "bad count": ("%d 分钟前", "%d {#:минуту|минут} назад"),
            "$P/$p in Russian": ("结果只是轻轻地划破$p的皮肉。", "Лишь царапина на коже $p."),
            "full width": ("%d 分钟前", "%d {#:минуту|минуты|минут} назад…"),
            "inside a sentence with no case mark": ("你给{npc}{item}。", "Вы даёте {item}{:вин} и {npc} кивает."),
            "bad player form": ("看见你，放下了手里的扫帚。", "видит вас: «Ты {игрок:пришёл|пришла|пришло}!»"),
            "invents the token": ("{npc}{action}", "$N {npc}{:им} {action}"),
            "does not open with the plural": ("$N挥拳攻击$n的$l", "$N {N:ударил|ударили|ударила} $n{:вин} в $l."),
            "a Han character": ("店小二", "店小二"),
        }
        for label, entry in cases.items():
            with self.subTest(label=label):
                problems = check_po.problems_in(_po([entry], "ru"))
                self.assertTrue(any(label in problem for problem in problems), problems)
        clean = [
            ("你给{npc}{item}。", "Вы даёте {npc}{:дат} {item}{:вин}."),
            ("你打坐 {count} 次", "Медитация: {count} {#:раз|раза|раз}"),
            ("$N挥拳攻击$n的$l", "$N {N:бьёте|бьёт} $n{:вин} кулаком в $l."),
            ("{count}{unit}{item}", "{count} {item}{:счёт}"),
            ("看见你，放下了手里的扫帚。", "видит вас: «Ты {игрок:пришёл|пришла}!»"),
            ("结果只是轻轻地划破$p的皮肉。", "Удар лишь царапает {n:вам|ему|ей} кожу."),
            ("看见你，放下了手里的扫帚。", "видит вас и опускает метлу."),
        ]
        self.assertEqual(check_po.problems_in(_po(clean, "ru")), [])

    def test_spanish_rules(self) -> None:
        cases = {
            "after written text": ("你给{npc}{item}。", "Le das {item}{:el} a mozo{:el}."),
            "unknown article mark": ("你给{npc}{item}。", "Le das {item}{:la} a {npc}{:el}."),
            "with no marked name": ("看见你，放下了手里的扫帚。", "Te ve y queda {~:quieto|quieta}."),
            "bad agreement": ("你给{npc}{item}。", "{npc}{:el} toma {item}{:el}, {~:contento|contenta|contentos|contentas|contentes}."),
            "with no number before it": ("你打坐 {count} 次", "Meditación: {#:vez|veces} {count}"),
            "{:pl} with no number slot": ("你给{npc}{item}。", "Das {item}{:pl} a {npc}{:el}."),
            "$P/$p in Spanish": ("结果只是轻轻地划破$p的皮肉。", "Apenas roza la piel de $p."),
            "full width": ("%d 分钟前", "Hace %d {#:minuto|minutos}…"),
            "with no article mark": ("你给{npc}{item}。", "Das {item}{:el} y {npc} asiente."),
            "bad player form": ("看见你，放下了手里的扫帚。", "Te ve: \"¡Estás {jugador:cansado|cansada|cansade}!\""),
            "invents the token": ("{npc}{action}", "$N{:el} {npc}{:el}{action}"),
            "bad form": ("$N挥拳攻击$n的$l", "$N{:el} {N:golpea} a $n{:el} en $l."),
            "not paired": ("看见你，放下了手里的扫帚。", "Te ve. Qué raro?"),
            "(spanish_style.md, Tone: never)": ("看见你，放下了手里的扫帚。", "Te ve y deja la escoba. Vale."),
            "a Han character": ("店小二", "店小二"),
        }
        for label, entry in cases.items():
            with self.subTest(label=label):
                problems = check_po.problems_in(_po([entry], "es_419"))
                self.assertTrue(any(label in problem for problem in problems), problems)
        clean = [
            ("你给{npc}{item}。", "Le das {item}{:el} a {npc}{:el}."),
            ("你打坐 {count} 次", "Meditas {count} {#:vez|veces}."),
            ("$N挥拳攻击$n的$l", "$N{:el} {n:te golpea|golpea a $n{:el}} en $l."),
            ("{count}{unit}{item}", "{count} {item}{:pl}"),
            ("看见你，放下了手里的扫帚。", "Te ve: \"¿Ya {jugador:llegado|llegada}?\""),
            ("结果只是轻轻地划破$p的皮肉。", "El golpe apenas {n:te roza|le roza|le roza} la piel."),
            ("{npc}{action}", "{npc}{:el}{action}"),
        ]
        self.assertEqual(check_po.problems_in(_po(clean, "es_419")), [])

    def test_a_dropped_slot_is_allowed(self) -> None:
        self.assertEqual(check_po.problems_in(_po([("{npc}对你哈哈一笑：{npc}便是{self}！", "{npc} laughs. \"That'd be me!\"")])), [])


if __name__ == "__main__":
    unittest.main()
