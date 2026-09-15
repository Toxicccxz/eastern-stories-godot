"""Static ROOM declarations and audit findings, never final runtime state."""

from __future__ import annotations

import hashlib
import json
import posixpath
from collections import Counter
from enum import StrEnum
from pathlib import Path

from .es2_source import Source, SourceError, Token, ToolError, discover, lex, literal, pairs


class FindingCode(StrEnum):
    REQUIRES_SEMANTIC_REVIEW = 'REQUIRES_SEMANTIC_REVIEW'
    UNRESOLVED_INHERITANCE = 'UNRESOLVED_INHERITANCE'
    UNRESOLVED_INCLUDE = 'UNRESOLVED_INCLUDE'
    DYNAMIC_EXPRESSION = 'DYNAMIC_EXPRESSION'
    ORDER_SENSITIVE_MUTATION = 'ORDER_SENSITIVE_MUTATION'
    RNG_SEMANTICS = 'RNG_SEMANTICS'
    CALLBACK_BEHAVIOR = 'CALLBACK_BEHAVIOR'
    DRIVER_SEMANTICS_UNKNOWN = 'DRIVER_SEMANTICS_UNKNOWN'
    SOURCE_SYNTAX_ERROR = 'SOURCE_SYNTAX_ERROR'
    SOURCE_ENCODING_ISSUE = 'SOURCE_ENCODING_ISSUE'
    DUPLICATE_DECLARATION = 'DUPLICATE_DECLARATION'
    UNRESOLVED_REFERENCE = 'UNRESOLVED_REFERENCE'
    UNSUPPORTED_CONSTRUCT = 'UNSUPPORTED_CONSTRUCT'
    OUT_OF_SCOPE = 'OUT_OF_SCOPE'


FLAGS = {'outdoors', 'indoors', 'no_clean_up', 'no_fight'}
TEXT_FIELDS = {'short', 'name', 'long'}
EXTRACTOR_VERSION = '1.0.3'
KNOWN_EXTRACTOR_VERSIONS = {'1.0.0', '1.0.1', '1.0.2', '1.0.3'}
PROFILE = 'static-room-v1'
# Exact object constants from reference/es2/mudlib/include/{globals,weapon,armor}.h.
# Admission evidence only: no path guessing, subclass lookup or macro evaluation.
EXCLUDED_LITERAL_BASES = {
    '/std/room/bank': 'BANK', '/std/room/class_guild': 'CLASS_GUILD',
    '/std/force': 'FORCE', '/std/room/hockshop': 'HOCKSHOP', '/std/item': 'ITEM',
    '/std/liquid': 'LIQUID', '/std/char/npc': 'NPC', '/std/skill': 'SKILL',
    '/std/money': 'MONEY', '/std/item/combined': 'COMBINED_ITEM',
    '/std/weapon/axe': 'AXE', '/std/weapon/blade': 'BLADE',
    '/std/weapon/dagger': 'DAGGER', '/std/weapon/fork': 'FORK',
    '/std/weapon/hammer': 'HAMMER', '/std/weapon/sword': 'SWORD',
    '/std/weapon/staff': 'STAFF', '/std/weapon/throwing': 'THROWING',
    '/std/weapon/whip': 'WHIP',
    '/std/armor/head': 'HEAD', '/std/armor/neck': 'NECK',
    '/std/armor/cloth': 'CLOTH', '/std/armor/armor': 'ARMOR',
    '/std/armor/surcoat': 'SURCOAT', '/std/armor/waist': 'WAIST',
    '/std/armor/wrists': 'WRISTS', '/std/armor/shield': 'SHIELD',
    '/std/armor/finger': 'FINGER', '/std/armor/hands': 'HANDS',
    '/std/armor/boots': 'BOOTS',
}


def directive_parts(token: Token) -> list[str]:
    # Splice only the analysis view. Map diagnostic offsets back to original bytes;
    # token text and all stored provenance retain authored LF/CRLF continuations.
    raw = token.text.encode('utf-8')
    view, offsets = bytearray(), []
    i = 1  # skip '#'
    while i < len(raw):
        if raw.startswith(b'\\\r\n', i):
            i += 3
        elif raw.startswith(b'\\\n', i):
            i += 2
        else:
            offsets.append(i)
            view.append(raw[i])
            i += 1
    offsets.append(len(raw))
    try:
        return [t.text for t in lex(Source('directive', bytes(view)))]
    except SourceError as error:
        raise SourceError(str(error), token.start + offsets[error.start],
                          token.start + offsets[error.end], encoding=error.encoding) from error


