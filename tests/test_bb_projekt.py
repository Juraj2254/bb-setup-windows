"""Exercise onboarding with real local Git repositories and fake GitHub/bb CLIs."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "bb-projekt.sh"
GIT = shutil.which("git")


class ProjectSetupTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / "source"
        self.source.mkdir()
        self.git("init", "-q", "-b", "main", str(self.source))
        skill = self.source / ".bb/skills/example/SKILL.md"
        skill.parent.mkdir(parents=True)
        skill.write_text("---\nname: example\ndescription: Example\n---\n")
        (self.source / "skills").symlink_to(".bb/skills")
        (self.source / "AGENTS.md").write_text("Use the project rules.\n")
        self.git("-C", str(self.source), "add", ".")
        self.commit_source()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.fake("git", '''
if sys.argv[1:3] == ["config", "--global"]:
    sys.exit(subprocess.call([os.environ["TEST_GIT"], "config", "--file", os.environ["TEST_CONFIG"], *sys.argv[3:]]))
if "get-url" in sys.argv:
    print(os.environ.get("TEST_REMOTE", "https://github.com/owner/repo.git")); sys.exit()
sys.exit(subprocess.call([os.environ["TEST_GIT"], *sys.argv[1:]]))
''')
        self.fake("gh", '''
a = sys.argv[1:]
if a == ["--version"]: print("gh version 1.0.0")
elif a[:2] == ["auth", "status"]: sys.exit(int(os.environ.get("TEST_AUTH_EXIT", "0")))
elif a[:2] == ["auth", "setup-git"]: pass
elif a[:2] == ["api", "user"]: print("tester" if a[-1] == ".login" else "Test User")
elif a[:2] == ["repo", "view"]: print(os.environ.get("TEST_PERMISSION", "WRITE"))
elif a[:2] == ["repo", "clone"]:
    sys.exit(subprocess.call([os.environ["TEST_GIT"], "clone", "-q", os.environ["TEST_SOURCE"], a[3]]))
else: sys.exit(91)
''')
        self.fake("bb", '''
a = sys.argv[1:]
p = pathlib.Path(os.environ["TEST_PROJECTS"])
projects = json.loads(p.read_text()) if p.exists() else []
if a == ["status"]: sys.exit(int(os.environ.get("TEST_BB_EXIT", "0")))
elif a[:2] == ["project", "list"]: print(json.dumps(projects))
elif a[:2] == ["machine", "list"]: print('[{"id":"host_test","status":"connected"}]')
elif a[:2] == ["project", "create"]:
    result = {"id": "proj_test", "sources": [{"path": a[a.index("--root") + 1]}]}
    projects.append(result); p.write_text(json.dumps(projects)); print(json.dumps(result))
else: sys.exit(92)
''')
        self.env = dict(os.environ, NVM_DIR=str(self.root / "nvm"),
                        BB_DATA_DIR=str(self.root / "bb-data"),
                        BB_PROJEKTI_DIR=str(self.root / "projects"),
                        TEST_GIT=GIT, TEST_SOURCE=str(self.source),
                        TEST_CONFIG=str(self.root / "gitconfig"),
                        TEST_PROJECTS=str(self.root / "bb-projects.json"))
        self.env["PATH"] = os.pathsep.join([str(self.bin), os.environ["PATH"],
                                           str(Path.home() / ".local/bin"),
                                           str(Path.home() / ".bb/bin")])
        self.target = self.root / "projects/repo"
        self.registry = self.root / "bb-data/bb-setup/projekti.tsv"

    def fake(self, name, body):
        path = self.bin / name
        path.write_text("#!/usr/bin/env python3\nimport json, os, pathlib, subprocess, sys\n" + body)
        path.chmod(0o755)

    def git(self, *args):
        return subprocess.check_output([GIT, *args], text=True, stderr=subprocess.STDOUT)

    def commit_source(self):
        self.git("-C", str(self.source), "-c", "user.name=Test", "-c",
                 "user.email=test@example.invalid", "commit", "-qm", "Fixture")

    def run_script(self, *args, code=0, stdin=False, **env):
        command = ["bash", "-s", "--"] if stdin else ["bash", str(SCRIPT)]
        result = subprocess.run([*command, *args], text=True,
                                input=SCRIPT.read_text() if stdin else None,
                                capture_output=True, env=dict(self.env, **env))
        self.assertEqual(result.returncode, code, result.stdout + result.stderr)
        return result.stdout + result.stderr

    def test_connect_from_pipe_and_repeat_preserves_canonical_skills(self):
        self.run_script("--no-login", "owner/repo", stdin=True)
        self.run_script("--no-login", "owner/repo")
        self.assertEqual(self.git("-C", str(self.target), "status", "--porcelain"), "")
        self.assertTrue((self.target / "skills").is_symlink())
        self.assertFalse((self.target / ".bb/skills").is_symlink())
        self.assertEqual(len(json.loads((self.root / "bb-projects.json").read_text())), 1)
        self.assertEqual(len(self.registry.read_text().splitlines()), 1)
        self.run_script("--status")

    def test_existing_dirty_work_survives(self):
        self.run_script("owner/repo")
        (self.target / "AGENTS.md").write_text("Unfinished collaborator work\n")
        self.run_script("owner/repo")
        self.assertEqual((self.target / "AGENTS.md").read_text(), "Unfinished collaborator work\n")

    def test_clean_clone_fast_forwards(self):
        self.run_script("owner/repo")
        (self.source / "new.txt").write_text("Remote change\n")
        self.git("-C", str(self.source), "add", "new.txt")
        self.commit_source()
        self.run_script("owner/repo")
        self.assertEqual((self.target / "new.txt").read_text(), "Remote change\n")

    def test_custom_directory_is_remembered_and_updated(self):
        first = self.root / "first project"
        second = self.root / "second project"
        self.run_script("--add", "owner/repo", "--dir", str(first))
        self.run_script("--add", "owner/repo", "--dir", str(second))
        self.run_script("owner/repo")
        self.assertFalse(first.exists())
        self.assertTrue((second / ".git").is_dir())
        self.assertEqual(self.registry.read_text(), f"owner/repo\t{second}\n")

    def test_missing_login_returns_four_without_cloning(self):
        self.run_script("--no-login", "owner/repo", code=4, TEST_AUTH_EXIT="1")
        self.assertFalse(self.target.exists())

    def test_read_only_or_missing_access_returns_five(self):
        for permission in ["READ", ""]:
            self.run_script("owner/repo", code=5, TEST_PERMISSION=permission)
        self.assertFalse(self.target.exists())

    def test_existing_different_repository_is_untouched(self):
        self.run_script("owner/repo")
        self.run_script("owner/repo", code=1, TEST_REMOTE="https://github.com/other/project.git")
        self.assertEqual(self.git("-C", str(self.target), "status", "--porcelain"), "")

    def test_tracked_skill_symlink_is_never_deleted(self):
        self.run_script("owner/repo")
        self.git("-C", str(self.target), "mv", ".bb/skills", "project-skills")
        (self.target / ".bb/skills").symlink_to("../project-skills")
        self.git("-C", str(self.target), "add", ".bb/skills")
        before = self.git("-C", str(self.target), "status", "--porcelain")
        self.run_script("owner/repo", code=1)
        self.assertTrue((self.target / ".bb/skills").is_symlink())
        self.assertEqual(self.git("-C", str(self.target), "status", "--porcelain"), before)

    def test_plain_skills_copy_and_old_local_symlink_recovery(self):
        (self.source / "skills").unlink()
        self.git("-C", str(self.source), "mv", ".bb/skills", "skills")
        self.git("-C", str(self.source), "add", "-A")
        self.commit_source()
        self.run_script("owner/repo")
        copied = self.target / ".bb/skills"
        self.assertTrue((copied / "example/SKILL.md").is_file())
        self.assertEqual(self.git("-C", str(self.target), "status", "--porcelain"), "")
        shutil.rmtree(copied)
        copied.symlink_to("../skills")
        self.run_script("owner/repo")
        self.assertFalse(copied.is_symlink())
        (copied / "example/SKILL.md").write_text("Local skill edit\n")
        self.run_script("owner/repo")
        self.assertEqual((copied / "example/SKILL.md").read_text(), "Local skill edit\n")

    def test_no_bb_leaves_clone_for_retry(self):
        self.run_script("owner/repo", code=1, TEST_BB_EXIT="1")
        self.assertTrue((self.target / ".git").is_dir())
        self.run_script("owner/repo")

    def test_invalid_arguments_do_not_create_registry(self):
        for args in [("owner/repo/extra",), ("owner/..",), ("owner/repo with space",),
                     ("owner/repo", "--dir"), ("--unknown",),
                     ("owner/repo", "other/repo")]:
            self.run_script(*args, code=2)
        self.assertFalse(self.registry.exists())

    def test_https_and_ssh_repository_names(self):
        self.run_script("--add", "https://github.com/owner/repo.git")
        self.run_script("--add", "git@github.com:owner/repo.git")
        self.assertEqual(len(self.registry.read_text().splitlines()), 1)


if __name__ == "__main__":
    unittest.main()
