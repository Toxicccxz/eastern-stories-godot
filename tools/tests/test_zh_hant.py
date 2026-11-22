"""tools/l10n/zh_hant.py: the Traditional Chinese draft and its rules (DECISIONS「繁體中文 (preview)」)."""

from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path

REPOSITORY = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPOSITORY / "tools/l10n"))

import zh_hant  # noqa: E402
from po_batch import Block  # noqa: E402


class RulesTest(unittest.TestCase):
    def test_the_rules_read(self) -> None:
        rules = zh_hant.load_rules()
        self.assertTrue(rules.phrases and rules.chars and rules.ui)
        for source, target in rules.phrases:
            self.assertEqual(len(source), len(target), source)
        self.assertEqual(rules.phrases, sorted(rules.phrases, key=lambda pair: len(pair[0])), "longer phrases come last and win")

    def test_interface_text_is_code_scenes_and_the_guide(self) -> None:
        self.assertTrue(zh_hant.is_interface(Block([], refs=["ui/world/map_page.gd"])))
        self.assertTrue(zh_hant.is_interface(Block([], refs=["data/common/codex.json"], notes=["guide.start paragraphs"])))
        self.assertFalse(zh_hant.is_interface(Block([], refs=["data/snow/rooms.json"], notes=["es2:d/snow/inn long"])))


@unittest.skipUnless(importlib.util.find_spec("opencc"), "OpenCC is a development tool (pip install opencc)")
class ConvertTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.converter = zh_hant.Converter()

    def test_the_story_keeps_its_words(self) -> None:
        cases = {
            "回雪亭镇的饮风客栈。": "回雪亭鎮的飲風客棧。",
            "额头上的汗还没干。": "額頭上的汗還沒乾。",
            "接过那卷抄本。": "接過那卷抄本。",
            "这里不准战斗。": "這裡不准戰鬥。",
            "接过信，就着窗口看了很久。": "接過信，就著窗口看了很久。",
            "卫沧澜……二十年没有消息了。": "衛滄瀾……二十年沒有消息了。",
            "他说：“这口剑。”": "他說：「這口劍。」",
        }
        for source, expected in cases.items():
            with self.subTest(source=source):
                self.assertEqual(self.converter.convert(source), expected)

    def test_the_interface_speaks_taiwan(self) -> None:
        self.assertEqual(self.converter.convert("切出窗口时暂停", interface=True), "切出視窗時暫停")
        self.assertEqual(self.converter.convert("语言已切换，但这项设置未能保存。", interface=True), "語言已切換，但這項設定未能儲存。")
        self.assertEqual(self.converter.convert("返回主菜单", interface=False), "返回主選單")


if __name__ == "__main__":
    unittest.main()