def validate_document(document: dict) -> None:
    """Closed generated schema shared by serialization and overwrite recognition.

    The known patch versions share these shapes. Unknown future fields are
    preserved by rejecting the document, never by stripping or ignoring them.
    This validates structure/integrity, not authorship or LPC semantics.
    """
    def require(condition: bool, reason: str) -> None:
        if not condition:
            raise ToolError('IR validation: ' + reason)

    def record(value, *, strings='', integers='', lists='', booleans='', dictionaries='', nullable_strings=''):
        groups = ((strings, str), (integers, int), (lists, list), (booleans, bool),
                  (dictionaries, dict), (nullable_strings, (str, type(None))))
        expected = {key: kind for names, kind in groups for key in names.split()}
        require(type(value) is dict and set(value) == set(expected), 'unknown or missing record fields')
        for key, kind in expected.items():
            allowed = kind if isinstance(kind, tuple) else (kind,)
            require(type(value[key]) in allowed, 'invalid field type: ' + key)
        for key in integers.split():
            require(value[key] >= 0, 'negative count/offset: ' + key)

    def sha(value: str) -> None:
        require(len(value) == 64 and all(c in '0123456789abcdef' for c in value), 'invalid SHA-256')

    def string_list(value: list) -> None:
        require(all(type(x) is str for x in value), 'invalid string array')

    def unreviewed(value: dict) -> None:
        require(value['review_state'] == 'UNREVIEWED', 'reviewed data is not generated output')

    def provenance(p: dict, obj: dict, size: int) -> None:
        extra = ' raw_hex' if type(p) is dict and p.get('raw') is None else ''
        record(p, strings='source_path source_sha256 scope construct' + extra,
               integers='source_ordinal byte_start byte_end_exclusive line column', nullable_strings='raw')
        require(p['source_path'] == obj['source_path'] and p['source_sha256'] == obj['source_sha256'],
                'provenance source mismatch')
        require(p['byte_start'] <= p['byte_end_exclusive'] <= size and p['line'] > 0 and p['column'] > 0,
                'invalid provenance range/location')
        if p['raw'] is None:
            require(len(p['raw_hex']) % 2 == 0 and all(c in '0123456789abcdef' for c in p['raw_hex']),
                    'invalid raw_hex')
            raw = bytes.fromhex(p['raw_hex'])
            try:
                raw.decode('utf-8')
            except UnicodeDecodeError:
                pass
            else:
                raise ToolError('IR validation: raw_hex variant must represent undecodable UTF-8')
        else:
            raw = p['raw'].encode('utf-8')
        require(len(raw) == p['byte_end_exclusive'] - p['byte_start'], 'raw/span length mismatch')

    record(document, strings='extractor_version profile review_state', integers='schema_version',
           lists='objects findings', dictionaries='source_manifest summary')
    require(document['schema_version'] == 1 and document['profile'] == PROFILE
            and document['extractor_version'] in KNOWN_EXTRACTOR_VERSIONS, 'unsupported schema/profile/version')
    unreviewed(document)
    record(document['source_manifest'], strings='sha256', lists='files')
    sha(document['source_manifest']['sha256'])
    objects, manifest = document['objects'], document['source_manifest']['files']
    require(bool(manifest) and len(objects) == len(manifest), 'manifest coverage')
    statuses = {'EXTRACTED', 'PARTIAL', 'OUT_OF_SCOPE', 'QUARANTINED'}
    known_codes = {code.value for code in FindingCode}
    digest = hashlib.sha256()
    by_id, sizes = {}, {}
    for obj, item in zip(objects, manifest):
        record(obj, strings='object_id source_path source_sha256 review_state status input_path source_namespace',
               booleans='supported_candidate', lists='category_candidates direct_inherits facts finding_ids')
        record(item, strings='input_path source_path kind source_namespace sha256 status review_state', integers='size_bytes')
        unreviewed(obj)
        unreviewed(item)
        sha(item['sha256'])
        require(obj['object_id'] not in by_id, 'object identity collision')
        by_id[obj['object_id']], sizes[obj['object_id']] = obj, item['size_bytes']
        require(obj['status'] in statuses and item['status'] == obj['status'], 'object/manifest status mismatch')
        require(item['kind'] in {'LPC_SOURCE', 'HEADER', 'OTHER'} and obj['source_namespace'] in {'mudlib', 'source-root'},
                'invalid source kind/namespace')
        for key in ('input_path', 'source_path', 'source_namespace'):
            require(item[key] == obj[key], 'object/manifest identity mismatch')
        require(item['sha256'] == obj['source_sha256'], 'object/manifest hash mismatch')
        digest.update(item['input_path'].encode('utf-8') + b'\0' + item['sha256'].encode('ascii') + b'\n')
        string_list(obj['category_candidates'])
        string_list(obj['finding_ids'])
        require(obj['status'] not in {'OUT_OF_SCOPE', 'QUARANTINED'} or not obj['facts'], 'ineligible object facts')
        for declaration in obj['direct_inherits']:
            record(declaration, strings='expression', nullable_strings='symbol', dictionaries='provenance')
            provenance(declaration['provenance'], obj, item['size_bytes'])
        for fact in obj['facts']:
            require(type(fact) is dict, 'invalid fact')
            is_long = fact.get('field') == 'long'
            normalized = fact.get('classification') == 'STATIC_NORMALIZED'
            record(fact, strings='fact_id field classification review_state' + (' text_classification' if is_long else ''),
                   dictionaries='value provenance' + (' normalization' if normalized else ''))
            unreviewed(fact)
            sha(fact['fact_id'])
            field = fact['field']
            require(field in TEXT_FIELDS | FLAGS | {'inherit', 'exit'}, 'unsupported fact field')
            require(fact['classification'] in {'EXACT_LITERAL', 'STATIC_NORMALIZED'}, 'invalid classification')
            require(not normalized or field == 'exit', 'normalization on non-exit fact')
            if is_long:
                require(fact['text_classification'] == 'TEXT_ONLY', 'invalid long classification')
            provenance(fact['provenance'], obj, item['size_bytes'])
            value = fact['value']
            if field == 'exit':
                record(value, strings='kind direction target direction_raw target_raw', dictionaries='reference')
                require(value['kind'] == 'exit', 'invalid exit kind')
                ref = value['reference']
                record(ref, strings='target status', lists='candidates')
                string_list(ref['candidates'])
                require(ref['target'] == value['target'] and ref['status'] in
                        {'EXISTS', 'CASE_MISMATCH', 'AMBIGUOUS', 'MISSING', 'UNRESOLVED'}, 'invalid exit reference')
            else:
                record(value, strings='kind value')
                allowed = {'reference'} if field == 'inherit' else {'text'} if field in TEXT_FIELDS else {'text', 'integer'}
                require(value['kind'] in allowed, 'invalid typed value kind')
                if value['kind'] == 'integer':
                    text = value['value']
                    require(bool(text) and all(c in '0123456789' for c in text)
                            and (text == '0' or not text.startswith('0')), 'invalid decimal integer')
            if normalized:
                normalization = fact['normalization']
                record(normalization, strings='rule', integers='version', lists='inputs')
                require(normalization['rule'] == 'SOURCE_DIR_LITERAL_CONCAT' and normalization['version'] == 1
                        and len(normalization['inputs']) == 1, 'invalid normalization')
                provenance(normalization['inputs'][0], obj, item['size_bytes'])
    paths = [item['input_path'] for item in manifest]
    require(paths == sorted(set(paths)), 'manifest ordering/duplicate path')
    require(digest.hexdigest() == document['source_manifest']['sha256'], 'manifest digest mismatch')
    actual_ids = {identity: [] for identity in by_id}
    for finding in document['findings']:
        record(finding, strings='code severity object_id reason review_state finding_id',
               booleans='prevents_supported_consumption', dictionaries='provenance')
        unreviewed(finding)
        require(finding['code'] in known_codes and finding['severity'] in {'INFO', 'WARNING', 'ERROR'}, 'invalid finding')
        require(finding['object_id'] in by_id, 'unknown finding object')
        identity = finding['object_id']
        actual_ids[identity].append(finding['finding_id'])
        require(finding['finding_id'] == f'{identity}:{len(actual_ids[identity])}', 'finding identity/order mismatch')
        provenance(finding['provenance'], by_id[identity], sizes[identity])
    require(actual_ids == {identity: obj['finding_ids'] for identity, obj in by_id.items()}, 'finding references mismatch')
    summary = document['summary']
    record(summary, integers='scanned_files supported_candidates total_findings', dictionaries='statuses finding_codes')
    record(summary['statuses'], integers='EXTRACTED PARTIAL OUT_OF_SCOPE QUARANTINED')
    require(set(summary['finding_codes']) <= known_codes, 'unknown finding count code')
    require(all(type(count) is int and count > 0 for count in summary['finding_codes'].values()), 'invalid finding count')
    counts = Counter(obj['status'] for obj in objects)
    expected = dict(scanned_files=len(objects), supported_candidates=sum(o['supported_candidate'] for o in objects),
                    statuses={key: counts[key] for key in statuses}, total_findings=len(document['findings']),
                    finding_codes=dict(Counter(f['code'] for f in document['findings'])))
    require(summary == expected, 'summary mismatch')


