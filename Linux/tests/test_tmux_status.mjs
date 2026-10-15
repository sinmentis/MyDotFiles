import assert from "node:assert/strict";
import { execFile, spawn } from "node:child_process";
import { once } from "node:events";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import { test } from "node:test";
import {
    FRAME_INTERVAL_MS,
    LEASE_SECONDS,
    SPINNER_FRAMES,
    StatusController,
    StatusTracker,
    TmuxStatus,
    indicator,
} from "../copilot/extensions/tmux-status/status.mjs";

const execute = promisify(execFile);
const event = (type, data = {}, agentId) => ({ type, data, agentId });

test("running survives tool/model turns and related background work", () => {
    const tracker = new StatusTracker();
    tracker.handle(event("user.message"));
    assert.equal(tracker.state, "running");
    tracker.handle(event("assistant.turn_start"));
    tracker.handle(event("assistant.turn_end"));
    tracker.handle(event("assistant.idle"));
    tracker.handle(event("session.idle", {}, "child"));
    assert.equal(tracker.state, "running");
    assert.deepEqual(tracker.handle(event("session.idle")), { changed: true, bell: true });
    assert.equal(tracker.state, "done");
    assert.deepEqual(tracker.handle(event("session.idle")), {});
    assert.equal(tracker.state, "done");
    tracker.handle(event("assistant.turn_start"));
    assert.equal(tracker.state, "running");
});

test("child activity and queued prompts do not start an idle main agent", () => {
    const tracker = new StatusTracker();
    tracker.handle(event("assistant.turn_start", {}, "child"));
    tracker.handle(event("user.message", { delivery: "queued" }));
    assert.equal(tracker.state, "idle");
    tracker.handle(event("user.message", { source: "system", delivery: "idle" }));
    assert.equal(tracker.state, "running");
});

test("parallel requests resume only after every request is resolved", () => {
    const tracker = new StatusTracker();
    tracker.handle(event("assistant.turn_start"));
    assert.equal(tracker.handle(event("permission.requested", { requestId: "same" })).bell, true);
    assert.equal(tracker.handle(event("permission.requested", { requestId: "same" })).changed, false);
    tracker.handle(event("elicitation.requested", { requestId: "same" }, "child"));
    tracker.handle(event("user_input.requested", { requestId: "question" }));
    tracker.handle(event("assistant.turn_start"));
    assert.equal(tracker.state, "waiting");
    tracker.handle(event("permission.completed", { requestId: "unknown" }));
    tracker.handle(event("permission.completed", { requestId: "same" }));
    tracker.handle(event("elicitation.completed", { requestId: "same" }, "child"));
    assert.equal(tracker.state, "waiting");
    tracker.handle(event("user_input.completed", { requestId: "question", answer: "yes" }));
    assert.equal(tracker.state, "running");
});

test("permissions resolved by hooks do not request attention", () => {
    const tracker = new StatusTracker();
    tracker.handle(event("assistant.turn_start"));
    assert.deepEqual(tracker.handle(event("permission.requested", {
        requestId: "automatic",
        resolvedByHook: true,
    })), {});
    assert.equal(tracker.state, "running");
    assert.equal(tracker.requests.size, 0);
});

test("cancellation is idle, not successful completion", () => {
    for (const cancellation of ["abort", "assistant.idle", "session.idle"]) {
        const tracker = new StatusTracker();
        tracker.handle(event("assistant.turn_start"));
        tracker.handle(event("permission.requested", { requestId: "pending" }));
        assert.equal(tracker.handle(event(cancellation, { aborted: true })).bell, undefined);
        tracker.handle(event("session.idle"));
        assert.equal(tracker.state, "idle");
        assert.equal(tracker.requests.size, 0);
    }
});

