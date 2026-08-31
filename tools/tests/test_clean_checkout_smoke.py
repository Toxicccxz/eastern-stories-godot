from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPOSITORY = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPOSITORY / "tools/ci"))

import clean_checkout_smoke  # noqa: E402


class CleanCheckoutSmokeTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def test_output_must_be_below_controlled_build_directory(self) -> None:
        repository = self.root / "repository"
        repository.mkdir()
        clean_checkout_smoke._validate_output(repository, repository / "build/clean-checkout")
        for unsafe in (repository, repository / "build", repository / "game", self.root / "outside"):
            with self.subTest(unsafe=unsafe):
                with self.assertRaises(clean_checkout_smoke.CleanCheckoutError):
                    clean_checkout_smoke._validate_output(repository, unsafe)

    def test_git_archive_excludes_untracked_and_dirty_content(self) -> None:
        repository = self.root / "repository"
        repository.mkdir()
        subprocess.run(["git", "init"], cwd=repository, check=True, stdout=subprocess.DEVNULL)
        subprocess.run(["git", "config", "user.email", "phase10a@example.invalid"], cwd=repository, check=True)
        subprocess.run(["git", "config", "user.name", "Phase 10A Test"], cwd=repository, check=True)
        tracked = repository / "tracked.txt"
        tracked.write_text("committed\n", encoding="utf-8")
        subprocess.run(["git", "add", "tracked.txt"], cwd=repository, check=True)
        subprocess.run(["git", "commit", "-m", "fixture"], cwd=repository, check=True, stdout=subprocess.DEVNULL)
        tracked.write_text("dirty\n", encoding="utf-8")
        (repository / "untracked.txt").write_text("local\n", encoding="utf-8")

        output = repository / "build/clean-checkout"
        output.mkdir(parents=True)
        clean_checkout_smoke._extract_committed_head(repository, output)

        self.assertEqual("committed\n", (output / "tracked.txt").read_text(encoding="utf-8"))
        self.assertFalse((output / "untracked.txt").exists())


if __name__ == "__main__":
    unittest.main()