def canonical(document: dict) -> bytes:
    validate_document(document)
    return (json.dumps(document, ensure_ascii=False, indent=2, allow_nan=False) + '\n').encode('utf-8')


def split_at(tokens: list[Token], separator: str) -> list[list[Token]]:
    matching = pairs(tokens)
    groups, start, i = [], 0, 0
    while i < len(tokens):
        if i in matching:
            i = matching[i] + 1
        elif tokens[i].text == separator and tokens[i].kind == 'punctuation':
            groups.append(tokens[start:i])
            start = i + 1
            i += 1
        else:
            i += 1
    groups.append(tokens[start:])
    return groups


def reference(target: str, paths: set[str]) -> dict:
    """Check authored absolute LPC paths; do not repair paths or case."""
    if not target.startswith('/') or '\\' in target or '\x00' in target:
        return {'target': target, 'status': 'UNRESOLVED', 'candidates': []}
    pieces = target[1:].split('/')
    if any(piece in ('', '.', '..') for piece in pieces):
        return {'target': target, 'status': 'UNRESOLVED', 'candidates': []}
    path = target[1:] if target.endswith('.c') else target[1:] + '.c'
    if path in paths:
        return {'target': target, 'status': 'EXISTS', 'candidates': [path]}
    matches = sorted(p for p in paths if p.casefold() == path.casefold())
    return {'target': target, 'status': ('CASE_MISMATCH' if len(matches) == 1 else
                                       'AMBIGUOUS' if matches else 'MISSING'), 'candidates': matches}


