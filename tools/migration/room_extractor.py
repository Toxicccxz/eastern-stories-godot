"""Static ROOM declarations and audit findings, never final runtime state."""

from __future__ import annotations

import hashlib
import json
import posixpath
from collections import Counter
from enum import StrEnum
from pathlib import Path

from .es2_source import Source, SourceError, Token, ToolError, directive_keyword, discover, lex, literal, pairs


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
# Authored declaration starters bound a pending inherit; later bodies are not
# evidence for its missing terminator. This is not an LPC grammar.
DECLARATION_STARTERS = {'inherit', 'void', 'int', 'string', 'object', 'mapping', 'mixed',
                       'float', 'status', 'static', 'private', 'protected', 'public',
                       'nomask', 'varargs', 'nosave'}
EXTRACTOR_VERSION = '1.0.19'
KNOWN_EXTRACTOR_VERSIONS = {'1.0.0', '1.0.1', '1.0.2', '1.0.3', '1.0.4', '1.0.5', '1.0.6', '1.0.7', '1.0.8', '1.0.9', '1.0.10', '1.0.11', '1.0.12', '1.0.13', '1.0.14', '1.0.15', '1.0.16', '1.0.17', '1.0.18', '1.0.19'}
PROFILE = 'static-room-v1'
# Exact object constants from reference/es2/mudlib/include/{globals,weapon,armor}.h.
# Admission evidence only: no path guessing, subclass lookup or macro evaluation.
EXCLUDED_LITERAL_BASES = {
    '/std/room/bank': 'BANK', '/std/room/class_guild': 'CLASS_GUILD',
    '/std/force': 'FORCE', '/std/room/hockshop': 'HOCKSHOP', '/std/item': 'ITEM',
    '/std/liquid': 'LIQUID', '/std/char/npc': 'NPC', '/std/skill': 'SKILL',
    '/std/money': 'MONEY', '/std/item/combined': 'COMBINED_ITEM',
    '/std/bboard': 'BULLETIN_BOARD', '/std/char': 'CHARACTER',
    '/std/equip': 'EQUIP', '/std/medicine/powder': 'POWDER',
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


def directive_tokens(token: Token) -> list[Token]:
    if directive_keyword(token.text)[0] == 'echo':
        return []  # Raw payload is not a replacement-token analysis view.
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
        return lex(Source('directive', bytes(view)))
    except SourceError as error:
        raise SourceError(str(error), token.start + offsets[error.start],
                          token.start + offsets[error.end], encoding=error.encoding) from error


def directive_parts(token: Token) -> list[str]:
    if directive_keyword(token.text)[0] == 'echo':
        return ['echo']
    return [t.text for t in directive_tokens(token)]


class MacroEffect(StrEnum):
    INERT = 'INERT'
    CREATE_STATE_HAZARD = 'CREATE_STATE_HAZARD'
    STRUCTURAL_BOUNDARY_HAZARD = 'STRUCTURAL_BOUNDARY_HAZARD'
    UNKNOWN = 'UNKNOWN'


class CreateTailEffect(StrEnum):
    EMPTY = 'EMPTY'
    NONEMPTY_NEUTRAL = 'NONEMPTY_NEUTRAL'
    UNCERTAIN = 'UNCERTAIN'


# Source-backed persistent mapping mutations: feature/dbase.c and treemap.c.
# Temporary dbase APIs are separate; no speculative gameplay mutator registry.
MACRO_STATE_NAMES = {'set', 'add', 'delete', '_set', '_delete', 'map_delete', 'set_default_object', 'create'}


class MacroSummary:
    """Possible replacement dependencies, not a preprocessor or expanded source.

    Union every definition in the resolved compilation unit, regardless of order,
    guards or undef. Identity reachability and bounded effect classification are
    separate: inert constants need no identity, while cycles remain uncertain.
    Token offsets here belong solely to the existing directive analysis view.
    """
    def __init__(self):
        self.definitions: dict[str, list[tuple[bool, list[Token]]]] = {}
        self.parameters: dict[str, set[str]] = {}
        self.invalid: set[str] = set()
        self._effects: dict[str, MacroEffect] = {}

    def add(self, token: Token) -> None:
        ts = directive_tokens(token)
        if len(ts) < 2 or ts[0].text != 'define' or ts[1].kind != 'identifier':
            return
        function_like = (len(ts) > 2 and ts[2].text == '(' and ts[1].end == ts[2].start)
        name = ts[1].text
        replacement = ts[2:]
        if function_like:
            # Parameters are not replacement dependencies. Malformed signatures
            # remain an uncertain definition, never a root syntax quarantine.
            end = next((i for i in range(3, len(ts)) if ts[i].text == ')'), None)
            replacement = ts[end + 1:] if end is not None else []
            if end is None:
                self.invalid.add(name)
            else:
                parameters = {t.text for t in ts[3:end] if t.kind == 'identifier'}
                if any(t.text == '.' for t in ts[3:end]):
                    parameters.add('__VA_ARGS__')
                self.parameters.setdefault(name, set()).update(parameters)
        self.definitions.setdefault(name, []).append((function_like, replacement))
        self._effects.clear()

    def reach(self, name: str) -> tuple[set[str], bool]:
        """Iterative graph walk; each reachable name visited once, including cycles."""
        reached, uncertain, pending = set(), False, [name]
        edges: dict[str, set[str]] = {}
        while pending:
            current = pending.pop()
            if current in reached:
                continue
            reached.add(current)
            edges[current] = set()
            for function_like, replacement in self.definitions.get(current, []):
                uncertain |= function_like or len(replacement) != 1 or replacement[0].kind != 'identifier'
                for token in replacement:
                    if token.kind == 'identifier':
                        edges[current].add(token.text)
                        pending.append(token.text)
                    elif token.kind == 'string':
                        value = literal(token)
                        if value and value['value'] in EXCLUDED_LITERAL_BASES:
                            reached.add(value['value'])
        # Remove leaves to detect any reachable cycle without recursion/depth risk.
        remaining = set(edges)
        while remaining:
            leaves = {node for node in remaining if not edges[node] & remaining}
            if not leaves:
                uncertain = True
                break
            remaining -= leaves
        return reached, uncertain

    def pairing_uncertain(self, name: str, invoked: bool) -> bool:
        """Can this actual use invalidate an authored delimiter error?

        This is narrower than effect(): balanced replacements (even ';' or '#')
        cannot repair pairing by themselves. Invocation-shaped function macros
        can discard/transform arguments. Follow possible definitions iteratively,
        preserving invocation context through aliases, without expanding tokens.
        """
        edges: dict[tuple[str, bool], set[tuple[str, bool]]] = {}
        pending = [(name, invoked)]
        while pending:
            current, called = node = pending.pop()
            if node in edges:
                continue
            edges[node] = set()
            for function_like, replacement in self.definitions.get(current, []):
                if function_like:
                    if called:
                        return True  # Includes invalid signatures/parameter removal.
                    continue  # A bare function-macro name is not an invocation.
                try:
                    pairs(replacement)
                except SourceError:
                    return True
                # Token pasting can name another macro not visible as an authored
                # identifier edge. A lone '#' / ';' has no such pairing effect.
                if (any(t.kind == 'identifier' for t in replacement)
                        and any(a.text == b.text == '#' for a, b in zip(replacement, replacement[1:]))):
                    return True
                for index, token in enumerate(replacement):
                    if token.kind != 'identifier':
                        continue
                    follows_call = (index + 1 < len(replacement)
                                    and replacement[index + 1].text == '(')
                    # A trailing alias may receive the root use's following '('.
                    dependency = (token.text, follows_call or (called and index == len(replacement) - 1))
                    edges[node].add(dependency)
                    pending.append(dependency)
        # The same bounded cycle policy as reach(); no recursive expansion.
        remaining = set(edges)
        while remaining:
            leaves = {node for node in remaining if not edges[node] & remaining}
            if not leaves:
                return True
            remaining -= leaves
        return False

    def inherit_boundary_uncertain(self, name: str, invoked: bool) -> bool:
        """Summarize an actual declaration use; never expand a replacement.

        Only empty/single-atom replacements and their alias dependencies prove
        neutrality here. Uninvoked function macros contribute no replacement.
        """
        edges: dict[tuple[str, bool], set[tuple[str, bool]]] = {}
        pending = [(name, invoked)]
        while pending:
            current, called = node = pending.pop()
            if node in edges:
                continue
            edges[node] = set()
            definitions = [(f, r) for f, r in self.definitions.get(current, []) if not f or called]
            shapes = {(f, tuple((t.kind, t.text) for t in r)) for f, r in definitions}
            if definitions and (len(shapes) > 1 or current in self.invalid):
                return True
            for function_like, replacement in definitions:
                if not replacement:
                    continue
                if len(replacement) != 1 or replacement[0].kind not in {'identifier', 'number', 'string', 'character'}:
                    return True
                token = replacement[0]
                if token.kind == 'identifier':
                    if function_like and token.text in self.parameters.get(current, set()):
                        return True
                    dependency = (token.text, called)
                    edges[node].add(dependency)
                    pending.append(dependency)
        remaining = set(edges)
        while remaining:
            leaves = {node for node in remaining if not edges[node] & remaining}
            if not leaves:
                return True
            remaining -= leaves
        return False

    def create_tail_effect(self, name: str, invoked: bool) -> tuple[CreateTailEffect, bool]:
        """Classify a single actual use and whether it consumes its authored call.

        Follow only single-identifier aliases, iteratively. No replacement tokens
        are produced. Empty object macros leave following parentheses in place;
        a function macro consumes them, even when reached through object aliases.
        """
        visited: set[tuple[str, bool]] = set()
        consumes_call = False
        while True:
            node = (name, invoked)
            if node in visited:
                return CreateTailEffect.UNCERTAIN, consumes_call
            visited.add(node)
            definitions = [(f, r) for f, r in self.definitions.get(name, []) if not f or invoked]
            if not definitions:
                return CreateTailEffect.NONEMPTY_NEUTRAL, consumes_call
            shapes = {(f, tuple((t.kind, t.text) for t in r)) for f, r in definitions}
            if len(shapes) != 1 or name in self.invalid:
                return CreateTailEffect.UNCERTAIN, consumes_call
            function_like, replacement = definitions[0]
            if function_like:
                consumes_call = True
            if not replacement:
                return CreateTailEffect.EMPTY, consumes_call
            if len(replacement) != 1 or replacement[0].kind not in {'identifier', 'number', 'string', 'character'}:
                return CreateTailEffect.UNCERTAIN, consumes_call
            token = replacement[0]
            if token.kind != 'identifier':
                return CreateTailEffect.NONEMPTY_NEUTRAL, consumes_call
            if function_like and token.text in self.parameters.get(name, set()):
                return CreateTailEffect.UNCERTAIN, consumes_call
            # The invocation belongs to the function just consumed, not to its
            # replacement identifier. Object aliases retain the following call.
            invoked = invoked and not function_like
            name = token.text

    def effect(self, name: str) -> MacroEffect:
        """Classify possible effects, never substitute arguments or source tokens.

        A narrow contained call to a known mutator is state-only. Other complex
        expressions are unknown. Function-like replacement can be classified
        only when it does not reference formal parameters (no substitution).
        Every reachable definition contributes, including after undef/branches.
        """
        if name in self._effects:
            return self._effects[name]
        effects: set[MacroEffect] = set()
        edges: dict[str, set[str]] = {}
        pending = [name]
        while pending:
            current = pending.pop()
            if current in edges:
                continue
            edges[current] = set()
            definitions = self.definitions.get(current, [])
            if not definitions and current == 'inherit':
                effects.add(MacroEffect.STRUCTURAL_BOUNDARY_HAZARD)
            elif not definitions and current in MACRO_STATE_NAMES:
                effects.add(MacroEffect.CREATE_STATE_HAZARD)
            shapes = {(f, tuple((t.kind, t.text) for t in r)) for f, r in definitions}
            if len(shapes) > 1 or current in self.invalid:
                effects.add(MacroEffect.UNKNOWN)
            for function_like, replacement in definitions:
                identifiers = {t.text for t in replacement if t.kind == 'identifier'}
                edges[current].update(identifiers)
                pending.extend(identifiers)
                punctuation = {t.text for t in replacement if t.kind == 'punctuation'}
                if punctuation & {'{', '}', ';', '#'}:
                    effects.add(MacroEffect.STRUCTURAL_BOUNDARY_HAZARD)
                    continue
                try:
                    matching = pairs(replacement)
                except SourceError:
                    # Semantic uncertainty in a macro is not corrupt root bytes.
                    effects.add(MacroEffect.STRUCTURAL_BOUNDARY_HAZARD)
                    continue
                if function_like and identifiers & self.parameters.get(current, set()):
                    effects.add(MacroEffect.UNKNOWN)
                elif not replacement or (len(replacement) == 1 and replacement[0].kind in
                                          {'identifier', 'number', 'string', 'character'}):
                    effects.add(MacroEffect.INERT)
                elif (len(replacement) > 2 and replacement[0].kind == 'identifier'
                      and replacement[1].text == '(' and matching.get(1) == len(replacement) - 1
                      and self.reach(replacement[0].text)[0] & MACRO_STATE_NAMES):
                    effects.add(MacroEffect.CREATE_STATE_HAZARD)
                else:
                    effects.add(MacroEffect.UNKNOWN)
        remaining = set(edges)
        while remaining:
            leaves = {node for node in remaining if not edges[node] & remaining}
            if not leaves:
                effects.add(MacroEffect.UNKNOWN)
                break
            remaining -= leaves
        result = next((effect for effect in (MacroEffect.STRUCTURAL_BOUNDARY_HAZARD,
                      MacroEffect.UNKNOWN, MacroEffect.CREATE_STATE_HAZARD) if effect in effects), MacroEffect.INERT)
        self._effects[name] = result
        return result


def macro_regions(ts: list[Token]):
    """Yield original signature/body/declaration slices, never expanded syntax.

    A possible signature includes everything through the body opening, even
    macro tokens between ')' and '{'. Nested body tokens stay available for
    effect checks; only their authored scope is used as a provisional context.
    """
    matching = pairs(ts)
    i, start = 0, 0
    while i < len(ts):
        token = ts[i]
        if token.kind == 'directive':
            yield 'statement', ts[start:i]
            start = i = i + 1
            continue
        if i == start and token.kind == 'identifier' and token.text == 'inherit':
            end = next((j for j in range(i + 1, len(ts)) if ts[j].text == ';'), len(ts))
            yield 'inherit', ts[i:end]
            start = i = min(end + 1, len(ts))
            continue
        if token.text == '(' and i in matching:
            close = matching[i]
            opening = close + 1
            while opening < len(ts) and ts[opening].kind in {'identifier', 'directive'}:
                opening += 1
            if (i > start and ts[i - 1].kind == 'identifier' and opening < len(ts)
                    and ts[opening].text == '{'):
                yield 'signature', ts[start:opening]
                yield ('create' if ts[i - 1].text == 'create' else 'body'), ts[opening + 1:matching[opening]]
                start = i = matching[opening] + 1
                continue
        if token.kind == 'punctuation' and token.text == '{':
            yield 'signature', ts[start:i]
            yield 'body', ts[i + 1:matching[i]]
            start = i = matching[i] + 1
        elif i in matching:
            i = matching[i] + 1
        elif token.kind == 'punctuation' and token.text == ';':
            yield 'statement', ts[start:i]
            start = i = i + 1
        else:
            i += 1
    yield 'statement', ts[start:]


def macro_structure_hazards(ts: list[Token], macros: MacroSummary) -> set[str]:
    hazards: set[str] = set()
    for context, tokens in macro_regions(ts):
        for token in tokens:
            if token.kind != 'identifier' or token.text not in macros.definitions:
                continue
            effect = macros.effect(token.text)
            if context == 'inherit':
                hazards.add('macro inheritance')
            elif effect in {MacroEffect.STRUCTURAL_BOUNDARY_HAZARD, MacroEffect.UNKNOWN}:
                hazards.add('macro structure')
            elif context == 'signature':
                reached, uncertain = macros.reach(token.text)
                if effect == MacroEffect.CREATE_STATE_HAZARD and uncertain:
                    hazards.add('macro structure')
                else:
                    hazards.update(reached & {'set', 'create'})
            elif context == 'create' and effect == MacroEffect.CREATE_STATE_HAZARD:
                hazards.add('create state')
    return hazards


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


def included_structure_hazards(tokens: list[Token]) -> set[str]:
    """Summarize possible top-level declarations, never splice dependency bytes.

    Inspect all conditional content without choosing branches. If its combined
    structure cannot be balanced/summarized, the caller marks the include
    unresolved (not the root corrupt). Prototypes and ordinary declarations do
    not define functions; function bodies and grouped initializers stay opaque.
    """
    ts = tokens
    matching = pairs(ts)
    hazards: set[str] = set()
    i, start = 0, 0
    while i < len(ts):
        token = ts[i]
        if token.kind == 'directive':
            if start < i:
                raise SourceError('directive interrupts included declaration', token.start, token.end)
            i += 1
            start = i
            continue
        if i == start and token.kind == 'identifier' and token.text == 'inherit':
            hazards.add('included inherit')
        if token.text == '(' and i in matching:
            close = matching[i]
            if (i > start and ts[i - 1].kind == 'identifier'
                    and close + 1 < len(ts) and ts[close + 1].text == '{'):
                if any(t.kind == 'directive' for t in ts[start:close + 1]):
                    raise SourceError('directive interrupts included signature', ts[start].start, ts[close].end)
                name = ts[i - 1].text
                if name in {'set', 'create'}:
                    hazards.add(name)
                i = matching[close + 1] + 1
                start = i
                continue
        if token.kind == 'punctuation' and token.text == '{':
            raise SourceError('unresolved included top-level structure', token.start, token.end)
        if i in matching:
            i = matching[i] + 1
        elif token.kind == 'punctuation' and token.text == ';':
            i += 1
            start = i
        else:
            i += 1
    if start < len(ts):
        raise SourceError('unterminated included declaration', ts[start].start, ts[-1].end)
    return hazards


class RoomExtractor:
    def __init__(self, source: Source, paths: set[str], dependencies: dict[str, Source]):
        self.source, self.paths, self.dependencies = source, paths, dependencies
        self.tokens: list[Token] = []
        self.findings: list[dict] = []
        self.facts: list[dict] = []
        self.exit_candidates: list[tuple[dict, list[Token], dict | None]] = []
        self.exit_sequence_uncertain = False
        self.flat_exit_setter_starts: set[int] = set()
        self.exit_uncertainty_call_starts: set[int] = set()
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

    def macro_context(self, ts: list[Token], *, origins: dict[str, Token] | None = None) -> tuple[MacroSummary, list[tuple[str, list[Token]]], set[str], set[str]]:
        """Collect existing root/include context without requiring paired tokens.

        Source tokens are never merged. Each include is visited once per root;
        unresolved dependencies retain the existing admission veto.
        """
        hazards: set[str] = set()
        macros = MacroSummary()
        units = [(self.source.path, ts)]
        visited = {self.source.path}
        included: set[str] = set()
        index = 0
        while index < len(units):
            source_path, tokens = units[index]
            index += 1
            for token in tokens:
                if token.kind != 'directive':
                    continue
                try:
                    words = directive_parts(token)
                    macros.add(token)
                except SourceError:
                    if source_path == self.source.path:
                        raise
                    hazards.add('unresolved include')
                    continue
                if not words:
                    continue
                if words[0] in ('define', 'undef') and len(words) > 1:
                    if words[1] in {'ROOM', '__DIR__', 'set', 'create'}:
                        hazards.add(words[1])
                if words[0] != 'include':
                    continue
                authored = ''.join(words[1:])
                if authored.startswith('<') and authored.endswith('>'):
                    path = 'include/' + authored[1:-1]
                elif authored.startswith('"') and authored.endswith('"'):
                    path = posixpath.join(posixpath.dirname(source_path), authored[1:-1])
                else:
                    hazards.add('unresolved include')
                    continue
                if '..' in path.split('/') or path.startswith('/') or path not in self.dependencies:
                    hazards.add('unresolved include')
                    continue
                included.add(path)
                if path not in visited:
                    visited.add(path)
                    if origins is not None:
                        origins[path] = token if source_path == self.source.path else origins[source_path]
                    try:
                        units.append((path, lex(self.dependencies[path])))
                    except SourceError:
                        hazards.add('unresolved include')
        return macros, units, included, hazards

    def include_hazards(self, ts: list[Token]) -> set[str]:
        macros, units, included, hazards = self.macro_context(ts)
        for source_path, tokens in units:
            try:
                hazards.update(macro_structure_hazards(tokens, macros))
            except SourceError:
                if source_path == self.source.path:
                    raise
                hazards.add('unresolved include')
            if source_path in included:
                try:
                    hazards.update(included_structure_hazards(tokens))
                except SourceError:
                    hazards.add('unresolved include')
        return hazards

    def pairing_uncertain_use(self) -> Token | None:
        """Called only after root pairs() fails; definitions alone are not proof."""
        macros, _, _, _ = self.macro_context(self.tokens)
        for index, token in enumerate(self.tokens):
            if token.kind != 'identifier' or token.text not in macros.definitions:
                continue
            invoked = index + 1 < len(self.tokens) and self.tokens[index + 1].text == '('
            if macros.pairing_uncertain(token.text, invoked):
                return token  # Authored use, never replacement/header provenance.
        return None

    def include_pairing_uncertain_use(self) -> Token | None:
        """Resolved raw fragments only; retain the reaching root include token."""
        origins: dict[str, Token] = {}
        _, units, _, _ = self.macro_context(self.tokens, origins=origins)
        for path, tokens in units[1:]:
            try:
                # Directives contain their own lexical analysis view. A lexical
                # failure is not evidence of a valid raw pairing fragment.
                for token in tokens:
                    if token.kind == 'directive':
                        directive_tokens(token)
            except SourceError:
                continue
            try:
                pairs(tokens)
            except SourceError:
                return origins[path]
        return None

    def extract(self, *, header: bool = False) -> tuple[dict, list[dict]]:
        header_lexed = False
        try:
            self.tokens = lex(self.source)
            if header:
                for token in self.tokens:
                    if token.kind == 'directive':
                        directive_tokens(token)
                header_lexed = True
            conditional = any(t.kind == 'directive' and directive_parts(t)[:1] in
                              [['if'], ['ifdef'], ['ifndef'], ['else'], ['elif'], ['endif']] for t in self.tokens)
            if conditional:
                self.finding(FindingCode.OUT_OF_SCOPE, 'Conditional compilation prevents reliable profile admission.', self.tokens[:1], severity='INFO')
                self.finding(FindingCode.DRIVER_SEMANTICS_UNKNOWN, 'Preprocessor branches retained without evaluating or balancing mutually exclusive code.', self.tokens)
            else:
                try:
                    matching = pairs(self.tokens)
                except SourceError:
                    use = self.pairing_uncertain_use()
                    reason = 'Preprocessor macro usage may alter delimiter structure; authored delimiter imbalance is not sufficient evidence of source corruption.'
                    if use is None and not header:
                        use = self.include_pairing_uncertain_use()
                        reason = 'Resolved textual include fragments may alter delimiter structure; authored delimiter imbalance is not sufficient evidence of source corruption.'
                    if use is None:
                        raise  # Preserve the original pairing error and byte span.
                    self.finding(FindingCode.OUT_OF_SCOPE,
                                 'Preprocessor structure prevents reliable static-room admission.',
                                 [use], severity='INFO')
                    self.finding(FindingCode.DRIVER_SEMANTICS_UNKNOWN,
                                 reason,
                                 [use])
                else:
                    self.extract_structure(matching)
        except SourceError as error:
            self.facts.clear()
            if header_lexed:
                # Headers are textual fragments, not standalone translation units.
                # Lexical failures were excluded before any structural analysis.
                self.inherits.clear()
                self.findings.clear()
                self.record['category_candidates'] = []
                self.finding(FindingCode.OUT_OF_SCOPE, 'Header fragment is outside the standalone ROOM profile.',
                             self.tokens[:1], severity='INFO')
                self.finding(FindingCode.DRIVER_SEMANTICS_UNKNOWN,
                             'Header structural completeness depends on its include site; standalone parsing is not corruption evidence.',
                             self.tokens)
            else:
                self.record['status'] = 'QUARANTINED'
                self.findings.append(dict(code=(FindingCode.SOURCE_ENCODING_ISSUE if error.encoding else
                                               FindingCode.SOURCE_SYNTAX_ERROR).value,
                                         severity='ERROR', object_id=self.record['object_id'],
                                         reason=str(error), prevents_supported_consumption=True,
                                         provenance=self.source.span(error.start, error.end, 'unknown', 'source-error', 0)))
        if header and self.record['status'] != 'QUARANTINED':
            self.record['status'] = 'OUT_OF_SCOPE'
            self.record['supported_candidate'] = False
            self.facts.clear()
        self.facts.sort(key=lambda f: (f['provenance']['byte_start'], f['provenance']['byte_end_exclusive'], f['field']))
        self.findings.sort(key=lambda f: (f['provenance']['byte_start'], f['code'], f['reason']))
        for index, finding in enumerate(self.findings):
            finding['review_state'] = 'UNREVIEWED'
            finding['finding_id'] = f"{self.record['object_id']}:{index + 1}"
            self.record['finding_ids'].append(finding['finding_id'])
        return self.record, self.findings

    def inherit_boundary_uncertain(self, pending: list[Token]) -> tuple[Token, bool] | None:
        """Inspect only preprocessing participating in this pending declaration.

        Reuse compilation-context macros, but resolve each participating include
        through the existing traversal separately so unrelated units cannot waive
        an error. Units remain separate authored token lists throughout.
        """
        macros, _, _, _ = self.macro_context(self.tokens)

        def macro_use(tokens: list[Token]) -> Token | None:
            for index, token in enumerate(tokens):
                invoked = index + 1 < len(tokens) and tokens[index + 1].text == '('
                if (token.kind == 'identifier' and token.text in macros.definitions
                        and macros.inherit_boundary_uncertain(token.text, invoked)):
                    return token
            return None

        for token in pending:
            if token.kind != 'directive' or directive_parts(token)[:1] != ['include']:
                continue
            origins: dict[str, Token] = {}
            _, units, _, hazards = self.macro_context([token], origins=origins)
            if 'unresolved include' in hazards:
                return token, True
            for path, tokens in units[1:]:
                # A declaration/function header is not a terminator fragment.
                # Accept only an expression-shaped raw prefix, not a semicolon
                # buried inside a helper, variable declaration or function body.
                prefix = []
                for part in tokens:
                    if part.kind == 'directive':
                        continue
                    if part.text in DECLARATION_STARTERS or part.text in {'{', '}'}:
                        break
                    if part.text == ';':
                        return origins[path], False
                    if part.kind not in {'identifier', 'string', 'number', 'character'} and part.text != '+':
                        if part.text == '(':
                            prefix.append(part)  # Retain invocation evidence only.
                        break
                    prefix.append(part)
                if macro_use(prefix) is not None:
                    return origins[path], False
        use = macro_use(pending)
        return (use, False) if use is not None else None

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
                    part = ts[end]
                    if (part.kind == 'identifier' and part.text in DECLARATION_STARTERS
                            or part.text == '{'):
                        break
                    # Untyped function definitions also end the pending slice.
                    if (part.kind == 'identifier' and end + 1 in matching
                            and ts[end + 1].text == '('
                            and matching[end + 1] + 1 < len(ts)
                            and ts[matching[end + 1] + 1].text == '{'):
                        break
                    end += 1
                if end == len(ts) or ts[end].text != ';':
                    # A candidate boundary is not yet a trusted boundary: its
                    # leading identifier may itself be an actual macro use.
                    # Preserve that authored use and invocation marker for the
                    # existing uncertainty analysis, never the following body.
                    pending_end = end
                    if end < len(ts) and ts[end].kind == 'identifier':
                        pending_end += 1
                        if pending_end < len(ts) and ts[pending_end].text == '(':
                            pending_end += 1
                    uncertain = self.inherit_boundary_uncertain(ts[i + 1:pending_end])
                    if uncertain is not None:
                        use, unresolved = uncertain
                        self.inherits.clear()
                        self.record['category_candidates'].clear()
                        self.finding(FindingCode.OUT_OF_SCOPE,
                                     'Preprocessing at a pending inherit boundary prevents reliable admission.',
                                     [use], severity='INFO')
                        self.finding(FindingCode.DRIVER_SEMANTICS_UNKNOWN,
                                     'Pending inherit terminator or expression tail depends on preprocessing; no declaration is recovered.',
                                     [use])
                        if unresolved:
                            self.finding(FindingCode.UNRESOLVED_INCLUDE,
                                         'Pending inherit include dependency is unavailable or cannot be analyzed.', [use])
                        return  # No facts or reliable inheritance metadata emitted.
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
                    'BULLETIN_BOARD', 'CHARACTER', 'EQUIP', 'POWDER',
                    'SWORD', 'BLADE', 'HAMMER', 'AXE', 'STAFF', 'WHIP', 'SPEAR', 'THROWING',
                    'DAGGER', 'FORK', 'SURCOAT', 'WAIST', 'WRISTS', 'HANDS',
                    'F_FOOD', 'F_LIQUID', 'F_VENDOR', 'F_MASTER', 'LIQUID', 'CLOTH', 'BOOTS',
                    'GLOVES', 'HEAD', 'NECK', 'FINGER', 'SHIELD', 'SKILL', 'FORCE', 'DAEMON'}
        supported = (self.source.path.startswith('d/') and self.source.path.endswith('.c') and direct
                     and not hazards.intersection({'ROOM', 'unresolved include', 'included inherit', 'macro inheritance', 'macro structure'})
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
        shadowed = any(f[0] == 'set' for f in functions) or bool(hazards & {'set', 'create', 'unresolved include', 'create state'})
        for name, first, opening, end in functions:
            if name != 'create':
                self.finding(FindingCode.CALLBACK_BEHAVIOR, 'Function body retained for human semantic review.', ts[first:end + 1], name)
            elif len(create_functions) != 1 or shadowed:
                self.finding(FindingCode.UNSUPPORTED_CONSTRUCT, 'Duplicate create or unresolved/shadowed setter scope.', ts[first:end + 1], name)
            else:
                self.create_body(ts[opening + 1:end], hazards)
        if not create_functions:
            self.finding(FindingCode.UNSUPPORTED_CONSTRUCT, 'No unambiguous create() body.', ts[:1])
        self.commit_exit_facts()
        self.dynamic_findings()
        if any(f['prevents_supported_consumption'] for f in self.findings):
            self.record['status'] = 'PARTIAL'

    def create_tail_uncertain_use(self, runtime: list[Token]) -> Token | None:
        """Inspect only the unfinished tail, retaining all authored provenance."""
        macros, _, _, _ = self.macro_context(self.tokens)
        matching = pairs(runtime)
        first_empty = None
        residual = False
        i = 0
        while i < len(runtime):
            token = runtime[i]
            invoked = i + 1 in matching and runtime[i + 1].text == '('
            if token.kind == 'identifier' and token.text in macros.definitions:
                effect, consumes_call = macros.create_tail_effect(token.text, invoked)
                if effect == CreateTailEffect.UNCERTAIN:
                    return token
                if effect == CreateTailEffect.EMPTY:
                    first_empty = first_empty or token
                else:
                    residual = True
                i = matching[i + 1] + 1 if consumes_call else i + 1
            else:
                residual = True
                i += 1
        return first_empty if not residual else None

    def create_body(self, ts: list[Token], hazards: set[str]) -> None:
        # Plan original source slices before emitting facts. Directives are not
        # runtime statements, and interrupted fragments must never be stitched.
        matching = pairs(ts)
        segments: list[tuple[bool, list[Token]]] = []
        issues: dict[int, str] = {}
        non_runtime_directives = {'define', 'undef', 'pragma', 'echo'}
        for index, token in enumerate(ts):
            if token.kind != 'directive':
                continue
            keyword = directive_keyword(token.text)[0]
            if keyword == 'include':
                issues[index] = 'Include inside create may inject runtime statements; create-derived facts are not reliable.'
            elif keyword not in non_runtime_directives:
                issues[index] = 'Unknown directive inside create; create-derived facts are not reliable.'

        def interrupted(first: int, end: int) -> None:
            for index in range(first, end):
                if ts[index].kind == 'directive':
                    issues.setdefault(index, 'Preprocessor directive interrupts create statement; create-derived facts are not reliable.')

        start, i = 0, 0
        while i < len(ts):
            if ts[i].kind == 'directive':
                if start == i:
                    start = i + 1  # An independent preprocessing boundary.
                else:
                    interrupted(i, i + 1)
                i += 1
            elif ts[i].text == '{':
                end = matching[i]
                # Harmless directives within this already-unsupported block do
                # not change its extraction policy. Include/unknown issues were
                # collected at every depth above; global hazards still apply.
                segments.append((True, ts[start:end + 1]))
                start, i = end + 1, end + 1
            elif i in matching:
                interrupted(i + 1, matching[i])
                i = matching[i] + 1
            elif ts[i].text == ';':
                segments.append((False, ts[start:i + 1]))
                start, i = i + 1, i + 1
            else:
                i += 1
        if start < len(ts):
            tail = ts[start:]
            if any(t.kind == 'directive' and directive_keyword(t.text)[0] not in non_runtime_directives for t in tail):
                # Textual inclusion/unknown semantics might complete this tail;
                # do not invent syntax corruption without preprocessing it.
                interrupted(start, len(ts))
            else:
                # Known non-runtime directives cannot supply the missing ';'.
                # Diagnose the actual unfinished runtime range, not a directive.
                runtime = [t for t in tail if t.kind != 'directive']
                if runtime:
                    use = self.create_tail_uncertain_use(runtime)
                    if use is not None:
                        self.finding(FindingCode.UNSUPPORTED_CONSTRUCT,
                                     'Actual preprocessing use may erase or complete the create tail; create-derived facts are not extracted.',
                                     [use], 'create')
                        return  # Suppress even earlier create segments; no expansion.
                    raise SourceError('unterminated create statement', runtime[0].start, runtime[-1].end)
        if issues:
            for index, reason in sorted(issues.items()):
                self.finding(FindingCode.UNSUPPORTED_CONSTRUCT, reason, [ts[index]], 'create')
            return
        # Only a reliable plan reaches the existing bounded statement extractor.
        for nested, tokens in segments:
            if nested:
                self.unsupported_exit_mutations(tokens)
                self.finding(FindingCode.UNSUPPORTED_CONSTRUCT, 'Conditional/nested create scope is not extracted.', tokens, 'create')
            else:
                self.statement(tokens, hazards)

    def statement(self, ts: list[Token], hazards: set[str]) -> None:
        if len(ts) == 1:
            return
        matching = pairs(ts)
        if len(ts) < 4 or ts[0].kind != 'identifier' or ts[1].text != '(' or matching.get(1) != len(ts) - 2:
            self.unsupported_exit_mutations(ts)
            self.finding(FindingCode.UNSUPPORTED_CONSTRUCT, 'Statement receiver/control/expression outside static subset.', ts, 'create')
            return
        if ts[0].text != 'set':
            self.unsupported_exit_mutations(ts[2:-2])
            self.finding(FindingCode.REQUIRES_SEMANTIC_REVIEW, 'Call is a reference only; lifecycle/door/population is not executed.', ts, 'create')
            return
        args = split_at(ts[2:-2], ',')
        key = literal(args[0][0]) if args and len(args[0]) == 1 else None
        if len(args) != 2 or not key or key['kind'] != 'text':
            self.unsupported_exit_mutations(ts)
            self.finding(FindingCode.DYNAMIC_EXPRESSION, 'Setter key/argument shape is not a supported literal declaration.', ts, 'create')
            return
        field = key['value']
        if self.declarations[field]:
            self.finding(FindingCode.DUPLICATE_DECLARATION, 'Repeated setter retained in source order; no last-wins rule.', ts, 'create')
        self.declarations[field] += 1
        if field == 'exits':
            self.flat_exit_setter_starts.add(ts[0].start)
            self.exits(args[1], hazards)
        elif field in FLAGS | TEXT_FIELDS:
            value = literal(args[1][0]) if len(args[1]) == 1 else None
            if value and (field in FLAGS or value['kind'] == 'text'):
                self.fact(field, value, ts)
            else:
                self.finding(FindingCode.DYNAMIC_EXPRESSION, 'Value is outside approved static scalar/text literals.', ts, 'create')
        else:
            self.finding(FindingCode.UNSUPPORTED_CONSTRUCT, 'Setter field is outside static-room-v1.', ts, 'create')

    @staticmethod
    def classify_exit_call(ts: list[Token], index: int) -> str | None:
        """Classify bounded authored calls only; never evaluate receiver or value."""
        token = ts[index]
        if (index + 3 >= len(ts) or token.kind != 'identifier'
                or token.text not in {'set', 'add', 'delete'} or ts[index + 1].text != '('):
            return None
        key = literal(ts[index + 2])
        if (not key or key['kind'] != 'text' or ts[index + 3].text not in {',', ')'}
                or not (key['value'] == 'exits' or key['value'].startswith('exits/'))):
            return None
        receiver = ts[index - 1].text if index else ''
        if receiver == '->':
            return 'cross-object'
        if receiver == '::':
            return 'inherited'
        return 'local-whole-set' if token.text == 'set' and key['value'] == 'exits' else 'local-mutation'

    def refuse_exit_call(self, ts: list[Token], index: int, kind: str, *, finalizer: bool = False) -> None:
        self.exit_sequence_uncertain = True
        start = ts[index].start
        if start in self.exit_uncertainty_call_starts:
            return
        self.exit_uncertainty_call_starts.add(start)
        if kind == 'inherited':
            self.finding(FindingCode.UNSUPPORTED_CONSTRUCT,
                         'Inherited-qualified exit call in an unsupported create region makes this exit sequence uncertain.',
                         ts[index - 1:index + 3], 'create')
        else:
            reason = ('Unsupported create exit mutation prevents reliable exit facts from this sequence.'
                      if finalizer else
                      'Local exit mutation in an unsupported create region prevents reliable exit facts from this sequence.')
            self.finding(FindingCode.ORDER_SENSITIVE_MUTATION, reason, ts[index:index + 3], 'create')

    def unsupported_exit_mutations(self, ts: list[Token]) -> None:
        """Veto authored exit calls in a skipped region, preserving receiver identity."""
        for index in range(len(ts)):
            kind = self.classify_exit_call(ts, index)
            if kind is not None and kind != 'cross-object':
                self.refuse_exit_call(ts, index, kind)

    def mapping_preprocessing_use(self, ts: list[Token]) -> Token | None:
        """Actual authored use only; no replacement tokens or macro evaluation."""
        macros, _, _, _ = self.macro_context(self.tokens)
        for index, token in enumerate(ts):
            if token.kind == 'directive':
                return token
            if token.kind != 'identifier':
                continue
            invoked = index + 1 < len(ts) and ts[index + 1].text == '('
            if any(not function_like or invoked
                   for function_like, _ in macros.definitions.get(token.text, [])):
                return token
        return None

    def commit_exit_facts(self) -> None:
        # Exit declarations are staged until the entire create sequence is known.
        # Never choose a last write or remove already-created fact identities.
        for index, token in enumerate(self.tokens):
            if self.scopes.get(index) != 'create':
                continue
            kind = self.classify_exit_call(self.tokens, index)
            if kind is None or kind == 'cross-object':
                continue
            # Only this exact authored call was consumed by the flat declaration
            # path. Its mapping still has to pass the existing reliability gates.
            if kind == 'local-whole-set' and token.start in self.flat_exit_setter_starts:
                continue
            self.refuse_exit_call(self.tokens, index, kind, finalizer=True)
        if not self.exit_sequence_uncertain:
            for value, entry, normalization in self.exit_candidates:
                self.fact('exit', value, entry, normalized=normalization)
        self.exit_candidates.clear()

    def exits(self, ts: list[Token], hazards: set[str]) -> None:
        use = self.mapping_preprocessing_use(ts)
        if use is not None:
            self.exit_sequence_uncertain = True
            self.finding(FindingCode.DYNAMIC_EXPRESSION,
                         'Actual preprocessing use makes this exit mapping uncertain; no exit facts from the create exit sequence are emitted.',
                         [use], 'create')
        matching = pairs(ts)
        if (len(ts) < 4 or [t.text for t in ts[:2]] != ['(', '[']
                or matching.get(0) != len(ts) - 1 or matching.get(1) != len(ts) - 2):
            self.finding(FindingCode.DYNAMIC_EXPRESSION, 'Exit mapping is computed, not a literal mapping.', ts, 'create')
            self.exit_sequence_uncertain = True
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
            self.exit_candidates.append((exit_value, entry, normalization))
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
            record, diagnostics = extractor.extract(header=kind == 'HEADER')
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
