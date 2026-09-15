"""Extract static ROOM source facts and findings; never execute or approve LPC."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
import tempfile
from collections import Counter
from pathlib import Path

from .es2_source import ToolError, safe_path
from .room_extractor import EXTRACTOR_VERSION, PROFILE, canonical, scan


REPOSITORY = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT_ROOT = REPOSITORY / 'build/migration-tooling-v1'


def recognized_output(payload: bytes) -> bool:
    """Recognize complete canonical, unreviewed v1 output, including version 1.0.0.

    Metadata alone is insufficient. This is format recognition, not authentication;
    noncanonical, reviewed or inconsistent documents are not replaced.
    """
    try:
        previous = json.loads(payload)
        if (set(previous) != {'schema_version', 'extractor_version', 'profile', 'review_state',
                             'source_manifest', 'objects', 'findings', 'summary'}
                or previous['extractor_version'] not in {'1.0.0', EXTRACTOR_VERSION}
                or previous['review_state'] != 'UNREVIEWED' or canonical(previous) != payload):
            return False
        objects, findings = previous['objects'], previous['findings']
        manifest = previous['source_manifest']['files']
        digest = hashlib.sha256()
        for obj, item in zip(objects, manifest):
            if (item['review_state'] != 'UNREVIEWED' or item['status'] != obj['status']
                    or item['sha256'] != obj['source_sha256']
                    or item['source_path'] != obj['source_path']
                    or item['source_namespace'] != obj['source_namespace']
                    or item['kind'] not in {'LPC_SOURCE', 'HEADER', 'OTHER'}
                    or type(item['size_bytes']) is not int or item['size_bytes'] < 0
                    or len(item['sha256']) != 64
                    or any(c not in '0123456789abcdef' for c in item['sha256'])
                    or type(obj['supported_candidate']) is not bool
                    or not isinstance(obj['direct_inherits'], list)
                    or not isinstance(obj['category_candidates'], list)):
                return False
            digest.update(item['input_path'].encode('utf-8') + b'\0' + item['sha256'].encode('ascii') + b'\n')
        if digest.hexdigest() != previous['source_manifest']['sha256']:
            return False
        expected_ids = {obj['object_id']: obj['finding_ids'] for obj in objects}
        actual_ids = {identity: [] for identity in expected_ids}
        for finding in findings:
            if finding['review_state'] != 'UNREVIEWED':
                return False
            actual_ids[finding['object_id']].append(finding['finding_id'])
        counts = Counter(obj['status'] for obj in objects)
        summary = dict(scanned_files=len(objects), supported_candidates=sum(o['supported_candidate'] for o in objects),
                       statuses={key: counts[key] for key in ('EXTRACTED', 'PARTIAL', 'OUT_OF_SCOPE', 'QUARANTINED')},
                       total_findings=len(findings), finding_codes=dict(sorted(Counter(f['code'] for f in findings).items())))
        return expected_ids == actual_ids and summary == previous['summary']
    except (ValueError, TypeError, KeyError, AttributeError, ToolError):
        return False


def destination(source: Path, output_root: Path, output: Path) -> Path:
    source = safe_path(source)
    output_root = safe_path(output_root)
    target = safe_path(output if output.is_absolute() else output_root / output)
    if output_root == Path(output_root.anchor) or not target.is_relative_to(output_root) or target == output_root:
        raise ToolError('output must be a file within the intended non-root output directory')
    if output_root.is_relative_to(source) or source.is_relative_to(output_root):
        raise ToolError('source and output roots must not overlap')
    if target.is_relative_to(REPOSITORY) and not target.is_relative_to(DEFAULT_OUTPUT_ROOT):
        raise ToolError('repository output is restricted to build/migration-tooling-v1/')
    # Explicit external output roots may belong to another checkout; protect tracked files there too.
    ancestor = target.parent
    while not ancestor.exists():
        ancestor = ancestor.parent
    probe = subprocess.run(['git', '-C', str(ancestor), 'rev-parse', '--show-toplevel'],
                           capture_output=True, text=True, check=False)
    if probe.returncode == 0:
        checkout = Path(probe.stdout.strip()).resolve()
        relative = target.relative_to(checkout).as_posix()
        tracked = subprocess.run(['git', '-C', str(checkout), 'ls-files', '--error-unmatch', '--', relative],
                                 capture_output=True, check=False)
        if tracked.returncode == 0:
            raise ToolError('refusing to replace a tracked file')
        if tracked.returncode != 1:
            raise ToolError('cannot verify tracked output protection')
    if target.exists():
        if not target.is_file():
            raise ToolError('output target is not a regular file')
        if not recognized_output(target.read_bytes()):
            raise ToolError('refusing to overwrite unrecognized output')
    return target


def atomic_write(target: Path, payload: bytes) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    safe_path(target)  # Recheck after creating directories, before allocating the temp file.
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode='wb', dir=target.parent, prefix='.migration-', suffix='.tmp', delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, target)
        temporary = None
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument('--source-root', type=Path, default=REPOSITORY / 'reference/es2',
                        help='ES2 root containing mudlib/d, or a mudlib-shaped root containing d')
    result.add_argument('--output-root', type=Path, default=DEFAULT_OUTPUT_ROOT,
                        help='explicit intended output directory; defaults to ignored build output')
    result.add_argument('--output', type=Path, default=Path('static-rooms.json'),
                        help='destination within output-root (default: static-rooms.json)')
    result.add_argument('--profile', choices=[PROFILE], default=PROFILE)
    return result


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    try:
        target = destination(args.source_root, args.output_root, args.output)
        document, code = scan(args.source_root)
        payload = canonical(document)
        # Serialization must be complete and round-trip clean before replacement.
        if json.loads(payload) != document:
            raise ToolError('IR serialization invariant failed')
        atomic_write(target, payload)
        print(json.dumps({'exit_code': code, **document['summary']}, ensure_ascii=True))
        return code
    except Exception as error:
        # Object SourceError is caught by the extractor; everything else is fatal exit2.
        # Keep machine-specific details out of canonical output (stderr is diagnostic only).
        print(f'FATAL: {type(error).__name__}: {error}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