class RoomExtractor:
    def __init__(self, source: Source, paths: set[str], dependencies: dict[str, Source]):
        self.source, self.paths, self.dependencies = source, paths, dependencies
        self.tokens: list[Token] = []
        self.findings: list[dict] = []
        self.facts: list[dict] = []
        self.inherits: list[dict] = []
        self.scopes: dict[int, str] = {}
        self.declarations: Counter = Counter()
        self.record = dict(object_id='es2:' + source.path.removesuffix('.c'),
                           source_path=source.path, source_sha256=source.sha256,
                           review_state='UNREVIEWED', status='OUT_OF_SCOPE', supported_candidate=False,
                           category_candidates=[], direct_inherits=self.inherits, facts=self.facts,
                           finding_ids=[])

    def provenance(self, ts: list[Token], scope: str, construct: str) -> dict:
        if not ts:
            return self.source.span(0, 0, scope, construct, 0)
        # Token index is a source-order ordinal, not a runtime execution counter.
        ordinal = next(i + 1 for i, t in enumerate(self.tokens) if t.start == ts[0].start)
        return self.source.span(ts[0].start, ts[-1].end, scope, construct, ordinal)

    def finding(self, code: FindingCode, reason: str, ts: list[Token], scope: str = 'top-level',
                *, severity: str = 'WARNING', blocks: bool = True) -> None:
        self.findings.append(dict(code=code.value, severity=severity,
                                 object_id=self.record['object_id'], reason=reason,
                                 prevents_supported_consumption=blocks,
                                 provenance=self.provenance(ts, scope, code.value)))

    def fact(self, field: str, value: dict, ts: list[Token], scope: str = 'create',
             *, normalized: dict | None = None) -> None:
        provenance = self.provenance(ts, scope, 'inherit' if field == 'inherit' else 'call:set')
        identity = f"{self.source.path}\0{self.source.sha256}\0{field}\0{ts[0].start}\0{ts[-1].end}"
        fact = dict(fact_id=hashlib.sha256(identity.encode('utf-8')).hexdigest(), field=field,
                    classification='STATIC_NORMALIZED' if normalized else 'EXACT_LITERAL',
                    review_state='UNREVIEWED', value=value, provenance=provenance)
        if field == 'long':
            fact['text_classification'] = 'TEXT_ONLY'
        if normalized:
            fact['normalization'] = normalized
        self.facts.append(fact)

    def include_hazards(self, ts: list[Token], visited: set[str] | None = None) -> set[str]:
        """Dependency inspection only: no macro expansion or condition evaluation."""
        visited = set() if visited is None else visited
        hazards: set[str] = set()
        for token in ts:
            if token.kind != 'directive':
                continue
            words = directive_parts(token)
            if not words:
                continue
            directive = words[0]
            if directive in ('define', 'undef') and len(words) > 1:
                name = words[1]
                if name in {'ROOM', '__DIR__', 'set', 'create'}:
                    hazards.add(name)
            if directive == 'include':
                authored = ''.join(words[1:])
                if authored.startswith('<') and authored.endswith('>'):
                    path = 'include/' + authored[1:-1]
                elif authored.startswith('"') and authored.endswith('"'):
                    path = posixpath.join(posixpath.dirname(self.source.path), authored[1:-1])
                else:
                    hazards.add('unresolved include')
                    continue
                if '..' in path.split('/') or path.startswith('/') or path not in self.dependencies:
                    hazards.add('unresolved include')
                    continue
                if path not in visited:
                    visited.add(path)
                    dep = RoomExtractor(self.dependencies[path], self.paths, self.dependencies)
                    try:
                        hazards.update(dep.include_hazards(lex(dep.source), visited))
                    except SourceError:
                        hazards.add('unresolved include')
        return hazards

    def extract(self) -> tuple[dict, list[dict]]:
        try:
            self.tokens = lex(self.source)
            conditional = any(t.kind == 'directive' and directive_parts(t)[:1] in
                              [['if'], ['ifdef'], ['ifndef'], ['else'], ['elif'], ['endif']] for t in self.tokens)
            if conditional:
                self.finding(FindingCode.OUT_OF_SCOPE, 'Conditional compilation prevents reliable profile admission.', self.tokens[:1], severity='INFO')
                self.finding(FindingCode.DRIVER_SEMANTICS_UNKNOWN, 'Preprocessor branches retained without evaluating or balancing mutually exclusive code.', self.tokens)
            else:
                matching = pairs(self.tokens)
                self.extract_structure(matching)
        except SourceError as error:
            self.facts.clear()
            self.record['status'] = 'QUARANTINED'
            self.findings.append(dict(code=(FindingCode.SOURCE_ENCODING_ISSUE if error.encoding else
                                           FindingCode.SOURCE_SYNTAX_ERROR).value,
                                     severity='ERROR', object_id=self.record['object_id'],
                                     reason=str(error), prevents_supported_consumption=True,
                                     provenance=self.source.span(error.start, error.end, 'unknown', 'source-error', 0)))
        self.facts.sort(key=lambda f: (f['provenance']['byte_start'], f['provenance']['byte_end_exclusive'], f['field']))
        self.findings.sort(key=lambda f: (f['provenance']['byte_start'], f['code'], f['reason']))
        for index, finding in enumerate(self.findings):
            finding['review_state'] = 'UNREVIEWED'
            finding['finding_id'] = f"{self.record['object_id']}:{index + 1}"
            self.record['finding_ids'].append(finding['finding_id'])
        return self.record, self.findings

    def extract_structure(self, matching: dict[int, int]) -> None:
        ts = self.tokens
        functions: list[tuple[str, int, int, int]] = []
        unknown_top: list[list[Token]] = []
        i, start = 0, 0
        while i < len(ts):
            token = ts[i]
            if token.kind == 'directive':
                if start < i:
                    unknown_top.append(ts[start:i])
                start = i + 1
                i += 1
                continue
            if token.text == 'inherit' and i == start:
                end = i + 1
                while end < len(ts) and ts[end].text != ';':
                    end += 1
                if end == len(ts):
                    raise SourceError('unterminated inherit', token.start, token.end)
                expr = ts[i + 1:end]
                symbol = expr[0].text if len(expr) == 1 else None
                self.inherits.append(dict(expression=self.source.data[token.end:ts[end].start].decode('utf-8').strip(),
                                          symbol=symbol, provenance=self.provenance(ts[i:end + 1], 'top-level', 'inherit')))
                if symbol:
                    self.record['category_candidates'].append(symbol)
                if len(expr) == 1 and expr[0].kind == 'string':
                    base = literal(expr[0])
                    category = EXCLUDED_LITERAL_BASES.get(base['value']) if base else None
                    if category:
                        self.record['category_candidates'].append(category)
                i = end + 1
                start = i
                continue
            if token.text == '(' and i in matching:
                close = matching[i]
                if i > start and ts[i - 1].kind == 'identifier' and close + 1 < len(ts) and ts[close + 1].text == '{':
                    end = matching[close + 1]
                    name = ts[i - 1].text
                    functions.append((name, start, close + 1, end))
                    for j in range(start, end + 1):
                        self.scopes[j] = name
                    i, start = end + 1, end + 1
                    continue
            if i in matching:
                i = matching[i] + 1
            elif token.text == ';':
                unknown_top.append(ts[start:i + 1])
                i += 1
                start = i
            else:
                i += 1
        if start < len(ts):
            unknown_top.append(ts[start:])
        direct = any(x['symbol'] == 'ROOM' for x in self.inherits)
        hazards = self.include_hazards(ts)
        excluded = {'BANK', 'HOCKSHOP', 'CLASS_GUILD', 'NPC', 'ITEM', 'MONEY', 'COMBINED_ITEM', 'WEAPON', 'ARMOR',
                    'SWORD', 'BLADE', 'HAMMER', 'AXE', 'STAFF', 'WHIP', 'SPEAR', 'THROWING',
                    'DAGGER', 'FORK', 'SURCOAT', 'WAIST', 'WRISTS', 'HANDS',
                    'F_FOOD', 'F_LIQUID', 'F_VENDOR', 'F_MASTER', 'LIQUID', 'CLOTH', 'BOOTS',
                    'GLOVES', 'HEAD', 'NECK', 'FINGER', 'SHIELD', 'SKILL', 'FORCE', 'DAEMON'}
        supported = (self.source.path.startswith('d/') and self.source.path.endswith('.c') and direct
                     and not hazards.intersection({'ROOM', 'unresolved include'})
                     and not excluded.intersection(self.record['category_candidates']))
        self.record['supported_candidate'] = supported
        if not supported:
            self.finding(FindingCode.OUT_OF_SCOPE, 'Not an unconditional reliable direct ROOM under d/.',
                         ts[:1], severity='INFO')
            if direct and hazards:
                self.finding(FindingCode.UNRESOLVED_INHERITANCE, 'Preprocessor context prevents reliable ROOM identification.', ts[:1])
            if 'unresolved include' in hazards:
                for token in ts:
                    if token.kind == 'directive' and directive_parts(token)[:1] == ['include']:
                        self.finding(FindingCode.UNRESOLVED_INCLUDE, 'Include dependency context cannot be resolved reliably.', [token])
            return
        self.record['status'] = 'EXTRACTED'
        for declaration in self.inherits:
            p = declaration['provenance']
            decl = [t for t in ts if p['byte_start'] <= t.start < p['byte_end_exclusive']]
            self.fact('inherit', {'kind': 'reference', 'value': declaration['expression']}, decl, 'top-level')
            self.finding(FindingCode.REQUIRES_SEMANTIC_REVIEW, 'Inheritance is a source dependency, not evaluated defaults.', decl,
                         blocks=False, severity='INFO')
            if declaration['symbol'] != 'ROOM':
                self.finding(FindingCode.UNRESOLVED_INHERITANCE, 'Additional inheritance is not resolved by this profile.', decl)
        for token in ts:
            if token.kind == 'directive':
                code = FindingCode.UNRESOLVED_INCLUDE if 'unresolved include' in hazards else FindingCode.UNSUPPORTED_CONSTRUCT
                self.finding(code, 'Directive retained; no preprocessor execution or general macro expansion.', [token])
        for statement in unknown_top:
            self.finding(FindingCode.UNSUPPORTED_CONSTRUCT, 'Top-level construct outside the supported declaration subset.', statement)
        create_functions = [f for f in functions if f[0] == 'create']
        shadowed = any(f[0] == 'set' for f in functions) or bool(hazards & {'set', 'create', 'unresolved include'})
        for name, first, opening, end in functions:
            if name != 'create':
                self.finding(FindingCode.CALLBACK_BEHAVIOR, 'Function body retained for human semantic review.', ts[first:end + 1], name)
            elif len(create_functions) != 1 or shadowed:
                self.finding(FindingCode.UNSUPPORTED_CONSTRUCT, 'Duplicate create or unresolved/shadowed setter scope.', ts[first:end + 1], name)
            else:
                self.create_body(ts[opening + 1:end], hazards)
        if not create_functions:
            self.finding(FindingCode.UNSUPPORTED_CONSTRUCT, 'No unambiguous create() body.', ts[:1])
        self.dynamic_findings()
        if any(f['prevents_supported_consumption'] for f in self.findings):
            self.record['status'] = 'PARTIAL'

    def create_body(self, ts: list[Token], hazards: set[str]) -> None:
        # Semicolon-delimited outer statements only. Nested expressions are never scanned as initial state.
        matching = pairs(ts)
        start, i = 0, 0
        while i < len(ts):
            if ts[i].text == '{':
                end = matching[i]
                self.finding(FindingCode.UNSUPPORTED_CONSTRUCT, 'Conditional/nested create scope is not extracted.', ts[start:end + 1], 'create')
                start, i = end + 1, end + 1
            elif i in matching:
                i = matching[i] + 1
            elif ts[i].text == ';':
                self.statement(ts[start:i + 1], hazards)
                start, i = i + 1, i + 1
            else:
                i += 1
        if start < len(ts):
            raise SourceError('unterminated create statement', ts[start].start, ts[-1].end)

    def statement(self, ts: list[Token], hazards: set[str]) -> None:
        if len(ts) == 1:
            return
        matching = pairs(ts)
        if len(ts) < 4 or ts[0].kind != 'identifier' or ts[1].text != '(' or matching.get(1) != len(ts) - 2:
            self.finding(FindingCode.UNSUPPORTED_CONSTRUCT, 'Statement receiver/control/expression outside static subset.', ts, 'create')
            return
        if ts[0].text != 'set':
            self.finding(FindingCode.REQUIRES_SEMANTIC_REVIEW, 'Call is a reference only; lifecycle/door/population is not executed.', ts, 'create')
            return
        args = split_at(ts[2:-2], ',')
        key = literal(args[0][0]) if args and len(args[0]) == 1 else None
        if len(args) != 2 or not key or key['kind'] != 'text':
            self.finding(FindingCode.DYNAMIC_EXPRESSION, 'Setter key/argument shape is not a supported literal declaration.', ts, 'create')
            return
        field = key['value']
        if self.declarations[field]:
            self.finding(FindingCode.DUPLICATE_DECLARATION, 'Repeated setter retained in source order; no last-wins rule.', ts, 'create')
        self.declarations[field] += 1
        if field == 'exits':
            self.exits(args[1], hazards)
        elif field in FLAGS | TEXT_FIELDS:
            value = literal(args[1][0]) if len(args[1]) == 1 else None
            if value and (field in FLAGS or value['kind'] == 'text'):
                self.fact(field, value, ts)
            else:
                self.finding(FindingCode.DYNAMIC_EXPRESSION, 'Value is outside approved static scalar/text literals.', ts, 'create')
        else:
            self.finding(FindingCode.UNSUPPORTED_CONSTRUCT, 'Setter field is outside static-room-v1.', ts, 'create')

    def exits(self, ts: list[Token], hazards: set[str]) -> None:
        matching = pairs(ts)
        if (len(ts) < 4 or [t.text for t in ts[:2]] != ['(', '[']
                or matching.get(0) != len(ts) - 1 or matching.get(1) != len(ts) - 2):
            self.finding(FindingCode.DYNAMIC_EXPRESSION, 'Exit mapping is computed, not a literal mapping.', ts, 'create')
            return
        seen: set[str] = set()
        entries = split_at(ts[2:-2], ',')
        for index, entry in enumerate(entries):
            if not entry:
                if index == len(entries) - 1:
                    continue
                raise SourceError('empty exit mapping entry', ts[0].start, ts[-1].end)
            if any(t.text == '?' for t in entry):
                self.finding(FindingCode.DYNAMIC_EXPRESSION, 'Conditional exit entry is not evaluated.', entry, 'create')
                continue
            pair = split_at(entry, ':')
            if len(pair) != 2 or not pair[0] or not pair[1]:
                # Quarantine only positively malformed literal entries. Balanced
                # unfamiliar colon-bearing expressions are not syntax validation.
                missing_separator = len(pair) == 1 and all(literal(t) is not None for t in entry)
                missing_side = len(pair) == 2 and (not pair[0] or not pair[1])
                if missing_separator or missing_side:
                    raise SourceError('exit mapping requires key: value', entry[0].start, entry[-1].end)
                self.finding(FindingCode.DYNAMIC_EXPRESSION, 'Exit entry separator/expression is outside the static subset.', entry, 'create')
                continue
            key, target = pair
            direction = literal(key[0]) if len(key) == 1 else None
            value = literal(target[0]) if len(target) == 1 else None
            normalization = None
            if target[0].text == '__DIR__' and '__DIR__' not in hazards:
                tail = target[1:]
                if tail and tail[0].text == '+':
                    tail = tail[1:]
                suffix = literal(tail[0]) if len(tail) == 1 else None
                if suffix and suffix['kind'] == 'text' and not suffix['value'].startswith('/'):
                    value = {'kind': 'text', 'value': '/' + posixpath.dirname(self.source.path) + '/' + suffix['value']}
                    normalization = {'rule': 'SOURCE_DIR_LITERAL_CONCAT', 'version': 1,
                                     'inputs': [self.provenance(target, 'create', 'exit-target')]}
            if not direction or direction['kind'] != 'text' or not value or value['kind'] != 'text':
                self.finding(FindingCode.DYNAMIC_EXPRESSION, 'Exit key/target is dynamic or outside approved literal normalization.', entry, 'create')
                continue
            if direction['value'] in seen:
                self.finding(FindingCode.DUPLICATE_DECLARATION, 'Duplicate exit direction retained; not collapsed.', entry, 'create')
            seen.add(direction['value'])
            resolved = reference(value['value'], self.paths)
            exit_value = {'kind': 'exit', 'direction': direction['value'], 'target': value['value'],
                          'direction_raw': self.source.data[key[0].start:key[-1].end].decode('utf-8'),
                          'target_raw': self.source.data[target[0].start:target[-1].end].decode('utf-8'),
                          'reference': resolved}
            self.fact('exit', exit_value, entry, normalized=normalization)
            if resolved['status'] != 'EXISTS':
                self.finding(FindingCode.UNRESOLVED_REFERENCE, 'Authored target is missing, case-ambiguous or not a safe absolute source path.', entry, 'create')

    def dynamic_findings(self) -> None:
        ts = self.tokens
        for i, token in enumerate(ts):
            scope = self.scopes.get(i, 'top-level')
            if token.kind == 'unknown':
                self.finding(FindingCode.UNSUPPORTED_CONSTRUCT, 'Opaque lexical construct retained.', [token], scope)
            closure = token.text == '(' and i + 1 < len(ts) and ts[i + 1].text == ':'
            if closure or (token.text in {'random', 'call_out', 'add_action', 'replace_program', '->'} and token.kind not in {'string', 'heredoc', 'directive'}):
                code = (FindingCode.RNG_SEMANTICS if token.text == 'random' else
                        FindingCode.DRIVER_SEMANTICS_UNKNOWN if token.text == 'replace_program' else
                        FindingCode.CALLBACK_BEHAVIOR if closure or token.text in {'call_out', 'add_action'} else
                        FindingCode.REQUIRES_SEMANTIC_REVIEW)
                self.finding(code, 'Dynamic/runtime construct is a review dependency only.', [token], scope)
            if token.text in {'set', 'add', 'delete'} and token.kind == 'identifier' and i + 2 < len(ts) and ts[i + 1].text == '(':
                key = literal(ts[i + 2])
                outside = scope != 'create' or (i > 0 and ts[i - 1].text in {'->', '::'})
                if key and key['kind'] == 'text' and (key['value'].startswith('exits/') or (key['value'] == 'exits' and outside)):
                    self.finding(FindingCode.ORDER_SENSITIVE_MUTATION, 'Exit mutation outside a static create declaration; graph is not authoritative.', ts[i:i + 3], scope)


