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

    def test_every_archive_has_a_pinned_sha512(self) -> None:
        archives = [bootstrap_godot.TEMPLATE_ARCHIVE, *bootstrap_godot.EDITOR_ARCHIVES.values()]
        self.assertEqual(set(archives), set(bootstrap_godot.PINNED_SHA512))
        for digest in bootstrap_godot.PINNED_SHA512.values():
            self.assertRegex(digest, r"^[0-9a-f]{128}$")

    def test_no_sums_file_is_fetched(self) -> None:
        # The pins are the only source: the bootstrap downloads the archives and nothing else.
        downloaded: list[str] = []

        def record(url: str, destination: Path) -> None:
            downloaded.append(url)
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(b"x")

        with mock.patch.object(bootstrap_godot, "_download", side_effect=record):
            self.assertEqual(1, bootstrap_godot.main(["--platform", "linux", "--output", str(self.root), "--skip-templates"]))
        self.assertEqual([f"{bootstrap_godot.RELEASE_BASE}/{bootstrap_godot.EDITOR_ARCHIVES['linux']}"], downloaded)

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

    def test_download_retries_server_errors_then_succeeds(self) -> None:
        import io
        import urllib.error

        attempts: list[str] = []

        def flaky(url: str, timeout: float | None = None):
            attempts.append(url)
            if len(attempts) < 3:
                raise urllib.error.HTTPError(url, 504, "Gateway Time-out", None, None)
            return io.BytesIO(b"payload")

        pauses: list[float] = []
        destination = self.root / "file.txt"
        with mock.patch.object(bootstrap_godot.urllib.request, "urlopen", side_effect=flaky):
            bootstrap_godot._download("https://example.invalid/file.txt", destination, pause=pauses.append)
        self.assertEqual(destination.read_bytes(), b"payload")
        self.assertEqual(len(attempts), 3)
        self.assertEqual(pauses, list(bootstrap_godot.RETRY_PAUSES[:2]))

    def test_download_does_not_retry_client_errors(self) -> None:
        import urllib.error

        attempts: list[str] = []

        def missing(url: str, timeout: float | None = None):
            attempts.append(url)
            raise urllib.error.HTTPError(url, 404, "Not Found", None, None)

        with mock.patch.object(bootstrap_godot.urllib.request, "urlopen", side_effect=missing):
            with self.assertRaises(urllib.error.HTTPError):
                bootstrap_godot._download("https://example.invalid/missing", self.root / "missing", pause=lambda _seconds: None)
        self.assertEqual(len(attempts), 1)


if __name__ == "__main__":
    unittest.main()