test("errors stop animation without a success check mark", () => {
    const tracker = new StatusTracker();
    tracker.handle(event("assistant.turn_start"));
    assert.equal(tracker.handle(event("session.error")).bell, true);
    tracker.handle(event("session.idle"));
    assert.equal(tracker.state, "error");
    assert.equal(indicator(tracker.state), " !");
    tracker.handle(event("assistant.turn_start"));
    assert.equal(tracker.state, "running");
});

test("malformed request events are rejected explicitly", () => {
    assert.throws(() => new StatusTracker().handle(event("permission.requested")), /requestId/);
    assert.throws(() => new StatusTracker().handle(event("permission.requested", {
        requestId: "",
    })), /requestId/);
    assert.throws(() => indicator("unknown"), /Unknown Copilot status/);
    assert.throws(() => new TmuxStatus("invalid"), /Invalid tmux pane ID/);
});

function controllerFixture() {
    const frames = [];
    const bells = [];
    const errors = [];
    const scheduled = new Map();
    let cleared = 0;
    const adapter = {
        async claim() {},
        async publish(state, frame, until) { frames.push({ state, frame, until }); },
        async ring() { bells.push(true); },
        async clear() { cleared += 1; },
    };
    const controller = new StatusController(adapter, {
        now: () => 100_000,
        onError: (error) => errors.push(error),
        timers: {
            setInterval(callback, interval) {
                const token = {};
                scheduled.set(token, { callback, interval });
                return token;
            },
            clearInterval(token) { scheduled.delete(token); },
        },
    });
    return { controller, adapter, frames, bells, errors, scheduled, cleared: () => cleared };
}

test("animation advances every 200 ms and stops on idle", async () => {
    const fixture = controllerFixture();
    await fixture.controller.start();
    fixture.controller.handle(event("assistant.turn_start"));
    await fixture.controller.queue;
    const [{ callback, interval }] = fixture.scheduled.values();
    assert.equal(interval, FRAME_INTERVAL_MS);
    assert.equal(interval, 200);
    assert.equal(fixture.frames.at(-1).until, 100 + LEASE_SECONDS);
    for (let index = 0; index < SPINNER_FRAMES.length; index += 1) {
        callback();
        await fixture.controller.queue;
    }
    assert.equal(new Set(fixture.frames.slice(2).map(({ frame }) => frame)).size, 10);
    fixture.controller.handle(event("session.idle"));
    await fixture.controller.queue;
    assert.equal(fixture.scheduled.size, 0);
    assert.equal(fixture.frames.at(-1).state, "done");
    assert.equal(fixture.bells.length, 1);
    await fixture.controller.stop();
    assert.equal(fixture.cleared(), 1);
});

test("waiting uses a heartbeat instead of a spinner", async () => {
    const fixture = controllerFixture();
    await fixture.controller.start();
    fixture.controller.handle(event("assistant.turn_start"));
    fixture.controller.handle(event("user_input.requested", { requestId: "question" }));
    await fixture.controller.queue;
    const [{ interval }] = fixture.scheduled.values();
    assert.equal(interval, 1000);
    assert.equal(fixture.frames.at(-1).state, "waiting");
    assert.equal(fixture.bells.length, 1);
    fixture.controller.handle(event("user_input.completed", { requestId: "question" }));
    await fixture.controller.queue;
    assert.equal([...fixture.scheduled.values()][0].interval, 200);
    await fixture.controller.stop();
});

test("shutdown clears status and ignores later events", async () => {
    const fixture = controllerFixture();
    await fixture.controller.start();
    fixture.controller.handle(event("assistant.turn_start"));
    await fixture.controller.queue;
    fixture.controller.handle(event("session.shutdown"));
    await fixture.controller.queue;
    assert.equal(fixture.scheduled.size, 0);
    assert.equal(fixture.cleared(), 1);
    fixture.controller.handle(event("assistant.turn_start"));
    assert.equal(fixture.scheduled.size, 0);
});

