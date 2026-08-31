from __future__ import annotations

import hashlib
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


REPOSITORY = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPOSITORY / "tools/ci"))

import bootstrap_godot  # noqa: E402


class BootstrapGodotTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def test_checksum_parser_binds_digest_to_exact_archive_name(self) -> None:
        digest = "a" * 128
        self.assertEqual(
            {"Godot_v4.7.2-stable_win64.exe.zip": digest},
            bootstrap_godot._parse_sha512_sums(
                f"{digest}  *Godot_v4.7.2-stable_win64.exe.zip\n"
            ),
        )

    def test_verified_download_rejects_missing_checksum_entry(self) -> None:
        with self.assertRaises(bootstrap_godot.BootstrapError):
            bootstrap_godot._verified_download("missing.zip", self.root, {})

    def test_verified_download_fails_on_downloaded_checksum_mismatch(self) -> None:
        filename = "archive.zip"

        def write_wrong_archive(_url: str, destination: Path) -> None:
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(b"wrong")

        with mock.patch.object(bootstrap_godot, "_download", side_effect=write_wrong_archive):
            with self.assertRaises(bootstrap_godot.BootstrapError):
                bootstrap_godot._verified_download(filename, self.root, {filename: "0" * 128})

    def test_verified_download_accepts_matching_cached_archive_without_network(self) -> None:
        filename = "archive.zip"
        archive = self.root / filename
        archive.write_bytes(b"verified")
        digest = hashlib.sha512(b"verified").hexdigest()
        with mock.patch.object(bootstrap_godot, "_download") as download:
            self.assertEqual(
                archive,
                bootstrap_godot._verified_download(filename, self.root, {filename: digest}),
            )
        download.assert_not_called()


if __name__ == "__main__":
    unittest.main()
