import importlib.util
from importlib.machinery import SourceFileLoader
import io
import json
import os
import signal
import subprocess
import sys
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
    def test_missing_tmux_server_returns_empty_collections(self):
        messages = [
            "no server running on /tmp/tmux-1000/default",
            "failed to connect to server: No such file or directory",
            "error connecting to /tmp/tmux-1000/default (No such file or directory)",
            "error connecting to /tmp/tmux-1000/default (Connection refused)",
        ]
        for message in messages:
            for function, expected in (
                (COPILOT_TMUX.list_tmux_panes, []),
                (COPILOT_TMUX.existing_tmux_sessions, set()),
            ):
                with self.subTest(message=message, function=function.__name__):
                    with mock.patch.object(
                        COPILOT_TMUX, "tmux_output",
                        side_effect=COPILOT_TMUX.CopilotTmuxError(message),
                    ):
                        self.assertEqual(function(), expected)

    def test_other_tmux_errors_are_not_treated_as_missing_server(self):
        messages = [
            "error connecting to /tmp/tmux-1000/default (Permission denied)",
            "failed to connect to server: Permission denied",
            "error connecting to /tmp/tmux-1000/default (Resource temporarily unavailable)",
            "unknown command: list-panes",
        ]
        for message in messages:
            for function in (
                COPILOT_TMUX.list_tmux_panes,
                COPILOT_TMUX.existing_tmux_sessions,
            ):
                with self.subTest(message=message, function=function.__name__):
                    error = COPILOT_TMUX.CopilotTmuxError(message)
                    with mock.patch.object(COPILOT_TMUX, "tmux_output", side_effect=error):
                        with self.assertRaises(COPILOT_TMUX.CopilotTmuxError) as raised:
                            function()
                        self.assertIs(raised.exception, error)

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

    @mock.patch.object(COPILOT_TMUX, "inuse_session_ids", return_value={SESSION_B})
    @mock.patch.object(
        COPILOT_TMUX,
        "copilot_home_from_process",
        return_value=Path("/tmp/copilot-home"),
    )
    @mock.patch.object(
        COPILOT_TMUX,
        "pane_option",
        side_effect=lambda _pane, option: {
            COPILOT_TMUX.TMUX_SESSION_OPTION: SESSION_B,
            COPILOT_TMUX.TMUX_PID_OPTION: "11",
        }.get(option),
    )
    def test_resolve_launcher_detects_plain_copilot_from_hook(
        self,
        _pane_option,
        _home,
        _inuse,
    ):
        processes = {
            10: {"ppid": 1, "argv": ["zsh"]},
            11: {"ppid": 10, "argv": ["copilot"]},
        }

        resolved = COPILOT_TMUX.resolve_launcher(10, "", "%1", processes)

        self.assertEqual(resolved["session_id"], SESSION_B)
        self.assertEqual(resolved["session_detection"], "session-hook")
        self.assertIsNone(resolved["initial_session_id"])
        self.assertEqual(resolved["launcher"], ["copilot"])

    @mock.patch.object(COPILOT_TMUX, "inuse_session_ids", return_value={SESSION_B})
    @mock.patch.object(
        COPILOT_TMUX,
        "copilot_home_from_process",
        return_value=Path("/tmp/copilot-home"),
    )
    @mock.patch.object(COPILOT_TMUX, "pane_option", return_value=None)
    def test_resolve_launcher_detects_plain_copilot_from_live_hold(
        self,
        _pane_option,
        _home,
        _inuse,
    ):
        processes = {11: {"ppid": 10, "argv": ["copilot", "--yolo"]}}

        resolved = COPILOT_TMUX.resolve_launcher(11, "", "%1", processes)

        self.assertEqual(resolved["session_id"], SESSION_B)
        self.assertEqual(resolved["session_detection"], "live-hold")

    @mock.patch.object(COPILOT_TMUX, "inuse_session_ids", return_value=set())
    @mock.patch.object(
        COPILOT_TMUX,
        "copilot_home_from_process",
        return_value=Path("/tmp/copilot-home"),
    )
    @mock.patch.object(COPILOT_TMUX, "pane_option", return_value=None)
    def test_resolve_launcher_skips_plain_copilot_without_session(
        self,
        _pane_option,
        _home,
        _inuse,
    ):
        processes = {11: {"ppid": 10, "argv": ["copilot"]}}

        self.assertIsNone(COPILOT_TMUX.resolve_launcher(11, "", "%1", processes))

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