test("shutdown failures are reported", async () => {
    const fixture = controllerFixture();
    await fixture.controller.start();
    let attempts = 0;
    fixture.adapter.clear = async () => {
        if (attempts++ === 0) {
            throw new Error("cleanup failed");
        }
    };
    fixture.controller.handle(event("session.shutdown"));
    await fixture.controller.queue;
    assert.equal(fixture.errors.length, 1);
    assert.match(fixture.errors[0].message, /cleanup failed/);
});

test("tmux failures are reported and stop the timer", async () => {
    const fixture = controllerFixture();
    await fixture.controller.start();
    fixture.adapter.publish = async () => { throw new Error("tmux failed"); };
    fixture.controller.handle(event("assistant.turn_start"));
    await fixture.controller.queue;
    assert.equal(fixture.errors.length, 1);
    assert.match(fixture.errors[0].message, /tmux failed/);
    assert.equal(fixture.scheduled.size, 0);
    assert.equal(fixture.cleared(), 1);
});

test("temporary spawn failures retry and restore the running indicator", async () => {
    const fixture = controllerFixture();
    await fixture.controller.start();
    const publish = fixture.adapter.publish;
    let failures = 3;
    fixture.adapter.publish = async (...args) => {
        if (failures-- > 0) {
            throw Object.assign(new Error("spawn tmux EAGAIN"), { code: "EAGAIN" });
        }
        await publish(...args);
    };
    fixture.controller.handle(event("assistant.turn_start"));
    await fixture.controller.queue;
    assert.equal(fixture.controller.closed, false);
    assert.equal(fixture.cleared(), 0);
    assert.equal(fixture.errors.length, 1);
    for (let attempt = 0; attempt < 3; attempt += 1) {
        const [{ callback, interval }] = fixture.scheduled.values();
        assert.equal(interval, 1000);
        callback();
        await fixture.controller.queue;
    }
    assert.equal(fixture.errors.length, 1);
    assert.equal(fixture.frames.at(-1).state, "running");
    assert.equal(fixture.frames.at(-1).until, 100 + LEASE_SECONDS);
    assert.equal([...fixture.scheduled.values()][0].interval, FRAME_INTERVAL_MS);
    fixture.controller.handle(event("session.idle"));
    await fixture.controller.queue;
    assert.equal(fixture.frames.at(-1).state, "done");
    assert.equal(fixture.bells.length, 1);
    await fixture.controller.stop();
});

test("temporary spawn failures retry terminal states without losing attention bells", async () => {
    for (const terminal of ["session.idle", "abort"]) {
        const fixture = controllerFixture();
        await fixture.controller.start();
        fixture.controller.handle(event("assistant.turn_start"));
        await fixture.controller.queue;
        const publish = fixture.adapter.publish;
        fixture.adapter.publish = async () => {
            throw Object.assign(new Error("spawn tmux EAGAIN"), { code: "EAGAIN" });
        };
        fixture.controller.handle(event(terminal));
        await fixture.controller.queue;
        assert.equal(fixture.controller.closed, false);
        const [{ callback, interval }] = fixture.scheduled.values();
        assert.equal(interval, 1000);
        fixture.adapter.publish = publish;
        callback();
        await fixture.controller.queue;
        assert.equal(fixture.frames.at(-1).state, terminal === "abort" ? "idle" : "done");
        assert.equal(fixture.bells.length, terminal === "abort" ? 0 : 1);
        assert.equal(fixture.scheduled.size, 0);
        await fixture.controller.stop();
    }
});

test("shutdown during a temporary failure stops retries", async () => {
    const fixture = controllerFixture();
    await fixture.controller.start();
    fixture.adapter.publish = async () => {
        throw Object.assign(new Error("spawn tmux EAGAIN"), { code: "EAGAIN" });
    };
    fixture.controller.handle(event("assistant.turn_start"));
    await fixture.controller.queue;
    assert.equal(fixture.scheduled.size, 1);
    await fixture.controller.stop();
    assert.equal(fixture.scheduled.size, 0);
    assert.equal(fixture.cleared(), 1);
});

