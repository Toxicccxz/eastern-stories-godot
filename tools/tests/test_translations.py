"""The translations in game/locale against the template (tools/l10n/check_po.py)."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

REPOSITORY = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPOSITORY / "tools/l10n"))

import check_po  # noqa: E402


def _po(entries: list[tuple[str, str]], code: str = "en") -> Path:
    lines = ['msgid ""', 'msgstr ""', f'"Language: {code}\\n"', ""]
    for msgid, msgstr in entries:
        lines += [f'msgid "{msgid}"', f'msgstr "{msgstr}"', ""]
    handle = tempfile.NamedTemporaryFile("w", prefix=f"{code}_", suffix=".po", delete=False, encoding="utf-8")
    handle.write("\n".join(lines))
    handle.close()
    return Path(handle.name)


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

    def test_a_dropped_slot_is_allowed(self) -> None:
        self.assertEqual(check_po.problems_in(_po([("{npc}对你哈哈一笑：{npc}便是{self}！", "{npc} laughs. \"That'd be me!\"")])), [])


if __name__ == "__main__":
    unittest.main()