class ShutdownTests(unittest.TestCase):
    def setUp(self):
        self.entries = [
            {"copilot_pid": 101, "session_id": SESSION_A, "copilot_home": "/tmp/home",
             "pane_id": "%1", "tmux_session": "work", "window_index": 0},
            {"copilot_pid": 102, "session_id": SESSION_B, "copilot_home": "/tmp/home",
             "pane_id": "%2", "tmux_session": "work", "window_index": 1},
        ]
        self.snapshot = {"entries": self.entries}
        self.discover = self.enterContext(mock.patch.object(
            COPILOT_TMUX, "discover_snapshot", return_value=self.snapshot,
        ))
        self.write = self.enterContext(mock.patch.object(COPILOT_TMUX, "write_snapshot"))
        self.enterContext(mock.patch.object(COPILOT_TMUX, "print_entries"))
        self.enterContext(mock.patch.object(COPILOT_TMUX, "find_copilot_ancestor", return_value=None))
        self.validate = self.enterContext(mock.patch.object(COPILOT_TMUX, "validate_shutdown_target"))
        self.open = self.enterContext(mock.patch.object(
            COPILOT_TMUX.os, "pidfd_open", side_effect=[41, 42],
        ))
        self.close = self.enterContext(mock.patch.object(COPILOT_TMUX.os, "close"))
        self.send = self.enterContext(mock.patch.object(COPILOT_TMUX.signal, "pidfd_send_signal"))
        self.select = self.enterContext(mock.patch.object(
            COPILOT_TMUX.select, "select",
            side_effect=[([], [], []), ([41], [], []), ([], [], []), ([42], [], [])],
        ))
        self.output = self.enterContext(redirect_stdout(io.StringIO()))

    def args(self, *options):
        return COPILOT_TMUX.build_parser().parse_args(["shutdown", *options])

    def test_shutdown_saves_before_sequential_signals_and_waits(self):
        order = mock.Mock()
        order.attach_mock(self.write, "save")
        order.attach_mock(self.send, "signal")
        order.attach_mock(self.select, "wait")
        COPILOT_TMUX.shutdown_sessions(self.args("--yes", "--tmux-session", "work"))
        self.assertEqual(self.discover.call_args.args[0].tmux_session, "work")
        self.assertEqual(order.mock_calls, [
            mock.call.save(self.snapshot),
            mock.call.wait([41], [], [], 0),
            mock.call.signal(41, signal.SIGTERM),
            mock.call.wait([41], [], [], COPILOT_TMUX.SHUTDOWN_TIMEOUT_SECONDS),
            mock.call.wait([42], [], [], 0),
            mock.call.signal(42, signal.SIGTERM),
            mock.call.wait([42], [], [], COPILOT_TMUX.SHUTDOWN_TIMEOUT_SECONDS),
        ])
        self.assertEqual(self.validate.call_count, 4)
        self.assertEqual(self.close.call_args_list, [mock.call(42), mock.call(41)])

    def test_dry_run_neither_saves_nor_opens_or_signals_processes(self):
        COPILOT_TMUX.shutdown_sessions(self.args("--dry-run"))
        self.write.assert_not_called()
        self.open.assert_not_called()
        self.send.assert_not_called()

    def test_save_failure_does_not_stop_any_process(self):
        self.write.side_effect = OSError("disk full")
        with self.assertRaisesRegex(COPILOT_TMUX.CopilotTmuxError, "disk full"):
            COPILOT_TMUX.shutdown_sessions(self.args("--yes"))
        self.send.assert_not_called()
        self.assertEqual(self.close.call_count, 2)

    def test_changed_target_aborts_before_save(self):
        self.validate.side_effect = COPILOT_TMUX.CopilotTmuxError("Target changed")
        with self.assertRaisesRegex(COPILOT_TMUX.CopilotTmuxError, "Target changed"):
            COPILOT_TMUX.shutdown_sessions(self.args("--yes"))
        self.write.assert_not_called()
        self.send.assert_not_called()
        self.close.assert_called_once_with(41)

    def test_target_is_revalidated_after_save(self):
        self.validate.side_effect = [None, None, COPILOT_TMUX.CopilotTmuxError("Target changed")]
        with self.assertRaisesRegex(COPILOT_TMUX.CopilotTmuxError, "Target changed"):
            COPILOT_TMUX.shutdown_sessions(self.args("--yes"))
        self.write.assert_called_once()
        self.send.assert_not_called()

    def test_timeout_stops_sequence_without_force_kill(self):
        self.select.side_effect = [([], [], []), ([], [], [])]
        with self.assertRaisesRegex(COPILOT_TMUX.CopilotTmuxError, "Timed out"):
            COPILOT_TMUX.shutdown_sessions(self.args("--yes"))
        self.send.assert_called_once_with(41, signal.SIGTERM)
        self.assertEqual(self.close.call_count, 2)

    def test_exited_process_is_not_signalled(self):
        self.select.side_effect = [([41], [], []), ([42], [], [])]
        COPILOT_TMUX.shutdown_sessions(self.args("--yes"))
        self.send.assert_not_called()

    def test_cannot_shutdown_own_copilot_ancestor(self):
        with mock.patch.object(COPILOT_TMUX, "find_copilot_ancestor", return_value=101):
            with self.assertRaisesRegex(COPILOT_TMUX.CopilotTmuxError, "separate shell"):
                COPILOT_TMUX.shutdown_sessions(self.args("--yes"))
        self.write.assert_not_called()
        self.send.assert_not_called()

    def test_declined_confirmation_does_nothing(self):
        with (
            mock.patch.object(COPILOT_TMUX.sys.stdin, "isatty", return_value=True),
            mock.patch("builtins.input", return_value="n"),
        ):
            COPILOT_TMUX.shutdown_sessions(self.args())
        self.write.assert_not_called()
        self.open.assert_not_called()

    def test_noninteractive_shutdown_requires_yes(self):
        with mock.patch.object(COPILOT_TMUX.sys.stdin, "isatty", return_value=False):
            with self.assertRaisesRegex(COPILOT_TMUX.CopilotTmuxError, "--yes"):
                COPILOT_TMUX.shutdown_sessions(self.args())
        self.write.assert_not_called()
        self.send.assert_not_called()

    def test_signal_errors_stop_sequence(self):
        self.send.side_effect = PermissionError("permission denied")
        with self.assertRaisesRegex(COPILOT_TMUX.CopilotTmuxError, "Cannot stop"):
            COPILOT_TMUX.shutdown_sessions(self.args("--yes"))
        self.send.assert_called_once_with(41, signal.SIGTERM)


