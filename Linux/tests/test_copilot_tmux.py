import importlib.util
from importlib.machinery import SourceFileLoader
import io
import json
import os
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest import mock


SCRIPT = Path(__file__).parents[1] / "bin" / "copilot-tmux"
LOADER = SourceFileLoader("copilot_tmux", str(SCRIPT))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
COPILOT_TMUX = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(COPILOT_TMUX)

SESSION_A = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
SESSION_B = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"


class CopilotTmuxTests(unittest.TestCase):
    def test_strip_session_control_preserves_launcher_flags(self):
        argv = [
            "agency",
            "copilot",
            "--profile-only",
            "lazy",
            "--session-id",
            SESSION_A,
            "--yolo",
            "--resume=" + SESSION_B,
        ]

        self.assertEqual(
            COPILOT_TMUX.strip_session_control(argv),
            [
                "agency",
                "copilot",
                "--profile-only",
                "lazy",
                "--yolo",
            ],
        )

    @mock.patch.object(COPILOT_TMUX, "pane_bound_session_id", return_value=SESSION_B)
    @mock.patch.object(COPILOT_TMUX, "inuse_session_ids", return_value={SESSION_A})
    def test_official_hook_binding_wins_over_private_fallbacks(
        self,
        _inuse,
        _bound,
    ):
        session_id, source = COPILOT_TMUX.active_session_id(
            123,
            SESSION_A,
            "stale title - GitHub Copilot",
            "%1",
        )

        self.assertEqual((session_id, source), (SESSION_B, "session-hook"))

    @mock.patch.object(COPILOT_TMUX, "pane_bound_session_id", return_value=None)
    @mock.patch.object(COPILOT_TMUX, "inuse_session_ids", return_value={SESSION_B})
    def test_unique_live_hold_beats_stale_launch_id(self, _inuse, _bound):
        session_id, source = COPILOT_TMUX.active_session_id(
            123,
            SESSION_A,
            "stale title - GitHub Copilot",
            "%1",
        )

        self.assertEqual((session_id, source), (SESSION_B, "live-hold"))

    @mock.patch.object(
        COPILOT_TMUX,
        "pane_option",
        side_effect=[SESSION_B, "9999"],
    )
    def test_pane_binding_from_another_process_is_ignored(self, _pane_option):
        self.assertIsNone(
            COPILOT_TMUX.pane_bound_session_id("%1", 1234, {SESSION_B})
        )

    @mock.patch.object(
        COPILOT_TMUX,
        "pane_option",
        side_effect=["9999", "/tmp/stale-home"],
    )
    def test_copilot_home_from_another_process_is_ignored(self, _pane_option):
        self.assertIsNone(COPILOT_TMUX.pane_bound_copilot_home("%1", 1234))

    @mock.patch.object(
        COPILOT_TMUX,
        "active_session_id",
        return_value=(SESSION_B, "session-hook"),
    )
    @mock.patch.object(
        COPILOT_TMUX,
        "copilot_home_from_process",
        return_value=Path("/tmp/copilot-home"),
    )
    @mock.patch.object(COPILOT_TMUX, "pane_option", return_value=None)
    def test_resolve_launcher_handles_agency_and_new_session_id(
        self,
        _pane_option,
        _home,
        _active,
    ):
        processes = {
            10: {"ppid": 1, "argv": ["zsh"]},
            11: {
                "ppid": 10,
                "argv": [
                    "agency",
                    "copilot",
                    "--profile-only",
                    "lazy",
                    "--yolo",
                ],
            },
            12: {
                "ppid": 11,
                "argv": [
                    "/opt/copilot",
                    "--new-session-id",
                    SESSION_A,
                ],
            },
        }

        resolved = COPILOT_TMUX.resolve_launcher(
            10,
            "Current - GitHub Copilot",
            "%1",
            processes,
        )

        self.assertEqual(resolved["session_id"], SESSION_B)
        self.assertEqual(resolved["launcher_kind"], "agency")
        self.assertIn("--profile-only", resolved["launcher"])
        self.assertIn("--yolo", resolved["launcher"])
        self.assertNotIn("--new-session-id", resolved["launcher"])

    @mock.patch.object(COPILOT_TMUX, "inuse_session_ids", return_value=set())
    @mock.patch.object(
        COPILOT_TMUX,
        "copilot_home_from_process",
        return_value=Path("/tmp/copilot-home"),
    )
    @mock.patch.object(COPILOT_TMUX, "pane_option", return_value=None)
    def test_resolve_launcher_detects_restored_resume_pane(
        self,
        _pane_option,
        _home,
        _inuse,
    ):
        processes = {
            10: {"ppid": 1, "argv": ["agency", "copilot", "--yolo", f"--resume={SESSION_A}"]},
            11: {"ppid": 10, "argv": ["/opt/copilot", f"--resume={SESSION_A}"]},
        }

        resolved = COPILOT_TMUX.resolve_launcher(10, "", "%1", processes)

        self.assertEqual(resolved["session_id"], SESSION_A)
        self.assertEqual(resolved["launcher"][-1], "--yolo")

    def test_version_flag_and_plain_table(self):
        output = io.StringIO()
        with redirect_stdout(output), self.assertRaises(SystemExit):
            COPILOT_TMUX.build_parser().parse_args(["--version"])
        self.assertEqual(
            output.getvalue().strip(),
            f"copilot-tmux {COPILOT_TMUX.__version__}",
        )

        output = io.StringIO()
        entry = {
            "tmux_session": "work",
            "window_index": 2,
            "window_name": "Agent",
            "session_id": SESSION_A,
            "cwd": str(Path.home() / "repo"),
            "metadata": {"summary": "Fix things"},
        }
        with redirect_stdout(output):
            COPILOT_TMUX.print_entries([entry])
        self.assertNotIn("\033[", output.getvalue())
        self.assertIn(f"work:2  Agent  {SESSION_A[:8]}  ~/repo", output.getvalue())

    def test_session_start_hook_records_pane_binding(self):
        payload = io.StringIO(json.dumps({"sessionId": SESSION_B, "source": "resume"}))
        with (
            mock.patch.object(COPILOT_TMUX, "TMUX", "/usr/bin/tmux"),
            mock.patch.object(COPILOT_TMUX.sys, "stdin", payload),
            mock.patch.object(
                COPILOT_TMUX,
                "find_copilot_ancestor",
                return_value=1234,
            ),
            mock.patch.object(COPILOT_TMUX, "run") as run,
            mock.patch.dict(
                os.environ,
                {"TMUX": "/tmp/tmux,1,0", "TMUX_PANE": "%7"},
                clear=False,
            ),
        ):
            COPILOT_TMUX.record_session_start(None)

        self.assertEqual(run.call_count, 3)
        self.assertEqual(
            run.call_args_list[0].args[0][-2:],
            [COPILOT_TMUX.TMUX_SESSION_OPTION, SESSION_B],
        )
        self.assertEqual(
            run.call_args_list[2].args[0][-2:],
            [COPILOT_TMUX.TMUX_PID_OPTION, "1234"],
        )

    def test_custom_copilot_home_is_restored(self):
        entry = {
            "launcher": ["agency", "copilot", "--yolo"],
            "session_id": SESSION_B,
            "copilot_home": "/tmp/custom-copilot",
        }

        command = COPILOT_TMUX.restore_command(entry)

        self.assertIn("COPILOT_HOME=/tmp/custom-copilot", command)
        self.assertIn(f"--resume={SESSION_B}", command)

    def test_save_and_restore_preserve_changed_session_directories(self):
        for metadata_state in ("changed", "missing", "empty"):
            with (
                self.subTest(metadata_state=metadata_state),
                tempfile.TemporaryDirectory() as directory,
            ):
                root = Path(directory)
                copilot_home = root / "copilot-home"
                state_dir = root / "snapshots"
                snapshot_path = state_dir / "snapshot.json"
                initial_dirs = [root / f"initial directory {index}" for index in range(2)]
                current_dirs = [root / f"current directory {index}" for index in range(2)]
                workspace_paths = []
                panes = []
                launchers = []
                for index, session_id in enumerate((SESSION_A, SESSION_B)):
                    initial_dirs[index].mkdir()
                    current_dirs[index].mkdir()
                    workspace = copilot_home / "session-state" / session_id / "workspace.yaml"
                    workspace.parent.mkdir(parents=True)
                    workspace.write_text(f"cwd: {json.dumps(str(initial_dirs[index]))}\n")
                    workspace_paths.append(workspace)
                    panes.append({
                        "tmux_session": "snapshot-test",
                        "window_index": index,
                        "window_name": f"Agent {index}",
                        "window_active": index == 0,
                        "window_panes": 1,
                        "pane_id": f"%{index}",
                        "pane_pid": 100 + index,
                        "pane_title": f"Agent {index}",
                        "cwd": str(initial_dirs[index]),
                    })
                    launchers.append({
                        "session_id": session_id,
                        "copilot_home": str(copilot_home),
                        "launcher": ["agency", "copilot", "--profile-only", "lazy", "--yolo"],
                    })

                output = io.StringIO()
                with (
                    mock.patch.object(COPILOT_TMUX, "STATE_DIR", state_dir),
                    mock.patch.object(COPILOT_TMUX, "SNAPSHOT_PATH", snapshot_path),
                    mock.patch.object(COPILOT_TMUX, "TMUX", "/usr/bin/tmux"),
                    mock.patch.object(COPILOT_TMUX, "process_table", return_value={}),
                    mock.patch.object(COPILOT_TMUX, "list_tmux_panes", return_value=panes),
                    mock.patch.object(
                        COPILOT_TMUX, "resolve_launcher", side_effect=launchers * 2,
                    ),
                    redirect_stdout(output),
                ):
                    save_args = COPILOT_TMUX.build_parser().parse_args(["save"])
                    COPILOT_TMUX.save_snapshot(save_args)
                    for index, workspace in enumerate(workspace_paths):
                        content = "name: Current session\n"
                        if metadata_state == "changed":
                            content += f"cwd: {json.dumps(str(current_dirs[index]))}\n"
                        elif metadata_state == "empty":
                            content += 'cwd: ""\n'
                        workspace.write_text(content)
                    output.seek(0)
                    output.truncate()
                    COPILOT_TMUX.save_snapshot(save_args)
                    COPILOT_TMUX.show_snapshot(None)
                    entries = json.loads(snapshot_path.read_text())["entries"]
                    expected = [
                        str(path) for path in
                        (current_dirs if metadata_state == "changed" else initial_dirs)
                    ]
                    self.assertEqual([entry["cwd"] for entry in entries], expected)
                    for cwd in expected:
                        self.assertIn(cwd, output.getvalue())

                    commands = []
                    with (
                        mock.patch.object(
                            COPILOT_TMUX, "existing_tmux_sessions", return_value=set(),
                        ),
                        mock.patch.object(
                            COPILOT_TMUX, "display_tmux_command", side_effect=commands.append,
                        ),
                    ):
                        restore_args = COPILOT_TMUX.build_parser().parse_args(
                            ["restore", "--dry-run"],
                        )
                        COPILOT_TMUX.restore_snapshot(restore_args)
                    windows = [
                        command for command in commands
                        if command[1] in ("new-session", "new-window")
                    ]
                    self.assertEqual(
                        [command[command.index("-c") + 1] for command in windows],
                        expected,
                    )
                    for command, session_id in zip(windows, (SESSION_A, SESSION_B)):
                        self.assertIn(f"--resume={session_id}", command[-1])
                        self.assertIn("--profile-only lazy --yolo", command[-1])

    def test_failed_snapshot_publish_preserves_previous_file(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            state_dir = Path(temporary_directory)
            snapshot_path = state_dir / "snapshot.json"
            snapshot_path.write_text("old snapshot\n")
            with (
                mock.patch.object(COPILOT_TMUX, "STATE_DIR", state_dir),
                mock.patch.object(COPILOT_TMUX, "SNAPSHOT_PATH", snapshot_path),
                mock.patch.object(
                    COPILOT_TMUX.os,
                    "replace",
                    side_effect=OSError("publish failed"),
                ),
            ):
                with self.assertRaises(OSError):
                    COPILOT_TMUX.write_snapshot({"schema_version": 1})

            self.assertEqual(snapshot_path.read_text(), "old snapshot\n")
            self.assertFalse(snapshot_path.with_suffix(".json.tmp").exists())


if __name__ == "__main__":
    unittest.main()
