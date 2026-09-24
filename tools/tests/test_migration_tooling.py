"""Deterministic source extraction tests; all fixtures and outputs are tooling-only."""

from __future__ import annotations

import contextlib
import copy
import hashlib
import io
import json
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


REPOSITORY = Path(__file__).resolve().parents[2]
if str(REPOSITORY) not in sys.path:
    sys.path.insert(0, str(REPOSITORY))
from tools.migration import cli
from tools.migration.es2_source import Source, SourceError, ToolError, discover, lex, literal, pairs
from tools.migration.room_extractor import CreateTailEffect, MacroSummary, EXCLUDED_LITERAL_BASES, RoomExtractor, canonical, directive_parts, reference, scan


FIXTURES = Path(__file__).parent / 'fixtures/migration_v1'


def extract(text: str | bytes, path: str = 'd/test/room.c', paths: set[str] | None = None,
            dependencies: dict[str, Source] | None = None) -> tuple[dict, list[dict]]:
    data = text.encode('utf-8') if isinstance(text, str) else text
    return RoomExtractor(Source(path, data), paths or set(), dependencies or {}).extract()


def room(body: str, extra: str = '') -> str:
    return 'inherit ROOM;\nvoid create() {\n' + body + '\n}\n' + extra


def fields(record: dict, field: str) -> list[dict]:
    return [f for f in record['facts'] if f['field'] == field]


def codes(findings: list[dict]) -> set[str]:
    return {f['code'] for f in findings}


class LexerTests(unittest.TestCase):
    def test_line_and_block_comments_do_not_produce_code(self):
        tokens = lex(Source('x.c', b'// inherit ROOM;\n/* inherit ROOM; */ inherit ITEM;'))
        self.assertEqual(['inherit', 'ITEM', ';'], [t.text for t in tokens])

    def test_string_escaped_quote_and_backslash(self):
        token = lex(Source('x.c', br'"a\"b\\c // /* inherit ROOM;"'))[0]
        self.assertEqual('a"b\\c // /* inherit ROOM;', literal(token)['value'])

    def test_character_literals_are_opaque(self):
        ts = lex(Source('x.c', b"'{' '\\n' '\\''"))
        self.assertEqual(['character'] * 3, [t.kind for t in ts])
        self.assertEqual({}, pairs(ts))

    def test_quoted_symbol_is_unsupported_not_executed(self):
        self.assertEqual('unknown', lex(Source('x.c', b"'symbol"))[0].kind)

    def test_heredoc_excludes_code_and_keeps_suffix(self):
        ts = lex(Source('x.c', b'@CODE\ninherit ROOM;\nCODE);'))
        self.assertEqual(['heredoc', 'punctuation', 'punctuation'], [t.kind for t in ts])
        self.assertEqual('inherit ROOM;\n', literal(ts[0])['value'])

    def test_heredoc_similar_identifier_is_body(self):
        ts = lex(Source('x.c', b'@CODE\nCODE_EXTRA\nCODE is text\nCODE\n'))
        self.assertEqual('CODE_EXTRA\nCODE is text\n', literal(ts[0])['value'])

    def test_array_heredoc_not_scalar(self):
        ts = lex(Source('x.c', b'@@LINES\na\nb\nLINES\n'))
        self.assertEqual('heredoc_array', ts[0].kind)
        self.assertIsNone(literal(ts[0]))

    def test_multibyte_crlf_offsets(self):
        raw = '// 雪\r\n\tset("short", "雪");'.encode('utf-8')
        source = Source('x.c', raw)
        ts = lex(source)
        self.assertEqual(9, ts[0].start)
        p = source.span(ts[0].start, ts[-1].end, 'create', 'call:set', 1)
        self.assertEqual((2, 2), (p['line'], p['column']))
        self.assertEqual(raw[9:].decode('utf-8'), p['raw'])

    def test_unterminated_comment_string_multiline(self):
        for raw in [b'/* a', b'"unfinished', b'@TEXT\nunfinished', b'"escape\\']:
            with self.subTest(raw=raw), self.assertRaises(SourceError):
                lex(Source('x.c', raw))

    def test_encoding_corruption(self):
        for raw in [b'\xff', b'\x00', '\ufffd'.encode('utf-8')]:
            with self.subTest(raw=raw), self.assertRaises(SourceError) as caught:
                lex(Source('x.c', raw))
            self.assertTrue(caught.exception.encoding)

    def test_balanced_spaced_closure(self):
        pairs(lex(Source('x.c', b'set("x", (:this_object(), ({"a"}): ));')))

    def test_mismatched_delimiters(self):
        with self.assertRaises(SourceError):
            pairs(lex(Source('x.c', b'([)]')))

    def test_preprocessor_continuation_is_opaque(self):
        ts = lex(Source('x.c', b'#define TEXT \\\n inherit ROOM;\ninherit ITEM;'))
        self.assertEqual('directive', ts[0].kind)
        self.assertEqual(['inherit', 'ITEM', ';'], [t.text for t in ts[1:]])


class RoomFactTests(unittest.TestCase):
    def test_hand_authored_projection_golden(self):
        data = (FIXTURES / 'static_room.c').read_bytes()
        record, findings = extract(data, paths={'d/test/east.c', 'd/test/west.c', 'd/test/north.c'})
        actual = dict(status=record['status'], fields=[f['field'] for f in record['facts']],
                      text=[f['value']['value'] for f in record['facts'] if f['field'] in {'short', 'name', 'long'}],
                      flags=[f['value'] for f in record['facts'] if f['field'] in {'no_fight', 'outdoors'}],
                      exits=[dict(direction=f['value']['direction'], target=f['value']['target'], classification=f['classification']) for f in fields(record, 'exit')],
                      finding_codes=[f['code'] for f in findings])
        expected = json.loads((FIXTURES / 'static_room.expected.json').read_text(encoding='utf-8'))
        self.assertEqual(expected, actual)
        self.assertEqual('TEXT_ONLY', fields(record, 'long')[0]['text_classification'])

    def test_non_room_categories_are_out_of_scope(self):
        for category in ['BANK', 'HOCKSHOP', 'CLASS_GUILD', 'NPC', 'ITEM', 'SWORD', 'CLOTH', 'F_FOOD']:
            with self.subTest(category=category):
                r, f = extract(f'inherit {category}; void create() {{ set("short", "x"); }}')
                self.assertEqual('OUT_OF_SCOPE', r['status'])
                self.assertEqual([], r['facts'])

    def test_room_outside_d_is_not_supported(self):
        r, _ = extract(room('set("short", "x");'), 'u/room.c')
        self.assertFalse(r['supported_candidate'])

    def test_multiple_inherit_retained_without_flattening(self):
        r, f = extract('inherit ROOM; inherit F_CUSTOM; void create() {}')
        self.assertEqual(['ROOM', 'F_CUSTOM'], r['category_candidates'])
        self.assertEqual(2, len(fields(r, 'inherit')))
        self.assertIn('UNRESOLVED_INHERITANCE', codes(f))
        self.assertEqual('PARTIAL', r['status'])

    def test_room_and_explicit_excluded_category_is_not_supported(self):
        r, _ = extract('inherit ROOM; inherit NPC; void create() {}')
        self.assertFalse(r['supported_candidate'])

    def test_fake_inherit_all_noncode_forms(self):
        text = '// inherit ROOM;\n/* inherit ROOM; */\ninherit ITEM;\nstring s="inherit ROOM;";\nstring t=@CODE\ninherit ROOM;\nCODE\n;'
        r, _ = extract(text)
        self.assertEqual(['ITEM'], r['category_candidates'])
        self.assertFalse(r['supported_candidate'])

    def test_explicit_zero_is_distinct_from_absent(self):
        r, _ = extract(room('set("no_fight", 0); set("indoors", 1);'))
        self.assertEqual({'kind': 'integer', 'value': '0'}, fields(r, 'no_fight')[0]['value'])
        self.assertEqual([], fields(r, 'outdoors'))

    def test_large_integer_is_exact_decimal_string(self):
        r, _ = extract(room('set("no_fight", 9007199254740993);'))
        self.assertEqual('9007199254740993', fields(r, 'no_fight')[0]['value']['value'])

    def test_unknown_null_macro_arithmetic_not_coerced(self):
        for expression in ['NULL', '0.0', '1 + 2', '077', '"a" + "b"', 'VALUE', 'random(0)']:
            with self.subTest(expression=expression):
                r, f = extract(room(f'set("no_fight", {expression});'))
                self.assertEqual([], fields(r, 'no_fight'))
                self.assertIn('DYNAMIC_EXPRESSION', codes(f))

    def test_repeated_declarations_have_order_and_distinct_identity(self):
        r, f = extract(room('set("short", "x"); set("short", "x");'))
        facts = fields(r, 'short')
        self.assertEqual(2, len(facts))
        self.assertNotEqual(facts[0]['fact_id'], facts[1]['fact_id'])
        self.assertLess(facts[0]['provenance']['source_ordinal'], facts[1]['provenance']['source_ordinal'])
        self.assertIn('DUPLICATE_DECLARATION', codes(f))

    def test_only_unambiguous_create_receiver(self):
        text = room('ob->set("short", "foreign"); if (x) set("short", "conditional"); if (x) {set("short", "nested");}',
                    'void reset() {set("short", "reset");}')
        r, f = extract(text)
        self.assertEqual([], fields(r, 'short'))
        self.assertIn('UNSUPPORTED_CONSTRUCT', codes(f))
        self.assertIn('CALLBACK_BEHAVIOR', codes(f))

    def test_shadowed_setter_not_treated_as_base_set(self):
        r, _ = extract(room('set("short", "x");', 'void set(string a, string b) {}'))
        self.assertEqual([], fields(r, 'short'))

    def test_conditional_preprocessor_not_evaluated(self):
        r, f = extract('#if MODE\ninherit ROOM;\n#else\ninherit NPC;\n#endif\nvoid create() {}')
        self.assertFalse(r['supported_candidate'])
        self.assertIn('DRIVER_SEMANTICS_UNKNOWN', codes(f))

    def test_redefined_room_or_dir_not_guessed(self):
        r, _ = extract('#define ROOM NPC\n' + room('set("short", "x");'))
        self.assertFalse(r['supported_candidate'])
        r, f = extract('#define __DIR__ "/elsewhere/"\n' + room('set("exits", (["e": __DIR__"x"]));'))
        self.assertEqual([], fields(r, 'exit'))
        self.assertIn('DYNAMIC_EXPRESSION', codes(f))

    def test_directive_comments_do_not_hide_shadowing_or_condition(self):
        for directive in ['#define ROOM/**/ NPC\n', '#if/**/FEATURE\n', '#undef/**/ROOM\n']:
            with self.subTest(directive=directive):
                r, _ = extract(directive + room('set("short", "x");'))
                self.assertFalse(r['supported_candidate'])

    def test_unresolved_include_prevents_setter_assumptions(self):
        r, f = extract('#include <missing.h>\n' + room('set("short", "x");'))
        self.assertEqual([], fields(r, 'short'))
        self.assertIn('UNRESOLVED_INCLUDE', codes(f))

    def test_include_shadow_dependency_is_inspected(self):
        deps = {'include/custom.h': Source('include/custom.h', b'#define set my_set\n')}
        r, _ = extract('#include <custom.h>\n' + room('set("short", "x");'), dependencies=deps)
        self.assertEqual([], fields(r, 'short'))

    def test_unknown_field_preserves_full_statement(self):
        r, f = extract(room('set("objects", (["npc": 5]));'))
        self.assertEqual(['inherit'], [fact['field'] for fact in r['facts']])
        diagnostic = next(x for x in f if x['code'] == 'UNSUPPORTED_CONSTRUCT')
        self.assertEqual('set("objects", (["npc": 5]));', diagnostic['provenance']['raw'])

    def test_all_fact_provenance_matches_original_bytes(self):
        raw = (FIXTURES / 'static_room.c').read_bytes().replace(b'\n', b'\r\n')
        r, findings = extract(raw)
        for obj in r['facts'] + findings:
            p = obj['provenance']
            self.assertEqual(hashlib.sha256(raw).hexdigest(), p['source_sha256'])
            self.assertEqual(p['raw'].encode('utf-8'), raw[p['byte_start']:p['byte_end_exclusive']])
            prefix = raw[:p['byte_start']].decode('utf-8')
            self.assertEqual(prefix.count('\n') + 1, p['line'])
            self.assertEqual(len(prefix.rsplit('\n', 1)[-1]) + 1, p['column'])

    def test_malformed_mapping_quarantines_and_clears_facts(self):
        for entry in ['"north" "bad"', ',"e": "x"', '"n":']:
            with self.subTest(entry=entry):
                r, f = extract(room('set("short", "x"); set("exits", ([' + entry + ']));'))
                self.assertEqual('QUARANTINED', r['status'])
                self.assertEqual([], r['facts'])
                self.assertIn('SOURCE_SYNTAX_ERROR', codes(f))


class ExitTests(unittest.TestCase):
    def test_literal_and_dir_exits_order(self):
        r, _ = extract(room('set("exits", (["e": "/d/e", "w": __DIR__"w", "n": __DIR__ + "n"]));'))
        self.assertEqual(['e', 'w', 'n'], [f['value']['direction'] for f in fields(r, 'exit')])
        self.assertEqual('/d/test/w', fields(r, 'exit')[1]['value']['target'])
        self.assertEqual(1, fields(r, 'exit')[1]['normalization']['version'])

    def test_random_variable_and_arithmetic_remain_dynamic(self):
        r, f = extract(room('set("exits", (["e": __DIR__"pine" + random(5), key: "x", "w": DEST]));'))
        self.assertEqual([], fields(r, 'exit'))
        self.assertIn('RNG_SEMANTICS', codes(f))
        self.assertEqual(3, sum(x['code'] == 'DYNAMIC_EXPRESSION' for x in f))

    def test_duplicate_direction_retained(self):
        r, f = extract(room('set("exits", (["e": "/a", "e": "/b"]));'))
        self.assertEqual(2, len(fields(r, 'exit')))
        self.assertIn('DUPLICATE_DECLARATION', codes(f))

    def test_ternary_mapping_is_dynamic_not_syntax_error(self):
        r, f = extract(room('set("exits", (["e": flag ? "/a" : "/b"]));'))
        self.assertEqual('PARTIAL', r['status'])
        self.assertEqual([], fields(r, 'exit'))
        self.assertIn('DYNAMIC_EXPRESSION', codes(f))

    def test_local_callback_and_cross_object_exit_mutations(self):
        r, f = extract(room('set("exits", (["e": "/a"])); delete("exits/e");',
                            'void reset() { ob->set("exits/e", "b"); set("exits", variable); }'))
        # P2F17: the unsupported create mutation suppresses this exit sequence.
        self.assertEqual(0, len(fields(r, 'exit')))
        self.assertEqual('PARTIAL', r['status'])
        self.assertEqual(4, sum(x['code'] == 'ORDER_SENSITIVE_MUTATION' for x in f))

    def test_multiple_exit_assignments_even_empty_first(self):
        _, f = extract(room('set("exits", ([])); set("exits", (["e": "/a"]));'))
        self.assertIn('DUPLICATE_DECLARATION', codes(f))

    def test_reference_case_missing_ambiguous_dynamic(self):
        self.assertEqual('EXISTS', reference('/d/A', {'d/A.c'})['status'])
        self.assertEqual('CASE_MISMATCH', reference('/d/a', {'d/A.c'})['status'])
        self.assertEqual('AMBIGUOUS', reference('/d/AB', {'d/Ab.c', 'd/aB.c'})['status'])
        self.assertEqual('MISSING', reference('/d/absent', set())['status'])
        self.assertEqual('UNRESOLVED', reference('../outside', set())['status'])


class ScanAndCliTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.source = self.base / 'input'
        (self.source / 'd').mkdir(parents=True)
        self.output = self.base / 'output'

    def write(self, path: str, data: bytes):
        file = self.source / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_bytes(data)

    def run_cli(self, *extra: str):
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            return cli.main(['--source-root', str(self.source), '--output-root', str(self.output), *extra])

    def test_discovery_all_files_and_order(self):
        self.write('d/z.c', b'inherit ROOM; void create() {}')
        self.write('d/A.c', b'inherit ITEM;')
        self.write('include/x.h', b'// header')
        self.write('README', b'text')
        r, code = scan(self.source)
        self.assertEqual(0, code)
        self.assertEqual(['README', 'd/A.c', 'd/z.c', 'include/x.h'], [f['input_path'] for f in r['source_manifest']['files']])
        self.assertEqual(4, len(r['objects']))

    def test_reversed_enumeration_does_not_change_output(self):
        self.write('d/z.c', b'inherit ROOM; void create() {}')
        self.write('d/a.c', b'inherit ROOM; void create() {}')
        first = canonical(scan(self.source)[0])
        original = Path.iterdir
        with patch.object(Path, 'iterdir', lambda p: iter(reversed(list(original(p))))):
            second = canonical(scan(self.source)[0])
        self.assertEqual(first, second)
        self.assertNotIn(str(self.base).encode(), first)
        self.assertNotIn(b'timestamp', first)
        self.assertNotIn(b'\r\n', first)

    def test_exit0_and_atomic_repeat(self):
        self.write('d/a.c', b'inherit ROOM; void create() {}')
        self.assertEqual(0, self.run_cli())
        before = (self.output / 'static-rooms.json').read_bytes()
        self.assertEqual(0, self.run_cli())
        self.assertEqual(before, (self.output / 'static-rooms.json').read_bytes())

    def test_exit1_still_emits_diagnostics(self):
        self.write('d/a.c', b'inherit ROOM; void create() {')
        self.write('d/b.c', b'\xff')
        self.assertEqual(1, self.run_cli())
        r = json.loads((self.output / 'static-rooms.json').read_bytes())
        self.assertEqual(2, r['summary']['statuses']['QUARANTINED'])
        self.assertIn('raw_hex', r['findings'][-1]['provenance'])

    def test_exit2_bad_arguments(self):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as caught:
            cli.main(['--profile', 'execute-lpc'])
        self.assertEqual(2, caught.exception.code)

    def test_exit2_unsafe_source_root(self):
        with self.assertRaises(ToolError):
            scan(self.base)

    def test_exit2_output_escape_and_source_overlap(self):
        self.assertEqual(2, self.run_cli('--output', '../escape.json'))
        with self.assertRaises(ToolError):
            cli.destination(self.source, self.source / 'out', Path('x.json'))
        with self.assertRaises(ToolError):
            cli.destination(self.source, REPOSITORY / 'game', Path('x.json'))

    def test_links_and_junctions_rejected(self):
        for method in ['is_symlink', 'is_junction']:
            with self.subTest(method=method), patch.object(Path, method, return_value=True), self.assertRaises(ToolError):
                discover(self.source)

    def test_existing_manual_output_not_replaced(self):
        self.output.mkdir()
        file = self.output / 'static-rooms.json'
        file.write_bytes(b'manual notes')
        self.assertEqual(2, self.run_cli())
        self.assertEqual(b'manual notes', file.read_bytes())

    def test_tracked_external_file_not_replaced(self):
        self.output.mkdir()
        subprocess.run(['git', 'init', '-q', str(self.output)], check=True, capture_output=True)
        file = self.output / 'static-rooms.json'
        file.write_bytes(b'{}')
        subprocess.run(['git', '-C', str(self.output), 'add', 'static-rooms.json'], check=True, capture_output=True)
        self.assertEqual(2, self.run_cli())
        self.assertEqual(b'{}', file.read_bytes())

    def test_fatal_write_preserves_existing_and_cleans_temp(self):
        self.write('d/a.c', b'inherit ROOM; void create() {}')
        self.assertEqual(0, self.run_cli())
        target = self.output / 'static-rooms.json'
        before = target.read_bytes()
        with patch('tools.migration.cli.os.replace', side_effect=OSError('test write failure')):
            self.assertEqual(2, self.run_cli())
        self.assertEqual(before, target.read_bytes())
        self.assertEqual([target], list(self.output.iterdir()))

    def test_fatal_read_does_not_emit_output(self):
        self.write('d/a.c', b'inherit ROOM; void create() {}')
        with patch('tools.migration.es2_source.Path.read_bytes', side_effect=OSError('test read failure')):
            self.assertEqual(2, self.run_cli())
        self.assertFalse((self.output / 'static-rooms.json').exists())

    def test_schema_invariant_failure_is_exit2_without_output(self):
        self.write('d/a.c', b'inherit ROOM; void create() {}')
        report, code = scan(self.source)
        report['objects'][0]['status'] = 'APPROVED'
        with patch('tools.migration.cli.scan', return_value=(report, code)):
            self.assertEqual(2, self.run_cli())
        self.assertFalse((self.output / 'static-rooms.json').exists())

    def test_root_and_mudlib_same_name_files_have_distinct_identity(self):
        self.write('mudlib/d/a.c', b'inherit ROOM; void create() {}')
        self.write('mudlib/README', b'inside')
        self.write('README', b'outside')
        r, _ = scan(self.source)
        self.assertEqual(3, len({o['object_id'] for o in r['objects']}))
        self.assertEqual(['source-root', 'mudlib', 'mudlib'], [o['source_namespace'] for o in r['objects']])

    def test_previous_complete_100_output_upgrades_atomically(self):
        self.write('d/a.c', b'inherit ROOM; void create() {}')
        previous, _ = scan(self.source)
        previous['extractor_version'] = '1.0.0'
        self.output.mkdir()
        target = self.output / 'static-rooms.json'
        target.write_bytes(canonical(previous))
        self.assertEqual(0, self.run_cli())
        self.assertEqual('1.0.33', json.loads(target.read_bytes())['extractor_version'])

    def test_metadata_only_json_is_never_recognized(self):
        self.write('d/a.c', b'inherit ROOM; void create() {}')
        self.output.mkdir()
        target = self.output / 'static-rooms.json'
        for version in ('1.0.0', '1.0.1', '1.0.2', '1.0.3', '1.0.4', '1.0.5', '1.0.6', '1.0.7', '1.0.8', '1.0.9', '1.0.10', '1.0.11', '1.0.12', '1.0.13', '1.0.14', '1.0.15', '1.0.16', '1.0.17', '1.0.18', '1.0.19', '1.0.20', '1.0.21', '1.0.22', '1.0.23', '1.0.24', '1.0.25', '1.0.26', '1.0.27', '1.0.28', '1.0.29', '1.0.30', '1.0.31', '1.0.32', '1.0.33'):
            payload = json.dumps(dict(schema_version=1, profile='static-room-v1', extractor_version=version)).encode()
            target.write_bytes(payload)
            with patch.object(cli, 'atomic_write') as writer:
                self.assertEqual(2, self.run_cli())
                writer.assert_not_called()
            self.assertEqual(payload, target.read_bytes())

    def test_edited_reviewed_or_unknown_output_not_replaced(self):
        self.write('d/a.c', b'inherit ROOM; void create() {}')
        self.output.mkdir()
        target = self.output / 'static-rooms.json'
        for edit in ('version', 'review', 'manifest', 'summary', 'notes'):
            previous, _ = scan(self.source)
            if edit == 'version':
                previous['extractor_version'] = '9.0.0'
            elif edit == 'review':
                previous['review_state'] = 'APPROVED'
            elif edit == 'manifest':
                previous['source_manifest']['sha256'] = '0' * 64
            elif edit == 'summary':
                previous['summary']['scanned_files'] = 123
            else:
                previous['owner_notes'] = 'preserve'
            # Invalid external input must bypass the now-shared strict serializer.
            payload = (json.dumps(previous, ensure_ascii=False, indent=2) + '\n').encode('utf-8')
            target.write_bytes(payload)
            with self.subTest(edit=edit):
                self.assertEqual(2, self.run_cli())
                self.assertEqual(payload, target.read_bytes())


class AuditBlockerRegressionTests(unittest.TestCase):
    """P2F1: adversarial admission, provenance and classification boundaries."""

    def test_h1_parent_output_root_cannot_reenter_protected_checkout(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'input'
            (source / 'd').mkdir(parents=True)
            (source / 'd/probe.c').write_text(room(''), encoding='utf-8')
            for folder in ('game', 'reference/es2', 'docs'):
                target = REPOSITORY / folder / 'p2f1-never-written.json'
                before = sorted(p.name for p in target.parent.iterdir())
                self.assertFalse(target.exists())
                for output in (target, target.relative_to(REPOSITORY.parent)):
                    with self.subTest(folder=folder, output=str(output)), patch.object(cli, 'atomic_write') as writer:
                        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                            result = cli.main(['--source-root', str(source), '--output-root',
                                               str(REPOSITORY.parent), '--output', str(output)])
                        self.assertEqual(2, result)
                        writer.assert_not_called()
                self.assertFalse(target.exists())
                self.assertEqual(before, sorted(p.name for p in target.parent.iterdir()))
            allowed = cli.DEFAULT_OUTPUT_ROOT / 'p2f1-allowed.json'
            self.assertEqual(allowed, cli.destination(source, REPOSITORY.parent, allowed))

    def check_shadow(self, directive, name):
        text = directive + room('set("short", "雪"); set("exits", (["e":__DIR__"x"]));')
        record, findings = extract(text)
        if name == 'ROOM':
            self.assertFalse(record['supported_candidate'])
            self.assertEqual([], record['facts'])
            self.assertIn('UNRESOLVED_INHERITANCE', codes(findings))
        elif name in ('set', 'create'):
            self.assertEqual([], fields(record, 'short'))
            self.assertEqual([], fields(record, 'exit'))
        else:
            self.assertEqual([], fields(record, 'exit'))
            self.assertFalse(any('normalization' in f for f in record['facts']))
        raw = text.encode('utf-8')
        for entry in record['facts'] + findings + record['direct_inherits']:
            p = entry['provenance']
            self.assertEqual(raw[p['byte_start']:p['byte_end_exclusive']].decode('utf-8'), p['raw'])
            self.assertEqual(hashlib.sha256(raw).hexdigest(), p['source_sha256'])
        if name == 'create':
            self.assertEqual('OUT_OF_SCOPE', record['status'])
            self.assertFalse(record['supported_candidate'])
            self.assertEqual([], record['facts'])
            self.assertTrue(all(f['provenance']['raw'] == 'create' for f in findings))
        else:
            self.assertTrue(any(f['provenance']['raw'] == directive for f in findings))

    def test_h2_continued_critical_names_lf_and_crlf(self):
        for newline in ('\n', '\r\n'):
            for name in ('ROOM', 'set', '__DIR__', 'create'):
                with self.subTest(newline=repr(newline), name=name):
                    self.check_shadow('#define \\' + newline + name + ' replacement' + newline, name)

    def test_h2_split_keyword_name_and_undef(self):
        for newline in ('\n', '\r\n'):
            for directive in ('#define RO\\' + newline + 'OM NPC',
                              '#de\\' + newline + 'fine ROOM NPC',
                              '#undef \\' + newline + 'ROOM'):
                with self.subTest(directive=directive):
                    self.check_shadow(directive + newline, 'ROOM')

    def test_h2_benign_continuation_does_not_block_safe_facts(self):
        for newline in ('\n', '\r\n'):
            directive = '#define LABEL \\' + newline + '"label"' + newline
            record, findings = extract(directive + room('set("short", "safe");'))
            self.assertTrue(record['supported_candidate'])
            self.assertEqual('safe', fields(record, 'short')[0]['value']['value'])
            self.assertNotIn('UNRESOLVED_INHERITANCE', codes(findings))

    def test_h2_spliced_directive_error_offsets_use_original_bytes(self):
        for newline in ('\n', '\r\n'):
            text = '#define LABEL \\' + newline + '"雪'
            record, findings = extract(text)
            self.assertEqual('QUARANTINED', record['status'])
            p = findings[-1]['provenance']
            self.assertEqual(text.encode('utf-8').index(b'"'), p['byte_start'])
            self.assertEqual('"雪', p['raw'])

    def test_m1_exact_literal_excluded_bases(self):
        # Independent expectations from include/globals.h:54-68; no inferred subclasses.
        bases = {'/std/room/bank': 'BANK', '/std/room/class_guild': 'CLASS_GUILD',
                 '/std/force': 'FORCE', '/std/room/hockshop': 'HOCKSHOP', '/std/item': 'ITEM',
                 '/std/liquid': 'LIQUID', '/std/char/npc': 'NPC', '/std/skill': 'SKILL'}
        for base, category in bases.items():
            with self.subTest(base=base):
                text = 'inherit ROOM; inherit "' + base + '"; void create(){set("short","mixed");}'
                record, findings = extract(text)
                self.assertFalse(record['supported_candidate'])
                self.assertEqual([], record['facts'])
                self.assertEqual(2, len(record['direct_inherits']))
                self.assertEqual('"' + base + '"', record['direct_inherits'][1]['expression'])
                self.assertEqual('inherit "' + base + '";', record['direct_inherits'][1]['provenance']['raw'])
                self.assertIn(category, record['category_candidates'])
                self.assertIn('OUT_OF_SCOPE', codes(findings))

    def test_m1_does_not_guess_indirect_or_similar_names(self):
        for base in ('/custom/npc', '/std/char/npc_child', '/STD/char/npc'):
            record, findings = extract('inherit "' + base + '"; ' + room(''))
            self.assertTrue(record['supported_candidate'])
            self.assertIn('UNRESOLVED_INHERITANCE', codes(findings))

    def test_m2_missing_include_rejects_admission_without_quarantine(self):
        record, findings = extract('#include <missing.h>\n' + room('set("short", "x");'))
        self.assertFalse(record['supported_candidate'])
        self.assertEqual('OUT_OF_SCOPE', record['status'])
        self.assertEqual([], record['facts'])
        self.assertIn('UNRESOLVED_INCLUDE', codes(findings))
        self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(findings))

    def test_m2_transitive_missing_include_retains_shadow_evidence(self):
        dep = Source('include/test.h', b'#include <missing.h>\n#define ROOM NPC\n')
        record, findings = extract('#include <test.h>\n' + room(''), dependencies={dep.path: dep})
        self.assertFalse(record['supported_candidate'])
        self.assertEqual([], record['facts'])
        self.assertTrue({'UNRESOLVED_INCLUDE', 'UNRESOLVED_INHERITANCE'} <= codes(findings))

    def test_m3_computed_mapping_and_balanced_values_remain_partial(self):
        expressions = ['(["e":"/a"])+(["w":"/b"])',
                       '(["e": (["nested":"/a"])])',
                       '(["e": flag ? "/a" : "/b"])',
                       '(["e": random(2)])', '(["e": (: choose, "a:b" :)])',
                       '([(: choose :) : "/a"])', '(["e": "/a"; "/b"])',
                       '(["e": value:other])']
        for expression in expressions:
            with self.subTest(expression=expression):
                record, findings = extract(room('set("short","safe"); set("exits",' + expression + ');'))
                self.assertEqual('PARTIAL', record['status'])
                self.assertEqual('safe', fields(record, 'short')[0]['value']['value'])
                self.assertEqual([], fields(record, 'exit'))
                self.assertIn('DYNAMIC_EXPRESSION', codes(findings))
                self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(findings))

    def test_m3_genuinely_malformed_mapping_stays_quarantined(self):
        for expression in ('(["e" "/a"])', '([,"e":"/a"])', '(["e":])', '(["e":"/a"]) )'):
            with self.subTest(expression=expression):
                record, findings = extract(room('set("short","safe"); set("exits",' + expression + ');'))
                self.assertEqual('QUARANTINED', record['status'])
                self.assertEqual([], record['facts'])
                self.assertIn('SOURCE_SYNTAX_ERROR', codes(findings))


class P2F2RegressionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.source = Path(self.temp.name) / 'input'
        (self.source / 'd').mkdir(parents=True)
        (self.source / 'd/room.c').write_text(room(
            'set("short","safe");set("long","text only");set("no_fight",0);'
            'set("exits",(["e":__DIR__"room","w":"/d/room"]));'), encoding='utf-8')
        (self.source / 'd/bad.c').write_bytes(b'\xff')
        self.output = Path(self.temp.name) / 'output'
        self.output.mkdir()
        self.target = self.output / 'static-rooms.json'
        self.document, self.scan_code = scan(self.source)

    def run_cli(self):
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            return cli.main(['--source-root', str(self.source), '--output-root', str(self.output)])

    def levels(self, doc):
        obj = next(o for o in doc['objects'] if o['facts'])
        fact = next(f for f in obj['facts'] if 'normalization' in f)
        diagnostic = next(f for f in doc['findings'] if f['provenance']['raw'] is None)
        return {'document': doc, 'manifest': doc['source_manifest'],
                'manifest_file': doc['source_manifest']['files'][0], 'object': obj,
                'inherit': obj['direct_inherits'][0], 'inherit_provenance': obj['direct_inherits'][0]['provenance'],
                'fact': fact, 'finding': doc['findings'][0], 'fact_provenance': fact['provenance'],
                'finding_provenance': doc['findings'][0]['provenance'],
                'encoding_provenance': diagnostic['provenance'], 'normalization': fact['normalization'],
                'normalization_input': fact['normalization']['inputs'][0], 'exit_value': fact['value'],
                'reference_value': fields(obj, 'inherit')[0]['value'],
                'text_value': fields(obj, 'short')[0]['value'], 'integer_value': fields(obj, 'no_fight')[0]['value'],
                'exit_reference': fact['value']['reference'], 'summary': doc['summary'],
                'statuses': doc['summary']['statuses'], 'finding_codes': doc['summary']['finding_codes']}

    def assert_preserved(self, doc):
        # Deliberately bypass canonical(): this is adversarial input, not producer output.
        payload = (json.dumps(doc, ensure_ascii=False, indent=2) + '\n').encode('utf-8')
        self.target.write_bytes(payload)
        with patch.object(cli, 'atomic_write') as writer:
            result = self.run_cli()
            self.assertEqual(2, result)
            writer.assert_not_called()
        self.assertFalse(cli.recognized_output(payload))
        self.assertEqual(payload, self.target.read_bytes())

    def test_unknown_fields_at_every_generated_layer_preserve_bytes(self):
        for version in ('1.0.0', '1.0.1', '1.0.2', '1.0.3', '1.0.4', '1.0.5', '1.0.6', '1.0.7', '1.0.8', '1.0.9', '1.0.10', '1.0.11', '1.0.12', '1.0.13', '1.0.14', '1.0.15', '1.0.16', '1.0.17', '1.0.18', '1.0.19', '1.0.20', '1.0.21', '1.0.22', '1.0.23', '1.0.24', '1.0.25', '1.0.26', '1.0.27', '1.0.28', '1.0.29', '1.0.30', '1.0.31', '1.0.32', '1.0.33'):
            for level in self.levels(self.document):
                for key in ('owner_notes', 'future_field'):
                    with self.subTest(version=version, level=level, key=key):
                        doc = copy.deepcopy(self.document)
                        doc['extractor_version'] = version
                        self.levels(doc)[level][key] = 'preserve manual data'
                        self.assert_preserved(doc)

    def test_canonical_uses_same_closed_schema(self):
        for level in self.levels(self.document):
            with self.subTest(level=level):
                doc = copy.deepcopy(self.document)
                self.levels(doc)[level]['manual_tag'] = 'keep'
                with self.assertRaises(ToolError):
                    canonical(doc)

    def test_all_known_versions_upgrade_with_real_atomic_replace(self):
        for version in ('1.0.0', '1.0.1', '1.0.2', '1.0.3', '1.0.4', '1.0.5', '1.0.6', '1.0.7', '1.0.8', '1.0.9', '1.0.10', '1.0.11', '1.0.12', '1.0.13', '1.0.14', '1.0.15', '1.0.16', '1.0.17', '1.0.18', '1.0.19', '1.0.20', '1.0.21', '1.0.22', '1.0.23', '1.0.24', '1.0.25', '1.0.26', '1.0.27', '1.0.28', '1.0.29', '1.0.30', '1.0.31', '1.0.32', '1.0.33'):
            with self.subTest(version=version):
                doc = copy.deepcopy(self.document)
                doc['extractor_version'] = version
                payload = canonical(doc)
                self.assertTrue(cli.recognized_output(payload))
                self.target.write_bytes(payload)
                with patch.object(cli.os, 'replace', wraps=cli.os.replace) as replace:
                    self.assertEqual(self.scan_code, self.run_cli())
                    replace.assert_called_once()
                self.assertEqual('1.0.33', json.loads(self.target.read_bytes())['extractor_version'])
                self.assertEqual([self.target], list(self.output.iterdir()))

    def test_conditional_fact_and_provenance_shapes_reject_invalid_variants(self):
        for change in ('text_classification', 'normalization', 'missing_normalization', 'raw_hex', 'missing_raw_hex'):
            with self.subTest(change=change):
                doc = copy.deepcopy(self.document)
                levels = self.levels(doc)
                if change == 'text_classification':
                    levels['fact']['text_classification'] = 'TEXT_ONLY'
                elif change == 'normalization':
                    obj = levels['object']
                    fields(obj, 'short')[0]['normalization'] = copy.deepcopy(levels['normalization'])
                elif change == 'missing_normalization':
                    del levels['fact']['normalization']
                elif change == 'raw_hex':
                    levels['fact_provenance']['raw_hex'] = '00'
                else:
                    del levels['encoding_provenance']['raw_hex']
                self.assert_preserved(doc)

    def test_invalid_typed_values_and_counts_rejected(self):
        for level, key, value in [('integer_value', 'value', 0), ('integer_value', 'value', '01'),
                                  ('text_value', 'value', {}), ('exit_value', 'kind', 'text'),
                                  ('exit_reference', 'candidates', {}), ('statuses', 'PARTIAL', True),
                                  ('summary', 'scanned_files', True), ('finding_codes', 'OUT_OF_SCOPE', -1)]:
            with self.subTest(level=level, key=key):
                doc = copy.deepcopy(self.document)
                self.levels(doc)[level][key] = value
                self.assert_preserved(doc)

    def test_money_combined_symbol_and_literal_excluded(self):
        for expr, category in [('MONEY', 'MONEY'), ('COMBINED_ITEM', 'COMBINED_ITEM'),
                               ('"/std/money"', 'MONEY'), ('"/std/item/combined"', 'COMBINED_ITEM')]:
            with self.subTest(expr=expr):
                text = 'inherit ' + expr + ';' + room('set("short","bad candidate");')
                obj, findings = extract(text)
                self.assertFalse(obj['supported_candidate'])
                self.assertEqual('OUT_OF_SCOPE', obj['status'])
                self.assertEqual([], obj['facts'])
                self.assertEqual([expr, 'ROOM'], [d['expression'] for d in obj['direct_inherits']])
                self.assertIn(category, obj['category_candidates'])
                self.assertIn('OUT_OF_SCOPE', codes(findings))
                for declaration in obj['direct_inherits']:
                    p = declaration['provenance']
                    self.assertEqual(text.encode()[p['byte_start']:p['byte_end_exclusive']].decode(), p['raw'])
                    self.assertEqual(hashlib.sha256(text.encode()).hexdigest(), p['source_sha256'])

    def test_similar_money_combined_literals_are_not_guessed(self):
        for path in ('/std/money_custom', '/std/item/combined_child'):
            obj, findings = extract('inherit "' + path + '";' + room(''))
            self.assertTrue(obj['supported_candidate'])
            self.assertFalse({'MONEY', 'COMBINED_ITEM'} & set(obj['category_candidates']))
            self.assertIn('UNRESOLVED_INHERITANCE', codes(findings))


class P2F3RegressionTests(unittest.TestCase):
    # Hand-reviewed object bases only; never generate expectations from production
    # policy or source headers. Changes in authority require explicit review.
    WEAPONS = {
        'AXE': '/std/weapon/axe', 'BLADE': '/std/weapon/blade',
        'DAGGER': '/std/weapon/dagger', 'FORK': '/std/weapon/fork',
        'HAMMER': '/std/weapon/hammer', 'SWORD': '/std/weapon/sword',
        'STAFF': '/std/weapon/staff', 'THROWING': '/std/weapon/throwing',
        'WHIP': '/std/weapon/whip',
    }
    ARMORS = {
        'HEAD': '/std/armor/head', 'NECK': '/std/armor/neck',
        'CLOTH': '/std/armor/cloth', 'ARMOR': '/std/armor/armor',
        'SURCOAT': '/std/armor/surcoat', 'WAIST': '/std/armor/waist',
        'WRISTS': '/std/armor/wrists', 'SHIELD': '/std/armor/shield',
        'FINGER': '/std/armor/finger', 'HANDS': '/std/armor/hands',
        'BOOTS': '/std/armor/boots',
    }

    def assert_excluded(self, expression, category):
        text = ('inherit ROOM;\ninherit ' + expression + ';\n'
                'void create()\n{\n    set("short", "must not migrate");\n}\n')
        obj, findings = extract(text)
        self.assertFalse(obj['supported_candidate'])
        self.assertEqual('OUT_OF_SCOPE', obj['status'])
        self.assertEqual([], obj['facts'])
        self.assertEqual(['ROOM', expression], [d['expression'] for d in obj['direct_inherits']])
        self.assertIn(category, obj['category_candidates'])
        self.assertIn('OUT_OF_SCOPE', codes(findings))
        for index, declaration in enumerate(obj['direct_inherits']):
            p = declaration['provenance']
            expected_raw = 'inherit ' + ('ROOM' if index == 0 else expression) + ';'
            start = text.index(expected_raw)
            self.assertEqual((start, start + len(expected_raw)),
                             (p['byte_start'], p['byte_end_exclusive']))
            self.assertEqual(expected_raw, p['raw'])
            self.assertEqual(expected_raw.encode(), text.encode()[p['byte_start']:p['byte_end_exclusive']])
            self.assertEqual(hashlib.sha256(text.encode()).hexdigest(), p['source_sha256'])
            self.assertEqual('d/test/room.c', p['source_path'])
            self.assertEqual((index + 1, 1), (p['line'], p['column']))
            self.assertEqual(('top-level', 'inherit'), (p['scope'], p['construct']))

    def test_all_standard_symbols_excluded(self):
        for symbol in self.WEAPONS | self.ARMORS:
            with self.subTest(symbol=symbol):
                self.assert_excluded(symbol, symbol)

    def test_all_standard_literals_excluded(self):
        for symbol, path in (self.WEAPONS | self.ARMORS).items():
            with self.subTest(path=path):
                self.assert_excluded('"' + path + '"', symbol)

    def test_authorized_exact_mapping_complete(self):
        self.assertEqual((9, 11), (len(self.WEAPONS), len(self.ARMORS)))
        for symbol, path in (self.WEAPONS | self.ARMORS).items():
            with self.subTest(symbol=symbol):
                self.assertEqual(symbol, EXCLUDED_LITERAL_BASES.get(path))
        # Feature/mixin bases are outside this object-base authorization.
        for name in ('axe', 'blade', 'dagger', 'fork', 'hammer', 'sword', 'staff', 'whip'):
            self.assertNotIn('/std/weapon/_' + name, EXCLUDED_LITERAL_BASES)

    def test_checked_in_authority_matches_hand_reviewed_mapping(self):
        for header, expected in [('weapon.h', self.WEAPONS), ('armor.h', self.ARMORS)]:
            with self.subTest(header=header):
                text = (REPOSITORY / 'reference/es2/mudlib/include' / header).read_text(encoding='utf-8')
                # Read-only drift check, not a runtime policy generator. F_* are
                # feature bases; numeric flags and TYPE_* are not object bases.
                definitions = re.findall(r'^#define\s+([A-Z_]+)\s+"(/std/(?:weapon|armor)/[^"\n]+)"\s*$',
                                         text, re.MULTILINE)
                objects = [(symbol, path) for symbol, path in definitions if not symbol.startswith('F_')]
                self.assertEqual(len(expected), len(objects))
                self.assertEqual(expected, dict(objects))

    def test_similar_unknown_bases_are_not_guessed(self):
        for expression in ('"/std/weapon/sword_custom"', '"/std/weapon/dagger_child"',
                           '"/std/armor/cloth_custom"', '"/std/armor/hands_child"',
                           'DAGGER_CHILD', 'CUSTOM_ARMOR'):
            with self.subTest(expression=expression):
                obj, findings = extract('inherit ROOM;\ninherit ' + expression + ';')
                self.assertTrue(obj['supported_candidate'])
                self.assertEqual('PARTIAL', obj['status'])
                self.assertEqual(['ROOM', expression], obj['category_candidates'])
                self.assertFalse(set(self.WEAPONS | self.ARMORS) & set(obj['category_candidates']))
                self.assertIn('UNRESOLVED_INHERITANCE', codes(findings))


class P2F4RegressionTests(unittest.TestCase):
    # Hand-reviewed globals.h object categories relevant to the authorized D2 fix.
    STANDARD_OBJECTS = {
        'BANK': '/std/room/bank', 'BULLETIN_BOARD': '/std/bboard',
        'CHARACTER': '/std/char', 'CLASS_GUILD': '/std/room/class_guild',
        'COMBINED_ITEM': '/std/item/combined', 'EQUIP': '/std/equip',
        'FORCE': '/std/force', 'HOCKSHOP': '/std/room/hockshop',
        'ITEM': '/std/item', 'LIQUID': '/std/liquid', 'MONEY': '/std/money',
        'NPC': '/std/char/npc', 'POWDER': '/std/medicine/powder',
        'ROOM': '/std/room', 'SKILL': '/std/skill',
    }
    NEW_BASES = ('BULLETIN_BOARD', 'CHARACTER', 'EQUIP', 'POWDER')
    SPECIALIZED_ROOMS = {'BANK', 'CLASS_GUILD', 'HOCKSHOP'}
    # Present in the same authority section, but a skill helper rather than one
    # of this slice's four authorized object-family additions. Pin its definition
    # for full-section drift detection without changing its admission semantics.
    OTHER_STANDARD_DEFINITIONS = {'SSERVER': '/std/sserver'}

    def assert_excluded(self, expression, category):
        text = ('inherit ROOM;\ninherit ' + expression + ';\n'
                'void create() { set("short", "must not migrate"); }\n')
        obj, findings = extract(text)
        self.assertFalse(obj['supported_candidate'])
        self.assertEqual('OUT_OF_SCOPE', obj['status'])
        self.assertEqual([], obj['facts'])
        self.assertEqual(['ROOM', expression], [d['expression'] for d in obj['direct_inherits']])
        self.assertIn(category, obj['category_candidates'])
        self.assertIn('OUT_OF_SCOPE', codes(findings))
        for index, declaration in enumerate(obj['direct_inherits']):
            expected = 'inherit ' + ('ROOM' if index == 0 else expression) + ';'
            start = text.index(expected)
            p = declaration['provenance']
            self.assertEqual((start, start + len(expected)), (p['byte_start'], p['byte_end_exclusive']))
            self.assertEqual(expected, p['raw'])
            self.assertEqual(expected.encode(), text.encode()[p['byte_start']:p['byte_end_exclusive']])
            self.assertEqual(hashlib.sha256(text.encode()).hexdigest(), p['source_sha256'])
            self.assertEqual('d/test/room.c', p['source_path'])
            self.assertEqual((index + 1, 1), (p['line'], p['column']))

    def test_four_symbolic_bases_excluded(self):
        for symbol in self.NEW_BASES:
            with self.subTest(symbol=symbol):
                self.assert_excluded(symbol, symbol)

    def test_four_literal_bases_excluded(self):
        for symbol in self.NEW_BASES:
            with self.subTest(symbol=symbol):
                self.assert_excluded('"' + self.STANDARD_OBJECTS[symbol] + '"', symbol)

    def test_near_matches_are_not_guessed(self):
        for expression in ('"/std/bboard_custom"', '"/std/char_child"', '"/std/equip_custom"',
                           '"/std/medicine/powder_child"', 'BULLETIN_BOARD_CHILD',
                           'CHARACTER_CUSTOM', 'EQUIP_CHILD', 'POWDER_CUSTOM'):
            with self.subTest(expression=expression):
                obj, findings = extract('inherit ROOM;\ninherit ' + expression + ';')
                self.assertTrue(obj['supported_candidate'])
                self.assertEqual('PARTIAL', obj['status'])
                self.assertEqual(['ROOM', expression], obj['category_candidates'])
                self.assertFalse(set(self.NEW_BASES) & set(obj['category_candidates']))
                self.assertIn('UNRESOLVED_INHERITANCE', codes(findings))

    def test_globals_standard_object_policy_complete(self):
        self.assertEqual(15, len(self.STANDARD_OBJECTS))
        self.assertEqual({'BANK', 'CLASS_GUILD', 'HOCKSHOP'}, self.SPECIALIZED_ROOMS)
        for symbol, path in self.STANDARD_OBJECTS.items():
            category = ('generic-room' if symbol == 'ROOM' else
                        'specialized-room' if symbol in self.SPECIALIZED_ROOMS else 'non-room-object')
            with self.subTest(symbol=symbol, category=category):
                if category == 'generic-room':
                    self.assertNotIn(path, EXCLUDED_LITERAL_BASES)
                    obj, _ = extract(room('set("short", "plain room");'))
                    self.assertTrue(obj['supported_candidate'])
                    self.assertEqual('EXTRACTED', obj['status'])
                    self.assertEqual('plain room', fields(obj, 'short')[0]['value']['value'])
                else:
                    self.assertEqual(symbol, EXCLUDED_LITERAL_BASES.get(path))
                    self.assert_excluded(symbol, symbol)
                    self.assert_excluded('"' + path + '"', symbol)

    def test_globals_authority_section_matches_hand_reviewed_table(self):
        text = (REPOSITORY / 'reference/es2/mudlib/include/globals.h').read_text(encoding='utf-8')
        section = text.split('// Inheritable Standard Objects\n', 1)[1].split('// User IDs', 1)[0]
        definitions = re.findall(r'^#define\s+([A-Z_]+)\s+"([^"\n]+)"\s*$', section, re.MULTILINE)
        expected = self.STANDARD_OBJECTS | self.OTHER_STANDARD_DEFINITIONS
        self.assertEqual(len(expected), len(definitions))
        self.assertEqual(expected, dict(definitions))

    def test_room_admission_safeguards_remain_required(self):
        for source, path in [(room(''), 'std/room.c'),
                             ('inherit "/std/room"; void create() {}', 'd/test/room.c'),
                             ('#define ROOM ITEM\n' + room(''), 'd/test/room.c'),
                             ('#include "missing.h"\n' + room(''), 'd/test/room.c')]:
            with self.subTest(source=source, path=path):
                obj, _ = extract(source, path=path)
                self.assertFalse(obj['supported_candidate'])
                self.assertEqual('OUT_OF_SCOPE', obj['status'])
                self.assertEqual([], obj['facts'])


class P2F5RegressionTests(unittest.TestCase):
    BODY = 'void create(){set("short","雪");set("exits",(["e":__DIR__ + "next"]));}\n'

    def assert_directive(self, text, directive, dependencies=None):
        raw = text.encode('utf-8')
        source = Source('d/test/room.c', raw)
        tokens = [t for t in lex(source) if t.kind == 'directive' and t.text == directive]
        self.assertEqual(1, len(tokens))
        token = tokens[0]
        start = raw.index(directive.encode('utf-8'))
        self.assertEqual((start, start + len(directive.encode('utf-8'))), (token.start, token.end))
        self.assertEqual(directive.encode('utf-8'), raw[token.start:token.end])
        self.assertEqual(hashlib.sha256(raw).hexdigest(), source.sha256)
        obj, findings = extract(raw, dependencies=dependencies)
        records = obj['direct_inherits'] + obj['facts'] + findings
        for record in records:
            spans = [record['provenance']]
            if 'normalization' in record:
                spans += record['normalization']['inputs']
            for p in spans:
                self.assertEqual(raw[p['byte_start']:p['byte_end_exclusive']], p['raw'].encode('utf-8'))
                self.assertEqual(source.sha256, p['source_sha256'])
                prefix = raw[:p['byte_start']].decode('utf-8')
                self.assertEqual((prefix.count('\n') + 1, len(prefix.rsplit('\n', 1)[-1]) + 1),
                                 (p['line'], p['column']))
        return obj, findings

    def assert_hazard(self, obj, findings, name, structural=False):
        if name == 'ROOM' or structural:
            self.assertFalse(obj['supported_candidate'])
            self.assertEqual('OUT_OF_SCOPE', obj['status'])
            self.assertEqual([], obj['facts'])
        elif name in ('set', 'create'):
            self.assertEqual([], fields(obj, 'short'))
            self.assertEqual([], fields(obj, 'exit'))
            self.assertEqual('PARTIAL', obj['status'])
        else:
            self.assertEqual([], fields(obj, 'exit'))
            self.assertFalse(any('normalization' in f for f in obj['facts']))
            self.assertEqual('雪', fields(obj, 'short')[0]['value']['value'])
        self.assertTrue(findings)

    def test_comment_prefixed_critical_defines_lf_crlf(self):
        for nl in ('\n', '\r\n'):
            for name, tail in [('ROOM', ' NPC'), ('set', '(key,value) ignored(key,value)'),
                               ('create', ' renamed'), ('__DIR__', ' "/wrong/"')]:
                with self.subTest(newline=repr(nl), name=name):
                    directive = '#define ' + name + tail + nl
                    text = 'inherit ROOM;' + nl + '/* 雪 */ ' + directive + self.BODY.replace('\n', nl)
                    obj, findings = self.assert_directive(text, directive)
                    self.assert_hazard(obj, findings, name, structural=name in ('set', 'create'))

    def test_comment_prefixed_conditionals_lf_crlf(self):
        for nl in ('\n', '\r\n'):
            for keyword in ('if FLAG', 'ifdef FLAG', 'ifndef FLAG', 'elif FLAG', 'else', 'endif'):
                with self.subTest(newline=repr(nl), keyword=keyword):
                    directive = '#' + keyword + nl
                    obj, findings = self.assert_directive('inherit ROOM;' + nl + '/* c */ ' + directive
                                                         + self.BODY.replace('\n', nl), directive)
                    self.assertFalse(obj['supported_candidate'])
                    self.assertEqual('OUT_OF_SCOPE', obj['status'])
                    self.assertEqual([], obj['facts'])
                    self.assertIn('DRIVER_SEMANTICS_UNKNOWN', codes(findings))

    def test_comment_prefixed_undef_all_critical_names(self):
        for nl in ('\n', '\r\n'):
            for name in ('ROOM', 'set', 'create', '__DIR__'):
                with self.subTest(newline=repr(nl), name=name):
                    directive = '#undef ' + name + nl
                    obj, findings = self.assert_directive('inherit ROOM;' + nl + '/* c */ ' + directive
                                                         + self.BODY.replace('\n', nl), directive)
                    self.assert_hazard(obj, findings, name)

    def test_comment_prefixed_missing_and_resolved_includes(self):
        for nl in ('\n', '\r\n'):
            for mode in ('missing', 'resolved', 'shadowed'):
                with self.subTest(newline=repr(nl), mode=mode):
                    directive = '#include <probe.h>' + nl
                    deps = {} if mode == 'missing' else {'include/probe.h': Source('include/probe.h',
                           ('/* header */ #define set other' + nl if mode == 'shadowed' else '// harmless' + nl).encode())}
                    obj, findings = self.assert_directive('/* c */ ' + directive + 'inherit ROOM;' + nl
                                                         + self.BODY.replace('\n', nl), directive, deps)
                    if mode == 'missing':
                        self.assertFalse(obj['supported_candidate'])
                        self.assertEqual('OUT_OF_SCOPE', obj['status'])
                        self.assertEqual([], obj['facts'])
                        self.assertIn('UNRESOLVED_INCLUDE', codes(findings))
                    elif mode == 'shadowed':
                        self.assert_hazard(obj, findings, 'set')
                    else:
                        self.assertTrue(obj['supported_candidate'])
                        self.assertEqual('雪', fields(obj, 'short')[0]['value']['value'])
                    self.assertNotEqual('QUARANTINED', obj['status'])

    def test_comment_prefix_with_continued_directives(self):
        for nl in ('\n', '\r\n'):
            for value in ('#define \\' + nl + 'ROOM NPC', '#define RO\\' + nl + 'OM NPC',
                          '#de\\' + nl + 'fine ROOM NPC'):
                with self.subTest(newline=repr(nl), value=value):
                    directive = value + nl
                    obj, findings = self.assert_directive('inherit ROOM;' + nl + '/* c */ ' + directive
                                                         + self.BODY.replace('\n', nl), directive)
                    self.assert_hazard(obj, findings, 'ROOM')

    def test_multiple_multiline_comment_prefixes(self):
        prefixes = ('', '    ', '/* a */ ', '/* a */ /* b */ ', '  /* a */  /* b */  ',
                    '/*\n a\n*/ ', '/* a\n*/ ', '/* a\n */ /* b\n */ ', 'x /* a\ncontinued */ ')
        for nl in ('\n', '\r\n'):
            for prefix in prefixes:
                with self.subTest(newline=repr(nl), prefix=prefix):
                    directive = '#define set(k,v) ignored(k,v)' + nl
                    obj, findings = self.assert_directive('inherit ROOM;' + nl + prefix.replace('\n', nl)
                                                         + directive + self.BODY.replace('\n', nl), directive)
                    self.assert_hazard(obj, findings, 'set', structural=True)

    def test_actual_code_before_comment_is_not_directive(self):
        for nl in ('\n', '\r\n'):
            for prefix in ('x /* a */ ', 'inherit ROOM; /* a */ '):
                with self.subTest(newline=repr(nl), prefix=prefix):
                    tokens = lex(Source('d/test/room.c', (prefix + '#define ROOM NPC' + nl).encode()))
                    self.assertEqual([], [t for t in tokens if t.kind == 'directive'])
                    self.assertEqual(['#'], [t.text for t in tokens if t.text == '#'])

    def test_hashes_in_comments_strings_and_heredocs_stay_opaque(self):
        samples = ('// #define ROOM NPC\n', '/* #define ROOM NPC */', '/*\n#define ROOM NPC\n*/',
                   '"/* comment */ #define ROOM NPC"', '@TEXT\n#define ROOM NPC\nTEXT\n',
                   '@@TEXT\n#define ROOM NPC\nTEXT\n')
        for nl in ('\n', '\r\n'):
            for text in samples:
                with self.subTest(newline=repr(nl), text=text):
                    tokens = lex(Source('d/test/room.c', text.replace('\n', nl).encode()))
                    self.assertEqual([], [t for t in tokens if t.kind == 'directive'])

    def test_raw_offsets_and_line_state_after_multiline_tokens(self):
        for nl in ('\n', '\r\n'):
            for prefix in ('"雪\ntext" /* c */ ', '@TEXT\n雪\nTEXT; /* c */ '):
                with self.subTest(newline=repr(nl), prefix=prefix):
                    # A token's final physical line still contains code, even
                    # though its body consumed newlines. The following line resets.
                    directive = '#define LABEL "safe"' + nl
                    text = prefix.replace('\n', nl) + '#not_a_directive' + nl + '/* 雪 */ ' + directive
                    self.assert_directive(text, directive)
                    tokens = lex(Source('d/test/room.c', text.encode()))
                    self.assertEqual([directive], [t.text for t in tokens if t.kind == 'directive'])
            directive = '#define FIRST 1' + nl
            next_directive = '#define SECOND 2' + nl
            text = '/* 雪 */ ' + directive + '/* 二 */ ' + next_directive
            self.assert_directive(text, directive)
            self.assert_directive(text, next_directive)

    def test_original_fr01_real_cli_four_cases(self):
        for nl in ('\n', '\r\n'):
            for conditional in (False, True):
                with self.subTest(newline=repr(nl), conditional=conditional), tempfile.TemporaryDirectory() as temp:
                    source = Path(temp) / 'source'
                    (source / 'd').mkdir(parents=True)
                    directive = '#if FOO' if conditional else '#define set(key,value) ignored(key,value)'
                    text = ('inherit ROOM;\n/* audit */ ' + directive + '\n'
                            'void create(){set("short","must not extract");}\n'
                            + ('/* audit */ #endif\n' if conditional else '')).replace('\n', nl)
                    (source / 'd/probe.c').write_bytes(text.encode())
                    output = Path(temp) / 'output'
                    result = subprocess.run([sys.executable, '-m', 'tools.migration.cli', '--source-root', str(source),
                                             '--output-root', str(output)], cwd=REPOSITORY, capture_output=True, text=True)
                    self.assertEqual(0, result.returncode, result.stderr)
                    document = json.loads((output / 'static-rooms.json').read_bytes())
                    obj = document['objects'][0]
                    self.assertEqual([], fields(obj, 'short'))
                    # P2F10: parameter substitution has unknown boundary effects.
                    self.assertFalse(obj['supported_candidate'])
                    self.assertEqual('OUT_OF_SCOPE', obj['status'])
                    self.assertEqual([], obj['facts'])
                    self.assertIn('DRIVER_SEMANTICS_UNKNOWN' if conditional else 'UNRESOLVED_INHERITANCE',
                                  codes(document['findings']))


class P2F6RegressionTests(unittest.TestCase):
    BODY = 'void create(){set("short","safe");}\n'

    def check_directive(self, authored, nl, *, prefix='// 雪\ninherit ROOM;\n', after=None):
        directive = authored.replace('\n', nl)
        prefix = prefix.replace('\n', nl)
        after = self.BODY if after is None else after
        raw = (prefix + directive + after.replace('\n', nl)).encode('utf-8')
        source = Source('d/test/room.c', raw)
        tokens = lex(source)
        directives = [t for t in tokens if t.kind == 'directive']
        self.assertEqual(1, len(directives))
        token = directives[0]
        start = len(prefix.encode('utf-8'))
        self.assertEqual((start, start + len(directive.encode('utf-8'))), (token.start, token.end))
        self.assertEqual(directive, token.text)
        self.assertEqual(raw[token.start:token.end], token.text.encode('utf-8'))
        self.assertEqual(hashlib.sha256(raw).hexdigest(), source.sha256)
        parts = directive_parts(token)
        if after:
            self.assertTrue(any(t.text == 'void' and t.start >= token.end for t in tokens))
        obj, findings = extract(raw)
        self.assertNotEqual('QUARANTINED', obj['status'])
        self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(findings))
        for record in obj['direct_inherits'] + obj['facts'] + findings:
            p = record['provenance']
            self.assertEqual(raw[p['byte_start']:p['byte_end_exclusive']], p['raw'].encode('utf-8'))
            self.assertEqual(source.sha256, p['source_sha256'])
            preceding = raw[:p['byte_start']].decode('utf-8')
            self.assertEqual((preceding.count('\n') + 1, len(preceding.rsplit('\n', 1)[-1]) + 1),
                             (p['line'], p['column']))
        return obj, findings, parts

    def assert_safe(self, obj):
        self.assertTrue(obj['supported_candidate'])
        self.assertEqual('PARTIAL', obj['status'])
        self.assertEqual('safe', fields(obj, 'short')[0]['value']['value'])

    def test_minimal_fr5_01_lf_crlf(self):
        for nl in ('\n', '\r\n'):
            with self.subTest(newline=repr(nl)):
                obj, _, parts = self.check_directive('#define LABEL 1 /* first\nsecond */\n', nl)
                self.assert_safe(obj)
                self.assertEqual(['define', 'LABEL', '1'], parts)

    def test_comment_positions_beginning_middle_end(self):
        for nl in ('\n', '\r\n'):
            for text in ('#define /* 雪\nsecond */ LABEL 1\n', '#define LABEL /* 雪\nsecond */ 1\n',
                         '#define LABEL 1 /* 雪\nsecond */\n'):
                with self.subTest(newline=repr(nl), text=text):
                    obj, _, parts = self.check_directive(text, nl)
                    self.assert_safe(obj)
                    self.assertEqual(['define', 'LABEL', '1'], parts)

    def test_trailing_replacement_tokens_after_close(self):
        for nl in ('\n', '\r\n'):
            obj, _, parts = self.check_directive('#define X /* first\nsecond */ replacement tokens\n', nl)
            self.assert_safe(obj)
            self.assertEqual(['define', 'X', 'replacement', 'tokens'], parts)

    def test_second_hash_after_close_stays_in_same_directive(self):
        for nl in ('\n', '\r\n'):
            obj, _, _ = self.check_directive('#define X /* first\nsecond */ #define Y 1\n', nl)
            self.assert_safe(obj)

    def test_multiple_multiline_comments(self):
        for nl in ('\n', '\r\n'):
            obj, _, parts = self.check_directive('#define LABEL /* one\ntwo */ 1 /* three\nfour */\n', nl)
            self.assert_safe(obj)
            self.assertEqual(['define', 'LABEL', '1'], parts)

    def test_quoted_comment_markers_and_escaped_quotes(self):
        values = ('"/* not a comment */"', '"/* not closed"', '"// not a line comment"',
                  r'"escaped \" /* still string"', r'"backslash \\"', "'/'", "'*'", r"'\''")
        for nl in ('\n', '\r\n'):
            for value in values:
                with self.subTest(newline=repr(nl), value=value):
                    obj, _, _ = self.check_directive('#define TEXT ' + value + '\n', nl)
                    self.assert_safe(obj)
            # LPC quoted symbols are opaque tokens, not unterminated character literals.
            obj, _, _ = self.check_directive("#define TEXT 'symbol /* first\nsecond */\n", nl)
            self.assert_safe(obj)

    def test_line_comments_do_not_open_block_comments(self):
        for nl in ('\n', '\r\n'):
            for tail in ('// comment', '// /* not block', '// " not string', '// trailing \\'):
                with self.subTest(newline=repr(nl), tail=tail):
                    obj, _, parts = self.check_directive('#define LABEL 1 ' + tail + '\n', nl)
                    self.assert_safe(obj)
                    self.assertEqual(['define', 'LABEL', '1'], parts)

    def test_backslash_newline_outside_comment(self):
        for nl in ('\n', '\r\n'):
            for text in ('#define LABEL \\\n1\n', '#define LABEL 1 /* comment */ \\\n2\n',
                         '#de\\\nfine RO\\\nOM NPC /* one\ntwo */\n'):
                with self.subTest(newline=repr(nl), text=text):
                    obj, _, parts = self.check_directive(text, nl)
                    if parts[1] == 'ROOM':
                        self.assertFalse(obj['supported_candidate'])
                        self.assertEqual([], obj['facts'])
                    else:
                        self.assert_safe(obj)

    def test_backslash_inside_multiline_comment(self):
        for nl in ('\n', '\r\n'):
            for space in ('', ' '):
                obj, _, parts = self.check_directive('#define LABEL 1 /* first' + space + '\\\nsecond */\n', nl)
                self.assert_safe(obj)
                self.assertEqual(['define', 'LABEL', '1'], parts)

    def test_other_directive_kinds_remain_conservative(self):
        for nl in ('\n', '\r\n'):
            for name in ('ROOM', 'set', 'create', '__DIR__'):
                with self.subTest(newline=repr(nl), undef=name):
                    obj, _, parts = self.check_directive('#undef /* first\nsecond */ ' + name + '\n', nl)
                    self.assertEqual(['undef', name], parts)
                    if name == 'ROOM':
                        self.assertFalse(obj['supported_candidate'])
                        self.assertEqual([], obj['facts'])
                    elif name in ('set', 'create'):
                        self.assertEqual([], fields(obj, 'short'))
            obj, findings, _ = self.check_directive('#include /* first\nsecond */ <missing.h>\n', nl)
            self.assertFalse(obj['supported_candidate'])
            self.assertEqual('OUT_OF_SCOPE', obj['status'])
            self.assertEqual([], obj['facts'])
            self.assertIn('UNRESOLVED_INCLUDE', codes(findings))
            for keyword in ('if FLAG', 'ifdef FLAG', 'ifndef FLAG', 'elif FLAG', 'else', 'endif'):
                with self.subTest(newline=repr(nl), conditional=keyword):
                    obj, findings, _ = self.check_directive('#' + keyword + ' /* first\nsecond */\n', nl)
                    self.assertFalse(obj['supported_candidate'])
                    self.assertEqual('OUT_OF_SCOPE', obj['status'])
                    self.assertEqual([], obj['facts'])
                    self.assertIn('DRIVER_SEMANTICS_UNKNOWN', codes(findings))

    def test_true_unterminated_block_comment_stays_quarantined(self):
        for nl in ('\n', '\r\n'):
            raw = ('inherit ROOM;\n#define LABEL 1 /* first\nsecond\n').replace('\n', nl).encode()
            obj, findings = extract(raw)
            self.assertEqual('QUARANTINED', obj['status'])
            self.assertEqual([], obj['facts'])
            finding = next(f for f in findings if f['code'] == 'SOURCE_SYNTAX_ERROR')
            self.assertIn('unterminated block comment', finding['reason'])
            p = finding['provenance']
            self.assertEqual(raw.index(b'/*'), p['byte_start'])
            self.assertEqual(raw[p['byte_start']:p['byte_end_exclusive']], p['raw'].encode())

    def test_controls_and_complete_comment_at_eof(self):
        for nl in ('\n', '\r\n'):
            obj, _, _ = self.check_directive('#define LABEL 1 /* comment */\n', nl)
            self.assert_safe(obj)
            obj, _, _ = self.check_directive('#define LABEL 1\n', nl, after='/* first\nsecond */\n' + self.BODY)
            self.assert_safe(obj)
            self.check_directive('#define LABEL 1 /* first\nsecond */', nl, after='')

    def test_p2f5_prefix_and_critical_macro_interaction(self):
        for nl in ('\n', '\r\n'):
            for name, replacement in [('ROOM', 'NPC'), ('set(k,v)', 'ignored(k,v)'), ('create', 'renamed')]:
                for prefix in ('inherit ROOM;\n/* prefix */ ', 'inherit ROOM;\nx /* previous\nline */ '):
                    obj, _, _ = self.check_directive('#define ' + name + ' /* first\nsecond */ ' + replacement + '\n',
                                                      nl, prefix=prefix)
                    self.assertEqual([], fields(obj, 'short'))
            raw = ('x /* prefix */ #define X /* first\nsecond */\n').replace('\n', nl).encode()
            self.assertEqual([], [t for t in lex(Source('x.c', raw)) if t.kind == 'directive'])

    def test_real_cli_fr5_01_matrix(self):
        cases = {'multiline': '#define LABEL 1 /* first\nsecond */\n',
                 'single_line': '#define LABEL 1 /* first second */\n',
                 'independent': '#define LABEL 1\n/* first\nsecond */\n',
                 'unclosed': '#define LABEL 1 /* first\nsecond\n'}
        for nl in ('\n', '\r\n'):
            for name, directive in cases.items():
                with self.subTest(newline=repr(nl), case=name), tempfile.TemporaryDirectory() as temp:
                    source = Path(temp) / 'source'
                    (source / 'd').mkdir(parents=True)
                    text = 'inherit ROOM;\n' + directive + ('' if name == 'unclosed' else self.BODY)
                    (source / 'd/probe.c').write_bytes(text.replace('\n', nl).encode())
                    output = Path(temp) / 'output'
                    result = subprocess.run([sys.executable, '-m', 'tools.migration.cli', '--source-root', str(source),
                                             '--output-root', str(output)], cwd=REPOSITORY, capture_output=True, text=True)
                    doc = json.loads((output / 'static-rooms.json').read_bytes())
                    obj = doc['objects'][0]
                    unclosed = name == 'unclosed'
                    self.assertEqual(1 if unclosed else 0, result.returncode, result.stderr)
                    self.assertEqual(not unclosed, obj['supported_candidate'])
                    self.assertEqual('QUARANTINED' if unclosed else 'PARTIAL', obj['status'])
                    self.assertEqual([] if unclosed else ['inherit', 'short'], [f['field'] for f in obj['facts']])
                    self.assertEqual({'SOURCE_SYNTAX_ERROR'} if unclosed else
                                     {'REQUIRES_SEMANTIC_REVIEW', 'UNSUPPORTED_CONSTRUCT'}, codes(doc['findings']))


class P2F7RegressionTests(unittest.TestCase):
    BODY = 'inherit ROOM;\nvoid create(){set("short","safe");set("exits",(["east":__DIR__"east"]));}\n'
    PAYLOADS = ('plain', '/*', '*/', '//', '"', "'", '"unterminated-looking',
                '/* unterminated-looking', '@MARKER', '@@MARKER',
                '#define set(k,v) ignored(k,v)', '#endif', '\\', '雪 中文 Unicode',
                'mixed " /* // @ @@ #define \\')

    def check_echo(self, authored, nl='\n', *, prefix='// 雪\n', after=None):
        after = self.BODY if after is None else after
        prefix, authored, after = (s.replace('\n', nl) for s in (prefix, authored, after))
        raw = (prefix + authored + after).encode()
        source = Source('d/test/room.c', raw)
        tokens = lex(source)
        token = next(t for t in tokens if t.kind == 'directive')
        start = len(prefix.encode())
        self.assertEqual((start, start + len(authored.encode())), (token.start, token.end))
        self.assertEqual(authored, token.text)
        self.assertEqual(raw[token.start:token.end], token.text.encode())
        self.assertEqual(hashlib.sha256(raw).hexdigest(), source.sha256)
        self.assertEqual(['echo'], directive_parts(token))
        if after:
            self.assertTrue(any(t.start >= token.end for t in tokens))
        obj, findings = extract(raw)
        self.assertNotEqual('QUARANTINED', obj['status'])
        self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(findings))
        records = obj['direct_inherits'] + obj['facts'] + findings
        for record in records:
            p = record['provenance']
            a, b = p['byte_start'], p['byte_end_exclusive']
            self.assertEqual(raw[a:b], p['raw'].encode())
            self.assertEqual(source.sha256, p['source_sha256'])
            preceding = raw[:a].decode()
            self.assertEqual((preceding.count('\n') + 1, len(preceding.rsplit('\n', 1)[-1]) + 1),
                             (p['line'], p['column']))
        if obj['supported_candidate']:
            echo_finding = next(f for f in findings if f['provenance']['byte_start'] == token.start)
            self.assertEqual(authored, echo_finding['provenance']['raw'])
            self.assertEqual('UNSUPPORTED_CONSTRUCT', echo_finding['code'])
        return obj, findings, tokens

    def test_plain_echo_lf_crlf_eof(self):
        for nl in ('\n', '\r\n'):
            self.check_echo('#echo plain\n', nl)
        self.check_echo('#echo plain', after='')

    def test_empty_message(self):
        for nl in ('\n', '\r\n'):
            self.check_echo('#echo\n', nl)
        self.check_echo('#echo', after='')

    def test_raw_quote_comment_heredoc_payload_matrix(self):
        for payload in self.PAYLOADS:
            for nl in ('\n', '\r\n', ''):
                with self.subTest(payload=payload, newline=repr(nl)):
                    self.check_echo('#echo ' + payload + ('\n' if nl else ''), nl or '\n',
                                    after=None if nl else '')

    def test_trailing_backslash_does_not_continue(self):
        for nl in ('\n', '\r\n'):
            for space in ('', ' '):
                obj, _, tokens = self.check_echo('#echo' + space + '\\\n', nl,
                                                  after='#define ROOM NPC\n' + self.BODY)
                self.assertEqual(2, sum(t.kind == 'directive' for t in tokens))
                self.assertFalse(obj['supported_candidate'])

    def test_next_line_critical_macros_and_undef(self):
        hazards = ('define ROOM NPC', 'define set(k,v) ignored(k,v)', 'define create renamed',
                   'define __DIR__ "/wrong/"', 'undef ROOM', 'undef set', 'undef create', 'undef __DIR__')
        for payload in ('/*', '"', '@MARKER', '@@MARKER', '\\', 'plain'):
            for hazard in hazards:
                for nl in ('\n', '\r\n'):
                    with self.subTest(payload=payload, hazard=hazard, newline=repr(nl)):
                        obj, _, tokens = self.check_echo('#echo ' + payload + '\n', nl,
                                                          after='#' + hazard + ' /* closed */\n' + self.BODY)
                        self.assertEqual(2, sum(t.kind == 'directive' for t in tokens))
                        if 'ROOM' in hazard or hazard.startswith(('define set(', 'define create ')):
                            self.assertFalse(obj['supported_candidate'])
                            self.assertEqual([], obj['facts'])
                        elif '__DIR__' in hazard:
                            self.assertEqual([], fields(obj, 'exit'))
                            self.assertEqual(1, len(fields(obj, 'short')))
                        else:
                            self.assertEqual(['inherit'], [f['field'] for f in obj['facts']])

    def test_next_line_include_and_conditional(self):
        for payload in ('/*', '"', '@MARKER', '@@MARKER', '\\', 'plain'):
            for directive, code in (('#include <missing.h>\n', 'UNRESOLVED_INCLUDE'),
                                    ('#if FOO\n', 'DRIVER_SEMANTICS_UNKNOWN')):
                for nl in ('\n', '\r\n'):
                    obj, findings, tokens = self.check_echo('#echo ' + payload + '\n', nl,
                        after=directive + self.BODY + ('#endif\n' if directive.startswith('#if') else ''))
                    self.assertTrue(any(t.text.startswith(directive.rstrip()) for t in tokens[1:]))
                    self.assertFalse(obj['supported_candidate'])
                    self.assertEqual('OUT_OF_SCOPE', obj['status'])
                    self.assertEqual([], obj['facts'])
                    self.assertIn(code, codes(findings))

    def test_same_line_hash_is_message_not_hazard(self):
        for nl in ('\n', '\r\n'):
            for payload in ('#define ROOM NPC', '#define set(k,v) ignored(k,v)', '#endif'):
                obj, _, tokens = self.check_echo('#echo ' + payload + '\n', nl)
                self.assertEqual(1, sum(t.kind == 'directive' for t in tokens))
                self.assertEqual(['inherit', 'short', 'exit'], [f['field'] for f in obj['facts']])

    def test_exact_keyword_and_unknown_stay_generic(self):
        for word in ('echofoo', 'echo_value', 'Echo', 'unknown', 'echo1'):
            for nl in ('\n', '\r\n'):
                obj, findings = extract(('#' + word + ' /*\n' + self.BODY).replace('\n', nl).encode())
                self.assertEqual('QUARANTINED', obj['status'])
                self.assertIn('SOURCE_SYNTAX_ERROR', codes(findings))

    def test_spacing_and_trivia_before_keyword(self):
        for head in ('#echo', '# echo', '#   echo', '#\techo', '#/* before */echo', '#/* before\nend */ echo'):
            for nl in ('\n', '\r\n'):
                self.check_echo(head + ' /* " @ \\\n', nl)

    def test_split_keyword_uses_existing_continuation_only_in_head(self):
        for head in ('#ec\\\nho', '#e\\\nc\\\nho', '#\\\necho', '# \\\n ec\\\nho'):
            for nl in ('\n', '\r\n'):
                obj, _, tokens = self.check_echo(head + ' /* \\\n', nl,
                                                  after='#define set(k,v) ignored(k,v)\n' + self.BODY)
                self.assertEqual(2, sum(t.kind == 'directive' for t in tokens))
                self.assertFalse(obj['supported_candidate'])
                self.assertEqual('OUT_OF_SCOPE', obj['status'])
                self.assertEqual([], obj['facts'])
        token = lex(Source('d/x.c', b'#ec\\\nhofoo plain\n'))[0]
        self.assertEqual('echofoo', directive_parts(token)[0])

    def test_comment_prefix_positive_and_code_negative(self):
        for nl in ('\n', '\r\n'):
            for prefix in ('/* prefix */ ', '/* one */ /* two */ '):
                obj, _, _ = self.check_echo('#echo /*\n', nl, prefix=prefix,
                                              after='#define ROOM NPC\n' + self.BODY)
                self.assertFalse(obj['supported_candidate'])
            tokens = lex(Source('d/x.c', 'x /* prefix */ #echo plain\n'.replace('\n', nl).encode()))
            self.assertFalse(any(t.kind == 'directive' for t in tokens))

    def test_multiline_prefix_retains_p2f5_line_state(self):
        for nl in ('\n', '\r\n'):
            obj, _, _ = self.check_echo('#echo /*\n', nl, prefix='x /* old line\nnew line */ ',
                                          after='#define ROOM NPC\n' + self.BODY)
            self.assertFalse(obj['supported_candidate'])

    def test_unicode_raw_offsets_and_finding_provenance(self):
        for nl in ('\n', '\r\n'):
            self.check_echo('#echo 雪 中文 " /* \\\n', nl, prefix='/* 雪 */ ')

    def test_directive_parts_never_relexes_echo_payload(self):
        for payload in self.PAYLOADS:
            token = lex(Source('d/x.c', ('#echo ' + payload + '\n').encode()))[0]
            with patch('tools.migration.room_extractor.lex', side_effect=AssertionError('echo payload re-lexed')):
                self.assertEqual(['echo'], directive_parts(token))

    def test_true_non_echo_corruption_remains_quarantined(self):
        for text in ('"unterminated normal string', '/* unterminated comment', '#define X /* first\nsecond'):
            for nl in ('\n', '\r\n'):
                obj, findings = extract(text.replace('\n', nl).encode())
                self.assertEqual('QUARANTINED', obj['status'])
                self.assertEqual([], obj['facts'])
                self.assertIn('SOURCE_SYNTAX_ERROR', codes(findings))

    def test_authoritative_non_echo_directive_families(self):
        # Hand-reviewed doc/concepts/preprocessor families, not generated policy.
        bodies = ('define X 1', 'undef X', 'include <missing.h>', 'if FOO', 'ifdef FOO',
                  'ifndef FOO', 'elif FOO', 'else', 'endif', 'pragma strict_types')
        for body in bodies:
            for nl in ('\n', '\r\n'):
                authored = ('#' + body + ' /* first\nsecond */\n').replace('\n', nl)
                ts = lex(Source('d/x.c', (authored + 'void create(){}\n').encode()))
                self.assertEqual(authored, ts[0].text)
                self.assertEqual(body.split()[0], directive_parts(ts[0])[0])
        for head in ('@MARKER', '@@MARKER'):
            self.assertFalse(any(t.kind == 'directive' for t in lex(Source('x.c', (head+'\ntext\nMARKER\n').encode()))))

    def run_echo_cli(self, text, nl):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / 'source'
            (root / 'd').mkdir(parents=True)
            (root / 'd/probe.c').write_bytes(text.replace('\n', nl).encode())
            output = Path(temp) / 'output'
            result = subprocess.run([sys.executable, '-m', 'tools.migration.cli', '--source-root', str(root),
                                     '--output-root', str(output)], cwd=REPOSITORY, capture_output=True, text=True)
            self.assertEqual(0, result.returncode, result.stderr)
            document = json.loads((output / 'static-rooms.json').read_bytes())
            self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(document['findings']))
            return document['objects'][0], document['findings']

    def test_real_cli_fr6_01(self):
        for nl in ('\n', '\r\n'):
            for directive in ('define ROOM NPC', 'define set(k,v) ignored(k,v)', 'define create renamed',
                              'define __DIR__ "/wrong/"', 'include <missing.h>', 'if FOO'):
                obj, findings = self.run_echo_cli('#echo /*\n#' + directive + '\n' + self.BODY, nl)
                if directive.startswith(('define ROOM', 'define set(', 'define create ', 'include', 'if')):
                    self.assertFalse(obj['supported_candidate'])
                    self.assertEqual('OUT_OF_SCOPE', obj['status'])
                    self.assertEqual([], obj['facts'])
                elif '__DIR__' in directive:
                    self.assertEqual(['inherit', 'short'], [f['field'] for f in obj['facts']])
                else:
                    self.assertEqual(['inherit'], [f['field'] for f in obj['facts']])

    def test_real_cli_fr6_02(self):
        for payload in ('"', '/*', '@MARKER', '@@MARKER', '\\', 'plain'):
            for ending in ('\n', '\r\n', ''):
                obj, _ = self.run_echo_cli('#echo ' + payload + ('\n' + self.BODY if ending else ''), ending or '\n')
                self.assertEqual('PARTIAL' if ending else 'OUT_OF_SCOPE', obj['status'])
                self.assertEqual(bool(ending), obj['supported_candidate'])
                self.assertEqual(['inherit', 'short', 'exit'] if ending else [], [f['field'] for f in obj['facts']])


class P2F8RegressionTests(unittest.TestCase):
    ROOT = ('#include "hazard.h"\ninherit ROOM;\n'
            'void create(){set("short","unsafe");set("exits",(["east":__DIR__ + "east"]));}\n')

    def check(self, header, expected='setter', *, extra=None, root=None, newline='\n'):
        sources = {'d/test/hazard.h': header, **(extra or {})}
        deps = {p: Source(p, t.replace('\n', newline).encode()) for p, t in sources.items()}
        raw = (root or self.ROOT).replace('\n', newline).encode()
        obj, findings = extract(raw, dependencies=deps)
        self.assertNotEqual('QUARANTINED', obj['status'])
        self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(findings))
        self.assertNotIn('SOURCE_ENCODING_ISSUE', codes(findings))
        if expected in ('admission', 'header'):
            self.assertFalse(obj['supported_candidate'])
            self.assertEqual('OUT_OF_SCOPE', obj['status'])
            self.assertEqual([], obj['facts'])
            if expected == 'admission':
                self.assertIn('UNRESOLVED_INHERITANCE', codes(findings))
            else:
                self.assertIn('DRIVER_SEMANTICS_UNKNOWN', codes(findings))
                self.assertEqual([], obj['category_candidates'])
        else:
            self.assertTrue(obj['supported_candidate'])
            self.assertEqual('PARTIAL', obj['status'])
            self.assertEqual(['inherit'] if expected == 'setter' else
                             ['inherit', 'short'] if expected == 'dir' else ['inherit', 'short', 'exit'],
                             [f['field'] for f in obj['facts']])
        self.assertEqual([] if expected == 'header' else ['ROOM'],
                         [d['expression'] for d in obj['direct_inherits']])
        for p in [d['provenance'] for d in obj['direct_inherits']] + [f['provenance'] for f in obj['facts'] + findings]:
            self.assertEqual('d/test/room.c', p['source_path'])
            self.assertEqual(hashlib.sha256(raw).hexdigest(), p['source_sha256'])
            self.assertEqual(p['raw'].encode(), raw[p['byte_start']:p['byte_end_exclusive']])
        return obj, findings

    def test_included_set(self):
        for nl in ('\n', '\r\n'):
            self.check('void set(string key, mixed value) {}\n', newline=nl)

    def test_included_create(self):
        for nl in ('\n', '\r\n'):
            self.check('void create() {}\n', newline=nl)

    def test_included_room_inherit(self):
        self.check('inherit ROOM;\n', 'admission')

    def test_included_excluded_inherit(self):
        for base in ('NPC', 'ITEM', '"/std/item"'):
            self.check('inherit ' + base + ';\n', 'admission')

    def test_included_unknown_inherit(self):
        for base in ('CUSTOM', '"/std/unknown"'):
            self.check('inherit ' + base + ';\n', 'admission')

    def test_nested_set(self):
        self.check('#include <b.h>\n', extra={'include/b.h': 'mixed set(string k,mixed v){return 0;}\n'})

    def test_nested_create(self):
        self.check('#include <b.h>\n', extra={'include/b.h': 'void create(){}\n'})

    def test_nested_inherit(self):
        self.check('#include <b.h>\n', 'admission', extra={'include/b.h': 'inherit CUSTOM;\n'})

    def test_nested_critical_macros(self):
        for name, expected in [('ROOM', 'admission'), ('set', 'setter'), ('create', 'setter'), ('__DIR__', 'dir')]:
            for directive in ('define', 'undef'):
                self.check('#include <b.h>\n', 'header' if name == 'create' and directive == 'define' else expected,
                           extra={'include/b.h': '#' + directive + ' ' + name + (' other' if directive == 'define' else '') + '\n'})

    def test_nested_missing_include(self):
        _, findings = self.check('#include <b.h>\n', 'admission', extra={'include/b.h': '#include "missing.h"\n'})
        self.assertIn('UNRESOLVED_INCLUDE', codes(findings))

    def test_conditional_potential_definitions(self):
        for directive in ('if 0', 'ifdef CUSTOM', 'ifndef CUSTOM'):
            for code, expected in [('void set(string k,mixed v){}', 'setter'), ('void create(){}', 'setter'),
                                   ('inherit NPC;', 'admission')]:
                self.check('#' + directive + '\n' + code + '\n#endif\n', expected)

    def test_conditional_alternative_shapes_are_unresolved_not_root_corruption(self):
        _, findings = self.check('#if CUSTOM\nvoid set(){\n#else\nvoid set(){\n#endif\n}\n', 'admission')
        self.assertIn('UNRESOLVED_INCLUDE', codes(findings))

    def test_split_conditional_signatures_are_not_joined_into_harmless_definition(self):
        for text in ('void\n#if CUSTOM\nset\n#else\nhelper\n#endif\n(){}\n',
                     'void helper(\n#if CUSTOM\nint x\n#else\nstring x\n#endif\n){}\n'):
            expected = 'header' if text.startswith('void\n') else 'admission'
            _, findings = self.check(text, expected)
            self.assertIn('DRIVER_SEMANTICS_UNKNOWN' if expected == 'header' else
                          'UNRESOLVED_INCLUDE', codes(findings))

    def test_cyclic_includes_preserve_hazards_and_determinism(self):
        for code, expected in [('', 'safe'), ('void set(){}', 'setter'), ('void create(){}', 'setter'),
                               ('inherit NPC;', 'admission'), ('#define ROOM NPC\n', 'admission')]:
            header = '#include "b.h"\n' + code + '\n'
            deps = {'d/test/b.h': '#include "hazard.h"\n'}
            a = self.check(header, expected, extra=deps)
            self.assertEqual(a, self.check(header, expected, extra=deps))
            self.check('#include "b.h"\n', expected,
                       extra={'d/test/b.h': '#include "hazard.h"\n' + code + '\n'})

    def test_repeated_include_keeps_hazards(self):
        for code, expected in [('void set(){}', 'setter'), ('void create(){}', 'setter'), ('inherit ROOM;', 'admission')]:
            self.check(code, expected, root='#include "hazard.h"\n' + self.ROOT)

    def test_relative_nested_paths_use_including_file_directory(self):
        self.check('#include "headers/a.h"\n', extra={
            'd/test/headers/a.h': '#include "sub/b.h"\n',
            'd/test/headers/sub/b.h': 'void set(){}\n',
            'd/test/sub/b.h': '// misleading root-relative safe header\n'})

    def test_include_path_escape_remains_unresolved(self):
        self.check('#include "../other.h"\n', 'admission', extra={'d/other.h': '// safe\n'})

    def test_comment_string_heredoc_and_nested_body_negatives(self):
        self.check('// void set(){}\n/* inherit NPC; */\n'
                   'string text="void create(){} inherit NPC;";\n'
                   'string long_text=@END\ninherit NPC;\nvoid set(){}\nEND\n;\n'
                   'void helper(){int set; create(); set=1;}\n', 'safe')

    def test_harmless_helper_and_near_names(self):
        self.check('int helper(){return 1;}\nvoid setter(){}\nvoid creator(){}\n', 'safe')

    def test_data_and_prototypes_are_not_function_definitions(self):
        self.check('int x; string foo; mapping data; int set; mixed set(string k,mixed v); void create();\n', 'safe')

    def test_combined_hazards_choose_strongest_boundary(self):
        for text, expected in [('void set(){} void create(){}', 'setter'), ('void set(){} inherit CUSTOM;', 'admission'),
                               ('void create(){} inherit ROOM;', 'admission'), ('#define __DIR__ "/wrong/"\nvoid set(){}', 'setter'),
                               ('#define set other\ninherit NPC;', 'admission')]:
            self.check(text, expected)

    def test_include_order_does_not_erase_compilation_unit_hazards(self):
        bare = self.ROOT.removeprefix('#include "hazard.h"\n')
        for code, expected in [('void set(){}', 'setter'), ('void create(){}', 'setter'), ('inherit CUSTOM;', 'admission')]:
            for root in ('#include "hazard.h"\n'+bare, bare.replace('inherit ROOM;\n', 'inherit ROOM;\n#include "hazard.h"\n'),
                         bare+'#include "hazard.h"\n'):
                self.check(code, expected, root=root)

    def test_malformed_dependency_does_not_quarantine_root(self):
        for text in ('/* unclosed', 'void set(){', 'int x', 'inherit NPC', '}', '\ufffd', '{ weird; }'):
            _, findings = self.check(text, 'admission')
            self.assertIn('UNRESOLVED_INCLUDE', codes(findings))

    def test_bad_dependency_manifest_is_quarantined_separately(self):
        # P2F13: an incomplete header structure is a fragment; genuine lexical
        # corruption still quarantines the dependency separately from the root.
        for raw, expected_code, header_status in ((b'void set(){', 0, 'OUT_OF_SCOPE'),
                                                  (b'/* unclosed', 1, 'QUARANTINED'),
                                                  (b'\xff', 1, 'QUARANTINED')):
            with tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                (root/'d/test').mkdir(parents=True)
                (root/'d/test/room.c').write_bytes(self.ROOT.encode())
                (root/'d/test/hazard.h').write_bytes(raw)
                doc, code = scan(root)
                self.assertEqual(expected_code, code)
                objects = {o['source_path']: o for o in doc['objects']}
                self.assertEqual(header_status, objects['d/test/hazard.h']['status'])
                self.assertEqual([], objects['d/test/hazard.h']['facts'])
                self.assertEqual('OUT_OF_SCOPE', objects['d/test/room.c']['status'])
                self.assertEqual([], objects['d/test/room.c']['facts'])
                self.assertFalse(any(f['code'].startswith('SOURCE_') and f['object_id']=='es2:d/test/room'
                                     for f in doc['findings']))

    def test_real_cli_fr7_matrix_and_root_provenance(self):
        cases = [('set', 'void set(string k,mixed v){}', 'setter'), ('create', 'void create(){}', 'setter'),
                 ('room', 'inherit ROOM;', 'admission'), ('npc', 'inherit NPC;', 'admission'),
                 ('unknown', 'inherit "/std/unknown";', 'admission'), ('helper', 'int helper(){return 1;}', 'safe')]
        cases += [('nested-'+name, text, expected) for name, text, expected in cases[:3]]
        cases += [('nested-missing', '#include "missing.h"\n', 'admission')]
        for nl in ('\n', '\r\n'):
            for name, text, expected in cases:
                with self.subTest(name=name, newline=repr(nl)), tempfile.TemporaryDirectory() as tmp:
                    root = Path(tmp)/'source'
                    (root/'d/test').mkdir(parents=True)
                    source = self.ROOT.replace('\n', nl).encode()
                    (root/'d/test/room.c').write_bytes(source)
                    header = '#include "b.h"\n' if name.startswith('nested-') else text
                    (root/'d/test/hazard.h').write_bytes(header.replace('\n', nl).encode())
                    if name.startswith('nested-'):
                        (root/'d/test/b.h').write_bytes(text.replace('\n', nl).encode())
                    result = subprocess.run([sys.executable, '-m', 'tools.migration.cli', '--source-root', str(root),
                                             '--output-root', str(Path(tmp)/'out')], cwd=REPOSITORY, capture_output=True)
                    self.assertEqual(0, result.returncode, result.stderr)
                    raw = (Path(tmp)/'out/static-rooms.json').read_bytes()
                    doc = json.loads(raw)
                    self.assertEqual(raw, canonical(doc))
                    obj = next(o for o in doc['objects'] if o['source_path']=='d/test/room.c')
                    self.assertEqual(expected != 'admission', obj['supported_candidate'])
                    self.assertEqual('OUT_OF_SCOPE' if expected=='admission' else 'PARTIAL', obj['status'])
                    self.assertEqual([] if expected=='admission' else ['inherit'] if expected=='setter' else ['inherit','short','exit'],
                                     [f['field'] for f in obj['facts']])
                    self.assertEqual(['ROOM'], [i['expression'] for i in obj['direct_inherits']])
                    for fact in obj['facts']:
                        p = fact['provenance']
                        self.assertEqual('d/test/room.c', p['source_path'])
                        self.assertEqual(source[p['byte_start']:p['byte_end_exclusive']], p['raw'].encode())


class P2F9RegressionTests(unittest.TestCase):
    BODY = 'set("short","safe");set("exits",(["east":__DIR__"east"]));'

    def check_case(self, prefix, expected='header', dependencies=None):
        return_obj = None
        for newline in ('\n', '\r\n'):
            raw = (prefix + '\n' + room(self.BODY)).replace('\n', newline).encode()
            deps = {p: Source(p, text.replace('\n', newline).encode())
                    for p, text in (dependencies or {}).items()}
            with self.subTest(prefix=prefix, newline=repr(newline)):
                obj, findings = extract(raw, dependencies=deps)
                self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(findings))
                self.assertEqual(expected not in {'inherit', 'header'}, obj['supported_candidate'])
                self.assertEqual('OUT_OF_SCOPE' if expected in {'inherit', 'header'} else 'PARTIAL', obj['status'])
                self.assertEqual([] if expected in {'inherit', 'header'} else ['inherit'] if expected == 'function'
                                 else ['inherit', 'short', 'exit'], [f['field'] for f in obj['facts']])
                if expected == 'header':
                    self.assertEqual([], obj['direct_inherits'])
                    self.assertEqual([], obj['category_candidates'])
                # No synthetic source: every span still slices the authored root.
                for item in obj['direct_inherits'] + obj['facts'] + findings:
                    p = item['provenance']
                    self.assertEqual(p['raw'].encode(), raw[p['byte_start']:p['byte_end_exclusive']])
                return_obj = obj
        return return_obj

    def test_simple_set(self):
        self.check_case('#define S set\nvoid S(string key,mixed value) {}')

    def test_chain_set(self):
        self.check_case('#define A B\n#define B set\nvoid A() {}')

    def test_simple_create(self):
        self.check_case('#define C create\nvoid C() {}')

    def test_chain_create(self):
        self.check_case('#define A B\n#define B create\nvoid A() {}')

    def test_hidden_inherit(self):
        obj = self.check_case('#define I inherit\nI NPC;', 'inherit')
        self.assertEqual(['ROOM'], [x['symbol'] for x in obj['direct_inherits']])
        self.check_case('#define inherit helper\n', 'inherit')

    def test_chain_inherit(self):
        self.check_case('#define A B\n#define B inherit\nA NPC;', 'inherit')

    def test_inherit_operand_room(self):
        self.check_case('#define BASE ROOM\ninherit BASE;', 'inherit')

    def test_inherit_operand_npc(self):
        self.check_case('#define BASE NPC\ninherit BASE;', 'inherit')

    def test_inherit_operand_item(self):
        self.check_case('#define BASE ITEM\ninherit BASE;', 'inherit')

    def test_inherit_operand_custom(self):
        self.check_case('#define BASE CUSTOM\ninherit BASE;', 'inherit')

    def test_literal_and_chained_bases(self):
        for base in ('ROOM', 'NPC', 'ITEM', 'CUSTOM', '"/std/item"', '"/std/unknown"'):
            self.check_case(f'#define A B\n#define B {base}\ninherit A;', 'inherit')
        for base in EXCLUDED_LITERAL_BASES:
            self.check_case(f'#define BASE "{base}"\ninherit BASE;', 'inherit')

    def test_include_aliases(self):
        for target, use, expected in (('set', 'void A() {}', 'header'),
                                       ('create', 'void A() {}', 'header'),
                                       ('inherit', 'A NPC;', 'inherit'),
                                       ('NPC', 'inherit A;', 'inherit')):
            self.check_case('#include "a.h"\n' + use, expected, {'d/test/a.h': f'#define A {target}\n'})

    def test_nested_include_chains(self):
        for target, use, expected in (('set', 'void A() {}', 'header'),
                                       ('create', 'void A() {}', 'header'),
                                       ('inherit', 'A NPC;', 'inherit'),
                                       ('NPC', 'inherit A;', 'inherit')):
            self.check_case('#include "a.h"\n' + use, expected,
                            {'d/test/a.h': '#include "b.h"\n', 'd/test/b.h': f'#define A B\n#define B {target}\n'})

    def test_cross_file_definition_and_usage(self):
        for target, use, expected in (('set', 'void A() {}', 'header'),
                                       ('create', 'void A() {}', 'header'),
                                       ('inherit', 'A NPC;', 'inherit')):
            self.check_case(f'#define A {target}\n#include "a.h"', expected, {'d/test/a.h': use})
            self.check_case('#include "a.h"\n#include "b.h"', expected,
                            {'d/test/a.h': use, 'd/test/b.h': f'#define A {target}\n'})

    def test_include_cycle_back_to_root_preserves_include_veto(self):
        for header in ('#include "room.c"\n', '#include "a.h"\n'):
            text = header + room(self.BODY)
            deps = {'d/test/room.c': Source('d/test/room.c', text.encode()),
                    'd/test/a.h': Source('d/test/a.h', b'#include "room.c"\n')}
            obj, findings = extract(text, dependencies=deps)
            self.assertFalse(obj['supported_candidate'])
            self.assertEqual('OUT_OF_SCOPE', obj['status'])
            self.assertEqual([], obj['facts'])
            self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(findings))

    def test_conditional_aliases_are_not_evaluated(self):
        for target, use, expected in (('set', 'void A() {}', 'header'), ('inherit', 'A NPC;', 'inherit')):
            self.check_case('#include "a.h"\n' + use, expected,
                            {'d/test/a.h': f'#if FLAG\n#define A {target}\n#endif\n'})
            obj, findings = extract(f'#if FLAG\n#define A {target}\n#endif\n' + use + room(self.BODY))
            self.assertFalse(obj['supported_candidate'])
            self.assertEqual([], obj['facts'])
            self.assertIn('DRIVER_SEMANTICS_UNKNOWN', codes(findings))

    def test_undef_and_redefinition_do_not_erase_hazards(self):
        # P2F10 explicitly makes ambiguous/cyclic signatures inadmissible.
        self.check_case('#define A set\n#undef A\n#define A helper\nvoid A() {}', 'inherit')
        self.check_case('#define A inherit\n#undef A\nA NPC;', 'inherit')

    def test_cycles_terminate_conservatively(self):
        self.check_case('#define A B\n#define B A\nvoid A() {}', 'inherit')
        self.check_case('#define A B\n#define B A\ninherit A;', 'inherit')
        self.check_case('#define A B\n#define B A\n', 'safe')
        self.check_case('#define A B\n#define B A\n#define B set\nvoid A() {}', 'inherit')

    def test_function_like_and_complex_macros(self):
        for target in ('set', 'create'):
            self.check_case(f'#define A(...) {target}(__VA_ARGS__)\nvoid A() {{}}', 'inherit')
            self.check_case(f'#define A {target}(string key,mixed value)\nvoid A {{}}', 'inherit')
            self.check_case(f'#define A B\n#define B(...) {target}(__VA_ARGS__)\nvoid A() {{}}', 'inherit')
        self.check_case('#define I(x) inherit x\nI(NPC);', 'inherit')
        self.check_case('#define BASE(x) x\ninherit BASE(NPC);', 'inherit')
        self.check_case('#define NAME(x) x\nvoid NAME(set) {}', 'inherit')
        self.check_case('#define NAME se ## t\nvoid NAME() {}', 'inherit')
        self.check_case('#define DECL(x) x\nDECL(inherit NPC);', 'inherit')

    def test_unused_critical_aliases(self):
        self.check_case('#define S set\n#define C create\n#define I inherit\n#define BASE NPC\n', 'safe')

    def test_harmless_helper_and_color_aliases(self):
        # P2F29: helper metadata is not an authored function-name proof.
        self.check_case('#define H helper\n#define COLOR red\nvoid H() {}', 'header')
        self.check_case('#define H J\n#define J helper\nvoid H() {}', 'header')

    def test_opaque_and_body_mentions_are_not_definitions(self):
        self.check_case('#define S set\n#define I inherit\n'
                        '// void S() {} I NPC;\n/* void S() {} I NPC; */\n'
                        'string text = "void S() {} I NPC;";\n'
                        'string help = @TEXT\nvoid S() {} I NPC;\nTEXT;\n'
                        '#echo void S() {} I NPC; " /*\n'
                        'void helper() { S("x",1); I; }', 'inherit')  # P2F10: actual inherit alias use.
        self.check_case('// #define S set\n/* #define S set */\n'
                        'string text = "#define S set";\n'
                        'string help = @TEXT\n#define S set\nTEXT;\n'
                        '#echo #define S set\nvoid S() {}', 'safe')

    def test_dir_aliases_never_normalize(self):
        for prefix in ('#define D __DIR__\n', '#define D A\n#define A __DIR__\n', '#include "a.h"\n'):
            obj, findings = extract(prefix + room('set("exits",(["east":D "east"]));'),
                                    dependencies={'d/test/a.h': Source('d/test/a.h', b'#define D __DIR__\n')})
            self.assertTrue(obj['supported_candidate'])
            self.assertEqual([], fields(obj, 'exit'))
            self.assertIn('DYNAMIC_EXPRESSION', codes(findings))

    def test_direct_critical_define_undef_policy(self):
        for directive in ('define', 'undef'):
            for name in ('set', 'create'):
                self.check_case(f'#{directive} {name}\n',
                                'header' if (directive, name) == ('define', 'create') else 'function')
            self.check_case(f'#{directive} ROOM\n', 'inherit')
            obj, _ = extract(f'#{directive} __DIR__\n' + room(self.BODY))
            self.assertTrue(fields(obj, 'short'))
            self.assertFalse(fields(obj, 'exit'))

    def test_summary_shape_and_reachability(self):
        from tools.migration.room_extractor import MacroSummary
        macros = MacroSummary()
        text = '#define A B\n#define B set\n#define H helper\n#define F(x) create(x)\n#define O (helper)\n'
        text += '#define D __DIR__\n#define R ROOM\n#define L "/std/item"\n'
        for token in lex(Source('a.h', text.encode())):
            macros.add(token)
        self.assertEqual(({'A', 'B', 'set'}, False), macros.reach('A'))
        self.assertFalse(macros.definitions['O'][0][0])
        self.assertTrue(macros.definitions['F'][0][0])
        for name, target in [('F', 'create'), ('D', '__DIR__'), ('R', 'ROOM'), ('L', '/std/item')]:
            self.assertIn(target, macros.reach(name)[0])

    def test_directive_splices_comments_and_newlines(self):
        self.check_case('/* prefix */ #define A B\\\n\n#define B /* gap */ set\nvoid A() {}')
        self.check_case('#de\\\nfine S se\\\nt\nvoid S() {}')

    def test_real_cli_matrix(self):
        cases = [
            ('set', '#define S set\nvoid S() {}', {}, 'header'),
            ('create', '#define C create\nvoid C() {}', {}, 'header'),
            ('inherit', '#define I inherit\nI NPC;', {}, 'inherit'),
            ('npc', '#define BASE NPC\ninherit BASE;', {}, 'inherit'),
            ('item', '#define BASE ITEM\ninherit BASE;', {}, 'inherit'),
            ('chain-set', '#define A B\n#define B set\nvoid A() {}', {}, 'header'),
            ('chain-create', '#define A B\n#define B create\nvoid A() {}', {}, 'header'),
            ('chain-inherit', '#define A B\n#define B inherit\nA NPC;', {}, 'inherit'),
            ('included-set', '#include "a.h"\nvoid A() {}', {'a.h': '#define A set\n'}, 'header'),
            ('included-create', '#include "a.h"\nvoid A() {}', {'a.h': '#define A create\n'}, 'header'),
            ('included-inherit', '#include "a.h"\nA NPC;', {'a.h': '#define A inherit\n'}, 'inherit'),
            ('nested', '#include "a.h"\nvoid A() {}', {'a.h': '#include "b.h"\n', 'b.h': '#define A B\n#define B set\n'}, 'header'),
            ('unused', '#define S set\n', {}, 'safe'),
            ('helper', '#define H helper\nvoid H() {}', {}, 'header'),
        ]
        for name, prefix, deps, expected in cases:
            for newline in ('\n', '\r\n'):
                with self.subTest(name=name, newline=repr(newline)), tempfile.TemporaryDirectory() as tmp:
                    source, output = Path(tmp)/'source', Path(tmp)/'output'
                    (source/'d/test').mkdir(parents=True)
                    for path, text in {'room.c': prefix + '\n' + room(self.BODY), **deps}.items():
                        (source/'d/test'/path).write_bytes(text.replace('\n', newline).encode())
                    result = subprocess.run([sys.executable, '-m', 'tools.migration.cli', '--source-root', str(source),
                                             '--output-root', str(output)], cwd=REPOSITORY, capture_output=True)
                    self.assertEqual(0, result.returncode, result.stderr)
                    document = json.loads((output/'static-rooms.json').read_bytes())
                    obj = next(o for o in document['objects'] if o['source_path'] == 'd/test/room.c')
                    self.assertEqual(expected not in {'inherit', 'header'}, obj['supported_candidate'])
                    self.assertEqual('OUT_OF_SCOPE' if expected in {'inherit', 'header'} else 'PARTIAL', obj['status'])
                    self.assertEqual([] if expected in {'inherit', 'header'} else ['inherit'] if expected == 'function'
                                     else ['inherit', 'short', 'exit'], [f['field'] for f in obj['facts']])


class P2F10RegressionTests(unittest.TestCase):
    BODY = ('set("short","safe");set("name","name");set("long","text");'
            'set("outdoors",1);set("indoors",0);set("no_clean_up",1);set("no_fight",0);'
            'set("exits",(["east":__DIR__"east"]));')
    FIELDS = ['inherit', 'short', 'name', 'long', 'outdoors', 'indoors', 'no_clean_up', 'no_fight', 'exit']

    def check(self, definitions='', declaration='', body='', expected='OUT_OF_SCOPE',
              signature='void create()', dependencies=None, conditional_root=False, cleared_admission=False):
        text = definitions + '\ninherit ROOM;\n' + declaration + '\n' + signature + '{' + self.BODY + body + '}\n'
        result = None
        for newline in ('\n', '\r\n'):
            raw = text.replace('\n', newline).encode()
            deps = {p: Source(p, content.replace('\n', newline).encode()) for p, content in (dependencies or {}).items()}
            with self.subTest(newline=repr(newline), definitions=definitions, body=body):
                obj, findings = extract(raw, dependencies=deps)
                result = obj
                self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(findings))
                self.assertEqual(expected != 'OUT_OF_SCOPE', obj['supported_candidate'])
                self.assertEqual('OUT_OF_SCOPE' if expected == 'OUT_OF_SCOPE' else 'PARTIAL', obj['status'])
                wanted = [] if expected == 'OUT_OF_SCOPE' else ['inherit'] if expected == 'STATE' else self.FIELDS
                self.assertEqual(wanted, [f['field'] for f in obj['facts']])
                self.assertEqual([] if conditional_root or cleared_admission else ['ROOM'], [d['symbol'] for d in obj['direct_inherits']])
                if cleared_admission:
                    self.assertEqual([], obj['category_candidates'])
                for item in obj['direct_inherits'] + obj['facts'] + findings:
                    p = item['provenance']
                    self.assertEqual(hashlib.sha256(raw).hexdigest(), p['source_sha256'])
                    self.assertEqual(p['raw'].encode(), raw[p['byte_start']:p['byte_end_exclusive']])
        return result

    def test_safe_return_type_alias(self):
        self.check('#define INT int', 'INT helper(){return 1;}', expected='SAFE')

    def test_complex_return_prefix(self):
        self.check('#define TYPE int; inherit NPC; int', 'TYPE helper(){return 1;}', cleared_admission=True)

    def test_name_aliases(self):
        for name in ('helper', 'set', 'create'):
            self.check(f'#define H {name}', 'void H(){}', cleared_admission=True)

    def test_safe_parameter_type(self):
        self.check('#define INT int', 'void helper(INT x){}', expected='SAFE')

    def test_signature_modifiers_parameter_names_and_defaults(self):
        self.check('#define MOD nomask\n#define ARG value', 'MOD void helper(int ARG){}', expected='SAFE')
        for signature in ('BAD void helper(){}', 'void helper(int BAD){}',
                          'void helper(int x=BAD){}', 'void helper(int x BAD string y){}'):
            self.check('#define BAD ){} inherit NPC; void tail(', signature,
                       cleared_admission=signature == 'BAD void helper(){}')

    def test_other_body_semicolon_is_structural(self):
        self.check('#define RET return;', 'void helper(){RET}')

    def test_ambiguous_sibling_definitions(self):
        self.check('#include "a.h"\n#include "b.h"', body='M;', dependencies={
            'd/test/a.h':'#define M 1\n', 'd/test/b.h':'#define M 2\n'})

    def test_compound_literal_alias_remains_unknown(self):
        # The bounded classifier does not evaluate ANSI-like concatenations.
        self.check('#define ESC "escape"\n#define COLOR ESC+"[31m"', 'void helper(){write(COLOR);}')

    def test_inert_function_like_chain_without_substitution(self):
        self.check('#define ONE(x) N\n#define N 1', 'int helper(){return ONE(0);}', expected='SAFE')

    def test_parameter_structure_uncertain(self):
        self.check('#define P int x, string y', 'void helper(P){}')

    def test_parameter_injects_set(self):
        self.check('#define P ){} mixed set(string k,mixed v){return 0;} void tail(', 'void helper(P){}')

    def test_parameter_injects_create(self):
        self.check('#define P ){} void create(){} void tail(', 'void helper(P){}')

    def test_parameter_injects_inherit(self):
        self.check('#define P ){} inherit NPC; void tail(', 'void helper(P){}')

    def test_between_parameter_close_and_body(self):
        self.check('#define END ; inherit NPC; void tail()', 'void helper() END {}', cleared_admission=True)
        # P2F29 also clears helper metadata when body adjacency is unresolved.
        self.check('#define END ; inherit NPC; void tail()', signature='void create() END', cleared_admission=True)

    def test_function_like_signature(self):
        self.check('#define P(x) x', 'void helper(P(set)){}')
        self.check('#define P() ){} void set(){} void tail(', 'void helper(P()){}')

    def test_chained_signature(self):
        self.check('#define A B\n#define B ){} void set(){} void tail(', 'void helper(A){}')

    def test_cyclic_signature(self):
        self.check('#define A B\n#define B A', 'void helper(A){}')

    def test_create_set_alias(self):
        self.check('#define M set', body='M("short","other");', expected='STATE')

    def test_create_add_alias(self):
        self.check('#define M add', body='M("exits/east","/other");', expected='STATE')

    def test_create_delete_alias(self):
        self.check('#define M delete', body='M("exits/east");', expected='STATE')

    def test_create_create_alias(self):
        self.check('#define M create', body='M();', expected='STATE')

    def test_create_inherit_alias(self):
        self.check('#define M inherit', body='M NPC;')

    def test_body_closes_brace(self):
        self.check('#define M }', body='M;')

    def test_body_opens_brace(self):
        self.check('#define M {', body='M;')

    def test_body_semicolon_or_declaration(self):
        for replacement in (';', 'int x;', 'set("short","other");'):
            self.check('#define M ' + replacement, body='M;')

    def test_body_injects_function(self):
        self.check('#define M } mixed set(string k,mixed v){return 0;} void tail(){', body='M;')

    def test_body_injects_inherit(self):
        self.check('#define M } inherit NPC; void tail(){', body='M;')

    def test_function_like_body(self):
        self.check('#define M(x) set(x)', body='M("short");')
        self.check('#define DECL(x) x', body='DECL(set("short","other"));')
        self.check('#define WRAP(x) } x {', body='WRAP(inherit NPC;);')

    def test_body_chains(self):
        for target in ('set', 'add', 'delete', 'create'):
            self.check(f'#define A B\n#define B {target}', body='A("short","other");', expected='STATE')
        self.check('#define A B\n#define B inherit', body='A NPC;')
        self.check('#define A B\n#define B } void tail(){', body='A;')

    def test_body_cycle(self):
        self.check('#define A B\n#define B A', body='A;')
        self.check('#define A B\n#define B A', expected='SAFE')

    def test_other_body_constants(self):
        self.check('#define ONE 1\n#define LABEL "text"', 'int helper(){return ONE;} int other(){return LABEL!=0;}', expected='SAFE')

    def test_other_body_helper_alias(self):
        self.check('#define H helper', 'void helper(){} void other(){H();}', expected='SAFE')

    def test_other_body_escape(self):
        self.check('#define M } void tail(){', 'void helper(){M}')

    def test_other_body_hidden_inherit(self):
        self.check('#define M } inherit NPC; void tail(){', 'void helper(){M}')

    def test_other_body_hidden_functions(self):
        for name in ('set', 'create'):
            self.check(f'#define M }} void {name}(){{}} void tail(){{', 'void helper(){M}')

    def test_header_definition_root_use(self):
        self.check('#include "a.h"', 'void helper(P){}', dependencies={'d/test/a.h':'#define P ){} void set(){} void tail(\n'})
        self.check('#include "a.h"', body='M("short","other");', expected='STATE', dependencies={'d/test/a.h':'#define M set\n'})

    def test_root_definition_header_use(self):
        self.check('#define P ){} void set(){} void tail(\n#include "a.h"', dependencies={'d/test/a.h':'void helper(P){}\n'})

    def test_nested_definition_root_use(self):
        self.check('#include "a.h"', 'void helper(P){}', dependencies={'d/test/a.h':'#include "sub/b.h"\n','d/test/sub/b.h':'#define P ){} void set(){} void tail(\n'})

    def test_conditional_definitions(self):
        self.check('#include "a.h"', body='M("short","other");', expected='STATE', dependencies={'d/test/a.h':'#if FLAG\n#define M set\n#endif\n'})
        self.check('#if FLAG\n#define M set\n#endif', body='M("short","other");', conditional_root=True)

    def test_undef_redefinitions(self):
        self.check('#define M set\n#undef M', body='M("short","other");', expected='STATE')
        self.check('#define M set\n#undef M\n#define M helper', body='M("short","other");')

    def test_comment_prefix_and_continuations(self):
        self.check('/* prefix */ #define M ad\\\nd', body='M("short","other");', expected='STATE')
        self.check('#define M /* first\nsecond */ delete', body='M("exits/east");', expected='STATE')

    def test_opaque_negatives(self):
        self.check('#define BAD } inherit NPC; {\n#echo BAD #define M set " /*',
                   'void helper(){/* BAD */ string x="BAD";string y=@TXT\nBAD\nTXT;\n// BAD\n}',
                   body='/* BAD */ // BAD\n', expected='SAFE')

    def test_authored_provenance_and_no_synthetic_inherit(self):
        obj = self.check('#define BAD inherit NPC;', body='BAD;')
        self.assertEqual('inherit ROOM;', obj['direct_inherits'][0]['provenance']['raw'])
        self.assertEqual([], obj['facts'])

    def test_contained_object_mutator_calls(self):
        for replacement in ('set("short","other")', 'add("exits/east","/other")', 'delete("exits/east")'):
            self.check('#define M ' + replacement, body='M;', expected='STATE')

    def test_state_hazards_before_after_and_nested(self):
        for use in ('M("short","other");', 'if(0){M("short","other");}', 'helper(M("short","other"));'):
            self.check('#define M set', body=use, expected='STATE')
        obj, _ = extract('#define M set\n' + room('M("short","other");' + self.BODY))
        self.assertEqual(['inherit'], [f['field'] for f in obj['facts']])

    def test_parameter_independent_function_like(self):
        self.check('#define ONE(x) 1', 'int helper(){return ONE(0);}', body='ONE(0);', expected='SAFE')
        self.check('#define M(x) set("short","other")', body='M(0);', expected='STATE')

    def test_safe_constants_inside_create(self):
        self.check('#define ONE 1\n#define LABEL "text"', body='helper(ONE,LABEL);', expected='SAFE')

    def test_contained_mutator_in_other_body(self):
        self.check('#define M set("short","other")', 'void helper(){M;}', expected='SAFE')

    def test_source_backed_mapping_mutators(self):
        for name in ('_set', '_delete', 'map_delete', 'set_default_object'):
            self.check('#define M ' + name, body='M(query_entire_dbase(),"short",0);', expected='STATE')

    def test_pasting_stringification_and_unknown_calls(self):
        for replacement in ('se ## t', '# x', 'helper()', '(1+2)'):
            self.check('#define M ' + replacement, body='M;')

    def test_sibling_headers_and_cycle(self):
        self.check('#include "a.h"\n#include "b.h"', dependencies={
            'd/test/a.h':'#define P Q\n#include "b.h"\n',
            'd/test/b.h':'#include "a.h"\n#define Q ){} void set(){} void tail(\nvoid helper(P){}\n'})

    def test_unused_dangerous_definitions(self):
        self.check('#define S set\n#define I inherit\n#define BAD } inherit NPC; {', expected='SAFE')

    def test_effect_classes_and_cycle_termination(self):
        from tools.migration.room_extractor import MacroEffect, MacroSummary
        summary = MacroSummary()
        source = ('#define INT int\n#define ONE 1\n#define M set("short","other")\n'
                  '#define BAD } inherit NPC; {\n#define F(x) x\n#define A B\n#define B A\n')
        for token in lex(Source('macros.h', source.encode())):
            summary.add(token)
        for name, expected in [('INT',MacroEffect.INERT),('ONE',MacroEffect.INERT),
                               ('M',MacroEffect.CREATE_STATE_HAZARD),('BAD',MacroEffect.STRUCTURAL_BOUNDARY_HAZARD),
                               ('F',MacroEffect.UNKNOWN),('A',MacroEffect.UNKNOWN)]:
            self.assertEqual(expected, summary.effect(name))

    def test_real_cli_matrix(self):
        cases = [('parameter','#define P ){} void set(){} void tail(\n','void helper(P){}\n','',False),
                 ('set','#define M set\n','','M("short","other");',True),
                 ('add','#define M add\n','','M("exits/east","/other");',True),
                 ('delete','#define M delete\n','','M("exits/east");',True),
                 ('escape','#define M } void set(){} void tail(){\n','','M;',False),
                 ('inherit','#define M inherit\n','','M NPC;',False),
                 ('function','#define M(x) set(x)\n','','M("short");',False),
                 ('chain','#define M N\n#define N add\n','','M("short",1);',True),
                 ('cycle','#define M N\n#define N M\n','','M;',False)]
        for name, definition, declaration, body, candidate in cases:
            for layout in ('inline', 'header', 'nested'):
                for newline in ('\n','\r\n'):
                    with self.subTest(name=name,layout=layout,newline=repr(newline)), tempfile.TemporaryDirectory() as tmp:
                        source, output = Path(tmp)/'source', Path(tmp)/'output'
                        (source/'d').mkdir(parents=True)
                        files={'d/a.h':definition} if layout=='header' else {'d/a.h':'#include "b.h"\n','d/b.h':definition} if layout=='nested' else {}
                        files['d/room.c']=(definition if layout=='inline' else '#include "a.h"\n')+'inherit ROOM;\n'+declaration+'void create(){'+self.BODY+body+'}\n'
                        for path,text in files.items():(source/path).write_bytes(text.replace('\n',newline).encode())
                        result=subprocess.run([sys.executable,'-m','tools.migration.cli','--source-root',str(source),'--output-root',str(output)],cwd=REPOSITORY,capture_output=True)
                        self.assertEqual(0,result.returncode,result.stderr)
                        doc=json.loads((output/'static-rooms.json').read_bytes())
                        obj=next(o for o in doc['objects'] if o['source_path']=='d/room.c')
                        self.assertEqual(candidate,obj['supported_candidate'])
                        self.assertEqual(['inherit'] if candidate else [],[f['field'] for f in obj['facts']])


class P2F11RegressionTests(unittest.TestCase):
    FIRST = 'set("short","safe");\n'
    REST = ('set("name","name");set("long","text");set("outdoors",1);set("indoors",0);'
            'set("no_clean_up",1);set("no_fight",0);set("exits",(["east":__DIR__"east"]));\n')
    FIELDS = ['inherit', 'short', 'name', 'long', 'outdoors', 'indoors', 'no_clean_up', 'no_fight', 'exit']
    DIRECTIVES = {
        'define': '#define UNUSED 1\n', 'undef': '#undef UNUSED\n',
        'pragma': '#pragma warnings\n', 'echo': '#echo raw ; { #define set x " /* \\\n',
        'empty': '#include "empty.h"\n', 'macro': '#include "macro.h"\n',
        'unknown': '#unsupported message\n',
    }
    HEADERS = {'d/test/empty.h': '', 'd/test/macro.h': '#define UNUSED 1\n'}
    PLACEMENTS = ('start', 'middle', 'tail', 'arguments', 'before-semicolon', 'receiver',
                  'mapping', 'nested', 'helper-tail', 'top-level')

    def source(self, directive, placement):
        body, extra, prefix = self.FIRST + self.REST, '', ''
        if placement == 'start': body = directive + body
        elif placement == 'middle': body = self.FIRST + directive + self.REST
        elif placement == 'tail': body += directive
        elif placement == 'arguments': body += 'set(\n' + directive + '"short","other");\n'
        elif placement == 'before-semicolon': body += 'set("short","other")\n' + directive + ';\n'
        elif placement == 'receiver': body += 'set\n' + directive + '("short","other");\n'
        elif placement == 'mapping': body += 'set("exits",([\n' + directive + '"west":__DIR__"west"]));\n'
        elif placement == 'nested': body += 'if(flag){\n' + directive + 'helper();\n}\n'
        elif placement == 'helper-tail': extra = 'void helper(){\n' + directive + '}\n'
        elif placement == 'top-level': prefix = directive
        else: raise AssertionError(placement)
        return prefix + room(body, extra)

    def check(self, text, expected='FULL', dependencies=None):
        for nl in ('\n', '\r\n'):
            raw = text.replace('\n', nl).encode()
            deps = {p: Source(p, s.replace('\n', nl).encode()) for p, s in (dependencies or {}).items()}
            with self.subTest(newline=repr(nl)):
                obj, findings = extract(raw, dependencies=deps)
                self.assertEqual(expected != 'OOS', obj['supported_candidate'])
                self.assertEqual('OUT_OF_SCOPE' if expected == 'OOS' else 'PARTIAL', obj['status'])
                self.assertEqual([] if expected == 'OOS' else ['inherit'] if expected == 'STATE' else self.FIELDS,
                                 [f['field'] for f in obj['facts']])
                self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(findings))
                self.assertEqual(['ROOM'], [d['symbol'] for d in obj['direct_inherits']])
                for item in obj['facts'] + obj['direct_inherits'] + findings:
                    p = item['provenance']
                    self.assertEqual(hashlib.sha256(raw).hexdigest(), p['source_sha256'])
                    self.assertEqual('d/test/room.c', p['source_path'])
                    self.assertEqual(raw[p['byte_start']:p['byte_end_exclusive']], p['raw'].encode())
                if expected == 'STATE':
                    self.assertTrue(any(f['code'] == 'UNSUPPORTED_CONSTRUCT' and f['prevents_supported_consumption']
                                        and f['provenance']['scope'] == 'create' for f in findings))

    def test_define_start(self):
        self.check(self.source(self.DIRECTIVES['define'], 'start'))

    def test_define_middle(self):
        self.check(self.source(self.DIRECTIVES['define'], 'middle'))

    def test_define_tail(self):
        self.check(self.source(self.DIRECTIVES['define'], 'tail'))

    def test_undef_tail(self):
        self.check(self.source(self.DIRECTIVES['undef'], 'tail'))

    def test_pragma_tail(self):
        self.check(self.source(self.DIRECTIVES['pragma'], 'tail'))

    def test_echo_tail(self):
        self.check(self.source(self.DIRECTIVES['echo'], 'tail'))

    def test_empty_include_tail(self):
        self.check(self.source(self.DIRECTIVES['empty'], 'tail'), 'STATE', self.HEADERS)

    def test_macro_only_include_tail(self):
        self.check(self.source(self.DIRECTIVES['macro'], 'tail'), 'STATE', self.HEADERS)

    def test_unknown_directive_tail(self):
        self.check(self.source(self.DIRECTIVES['unknown'], 'tail'), 'STATE')

    def test_directive_inside_set_arguments(self):
        self.check(self.source(self.DIRECTIVES['define'], 'arguments'), 'STATE')

    def test_directive_between_call_and_semicolon(self):
        self.check(self.source(self.DIRECTIVES['pragma'], 'before-semicolon'), 'STATE')

    def test_directive_between_receiver_and_opening(self):
        self.check(self.source(self.DIRECTIVES['define'], 'receiver'), 'STATE')

    def test_directive_inside_mapping(self):
        self.check(self.source(self.DIRECTIVES['define'], 'mapping'), 'STATE')

    def test_directive_inside_nested_call(self):
        self.check(room(self.FIRST + 'helper(\n#define UNUSED 1\nset("short","other"));\n' + self.REST), 'STATE')

    def test_nested_unsupported_block(self):
        self.check(self.source(self.DIRECTIVES['pragma'], 'nested'))

    def test_helper_tail_control(self):
        self.check(self.source(self.DIRECTIVES['define'], 'helper-tail'))

    def test_top_level_control(self):
        self.check(self.source(self.DIRECTIVES['define'], 'top-level'))

    def test_comment_prefixed_start_middle_tail(self):
        for place in ('start', 'middle', 'tail'):
            self.check(self.source('/* prefix */ #define UNUSED 1\n', place))

    def test_multiline_comment_start_middle_tail(self):
        for place in ('start', 'middle', 'tail'):
            self.check(self.source('#define UNUSED /* first\nsecond */ 1\n', place))

    def test_continued_keyword_start_middle_tail(self):
        for place in ('start', 'middle', 'tail'):
            self.check(self.source('#de\\\nfine UNUSED 1\n', place))

    def test_echo_payload_opaque_and_next_line_independent(self):
        self.check(self.source('#echo text ; { #define set x " /* \\\n#define UNUSED 1\n', 'tail'))
        self.check(self.source('#echo text ; { #define set x " /* \\\n#define ROOM NPC\n', 'tail'), 'OOS')

    def test_true_unfinished_runtime_statement(self):
        for prefix in ('', '#define UNUSED 1\n'):
            for nl in ('\n', '\r\n'):
                obj, findings = extract(room(prefix + 'set("short","unfinished")').replace('\n', nl))
                self.assertEqual('QUARANTINED', obj['status'])
                self.assertEqual([], obj['facts'])
                self.assertTrue(any(f['reason'] == 'unterminated create statement' for f in findings))

    def test_true_lexical_and_delimiter_errors(self):
        for broken in ('set("short",', 'set("short","unterminated);', '/* unclosed', 'set("short","x"];'):
            for nl in ('\n', '\r\n'):
                obj, findings = extract(room('#define UNUSED 1\n' + broken).replace('\n', nl))
                self.assertEqual('QUARANTINED', obj['status'])
                self.assertEqual([], obj['facts'])
                self.assertIn('SOURCE_SYNTAX_ERROR', codes(findings))

    def test_unfinished_runtime_before_tail_directive(self):
        for name in ('define', 'undef', 'pragma', 'echo'):
            for nl in ('\n', '\r\n'):
                obj, findings = extract(room('set("short","unfinished")\n' + self.DIRECTIVES[name]).replace('\n', nl))
                self.assertEqual('QUARANTINED', obj['status'])
                self.assertEqual([], obj['facts'])
                error = next(f for f in findings if f['code'] == 'SOURCE_SYNTAX_ERROR')
                self.assertEqual('unterminated create statement', error['reason'])
                self.assertEqual('set("short","unfinished")', error['provenance']['raw'])

    def test_interrupted_tail_include_may_supply_terminator(self):
        self.check(room(self.FIRST + self.REST + 'set("short","other")\n#include "end.h"\n'),
                   'STATE', {'d/test/end.h': ';'})

    def test_include_runtime_calls(self):
        for statement in ('set("short","other");', 'add("exits/east","/other");',
                          'delete("exits/east");', 'helper();'):
            self.check(self.source('#include "runtime.h"\n', 'tail'), 'STATE', {'d/test/runtime.h': statement})

    def test_include_prototype_and_data(self):
        for content in ('int helper();', 'int value=1;'):
            self.check(self.source('#include "safe.h"\n', 'middle'), 'STATE', {'d/test/safe.h': content})

    def test_missing_include(self):
        self.check(self.source('#include "missing.h"\n', 'tail'), 'OOS')

    def test_malformed_include_dependency(self):
        self.check(self.source('#include "bad.h"\n', 'tail'), 'OOS', {'d/test/bad.h': 'void broken(){'})

    def test_include_inherit_stronger_hazard(self):
        self.check(self.source('#include "bad.h"\n', 'tail'), 'OOS', {'d/test/bad.h': 'inherit NPC;'})

    def test_nested_include(self):
        self.check(self.source('#include "a.h"\n', 'tail'), 'STATE',
                   {'d/test/a.h':'#include "sub/b.h"\n', 'd/test/sub/b.h':'delete("exits/east");'})

    def test_nested_block_include_and_unknown(self):
        self.check(self.source(self.DIRECTIVES['empty'], 'nested'), 'STATE', self.HEADERS)
        self.check(self.source(self.DIRECTIVES['unknown'], 'nested'), 'STATE')

    def test_root_conditionals_still_out_of_scope(self):
        for name in ('if FLAG', 'ifdef FLAG', 'ifndef FLAG', 'elif FLAG', 'else', 'endif'):
            obj, findings = extract(self.source('#' + name + '\n', 'tail'))
            self.assertFalse(obj['supported_candidate'])
            self.assertEqual('OUT_OF_SCOPE', obj['status'])
            self.assertEqual([], obj['facts'])
            self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(findings))

    def test_existing_macro_hazards_remain_stronger(self):
        self.check(self.source('#define UNUSED 1\n#define ROOM NPC\n', 'tail'), 'OOS')
        text = self.source('#define BAD } inherit NPC; {\n', 'tail').replace('set("short","safe");', 'BAD;')
        obj, _ = extract(text)
        self.assertFalse(obj['supported_candidate'])
        self.assertEqual('OUT_OF_SCOPE', obj['status'])
        self.assertEqual([], obj['facts'])

    def test_provenance_no_included_facts(self):
        self.check(self.source('#include "runtime.h"\n', 'tail'), 'STATE',
                   {'d/test/runtime.h':'set("short","injected");set("exits",(["west":"/injected"]));'})

    def test_early_and_late_facts_suppressed_together(self):
        self.check(room(self.FIRST + 'set(\n#pragma warnings\n"name","interrupted");\n' + self.REST), 'STATE')

    def test_directive_position_matrix(self):
        for name, directive in self.DIRECTIVES.items():
            for place in self.PLACEMENTS:
                expected = ('FULL' if place in ('helper-tail', 'top-level') else
                            'STATE' if name in ('empty', 'macro', 'unknown') or
                            place in ('arguments', 'before-semicolon', 'receiver', 'mapping') else 'FULL')
                with self.subTest(name=name, placement=place):
                    self.check(self.source(directive, place), expected, self.HEADERS)

    def test_original_reproducer_real_cli(self):
        for nl in ('\n', '\r\n'):
            with tempfile.TemporaryDirectory() as tmp:
                root, output = Path(tmp)/'source', Path(tmp)/'output'
                (root/'d').mkdir(parents=True)
                (root/'d/room.c').write_bytes(room('set("short","authored");\n#define UNUSED 1\n').replace('\n', nl).encode())
                result = subprocess.run([sys.executable, '-m', 'tools.migration.cli', '--source-root', str(root),
                                         '--output-root', str(output)], cwd=REPOSITORY, capture_output=True)
                self.assertEqual(0, result.returncode, result.stderr)
                document = json.loads((output/'static-rooms.json').read_bytes())
                obj = document['objects'][0]
                self.assertTrue(obj['supported_candidate'])
                self.assertEqual('PARTIAL', obj['status'])
                self.assertEqual(['inherit', 'short'], [f['field'] for f in obj['facts']])
                self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(document['findings']))


class P2F12RegressionTests(unittest.TestCase):
    # Handwritten macro/literal/malformed triplets; no generated expansion oracle.
    CASES = {
        '{': ('inherit ROOM;\nvoid create() M\nset("short","x");\n}\n',
              'inherit ROOM;\nvoid create() {\nset("short","x");\n}\n',
              'inherit ROOM;\nvoid create()\nset("short","x");\n}\n'),
        '}': ('inherit ROOM;\nvoid create() {\nset("short","x");\nM\n',
              'inherit ROOM;\nvoid create() {\nset("short","x");\n}\n',
              'inherit ROOM;\nvoid create() {\nset("short","x");\n'),
        '(': ('inherit ROOM;\nvoid create() { set M "short","x"); }\n',
              'inherit ROOM;\nvoid create() { set("short","x"); }\n',
              'inherit ROOM;\nvoid create() { set "short","x"); }\n'),
        ')': ('inherit ROOM;\nvoid create() { set("short","x" M; }\n',
              'inherit ROOM;\nvoid create() { set("short","x"); }\n',
              'inherit ROOM;\nvoid create() { set("short","x"; }\n'),
        '[': ('inherit ROOM;\nvoid create() { set("exits", (M "east":"/d/test/room",])); }\n',
              'inherit ROOM;\nvoid create() { set("exits", (["east":"/d/test/room",])); }\n',
              'inherit ROOM;\nvoid create() { set("exits", ("east":"/d/test/room",])); }\n'),
        ']': ('inherit ROOM;\nvoid create() { set("exits", (["east":"/d/test/room",M)); }\n',
              'inherit ROOM;\nvoid create() { set("exits", (["east":"/d/test/room",])); }\n',
              'inherit ROOM;\nvoid create() { set("exits", (["east":"/d/test/room",)); }\n'),
    }

    def check(self, text, expected, dependencies=None):
        for newline in ('\n', '\r\n'):
            raw = text.replace('\n', newline).encode('utf-8')
            deps = {p: Source(p, t.replace('\n', newline).encode('utf-8'))
                    for p, t in (dependencies or {}).items()}
            with self.subTest(newline=repr(newline), source=text):
                r, fs = extract(raw, paths={'d/test/room.c'}, dependencies=deps)
                self.assertEqual(expected, r['status'])
                if expected == 'OUT_OF_SCOPE':
                    self.assertFalse(r['supported_candidate'])
                    self.assertEqual([], r['facts'])
                    self.assertEqual([], r['direct_inherits'])
                    self.assertEqual({'OUT_OF_SCOPE', 'DRIVER_SEMANTICS_UNKNOWN'}, codes(fs))
                    self.assertTrue(all(f['provenance']['raw'] in ('M', 'A', 'OPEN', 'DROP', 'ONE') for f in fs))
                elif expected == 'QUARANTINED':
                    self.assertEqual([], r['facts'])
                    self.assertIn('SOURCE_SYNTAX_ERROR', codes(fs))
                    # The original failed pairing still owns the diagnostic span.
                    with self.assertRaises(SourceError) as failure:
                        pairs(lex(Source('d/test/room.c', raw)))
                    error = next(f for f in fs if f['code'] == 'SOURCE_SYNTAX_ERROR')
                    self.assertEqual(str(failure.exception), error['reason'])
                    self.assertEqual(failure.exception.start, error['provenance']['byte_start'])
                    self.assertEqual(failure.exception.end, error['provenance']['byte_end_exclusive'])
                else:
                    self.assertTrue(r['supported_candidate'])
                    self.assertTrue(r['facts'])
                    self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(fs))
                for f in fs + r['facts']:
                    p = f['provenance']
                    self.assertEqual('d/test/room.c', p['source_path'])
                    self.assertEqual(hashlib.sha256(raw).hexdigest(), p['source_sha256'])
                    self.assertEqual(raw[p['byte_start']:p['byte_end_exclusive']].decode(), p['raw'])

    def delimiter(self, mark):
        macro, _, _ = self.CASES[mark]
        self.check('#define M ' + mark + '\n' + macro, 'OUT_OF_SCOPE')

    def test_object_open_brace(self):
        self.delimiter('{')

    def test_object_close_brace(self):
        self.delimiter('}')

    def test_object_open_parenthesis(self):
        self.delimiter('(')

    def test_object_close_parenthesis(self):
        self.delimiter(')')

    def test_object_open_square(self):
        self.delimiter('[')

    def test_object_close_square(self):
        self.delimiter(']')

    def test_handwritten_controls_all_six(self):
        for _, literal_source, _ in self.CASES.values():
            self.check(literal_source, 'EXTRACTED')

    def test_true_malformed_all_six(self):
        for _, _, malformed in self.CASES.values():
            self.check(malformed, 'QUARANTINED')

    def test_unused_dangerous_all_six(self):
        for mark, (_, _, malformed) in self.CASES.items():
            self.check('#define M ' + mark + '\n' + malformed, 'QUARANTINED')

    def test_used_pairing_neutral_replacements(self):
        for replacement in ('1', '"text"', '"{(["', "'}'", ';', '#', '{}', '(1)', '[1]', '1 + 2'):
            self.check('#define M ' + replacement + '\ninherit ROOM;\nvoid create()\nset("short",M);\n}\n',
                       'QUARANTINED')

    def test_alias_chain_open_brace(self):
        self.check('#define A B\n#define B {\n' + self.CASES['{'][0].replace(' M', ' A'), 'OUT_OF_SCOPE')

    def test_alias_chain_close_parenthesis(self):
        self.check('#define A B\n#define B C\n#define C )\n' + self.CASES[')'][0].replace(' M', ' A'), 'OUT_OF_SCOPE')

    def test_iterative_long_alias_chain(self):
        definitions = '#define A N0\n' + ''.join(f'#define N{i} N{i + 1}\n' for i in range(1100)) + '#define N1100 {\n'
        self.check(definitions + self.CASES['{'][0].replace(' M', ' A'), 'OUT_OF_SCOPE')

    def test_used_cycle(self):
        self.check('#define A B\n#define B A\n' + self.CASES['{'][0].replace(' M', ' A'), 'OUT_OF_SCOPE')

    def test_unused_cycle(self):
        self.check('#define A B\n#define B A\n' + self.CASES['{'][2], 'QUARANTINED')

    def test_competing_pairing_definition(self):
        for definitions in ('#define M 1\n#define M {\n', '#define M {\n#undef M\n#define M 1\n'):
            self.check(definitions + self.CASES['{'][0], 'OUT_OF_SCOPE')

    def test_competing_neutral_definitions(self):
        self.check('#define M 1\n#define M "text"\n' + self.CASES['{'][0], 'QUARANTINED')

    def test_token_paste_can_hide_pairing_macro_identity(self):
        self.check('#define OPEN {\n#define M OP ## EN\n' + self.CASES['{'][0], 'OUT_OF_SCOPE')

    def test_function_open_brace_invocation(self):
        self.check('#define M() {\n' + self.CASES['{'][0].replace(' M', ' M()'), 'OUT_OF_SCOPE')

    def test_function_close_parenthesis_invocation(self):
        self.check('#define M() )\n' + self.CASES[')'][0].replace(' M', ' M()'), 'OUT_OF_SCOPE')

    def test_function_parameter_dependent_invocation(self):
        self.check('#define M(x) x\ninherit ROOM;\nvoid create() M({)\nset("short","x");\n}\n', 'OUT_OF_SCOPE')

    def test_function_drops_delimiter_argument(self):
        self.check('#define DROP(x)\ninherit ROOM;\nvoid create() { DROP({) set("short","x"); }\n', 'OUT_OF_SCOPE')

    def test_function_invalid_signature_invoked(self):
        self.check('#define M(x\n' + self.CASES['{'][0].replace(' M', ' M()'), 'OUT_OF_SCOPE')

    def test_function_name_is_not_invocation(self):
        self.check('#define M() {\n' + self.CASES['{'][0], 'QUARANTINED')

    def test_unused_function_macro(self):
        self.check('#define M() {\n' + self.CASES['{'][2], 'QUARANTINED')

    def test_alias_function_invoked_and_bare(self):
        definitions = '#define A B\n#define B M\n#define M() {\n'
        self.check(definitions + self.CASES['{'][0].replace(' M', ' A()'), 'OUT_OF_SCOPE')
        self.check(definitions + self.CASES['{'][0].replace(' M', ' A'), 'QUARANTINED')

    def test_internal_function_invocation_in_object_replacement(self):
        self.check('#define A M({)\n#define M(x)\n' + self.CASES['{'][0].replace(' M', ' A'), 'OUT_OF_SCOPE')

    def test_direct_header_definition(self):
        self.check('#include "delimiters.h"\n' + self.CASES['{'][0], 'OUT_OF_SCOPE',
                   {'d/test/delimiters.h': '#define M {\n'})

    def test_nested_header_definition(self):
        self.check('#include "a.h"\n' + self.CASES['{'][0], 'OUT_OF_SCOPE',
                   {'d/test/a.h': '#include "nested/b.h"\n', 'd/test/nested/b.h': '#define M {\n'})

    def test_sibling_root_header_aliases(self):
        self.check('#define A B\n#include "a.h"\n#include "b.h"\n' + self.CASES['{'][0].replace(' M', ' A'),
                   'OUT_OF_SCOPE', {'d/test/a.h': '#define B C\n', 'd/test/b.h': '#define C {\n'})

    def test_header_function_macro(self):
        self.check('#include <delimiters.h>\n' + self.CASES['{'][0].replace(' M', ' M()'), 'OUT_OF_SCOPE',
                   {'include/delimiters.h': '#define M() {\n'})

    def test_include_cycles_and_conditional_definitions(self):
        self.check('#include "a.h"\n' + self.CASES['{'][0], 'OUT_OF_SCOPE',
                   {'d/test/a.h': '#include "b.h"\n', 'd/test/b.h': '#include "a.h"\n#ifdef X\n#define M {\n#endif\n'})

    def test_safe_or_missing_include_is_not_pairing_evidence(self):
        for deps in ({}, {'d/test/a.h': ''}, {'d/test/a.h': '#define UNUSED {\n'},
                     {'d/test/a.h': 'int helper(){return 1;}\n'}, {'d/test/a.h': '"bad'}):
            self.check('#include "a.h"\n' + self.CASES['{'][2], 'QUARANTINED', deps)

    def test_opaque_comments(self):
        self.check('#define OPEN {\n// OPEN\n/* OPEN */\n' + self.CASES['{'][2], 'QUARANTINED')

    def test_opaque_strings(self):
        self.check('#define OPEN {\nstring label="OPEN";\n' + self.CASES['{'][2], 'QUARANTINED')

    def test_opaque_characters_and_symbols(self):
        self.check("#define O {\n#define OPEN {\nint label='O';\nmixed symbol='OPEN;\n" + self.CASES['{'][2], 'QUARANTINED')

    def test_opaque_heredoc(self):
        self.check('#define OPEN {\nstring label=@TEXT\nOPEN\nTEXT;\n' + self.CASES['{'][2], 'QUARANTINED')

    def test_opaque_echo_and_unused_replacement(self):
        self.check('#define OPEN {\n#echo OPEN({\n#define OTHER OPEN\n' + self.CASES['{'][2], 'QUARANTINED')

    def test_root_conditional_does_not_enter_gate(self):
        for directive in ('if 1', 'ifdef X', 'ifndef X', 'elif 1', 'else', 'endif'):
            with patch.object(RoomExtractor, 'pairing_uncertain_use', side_effect=AssertionError('must stay lazy')):
                r, fs = extract('#' + directive + '\n' + self.CASES['{'][2])
            self.assertEqual('OUT_OF_SCOPE', r['status'])
            self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(fs))

    def test_paired_source_does_not_enter_gate(self):
        for source in (self.CASES['{'][1], '#define M {\n' + room('M; set("short","x");'),
                       '#define M "text"\n' + room('set("short",M);')):
            with patch.object(RoomExtractor, 'pairing_uncertain_use', side_effect=AssertionError('must stay lazy')):
                extract(source)

    def test_lexical_and_encoding_errors_bypass_gate(self):
        for invalid in (b'\xff', b'\0', '\ufffd'.encode(), b'"unterminated', b'/* unterminated'):
            raw = b'#define OPEN {\ninherit ROOM;\nvoid create() OPEN\n' + invalid
            with patch.object(RoomExtractor, 'pairing_uncertain_use', side_effect=AssertionError('must stay lazy')):
                r, fs = extract(raw)
            self.assertEqual('QUARANTINED', r['status'])
            self.assertEqual([], r['facts'])
            self.assertTrue(codes(fs) & {'SOURCE_ENCODING_ISSUE', 'SOURCE_SYNTAX_ERROR'})

    def test_original_reproducer_real_cli(self):
        text = '#define OPEN {\ninherit ROOM;\nvoid create() OPEN\n    set("short", "x");\n}\n'
        for newline in ('\n', '\r\n'):
            with tempfile.TemporaryDirectory() as directory:
                base = Path(directory); source = base / 'source'; (source / 'd').mkdir(parents=True)
                raw = text.replace('\n', newline).encode(); (source / 'd/room.c').write_bytes(raw)
                result = subprocess.run([sys.executable, '-m', 'tools.migration.cli', '--source-root', str(source),
                                         '--output-root', str(base / 'output')], cwd=REPOSITORY, capture_output=True)
                self.assertEqual(0, result.returncode, result.stderr)
                doc = json.loads((base / 'output/static-rooms.json').read_bytes())
                self.assertEqual('1.0.33', doc['extractor_version'])
                self.assertEqual('OUT_OF_SCOPE', doc['objects'][0]['status'])
                self.assertEqual([], doc['objects'][0]['facts'])
                self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(doc['findings']))
                for f in doc['findings']:
                    self.assertEqual('OPEN', f['provenance']['raw'])
                    self.assertEqual(hashlib.sha256(raw).hexdigest(), f['provenance']['source_sha256'])


class P2F13RegressionTests(unittest.TestCase):
    # Include-site source, header, independently handwritten literal, true defect.
    CASES = {
        '{': ('inherit ROOM;\nvoid create()\n#include "part.h"\nset("short","雪");\n}\n',
              '{\n', 'inherit ROOM;\nvoid create(){set("short","雪");}\n',
              'inherit ROOM;\nvoid create()\nset("short","雪");}\n'),
        '}': ('inherit ROOM;\nvoid create(){set("short","雪");\n#include "part.h"\n',
              '}\n', 'inherit ROOM;\nvoid create(){set("short","雪");}\n',
              'inherit ROOM;\nvoid create(){set("short","雪");\n'),
        '(': ('inherit ROOM;\nvoid create\n#include "part.h"\n){set("short","雪");}\n',
              '(\n', 'inherit ROOM;\nvoid create(){set("short","雪");}\n',
              'inherit ROOM;\nvoid create){set("short","雪");}\n'),
        ')': ('inherit ROOM;\nvoid create(\n#include "part.h"\n{set("short","雪");}\n',
              ')\n', 'inherit ROOM;\nvoid create(){set("short","雪");}\n',
              'inherit ROOM;\nvoid create({set("short","雪");}\n'),
        '[': ('inherit ROOM;\nvoid create(){set("exits", (\n#include "part.h"\n"n":"/d/n"]));}\n',
              '[\n', 'inherit ROOM;\nvoid create(){set("exits", (["n":"/d/n"]));}\n',
              'inherit ROOM;\nvoid create(){set("exits", ("n":"/d/n"]));}\n'),
        ']': ('inherit ROOM;\nvoid create(){set("exits", (["n":"/d/n"\n#include "part.h"\n));}\n',
              ']\n', 'inherit ROOM;\nvoid create(){set("exits", (["n":"/d/n"]));}\n',
              'inherit ROOM;\nvoid create(){set("exits", (["n":"/d/n"));}\n'),
    }

    def check(self, source, headers=None, *, status='OUT_OF_SCOPE', exit_code=0,
              bad_headers=(), anchor=None, real_cli=False):
        for newline in ('\n', '\r\n'):
            with self.subTest(newline=repr(newline)), tempfile.TemporaryDirectory() as directory:
                base = Path(directory); root = base / 'source'; (root / 'd').mkdir(parents=True)
                authored = {'d/test.c': source, **(headers or {})}
                raw = {p: (t.encode() if isinstance(t, str) else t).replace(b'\n', newline.encode())
                       for p, t in authored.items()}
                for path, data in raw.items():
                    target = root / path; target.parent.mkdir(parents=True, exist_ok=True); target.write_bytes(data)
                if real_cli:
                    output = base / 'output'
                    run = subprocess.run([sys.executable, '-m', 'tools.migration.cli', '--source-root', str(root),
                                          '--output-root', str(output)], cwd=REPOSITORY, capture_output=True)
                    code = run.returncode; doc = json.loads((output / 'static-rooms.json').read_bytes())
                else:
                    doc, code = scan(root)
                self.assertEqual(exit_code, code)
                record = next(o for o in doc['objects'] if o['source_path'] == 'd/test.c')
                self.assertEqual(status, record['status'])
                diagnostics = [f for f in doc['findings'] if f['object_id'] == record['object_id']]
                if status in ('OUT_OF_SCOPE', 'QUARANTINED'):
                    self.assertFalse(record['supported_candidate']); self.assertEqual([], record['facts'])
                else:
                    self.assertTrue(record['supported_candidate']); self.assertTrue(record['facts'])
                if status == 'QUARANTINED':
                    self.assertIn('SOURCE_SYNTAX_ERROR', codes(diagnostics))
                else:
                    self.assertFalse(codes(diagnostics) & {'SOURCE_SYNTAX_ERROR', 'SOURCE_ENCODING_ISSUE'})
                if anchor:
                    for finding in diagnostics:
                        self.assertEqual('d/test.c', finding['provenance']['source_path'])
                        self.assertEqual(anchor.replace('\n', newline), finding['provenance']['raw'])
                for obj in doc['objects']:
                    if not obj['source_path'].endswith('.h'):
                        continue
                    self.assertFalse(obj['supported_candidate']); self.assertEqual([], obj['facts'])
                    self.assertEqual('QUARANTINED' if obj['source_path'] in bad_headers else 'OUT_OF_SCOPE', obj['status'])
                def provenance(value):
                    if isinstance(value, dict):
                        if 'byte_end_exclusive' in value:
                            data = raw[value['source_path']]; start = value['byte_start']; end = value['byte_end_exclusive']
                            self.assertEqual(hashlib.sha256(data).hexdigest(), value['source_sha256'])
                            self.assertEqual(data[start:end], bytes.fromhex(value['raw_hex']) if value['raw'] is None else value['raw'].encode())
                            self.assertEqual(data[:start].count(b'\n') + 1, value['line'])
                            line_start = data.rfind(b'\n', 0, start) + 1
                            self.assertEqual(len(data[line_start:start].decode('utf-8', errors='replace')) + 1, value['column'])
                        for child in value.values(): provenance(child)
                    elif isinstance(value, list):
                        for child in value: provenance(child)
                provenance(doc)

    def delimiter(self, delimiter):
        source, fragment, _, _ = self.CASES[delimiter]
        self.check(source, {'d/part.h': fragment}, anchor='#include "part.h"\n')

    def test_include_open_brace(self): self.delimiter('{')
    def test_include_close_brace(self): self.delimiter('}')
    def test_include_open_parenthesis(self): self.delimiter('(')
    def test_include_close_parenthesis(self): self.delimiter(')')
    def test_include_open_bracket(self): self.delimiter('[')
    def test_include_close_bracket(self): self.delimiter(']')

    def test_handwritten_literal_controls(self):
        for delimiter, (_, _, literal_source, _) in self.CASES.items():
            self.check(literal_source, status='PARTIAL' if delimiter in '[]' else 'EXTRACTED')

    def test_true_malformed_roots(self):
        for _, _, _, malformed in self.CASES.values():
            self.check(malformed, status='QUARANTINED', exit_code=1)

    def test_safe_include_preserves_original_error(self):
        for fragment in ('', '#define ONE 1\n', 'int helper(){return 1;}\n', ';\n', '#define UNUSED {\n'):
            self.check(self.CASES['{'][0], {'d/part.h': fragment}, status='QUARANTINED', exit_code=1)
        text = self.CASES['{'][0]
        with self.assertRaises(SourceError) as original: pairs(lex(Source('d/test.c', text.encode())))
        record, findings = extract(text, path='d/test.c', dependencies={'d/part.h': Source('d/part.h', b'')})
        error = next(f for f in findings if f['code'] == 'SOURCE_SYNTAX_ERROR')
        self.assertEqual(str(original.exception), error['reason'])
        self.assertEqual(original.exception.start, error['provenance']['byte_start'])
        self.assertEqual(original.exception.end, error['provenance']['byte_end_exclusive'])

    def test_nested_fragment_reaches_root_directive(self):
        self.check(self.CASES['{'][0], {'d/part.h': '#include "nested/open.h"\n', 'd/nested/open.h': '{\n'},
                   anchor='#include "part.h"\n')

    def test_standard_fragment(self):
        self.check(self.CASES['}'][0].replace('"part.h"', '<part.h>'), {'include/part.h': '}\n'},
                   anchor='#include <part.h>\n')

    def test_cooperating_fragments_paired_root(self):
        self.check('inherit ROOM;\nvoid create()\n#include "open.h"\nset("short","x");\n#include "close.h"\n',
                   {'d/open.h': '{\n', 'd/close.h': '}\n'})

    def test_repeated_cycle_include_graph_is_bounded(self):
        self.check(self.CASES['{'][0], {'d/part.h': '#include "cycle.h"\n#include "cycle.h"\n',
                                      'd/cycle.h': '#include "part.h"\n{\n'}, anchor='#include "part.h"\n')

    def test_sibling_provenance_uses_reaching_include(self):
        self.check('#include "safe.h"\n' + self.CASES['{'][0], {'d/safe.h':'#define ONE 1\n', 'd/part.h':'{\n'},
                   anchor='#include "part.h"\n')

    def test_unreferenced_raw_header_does_not_excuse_root(self):
        self.check(self.CASES['{'][3], {'d/unreferenced.h':'{\n'}, status='QUARANTINED', exit_code=1)

    def test_standalone_header_delimiters(self):
        for delimiter in '{}()[]':
            self.check(room('set("short","x");'), {'include/fragment.h': delimiter+'\n'}, status='EXTRACTED')

    def test_standalone_structural_fragments_beyond_pairs(self):
        for fragment in ('inherit ROOM', 'void create(){set("short","x")}', 'inherit ROOM;\nvoid create(){set("exits", (["n":]));}'):
            self.check(room('set("short","x");'), {'include/fragment.h':fragment}, status='EXTRACTED')

    def test_balanced_header_never_promoted_or_emits_facts(self):
        self.check(room('set("short","root");'), {'d/fake_room.h':room('set("short","header");')}, status='EXTRACTED')

    def test_header_encoding_corruption(self):
        for raw in (b'\xff', b'\0', '\ufffd'.encode()):
            self.check(room('set("short","x");'), {'include/bad.h':raw}, status='EXTRACTED', exit_code=1,
                       bad_headers=('include/bad.h',))

    def test_header_lexical_corruption(self):
        for raw in ('"unfinished', '/* unfinished', '@TEXT\nunfinished', '#define X "unfinished\n'):
            self.check(room('set("short","x");'), {'include/bad.h':raw}, status='EXTRACTED', exit_code=1,
                       bad_headers=('include/bad.h',))

    def test_existing_quoted_symbol_policy_is_not_redefined(self):
        self.check(room('set("short","x");'), {'include/symbol.h':"'symbol\n'{'\n"}, status='EXTRACTED')

    def test_valid_root_with_lexically_bad_header(self):
        self.check('#include "bad.h"\n'+room('set("short","x");'), {'d/bad.h':'"unfinished'},
                   exit_code=1, bad_headers=('d/bad.h',))

    def test_real_root_defect_with_lexically_bad_header(self):
        for bad in ('"unfinished', '#define X "unfinished\n{\n'):
            self.check(self.CASES['{'][0], {'d/part.h':bad}, status='QUARANTINED', exit_code=1,
                       bad_headers=('d/part.h',))

    def test_missing_include_policy_unchanged(self):
        self.check('#include "missing.h"\n'+room('set("short","x");'))
        self.check(self.CASES['{'][0], status='QUARANTINED', exit_code=1)

    def test_macro_recovery_precedes_raw_fragment_recovery(self):
        with patch.object(RoomExtractor, 'include_pairing_uncertain_use', side_effect=AssertionError('macro already explains failure')):
            record, findings = extract('#define OPEN {\ninherit ROOM;\nvoid create() OPEN set("short","x");}')
        self.assertEqual('OUT_OF_SCOPE', record['status']); self.assertEqual([], record['facts'])

    def test_normal_paired_root_does_not_enter_new_gate(self):
        with patch.object(RoomExtractor, 'include_pairing_uncertain_use', side_effect=AssertionError('must be lazy')):
            self.check('#include "safe.h"\n'+room('set("short","x");'), {'d/safe.h':'#define X 1\n'}, status='PARTIAL')

    def test_root_conditionals_bypass_new_gate(self):
        with patch.object(RoomExtractor, 'include_pairing_uncertain_use', side_effect=AssertionError('must be lazy')):
            for directive in ('if 1', 'ifdef X', 'ifndef X', 'elif 1', 'else', 'endif'):
                self.check('#'+directive+'\n'+self.CASES['{'][3])

    def test_root_lexical_and_encoding_errors_bypass_new_gate(self):
        with patch.object(RoomExtractor, 'include_pairing_uncertain_use', side_effect=AssertionError('must be lazy')):
            for raw in (b'\xff', b'\0', b'"unfinished', b'/* unfinished'):
                record, findings = extract(raw)
                self.assertEqual('QUARANTINED', record['status'])

    def test_original_fr12_reproducer_real_cli(self):
        self.check('inherit ROOM;\nvoid create()\n#include "open.h"\n    set("short", "x");\n}\n',
                   {'d/open.h':'{\n'}, anchor='#include "open.h"\n', real_cli=True)



class P2F14RegressionTests(unittest.TestCase):
    # Independently authored inputs/expectations, never extractor-generated.
    CASES = [
        ('include-function-invocation', '#define END() ;\ninherit ROOM\n#include "tail.h"\n', {'d/tail.h': 'END()\n'}, 'OUT_OF_SCOPE'),
        ('include-neutral-invocation', '#define END() 1\ninherit ROOM\n#include "tail.h"\n', {'d/tail.h': 'END()\n'}, 'OUT_OF_SCOPE'),
        ('direct', 'inherit ROOM\n#include "semi.h"\nvoid create() {}\n', {'d/semi.h': ';\n'}, 'OUT_OF_SCOPE'),
        ('at-eof', 'inherit ROOM\n#include "semi.h"\n', {'d/semi.h': ';\n'}, 'OUT_OF_SCOPE'),
        ('nested', 'inherit ROOM\n#include "outer.h"\nvoid create() {}\n', {'d/outer.h': '#include "semi.h"\n', 'd/semi.h': ';\n'}, 'OUT_OF_SCOPE'),
        ('standard', 'inherit ROOM\n#include <semi.h>\nvoid create() {}\n', {'include/semi.h': ';\n'}, 'OUT_OF_SCOPE'),
        ('safe-sibling', '#include "safe.h"\ninherit ROOM\n#include "semi.h"\nvoid create() {}\n', {'d/safe.h': 'int helper() { return 1; }\n', 'd/semi.h': ';\n'}, 'OUT_OF_SCOPE'),
        ('literal-base', 'inherit "/std/room"\n#include "semi.h"\nvoid create() {}\n', {'d/semi.h': ';\n'}, 'OUT_OF_SCOPE'),
        ('whole-expression', 'inherit\n#include "base.h"\nvoid create() {}\n', {'d/base.h': 'ROOM;\n'}, 'OUT_OF_SCOPE'),
        ('macro-object', '#define END ;\ninherit ROOM END\nvoid create() {}\n', {}, 'OUT_OF_SCOPE'),
        ('macro-alias', '#define END ;\n#define FIN END\ninherit ROOM FIN\nvoid create() {}\n', {}, 'OUT_OF_SCOPE'),
        ('macro-function', '#define END() ;\ninherit ROOM END()\nvoid create() {}\n', {}, 'OUT_OF_SCOPE'),
        ('macro-header', '#include "macros.h"\ninherit ROOM END\nvoid create() {}\n', {'d/macros.h': '#define END ;\n'}, 'OUT_OF_SCOPE'),
        ('literal', 'inherit ROOM;\nvoid create() {}\n', {}, 'EXTRACTED'),
        ('literal-fact', 'inherit ROOM;\nvoid create() { set("short", "x"); }\n', {}, 'EXTRACTED'),
        ('missing-terminator', 'inherit ROOM\nvoid create() {}\n', {}, 'QUARANTINED'),
        ('empty-include', 'inherit ROOM\n#include "empty.h"\nvoid create() {}\n', {'d/empty.h': ''}, 'OUT_OF_SCOPE'),
        ('safe-include', 'inherit ROOM\n#include "safe.h"\nvoid create() {}\n', {'d/safe.h': 'int helper() { return 1; }\n'}, 'OUT_OF_SCOPE'),
        ('unused-macro', '#define END ;\ninherit ROOM\nvoid create() {}\n', {}, 'QUARANTINED'),
        ('neutral-used-macro', '#define BASE ROOM\ninherit BASE\nvoid create() {}\n', {}, 'QUARANTINED'),
        ('unreferenced-header', 'inherit ROOM\nvoid create() {}\n', {'d/semi.h': ';\n'}, 'QUARANTINED'),
        ('missing-include', 'inherit ROOM\n#include "missing.h"\nvoid create() {}\n', {}, 'OUT_OF_SCOPE'),
        ('whole-literal', 'inherit\n#include "base.h"\nvoid create() {}\n', {'d/base.h': '"/std/room";\n'}, 'OUT_OF_SCOPE'),
        ('suffix', 'inherit "/std/"\n#include "tail.h"\n', {'d/tail.h': '+ "room";\n'}, 'OUT_OF_SCOPE'),
        ('unrelated-missing', '#include "missing.h"\ninherit ROOM\nvoid create() {}\n', {}, 'QUARANTINED'),
        ('unrelated-terminator', '#include "semi.h"\ninherit ROOM\nvoid create() {}\n', {'d/semi.h': ';\n'}, 'QUARANTINED'),
        ('safe-data', 'inherit ROOM\n#include "safe.h"\nvoid create() {}\n', {'d/safe.h': 'int x;\n'}, 'OUT_OF_SCOPE'),
        ('untyped-helper', 'inherit ROOM\n#include "safe.h"\nvoid create() {}\n', {'d/safe.h': 'helper(){return 1;}\n'}, 'OUT_OF_SCOPE'),
        ('missing-nested', 'inherit ROOM\n#include "outer.h"\n', {'d/outer.h': '#include "missing.h"\n'}, 'OUT_OF_SCOPE'),
        ('missing-standard', 'inherit ROOM\n#include <missing.h>\n', {}, 'OUT_OF_SCOPE'),
        ('include-macro-path', 'inherit ROOM\n#include UNKNOWN\n', {}, 'OUT_OF_SCOPE'),
        ('cross-header', '#include "a.h"\n#include "b.h"\ninherit ROOM END\n', {'d/a.h': '#define END FIN\n', 'd/b.h': '#define FIN ;\n'}, 'OUT_OF_SCOPE'),
        ('cycle', '#define END FIN\n#define FIN END\ninherit ROOM END\n', {}, 'OUT_OF_SCOPE'),
        ('competing', '#define END 1\n#define END 2\ninherit ROOM END\n', {}, 'OUT_OF_SCOPE'),
        ('paste', '#define END A ## B\ninherit ROOM END\n', {}, 'OUT_OF_SCOPE'),
        ('invalid-function', '#define END(x ;\ninherit ROOM END()\n', {}, 'OUT_OF_SCOPE'),
        ('parameter', '#define END(x) x\ninherit ROOM END(1)\n', {}, 'OUT_OF_SCOPE'),
        ('neutral-number', '#define V 1\ninherit ROOM V\nvoid create(){}\n', {}, 'QUARANTINED'),
        ('neutral-function', '#define V() 1\ninherit ROOM V()\nvoid create(){}\n', {}, 'QUARANTINED'),
        ('uninvoked-function', '#define V() ;\ninherit ROOM V\nvoid create(){}\n', {}, 'QUARANTINED'),
        ('later-macro', '#define END ;\ninherit ROOM\nvoid create(){END}\n', {}, 'QUARANTINED'),
        ('later-untyped-macro', '#define END ;\ninherit ROOM\ncreate(){END}\n', {}, 'QUARANTINED'),
        ('later-include', 'inherit ROOM\nvoid create(){\n#include "semi.h"\n}\n', {'d/semi.h': ';\n'}, 'QUARANTINED'),
        ('unused-define-at-boundary', 'inherit ROOM\n#define END ;\nvoid create(){}\n', {}, 'OUT_OF_SCOPE'),
        ('raw-echo', 'inherit ROOM\n#echo ; raw "\nvoid create(){}\n', {}, 'OUT_OF_SCOPE'),
        ('pragma', 'inherit ROOM\n#pragma strict_types\nvoid create(){}\n', {}, 'OUT_OF_SCOPE'),
        ('undef', 'inherit ROOM\n#undef END\nvoid create(){}\n', {}, 'OUT_OF_SCOPE'),
        ('later-authored-semicolon', 'inherit ROOM\nvoid create(){set("short","x");}\n', {}, 'QUARANTINED'),
        ('include-before-later-authored-semicolon', 'inherit ROOM\n#include "semi.h"\nvoid create(){set("short","x");}\n', {'d/semi.h': ';\n'}, 'OUT_OF_SCOPE'),
        ('uncertain-second', 'inherit ROOM;\ninherit ROOM\n#include "semi.h"\nvoid create(){}\n', {'d/semi.h': ';\n'}, 'OUT_OF_SCOPE'),
        ('uncertain-first', 'inherit ROOM\n#include "semi.h"\ninherit ROOM;\nvoid create(){}\n', {'d/semi.h': ';\n'}, 'OUT_OF_SCOPE'),
    ]

    def check(self, text, headers, status):
        for newline in ('\n', '\r\n'):
            raw = text.replace('\n', newline).encode()
            deps = {p: Source(p, h.replace('\n', newline).encode()) for p, h in headers.items()}
            record, findings = extract(raw, path='d/probe.c', dependencies=deps)
            with self.subTest(newline=repr(newline), text=text):
                self.assertEqual(status, record['status'])
                if status == 'OUT_OF_SCOPE':
                    self.assertFalse(record['supported_candidate'])
                    self.assertEqual([], record['facts'])
                    self.assertEqual([], record['direct_inherits'])
                    self.assertEqual([], record['category_candidates'])
                    self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(findings))
                    self.assertIn('DRIVER_SEMANTICS_UNKNOWN', codes(findings))
                elif status == 'QUARANTINED':
                    self.assertEqual([], record['facts'])
                    error = next(f for f in findings if f['code'] == 'SOURCE_SYNTAX_ERROR')
                    self.assertEqual('unterminated inherit', error['reason'])
                    self.assertEqual('inherit', error['provenance']['raw'])
                for f in findings + record['facts']:
                    p = f['provenance']
                    self.assertEqual(hashlib.sha256(raw).hexdigest(), p['source_sha256'])
                    self.assertEqual(raw[p['byte_start']:p['byte_end_exclusive']].decode(), p['raw'])
        return record, findings

    def test_pending_declaration_matrix(self):
        for name, text, headers, status in self.CASES:
            with self.subTest(case=name): self.check(text, headers, status)

    def test_long_alias_chain(self):
        defs = ''.join(f'#define A{i} A{i+1}\n' for i in range(1100))+'#define A1100 ;\n'
        self.check(defs+'inherit ROOM A0\n', {}, 'OUT_OF_SCOPE')

    def test_finding_anchors(self):
        for text, headers, anchor in [
            ('inherit ROOM\n#include "a.h"\n', {'d/a.h':'#include "nested/semi.h"\n','d/nested/semi.h':';'}, '#include "a.h"\n'),
            ('inherit ROOM\n#include "missing.h"\n', {}, '#include "missing.h"\n'),
            ('#define END ;\ninherit ROOM END\n', {}, 'END'),
        ]:
            _, ff = self.check(text, headers, 'OUT_OF_SCOPE')
            # P2F25 refuses participating directives before pending parsing.
            anchors = {anchor, 'inherit'} if anchor.startswith('#include') else {anchor}
            self.assertEqual(anchors, {f['provenance']['raw'].replace('\r\n', '\n') for f in ff})

    def test_missing_dependency_finding(self):
        _, ff = self.check('inherit ROOM\n#include "missing.h"\n', {}, 'OUT_OF_SCOPE')
        # Structural refusal no longer depends on resolving this include.
        self.assertEqual({'OUT_OF_SCOPE', 'DRIVER_SEMANTICS_UNKNOWN'}, codes(ff))

    def test_multiple_authored_inherits(self):
        r, _ = extract('inherit ROOM; inherit "/custom/base"; void create(){}')
        self.assertEqual('PARTIAL', r['status']); self.assertEqual(2, len(fields(r, 'inherit')))

    def test_authored_valid_path_is_lazy(self):
        with patch.object(RoomExtractor, 'inherit_boundary_uncertain', side_effect=AssertionError('must stay lazy')):
            self.check('inherit ROOM;\nvoid create(){}', {}, 'EXTRACTED')
            r, _ = self.check(room('set("short","x");'), {}, 'EXTRACTED')
            self.assertEqual('x', fields(r, 'short')[0]['value']['value'])

    def test_existing_exclusions(self):
        for base in ('NPC', 'ITEM', 'BANK', 'HOCKSHOP', '"/std/weapon/sword"', '"/std/armor/boots"'):
            r, _ = extract(f'inherit ROOM; inherit {base}; void create(){{}}')
            self.assertFalse(r['supported_candidate']); self.assertEqual([], r['facts'])

    def test_header_fragments(self):
        for fragment in (';', 'ROOM;', '{', '}', '(', ')', '[', ']', 'inherit ROOM'):
            r, ff = RoomExtractor(Source('include/x.h', fragment.encode()), set(), {}).extract(header=True)
            self.assertEqual('OUT_OF_SCOPE', r['status']); self.assertEqual([], r['facts'])
            self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(ff))

    def test_header_corruption(self):
        for raw in (b'\xff', b'\0', b'"unfinished', b'/* unfinished', b'@TEXT\nunfinished'):
            r, _ = RoomExtractor(Source('include/x.h', raw), set(), {}).extract(header=True)
            self.assertEqual('QUARANTINED', r['status']); self.assertEqual([], r['facts'])



class P2F15RegressionTests(unittest.TestCase):
    # Hand-authored expectations; includes the complete 24 x LF/CRLF FR14 matrix.
    CASES = [
        ('direct', '#define TAIL() ; void create()\ninherit ROOM TAIL() {}\n', {}, 'OUT_OF_SCOPE'),
        ('alias', '#define END TAIL\n#define TAIL() ; void create()\ninherit ROOM END() {}\n', {}, 'OUT_OF_SCOPE'),
        ('alias-two', '#define END MID\n#define MID TAIL\n#define TAIL() ; void create()\ninherit ROOM END() {}\n', {}, 'OUT_OF_SCOPE'),
        ('parameter', '#define TAIL(x) ; void create()\ninherit ROOM TAIL(1) {}\n', {}, 'OUT_OF_SCOPE'),
        ('substituted-name', '#define TAIL(name) ; void name()\ninherit ROOM TAIL(create) {}\n', {}, 'OUT_OF_SCOPE'),
        ('header', '#include "defs.h"\ninherit ROOM TAIL() {}\n', {'d/defs.h': '#define TAIL() ; void create()\n'}, 'OUT_OF_SCOPE'),
        ('nested', '#include "defs.h"\ninherit ROOM TAIL() {}\n', {'d/defs.h': '#include "inner.h"\n', 'd/inner.h': '#define TAIL() ; void create()\n'}, 'OUT_OF_SCOPE'),
        ('standard', '#include <defs.h>\ninherit ROOM TAIL() {}\n', {'include/defs.h': '#define TAIL() ; void create()\n'}, 'OUT_OF_SCOPE'),
        ('cross-header', '#include "a.h"\n#include "b.h"\ninherit ROOM END() {}\n', {'d/a.h': '#define END TAIL\n', 'd/b.h': '#define TAIL() ; void create()\n'}, 'OUT_OF_SCOPE'),
        ('literal-base', '#define TAIL() ; void create()\ninherit "/std/room" TAIL() {}\n', {}, 'OUT_OF_SCOPE'),
        ('valid-first', '#define TAIL() ; void create()\ninherit "/custom/base";\ninherit ROOM TAIL() {}\n', {}, 'OUT_OF_SCOPE'),
        ('keyword-int', '#define int ;\ninherit ROOM int\nvoid create() {}\n', {}, 'OUT_OF_SCOPE'),
        ('keyword-private', '#define private ; void create()\ninherit ROOM private {}\n', {}, 'OUT_OF_SCOPE'),
        ('object-tail', '#define TAIL ; void create()\ninherit ROOM TAIL {}\n', {}, 'OUT_OF_SCOPE'),
        ('direct-end-call', '#define END() ;\ninherit ROOM END()\nvoid create() {}\n', {}, 'OUT_OF_SCOPE'),
        ('raw-include-tail', 'inherit ROOM\n#include "tail.h"\n{}\n', {'d/tail.h': '; void create()\n'}, 'OUT_OF_SCOPE'),
        ('literal', 'inherit ROOM;\nvoid create() {}\n', {}, 'EXTRACTED'),
        ('literal-short', 'inherit ROOM;\nvoid create() {set("short","x");}\n', {}, 'EXTRACTED'),
        ('literal-multiple', 'inherit "/custom/base";\ninherit ROOM;\nvoid create() {}\n', {}, 'PARTIAL'),
        ('true-typed', 'inherit ROOM\nvoid create() {}\n', {}, 'QUARANTINED'),
        ('true-untyped', 'inherit ROOM\ncreate() {}\n', {}, 'QUARANTINED'),
        ('unused-tail', '#define TAIL() ; void helper()\ninherit ROOM\nvoid create() {}\n', {}, 'QUARANTINED'),
        ('neutral-untyped', '#define TAIL() 1\ninherit ROOM TAIL() {}\n', {}, 'QUARANTINED'),
        ('later-tail', '#define TAIL() ;\ninherit ROOM\nvoid create() {TAIL()}\n', {}, 'QUARANTINED'),
        ('different-name', '#define FINISH() ; void create()\ninherit ROOM FINISH() {}\n', {}, 'OUT_OF_SCOPE'),
        ('function-to-object', '#define FINISH() END\n#define END ; void create()\ninherit ROOM FINISH() {}\n', {}, 'OUT_OF_SCOPE'),
        ('keyword-void', '#define void ;\ninherit ROOM void\ncreate() {}\n', {}, 'OUT_OF_SCOPE'),
        ('keyword-static', '#define static ; void create()\ninherit ROOM static {}\n', {}, 'OUT_OF_SCOPE'),
        ('keyword-neutral', '#define int 1\ninherit ROOM int x;\n', {}, 'QUARANTINED'),
        ('normal-int', 'inherit ROOM\nint x;\n', {}, 'QUARANTINED'),
        ('normal-string', 'inherit ROOM\nstring foo;\n', {}, 'QUARANTINED'),
        ('normal-private', 'inherit ROOM\nprivate void helper() {}\n', {}, 'QUARANTINED'),
        ('normal-static', 'inherit ROOM\nstatic int value;\n', {}, 'QUARANTINED'),
        ('comment-only', '#define FINISH() ; void create()\ninherit ROOM /* FINISH() {} */\ncreate() {}\n', {}, 'QUARANTINED'),
        ('string-only', '#define FINISH() ; void create()\ninherit "FINISH"\ncreate() {}\n', {}, 'QUARANTINED'),
        ('character-only', "#define X ;\ninherit ROOM 'X'\ncreate() {}\n", {}, 'QUARANTINED'),
        ('quoted-symbol-only', "#define FINISH() ; void create()\ninherit ROOM 'FINISH\ncreate() {}\n", {}, 'QUARANTINED'),
        ('heredoc-only', '#define FINISH() ; void create()\ninherit @END\nFINISH() {}\nEND\ncreate() {}\n', {}, 'QUARANTINED'),
        ('raw-echo-only', '#define FINISH() ; void create()\ninherit ROOM\n#echo FINISH() {}\ncreate() {}\n', {}, 'OUT_OF_SCOPE'),
        ('whitespace-call', '#define FINISH() ; void create()\ninherit ROOM FINISH () {}\n', {}, 'OUT_OF_SCOPE'),
        ('multiline-call', '#define FINISH() ; void create()\ninherit ROOM FINISH\n(\n)\n{}\n', {}, 'OUT_OF_SCOPE'),
        ('competing', '#define FINISH() 1\n#define FINISH() ; void create()\ninherit ROOM FINISH() {}\n', {}, 'OUT_OF_SCOPE'),
        ('cycle', '#define FINISH NEXT\n#define NEXT FINISH\ninherit ROOM FINISH() {}\n', {}, 'OUT_OF_SCOPE'),
        ('unused-cycle', '#define FINISH NEXT\n#define NEXT FINISH\ninherit ROOM\ncreate() {}\n', {}, 'QUARANTINED'),
        ('paste', '#define FINISH() F ## N\ninherit ROOM FINISH() {}\n', {}, 'OUT_OF_SCOPE'),
        ('invalid-function', '#define FINISH(x ;\ninherit ROOM FINISH() {}\n', {}, 'OUT_OF_SCOPE'),
        ('parameter-structural', '#define FINISH(x) x\ninherit ROOM FINISH(END) {}\n', {}, 'OUT_OF_SCOPE'),
        ('unused-unknown', '#define FINISH() F ## N\ninherit ROOM\ncreate() {}\n', {}, 'QUARANTINED'),
        ('neutral-function-alias', '#define FINISH() VALUE\n#define VALUE 1\ninherit ROOM FINISH() {}\n', {}, 'QUARANTINED'),
        ('uncertain-before-later-valid', '#define FINISH() ; void create()\ninherit ROOM FINISH() {}\ninherit "/custom/base";\n', {}, 'OUT_OF_SCOPE'),
        ('excluded-before-uncertain', '#define FINISH() ; void create()\ninherit NPC;\ninherit ROOM FINISH() {}\n', {}, 'OUT_OF_SCOPE'),
        ('valid-multiple', 'inherit ROOM;inherit "/custom/base";void create(){}\n', {}, 'PARTIAL'),
        ('valid-authored', 'inherit ROOM;void create(){}\n', {}, 'EXTRACTED'),
        ('valid-authored-short', 'inherit ROOM;void create(){set("short","x");}\n', {}, 'EXTRACTED'),
    ]

    def check(self, text, headers, status):
        for newline in ('\n', '\r\n'):
            raw = text.replace('\n', newline).encode()
            deps = {p: Source(p, h.replace('\n', newline).encode()) for p, h in headers.items()}
            r, ff = extract(raw, path='d/probe.c', dependencies=deps)
            with self.subTest(newline=repr(newline), text=text):
                self.assertEqual(status, r['status'])
                if status == 'OUT_OF_SCOPE':
                    self.assertFalse(r['supported_candidate'])
                    self.assertEqual([], r['facts'])
                    self.assertEqual([], r['direct_inherits'])
                    self.assertEqual([], r['category_candidates'])
                    self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(ff))
                elif status == 'QUARANTINED':
                    self.assertEqual([], r['facts'])
                    error = next(f for f in ff if f['code'] == 'SOURCE_SYNTAX_ERROR')
                    self.assertEqual('unterminated inherit', error['reason'])
                    self.assertEqual('inherit', error['provenance']['raw'])
                for f in ff + r['facts']:
                    p = f['provenance']
                    self.assertEqual(hashlib.sha256(raw).hexdigest(), p['source_sha256'])
                    self.assertEqual(raw[p['byte_start']:p['byte_end_exclusive']].decode(), p['raw'])
        return r, ff

    def test_function_and_keyword_boundary_matrix(self):
        for name, text, headers, status in self.CASES:
            with self.subTest(case=name): self.check(text, headers, status)

    def test_long_function_alias_chain(self):
        defs = ''.join(f'#define A{i} A{i+1}\n' for i in range(1100))+'#define A1100() ; void create()\n'
        self.check(defs+'inherit ROOM A0() {}\n', {}, 'OUT_OF_SCOPE')

    def test_nested_macro_provenance(self):
        _, ff = self.check('#include "outer.h"\ninherit ROOM CLOSE() {}\n',
                          {'d/outer.h':'#include "inner.h"\n', 'd/inner.h':'#define CLOSE() ; void create()\n'}, 'OUT_OF_SCOPE')
        self.assertTrue(all(f['provenance']['raw']=='CLOSE' for f in ff))

    def test_keyword_macro_provenance(self):
        _, ff = self.check('#define static ; void create()\ninherit ROOM static {}\n', {}, 'OUT_OF_SCOPE')
        self.assertTrue(all(f['provenance']['raw']=='static' for f in ff))

    def test_valid_authored_declaration_stays_lazy(self):
        with patch.object(RoomExtractor, 'inherit_boundary_uncertain', side_effect=AssertionError('must stay lazy')):
            self.check('inherit ROOM;void create(){}', {}, 'EXTRACTED')
            self.check(room('set("short","x");'), {}, 'EXTRACTED')


class P2F16RegressionTests(unittest.TestCase):
    # Handwritten original FR15 controls plus causal/residual-tail challenges.
    CASES = [
        ('primary-empty-object', '#define NOTHING\ninherit ROOM;\nvoid create(){ NOTHING }\n', {}, 'PARTIAL'),
        ('primary-handwritten-literal', 'inherit ROOM;\nvoid create(){ }\n', {}, 'EXTRACTED'),
        ('empty-alias', '#define EMPTY\n#define END EMPTY\ninherit ROOM;void create(){ END }\n', {}, 'PARTIAL'),
        ('empty-function', '#define ERASE()\ninherit ROOM;void create(){ ERASE() }\n', {}, 'PARTIAL'),
        ('header-empty', '#include "empty.h"\ninherit ROOM;void create(){ EMPTY }\n', {'d/empty.h': '#define EMPTY\n'}, 'PARTIAL'),
        ('nested-header-empty', '#include "outer.h"\ninherit ROOM;void create(){ EMPTY }\n', {'d/outer.h': '#include "inner.h"\n', 'd/inner.h': '#define EMPTY\n'}, 'PARTIAL'),
        ('standard-header-empty', '#include <empty.h>\ninherit ROOM;void create(){ EMPTY }\n', {'include/empty.h': '#define EMPTY\n'}, 'PARTIAL'),
        ('semicolon-macro', '#define END ;\ninherit ROOM;void create(){ END }\n', {}, 'OUT_OF_SCOPE'),
        ('complete-statement-macro', '#define DONE return;\ninherit ROOM;void create(){ DONE }\n', {}, 'OUT_OF_SCOPE'),
        ('complete-setter-macro', '#define DONE set("short","x");\ninherit ROOM;void create(){ DONE }\n', {}, 'OUT_OF_SCOPE'),
        ('neutral-literal-macro', '#define VALUE 1\ninherit ROOM;void create(){ VALUE }\n', {}, 'QUARANTINED'),
        ('unused-empty', '#define EMPTY\ninherit ROOM;void create(){ }\n', {}, 'PARTIAL'),
        ('earlier-not-tail', '#define EMPTY\ninherit ROOM;void create(){ EMPTY; set("short","x"); }\n', {}, 'PARTIAL'),
        ('raw-include-tail', 'inherit ROOM;void create(){ set("short","x")\n#include "end.h"\n}\n', {'d/end.h': ';\n'}, 'PARTIAL'),
        ('safe-include-tail', 'inherit ROOM;void create(){\n#include "safe.h"\n}\n', {'d/safe.h': '#define UNUSED 1\n'}, 'PARTIAL'),
        ('missing-include-tail', 'inherit ROOM;void create(){\n#include "missing.h"\n}\n', {}, 'OUT_OF_SCOPE'),
        ('unknown-directive-tail', 'inherit ROOM;void create(){\n#unknown foo\n}\n', {}, 'PARTIAL'),
        ('pragma-tail', 'inherit ROOM;void create(){\n#pragma strict_types\n}\n', {}, 'PARTIAL'),
        ('undef-tail', 'inherit ROOM;void create(){\n#undef UNUSED\n}\n', {}, 'PARTIAL'),
        ('define-tail', 'inherit ROOM;void create(){\n#define EMPTY\n}\n', {}, 'PARTIAL'),
        ('runtime-identifier', 'inherit ROOM;void create(){ ordinary_identifier }\n', {}, 'QUARANTINED'),
        ('runtime-call', 'inherit ROOM;void create(){ ordinary_call() }\n', {}, 'QUARANTINED'),
        ('setter-fragment', 'inherit ROOM;void create(){ set("short","x") }\n', {}, 'QUARANTINED'),
        ('unused-empty-runtime-tail', '#define EMPTY\ninherit ROOM;void create(){ ordinary_identifier }\n', {}, 'QUARANTINED'),
        ('literal-semicolon', 'inherit ROOM;void create(){ ; }\n', {}, 'EXTRACTED'),
        ('literal-return', 'inherit ROOM;void create(){ return; }\n', {}, 'PARTIAL'),
        ('literal-setter', 'inherit ROOM;void create(){ set("short","x"); }\n', {}, 'EXTRACTED'),
        ('literal-neutral-unfinished', 'inherit ROOM;void create(){ 1 }\n', {}, 'QUARANTINED'),
        ('unfinished-pragma', 'inherit ROOM;void create(){ ordinary_identifier\n#pragma strict_types\n}\n', {}, 'QUARANTINED'),
        ('unfinished-undef', 'inherit ROOM;void create(){ ordinary_identifier\n#undef UNUSED\n}\n', {}, 'QUARANTINED'),
        ('unfinished-define', 'inherit ROOM;void create(){ ordinary_identifier\n#define EMPTY\n}\n', {}, 'QUARANTINED'),
        ('parameter-empty', '#define ERASE(x)\ninherit ROOM;\nvoid create(){ ERASE(anything) }\n', {}, 'PARTIAL'),
        ('parameter-nested-empty', '#define ERASE(x)\ninherit ROOM;\nvoid create(){ ERASE(call(1, 2)) }\n', {}, 'PARTIAL'),
        ('cross-header', '#include "a.h"\n#include "b.h"\ninherit ROOM;\nvoid create(){ END }\n', {'d/a.h': '#define END EMPTY\n', 'd/b.h': '#define EMPTY\n'}, 'PARTIAL'),
        ('two-empty', '#define A\n#define B\ninherit ROOM;\nvoid create(){ A B }\n', {}, 'PARTIAL'),
        ('empty-runtime', '#define EMPTY\ninherit ROOM;\nvoid create(){ EMPTY ordinary_identifier }\n', {}, 'QUARANTINED'),
        ('runtime-empty', '#define EMPTY\ninherit ROOM;\nvoid create(){ ordinary_identifier EMPTY }\n', {}, 'QUARANTINED'),
        ('two-empty-runtime', '#define A\n#define B\ninherit ROOM;\nvoid create(){ A ordinary_identifier B }\n', {}, 'QUARANTINED'),
        ('neutral-string', '#define VALUE "x"\ninherit ROOM;\nvoid create(){ VALUE }\n', {}, 'QUARANTINED'),
        ('neutral-character', "#define VALUE 'x'\ninherit ROOM;\nvoid create(){ VALUE }\n", {}, 'QUARANTINED'),
        ('neutral-alias', '#define VALUE NUMBER\n#define NUMBER 1\ninherit ROOM;\nvoid create(){ VALUE }\n', {}, 'QUARANTINED'),
        ('neutral-function', '#define VALUE() 1\ninherit ROOM;\nvoid create(){ VALUE() }\n', {}, 'QUARANTINED'),
        ('uninvoked-function', '#define ERASE()\ninherit ROOM;\nvoid create(){ ERASE }\n', {}, 'QUARANTINED'),
        ('earlier-only', '#define EMPTY\ninherit ROOM;\nvoid create(){ EMPTY; ordinary_identifier }\n', {}, 'QUARANTINED'),
        ('cycle', '#define A B\n#define B A\ninherit ROOM;\nvoid create(){ A }\n', {}, 'OUT_OF_SCOPE'),
        ('competing', '#define A\n#define A 1\ninherit ROOM;\nvoid create(){ A }\n', {}, 'OUT_OF_SCOPE'),
        ('paste', '#define A X ## Y\ninherit ROOM;\nvoid create(){ A }\n', {}, 'OUT_OF_SCOPE'),
        ('invalid-function', '#define A(x\ninherit ROOM;\nvoid create(){ A() }\n', {}, 'OUT_OF_SCOPE'),
        ('parameter-dependent', '#define A(x) x\ninherit ROOM;\nvoid create(){ A(END) }\n', {}, 'OUT_OF_SCOPE'),
        ('complex', '#define A (1 + 2)\ninherit ROOM;\nvoid create(){ A }\n', {}, 'OUT_OF_SCOPE'),
        ('unknown-residual', '#define A X ## Y\ninherit ROOM;\nvoid create(){ ordinary_identifier A }\n', {}, 'OUT_OF_SCOPE'),
        ('empty-authored-semicolon', '#define EMPTY\ninherit ROOM;\nvoid create(){ EMPTY; }\n', {}, 'PARTIAL'),
        ('empty-before-setter', '#define EMPTY\ninherit ROOM;\nvoid create(){ EMPTY\nset("short","x"); }\n', {}, 'PARTIAL'),
        ('setter-before-empty', '#define EMPTY\ninherit ROOM;\nvoid create(){ set("short","x"); EMPTY }\n', {}, 'PARTIAL'),
        ('setter-before-two-empty', '#define A\n#define B\ninherit ROOM;\nvoid create(){ set("short","x"); A B }\n', {}, 'PARTIAL'),
        ('opaque-comment', '#define EMPTY\ninherit ROOM;\nvoid create(){ /* EMPTY */ ordinary_identifier }\n', {}, 'QUARANTINED'),
        ('opaque-string', '#define EMPTY\ninherit ROOM;\nvoid create(){ "EMPTY" }\n', {}, 'QUARANTINED'),
        ('opaque-character', "#define E\ninherit ROOM;\nvoid create(){ 'E' }\n", {}, 'QUARANTINED'),
        ('opaque-symbol', "#define EMPTY\ninherit ROOM;\nvoid create(){ 'EMPTY }\n", {}, 'QUARANTINED'),
        ('opaque-heredoc', '#define EMPTY\ninherit ROOM;\nvoid create(){ @END\nEMPTY\nEND\n }\n', {}, 'QUARANTINED'),
        ('opaque-echo', '#define EMPTY\ninherit ROOM;\nvoid create(){ \n#echo EMPTY\nordinary_identifier }\n', {}, 'QUARANTINED'),
        ('function-whitespace', '#define ERASE()\ninherit ROOM;\nvoid create(){ ERASE () }\n', {}, 'PARTIAL'),
        ('function-multiline', '#define ERASE()\ninherit ROOM;\nvoid create(){ ERASE\n() }\n', {}, 'PARTIAL'),
        ('object-to-function', '#define A E\n#define E()\ninherit ROOM;\nvoid create(){ A() }\n', {}, 'PARTIAL'),
        ('function-to-object', '#define A() E\n#define E\ninherit ROOM;\nvoid create(){ A() }\n', {}, 'PARTIAL'),
        ('object-empty-parentheses', '#define E\ninherit ROOM;\nvoid create(){ E() }\n', {}, 'QUARANTINED'),
        ('object-alias-empty-parentheses', '#define A E\n#define E\ninherit ROOM;\nvoid create(){ A() }\n', {}, 'QUARANTINED'),
        ('function-empty-extra-parentheses', '#define E()\ninherit ROOM;\nvoid create(){ E()() }\n', {}, 'QUARANTINED'),
        ('function-to-uninvoked-function', '#define A() E\n#define E()\ninherit ROOM;\nvoid create(){ A() }\n', {}, 'QUARANTINED'),
        ('uninvoked-alias-function', '#define A E\n#define E()\ninherit ROOM;\nvoid create(){ A }\n', {}, 'QUARANTINED'),
        ('function-empty-runtime', '#define E(x)\ninherit ROOM;\nvoid create(){ E(ignored) ordinary_identifier }\n', {}, 'QUARANTINED'),
        ('runtime-function-empty', '#define E(x)\ninherit ROOM;\nvoid create(){ ordinary_identifier E(ignored) }\n', {}, 'QUARANTINED'),
        ('two-function-empty', '#define A(x)\n#define B()\ninherit ROOM;\nvoid create(){ A(ignored) B() }\n', {}, 'PARTIAL'),
        ('neutral-function-argument', '#define V(x) 1\ninherit ROOM;\nvoid create(){ V(ignored) }\n', {}, 'QUARANTINED'),
        ('neutral-function-empty-argument', '#define V(x) 1\n#define E\ninherit ROOM;\nvoid create(){ V(E) }\n', {}, 'QUARANTINED'),
    ]

    def check(self, text, headers, status):
        for newline in ('\n', '\r\n'):
            raw = text.replace('\n', newline).encode()
            deps = {p: Source(p, h.replace('\n', newline).encode()) for p, h in headers.items()}
            r, ff = extract(raw, path='d/probe.c', dependencies=deps)
            with self.subTest(newline=repr(newline), text=text):
                self.assertEqual(status, r['status'])
                if status in {'OUT_OF_SCOPE', 'QUARANTINED'}:
                    self.assertEqual([], r['facts'])
                if status == 'QUARANTINED':
                    error = next(f for f in ff if f['code'] == 'SOURCE_SYNTAX_ERROR')
                    self.assertEqual('unterminated create statement', error['reason'])
                else:
                    self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(ff))
                for f in ff + r['facts']:
                    p = f['provenance']
                    self.assertEqual(hashlib.sha256(raw).hexdigest(), p['source_sha256'])
                    self.assertEqual(raw[p['byte_start']:p['byte_end_exclusive']].decode(), p['raw'])
        return r, ff

    def test_create_tail_matrix(self):
        for name, text, headers, status in self.CASES:
            with self.subTest(case=name): self.check(text, headers, status)

    def test_long_empty_alias_chains(self):
        definitions = ''.join(f'#define A{i} A{i+1}\n' for i in range(1100))
        self.check(definitions+'#define A1100\n'+room('A0'), {}, 'PARTIAL')
        self.check(definitions+'#define A1100(x)\n'+room('A0(ignored)'), {}, 'PARTIAL')

    def test_tail_refusal_suppresses_earlier_create_facts(self):
        text = '#define EMPTY\n'+room('set("short","x"); EMPTY')
        r, ff = self.check(text, {}, 'PARTIAL')
        self.assertEqual(['inherit'], [f['field'] for f in r['facts']])
        f = next(f for f in ff if 'create tail' in f['reason'])
        self.assertEqual('EMPTY', f['provenance']['raw'])
        self.assertEqual('create', f['provenance']['scope'])

    def test_nested_header_refusal_anchors_root_use(self):
        text = '#include "outer.h"\n'+room('ERASE(value)')
        r, ff = self.check(text, {'d/outer.h':'#include "inner.h"\n',
                                  'd/inner.h':'#define ERASE(x)\n'}, 'PARTIAL')
        self.assertEqual(['inherit'], [f['field'] for f in r['facts']])
        f = next(f for f in ff if 'create tail' in f['reason'])
        self.assertEqual('ERASE', f['provenance']['raw'])
        self.assertEqual('d/probe.c', f['provenance']['source_path'])

    def test_complete_authored_bodies_stay_lazy(self):
        with patch.object(RoomExtractor, 'create_tail_uncertain_use', side_effect=AssertionError('must stay lazy')):
            self.check(room(''), {}, 'EXTRACTED')
            self.check(room('set("short","x");'), {}, 'EXTRACTED')


class P2F17RegressionTests(unittest.TestCase):
    # Handwritten source and contract counts, never generated expected output.
    CASES = [
        ('key-alias', '#define K KEY\n#define KEY "north"\ninherit ROOM;\nvoid create(){set("exits",(["north":"/a", K:"/b"]));}\n', {}, 0),
        ('key-function', '#define KEY() "north"\ninherit ROOM;\nvoid create(){set("exits",(["north":"/a", KEY():"/b"]));}\n', {}, 0),
        ('key-parameter', '#define KEY(x) x\ninherit ROOM;\nvoid create(){set("exits",(["north":"/a", KEY("north"):"/b"]));}\n', {}, 0),
        ('key-header', '#include "defs.h"\ninherit ROOM;\nvoid create(){set("exits",(["north":"/a", KEY:"/b"]));}\n', {'d/defs.h': '#define KEY "north"\n'}, 0),
        ('key-nested', '#include "outer.h"\ninherit ROOM;\nvoid create(){set("exits",(["north":"/a", KEY:"/b"]));}\n', {'d/outer.h': '#include "inner.h"\n', 'd/inner.h': '#define KEY "north"\n'}, 0),
        ('key-standard', '#include <defs.h>\ninherit ROOM;\nvoid create(){set("exits",(["north":"/a", KEY:"/b"]));}\n', {'include/defs.h': '#define KEY "north"\n'}, 0),
        ('key-cross-header', '#include "a.h"\n#include "b.h"\ninherit ROOM;\nvoid create(){set("exits",(["north":"/a", K:"/b"]));}\n', {'d/a.h': '#define K KEY\n', 'd/b.h': '#define KEY "north"\n'}, 0),
        ('key-before-literal', '#define KEY "north"\ninherit ROOM;\nvoid create(){set("exits",([KEY:"/b", "north":"/a"]));}\n', {}, 0),
        ('key-between-literals', '#define KEY "north"\ninherit ROOM;\nvoid create(){set("exits",(["north":"/a", KEY:"/b", "east":"/e"]));}\n', {}, 0),
        ('key-only', '#define KEY "north"\ninherit ROOM;\nvoid create(){set("exits",([KEY:"/b"]));}\n', {}, 0),
        ('value-after-literal', '#define TARGET "/b"\ninherit ROOM;\nvoid create(){set("exits",(["north":"/a", "south":TARGET]));}\n', {}, 0),
        ('value-before-literal', '#define TARGET "/b"\ninherit ROOM;\nvoid create(){set("exits",(["south":TARGET, "north":"/a"]));}\n', {}, 0),
        ('value-function', '#define TARGET() "/b"\ninherit ROOM;\nvoid create(){set("exits",(["north":"/a", "south":TARGET()]));}\n', {}, 0),
        ('empty-value-prefix', '#define EMPTY\ninherit ROOM;\nvoid create(){set("exits",(["north":"/a", "south":EMPTY "/b"]));}\n', {}, 0),
        ('entry-suffix', '#define SUFFIX\ninherit ROOM;\nvoid create(){set("exits",(["north":"/a", "south":"/b" SUFFIX]));}\n', {}, 0),
        ('literal-equivalent', 'inherit ROOM;\nvoid create(){set("exits",(["north":"/a", "south":"/b"]));}\n', {}, 2),
        ('whole-entry-object', '#define ENTRY "south":"/b"\ninherit ROOM;\nvoid create(){set("exits",(["north":"/a", ENTRY]));}\n', {}, 0),
        ('whole-entry-function', '#define ENTRY() "south":"/b"\ninherit ROOM;\nvoid create(){set("exits",(["north":"/a", ENTRY()]));}\n', {}, 0),
        ('comma-object', '#define COMMA ,\ninherit ROOM;\nvoid create(){set("exits",(["north":"/a" COMMA "south":"/b"]));}\n', {}, 0),
        ('comma-function', '#define COMMA() ,\ninherit ROOM;\nvoid create(){set("exits",(["north":"/a" COMMA() "south":"/b"]));}\n', {}, 0),
        ('colon-object', '#define COLON :\ninherit ROOM;\nvoid create(){set("exits",(["north":"/a", "south" COLON "/b"]));}\n', {}, 0),
        ('colon-alias', '#define C COLON\n#define COLON :\ninherit ROOM;\nvoid create(){set("exits",(["north":"/a", "south" C "/b"]));}\n', {}, 0),
        ('raw-entry', 'inherit ROOM;\nvoid create(){set("exits",(["north":"/a",\n#include "entry.h"\n]));}\n', {'d/entry.h': '"south":"/b"\n'}, 0),
        ('raw-comma', 'inherit ROOM;\nvoid create(){set("exits",(["north":"/a"\n#include "comma.h"\n"south":"/b"]));}\n', {'d/comma.h': ',\n'}, 0),
        ('raw-key', 'inherit ROOM;\nvoid create(){set("exits",(["north":"/a",\n#include "key.h"\n:"/b"]));}\n', {'d/key.h': '"south"\n'}, 0),
        ('raw-value', 'inherit ROOM;\nvoid create(){set("exits",(["north":"/a", "south":\n#include "value.h"\n]));}\n', {'d/value.h': '"/b"\n'}, 0),
        ('raw-colon', 'inherit ROOM;\nvoid create(){set("exits",(["north":"/a", "south"\n#include "colon.h"\n"/b"]));}\n', {'d/colon.h': ':\n'}, 0),
        ('raw-nested-entry', 'inherit ROOM;\nvoid create(){set("exits",(["north":"/a",\n#include "outer.h"\n]));}\n', {'d/outer.h': '#include "inner.h"\n', 'd/inner.h': '"south":"/b"\n'}, 0),
        ('raw-standard-entry', 'inherit ROOM;\nvoid create(){set("exits",(["north":"/a",\n#include <entry.h>\n]));}\n', {'include/entry.h': '"south":"/b"\n'}, 0),
        ('missing-include', 'inherit ROOM;\nvoid create(){set("exits",(["north":"/a",\n#include "missing.h"\n]));}\n', {}, 0),
        ('empty-function-fragment', '#define DROP(x)\ninherit ROOM;\nvoid create(){set("exits",(["north":"/a", "south":DROP(:)"/b"]));}\n', {}, 0),
        ('empty-middle', 'inherit ROOM;\nvoid create(){set("exits",(["north":"/a",,"south":"/b"]));}\n', {}, -1),
        ('missing-colon', 'inherit ROOM;\nvoid create(){set("exits",(["north":"/a", "south" "/b"]));}\n', {}, -1),
        ('empty-key', 'inherit ROOM;\nvoid create(){set("exits",(["north":"/a", :"/b"]));}\n', {}, -1),
        ('empty-value', 'inherit ROOM;\nvoid create(){set("exits",(["north":"/a", "south":]));}\n', {}, -1),
        ('missing-comma', 'inherit ROOM;\nvoid create(){set("exits",(["north":"/a" "south":"/b"]));}\n', {}, 0),
        ('unfinished-entry', 'inherit ROOM;\nvoid create(){set("exits",(["north":"/a", "south"]));}\n', {}, -1),
        ('unused-structural', '#define UNUSED ,\ninherit ROOM;\nvoid create(){set("exits",(["north":"/a",,"south":"/b"]));}\n', {}, -1),
        ('unreferenced-header', 'inherit ROOM;\nvoid create(){set("exits",(["north":"/a",,"south":"/b"]));}\n', {'d/unused.h': ',\n'}, -1),
        ('neutral-cannot-repair', '#define VALUE "/b"\ninherit ROOM;\nvoid create(){set("exits",(["north":"/a",,"south":VALUE]));}\n', {}, -1),
        ('unrelated-include', '#include "safe.h"\ninherit ROOM;\nvoid create(){set("exits",(["north":"/a",,"south":"/b"]));}\n', {'d/safe.h': '#define UNUSED 1\n'}, -1),
        ('primary-formatted', '#define KEY "north"\ninherit ROOM;\nvoid create(){\n    set("exits", ([\n        "north": "/a",\n        KEY: "/b"\n    ]));\n}\n', {}, 0),
        ('complete-control', 'inherit ROOM;\nvoid create(){set("exits",(["north":"/a", "south":"/b"]));}\n', {}, 2),
        ('runtime-scope', 'inherit ROOM;\nvoid create(){set("exits",(["north":"/a", runtime_key:"/b"]));}\n', {}, 1),
        ('conditional-scope', 'inherit ROOM;\nvoid create(){set("exits",(["north":"/a", flag ? "n" : "s":"/b"]));}\n', {}, 1),
        ('uninvoked-scope', '#define KEY() "north"\ninherit ROOM;\nvoid create(){set("exits",(["north":"/a", KEY:"/b"]));}\n', {}, 1),
        ('unused-definition', '#define UNUSED ,\ninherit ROOM;\nvoid create(){set("exits",(["north":"/a", "south":"/b"]));}\n', {}, 2),
        ('unreferenced-header', 'inherit ROOM;\nvoid create(){set("exits",(["north":"/a", "south":"/b"]));}\n', {'d/unused.h': ',\n'}, 2),
        ('unrelated-directive', 'inherit ROOM;\nvoid create(){\n#pragma strict_types\nset("exits",(["north":"/a", "south":"/b"]));}\n', {}, 2),
        ('unused-header-definition', '#include "key.h"\ninherit ROOM;\nvoid create(){set("exits",(["north":"/a", "south":"/b"]));}\n', {'d/key.h': '#define KEY "north"\n'}, 2),
        ('duplicate-literal', 'inherit ROOM;\nvoid create(){set("exits",(["north":"/a","north":"/b"]));}\n', {}, 2),
        ('normalized-literal', 'inherit ROOM;\nvoid create(){set("exits",(["north":__DIR__+"a","south":__DIR__"b"]));}\n', {}, 2),
        ('normalized-uncertain', '#define KEY "north"\ninherit ROOM;\nvoid create(){set("exits",(["north":__DIR__+"a",KEY:"/b"]));}\n', {}, 0),
        ('independent-short', '#define KEY "north"\ninherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a", KEY:"/b"]));}\n', {}, 0),
        ('reliable-then-uncertain', '#define KEY "north"\ninherit ROOM;\nvoid create(){set("exits",(["north":"/a", "south":"/b"]));set("exits",(["north":"/a", KEY:"/b"]));}\n', {}, 0),
        ('uncertain-then-reliable', '#define KEY "north"\ninherit ROOM;\nvoid create(){set("exits",(["north":"/a", KEY:"/b"]));set("exits",(["north":"/a", "south":"/b"]));}\n', {}, 0),
        ('both-reliable', 'inherit ROOM;\nvoid create(){set("exits",(["north":"/a", "south":"/b"]));set("exits",(["north":"/a", "south":"/b"]));}\n', {}, 4),
        ('add-before', 'inherit ROOM;\nvoid create(){add("exits",(["west":"/c"]));set("exits",(["north":"/a", "south":"/b"]));}\n', {}, 0),
        ('add-after', 'inherit ROOM;\nvoid create(){set("exits",(["north":"/a", "south":"/b"]));add("exits",(["west":"/c"]));}\n', {}, 0),
        ('delete-before', 'inherit ROOM;\nvoid create(){delete("exits");set("exits",(["north":"/a", "south":"/b"]));}\n', {}, 0),
        ('delete-after', 'inherit ROOM;\nvoid create(){set("exits",(["north":"/a", "south":"/b"]));delete("exits");}\n', {}, 0),
        ('nested-key-before', 'inherit ROOM;\nvoid create(){set("exits/west","/c");set("exits",(["north":"/a", "south":"/b"]));}\n', {}, 0),
        ('nested-key-after', 'inherit ROOM;\nvoid create(){set("exits",(["north":"/a", "south":"/b"]));set("exits/west","/c");}\n', {}, 0),
        ('delete-path-before', 'inherit ROOM;\nvoid create(){delete("exits/west");set("exits",(["north":"/a", "south":"/b"]));}\n', {}, 0),
        ('delete-path-after', 'inherit ROOM;\nvoid create(){set("exits",(["north":"/a", "south":"/b"]));delete("exits/west");}\n', {}, 0),
        ('computed-before', 'inherit ROOM;\nvoid create(){set("exits",runtime_map);set("exits",(["north":"/a", "south":"/b"]));}\n', {}, 0),
        ('computed-after', 'inherit ROOM;\nvoid create(){set("exits",(["north":"/a", "south":"/b"]));set("exits",runtime_map);}\n', {}, 0),
        ('other-field-mutation', 'inherit ROOM;\nvoid create(){set("exits",(["north":"/a", "south":"/b"]));add("counter",1);delete("counter");}\n', {}, 2),
        ('value-header', '#include "target.h"\ninherit ROOM;\nvoid create(){set("exits",(["n":"/a","s":TARGET]));}\n', {'d/target.h': '#define TARGET "/b"\n'}, 0),
        ('value-alias', '#define TARGET VALUE\n#define VALUE "/b"\ninherit ROOM;\nvoid create(){set("exits",(["n":"/a","s":TARGET]));}\n', {}, 0),
        ('empty-alias', '#define EMPTY NOTHING\n#define NOTHING\ninherit ROOM;\nvoid create(){set("exits",(["n":"/a","s":EMPTY "/b"]));}\n', {}, 0),
        ('empty-header', '#include "empty.h"\ninherit ROOM;\nvoid create(){set("exits",(["n":"/a","s":"/b" EMPTY]));}\n', {'d/empty.h': '#define EMPTY\n'}, 0),
        ('function-whitespace', '#define KEY() "s"\ninherit ROOM;\nvoid create(){set("exits",(["n":"/a",KEY /* gap */ ():"/b"]));}\n', {}, 0),
        ('opaque-macro-string', '#define KEY "north"\ninherit ROOM;\nvoid create(){set("exits",(["KEY":"/KEY"]));}\n', {}, 1),
        ('unknown-directive', 'inherit ROOM;\nvoid create(){set("exits",(["n":"/a",\n#unknown mapping\n"s":"/b"]));}\n', {}, 0),
        ('neutral-macro-real-defect', '#define TARGET "/a"\ninherit ROOM;\nvoid create(){set("exits",(["n":TARGET,,"s":"/b"]));}\n', {}, -1),
    ]

    def test_mapping_fact_safety_matrix(self):
        for name, text, headers, expected in self.CASES:
            for newline in ('\n', '\r\n'):
                with self.subTest(case=name, newline=repr(newline)):
                    raw = text.replace('\n', newline).encode()
                    deps = {p: Source(p, h.replace('\n', newline).encode()) for p, h in headers.items()}
                    r, ff = extract(raw, path='d/probe.c', dependencies=deps)
                    self.assertEqual(max(0, expected), len(fields(r, 'exit')))
                    self.assertEqual(expected == -1, r['status'] == 'QUARANTINED')
                    if expected == -1:
                        self.assertEqual([], r['facts'])
                        self.assertIn('SOURCE_SYNTAX_ERROR', codes(ff))
                    else:
                        self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(ff))
                    for f in ff + r['facts']:
                        p = f['provenance']
                        self.assertEqual(hashlib.sha256(raw).hexdigest(), p['source_sha256'])
                        self.assertEqual(raw[p['byte_start']:p['byte_end_exclusive']].decode(), p['raw'])
                        self.assertEqual('UNREVIEWED', f['review_state'])

    def test_no_exit_fact_is_created_before_refusal(self):
        for entries in ('KEY:"/b", "north":"/a"', '"north":"/a", KEY:"/b"',
                        '"north":"/a", KEY:"/b", "east":"/c"'):
            text = '#define KEY "south"\n' + room('set("short","room");set("exits",(['+entries+']));')
            original = RoomExtractor.fact
            def reject_exit(instance, field, *args, **kwargs):
                self.assertNotEqual('exit', field)
                return original(instance, field, *args, **kwargs)
            with patch.object(RoomExtractor, 'fact', reject_exit):
                r, ff = extract(text)
            self.assertEqual(['inherit', 'short'], [f['field'] for f in r['facts']])
            finding = next(f for f in ff if 'Actual preprocessing use makes this exit mapping' in f['reason'])
            self.assertEqual('KEY', finding['provenance']['raw'])
            self.assertTrue(finding['prevents_supported_consumption'])

    def test_reliable_order_identity_normalization_and_duplicates(self):
        text = room('set("exits",(["n":"/a","n":"/b","s":__DIR__+"c"]));')
        r, ff = extract(text)
        exits = fields(r, 'exit')
        self.assertEqual(['n', 'n', 's'], [f['value']['direction'] for f in exits])
        self.assertIn('DUPLICATE_DECLARATION', codes(ff))
        self.assertEqual('STATIC_NORMALIZED', exits[-1]['classification'])
        for f in exits:
            p = f['provenance']
            identity = f"d/test/room.c\0{hashlib.sha256(text.encode()).hexdigest()}\0exit\0{p['byte_start']}\0{p['byte_end_exclusive']}"
            self.assertEqual(hashlib.sha256(identity.encode()).hexdigest(), f['fact_id'])
        self.assertEqual((r, ff), extract(text))

    def test_uninvoked_and_runtime_dynamic_scope(self):
        for prefix, key in (('', 'runtime_key'), ('', 'flag ? "n" : "s"'), ('#define KEY() "s"\n', 'KEY')):
            r, ff = extract(prefix+room('set("exits",(["n":"/a",'+key+':"/b"]));'))
            self.assertEqual(1, len(fields(r, 'exit')))
            self.assertFalse(any('Actual preprocessing use makes this exit mapping' in f['reason'] for f in ff))

    def test_mutation_sequence_preserves_independent_facts(self):
        for mutation in ('add("exits",(["w":"/c"]));', 'delete("exits");', 'set("exits/w","/c");'):
            for before in (True, False):
                mapping = 'set("exits",(["n":"/a"]));'
                r, ff = extract(room('set("short","room");'+(mutation+mapping if before else mapping+mutation)))
                self.assertEqual(['inherit', 'short'], [f['field'] for f in r['facts']])
                self.assertIn('ORDER_SENSITIVE_MUTATION', codes(ff))

    def test_callback_mutations_remain_review_dependencies(self):
        r, ff = extract(room('set("exits",(["n":"/a"]));',
                             'void reset(){delete("exits/n");ob->set("exits",other);}'))
        self.assertEqual(1, len(fields(r, 'exit')))
        self.assertEqual(2, sum(f['code'] == 'ORDER_SENSITIVE_MUTATION' for f in ff))


class P2F18RegressionTests(unittest.TestCase):
    # Handwritten expectations: inherited dispatch is distinct from direct calls.
    CASES = [
        ('prompt-primary', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));if(condition){set("exits",variable);}}\n', {}, 0),
        ('computed-before', 'inherit ROOM;\nvoid create(){set("short","room");{set("exits",variable);}set("exits",(["north":"/a"]));}\n', {}, 0),
        ('computed-after', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));{set("exits",variable);}}\n', {}, 0),
        ('computed-between', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));{set("exits",variable);}set("exits",(["north":"/a"]));}\n', {}, 0),
        ('literal-before', 'inherit ROOM;\nvoid create(){set("short","room");{set("exits",(["south":"/b"]));}set("exits",(["north":"/a"]));}\n', {}, 0),
        ('literal-after', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));{set("exits",(["south":"/b"]));}}\n', {}, 0),
        ('literal-between', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));{set("exits",(["south":"/b"]));}set("exits",(["north":"/a"]));}\n', {}, 0),
        ('macro-before', '#define KEY "south"\ninherit ROOM;\nvoid create(){set("short","room");{set("exits",([KEY:"/b"]));}set("exits",(["north":"/a"]));}\n', {}, 0),
        ('macro-after', '#define KEY "south"\ninherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));{set("exits",([KEY:"/b"]));}}\n', {}, 0),
        ('macro-between', '#define KEY "south"\ninherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));{set("exits",([KEY:"/b"]));}set("exits",(["north":"/a"]));}\n', {}, 0),
        ('two-level', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));if(condition){while(other){set("exits",variable);}}}\n', {}, 0),
        ('three-level', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));if(condition){while(other){{set("exits",variable);}}}}\n', {}, 0),
        ('unbraced-if', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));if(condition) set("exits",variable);}\n', {}, 0),
        ('unbraced-while', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));while(condition) set("exits",variable);}\n', {}, 0),
        ('switch', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));switch(flag){case 1:set("exits",variable);break;}}\n', {}, 0),
        ('flat-set-subtree', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));set("exits/e","/b");}\n', {}, 0),
        ('nested-set-subtree', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));{set("exits/e","/b");}}\n', {}, 0),
        ('flat-add-whole', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));add("exits",variable);}\n', {}, 0),
        ('nested-add-whole', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));{add("exits",variable);}}\n', {}, 0),
        ('flat-add-subtree', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));add("exits/e",variable);}\n', {}, 0),
        ('nested-add-subtree', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));{add("exits/e",variable);}}\n', {}, 0),
        ('flat-delete-whole', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));delete("exits");}\n', {}, 0),
        ('nested-delete-whole', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));{delete("exits");}}\n', {}, 0),
        ('flat-delete-subtree', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));delete("exits/e");}\n', {}, 0),
        ('nested-delete-subtree', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));{delete("exits/e");}}\n', {}, 0),
        ('unrelated-short', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));if(condition){set("short","x");}}\n', {}, 1),
        ('unrelated-name', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));if(condition){set("name","x");}}\n', {}, 1),
        ('unrelated-long', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));if(condition){set("long","x");}}\n', {}, 1),
        ('unrelated-indoors', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));if(condition){set("indoors","x");}}\n', {}, 1),
        ('unrelated-call', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));if(condition){foo();}}\n', {}, 1),
        ('unrelated-expression', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));if(condition){x=x+1;}}\n', {}, 1),
        ('cross-set-exits', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));if(condition){other->set("exits",variable);}}\n', {}, 1),
        ('cross-set-exits-e', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));if(condition){other->set("exits/e",variable);}}\n', {}, 1),
        ('cross-add-exits', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));if(condition){other->add("exits",variable);}}\n', {}, 1),
        ('cross-add-exits-e', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));if(condition){other->add("exits/e",variable);}}\n', {}, 1),
        ('cross-delete-exits', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));if(condition){other->delete("exits");}}\n', {}, 1),
        ('cross-delete-exits-e', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));if(condition){other->delete("exits/e");}}\n', {}, 1),
        ('inherited-nested', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));if(condition){::set("exits",variable);}}\n', {}, 0),
        ('inherited-flat', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));::set("exits",variable);}\n', {}, 0),
        ('include-nested', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));{\n#include "mutate.h"\n}}\n', {'d/mutate.h': 'set("exits",variable);\n'}, 0),
        ('macro-hazard', '#define MUTATE() set("exits",variable)\ninherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));{MUTATE();}}\n', {}, 0),
        ('two-reliable', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));set("exits",(["north":"/a"]));}\n', {}, 2),
        ('single-reliable', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));}\n', {}, 1),
        ('normalized-reliable', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["n":__DIR__+"a"]));}\n', {}, 1),
        ('callback-only', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));}\nvoid reset(){set("exits",variable);}\n', {}, 1),
        ('duplicate-create', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));}\nvoid create(){set("exits",variable);}\n', {}, 0),
        ('shadowed-set', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));}\nvoid set(string key,mixed value){}\n', {}, 0),
        ('missing-include', '#include "missing.h"\ninherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));}\n', {}, 0),
        ('true-mapping', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["n":"/a",,"s":"/b"]));}\n', {}, -1),
        ('true-tail', 'inherit ROOM;\nvoid create(){set("short","room");set("exits",(["north":"/a"]));unfinished}\n', {}, -1),
    ]

    def test_nested_create_matrix(self):
        for name, text, headers, expected in self.CASES:
            for newline in ('\n', '\r\n'):
                with self.subTest(case=name, newline=repr(newline)):
                    raw = text.replace('\n', newline).encode()
                    deps = {p: Source(p, h.replace('\n', newline).encode()) for p, h in headers.items()}
                    r, ff = extract(raw, path='d/probe.c', dependencies=deps)
                    self.assertEqual(max(0, expected), len(fields(r, 'exit')))
                    self.assertEqual(expected == -1, r['status'] == 'QUARANTINED')
                    for f in r['facts'] + ff:
                        p = f['provenance']
                        self.assertEqual(hashlib.sha256(raw).hexdigest(), p['source_sha256'])
                        self.assertEqual(raw[p['byte_start']:p['byte_end_exclusive']].decode(), p['raw'])

    def test_suppressed_exit_ids_never_created(self):
        original = RoomExtractor.fact
        def reject_exit(instance, field, *args, **kwargs):
            self.assertNotEqual('exit', field)
            return original(instance, field, *args, **kwargs)
        reliable = 'set("exits",(["n":"/a"]));'
        nested = '{set("exits",variable);}'
        for body in (nested+reliable, reliable+nested, reliable+nested+reliable):
            with patch.object(RoomExtractor, 'fact', reject_exit):
                r, ff = extract(room('set("short","room");'+body))
            self.assertEqual(['inherit', 'short'], [f['field'] for f in r['facts']])
            f = next(f for f in ff if 'Local exit mutation in an unsupported' in f['reason'])
            self.assertEqual('set("exits"', f['provenance']['raw'])
            self.assertTrue(f['prevents_supported_consumption'])

    def test_flat_literal_identity_is_unchanged(self):
        text = room('set("exits",(["n":__DIR__+"a","s":"/b"]));')
        r, ff = extract(text)
        self.assertEqual(['n', 's'], [f['value']['direction'] for f in fields(r, 'exit')])
        for f in fields(r, 'exit'):
            p = f['provenance']
            identity = f"d/test/room.c\0{hashlib.sha256(text.encode()).hexdigest()}\0exit\0{p['byte_start']}\0{p['byte_end_exclusive']}"
            self.assertEqual(hashlib.sha256(identity.encode()).hexdigest(), f['fact_id'])
        self.assertEqual((r, ff), extract(text))

    def test_opaque_text_and_unrelated_nested_statements_do_not_veto(self):
        for body in ('{foo();}', '{set("short","exits");}', '{/* set("exits",x); */}',
                     '{"set(\"exits\",x)";}', '{set("exits_other",x);}'):
            r, ff = extract(room('set("exits",(["n":"/a"]));'+body))
            self.assertEqual(1, len(fields(r, 'exit')))
            self.assertFalse(any('Local exit mutation in an unsupported' in f['reason'] for f in ff))

    def test_direct_local_mutations_in_unbraced_regions(self):
        for control in ('if(flag)', 'while(flag)', 'for(i=0;i<1;i++)'):
            r, ff = extract(room('set("exits",(["n":"/a"]));'+control+' set("exits",variable);'))
            self.assertEqual([], fields(r, 'exit'))
            self.assertIn('ORDER_SENSITIVE_MUTATION', codes(ff))

    def test_receiver_findings_preserve_authored_identity(self):
        for call in ('set("exits",x)', 'add("exits/e",x)', 'delete("exits")'):
            for prefix in ('', '::', 'other->'):
                r, ff = extract(room('set("exits",(["n":"/a"]));{'+prefix+call+';}'))
                self.assertEqual(1 if prefix == 'other->' else 0, len(fields(r, 'exit')))
                local = [f for f in ff if 'Local exit mutation in an unsupported' in f['reason']]
                inherited = [f for f in ff if 'Inherited-qualified exit call' in f['reason']]
                self.assertEqual(prefix == '', bool(local))
                self.assertEqual(prefix == '::', bool(inherited))
                if inherited:
                    self.assertEqual('UNSUPPORTED_CONSTRUCT', inherited[0]['code'])
                    self.assertTrue(inherited[0]['provenance']['raw'].startswith('::'))


class P2F19RegressionTests(unittest.TestCase):
    SAFE = 'set("exits",(["north":"/a"]));'
    INNER = 'set("exits",(["south":"/b"]))'
    # Expectations describe authored calls, never evaluated expression results.
    CASES = [
        *[(field, 'set("exits",(["north":"/a"]));set("' + field + '",sizeof(set("exits",(["south":"/b"]))));', 0)
          for field in ('short', 'name', 'long', 'indoors', 'outdoors', 'no_fight', 'no_clean_up', 'objects', 'foo')],
        ('deep', SAFE + 'set("indoors",foo(bar(baz(' + INNER + '))));', 0),
        ('conditional', SAFE + 'set("indoors",flag ? ' + INNER + ' : 1);', 0),
        ('before', 'set("objects",' + INNER + ');' + SAFE, 0),
        ('between', SAFE + 'set("objects",' + INNER + ');' + SAFE, 0),
        ('mapping-inner', 'set("exits",(["north":"/a","south":' + INNER + ']));', 0),
        ('computed-inner', SAFE + 'set("exits",compute(' + INNER + '));', 0),
        ('generic-wrapper', SAFE + 'foo(' + INNER + ');', 0),
        ('nested', SAFE + '{' + INNER + ';}', 0),
        ('nested-deep', SAFE + '{{{' + INNER + ';}}}', 0),
        ('nested-before', '{' + INNER + ';}' + SAFE, 0),
        ('nested-between', SAFE + '{' + INNER + ';}' + SAFE, 0),
        ('unrelated-flag', SAFE + 'set("indoors",sizeof(foo()));', 1),
        ('unrelated-text', SAFE + 'set("short",some_dynamic_value);', 1),
        ('comment', SAFE + 'set("indoors",foo(/* set("exits",x) */));', 1),
        ('string', SAFE + r'set("short","set(\"exits\", x)");', 1),
        ('character', SAFE + "set(\"indoors\",'(');", 1),
        ('heredoc', SAFE + '\nset("long",@TEXT\nset("exits",x);\nTEXT\n);', 1),
        ('echo', SAFE + '\n#echo set("exits",x);\n', 1),
        ('single-flat', SAFE, 1),
        ('two-flat', SAFE + SAFE, 2),
        ('computed-flat', SAFE + 'set("exits",variable);', 0),
        ('flat-delete', SAFE + 'delete("exits/e");', 0),
    ]

    def test_value_matrix_lf_crlf(self):
        for name, body, expected in self.CASES:
            for newline in ('\n', '\r\n'):
                with self.subTest(case=name, newline=repr(newline)):
                    raw = room(body).replace('\n', newline).encode()
                    r, ff = extract(raw)
                    self.assertEqual(expected, len(fields(r, 'exit')))
                    self.assertNotEqual('QUARANTINED', r['status'])
                    for f in r['facts'] + ff:
                        p = f['provenance']
                        self.assertEqual(hashlib.sha256(raw).hexdigest(), p['source_sha256'])
                        self.assertEqual(raw[p['byte_start']:p['byte_end_exclusive']].decode(), p['raw'])

    def test_receiver_and_key_family(self):
        for call in ('set("exits",x)', 'set("exits/e",x)', 'add("exits",x)',
                     'add("exits/e",x)', 'delete("exits")', 'delete("exits/e")'):
            for prefix in ('', '::', 'other->'):
                with self.subTest(call=call, prefix=prefix):
                    r, ff = extract(room(self.SAFE + 'set("objects",' + prefix + call + ');'))
                    self.assertEqual(1 if prefix == 'other->' else 0, len(fields(r, 'exit')))
                    inherited = [f for f in ff if 'Inherited-qualified exit call' in f['reason']]
                    self.assertEqual(prefix == '::', bool(inherited))
                    if inherited:
                        self.assertTrue(inherited[0]['provenance']['raw'].startswith('::'))

    def test_exact_registration_and_no_suppressed_fact_ids(self):
        original = RoomExtractor.fact
        def reject_exit(instance, field, *args, **kwargs):
            self.assertNotEqual('exit', field)
            return original(instance, field, *args, **kwargs)
        text = room('set("short","independent");set("exits",(["north":"/a","south":' + self.INNER + ']));')
        extractor = RoomExtractor(Source('d/probe.c', text.encode()), set(), {})
        with patch.object(RoomExtractor, 'fact', reject_exit):
            r, ff = extractor.extract()
        outer = text.index('set("exits"')
        inner = text.index('set("exits"', outer + 1)
        self.assertEqual({outer}, extractor.flat_exit_setter_starts)
        self.assertEqual({inner}, extractor.exit_uncertainty_call_starts)
        self.assertEqual(['inherit', 'short'], [f['field'] for f in r['facts']])
        self.assertEqual([], extractor.exit_candidates)

    def test_finalizer_catches_calls_even_without_early_scanner(self):
        for body in ('foo(' + self.INNER + ');', '{' + self.INNER + ';}',
                     'set("indoors",sizeof(' + self.INNER + '));'):
            with patch.object(RoomExtractor, 'unsupported_exit_mutations'):
                r, ff = extract(room(self.SAFE + body))
            self.assertEqual([], fields(r, 'exit'))
            self.assertTrue(any('prevents reliable exit facts' in f['reason'] for f in ff))

    def test_early_and_finalizer_findings_are_deduplicated(self):
        for prefix in ('', '::'):
            for call in (self.INNER, 'add("exits",x)', 'delete("exits/e")'):
                r, ff = extract(room(self.SAFE + '{' + prefix + call + ';}'))
                refusals = [f for f in ff if 'exit sequence uncertain' in f['reason']
                            or 'prevents reliable exit facts' in f['reason']]
                self.assertEqual(1, len(refusals))
                self.assertEqual([], fields(r, 'exit'))

    def test_flat_exits_keep_stable_authored_ids(self):
        text = room(self.SAFE + self.SAFE)
        r, ff = extract(text)
        self.assertEqual(2, len(fields(r, 'exit')))
        for f in fields(r, 'exit'):
            p = f['provenance']
            identity = f"d/test/room.c\0{hashlib.sha256(text.encode()).hexdigest()}\0exit\0{p['byte_start']}\0{p['byte_end_exclusive']}"
            self.assertEqual(hashlib.sha256(identity.encode()).hexdigest(), f['fact_id'])
        self.assertEqual((r, ff), extract(text))

    def test_registration_does_not_override_mapping_or_environment(self):
        for text in ('#define KEY "s"\n' + room(self.SAFE + 'set("exits",([KEY:"/b"]));'),
                     room(self.SAFE + 'set("exits",variable);'),
                     room(self.SAFE, 'void create(){set("exits",x);}\n'),
                     room(self.SAFE, 'void set(string key,mixed value){}\n')):
            r, _ = extract(text)
            self.assertEqual([], fields(r, 'exit'))

    def test_other_function_scopes_do_not_veto_create(self):
        for name in ('reset', 'init', 'helper'):
            r, _ = extract(room(self.SAFE, 'void ' + name + '(){' + self.INNER + ';}\n'))
            self.assertEqual(1, len(fields(r, 'exit')))


class P2F20RegressionTests(unittest.TestCase):
    SAFE = 'set("exits",(["north":"/a"]));'

    @classmethod
    def cases(cls):
        # Handwritten policies, generated spellings only; no observed-output oracle.
        cases = []
        for operation in ('set', 'add', 'delete'):
            for key in ('exits', 'exits/east'):
                for depth in (1, 2, 3):
                    grouped = '(' * depth + '"' + key + '"' + ')' * depth
                    call = operation + '(' + grouped + ('' if operation == 'delete' else ',value') + ');'
                    cases.append((f'group-{operation}-{key}-{depth}', room(cls.SAFE + call), 0))
            for key in ('variable', '(variable)', 'foo()', '"exits" + suffix', '("exits" + "")',
                        'mapping[index]', 'condition ? "exits" : "short"', '(("exits", "short"))',
                        '("exits"[0..])', 'K', '42'):
                call = operation + '(' + key + ('' if operation == 'delete' else ',value') + ');'
                cases.append((f'unknown-{operation}-{key}', room(cls.SAFE + call), 0))
            for receiver in ('::', 'other->'):
                for key in ('variable', 'foo()', '("exits")', '(("short"))'):
                    call = receiver + operation + '(' + key + ('' if operation == 'delete' else ',value') + ');'
                    cases.append((f'receiver-{receiver}-{operation}-{key}', room(cls.SAFE + call),
                                  1 if receiver == 'other->' or key == '(("short"))' else 0))
        for key in ('("exits")', 'unknown_key'):
            for receiver in ('', '::'):
                call = receiver + 'set(' + key + ',value)'
                for place, body in (
                    ('flat', cls.SAFE + call + ';'),
                    ('nested', cls.SAFE + '{' + call + ';}'),
                    ('value', cls.SAFE + 'set("objects",' + call + ');'),
                    ('wrapper', cls.SAFE + 'foo(' + call + ');'),
                    ('mapping', 'set("exits",(["north":"/a","south":' + call + ']));'),
                    ('before', call + ';' + cls.SAFE),
                    ('after', cls.SAFE + call + ';'),
                    ('between', cls.SAFE + call + ';' + cls.SAFE),
                ):
                    cases.append((f'position-{key}-{receiver}-{place}', room(body), 0))
        for key in ('("short")', '(("name"))', '("indoors")', '"exits_other"', '"objects"', '("inventory")'):
            for receiver in ('', '::', 'other->'):
                cases.append((f'non-exit-{receiver}-{key}', room(cls.SAFE + receiver + 'set(' + key + ',value);'), 1))
        for name in ('reset', 'init', 'helper'):
            cases.append(('scope-' + name, room(cls.SAFE, 'void ' + name + '(){set(variable,x);delete(("exits"));}'), 1))
        for name, extra in (
            ('comment', '/* delete(("exits")); set(variable,x); */'),
            ('string', r'set("long","delete((\"exits\")); set(variable,x)");'),
            ('character', "set(\"indoors\",'(');"),
            ('heredoc', 'set("long",@TEXT\ndelete(("exits"));\nTEXT\n);'),
            ('echo', '\n#echo delete(("exits")); set(variable,x);\n'),
        ):
            cases.append(('opaque-' + name, room(cls.SAFE + extra), 1))
        for definition in ('', '#define K "exits"\n'):
            for operation in ('set', 'delete'):
                call = operation + '((K)' + (',value' if operation == 'set' else '') + ');'
                cases.append((f'macro-{bool(definition)}-{operation}', definition + room(cls.SAFE + call), 0))
        cases += [('single', room(cls.SAFE), 1), ('double', room(cls.SAFE + cls.SAFE), 2)]
        return cases

    def test_grouped_unknown_receiver_position_matrix(self):
        for name, text, expected in self.cases():
            for newline in ('\n', '\r\n'):
                with self.subTest(case=name, newline=repr(newline)):
                    r, ff = extract(text.replace('\n', newline))
                    self.assertEqual(expected, len(fields(r, 'exit')))
                    self.assertNotEqual('QUARANTINED', r['status'])
                    self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(ff))

    def test_key_reduction_is_static_text_or_unknown_only(self):
        for key, expected in [('"exits"', 'exits'), ('((("short")))', 'short'),
                              ('("exits" + "")', None), ('(("exits", "short"))', None),
                              ('foo()', None), ('((variable))', None), ('("exits"[0..])', None)]:
            raw = ('set(' + key + ',value);').encode()
            ts = lex(Source('d/probe.c', raw))
            value, end = RoomExtractor.classify_property_key(ts, 2)
            self.assertEqual(expected, value)
            self.assertEqual(',', ts[end].text)
            self.assertEqual(key, raw[ts[2].start:ts[end - 1].end].decode())

    def test_grouped_calls_are_not_registered_as_flat_declarations(self):
        text = room(self.SAFE + 'set(("exits"),(["s":"/b"]));')
        ext = RoomExtractor(Source('d/probe.c', text.encode()), set(), {})
        r, _ = ext.extract()
        self.assertEqual({text.index('set("exits"')}, ext.flat_exit_setter_starts)
        self.assertEqual({text.index('set(("exits"')}, ext.exit_uncertainty_call_starts)
        self.assertEqual([], fields(r, 'exit'))

    def test_finalizer_alone_and_no_suppressed_fact_allocation(self):
        original = RoomExtractor.fact
        def reject_exit(instance, field, *args, **kwargs):
            self.assertNotEqual('exit', field)
            return original(instance, field, *args, **kwargs)
        for call in ('set(("exits"),x)', 'delete(("exits/east"))', 'set(variable,x)',
                     '::set(("exits"),x)', '::delete(compute_key())'):
            with patch.object(RoomExtractor, 'unsupported_exit_mutations'), patch.object(RoomExtractor, 'fact', reject_exit):
                r, _ = extract(room('set("short","independent");' + self.SAFE + 'foo(' + call + ');'))
            self.assertEqual(['inherit', 'short'], [f['field'] for f in r['facts']])
        for call in ('other->set(variable,x)', 'other->delete(("exits"))'):
            with patch.object(RoomExtractor, 'unsupported_exit_mutations'):
                r, _ = extract(room(self.SAFE + call + ';'))
            self.assertEqual(1, len(fields(r, 'exit')))

    def test_grouped_and_unknown_findings_deduplicate_and_keep_authored_span(self):
        for call in ('delete((("exits/east")))', 'set(compute_key(),x)', '::delete(("exits/east"))',
                     '::set(variable,x)'):
            for newline in ('\n', '\r\n'):
                raw = room(self.SAFE + '{' + call + ';}').replace('\n', newline).encode()
                r, ff = extract(raw)
                refused = [f for f in ff if 'prevents reliable exit facts' in f['reason']
                           or 'makes this exit sequence uncertain' in f['reason']]
                self.assertEqual(1, len(refused))
                p = refused[0]['provenance']
                self.assertEqual(raw[p['byte_start']:p['byte_end_exclusive']].decode(), p['raw'])
                self.assertTrue(p['raw'].startswith(call.split('(')[0] + '('))
                self.assertEqual(call.rsplit(',', 1)[0] if ',' in call else call[:-1], p['raw'])
                self.assertEqual([], fields(r, 'exit'))

    def test_long_grouping_is_iterative(self):
        for value, expected in (('exits', 0), ('short', 1)):
            key = '(' * 1100 + '"' + value + '"' + ')' * 1100
            for newline in ('\n', '\r\n'):
                r, _ = extract(room(self.SAFE + 'set(' + key + ',value);').replace('\n', newline))
                self.assertEqual(expected, len(fields(r, 'exit')))
                self.assertNotEqual('QUARANTINED', r['status'])

    def test_static_non_exit_inherited_keys_do_not_veto(self):
        for call in ('::set("short",value)', '::delete("objects")', '::add(("inventory"),value)'):
            r, ff = extract(room(self.SAFE + call + ';'))
            self.assertEqual(1, len(fields(r, 'exit')))
            self.assertFalse(any('exit sequence uncertain' in f['reason'] for f in ff))

    def test_existing_true_source_corruption_is_unchanged(self):
        for text in ('inherit ROOM; void create(){', 'inherit ROOM\nvoid create(){}',
                     room('unfinished'), room('set("exits",(["n":"/a",,"s":"/b"]));'),
                     b'inherit ROOM;\x00'):
            r, ff = extract(text)
            self.assertEqual('QUARANTINED', r['status'])
            self.assertEqual([], r['facts'])
            self.assertTrue(codes(ff) & {'SOURCE_SYNTAX_ERROR', 'SOURCE_ENCODING_ISSUE'})


class P2F21RegressionTests(unittest.TestCase):
    DEFINITIONS = '#define A() B\n#define B()\n'

    @staticmethod
    def summary(definitions):
        result = MacroSummary()
        for token in lex(Source('d/probe.c', definitions.encode())):
            result.add(token)
        return result

    @classmethod
    def cases(cls):
        cases = []
        for tail in ('A()()', 'A () ()', 'A()\n()', 'A()/* trivia */()',
                     'A()() A()()', 'EMPTY A()()', 'A()() EMPTY',
                     'DROP(ignored) A()()', 'A()() DROP(ignored)'):
            cases.append((tail, cls.DEFINITIONS + '#define EMPTY\n#define DROP(x)\n' + room(tail), {}, 'PARTIAL'))
        for definitions, tail in (
            ('#define A(x) B\n#define B(y)\n', 'A(7)(unused_identifier)'),
            ('#define A() B\n#define B() C\n#define C()\n', 'A()()()'),
            ('#define A() B\n#define B() C\n#define C() D\n#define D()\n', 'A()()()()'),
            ('#define START A\n' + cls.DEFINITIONS, 'START()()'),
            ('#define A() LINK\n#define LINK B\n#define B()\n', 'A()()'),
            ('#define A() X\n#define X Y\n#define Y B\n#define B() Z\n#define Z C\n#define C()\n', 'A()()()'),
        ):
            cases.append((tail + definitions, definitions + room(tail), {}, 'PARTIAL'))
        for prefix, headers in (
            ('#include "end.h"\n', {'d/end.h': cls.DEFINITIONS}),
            ('#include "outer.h"\n', {'d/outer.h': '#include "inner.h"\n', 'd/inner.h': cls.DEFINITIONS}),
            ('#include <end.h>\n', {'include/end.h': cls.DEFINITIONS}),
            ('#include "a.h"\n#include "b.h"\n', {'d/a.h': '#define A() B\n', 'd/b.h': '#define B()\n'}),
        ):
            cases.append((prefix, prefix + room('A()()'), headers, 'PARTIAL'))
        for tail in ('A()', 'A() identifier ()', 'identifier A()()', 'A()() identifier', 'A()()()'):
            cases.append((tail, cls.DEFINITIONS + room(tail), {}, 'QUARANTINED'))
        for definitions, tail in (
            ('#define A()\n', 'A()()'),
            ('#define A() B\n#define B\n', 'A()()'),
            ('#define A() B\n#define B() 1\n', 'A()()'),
            ('#define A() B\n#define B() "x"\n', 'A()()'),
            ("#define A() B\n#define B() 'x'\n", 'A()()'),
            ('#define A() unknown_name\n', 'A()()'),
        ):
            cases.append((definitions, definitions + room(tail), {}, 'QUARANTINED'))
        for definitions in ('#define A(x) x\n', '#define A(x) B(x)\n',
                            '#define A() B\n#define B() A\n', '#define A B\n#define B A\n',
                            '#define A()\n#define A() 1\n', '#define A\n#define A()\n',
                            '#define A(x\n', '#define A X ## Y\n', '#define A() (1 + 2)\n'):
            cases.append((definitions, definitions + room('A()()'), {}, 'OUT_OF_SCOPE'))
        return cases

    def test_legal_and_adversarial_continuation_matrix(self):
        for name, text, headers, status in self.cases():
            for newline in ('\n', '\r\n'):
                with self.subTest(case=name, newline=repr(newline)):
                    deps = {p: Source(p, v.replace('\n', newline).encode()) for p, v in headers.items()}
                    record, findings = extract(text.replace('\n', newline), path='d/probe.c', dependencies=deps)
                    self.assertEqual(status, record['status'])
                    self.assertEqual(status == 'QUARANTINED', 'SOURCE_SYNTAX_ERROR' in codes(findings))
                    if status == 'PARTIAL':
                        self.assertEqual(['inherit'], [f['field'] for f in record['facts']])

    def test_step_keeps_returned_callable_separate_from_consumed_arguments(self):
        summary = self.summary(self.DEFINITIONS)
        self.assertEqual((CreateTailEffect.CALLABLE_CONTINUATION, True, 'B'), summary.create_tail_effect('A', True))
        self.assertEqual((CreateTailEffect.NONEMPTY_NEUTRAL, False, None), summary.create_tail_effect('B', False))
        self.assertEqual((CreateTailEffect.EMPTY, True, None), summary.create_tail_effect('B', True))
        self.assertEqual((CreateTailEffect.NONEMPTY_NEUTRAL, False, None), summary.create_tail_effect('A', False))

    def test_object_aliases_before_and_after_consumed_function(self):
        summary = self.summary('#define START A\n#define A() X\n#define X Y\n#define Y B\n#define B()\n')
        self.assertEqual((CreateTailEffect.CALLABLE_CONTINUATION, True, 'B'), summary.create_tail_effect('START', True))
        self.assertEqual((CreateTailEffect.EMPTY, True, None), summary.create_tail_effect('X', True))

    def test_empty_result_does_not_own_extra_authored_call(self):
        for definitions in ('#define A()\n', '#define A() E\n#define E\n'):
            self.assertEqual((CreateTailEffect.EMPTY, True, None), self.summary(definitions).create_tail_effect('A', True))
            r, _ = extract(definitions + room('A()()'))
            self.assertEqual('QUARANTINED', r['status'])

    def test_parameter_cycles_and_ambiguous_definitions_are_uncertain(self):
        for definitions in ('#define A(x) x\n', '#define A(x) B(x)\n', '#define A B\n#define B A\n',
                            '#define A() A\n', '#define A()\n#define A() 1\n',
                            '#define A\n#define A()\n', '#define A(x\n', '#define A X ## Y\n'):
            self.assertEqual(CreateTailEffect.UNCERTAIN, self.summary(definitions).create_tail_effect('A', True)[0])

    def test_provenance_and_suppression_anchor_original_use(self):
        for newline in ('\n', '\r\n'):
            text = ('#include "tail.h"\n' + room('set("short","independent"); A()()')).replace('\n', newline)
            source = Source('d/probe.c', text.encode())
            ext = RoomExtractor(source, set(), {'d/tail.h': Source('d/tail.h', self.DEFINITIONS.encode())})
            r, findings = ext.extract()
            self.assertEqual(['inherit'], [f['field'] for f in r['facts']])
            f = next(f for f in findings if 'create tail' in f['reason'])
            self.assertEqual('A', f['provenance']['raw'])
            self.assertEqual('d/probe.c', f['provenance']['source_path'])
            self.assertEqual(text.index('A()()'), f['provenance']['byte_start'])
            self.assertFalse(any(t.text == 'B' for t in ext.tokens))

    def test_long_alias_and_continuation_chains_are_iterative(self):
        aliases = '#define START() A0\n' + ''.join(f'#define A{i} A{i+1}\n' for i in range(1100)) + '#define A1100()\n'
        calls = ''.join(f'#define A{i}() A{i+1}\n' for i in range(1100)) + '#define A1100()\n'
        for definitions, tail in ((aliases, 'START()()'), (calls, 'A0' + '()' * 1101)):
            for newline in ('\n', '\r\n'):
                record, findings = extract((definitions + room(tail)).replace('\n', newline))
                self.assertEqual('PARTIAL', record['status'])
                self.assertNotIn('SOURCE_SYNTAX_ERROR', codes(findings))

    def test_completed_statement_boundary_keeps_existing_dispatch(self):
        r, findings = extract(self.DEFINITIONS + room('A()(); set("short","safe");'))
        self.assertEqual('PARTIAL', r['status'])
        self.assertEqual('safe', fields(r, 'short')[0]['value']['value'])
        self.assertFalse(any('create tail' in f['reason'] for f in findings))


class P2F22RegressionTests(unittest.TestCase):
    @classmethod
    def cases(cls):
        cases = []
        for name, definitions, use in (
            ('empty-function', '#define inherit()\n', 'inherit()'),
            ('parameter', '#define inherit(x)\n', 'inherit(ROOM)'),
            ('parameters', '#define inherit(x,y)\n', 'inherit(ROOM,ignored())'),
            ('opaque-arguments', '#define inherit(x)\n', 'inherit(set("exits",value))'),
            ('empty-object', '#define inherit\n', 'inherit'),
            ('object-alias', '#define inherit END\n#define END\n', 'inherit'),
            ('object-function', '#define inherit END\n#define END(x)\n', 'inherit(ROOM)'),
            ('function-object', '#define inherit(x) END\n#define END\n', 'inherit(ROOM)'),
            ('continuation', '#define inherit() END\n#define END()\n', 'inherit()()'),
            ('longer-alias', '#define inherit() A\n#define A B\n#define B END\n#define END()\n', 'inherit()()'),
            ('object-cycle', '#define inherit A\n#define A inherit\n', 'inherit'),
            ('function-cycle', '#define inherit() A\n#define A() inherit\n', 'inherit()()'),
            ('competing', '#define inherit(x)\n#define inherit(x) 1\n', 'inherit(ROOM)'),
            ('object-function-ambiguity', '#define inherit\n#define inherit(x)\n', 'inherit ROOM;'),
            ('invalid', '#define inherit(x\n', 'inherit(ROOM)'),
            ('dependent', '#define inherit(x) x\n', 'inherit(ROOM)'),
            ('paste', '#define inherit A ## B\n', 'inherit ROOM;'),
            ('compound', '#define inherit() (1+2)\n', 'inherit()'),
            ('semicolon', '#define inherit()\n', 'inherit();'),
            ('apparent-declaration', '#define inherit SOMETHING\n', 'inherit ROOM;'),
            ('comment', '#define inherit(x)\n', 'inherit /*comment*/ (ROOM)'),
            ('multiline', '#define inherit(x)\n', 'inherit\n(ROOM)'),
        ):
            cases.append((name, definitions + use + '\nvoid create() {}\n', {}, 'OUT_OF_SCOPE'))
        for name, prefix, headers in (
            ('local', '#include "macros.h"\n', {'d/macros.h': '#define inherit(x)\n'}),
            ('nested', '#include "outer.h"\n', {'d/outer.h': '#include "macros.h"\n', 'd/macros.h': '#define inherit(x)\n'}),
            ('standard', '#include <macros.h>\n', {'include/macros.h': '#define inherit(x)\n'}),
            ('cross', '#include "a.h"\n#include "b.h"\n', {'d/a.h': '#define inherit(x) END\n', 'd/b.h': '#define END\n'}),
        ):
            cases.append((name, prefix + 'inherit(ROOM)\nvoid create() {}\n', headers, 'OUT_OF_SCOPE'))
        cases += [
            ('normal', room('set("short","safe");'), {}, 'EXTRACTED'),
            ('literal-only', 'inherit "/std/room"; void create() {}', {}, 'OUT_OF_SCOPE'),
            ('additional', 'inherit ROOM; inherit "/custom/base"; void create() {}', {}, 'PARTIAL'),
            ('uninvoked-valid', '#define inherit(x)\n' + room('set("short","safe");'), {}, 'PARTIAL'),
            ('uninvoked-structural', '#define inherit(x) ; inherit NPC;\n' + room(''), {}, 'PARTIAL'),
            ('uninvoked-missing', '#define inherit(x)\ninherit ROOM\nvoid create() {}', {}, 'QUARANTINED'),
            ('normal-missing', 'inherit ROOM\nvoid create() {}', {}, 'QUARANTINED'),
            ('unused', '#define UNUSED(x)\ninherit ROOM\nvoid create() {}', {}, 'QUARANTINED'),
            ('typed-boundary', '#define inherit(x)\ninherit(ROOM)\nint helper(){return 1;}\n', {}, 'OUT_OF_SCOPE'),
            ('untyped-boundary', '#define inherit(x)\ninherit(ROOM)\ncreate() {}\n', {}, 'OUT_OF_SCOPE'),
            ('missing-include-valid', '#include "missing.h"\n' + room(''), {}, 'OUT_OF_SCOPE'),
            ('missing-with-known-use', '#include "missing.h"\n#define inherit(x)\ninherit(ROOM)\n', {}, 'OUT_OF_SCOPE'),
            ('earlier-normal', '#define inherit(x)\ninherit ROOM;\ninherit(ROOM)\nvoid create(){}', {}, 'OUT_OF_SCOPE'),
            ('later-normal', '#define inherit(x)\ninherit(ROOM)\ninherit ROOM;\nvoid create(){}', {}, 'OUT_OF_SCOPE'),
            ('earlier-excluded', '#define inherit(x)\ninherit NPC;\ninherit(ROOM)\nvoid create(){}', {}, 'OUT_OF_SCOPE'),
        ]
        return cases

    def test_handwritten_keyword_use_matrix(self):
        for name, text, headers, expected in self.cases():
            for newline in ('\n', '\r\n'):
                with self.subTest(case=name, newline=repr(newline)):
                    deps = {p: Source(p, v.replace('\n', newline).encode()) for p, v in headers.items()}
                    record, findings = extract(text.replace('\n', newline), path='d/probe.c', dependencies=deps)
                    self.assertEqual(expected, record['status'])
                    self.assertEqual(expected == 'QUARANTINED', 'SOURCE_SYNTAX_ERROR' in codes(findings))
                    if expected == 'OUT_OF_SCOPE':
                        self.assertFalse(record['supported_candidate'])
                        self.assertEqual([], record['facts'])

    def test_uninvoked_definition_keeps_real_declaration_and_facts(self):
        plain, _ = extract(room('set("short","safe");set("exits",(["n":"/a"]));'))
        for definition in ('#define inherit(x)\n', '#define inherit(x) ; inherit NPC;\n'):
            record, _ = extract(definition + room('set("short","safe");set("exits",(["n":"/a"]));'))
            self.assertTrue(record['supported_candidate'])
            self.assertEqual([f['value'] for f in plain['facts']], [f['value'] for f in record['facts']])
            self.assertEqual(['ROOM'], record['category_candidates'])

    def test_refusal_clears_earlier_inheritance_before_any_fact_allocation(self):
        for prefix in ('inherit ROOM;', 'inherit NPC;', 'inherit ROOM;inherit "/custom/base";'):
            with patch.object(RoomExtractor, 'fact', side_effect=AssertionError('no uncertain facts')):
                record, _ = extract('#define inherit(x)\n' + prefix + '\ninherit(ignored)\nvoid create(){}')
            self.assertEqual('OUT_OF_SCOPE', record['status'])
            self.assertFalse(record['supported_candidate'])
            self.assertEqual([], record['direct_inherits'])
            self.assertEqual([], record['category_candidates'])
            self.assertEqual([], record['facts'])

    def test_header_finding_uses_authored_root_keyword_only(self):
        for newline in ('\n', '\r\n'):
            raw = ('// 中文\n#include "outer.h"\ninherit(ROOM)\nvoid create(){}').replace('\n', newline).encode()
            deps = {'d/outer.h': Source('d/outer.h', b'#include "inner.h"\n'),
                    'd/inner.h': Source('d/inner.h', b'#define inherit(x) ERASE\n#define ERASE\n')}
            ext = RoomExtractor(Source('d/probe.c', raw), set(), deps)
            record, findings = ext.extract()
            self.assertEqual([], record['facts'])
            self.assertEqual({'OUT_OF_SCOPE', 'DRIVER_SEMANTICS_UNKNOWN'}, codes(findings))
            for finding in findings:
                p = finding['provenance']
                self.assertEqual('d/probe.c', p['source_path'])
                self.assertEqual('inherit', p['raw'])
                self.assertEqual(raw.index(b'inherit(ROOM)'), p['byte_start'])
                self.assertEqual(hashlib.sha256(raw).hexdigest(), p['source_sha256'])
                self.assertEqual((3, 1), (p['line'], p['column']))
            self.assertFalse(any(t.text == 'ERASE' for t in ext.tokens))

    def test_macro_gate_does_not_summarize_replacements_or_expand(self):
        with (patch.object(MacroSummary, 'create_tail_effect', side_effect=AssertionError('not a create tail')),
              patch.object(MacroSummary, 'inherit_boundary_uncertain', side_effect=AssertionError('not a trusted declaration'))):
            record, _ = extract('#define inherit(x) unknown(x)\ninherit(ROOM)\nvoid create(){}')
        self.assertEqual('OUT_OF_SCOPE', record['status'])

    def test_normal_missing_terminator_still_has_original_diagnostic(self):
        for prefix in ('', '#define inherit(x)\n'):
            record, findings = extract(prefix + 'inherit ROOM\nvoid create(){}')
            self.assertEqual('QUARANTINED', record['status'])
            error = next(f for f in findings if f['code'] == 'SOURCE_SYNTAX_ERROR')
            self.assertEqual('unterminated inherit', error['reason'])
            self.assertEqual('inherit', error['provenance']['raw'])

    def test_long_alias_context_does_not_require_expansion(self):
        definitions = '#define inherit A0\n' + ''.join(f'#define A{i} A{i+1}\n' for i in range(1100)) + '#define A1100\n'
        record, _ = extract(definitions + 'inherit\nvoid create(){}')
        self.assertEqual('OUT_OF_SCOPE', record['status'])
        self.assertEqual([], record['direct_inherits'])


class P2F23RegressionTests(unittest.TestCase):
    @classmethod
    def cases(cls):
        body = 'void create(){set("short","safe");set("exits",(["n":"/a"]));}\n'
        cases = []
        for name, definitions, prefix in (
            ('object', '#define E\n', 'E'),
            ('function', '#define E(x)\n', 'E(123)'),
            ('opaque', '#define E(x)\n', 'E(ignored(inherit, NPC))'),
            ('alias', '#define E F\n#define F\n', 'E'),
            ('object-function', '#define E F\n#define F(x)\n', 'E(7)'),
            ('function-object', '#define E() F\n#define F\n', 'E()'),
            ('two-calls', '#define E() F\n#define F()\n', 'E()()'),
            ('three-calls', '#define E() F\n#define F() G\n#define G()\n', 'E()()()'),
            ('multiple', '#define E\n#define F\n', 'E F'),
            ('mixed', '#define E(x)\n#define F\n', 'E(7) F'),
            ('mixed-chains', '#define E() F\n#define F()\n#define G\n#define H()\n', 'E()() G H()'),
            ('trivia', '#define E\n', 'E /* comment */\n'),
            ('ambiguous', '#define E\n#define E(x)\n', 'E'),
            ('neutral-not-expanded', '#define E 1\n', 'E'),
            ('cycle-not-expanded', '#define E F\n#define F E\n', 'E'),
        ):
            cases.append((name, definitions + 'inherit ROOM;\n' + prefix + ' inherit NPC;\n' + body, {}, True, 'OUT_OF_SCOPE'))
        for name, declarations in (
            ('custom', 'inherit ROOM;\nE inherit "/custom/base";'),
            ('literal', 'inherit ROOM;\nE inherit "/std/item";'),
            ('hidden-room', 'E inherit ROOM;'),
            ('before-room', 'E inherit NPC;\ninherit ROOM;'),
            ('multiple-earlier', 'inherit ROOM;\ninherit "/custom/base";\nE inherit NPC;'),
        ):
            cases.append((name, '#define E\n' + declarations + '\n' + body, {}, True, 'OUT_OF_SCOPE'))
        for name, prefix, headers in (
            ('local', '#include "prefix.h"\n', {'d/prefix.h':'#define E(x)\n'}),
            ('nested', '#include "outer.h"\n', {'d/outer.h':'#include "inner.h"\n', 'd/inner.h':'#define E(x)\n'}),
            ('standard', '#include <prefix.h>\n', {'include/prefix.h':'#define E(x)\n'}),
            ('cross', '#include "a.h"\n#include "b.h"\n', {'d/a.h':'#define E F\n', 'd/b.h':'#define F(x)\n'}),
        ):
            cases.append((name, prefix + 'inherit ROOM;\nE(7) inherit ITEM;\n' + body, headers, True, 'OUT_OF_SCOPE'))
        for name, statement in (
            ('ordinary', 'ordinary_identifier E inherit NPC;'),
            ('numeric', '42 E inherit ITEM;'),
            ('text', '"+" E inherit NPC;'),
            ('interrupted-prefix', 'E ordinary_identifier inherit NPC;'),
            ('uninvoked-function', 'F inherit NPC;'),
            ('nested-argument', 'F(inherit NPC);'),
            ('nested-mapping', 'F(([inherit:NPC]));'),
            ('nested-array', 'F(({inherit,NPC}));'),
            ('nested-parentheses', 'F((inherit NPC));'),
            ('separate-room', 'E; inherit ROOM;'),
        ):
            cases.append((name, '#define E\n#define F(x)\ninherit ROOM;\n' + statement + '\n' + body, {}, False, 'PARTIAL'))
        cases.extend([
            ('normal', 'inherit ROOM;\n' + body, {}, False, 'PARTIAL'),
            ('normal-empty', 'inherit ROOM;\nvoid create(){}', {}, False, 'EXTRACTED'),
            ('explicit-excluded', 'inherit ROOM;inherit NPC;\n' + body, {}, False, 'OUT_OF_SCOPE'),
            ('separate-excluded', '#define E\ninherit ROOM;E;inherit NPC;\n' + body, {}, False, 'OUT_OF_SCOPE'),
            ('unused', '#define E\ninherit ROOM;\n' + body, {}, False, 'PARTIAL'),
        ])
        for name, directive, headers, expected in (
            ('define', '#define F\n', {}, 'PARTIAL'),
            ('undef', '#undef E\n', {}, 'PARTIAL'),
            ('pragma', '#pragma strict_types\n', {}, 'PARTIAL'),
            ('echo', '#echo message\n', {}, 'PARTIAL'),
            ('include', '#include "empty.h"\n', {'d/empty.h':''}, 'PARTIAL'),
            ('conditional', '#if 1\n#endif\n', {}, 'OUT_OF_SCOPE'),
            ('unknown', '#mystery\n', {}, 'PARTIAL'),
        ):
            cases.append(('directive-' + name, '#define E\ninherit ROOM;\nE\n' + directive + 'inherit ROOM;\n' + body, headers, False, 'OUT_OF_SCOPE'))
        return cases

    def test_handwritten_prefix_matrix(self):
        for name, text, headers, refused, expected in self.cases():
            for newline in ('\n', '\r\n'):
                with self.subTest(case=name, newline=repr(newline)):
                    deps = {p: Source(p, v.replace('\n', newline).encode()) for p, v in headers.items()}
                    record, findings = extract(text.replace('\n', newline), path='d/probe.c', dependencies=deps)
                    self.assertEqual(expected, record['status'])
                    self.assertEqual(refused, any('preprocessing prefix' in f['reason'] for f in findings))
                    if refused or name.startswith('directive-'):
                        self.assertFalse(record['supported_candidate'])
                        for field in ('facts', 'direct_inherits', 'category_candidates'):
                            self.assertEqual([], record[field])

    def test_refusal_precedes_all_fact_allocation(self):
        for prefix in ('inherit ROOM;', 'inherit ROOM;inherit "/custom/base";', 'inherit NPC;'):
            with patch.object(RoomExtractor, 'fact', side_effect=AssertionError('no allocation')):
                record, _ = extract('#define E\n' + prefix + '\nE inherit ITEM;\n' + room('set("short","x");set("exits",(["n":"/a"]));'))
            for field in ('facts', 'direct_inherits', 'category_candidates'):
                self.assertEqual([], record[field])
            self.assertFalse(record['supported_candidate'])

    def test_root_provenance_for_header_prefix_and_hidden_keyword(self):
        for newline in ('\n', '\r\n'):
            raw = ('// 中文\n#include "prefix.h"\ninherit ROOM;\nDROP(7) inherit ITEM;\nvoid create(){}').replace('\n', newline).encode()
            deps = {'d/prefix.h': Source('d/prefix.h', b'#define DROP(x) ERASE\n#define ERASE\n')}
            ext = RoomExtractor(Source('d/probe.c', raw), set(), deps)
            record, findings = ext.extract()
            self.assertEqual([], record['facts'])
            self.assertEqual({'OUT_OF_SCOPE', 'DRIVER_SEMANTICS_UNKNOWN'}, codes(findings))
            self.assertEqual({'DROP', 'inherit'}, {f['provenance']['raw'] for f in findings})
            for f in findings:
                p = f['provenance']
                self.assertEqual('d/probe.c', p['source_path'])
                self.assertEqual(hashlib.sha256(raw).hexdigest(), p['source_sha256'])
                self.assertEqual(p['raw'].encode(), raw[p['byte_start']:p['byte_end_exclusive']])
                self.assertEqual(4, p['line'])
            self.assertFalse(any(t.text == 'ERASE' for t in ext.tokens))

    def test_no_replacement_interpretation_or_inherit_recovery(self):
        with (patch.object(MacroSummary, 'effect', side_effect=AssertionError('no effect interpretation')),
              patch.object(MacroSummary, 'create_tail_effect', side_effect=AssertionError('no continuation expansion')),
              patch.object(MacroSummary, 'reach', side_effect=AssertionError('no alias interpretation'))):
            record, _ = extract('#define E arbitrary\ninherit ROOM;\nE()() inherit "/custom/base";')
        self.assertEqual([], record['direct_inherits'])
        self.assertEqual('OUT_OF_SCOPE', record['status'])

    def test_uninvoked_and_definite_prefixes_do_not_trigger_helper(self):
        for prefix in ('F', 'ordinary E', '42 E', '"+" E', 'E ordinary', '(E)'):
            ext = RoomExtractor(Source('d/probe.c', b''), set(), {})
            ext.tokens = lex(Source('d/probe.c', ('#define E\n#define F(x)\n' + prefix + ' inherit NPC;').encode()))
            self.assertIsNone(ext.preprocessing_hidden_inherit_use(ext.tokens[2:]))

    def test_helper_never_stitches_statements_or_directives(self):
        for tail in ('E; inherit NPC;', 'E\n#pragma strict_types\ninherit NPC;', 'E inherit NPC'):
            ext = RoomExtractor(Source('d/probe.c', b''), set(), {})
            ext.tokens = lex(Source('d/probe.c', ('#define E\n' + tail).encode()))
            self.assertIsNone(ext.preprocessing_hidden_inherit_use(ext.tokens[1:]))

    def test_long_prefixes_are_iterative_and_deterministic(self):
        aliases = '#define E A0\n' + ''.join(f'#define A{i} A{i+1}\n' for i in range(1100)) + '#define A1100\n'
        for definitions, prefix in ((aliases, 'E'), ('#define E()\n', 'E' + '()' * 1100), ('#define E\n', 'E ' * 1100)):
            for newline in ('\n', '\r\n'):
                text = (definitions + 'inherit ROOM;\n' + prefix + ' inherit NPC;').replace('\n', newline)
                first = extract(text)
                self.assertEqual(first, extract(text))
                self.assertEqual('OUT_OF_SCOPE', first[0]['status'])
                self.assertEqual([], first[0]['facts'])


class P2F26RegressionTests(unittest.TestCase):
    @classmethod
    def cases(cls):
        ordinary = 'void create(){set("short","identity");set("exits",(["e":"/end"]));}\n'
        cases = []
        directives = ('#define NOTE 1', '#undef NOTE', '#pragma strict_types', '#echo identity',
                      '#include "neutral.h"', '#unknown', '#if 1', '#ifdef NOTE',
                      '#ifndef NOTE', '#elif 1', '#else', '#endif')
        for target in ('set', 'create'):
            ret, params, body = ('mixed', 'string key,mixed value', 'return value;') if target == 'set' else ('void', '', '')
            for directive in directives:
                for gap in ('name', 'body'):
                    fragment = (f'{ret} IDENTITY\n{directive}\n({params}){{{body}}}\n' if gap == 'name'
                                else f'{ret} IDENTITY({params})\n{directive}\n{{{body}}}\n')
                    for where in ('root', 'header'):
                        definition = '#define IDENTITY ' + target + '\n'
                        headers = {'d/neutral.h': ''}
                        text = definition + 'inherit ROOM;\n' + fragment + ordinary
                        if where == 'header':
                            text = 'inherit ROOM;\n#include "fn.h"\n' + ordinary
                            headers['d/fn.h'] = definition + fragment
                        cases.append((target + directive + gap + where, text, headers, True))
            for kind, definitions, use in (
                ('object', '#define IDENTITY ' + target + '\n', 'IDENTITY'),
                ('alias', '#define IDENTITY NEXT\n#define NEXT ' + target + '\n', 'IDENTITY'),
                ('function', '#define IDENTITY(x) ' + target + '\n', 'IDENTITY(opaque_expression)'),
                ('object-function', '#define IDENTITY NEXT\n#define NEXT(x) ' + target + '\n', 'IDENTITY(7)'),
                ('function-object', '#define IDENTITY() NEXT\n#define NEXT ' + target + '\n', 'IDENTITY()'),
                ('continuation', '#define IDENTITY() NEXT\n#define NEXT() ' + target + '\n', 'IDENTITY()()'),
            ):
                fragment = f'{ret} {use}\n#pragma strict_types\n({params})\n#define NOTE 1\n#undef NOTE\n{{{body}}}\n'
                for context in ('root', 'local', 'nested', 'standard', 'cross', 'nested-cross'):
                    if context == 'root':
                        text, headers = definitions + 'inherit ROOM;\n' + fragment + ordinary, {}
                    elif context == 'local':
                        text, headers = 'inherit ROOM;\n#include "fn.h"\n' + ordinary, {'d/fn.h': definitions + fragment}
                    elif context == 'nested':
                        text, headers = 'inherit ROOM;\n#include "outer.h"\n' + ordinary, {'d/outer.h': '#include "fn.h"\n', 'd/fn.h': definitions + fragment}
                    elif context == 'standard':
                        text, headers = 'inherit ROOM;\n#include <fn.h>\n' + ordinary, {'include/fn.h': definitions + fragment}
                    elif context == 'cross':
                        text, headers = 'inherit ROOM;\n#include "defs.h"\n#include "fn.h"\n' + ordinary, {'d/defs.h': definitions, 'd/fn.h': fragment}
                    else:
                        text, headers = 'inherit ROOM;\n#include "outer.h"\n' + ordinary, {'d/outer.h': '#include "defs.h"\n#include "fn.h"\n', 'd/defs.h': definitions, 'd/fn.h': fragment}
                    cases.append((target + kind + context, text, headers, True))
        for name, definitions, use in (
            ('competing', '#define IDENTITY helper\n#define IDENTITY other\n', 'IDENTITY'),
            ('mixed', '#define IDENTITY helper\n#define IDENTITY(x) helper\n', 'IDENTITY'),
            ('cycle', '#define IDENTITY NEXT\n#define NEXT IDENTITY\n', 'IDENTITY'),
            ('compound', '#define IDENTITY a + b\n', 'IDENTITY'),
            ('paste', '#define IDENTITY(x) s ## x\n', 'IDENTITY(et)'),
            ('parameter', '#define IDENTITY(x) x\n', 'IDENTITY(set)'),
            ('structural', '#define IDENTITY {\n', 'IDENTITY'),
        ):
            fragment = 'mixed ' + use + '\n#pragma strict_types\n(string k,mixed v){return v;}\n'
            for dependency in (False, True):
                text = 'inherit ROOM;\n#include "fn.h"\n' + ordinary if dependency else definitions + 'inherit ROOM;\n' + fragment + ordinary
                # P2F27 Attempt 2 refuses the mixed object/function shape when
                # obtaining its possible invocation crosses the directive.
                cases.append((name + str(dependency), text, {'d/fn.h': definitions + fragment} if dependency else {}, True))
        controls = (
            ('no-directive-set', '#define IDENTITY set\n', 'mixed IDENTITY(string k,mixed v){return v;}\n'),
            ('no-directive-create', '#define IDENTITY create\n', 'void IDENTITY(){}\n'),
            ('helper', '#define IDENTITY helper\n', 'mixed IDENTITY\n#pragma strict_types\n(){}\n'),
            ('helper-chain', '#define IDENTITY NEXT\n#define NEXT helper\n', 'mixed IDENTITY\n#pragma strict_types\n(){}\n'),
            ('uninvoked', '#define IDENTITY() set\n', 'mixed IDENTITY\n#pragma strict_types\n(){}\n'),
            ('before', '#define IDENTITY set\n', '#pragma strict_types\nmixed IDENTITY(string k,mixed v){return v;}\n'),
            ('after', '#define IDENTITY set\n', 'mixed IDENTITY(string k,mixed v){return v;}\n#pragma strict_types\n'),
            ('semicolon', '#define IDENTITY set\n', 'IDENTITY;\n#pragma strict_types\nvoid helper(){}\n'),
            ('completed-function', '#define IDENTITY set\n', 'void helper(){IDENTITY("short","x");}\n#pragma strict_types\n'),
            ('nested', '#define IDENTITY set\n', 'void helper(){{\n#pragma strict_types\nIDENTITY("short","x");}}\n'),
            ('arguments', '#define IDENTITY set\n', 'void helper(){call(IDENTITY);}\n'),
            ('mapping', '#define IDENTITY set\n', 'mapping x=(["set":IDENTITY]);\n'),
            ('array', '#define IDENTITY create\n', 'mixed a=({IDENTITY});\n'),
            ('string', '#define IDENTITY set\n', 'string s="IDENTITY #pragma (){}";\n'),
            ('comment', '#define IDENTITY set\n', '/* IDENTITY\n#pragma strict_types\n(){} */\n'),
            ('text', '#define IDENTITY set\n', 'string s=@TEXT\nIDENTITY\n#pragma strict_types\n(){}\nTEXT\n;\n'),
        )
        for name, definitions, fragment in controls:
            cases.append((name, definitions + 'inherit ROOM;\n' + fragment + ordinary, {},
                          name in {'uninvoked', 'no-directive-set', 'no-directive-create',
                                   'helper', 'helper-chain', 'before', 'after'}))
        cases.append(('unreferenced', 'inherit ROOM;\n' + ordinary, {'d/unused.h': '#define IDENTITY set\nmixed IDENTITY\n#pragma strict_types\n(){}'}, False))
        return cases

    def test_handwritten_identity_matrix(self):
        for name, text, headers, refused in self.cases():
            for newline in ('\n', '\r\n'):
                with self.subTest(case=name, newline=repr(newline)):
                    deps = {p: Source(p, s.replace('\n', newline).encode()) for p, s in headers.items()}
                    record, findings = extract(text.replace('\n', newline), path='d/probe.c', dependencies=deps)
                    self.assertNotEqual('QUARANTINED', record['status'])
                    if refused:
                        self.assertEqual('OUT_OF_SCOPE', record['status'])
                        self.assertFalse(record['supported_candidate'])
                        for field in ('facts', 'direct_inherits', 'category_candidates'):
                            self.assertEqual([], record[field])
                    else:
                        self.assertFalse(any('admission-critical' in f['reason'] for f in findings))

    def test_every_positive_precedes_fact_allocation(self):
        for name, text, headers, refused in self.cases():
            if refused:
                with self.subTest(case=name), patch.object(RoomExtractor, 'fact', side_effect=AssertionError('no allocation')):
                    record, _ = extract(text, path='d/probe.c', dependencies={p: Source(p, s.encode()) for p, s in headers.items()})
                    self.assertEqual([], record['facts'])

    def test_shared_classifier_actual_use_and_identity(self):
        text = '#define A set\n#define F() set\n#define H helper\n#define C C\n#define M helper\n#define M(x) helper\n'
        ext = RoomExtractor(Source('d/a.c', text.encode()), set(), {})
        macros, _, _, _ = ext.macro_context(lex(ext.source))
        for name, called, expected in (('set', 0, 'SET'), ('create', 0, 'CREATE'),
                                        ('A', 0, 'SET'), ('F', 0, 'NONCRITICAL'), ('F', 1, 'SET'),
                                        ('H', 0, 'NONCRITICAL'), ('C', 0, 'UNKNOWN'), ('M', 0, 'NONCRITICAL')):
            token = lex(Source('d/a.c', name.encode()))[0]
            self.assertEqual(expected, ext.preprocessing_critical_function_identity(token, called, macros)[0])

    def test_dedicated_terminals_and_applicable_definitions(self):
        definitions = ('#define E\n#define N 1\n#define S "helper"\n#define C \'x\'\n'
                       '#define H helper\n#define H2 H\n#define F(x) helper\n#define EF(x)\n'
                       '#define P(x) x\n#define X(x) s ## x\n#define U a + b\n'
                       '#define SAFE helper\n#define SAFE other\n#define SAFE() helper\n'
                       '#define CRIT helper\n#define CRIT set\n#define CRIT() create\n'
                       '#define BAD(x\n')
        ext = RoomExtractor(Source('d/a.c', definitions.encode()), set(), {})
        macros, _, _, _ = ext.macro_context(lex(ext.source))
        for name, calls, expected in (('E', 0, 'EMPTY'), ('N', 0, 'UNKNOWN'), ('S', 0, 'UNKNOWN'),
                                     ('C', 0, 'UNKNOWN'), ('H2', 0, 'NONCRITICAL'), ('F', 1, 'NONCRITICAL'),
                                     ('EF', 1, 'EMPTY'), ('P', 1, 'UNKNOWN'), ('X', 1, 'UNKNOWN'),
                                     ('U', 0, 'UNKNOWN'), ('SAFE', 0, 'NONCRITICAL'), ('SAFE', 1, 'NONCRITICAL'),
                                     ('CRIT', 0, 'SET'), ('CRIT', 1, 'SET'), ('BAD', 1, 'UNKNOWN')):
            with self.subTest(name=name, calls=calls), patch.object(MacroSummary, 'reach', side_effect=AssertionError('generic reach forbidden')):
                self.assertEqual(expected, ext.preprocessing_critical_function_identity(lex(Source('d/a.c', name.encode()))[0], calls, macros)[0])

    def test_distinct_authored_call_ownership(self):
        definitions = '#define A() B\n#define B() set\n#define E() F\n#define F()\n#define O A\n'
        ext = RoomExtractor(Source('d/a.c', definitions.encode()), set(), {})
        macros, _, _, _ = ext.macro_context(lex(ext.source))
        for name, calls, expected in (('A', 0, ('NONCRITICAL', None)), ('A', 1, ('UNKNOWN', None)),
                                     ('A', 2, ('SET', None)), ('O', 2, ('SET', None)),
                                     ('E', 1, ('UNKNOWN', None)), ('E', 2, ('EMPTY', 2))):
            with self.subTest(name=name, calls=calls):
                self.assertEqual(expected, ext.preprocessing_critical_function_identity(lex(Source('d/a.c', name.encode()))[0], calls, macros))

    def test_single_function_name_slot_with_empty_prefixes_and_suffixes(self):
        definitions = '#define E\n#define E2 E\n#define F()\n#define X(x) x ## whatever\n#define W set\n'
        for name in ('mixed helper E', 'helper E', 'mixed E helper', 'mixed E E2 helper',
                     'mixed F() helper', 'mixed helper X(opaque)', 'mixed E helper W'):
            text = definitions + 'inherit ROOM;\n' + name + '\n#pragma warnings\n(){}\nvoid create(){set("short","kept");}'
            with self.subTest(name=name):
                ext = RoomExtractor(Source('d/a.c', text.encode()), set(), {})
                macros, _, _, _ = ext.macro_context(lex(ext.source))
                self.assertIsNotNone(ext.preprocessing_admission_structure_use(lex(ext.source), macros))
                with patch.object(ext, 'fact', side_effect=AssertionError('no allocation')):
                    record, _ = ext.extract()
                self.assertEqual('OUT_OF_SCOPE', record['status'])
                self.assertEqual([], record['facts'])
                self.assertEqual([], record['direct_inherits'])
        for name in ('mixed E W', 'E E2 W', 'mixed F() W'):
            with self.subTest(name=name), patch.object(RoomExtractor, 'fact', side_effect=AssertionError('no allocation')):
                record, _ = extract(definitions + 'inherit ROOM;\n' + name + '\n#pragma warnings\n(){}\nvoid create(){}')
                self.assertEqual('OUT_OF_SCOPE', record['status'])
                self.assertEqual([], record['facts'])

    def test_declaration_prefix_role_and_competing_categories(self):
        definitions = ('#define T mixed\n#define T2 T\n#define M static\n#define F() T\n'
                       '#define EP\n#define EP mixed\n#define EN\n#define EN helper\n'
                       '#define PN mixed\n#define PN helper\n#define PC mixed\n#define PC set\n'
                       '#define PP mixed\n#define PP static\n#define BOTH\n#define BOTH()\n')
        ext = RoomExtractor(Source('d/a.c', definitions.encode()), set(), {})
        macros, _, _, _ = ext.macro_context(lex(ext.source))
        for name, calls, expected in (('mixed', 0, ('PREFIX', 0)), ('static', 0, ('PREFIX', 0)),
                                     ('T2', 0, ('PREFIX', 0)), ('M', 0, ('PREFIX', 0)), ('F', 1, ('PREFIX', 1)),
                                     ('F', 0, ('NONCRITICAL', None)), ('EP', 0, ('PREFIX', 0)),
                                     ('EN', 0, ('UNKNOWN', None)), ('PN', 0, ('UNKNOWN', None)),
                                     ('PC', 0, ('UNKNOWN', None)), ('PP', 0, ('PREFIX', 0)),
                                     ('BOTH', 1, ('EMPTY', None)), ('inherit', 0, ('NONCRITICAL', None))):
            with self.subTest(name=name, calls=calls), patch.object(MacroSummary, 'reach', side_effect=AssertionError('no generic reach')):
                self.assertEqual(expected, ext.preprocessing_critical_function_identity(lex(Source('d/a.c', name.encode()))[0], calls, macros))

    def test_type_prefix_positions_precede_fact_allocation(self):
        definitions = ('#define T mixed\n#define T2 T\n#define M static\n#define E\n#define W set\n'
                       '#define F() set\n#define TF() mixed\n#define X static mixed\n#define Y(a) a\n'
                       '#define PN mixed\n#define PN helper\n#define EN\n#define EN helper\n')
        positives = ('T set', 'T create', 'T2 set', 'M T set', 'private static T set',
                     'E T set', 'T W', 'T F()', 'TF() set', 'X set', 'Y(opaque) set',
                     'PN set', 'EN set', 'T *set', 'mixed *set', 'set', 'create')
        unresolved_helpers = ('T helper', 'T2 helper', 'E T helper', 'T helper E', 'mixed helper T',
                     'M helper', 'helper E')
        for identity in positives + unresolved_helpers:
            for newline in ('\n', '\r\n'):
                for dependency in (False, True):
                    fragment = definitions + identity + '\n#pragma warnings\n(){}\n'
                    text = 'inherit ROOM;\n' + ('#include "fn.h"\n' if dependency else fragment) + 'void create(){set("name","ordinary");}\n'
                    deps = {'d/fn.h': Source('d/fn.h', fragment.replace('\n', newline).encode())} if dependency else {}
                    with self.subTest(identity=identity, newline=repr(newline), dependency=dependency):
                        with patch.object(RoomExtractor, 'fact', side_effect=AssertionError('no allocation')):
                            obj, _ = extract(text.replace('\n', newline), path='d/probe.c', dependencies=deps)
                        self.assertEqual('OUT_OF_SCOPE', obj['status'])
                        self.assertEqual([], obj['facts'])
                        self.assertEqual([], obj['direct_inherits'])

    def test_type_prefix_is_never_function_name_provenance(self):
        for identity in ('set', 'WRITER'):
            text = '#define TYPE mixed\n#define WRITER set\ninherit ROOM;\nTYPE ' + identity + '\n#pragma warnings\n(){}\nvoid create(){}'
            obj, findings = extract(text)
            self.assertEqual([], obj['facts'])
            # P2F29 keeps the earlier authored prefix-macro witness rather than
            # recovering a critical identity and blaming only the later gap.
            self.assertEqual({identity, 'TYPE'}, {f['provenance']['raw'] for f in findings})

    def test_preflight_itself_wins_before_raw_or_dependency_fallback(self):
        for dependency in (False, True):
            fragment = '#define A set\nmixed A\n#pragma strict_types\n(string k,mixed v){return v;}\n'
            text = 'inherit ROOM;\n#include "fn.h"\nvoid create(){}' if dependency else 'inherit ROOM;\n' + fragment + 'void create(){}'
            deps = {'d/fn.h': Source('d/fn.h', fragment.encode())} if dependency else {}
            ext = RoomExtractor(Source('d/probe.c', text.encode()), set(), deps)
            with (patch.object(ext, 'include_hazards', side_effect=AssertionError('no fallback')),
                  patch.object(ext, 'inherit_keyword_preprocessing_use', side_effect=AssertionError('no raw parser')),
                  patch.object(ext, 'fact', side_effect=AssertionError('no allocation'))):
                record, _ = ext.extract()
            self.assertEqual('OUT_OF_SCOPE', record['status'])
            self.assertEqual([], record['direct_inherits'])

    def test_root_macro_and_nested_root_include_provenance(self):
        for newline in ('\n', '\r\n'):
            for dependency in (False, True):
                fragment = '#define ALIAS set\nmixed ALIAS\n#pragma strict_types\n(string k,mixed v){return v;}\n'
                text = '// 中文\ninherit ROOM;\n' + ('#include "outer.h"\n' if dependency else fragment) + 'void create(){}'
                raw = text.replace('\n', newline).encode()
                deps = {p: Source(p, s.replace('\n', newline).encode()) for p, s in {'d/outer.h': '#include "inner.h"\n', 'd/inner.h': fragment}.items()} if dependency else {}
                ext = RoomExtractor(Source('d/probe.c', raw), set(), deps)
                record, findings = ext.extract()
                self.assertEqual([], record['facts'])
                for f in findings:
                    p = f['provenance']
                    self.assertEqual('d/probe.c', p['source_path'])
                    self.assertEqual(hashlib.sha256(raw).hexdigest(), p['source_sha256'])
                    self.assertEqual(raw[p['byte_start']:p['byte_end_exclusive']].decode(), p['raw'])
                    self.assertEqual(raw[:p['byte_start']].count(b'\n') + 1, p['line'])
                    if dependency:
                        self.assertEqual('#include "outer.h"' + newline, p['raw'])
                if not dependency:
                    self.assertEqual({'ALIAS'}, {f['provenance']['raw'] for f in findings})
                self.assertFalse(any(t.kind == 'identifier' and t.text == 'set' for t in ext.tokens))

    def test_no_effect_tail_expansion_or_recovery(self):
        with (patch.object(MacroSummary, 'effect', side_effect=AssertionError('no effect execution')),
              patch.object(MacroSummary, 'create_tail_effect', side_effect=AssertionError('no tail engine'))):
            record, _ = extract('#define A() B\n#define B() set\ninherit ROOM;\nmixed A()()\n#pragma strict_types\n(string k,mixed v){return v;}\nvoid create(){}')
        self.assertEqual('OUT_OF_SCOPE', record['status'])

    def test_long_aliases_and_authored_groups_are_iterative(self):
        definitions = ''.join(f'#define A{i} A{i+1}\n' for i in range(1100)) + '#define A1100 set\n'
        for defs, identity in ((definitions, 'A0'), ('#define A() set\n', 'A' + '()' * 1100)):
            text = defs + 'inherit ROOM;\nmixed ' + identity + '\n#pragma strict_types\n(string k,mixed v){return v;}\nvoid create(){}'
            first = extract(text)
            self.assertEqual(first, extract(text))
            self.assertEqual('OUT_OF_SCOPE', first[0]['status'])


class P2F25RegressionTests(unittest.TestCase):
    @classmethod
    def cases(cls):
        body = 'void create(){set("short","preflight");set("exits",(["n":"/a"]));}\n'
        cases = []
        directives = ('#define UNUSED 1', '#undef UNUSED', '#pragma warnings', '#echo audit',
                      '#include "empty.h"', '#unknown', '#if 1', '#ifdef UNUSED',
                      '#ifndef UNUSED', '#elif 1', '#else', '#endif')
        for directive in directives:
            for shape, declaration in (
                ('keyword', 'inherit\n' + directive + '\nNPC;\n'),
                ('tail', 'inherit NPC\n' + directive + '\n;\n'),
                ('hidden', 'E inherit NPC\n' + directive + '\n;\n'),
                ('prefix', 'E\n' + directive + '\ninherit NPC;\n'),
            ):
                for location in ('root', 'header'):
                    headers = {'d/empty.h': ''}
                    if location == 'root':
                        text = '#define E\ninherit ROOM;\n' + declaration + body
                    else:
                        text = 'inherit ROOM;\n#include "base.h"\n' + body
                        headers['d/base.h'] = '#define E\n' + declaration
                    cases.append((location + shape + directive, text, headers, True))
        for name, definitions, prefix in (
            ('empty', '#define E\n', 'E'),
            ('function', '#define E(x)\n', 'E(opaque(inherit, set))'),
            ('alias', '#define E NEXT\n#define NEXT\n', 'E'),
            ('object-function', '#define E NEXT\n#define NEXT(x)\n', 'E(1)'),
            ('function-object', '#define E() NEXT\n#define NEXT\n', 'E()'),
            ('continuation', '#define E() NEXT\n#define NEXT()\n', 'E()()'),
            ('multiple', '#define E\n#define NEXT(x)\n', 'E NEXT(1)'),
        ):
            for location, include, headers in (
                ('root', definitions, {}),
                ('local', '#include "defs.h"\n', {'d/defs.h': definitions}),
                ('nested', '#include "outer.h"\n', {'d/outer.h': '#include "defs.h"\n', 'd/defs.h': definitions}),
                ('standard', '#include <defs.h>\n', {'include/defs.h': definitions}),
                ('cross', '#include "a.h"\n#include "b.h"\n', {'d/a.h': '#define START E\n', 'd/b.h': definitions}),
            ):
                cases.append((name + location, include + prefix + '\n#pragma warnings\ninherit NPC;\ninherit ROOM;\n' + body, headers, True))
        for declaration in ('inherit NPC\n#pragma warnings\n#define X 1\n#undef X\n;\n',
                            'inherit ROOM\n#include "empty.h"\n;\n',
                            'inherit\n#include "empty.h"\nROOM;\n'):
            for position in ('before', 'after'):
                text = declaration + 'inherit ROOM;\n' if position == 'before' else 'inherit ROOM;\n' + declaration
                cases.append(('order-' + position + declaration, text + body, {'d/empty.h': ''}, True))
        for name, fragment in (
            ('standalone-before', '#pragma warnings\ninherit ROOM;\n'),
            ('standalone-after', 'inherit ROOM;\n#pragma warnings\n'),
            ('define-before', '#define X 1\ninherit ROOM;\n'),
            ('normal-room', 'inherit ROOM;\n'),
            ('normal-npc', 'inherit ROOM;\ninherit NPC;\n'),
            ('normal-item', 'inherit ROOM;\ninherit ITEM;\n'),
            ('literal-item', 'inherit ROOM;\ninherit "/std/item";\n'),
            ('custom', 'inherit ROOM;\ninherit "/custom/base";\n'),
            ('separate-excluded', 'inherit ROOM;\n#pragma warnings\ninherit NPC;\n'),
            ('complete-prefix', '#define E\nE;\n#pragma warnings\ninherit ROOM;\n'),
            ('ordinary-prefix', '#define E\ninherit ROOM;\nordinary E inherit NPC;\n'),
            ('interrupted-prefix', '#define E\ninherit ROOM;\nE ordinary inherit NPC;\n'),
            ('function-body', 'inherit ROOM;\nvoid helper(){\n#pragma warnings\ncall("inherit");}\n'),
            ('arguments', 'inherit ROOM;\nvoid helper(){call(inherit, (["set":"create"]));}\n'),
            ('top-group', 'inherit ROOM;\n(inherit NPC\n#pragma warnings\n);\n'),
            ('mapping', 'inherit ROOM;\nmapping m=(["inherit":"create"]);\n'),
            ('array', 'inherit ROOM;\nmixed a=({"inherit", "set"});\n'),
            ('comment', 'inherit ROOM;\n/* inherit NPC\n#pragma warnings\n; */\n'),
            ('text', 'inherit ROOM;\nstring s=@TEXT\ninherit NPC\n#pragma warnings\n;\nTEXT\n;\n'),
            ('after-function', 'inherit ROOM;\nvoid helper(){}\n#pragma warnings\n'),
        ):
            cases.append((name, fragment + body, {}, False))
        return cases

    def test_directive_inheritance_matrix(self):
        for name, text, headers, refused in self.cases():
            for newline in ('\n', '\r\n'):
                with self.subTest(case=name, newline=repr(newline)):
                    deps = {p: Source(p, s.replace('\n', newline).encode()) for p, s in headers.items()}
                    record, findings = extract(text.replace('\n', newline), path='d/probe.c', dependencies=deps)
                    self.assertNotEqual('QUARANTINED', record['status'])
                    if refused:
                        self.assertEqual('OUT_OF_SCOPE', record['status'])
                        self.assertFalse(record['supported_candidate'])
                        for field in ('facts', 'direct_inherits', 'category_candidates'):
                            self.assertEqual([], record[field])
                    else:
                        self.assertFalse(any('Preprocessing directives participate' in f['reason'] for f in findings))

    def test_all_positive_cases_allocate_no_facts(self):
        for name, text, headers, refused in self.cases():
            if refused:
                with self.subTest(case=name), patch.object(RoomExtractor, 'fact', side_effect=AssertionError('no allocation')):
                    record, _ = extract(text, path='d/probe.c', dependencies={p: Source(p, s.encode()) for p, s in headers.items()})
                self.assertEqual([], record['facts'])

    def test_shared_preflight_precedes_raw_inherit_and_dependency_fallback(self):
        class NoDeclarations(list):
            def append(self, _):
                raise AssertionError('raw inheritance parsing must not run')
        for declaration in ('inherit NPC\n#pragma warnings\n;', 'E inherit NPC\n#pragma warnings\n;',
                            'E\n#pragma warnings\ninherit NPC;'):
            for dependency in (False, True):
                text = 'inherit ROOM;\n#include "bad.h"\n' if dependency else '#define E\ninherit ROOM;\n' + declaration
                headers = {'d/bad.h': Source('d/bad.h', ('#define E\n' + declaration).encode())} if dependency else {}
                ext = RoomExtractor(Source('d/probe.c', text.encode()), set(), headers)
                ext.inherits = NoDeclarations()
                ext.record['direct_inherits'] = ext.inherits
                ext.tokens = lex(ext.source)
                macros, units, _, _ = ext.macro_context(ext.tokens)
                hit = next((ext.preprocessing_admission_structure_use(tokens, macros) for _, tokens in units
                            if ext.preprocessing_admission_structure_use(tokens, macros) is not None), None)
                self.assertIsNotNone(hit)
                self.assertEqual('inherit-directive', hit[0])
                with (patch.object(ext, 'include_hazards', side_effect=AssertionError('no fallback')),
                      patch.object(ext, 'inherit_keyword_preprocessing_use', side_effect=AssertionError('no raw loop')),
                      patch.object(ext, 'fact', side_effect=AssertionError('no fact'))):
                    record, _ = ext.extract()
                self.assertEqual('OUT_OF_SCOPE', record['status'])

    def test_root_and_nested_include_authored_provenance(self):
        for newline in ('\n', '\r\n'):
            for dependency in (False, True):
                text = '// 中文\n#include "outer.h"\ninherit ROOM;\n' if dependency else '// 中文\ninherit ROOM;\ninherit NPC\n#pragma warnings\n;'
                raw = text.replace('\n', newline).encode()
                deps = {p: Source(p, s.replace('\n', newline).encode()) for p, s in {
                    'd/outer.h': '#include "inner.h"\n', 'd/inner.h': 'inherit NPC\n#pragma warnings\n;'}.items()} if dependency else {}
                record, findings = extract(raw, path='d/probe.c', dependencies=deps)
                self.assertEqual([], record['direct_inherits'])
                self.assertEqual({'OUT_OF_SCOPE', 'DRIVER_SEMANTICS_UNKNOWN'}, codes(findings))
                for finding in findings:
                    p = finding['provenance']
                    self.assertEqual('d/probe.c', p['source_path'])
                    self.assertEqual(hashlib.sha256(raw).hexdigest(), p['source_sha256'])
                    self.assertEqual(raw[p['byte_start']:p['byte_end_exclusive']].decode(), p['raw'])
                    self.assertEqual(raw[:p['byte_start']].count(b'\n') + 1, p['line'])
                    if dependency:
                        self.assertEqual('#include "outer.h"' + newline, p['raw'])
                        self.assertEqual(2, p['line'])

    def test_no_macro_or_directive_interpretation(self):
        with (patch.object(MacroSummary, 'effect', side_effect=AssertionError('no effect')),
              patch.object(MacroSummary, 'reach', side_effect=AssertionError('no expansion')),
              patch.object(MacroSummary, 'create_tail_effect', side_effect=AssertionError('no expansion'))):
            record, _ = extract('#define E\nE\n#pragma warnings\ninherit NPC;\ninherit ROOM;')
        self.assertEqual([], record['facts'])
        self.assertEqual('OUT_OF_SCOPE', record['status'])

    def test_long_prefix_state_is_iterative(self):
        text = '#define E()\n' + 'E' + '()' * 1100 + '\n#pragma warnings\ninherit NPC;\ninherit ROOM;'
        first = extract(text)
        self.assertEqual(first, extract(text))
        self.assertEqual('OUT_OF_SCOPE', first[0]['status'])
        self.assertEqual([], first[0]['facts'])


class P2F24RegressionTests(unittest.TestCase):
    @classmethod
    def cases(cls):
        ordinary = 'void create(){set("short","ordinary");set("exits",(["n":"/a"]));}\n'
        definitions = '#define E\n#define F(x)\n#define A() B\n#define B()\n#define ALIAS E\n'
        cases = []
        for name in ('set', 'create'):
            for typed in ('', 'mixed '):
                for gap in ('E', 'F(opaque(set, create))', 'ALIAS', 'A()()', 'A()()()', 'E F(7)', 'E ALIAS E'):
                    for position in ('name', 'body', 'both'):
                        left = gap if position != 'body' else ''
                        right = gap if position != 'name' else ''
                        declaration = f'{typed}{name} {left} (mixed value) {right} {{ return value; }}\n'
                        cases.append((f'{name}-{bool(typed)}-{gap}-{position}', definitions + 'inherit ROOM;\n' + declaration + ordinary, {}, True))
        for name in ('set', 'create'):
            for position in ('name', 'body'):
                for directive in ('#define UNUSED 1', '#undef E', '#pragma strict_types', '#echo message', '#mystery', '#include "empty.h"'):
                    gap = '\n' + directive + '\n'
                    left, right = (gap, '') if position == 'name' else ('', gap)
                    declaration = f'mixed {name}{left}(mixed value){right}{{ return value; }}\n'
                    cases.append((f'directive-{name}-{position}-{directive}', 'inherit ROOM;\n' + declaration + ordinary, {'d/empty.h': ''}, True))
        for name in ('set', 'create'):
            for context, prefix, headers in (
                ('local', '#include "a.h"\n', {'d/a.h': '#define E\n'}),
                ('nested', '#include "a.h"\n', {'d/a.h': '#include "b.h"\n', 'd/b.h': '#define E\n'}),
                ('standard', '#include <a.h>\n', {'include/a.h': '#define E\n'}),
                ('cross', '#include "a.h"\n#include "b.h"\n', {'d/a.h': '#define E NEXT\n', 'd/b.h': '#define NEXT\n'}),
            ):
                for position in ('name', 'body'):
                    left, right = ('E', '') if position == 'name' else ('', 'E')
                    cases.append((f'{context}-{name}-{position}', prefix + 'inherit ROOM;\n' + ordinary + f'mixed {name} {left} () {right} {{}}', headers, True))
        for name in ('set', 'create'):
            for prefix in ('E mixed ', 'mixed E ', 'E ', 'F(7) mixed '):
                cases.append((f'prefix-{name}-{prefix}', definitions + 'inherit ROOM;\n' + prefix + name + '() {}\n' + ordinary, {}, False))
        for name in ('helper', 'foo', 'reset', 'init'):
            for typed in ('', 'mixed '):
                for left, right in (('E', ''), ('', 'E'), ('A()()', 'F(7)')):
                    cases.append((f'helper-{name}-{typed}-{left}-{right}', definitions + 'inherit ROOM;\n' + f'{typed}{name} {left} () {right} {{}}\n' + ordinary, {}, True))
        for fragment in ('set ordinary_identifier () {}', 'create 123 () {}', 'set F {}',
                         'void helper(){foo(set E ());}', 'void helper(){mixed m=(["set":"create E"]);}',
                         'void helper(){mixed a=({set, create});}', 'void helper(){{set E ();}}',
                         'void helper(){string x="create E () {}";}', '/* set E () {} */',
                         'void helper(){string x=@TEXT\nset E () {}\nTEXT\n;}',
                         'void helper(){foo(create E ());}'):
            cases.append(('negative-' + fragment, definitions + 'inherit ROOM;\n' + fragment + '\n' + ordinary, {}, False))
        for name in ('set', 'create'):
            cases.append(('ambiguity-' + name, '#define E\n#define E(x)\ninherit ROOM;\n' + name + ' E () {}\n' + ordinary, {}, True))
            cases.append(('statement-order-' + name, definitions + 'inherit ROOM;\nint marker;\n' + ordinary + name + ' E () {}\nvoid helper(){}', {}, True))
        return cases

    def test_critical_gap_matrix(self):
        for name, text, headers, refused in self.cases():
            for newline in ('\n', '\r\n'):
                with self.subTest(case=name, newline=repr(newline)):
                    deps = {p: Source(p, s.replace('\n', newline).encode()) for p, s in headers.items()}
                    record, findings = extract(text.replace('\n', newline), path='d/probe.c', dependencies=deps)
                    self.assertEqual(refused, not record['direct_inherits'])
                    if refused:
                        self.assertEqual('OUT_OF_SCOPE', record['status'])
                        self.assertFalse(record['supported_candidate'])
                        for field in ('facts', 'direct_inherits', 'category_candidates'):
                            self.assertEqual([], record[field])

    def test_all_refusals_precede_any_fact_allocation(self):
        for name, text, headers, refused in self.cases():
            if refused:
                with self.subTest(case=name), patch.object(RoomExtractor, 'fact', side_effect=AssertionError('no fact allocation')):
                    record, _ = extract(text, path='d/probe.c', dependencies={p: Source(p, s.encode()) for p, s in headers.items()})
                    self.assertEqual([], record['facts'])

    def test_no_replacement_summary_or_function_recovery(self):
        with (patch.object(MacroSummary, 'effect', side_effect=AssertionError('no expansion')),
              patch.object(MacroSummary, 'reach', side_effect=AssertionError('no reach')),
              patch.object(MacroSummary, 'create_tail_effect', side_effect=AssertionError('no tail summary'))):
            record, _ = extract('#define E unknown\ninherit ROOM;\nset E () {}\nvoid create(){}')
        self.assertEqual('OUT_OF_SCOPE', record['status'])

    def test_findings_anchor_root_tokens_not_header_replacement(self):
        for newline in ('\n', '\r\n'):
            raw = ('// 中文\n#include "a.h"\ninherit ROOM;\nmixed set GAP () {}\nvoid create(){}').replace('\n', newline).encode()
            ext = RoomExtractor(Source('d/probe.c', raw), set(), {'d/a.h': Source('d/a.h', b'#define GAP HIDDEN\n')})
            record, findings = ext.extract()
            self.assertEqual([], record['facts'])
            self.assertEqual({'set', 'GAP'}, {f['provenance']['raw'] for f in findings})
            for f in findings:
                p = f['provenance']
                self.assertEqual('d/probe.c', p['source_path'])
                self.assertEqual(hashlib.sha256(raw).hexdigest(), p['source_sha256'])
                self.assertEqual(p['raw'].encode(), raw[p['byte_start']:p['byte_end_exclusive']])
                self.assertEqual(4, p['line'])
            self.assertFalse(any(t.text == 'HIDDEN' for t in ext.tokens))

    def test_iterative_long_gaps_and_alias_context(self):
        aliases = '#define E A0\n' + ''.join(f'#define A{i} A{i+1}\n' for i in range(1100)) + '#define A1100\n'
        for defs, gap in ((aliases, 'E'), ('#define E\n', 'E ' * 1100), ('#define E()\n', 'E' + '()' * 1100)):
            text = defs + 'inherit ROOM;\nset ' + gap + ' () {}\nvoid create(){}'
            self.assertEqual(extract(text), extract(text))
            self.assertEqual('OUT_OF_SCOPE', extract(text)[0]['status'])

    def test_historical_macro_supplied_critical_names_stay_conservative(self):
        for name in ('set', 'create'):
            record, _ = extract('#define F ' + name + '\ninherit ROOM;\nmixed F() {}\nvoid create(){set("short","x");}')
            self.assertEqual([], fields(record, 'short'))


class P2F24DependencyRegressionTests(unittest.TestCase):
    @classmethod
    def cases(cls):
        ordinary = 'void create(){set("short","ordinary");set("exits",(["n":"/a"]));}\n'
        cases = []
        for context in ('local', 'nested', 'standard', 'cross', 'nested-cross'):
            for structure in ('mixed set GAP (mixed value) {return value;}',
                              'mixed set(mixed value) GAP {return value;}',
                              'void create GAP () {}', 'void create() GAP {}',
                              'GAP inherit NPC;', 'GAP inherit "/custom/base";'):
                if context == 'local':
                    prefix, headers = '#include "a.h"\n', {'d/a.h': '#define GAP\n' + structure}
                elif context == 'nested':
                    prefix, headers = '#include "outer.h"\n', {'d/outer.h': '#include "a.h"\n', 'd/a.h': '#define GAP\n' + structure}
                elif context == 'standard':
                    prefix, headers = '#include <a.h>\n', {'include/a.h': '#define GAP\n' + structure}
                elif context == 'cross':
                    prefix, headers = '#include "macros.h"\n#include "a.h"\n', {'d/macros.h': '#define GAP\n', 'd/a.h': structure}
                else:
                    prefix, headers = '#include "outer.h"\n', {'d/outer.h': '#include "macros.h"\n#include "a.h"\n', 'd/macros.h': '#define GAP\n', 'd/a.h': structure}
                cases.append((context + '-' + structure, 'inherit ROOM;\n' + prefix + ordinary, headers, True))
        for name in ('set', 'create'):
            for definitions, gap in (('#define F(x)\n', 'F(opaque(set, create))'),
                                     ('#define F() B\n#define B()\n', 'F()()'),
                                     ('#define F E\n#define E\n', 'F'),
                                     ('#define F\n#define F(x)\n', 'F'),
                                     ('#define F\n#define E\n', 'F E')):
                for left, right in ((gap, ''), ('', gap), (gap, gap)):
                    header = definitions + f'mixed {name} {left} (mixed arg) {right} {{return arg;}}'
                    cases.append(('macro-' + name + left + right + definitions, 'inherit ROOM;\n#include "a.h"\n' + ordinary, {'d/a.h': header}, True))
            for directive in ('#pragma strict_types', '#define UNUSED', '#undef UNUSED', '#echo hi', '#mystery', '#include "neutral.h"'):
                for left, right in (('\n' + directive + '\n', ''), ('', '\n' + directive + '\n')):
                    header = f'mixed {name} {left} (mixed arg) {right} {{return arg;}}'
                    cases.append(('directive-' + name + left + right, 'inherit ROOM;\n#include "a.h"\n' + ordinary, {'d/a.h': header, 'd/neutral.h': ''}, True))
        for header in ('mixed set(string key,mixed value){return value;}', 'void create(){}', 'inherit NPC;',
                       '#define GAP\nmixed helper GAP (){}', '#define GAP\nhelper GAP (){}',
                       '#define GAP\nGAP;\nmixed set(){}', '#define GAP\nmixed GAP set(){}',
                       '#define GAP\nGAP mixed set(){}', '#define GAP(x)\nmixed set GAP {}',
                       '#define GAP\nvoid helper(){foo(set GAP (),create GAP (),inherit);}',
                       '#define GAP\nvoid helper(){mixed m=(["set":"create GAP"]);mixed a=({inherit,set,create});}',
                       '#define GAP\nvoid helper(){{foo(set GAP ());}}',
                       '#define GAP\n/* set GAP (){} */\nstring s="create GAP (){}";',
                       '#define GAP\nordinary GAP inherit NPC;', '}', 'mixed incomplete(', ''):
            cases.append(('control-' + header, 'inherit ROOM;\n#include "a.h"\n' + ordinary, {'d/a.h': header},
                          header in {'#define GAP\nmixed helper GAP (){}', '#define GAP\nhelper GAP (){}'}))
        cases.append(('unreferenced', 'inherit ROOM;\n' + ordinary, {'d/a.h': '#define GAP\nset GAP () {}\nGAP inherit NPC;'}, False))
        cases.append(('direct-root-set', 'inherit ROOM;\n#include "a.h"\nmixed set(){}\n' + ordinary, {'d/a.h': 'void helper(){}'}, False))
        for includes in ('#include "safe.h"\n#include "a.h"\n', '#include "a.h"\n#include "safe.h"\n'):
            cases.append(('multiple-' + includes, 'inherit ROOM;\n' + includes + ordinary, {'d/safe.h': 'void helper(){}', 'd/a.h': '#define GAP\nset GAP (){}'}, True))
        for root, header in (('set GAP (){}', 'void helper(){}'), ('void create GAP (){}', 'set GAP (){}'),
                             ('GAP inherit NPC;', 'void create GAP (){}')):
            cases.append(('combined-' + root, '#define GAP\ninherit ROOM;\n#include "a.h"\n' + root + '\n' + ordinary, {'d/a.h': header}, True))
        return cases

    def test_dependency_matrix(self):
        for name, text, headers, refused in self.cases():
            for newline in ('\n', '\r\n'):
                with self.subTest(case=name, newline=repr(newline)):
                    deps = {p: Source(p, s.replace('\n', newline).encode()) for p, s in headers.items()}
                    record, findings = extract(text.replace('\n', newline), path='d/probe.c', dependencies=deps)
                    if refused:
                        self.assertFalse(record['supported_candidate'])
                        self.assertEqual('OUT_OF_SCOPE', record['status'])
                        for key in ('facts', 'direct_inherits', 'category_candidates'):
                            self.assertEqual([], record[key])
                    else:
                        self.assertFalse(any('resolved dependency contains preprocessing-sensitive' in f['reason'].lower() for f in findings))

    def test_dependency_refusal_precedes_any_fact_allocation(self):
        for name, text, headers, refused in self.cases():
            if refused:
                with self.subTest(case=name), patch.object(RoomExtractor, 'fact', side_effect=AssertionError('no allocation')):
                    record, _ = extract(text, path='d/probe.c', dependencies={p: Source(p, s.encode()) for p, s in headers.items()})
                    self.assertEqual([], record['facts'])

    def test_nested_dependency_anchors_root_include(self):
        for newline in ('\n', '\r\n'):
            raw = ('// 中文\ninherit ROOM;\n#include "outer.h"\nvoid create(){set("short","x");}').replace('\n', newline).encode()
            deps = {'d/outer.h': Source('d/outer.h', b'#include "inner.h"\n'),
                    'd/inner.h': Source('d/inner.h', b'#define GAP\nmixed set GAP (){}')}
            ext = RoomExtractor(Source('d/probe.c', raw), set(), deps)
            record, findings = ext.extract()
            self.assertEqual([], record['facts'])
            self.assertEqual({'OUT_OF_SCOPE', 'DRIVER_SEMANTICS_UNKNOWN'}, codes(findings))
            for f in findings:
                p = f['provenance']
                self.assertEqual('d/probe.c', p['source_path'])
                self.assertEqual(hashlib.sha256(raw).hexdigest(), p['source_sha256'])
                self.assertEqual(p['raw'].encode(), raw[p['byte_start']:p['byte_end_exclusive']])
                self.assertEqual('#include "outer.h"' + newline, p['raw'])
                self.assertEqual((3, 1), (p['line'], p['column']))
            self.assertFalse(any(t.text == 'GAP' for t in ext.tokens))

    def test_multiple_dangerous_dependencies_have_deterministic_origin(self):
        deps = {p: Source(p, b'#define GAP\nset GAP (){}') for p in ('d/a.h', 'd/b.h')}
        for first, second in (('a', 'b'), ('b', 'a')):
            text = f'inherit ROOM;\n#include "{first}.h"\n#include "{second}.h"\nvoid create(){{}}'
            result = extract(text, path='d/probe.c', dependencies=deps)
            self.assertEqual(result, extract(text, path='d/probe.c', dependencies=deps))
            self.assertTrue(all(f['provenance']['raw'] == f'#include "{first}.h"\n' for f in result[1]))


class P2F27RegressionTests(unittest.TestCase):
    tail = 'void create(){set("name","safe");set("exits",(["west":"/d/x"]));}\n'
    gap = '\n#pragma strict_types\n'

    def refused(self, definitions, declaration, dependency=False):
        text = 'inherit ROOM;\n' + ('#include "unit.h"\n' if dependency else definitions + declaration) + self.tail
        deps = {'d/unit.h': Source('d/unit.h', (definitions + declaration).encode())} if dependency else {}
        ext = RoomExtractor(Source('d/probe.c', text.encode()), set(), deps)
        ext.tokens = lex(ext.source)
        macros, units, _, _ = ext.macro_context(ext.tokens)
        self.assertTrue(any(ext.preprocessing_admission_structure_use(ts, macros) is not None for _, ts in units))
        with (patch.object(ext, 'fact', side_effect=AssertionError('no allocation')),
              patch.object(ext, 'include_hazards', side_effect=AssertionError('no late include fallback')),
              patch.object(ext, 'inherit_keyword_preprocessing_use', side_effect=AssertionError('no raw segmentation'))):
            record, findings = ext.extract()
        self.assertFalse(record['supported_candidate'])
        self.assertEqual('OUT_OF_SCOPE', record['status'])
        for key in ('facts', 'direct_inherits', 'category_candidates'):
            self.assertEqual([], record[key])
        return record, findings

    def test_empty_prefix_literal_critical_and_single_gap(self):
        for name in ('set', 'create'):
            for second in ('', self.gap):
                for dependency in (False, True):
                    with self.subTest(name=name, second=second, dependency=dependency):
                        self.refused('#define DROP(x)\n', 'DROP' + self.gap + '(ignored) mixed ' + name + second + '(){}\n', dependency)

    def test_prefix_modifier_and_critical_function_results(self):
        for result,rest in (('mixed', 'set'), ('void', 'create'), ('static', 'mixed set'), ('set', ''), ('create', '')):
            for dependency in (False, True):
                self.refused('#define F() ' + result + '\n', 'F' + self.gap + '() ' + rest + '(){}\n', dependency)

    def test_every_directive_kind_and_multiple_directives(self):
        for directive in ('#define UNUSED 1', '#undef UNUSED', '#pragma warnings', '#echo raw payload', '#include "neutral.h"',
                          '#unknown', '#if 1', '#ifdef FLAG', '#ifndef FLAG', '#elif 0', '#else', '#endif',
                          '#pragma warnings\n#define X 1\n#undef X'):
            for dependency in (False, True):
                self.refused('#define F()\n', 'F\n' + directive + '\n() mixed set(){}\n', dependency)

    def test_callable_stages_consume_distinct_groups(self):
        defs = '#define A() B\n#define B() TYPE\n#define TYPE mixed\n'
        self.refused(defs, 'A' + self.gap + '()\n#define UNUSED\n() set(){}\n')
        text = defs + 'A' + self.gap + '()\n#define UNUSED\n() set(){}\n'
        ext = RoomExtractor(Source('d/probe.c', text.encode()), set(), {})
        ts = lex(ext.source);macros, _, _, _ = ext.macro_context(ts)
        index = next(i for i,t in enumerate(ts) if t.kind == 'identifier' and t.text == 'A')
        groups = ext.preprocessing_possible_call_groups(ts, index, pairs(ts))
        self.assertEqual(2, len(groups))
        self.assertLess(groups[0][0], groups[1][0])
        self.assertIs(groups[0][1], ext.preprocessing_directive_invocation_use(ts[index], groups, macros))
        self.assertTrue(all(w.text.startswith('#pragma') for _, w in groups))

    def test_hard_boundaries_and_trailing_directive(self):
        for boundary in (';', 'helper', '123', '"text"', "'x'", '{}', ',', '+', '*'):
            text = 'F\n#pragma warnings\n' + boundary + '()'
            ext = RoomExtractor(Source('d/p.c', text.encode()), set(), {});ts = lex(ext.source)
            self.assertEqual([], ext.preprocessing_possible_call_groups(ts, 0, pairs(ts)))
        for text in ('F()\n#pragma warnings\nhelper()', 'F()\n#pragma warnings\n'):
            ext = RoomExtractor(Source('d/p.c', text.encode()), set(), {});ts = lex(ext.source)
            groups = ext.preprocessing_possible_call_groups(ts, 0, pairs(ts))
            self.assertEqual(1, len(groups));self.assertIsNone(groups[0][1])

    def test_directive_separated_helper_roles_are_intentionally_refused(self):
        for definitions,decl in (
            ('#define F() helper\n', 'mixed F' + self.gap + '()(){}'),
            ('#define F(x)\n', 'F' + self.gap + '(ignored) mixed helper' + self.gap + '(){}'),
            ('#define F() mixed\n', 'F' + self.gap + '() helper' + self.gap + '(){}'),
        ):
            for dependency in (False, True):
                self.refused(definitions, decl + '\n', dependency)

    def test_definite_helper_suffix_never_reopens_name_slot(self):
        for definitions, decl in (
            ('#define F() set\n', 'mixed helper F' + self.gap + '()(){}'),
            ('#define EMPTY\n', 'mixed helper EMPTY' + self.gap + '(){}'),
        ):
            record, findings = extract(definitions + 'inherit ROOM;\n' + decl + '\n' + self.tail)
            self.assertFalse(any('admission-critical' in f['reason'] for f in findings))
            self.assertNotEqual('QUARANTINED', record['status'])

    def test_root_and_nested_dependency_authored_witness(self):
        for newline in ('\n', '\r\n'):
            declaration = '#define F()\nF\n#pragma warnings\n() mixed set(){}\n'
            for dependency in (False, True):
                text = '// 中文\ninherit ROOM;\n' + ('#include "outer.h"\n' if dependency else declaration) + self.tail
                raw = text.replace('\n', newline).encode()
                deps = {p: Source(p,s.replace('\n',newline).encode()) for p,s in {
                    'd/outer.h':'#include "inner.h"\n','d/inner.h':declaration}.items()} if dependency else {}
                record, findings = extract(raw, path='d/probe.c', dependencies=deps)
                self.assertEqual([], record['facts'])
                self.assertEqual({'OUT_OF_SCOPE','DRIVER_SEMANTICS_UNKNOWN'},codes(findings))
                for f in findings:
                    p=f['provenance'];self.assertEqual('d/probe.c',p['source_path'])
                    self.assertEqual(raw[p['byte_start']:p['byte_end_exclusive']],p['raw'].encode())
                    if dependency:self.assertEqual('#include "outer.h"'+newline,p['raw'])
                if not dependency:self.assertEqual({'F','#pragma warnings'+newline},{f['provenance']['raw'] for f in findings})

    def test_nested_and_unreferenced_controls(self):
        declaration = '#define F()\nF\n#pragma warnings\n() mixed set(){}\n'
        baseline = extract('inherit ROOM;\n' + self.tail)
        self.assertEqual(baseline,extract('inherit ROOM;\n'+self.tail,dependencies={'d/unused.h':Source('d/unused.h',declaration.encode())}))
        text = '#define F()\ninherit ROOM;\nvoid helper(){ F\n#pragma warnings\n(); }\n'+self.tail
        record,findings=extract(text)
        self.assertFalse(any('admission-critical' in f['reason'] for f in findings))
        self.assertTrue(record['supported_candidate'])

    def test_ambiguous_roles_do_not_guess_ownership(self):
        for defs in ('#define F\n#define F() mixed\n', '#define F() mixed\n#define F() helper\n',
                     '#define F()\n#define F() set\n', '#define F(x) x\n', '#define F() X ## Y\n'):
            self.refused(defs, 'F'+self.gap+'() set(){}\n')

    def test_no_generic_expansion_or_execution(self):
        with (patch.object(MacroSummary,'reach',side_effect=AssertionError('no generic reach')),
              patch.object(MacroSummary,'effect',side_effect=AssertionError('no generic effect')),
              patch.object(MacroSummary,'create_tail_effect',side_effect=AssertionError('no tail summary'))):
            self.refused('#define F() mixed\n','F'+self.gap+'() set(){}\n')

    def test_barrier_precedes_terminal_role_analysis(self):
        for result in ('', 'mixed', 'helper', 'set', 'create', 'x + y'):
            text = '#define F() ' + result + '\nF' + self.gap + '() helper(){}\n'
            ext = RoomExtractor(Source('d/p.c', text.encode()), set(), {})
            ts = lex(ext.source); macros, _, _, _ = ext.macro_context(ts)
            with patch.object(ext, 'preprocessing_critical_function_identity', side_effect=AssertionError('no terminal recovery')):
                self.assertEqual('macro-invocation', ext.preprocessing_admission_structure_use(ts, macros)[0])

    def test_prior_attempt_helper_continuation_cannot_widen(self):
        self.refused('#define NEXT() LAST\n#define LAST() mixed\n', 'NEXT()' + self.gap + '() helper(){}\n')

    def test_direct_adjacent_role_classifier_retained(self):
        for result, expected in (('', ('EMPTY', 1)), ('mixed', ('PREFIX', 1)), ('helper', ('NONCRITICAL', None)),
                                 ('set', ('SET', None)), ('create', ('CREATE', None)), ('x + y', ('UNKNOWN', None))):
            text = '#define F() ' + result + '\nF() helper(){}\n'
            ext = RoomExtractor(Source('d/p.c', text.encode()), set(), {})
            ts = lex(ext.source); macros, _, _, _ = ext.macro_context(ts)
            index = next(i for i,t in enumerate(ts) if t.kind == 'identifier' and t.text == 'F')
            groups = ext.preprocessing_possible_call_groups(ts, index, pairs(ts))
            self.assertIsNone(ext.preprocessing_directive_invocation_use(ts[index], groups, macros))
            self.assertEqual(expected, ext.preprocessing_critical_function_identity(ts[index], 1, macros))

    def test_long_directive_separated_chain_is_iterative(self):
        defs=''.join(f'#define A{i}() A{i+1}\n' for i in range(1100))+'#define A1100() mixed\n'
        declaration='A0'+('\n#pragma warnings\n()'*1101)+' set(){}\n'
        self.refused(defs,declaration)


class RealSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.result, cls.code = scan(REPOSITORY / 'reference/es2')
        cls.objects = {o['source_path']: o for o in cls.result['objects']}

    def findings(self, path):
        return [f for f in self.result['findings'] if f['provenance']['source_path'] == path]

    def test_roommaker_is_item_not_room(self):
        r = self.objects['obj/roommaker.c']
        self.assertFalse(r['supported_candidate'])
        self.assertEqual(['ITEM', 'F_AUTOLOAD'], r['category_candidates'])

    def test_street1_static_provenance(self):
        r = self.objects['d/city/street1.c']
        f = fields(r, 'short')[0]
        self.assertEqual('京师东街', f['value']['value'])
        self.assertEqual((67, 96), (f['provenance']['byte_start'], f['provenance']['byte_end_exclusive']))
        self.assertEqual((7, 9), (f['provenance']['line'], f['provenance']['column']))
        self.assertEqual('22eae1c00f4141b629316f00517aa540e3747cb9075def30ead725c427ae69a9', f['provenance']['source_sha256'])
        self.assertEqual(['/d/city/biaoju', '/d/city/street2', '/d/city/shenwumen'], [f['value']['target'] for f in fields(r, 'exit')])

    def test_school_reports_population_door_and_closure(self):
        r = self.objects['d/snow/school1.c']
        self.assertEqual(2, len(fields(r, 'exit')))
        self.assertEqual('PARTIAL', r['status'])
        raw = '\n'.join(f['provenance']['raw'] for f in self.findings('d/snow/school1.c'))
        self.assertIn('create_door', raw)
        self.assertIn('"objects"', raw)
        self.assertIn('CALLBACK_BEHAVIOR', codes(self.findings('d/snow/school1.c')))

    def test_pine3_random_exits_not_evaluated(self):
        self.assertEqual([], fields(self.objects['d/oldpine/pine3.c'], 'exit'))
        self.assertIn('RNG_SEMANTICS', codes(self.findings('d/oldpine/pine3.c')))

    def test_keep2_complex_body_macros_reject_authored_boundary(self):
        r = self.objects['d/oldpine/keep2.c']
        # HIY/NOR reach compound ESC + string replacements through ansi.h.
        self.assertFalse(r['supported_candidate'])
        self.assertEqual([], r['facts'])
        self.assertEqual('OUT_OF_SCOPE', r['status'])
        self.assertIn('UNRESOLVED_INHERITANCE', codes(self.findings('d/oldpine/keep2.c')))

    def test_lake_retains_callback_lifecycle_boundary(self):
        r = self.objects['d/village/lake.c']
        self.assertEqual('PARTIAL', r['status'])
        self.assertTrue({'CALLBACK_BEHAVIOR', 'DRIVER_SEMANTICS_UNKNOWN'} <= codes(self.findings('d/village/lake.c')))

    def test_actual_malformed_source_quarantined(self):
        for path in ['d/latemoon/sroad1.c', 'u/cloud/obj/sword_book.c', 'u/cloud/obj/npc/flower_girl/guihua.c']:
            with self.subTest(path=path):
                self.assertEqual('QUARANTINED', self.objects[path]['status'])
                self.assertEqual([], self.objects[path]['facts'])
        self.assertEqual(1, self.code)

    def test_whole_input_coverage_and_no_autoapproval(self):
        objects = self.result['objects']
        self.assertEqual(len(self.result['source_manifest']['files']), len(objects))
        self.assertEqual(len(objects), len({o['object_id'] for o in objects}))
        self.assertEqual(len(objects), len({o['input_path'] for o in objects}))
        self.assertEqual(len(objects), sum(self.result['summary']['statuses'].values()))
        for obj in objects:
            self.assertEqual('UNREVIEWED', obj['review_state'])
            self.assertNotEqual('APPROVED', obj['status'])


class P2F28RegressionTests(unittest.TestCase):
    tail = 'void create(){set("name","prefix control");set("exits",(["east":"/d/end"]));}\n'
    gap = '\n#pragma strict_types\n'

    def refused(self, definitions, declaration, dependency=False):
        text = definitions + declaration
        deps = {'d/unit.h': Source('d/unit.h', text.encode())} if dependency else {}
        root = 'inherit ROOM;\n' + ('#include "unit.h"\n' if dependency else text) + self.tail
        ext = RoomExtractor(Source('d/probe.c', root.encode()), set(deps), deps)
        with (patch.object(ext, 'fact', side_effect=AssertionError('no allocation')),
              patch.object(ext, 'include_hazards', side_effect=AssertionError('no late fallback')),
              patch.object(ext, 'inherit_keyword_preprocessing_use', side_effect=AssertionError('no raw segmentation'))):
            obj, findings = ext.extract()
        self.assertFalse(obj['supported_candidate'])
        self.assertEqual('OUT_OF_SCOPE', obj['status'])
        for key in ('facts', 'direct_inherits', 'category_candidates'):
            self.assertEqual([], obj[key])
        for f in findings:
            p = f['provenance']
            self.assertEqual('d/probe.c', p['source_path'])
            self.assertEqual(root.encode()[p['byte_start']:p['byte_end_exclusive']], p['raw'].encode())
            if dependency:
                self.assertEqual('#include "unit.h"\n', p['raw'])
        return findings

    def test_original_macro_and_independent_alias(self):
        for defs, name in (('#define WRITER() set\n', 'WRITER'),
                           ('#define RESOLVE(x) TARGET\n#define TARGET set\n', 'RESOLVE')):
            for dependency in (False, True):
                self.refused(defs, 'static mixed *' + name + self.gap + '()(string k,mixed v){}\n', dependency)

    def test_unsupported_punctuation_has_no_type_semantics(self):
        for punctuation in ('*', '&', '[]', '+', '[opaque]', '**'):
            for dependency in (False, True):
                self.refused('#define F() set\n', 'mixed ' + punctuation + 'F' + self.gap + '()(){}\n', dependency)

    def test_literal_critical_and_helper_directives(self):
        for name in ('set', 'create', 'helper'):
            for position in ('before', 'after', 'body'):
                declaration = ('mixed []' + self.gap + name + '(){}\n' if position == 'before' else
                               'mixed []' + name + self.gap + '(){}\n' if position == 'after' else
                               'mixed []' + name + '()' + self.gap + '{}\n')
                self.refused('', declaration)

    def test_empty_prefix_helper_unknown_roles(self):
        for replacement in ('', 'mixed', 'helper', 'set', 'create', 'x + x'):
            for dependency in (False, True):
                self.refused('#define F(x) ' + replacement + '\n', 'mixed &F' + self.gap + '(opaque) set(){}\n', dependency)

    def test_no_preprocessing_and_completed_body_controls(self):
        for declaration in ('mixed *helper(){}\n', '#pragma warnings\nmixed *helper(){}\n',
                            'mixed *helper(){}\n#pragma warnings\n', 'mixed *value;\nvoid helper(){}\n'):
            obj, _ = extract('inherit ROOM;\n' + declaration + self.tail)
            self.assertTrue(obj['supported_candidate'])
            self.assertEqual(['inherit', 'name', 'exit'], [f['field'] for f in obj['facts']])

    def test_no_call_boundary_does_not_borrow_later_group(self):
        for boundary in (';', 'ordinary'):
            obj, _ = extract('#define F() set\ninherit ROOM;\nmixed *F' + self.gap + boundary + '(){}\n' + self.tail)
            if boundary == ';':
                self.assertTrue(obj['supported_candidate'])
                self.assertEqual(['inherit', 'name', 'exit'], [f['field'] for f in obj['facts']])
            else:
                # P2F29: an intervening identifier cannot close an unresolved
                # header; the directive still participates in this declaration.
                self.assertFalse(obj['supported_candidate'])
                self.assertEqual([], obj['facts'])

    def test_nested_and_unreferenced_prefix_has_no_gate_effect(self):
        declaration = 'mixed *F' + self.gap + '()(){}\n'
        baseline = extract('inherit ROOM;\n' + self.tail)
        self.assertEqual(baseline, extract('inherit ROOM;\n' + self.tail,
                         dependencies={'d/unused.h': Source('d/unused.h', ('#define F() set\n' + declaration).encode())}))
        obj, _ = extract('#define F() set\ninherit ROOM;\nvoid helper(){' + declaration + '}\n' + self.tail)
        self.assertTrue(obj['supported_candidate'])

    def test_authored_unknown_prefix_witness(self):
        findings = self.refused('#define F() set\n', 'mixed *F' + self.gap + '()(){}\n')
        self.assertEqual({'*', '#pragma strict_types\n'}, {f['provenance']['raw'] for f in findings})
        self.assertTrue(any('unresolved declaration header' in f['reason'] for f in findings))


class P2F29RegressionTests(P2F28RegressionTests):
    def test_macro_roles_cannot_resolve_unknown_header(self):
        for replacement in ('set', 'create', 'helper', '', 'mixed', 'static', 'x ## y'):
            for macro in ('ROLE', 'ROLE(x)'):
                use = 'ROLE(opaque)' if '(' in macro else 'ROLE'
                for name in ('helper', 'set', 'create'):
                    for dependency in (False, True):
                        self.refused('#define ' + macro + ' ' + replacement + '\n',
                                     'CUSTOM [] ' + use + ' ' + name + '(){}\n', dependency)

    def test_attempt1_critical_macro_role_recovery_is_refused(self):
        for defs, use in (('#define PREFIX set\n', 'PREFIX'),
                          ('#define RESULT NEXT\n#define NEXT create\n', 'RESULT')):
            for dependency in (False, True):
                self.refused(defs, use + ' helper' + self.gap + '(){}\n', dependency)

    def test_direct_authored_proof_without_preprocessing_resolves_header(self):
        for prefix in ('CUSTOM_TYPE', 'function', 'buffer', 'class', 'CUSTOM &', 'TYPE []'):
            text = 'inherit ROOM;\n' + prefix + ' helper(){}\n' + self.tail
            obj, _ = extract(text)
            self.assertTrue(obj['supported_candidate'])
            self.assertEqual(['inherit', 'name', 'exit'], [f['field'] for f in obj['facts']])

    def test_unknown_identifiers_do_not_claim_name_slot(self):
        for prefix in ('function', 'CUSTOM_TYPE', 'UNKNOWN_TYPE', 'static function',
                       'function *', 'CUSTOM &', 'TYPE []'):
            for name in ('helper', 'set', 'create'):
                for dependency in (False, True):
                    self.refused('', prefix + ' ' + name + self.gap + '(){}\n', dependency)

    def test_original_macro_and_independent_unknown_alias(self):
        for defs, decl in (
            ('#define STORE() set\n', 'function STORE' + self.gap + '()(string k,mixed v){}\n'),
            ('#define RESULT function\n#define CHOOSE(x) TARGET\n#define TARGET set\n',
             'static RESULT CHOOSE\n#undef UNRELATED\n(opaque)(string k,mixed v){}\n')):
            for dependency in (False, True):
                self.refused(defs, decl, dependency)

    def test_macro_prefix_before_unknown_header_is_not_forgotten(self):
        for replacement in ('', 'mixed', 'helper', 'function'):
            self.refused('#define PREFIX ' + replacement + '\n', 'PREFIX CUSTOM helper(){}\n')

    def test_unknown_header_actual_macro_use_is_not_recovered(self):
        for replacement in ('', 'mixed', 'helper', 'set', 'create'):
            for dependency in (False, True):
                self.refused('#define NAME ' + replacement + '\n', 'CUSTOM NAME(){}\n', dependency)

    def test_unknown_header_without_preprocessing_remains_parent_safe(self):
        for declaration in ('function helper(){}\n', 'CUSTOM_TYPE helper(){}\n',
                            'mixed *helper(){}\n', '#pragma warnings\nCUSTOM helper(){}\n',
                            'CUSTOM helper(){}\n#pragma warnings\n'):
            obj, _ = extract('inherit ROOM;\n' + declaration + self.tail)
            self.assertTrue(obj['supported_candidate'])
            self.assertEqual(['inherit', 'name', 'exit'], [f['field'] for f in obj['facts']])

    def test_unresolved_header_resets_and_nested_tokens_stay_opaque(self):
        for declaration in ('CUSTOM value\n#pragma warnings\n;\n',
                            'CUSTOM helper(){}\n',
                            'void helper(){CUSTOM NAME\n#pragma warnings\n()();}\n',
                            'void helper(string arg="CUSTOM NAME"){}\n'):
            obj, _ = extract('#define NAME() set\ninherit ROOM;\n' + declaration + self.tail)
            self.assertTrue(obj['supported_candidate'])

    def test_suffix_macro_requires_direct_name_evidence(self):
        self.refused('#define EMPTY\n', 'mixed helper EMPTY' + self.gap + '(){}\n')

    def test_unresolved_identifier_witness_is_authored(self):
        findings = self.refused('#define STORE() set\n', 'CUSTOM STORE' + self.gap + '()(){}\n')
        self.assertEqual({'CUSTOM', '#pragma strict_types\n'}, {f['provenance']['raw'] for f in findings})


class P2F30RegressionTests(unittest.TestCase):
    tail = 'void create(){set("name","eof");set("exits",(["north":"/d/end"]));}\n'

    def fixture(self, definitions, header, continuation='(){}\n', layout='local', newline='\n'):
        origin = '#include "unit.h"\n'
        if layout == 'local':
            includes, headers = origin, {'d/unit.h': definitions + header}
        elif layout == 'nested':
            origin = '#include "outer.h"\n'
            includes, headers = origin, {'d/outer.h': '#include "unit.h"\n', 'd/unit.h': definitions + header}
        elif layout == 'standard':
            origin = '#include <unit.h>\n'
            includes, headers = origin, {'include/unit.h': definitions + header}
        elif layout == 'cross':
            includes = '#include "defs.h"\n' + origin
            headers = {'d/defs.h': definitions, 'd/unit.h': header}
        else:
            self.assertEqual('nested-cross', layout)
            origin = '#include "outer.h"\n'
            includes, headers = origin, {'d/outer.h': '#include "defs.h"\n#include "unit.h"\n',
                                        'd/defs.h': definitions, 'd/unit.h': header}
        root = '// 雪山\ninherit ROOM;\n' + includes + continuation + self.tail
        source = Source('d/probe.c', root.replace('\n', newline).encode())
        dependencies = {p: Source(p, text.replace('\n', newline).encode()) for p, text in headers.items()}
        return RoomExtractor(source, set(dependencies), dependencies), origin.replace('\n', newline)

    def assert_early_refusal(self, ext, origin):
        # These are distinct forbidden downstream paths, not output-only checks.
        with contextlib.ExitStack() as stack:
            for method in ('inherit_keyword_preprocessing_use', 'include_hazards', 'create_body', 'fact'):
                stack.enter_context(patch.object(ext, method, side_effect=AssertionError('late path: ' + method)))
            obj, findings = ext.extract()
        self.assertFalse(obj['supported_candidate'])
        self.assertEqual('OUT_OF_SCOPE', obj['status'])
        for key in ('direct_inherits', 'category_candidates', 'facts'):
            self.assertEqual([], obj[key])
        self.assertEqual(2, len(findings))
        for finding in findings:
            p = finding['provenance']
            raw, start, end = ext.source.data, p['byte_start'], p['byte_end_exclusive']
            self.assertEqual(origin, p['raw'])
            self.assertEqual(raw[start:end], origin.encode())
            self.assertEqual(ext.source.path, p['source_path'])
            self.assertEqual(hashlib.sha256(raw).hexdigest(), p['source_sha256'])
            self.assertEqual(raw[:start].count(b'\n') + 1, p['line'])
            self.assertEqual(len(raw[raw.rfind(b'\n', 0, start) + 1:start].decode()) + 1, p['column'])

    def test_primary_and_renamed_before_raw_inherit_or_fallback(self):
        for name in ('STORE', 'ASSIGN'):
            for newline in ('\n', '\r\n'):
                with self.subTest(name=name, newline=newline):
                    self.assert_early_refusal(*self.fixture('#define ' + name + ' set\n',
                                              'function ' + name + '\n', newline=newline))

    def test_six_eof_shapes_in_five_dependency_layouts(self):
        shapes = [('#define STORE set\n', 'function STORE\n', '(string key,mixed value){}\n'),
                  ('#define STORE() set\n', 'function STORE()\n', '(string key,mixed value){}\n'),
                  ('#define STORE set\n', 'function STORE(string key,mixed value)\n', '{}\n'),
                  ('#define STORE() set\n', 'function STORE()(string key,mixed value)\n', '{}\n'),
                  ('#define GAP\n', 'function GAP set\n', '(string key,mixed value){}\n'),
                  ('#define STORE helper\n', 'function STORE\n', '(){}\n')]
        for definitions, header, continuation in shapes:
            for layout in ('local', 'nested', 'standard', 'cross', 'nested-cross'):
                for newline in ('\n', '\r\n'):
                    with self.subTest(header=header, layout=layout, newline=newline):
                        self.assert_early_refusal(*self.fixture(definitions, header, continuation, layout, newline))

    def test_roles_and_witness_order_at_eof(self):
        for replacement in ('set', 'create', 'helper', '', 'mixed', 'unknown + value'):
            for function in (False, True):
                definitions = '#define ROLE' + ('(x)' if function else '') + ' ' + replacement + '\n'
                use = 'ROLE(opaque)' if function else 'ROLE'
                for header in ('CUSTOM ' + use, '* ' + use, use + ' CUSTOM', 'CUSTOM ' + use + '(string arg)'):
                    with self.subTest(replacement=replacement, header=header):
                        self.assert_early_refusal(*self.fixture(definitions, header + '\n'))
        self.assert_early_refusal(*self.fixture('#define ROLE left\n#define ROLE right\n', 'CUSTOM ROLE\n'))

    def test_directive_witness_at_unresolved_eof(self):
        self.assert_early_refusal(*self.fixture('', 'CUSTOM helper\n#pragma warnings\n'))

    def test_root_eof_is_not_dependency_eof(self):
        source = Source('d/probe.c', b'#define ROLE set\nCUSTOM ROLE')
        ext = RoomExtractor(source, set(), {})
        tokens = lex(source)
        macros, *_ = ext.macro_context(tokens)
        self.assertIsNone(ext.preprocessing_admission_structure_use(tokens, macros))
        self.assertIsNotNone(ext.preprocessing_admission_structure_use(tokens, macros, reached_dependency=True))
        obj, _ = extract('inherit ROOM;\nvoid create(){')
        self.assertEqual('QUARANTINED', obj['status'])

    def test_no_preprocessing_fragment_keeps_existing_fallback(self):
        ext, _ = self.fixture('', 'function set\n')
        with patch.object(ext, 'include_hazards', wraps=ext.include_hazards) as late:
            obj, _ = ext.extract()
        late.assert_called_once()
        self.assertEqual('OUT_OF_SCOPE', obj['status'])
        self.assertEqual([], obj['facts'])
        self.assertEqual(['ROOM'], obj['category_candidates'])

    def test_semicolon_and_body_resets_do_not_leave_eof_hazard(self):
        for header in ('CUSTOM ROLE;\n',
                       'CUSTOM helper(){}\n', '#pragma warnings\nCUSTOM helper(){}\n',
                       'CUSTOM helper(){}\n#pragma warnings\n'):
            ext, _ = self.fixture('#define ROLE\n', header, continuation='')
            obj, _ = ext.extract()
            self.assertTrue(obj['supported_candidate'], header)
            self.assertEqual(['inherit', 'name', 'exit'], [f['field'] for f in obj['facts']])

    def test_directive_reset_preserves_late_incomplete_dependency_policy(self):
        # P2F29 already refuses this interrupted declaration in include_hazards.
        # The semicolon resets the shared gate; it does not certify the header.
        ext, _ = self.fixture('#define ROLE\n', 'CUSTOM value\n#pragma warnings\n;\n', continuation='')
        with patch.object(ext, 'include_hazards', wraps=ext.include_hazards) as late:
            obj, _ = ext.extract()
        late.assert_called_once()
        self.assertFalse(obj['supported_candidate'])
        self.assertEqual('OUT_OF_SCOPE', obj['status'])
        self.assertEqual([], obj['facts'])
        self.assertEqual(['ROOM'], obj['category_candidates'])

    def test_unused_definitions_and_unreferenced_header(self):
        root = 'inherit ROOM;\n' + self.tail
        self.assertEqual(extract(root), extract(root, dependencies={
            'd/unused.h': Source('d/unused.h', b'#define ROLE set\nCUSTOM ROLE')}))
        for header in ('#define ROLE set\n', '#define ROLE(x) x\n', 'int ordinary;\n#define ROLE set\n'):
            ext, _ = self.fixture('', header, continuation='')
            obj, _ = ext.extract()
            self.assertTrue(obj['supported_candidate'])

    def test_opaque_nested_lookalikes_do_not_create_pending_header(self):
        for header in ('void helper(){CUSTOM ROLE;}\n',
                       'void helper(){ {CUSTOM ROLE;} }\n',
                       'void helper(string arg="CUSTOM ROLE"){}\n',
                       'mapping data=(["key":"CUSTOM ROLE"]);\n',
                       'mixed *data=({"CUSTOM ROLE"});\n',
                       'string value="CUSTOM ROLE";\n', '/* CUSTOM ROLE */\n'):
            ext, _ = self.fixture('#define ROLE\n', header, continuation='')
            obj, _ = ext.extract()
            self.assertTrue(obj['supported_candidate'], header)

    def test_complete_and_literal_set_controls(self):
        self.assert_early_refusal(*self.fixture('#define STORE set\n', 'function STORE(){}\n', continuation=''))
        for dependency in (False, True):
            if dependency:
                ext, _ = self.fixture('', 'function set(string key,mixed value){}\n', continuation='')
                obj, _ = ext.extract()
            else:
                obj, _ = extract('inherit ROOM;\nfunction set(string key,mixed value){}\n' + self.tail)
            self.assertTrue(obj['supported_candidate'])
            self.assertEqual(['inherit'], [f['field'] for f in obj['facts']])


class P2F31RegressionTests(unittest.TestCase):
    tail = 'void create(){set("name","audit");set("exits",(["north":"/d/end"]));}\n'

    def root(self, definitions, declaration, newline='\n'):
        text = definitions + 'inherit ROOM;\n' + declaration + self.tail
        return RoomExtractor(Source('d/probe.c', text.replace('\n', newline).encode()), set(), {})

    def assert_refusal(self, ext):
        with contextlib.ExitStack() as stack:
            for method in ('inherit_keyword_preprocessing_use', 'include_hazards', 'create_body', 'fact'):
                stack.enter_context(patch.object(ext, method, side_effect=AssertionError('late path: ' + method)))
            obj, findings = ext.extract()
        self.assertFalse(obj['supported_candidate'])
        self.assertEqual('OUT_OF_SCOPE', obj['status'])
        for key in ('direct_inherits', 'category_candidates', 'facts'):
            self.assertEqual([], obj[key])
        self.assertEqual(2, len(findings))
        for f in findings:
            p = f['provenance']
            raw, start, end = ext.source.data, p['byte_start'], p['byte_end_exclusive']
            self.assertEqual(raw[start:end], p['raw'].encode())
            self.assertEqual(ext.source.path, p['source_path'])
            self.assertEqual(hashlib.sha256(raw).hexdigest(), p['source_sha256'])
            self.assertEqual(raw[:start].count(b'\n') + 1, p['line'])
            self.assertEqual(len(raw[raw.rfind(b'\n', 0, start) + 1:start].decode()) + 1, p['column'])
        return findings

    def test_invoked_set_and_independent_create_alias(self):
        shapes = [('#define inherit() set\n', 'void inherit()(string key,mixed value){}\n'),
                  ('#define BUILD create\n#define inherit(ignored) BUILD\n', 'mixed inherit(123)(){}\n')]
        for definitions, declaration in shapes:
            for newline in ('\n', '\r\n'):
                with self.subTest(declaration=declaration, newline=newline):
                    self.assert_refusal(self.root(definitions, declaration, newline))

    def test_reached_layouts_body_and_eof_provenance(self):
        factory = P2F30RegressionTests()
        for layout in ('local', 'nested', 'standard', 'cross', 'nested-cross'):
            for header, continuation in [('void inherit()(){}\n', ''), ('function inherit()\n', '(){}\n')]:
                for newline in ('\n', '\r\n'):
                    with self.subTest(layout=layout, header=header, newline=newline):
                        ext, origin = factory.fixture('#define inherit() set\n', header, continuation, layout, newline)
                        findings = self.assert_refusal(ext)
                        self.assertTrue(all(f['provenance']['raw'] == origin for f in findings))

    def test_uninvoked_function_macro_preserves_inheritance(self):
        for definitions in ('', '#define inherit(x) set\n', '#define inherit(x) create\n'):
            obj, _ = self.root(definitions, '').extract()
            self.assertTrue(obj['supported_candidate'])
            self.assertEqual(['inherit', 'name', 'exit'], [f['field'] for f in obj['facts']])

    def test_object_shadowing_keeps_p2f22_full_refusal(self):
        for definitions in ('#define inherit set\n', '#define BASE NEXT\n#define NEXT set\n#define inherit BASE\n'):
            obj, _ = self.root(definitions, '').extract()
            self.assertEqual('OUT_OF_SCOPE', obj['status'])
            self.assertFalse(obj['supported_candidate'])
            for key in ('direct_inherits', 'category_candidates', 'facts'):
                self.assertEqual([], obj[key])

    def test_unresolved_headers_preserve_all_macro_roles(self):
        for replacement in ('set', 'create', 'helper', '', 'mixed', 'x + y'):
            for prefix in ('function ', '* '):
                with self.subTest(replacement=replacement, prefix=prefix):
                    self.assert_refusal(self.root('#define inherit(x) ' + replacement + '\n',
                                                 prefix + 'inherit(opaque)(){}\n'))

    def test_macro_before_additional_authored_identifier(self):
        self.assert_refusal(self.root('#define inherit(x) mixed\n',
                                     'inherit(opaque) helper\n#pragma warnings\n(){}\n'))

    def test_directive_separated_invocation_is_not_keyword(self):
        for declaration in ('void inherit\n#pragma warnings\n()(){}\n',
                            'function inherit()\n#pragma warnings\n(){}\n'):
            self.assert_refusal(self.root('#define inherit() set\n', declaration))

    def test_competing_definitions_do_not_recover_keyword(self):
        self.assert_refusal(self.root('#define inherit(x) set\n#define inherit(x) helper\n',
                                     'void inherit(opaque)(){}\n'))

    def test_unreferenced_dependency_has_zero_effect(self):
        text = 'inherit ROOM;\n' + self.tail
        self.assertEqual(extract(text), extract(text, dependencies={
            'd/unused.h': Source('d/unused.h', b'#define inherit() set\nfunction inherit()')}))

    def test_root_and_dependency_eof_remain_distinct(self):
        ext = self.root('#define inherit() set\n', '')
        source = Source('d/header.h', b'#define inherit() set\nfunction inherit()')
        ts = lex(source)
        macros, *_ = ext.macro_context(ts)
        self.assertIsNone(ext.preprocessing_admission_structure_use(ts, macros))
        self.assertIsNotNone(ext.preprocessing_admission_structure_use(ts, macros, reached_dependency=True))

    def test_resets_and_opaque_groups_do_not_capture_body_uses(self):
        for declaration in ('CUSTOM inherit();\n', 'void helper(){inherit();}\n',
                            'void helper(){ { inherit(); } }\n',
                            'void helper(string s="inherit()"){}\n',
                            'mapping m=(["inherit()":1]);\n', 'mixed *a=({"inherit()"});\n',
                            '/* function inherit() */\n', '#pragma warnings\nvoid helper(){}\n'):
            ext = self.root('#define inherit()\n', declaration)
            ts = lex(ext.source)
            macros, *_ = ext.macro_context(ts)
            with self.subTest(declaration=declaration):
                self.assertIsNone(ext.preprocessing_admission_structure_use(ts, macros))


class P2F32RegressionTests(unittest.TestCase):
    definitions = '#define RETURN_TYPE mixed\n#define inherit() set\n'

    def refusal(self, definitions, header, continuation='()(){}\n', layout='local', newline='\n'):
        factory = P2F30RegressionTests()
        ext, origin = factory.fixture(definitions, header, continuation, layout, newline)
        factory.assert_early_refusal(ext, origin)

    def test_primary_lf_crlf_before_all_downstream_paths(self):
        for newline in ('\n', '\r\n'):
            self.refusal(self.definitions, 'RETURN_TYPE inherit\n',
                         '()(string key,mixed value){return 0;}\n', newline=newline)

    def test_independent_create_alias(self):
        for newline in ('\n', '\r\n'):
            self.refusal('#define RESULT function\n#define BUILD create\n#define inherit(ignored) BUILD\n',
                         'RESULT inherit\n', '(123)(){return 0;}\n', 'standard', newline)

    def test_all_five_layouts_use_root_include_provenance(self):
        for layout in ('local', 'nested', 'standard', 'cross', 'nested-cross'):
            for newline in ('\n', '\r\n'):
                with self.subTest(layout=layout, newline=newline):
                    self.refusal(self.definitions, 'RETURN_TYPE inherit\n', layout=layout, newline=newline)

    def test_active_prefix_roles_survive_keyword_spelling(self):
        for replacement in ('mixed', '', 'helper', 'set', 'create', 'x + y'):
            for function in (False, True):
                definition = '#define ROLE' + ('(x)' if function else '') + ' ' + replacement + '\n'
                use = 'ROLE(opaque)' if function else 'ROLE'
                with self.subTest(replacement=replacement, function=function):
                    self.refusal(definition + '#define inherit() set\n', use + ' inherit\n')
        self.refusal('#define ROLE NEXT\n#define NEXT mixed\n#define inherit() set\n', 'ROLE inherit\n')
        self.refusal('#define ROLE mixed\n#define ROLE helper\n#define inherit() set\n', 'ROLE inherit\n')

    def test_existing_unknown_header_witness_is_not_reset(self):
        self.refusal('#define EMPTY\n#define inherit() set\n', 'function EMPTY inherit\n')
        self.refusal('#define inherit() set\n', 'CUSTOM\n#pragma warnings\ninherit\n')

    def test_no_inherit_definition_still_preserves_active_header(self):
        self.refusal('#define PREFIX mixed\n', 'PREFIX inherit\n')

    def test_ordinary_uninvoked_and_undef_controls(self):
        body = 'inherit ROOM;\n' + P2F31RegressionTests.tail
        for definitions in ('', '#define inherit(x) set\n', '#define inherit(x) set\n#undef inherit\n'):
            obj, _ = extract(definitions + body)
            self.assertTrue(obj['supported_candidate'])
            self.assertEqual(['inherit', 'name', 'exit'], [f['field'] for f in obj['facts']])

    def test_invoked_and_object_shadowing_remain_refused(self):
        factory = P2F31RegressionTests()
        factory.assert_refusal(factory.root('#define inherit() set\n', 'void inherit()(){}\n'))
        obj, _ = extract('#define inherit set\ninherit ROOM;\n' + factory.tail)
        self.assertEqual('OUT_OF_SCOPE', obj['status'])
        for key in ('facts', 'direct_inherits', 'category_candidates'):
            self.assertEqual([], obj[key])

    def test_semicolon_and_completed_body_reset_header_state(self):
        for reset in ('PREFIX value;\n', 'PREFIX helper(){}\n', 'void helper(){PREFIX;}\n'):
            ext = P2F31RegressionTests().root('#define PREFIX mixed\n#define inherit(x) set\n', '')
            text = '#define PREFIX mixed\n#define inherit(x) set\n' + reset + 'inherit ROOM;\n' + P2F31RegressionTests.tail
            ts = lex(Source('d/probe.c', text.encode()))
            macros, *_ = ext.macro_context(ts)
            self.assertIsNone(ext.preprocessing_admission_structure_use(ts, macros))
            obj, _ = extract(text)
            self.assertTrue(obj['supported_candidate'])
            self.assertEqual(['inherit', 'name', 'exit'], [f['field'] for f in obj['facts']])

    def test_no_preprocessing_prefix_is_not_new_uncertainty(self):
        ext = P2F31RegressionTests().root('', '')
        for prefix in ('mixed', 'function', 'CUSTOM', '*'):
            ts = lex(Source('d/unit.h', (prefix + ' inherit').encode()))
            macros, *_ = ext.macro_context(ts)
            self.assertIsNone(ext.preprocessing_admission_structure_use(ts, macros, reached_dependency=True))

    def test_opaque_regions_do_not_start_header_state(self):
        for text in ('void helper(){ROLE inherit;}\n', 'void helper(){{ROLE inherit;}}\n',
                     'void helper(mixed ROLE, mixed inherit){}\n',
                     'mapping m=(["ROLE":"inherit"]);\n', 'mixed *a=({"ROLE","inherit"});\n',
                     'string s="ROLE inherit";\n', '/* ROLE inherit */\n'):
            ext = P2F31RegressionTests().root('#define ROLE mixed\n#define inherit(x) set\n', text)
            ts = lex(ext.source)
            macros, *_ = ext.macro_context(ts)
            self.assertIsNone(ext.preprocessing_admission_structure_use(ts, macros))

    def test_unreferenced_header_has_no_effect(self):
        text = 'inherit ROOM;\n' + P2F31RegressionTests.tail
        self.assertEqual(extract(text), extract(text, dependencies={
            'd/unused.h': Source('d/unused.h', (self.definitions + 'RETURN_TYPE inherit').encode())}))


class P2F33RegressionTests(unittest.TestCase):
    def refusal(self, definitions, header, continuation='set(string k,mixed v){}\n',
                layout='local', newline='\n'):
        factory = P2F30RegressionTests()
        factory.assert_early_refusal(*factory.fixture(definitions, header, continuation, layout, newline))

    def test_primary_before_all_downstream_processing(self):
        for newline in ('\n', '\r\n'):
            self.refusal('#define RETURN_TYPE mixed\n', 'RETURN_TYPE\n', newline=newline)

    def test_independent_function_prefix_create(self):
        for newline in ('\n', '\r\n'):
            self.refusal('#define RESULT(ignored) void\n', 'RESULT(123)\n',
                         'create(){return;}\n', 'standard', newline)

    def test_prefix_and_empty_roles_both_remain_pending(self):
        for value in ('mixed', ''):
            for macro, use in (('ROLE', 'ROLE'), ('ROLE(x)', 'ROLE(opaque)')):
                self.refusal('#define ' + macro + ' ' + value + '\n', use + '\n')

    def test_alias_chains_preserve_pending_evidence(self):
        for value in ('mixed', ''):
            self.refusal('#define FIRST NEXT\n#define NEXT LAST\n#define LAST ' + value + '\n', 'FIRST\n')
            self.refusal('#define FIRST() NEXT\n#define NEXT(x) ' + value + '\n', 'FIRST()(opaque)\n')

    def test_sequential_consumed_roles_do_not_discharge(self):
        definitions = '#define TYPE mixed\n#define EMPTY(x)\n#define MOD private\n'
        for header in ('TYPE EMPTY(opaque) MOD\n', 'EMPTY(opaque) TYPE\n', 'TYPE MOD\n'):
            self.refusal(definitions, header)

    def test_competing_prefix_like_definitions_remain_pending(self):
        self.refusal('#define ROLE mixed\n#define ROLE\n', 'ROLE\n')
        self.refusal('#define ROLE(x) private\n#define ROLE(x) void\n', 'ROLE(opaque)\n')

    def test_directives_do_not_discharge_active_prefix(self):
        for directive in ('#pragma warnings\n', '#define UNRELATED 1\n', '#undef UNRELATED\n'):
            self.refusal('#define TYPE mixed\n', 'TYPE\n' + directive)
        self.refusal('', 'CUSTOM\n#pragma warnings\n')

    def test_other_macro_roles_and_unknown_headers_remain_pending(self):
        for value in ('set', 'create', 'helper', 'x + y', 'function'):
            for header in ('ROLE\n', 'ROLE CUSTOM\n', 'ROLE *\n', 'CUSTOM ROLE\n'):
                self.refusal('#define ROLE ' + value + '\n', header)

    def test_all_dependency_layouts_and_raw_provenance(self):
        for layout in ('local', 'nested', 'standard', 'cross', 'nested-cross'):
            for newline in ('\n', '\r\n'):
                self.refusal('#define TYPE mixed\n', 'TYPE\n', layout=layout, newline=newline)

    def test_semicolon_and_body_discharge_before_later_inheritance(self):
        for header in ('TYPE value;\n', 'TYPE helper(){}\n', 'TYPE {}\n'):
            text = '#define TYPE mixed\n' + header + 'inherit ROOM;\n' + P2F30RegressionTests.tail
            ext = RoomExtractor(Source('d/probe.c', text.encode()), set(), {})
            ts = lex(ext.source)
            macros, *_ = ext.macro_context(ts)
            self.assertIsNone(ext.preprocessing_admission_structure_use(ts, macros, reached_dependency=True))

    def test_existing_direct_proof_is_not_new_uncertainty(self):
        for header in ('TYPE helper(){}\n', 'TYPE helper(string arg){}\n'):
            ext, _ = P2F30RegressionTests().fixture('#define TYPE mixed\n', header, '')
            obj, _ = ext.extract()
            self.assertTrue(obj['supported_candidate'])
            self.assertEqual(['inherit', 'name', 'exit'], [f['field'] for f in obj['facts']])

    def test_unused_unreferenced_and_no_preprocessing_controls(self):
        for header in ('#define TYPE mixed\n', '#define TYPE(x)\n', 'CUSTOM\n', 'function *\n'):
            ext = RoomExtractor(Source('d/unit.h', header.encode()), set(), {})
            ts = lex(ext.source)
            macros, *_ = ext.macro_context(ts)
            self.assertIsNone(ext.preprocessing_admission_structure_use(ts, macros, reached_dependency=True))
        text = 'inherit ROOM;\n' + P2F30RegressionTests.tail
        self.assertEqual(extract(text), extract(text, dependencies={
            'd/unused.h': Source('d/unused.h', b'#define TYPE mixed\nTYPE\n')}))

    def test_opaque_regions_do_not_create_pending_declarations(self):
        for header in ('void helper(){TYPE;}\n', 'void helper(){{TYPE;}}\n',
                       'void helper(mixed TYPE){}\n', 'mapping m=(["TYPE":1]);\n',
                       'mixed *a=({"TYPE"});\n', 'string s="TYPE";\n', '/* TYPE */\n',
                       'string s=@TEXT\nTYPE\nTEXT\n;\n'):
            ext, _ = P2F30RegressionTests().fixture('#define TYPE mixed\n', header, '')
            ts = lex(ext.source)
            macros, units, *_ = ext.macro_context(ts)
            for _, tokens in units:
                self.assertIsNone(ext.preprocessing_admission_structure_use(tokens, macros, reached_dependency=True))

    def test_root_eof_is_not_reached_dependency_eof(self):
        ext = RoomExtractor(Source('d/probe.c', b'#define TYPE mixed\nTYPE'), set(), {})
        ts = lex(ext.source)
        macros, *_ = ext.macro_context(ts)
        self.assertIsNone(ext.preprocessing_admission_structure_use(ts, macros))
        self.assertIsNotNone(ext.preprocessing_admission_structure_use(ts, macros, reached_dependency=True))

    def test_fr29_through_fr32_common_pending_invariant(self):
        for definitions, header in (
            ('#define STORE() set\n', 'function STORE()\n'),
            ('#define inherit() set\n', 'function inherit()\n'),
            ('#define TYPE mixed\n#define inherit() set\n', 'TYPE inherit\n'),
            ('#define TYPE mixed\n', 'TYPE\n')):
            for layout in ('local', 'standard'):
                self.refusal(definitions, header, layout=layout)


if __name__ == '__main__':
    unittest.main()