class ShutdownTargetTests(unittest.TestCase):
    def test_revalidation_checks_process_session_and_home(self):
        entry = {"pane_id": "%1", "copilot_pid": 101,
                 "session_id": SESSION_A, "copilot_home": "/tmp/home"}
        pane = {"pane_id": "%1", "pane_pid": 100, "pane_title": "Copilot"}
        for change in ({}, {"copilot_pid": 102}, {"session_id": SESSION_B},
                       {"copilot_home": "/tmp/other"}):
            with (
                self.subTest(change=change),
                mock.patch.object(COPILOT_TMUX, "list_tmux_panes", return_value=[pane]),
                mock.patch.object(COPILOT_TMUX, "process_table", return_value={}),
                mock.patch.object(COPILOT_TMUX, "resolve_launcher", return_value={**entry, **change}),
            ):
                if change:
                    with self.assertRaisesRegex(COPILOT_TMUX.CopilotTmuxError, "Target changed"):
                        COPILOT_TMUX.validate_shutdown_target(entry)
                else:
                    COPILOT_TMUX.validate_shutdown_target(entry)

    @unittest.skipUnless(
        hasattr(os, "pidfd_open") and hasattr(signal, "pidfd_send_signal"),
        "Linux pidfds are required",
    )
    def test_real_process_gets_sigterm_and_finishes_cleanup_before_next_target(self):
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory) / "flushed"
            code = (
                "import pathlib, signal, sys, time\n"
                f"marker = pathlib.Path({str(marker)!r})\n"
                "def stop(*_):\n"
                "    marker.write_text('flushed')\n"
                "    sys.exit(0)\n"
                "signal.signal(signal.SIGTERM, stop)\n"
                "print('ready', flush=True)\n"
                "while True: time.sleep(1)\n"
            )
            child = subprocess.Popen([sys.executable, "-c", code], stdout=subprocess.PIPE, text=True)
            try:
                self.assertEqual(child.stdout.readline().strip(), "ready")
                entry = {"copilot_pid": child.pid, "tmux_session": "test", "window_index": 0}
                with (
                    mock.patch.object(COPILOT_TMUX, "discover_snapshot", return_value={"entries": [entry]}),
                    mock.patch.object(COPILOT_TMUX, "print_entries"),
                    mock.patch.object(COPILOT_TMUX, "write_snapshot"),
                    mock.patch.object(COPILOT_TMUX, "find_copilot_ancestor", return_value=None),
                    mock.patch.object(COPILOT_TMUX, "validate_shutdown_target"),
                    redirect_stdout(io.StringIO()),
                ):
                    args = COPILOT_TMUX.build_parser().parse_args(["shutdown", "--yes"])
                    COPILOT_TMUX.shutdown_sessions(args)
                self.assertEqual(marker.read_text(), "flushed")
                self.assertEqual(child.wait(timeout=2), 0)
            finally:
                if child.poll() is None:
                    child.kill()
                    child.wait()
                child.stdout.close()


if __name__ == "__main__":
    unittest.main()