async function waitFor(check, description) {
    const deadline = Date.now() + 3000;
    while (Date.now() < deadline) {
        if (await check()) {
            return;
        }
        await new Promise((resolve) => setTimeout(resolve, 25));
    }
    assert.fail(`Timed out waiting for ${description}`);
}

test("real tmux renders separated colored tabs while preserving indices, names, and indicators", {
    timeout: 15000,
}, async () => {
    const directory = await mkdtemp(join(tmpdir(), "copilot-status-test-"));
    const socketPath = join(directory, "tmux.sock");
    const config = join(dirname(fileURLToPath(import.meta.url)), "..", ".tmux.conf");
    const environment = { ...process.env, TMUX: "", TERM: "xterm-256color", LC_ALL: "C.UTF-8" };
    const tmux = async (...args) => {
        const result = await execute("tmux", ["-S", socketPath, ...args], {
            env: environment,
            timeout: 3000,
        });
        return result.stdout.replace(/\r?\n$/, "");
    };
    let client;
    let controller;
    let serverStarted = false;
    try {
        await tmux("-f", "/dev/null", "new-session", "-d", "-s", "test", "-n", "a", "sleep 600");
        serverStarted = true;
        await tmux("source-file", config);
        assert.equal(await tmux("show-options", "-gwv", "window-status-separator"), " | ");
        assert.equal(await tmux("show-options", "-gv", "status-right"), " %m-%d %H:%M ");
        const pane = await tmux("new-window", "-d", "-t", "test", "-n", "Agent work", "-P",
            "-F", "#{pane_id}", "sleep 600");
        client = spawn("script", ["-q", "-c",
            `tmux -S '${socketPath.replaceAll("'", "'\\''")}' attach-session -t test`, "/dev/null"], {
            env: environment,
            stdio: ["pipe", "pipe", "pipe"],
        });
        let screen = "";
        client.stdout.setEncoding("utf8").on("data", (chunk) => { screen += chunk; });
        client.stderr.setEncoding("utf8").on("data", (chunk) => { screen += chunk; });
        await waitFor(async () => (await tmux("list-clients", "-F", "#{client_name}")) !== "",
            "the attached test terminal");
        const background = (color) => new RegExp(`\\x1b\\[[0-9;]*48;5;${color}(?:;[0-9;]+)?m`);
        await waitFor(() => screen.includes(" | ") && background(236).test(screen)
            && background(33).test(screen), "visible separators with gray and blue tab backgrounds");
        assert.match(screen, /\d{2}-\d{2} \d{2}:\d{2}/);
        const errors = [];
        const adapter = new TmuxStatus(pane, { socketPath });
        const originalText = await tmux("display-message", "-p", "-t", pane,
            "#{window_index}:#{window_name}");
        const indexPrefix = originalText.slice(0, originalText.indexOf(":") + 1);
        const windowName = originalText.slice(indexPrefix.length);
        controller = new StatusController(adapter, { onError: (error) => errors.push(error) });
        await controller.start();
        const label = async (format = "window-status-format") => {
            const rendered = await tmux("display-message", "-p", "-t", pane,
                `#{E:${format}}`);
            const nativeText = await tmux("display-message", "-p", "-t", pane,
                "#W#{window_flags}");
            assert.ok(rendered.startsWith(` ${indexPrefix}`) && rendered.endsWith(`${nativeText} `),
                `Original window text ${JSON.stringify(originalText)} was replaced: ${rendered}`);
            return rendered.slice(1, -1);
        };
        assert.equal(await label(), originalText);
        assert.match(await tmux("display-message", "-p", "#{T:@copilot_status_clock}"), /^\d+$/);
        controller.handle(event("assistant.turn_start"));
        await controller.queue;
        assert.match(await label(), /^\d+:\u{1f914} [\u2800-\u28ff] /u);
        assert.match(await label("window-status-current-format"), /^\d+:\u{1f914} [\u2800-\u28ff] /u);
        await waitFor(() => SPINNER_FRAMES.filter((frame) => screen.includes(frame)).length >= 3,
            "three spinner frames in the rendered status bar");
        assert.ok(screen.includes("Agent work"), "The terminal must render the original window name");

        const command = adapter.command.bind(adapter);
        adapter.command = async () => {
            throw Object.assign(new Error("spawn tmux EAGAIN"), { code: "EAGAIN" });
        };
        controller.render();
        await controller.queue;
        await tmux("set-option", "-p", "-t", pane, "@copilot_status_until",
            String(Math.floor(Date.now() / 1000) - 1));
        assert.ok(!(await label()).includes("\u{1f914}"));
        assert.equal(errors.length, 1);
        assert.equal(errors[0].code, "EAGAIN");
        adapter.command = command;
        await waitFor(async () => (await label()).includes("\u{1f914}"),
            "the thinking indicator recovering after a temporary spawn failure");
        errors.length = 0;

        controller.handle(event("user_input.requested", { requestId: "question" }));
        await controller.queue;
        assert.ok((await label()).startsWith(`${indexPrefix}\u{270b} `));
        assert.ok(!(await label()).includes("\u{1f914}"));
        controller.handle(event("user_input.completed", { requestId: "question" }));
        await controller.queue;
        controller.handle(event("session.idle"));
        await controller.queue;
        await waitFor(async () => (await label()).startsWith(`${indexPrefix}\u{2705} `),
            "the unread check mark");
        assert.equal(await tmux("display-message", "-p", "-t", pane, "#{window_bell_flag}"), "1");
        await waitFor(() => background(220).test(screen), "the yellow unread tab background");
        await tmux("select-window", "-t", pane);
        await waitFor(async () => !(await label()).includes("\u{2705}"), "unread acknowledgement");
        await label("window-status-current-format");

        await adapter.publish("running", 0, Math.floor(Date.now() / 1000) - 1);
        assert.ok(!(await label()).includes("\u{1f914}"));
        await adapter.publish("running", 0, Math.ceil(Date.now() / 1000) + LEASE_SECONDS);
        const sibling = await tmux("split-window", "-h", "-t", pane, "-P",
            "-F", "#{pane_id}", "sleep 600");
        const siblingAdapter = new TmuxStatus(sibling, { socketPath });
        await siblingAdapter.claim();
        await siblingAdapter.publish("waiting", 0, Math.ceil(Date.now() / 1000) + LEASE_SECONDS);
        const combined = await label();
        assert.equal(combined.slice(indexPrefix.length, combined.indexOf(windowName)),
            `\u{1f914} ${SPINNER_FRAMES[0]} \u{270b} `);
        await siblingAdapter.clear();

        const replacement = new TmuxStatus(pane, { socketPath });
        await replacement.claim();
        await replacement.publish("running", 1, Math.ceil(Date.now() / 1000) + LEASE_SECONDS);
        await controller.stop();
        assert.equal(await tmux("display-message", "-p", "-t", pane, "#{@copilot_status_owner}"),
            replacement.owner);
        assert.ok((await label()).includes(SPINNER_FRAMES[1]));
        await replacement.clear();
        assert.equal(await tmux("display-message", "-p", "-t", pane, "#{@copilot_status}"), "");
        await label();
        assert.deepEqual(errors, []);
    } finally {
        try {
            if (controller) {
                await controller.stop();
            }
        } finally {
            try {
                if (serverStarted) {
                    await tmux("kill-server");
                }
                if (client && client.exitCode === null && client.signalCode === null) {
                    await once(client, "exit");
                }
            } finally {
                await rm(directory, { recursive: true, force: true });
            }
        }
    }
});