def scan(root: Path) -> tuple[dict, int]:
    mudlib, inputs = discover(root)
    # Resolve only within the actual mudlib namespace. Files outside it are manifest-only.
    root = root.resolve()
    prefix = 'mudlib/' if mudlib != root else ''
    dependencies = {source.path: source for relative, source in inputs if relative.startswith(prefix)}
    paths = set(dependencies)
    manifest, objects, findings = [], [], []
    for relative, source in inputs:
        kind = 'LPC_SOURCE' if relative.endswith('.c') else 'HEADER' if relative.endswith('.h') else 'OTHER'
        in_mudlib = relative.startswith(prefix)
        if kind in {'LPC_SOURCE', 'HEADER'} and in_mudlib:
            extractor = RoomExtractor(source, paths, dependencies)
            record, diagnostics = extractor.extract()
            if kind != 'LPC_SOURCE' and record['status'] != 'QUARANTINED':
                record['status'] = 'OUT_OF_SCOPE'
                record['supported_candidate'] = False
                record['facts'] = []
            objects.append(record)
            findings.extend(diagnostics)
            status = record['status']
        else:
            status = 'OUT_OF_SCOPE'
            objects.append(dict(object_id='es2-file:' + relative, source_path=source.path,
                                source_sha256=source.sha256, review_state='UNREVIEWED', status=status,
                                supported_candidate=False, category_candidates=[], direct_inherits=[], facts=[], finding_ids=[]))
        objects[-1]['input_path'] = relative
        objects[-1]['source_namespace'] = 'mudlib' if in_mudlib else 'source-root'
        manifest.append(dict(input_path=relative, source_path=source.path, kind=kind,
                             source_namespace=objects[-1]['source_namespace'],
                             size_bytes=len(source.data), sha256=source.sha256, status=status,
                             review_state='UNREVIEWED'))
    digest = hashlib.sha256()
    for item in manifest:
        digest.update(item['input_path'].encode('utf-8') + b'\0' + item['sha256'].encode('ascii') + b'\n')
    counts = Counter(obj['status'] for obj in objects)
    summary = dict(scanned_files=len(inputs), supported_candidates=sum(obj['supported_candidate'] for obj in objects),
                   statuses={key: counts[key] for key in ('EXTRACTED', 'PARTIAL', 'OUT_OF_SCOPE', 'QUARANTINED')},
                   total_findings=len(findings), finding_codes=dict(sorted(Counter(f['code'] for f in findings).items())))
    document = dict(schema_version=1, extractor_version=EXTRACTOR_VERSION, profile=PROFILE,
                    review_state='UNREVIEWED', source_manifest={'sha256': digest.hexdigest(), 'files': manifest},
                    objects=objects, findings=findings, summary=summary)
    return document, 1 if counts['QUARANTINED'] else 0
