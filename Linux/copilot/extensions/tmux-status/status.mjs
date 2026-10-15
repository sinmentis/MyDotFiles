import { execFile } from "node:child_process";
import { randomUUID } from "node:crypto";
import { writeFile } from "node:fs/promises";
import { promisify } from "node:util";

const execute = promisify(execFile);
const STATUS_OPTIONS = [
    "@copilot_state",
    "@copilot_status",
    "@copilot_status_until",
    "@copilot_status_owner",
];

export const FRAME_INTERVAL_MS = 200;
export const LEASE_SECONDS = 5;
export const SPINNER_FRAMES = [
    "\u280b", "\u2819", "\u2839", "\u2838", "\u283c",
    "\u2834", "\u2826", "\u2827", "\u2807", "\u280f",
];
export const EVENT_TYPES = [
    "user.message",
    "assistant.turn_start",
    "tool.execution_start",
    "assistant.idle",
    "session.idle",
    "session.error",
    "abort",
    "session.shutdown",
    "permission.requested",
    "permission.completed",
    "elicitation.requested",
    "elicitation.completed",
    "user_input.requested",
    "user_input.completed",
];

export function indicator(state, frame = 0) {
    switch (state) {
        case "running":
            return ` \u{1f914} ${SPINNER_FRAMES[frame % SPINNER_FRAMES.length]}`;
        case "waiting":
            return " \u{270b}";
        case "done":
            return " \u{2705}";
        case "error":
            return " !";
        case "idle":
            return "";
        default:
            throw new Error(`Unknown Copilot status: ${state}`);
    }
}

export class StatusTracker {
    state = "idle";
    active = false;
    requests = new Set();

    handle(event) {
        const [kind, action] = event.type.split(".");
        if (["permission", "elicitation", "user_input"].includes(kind)) {
            if (event.data.resolvedByHook) {
                return {};
            }
            if (typeof event.data.requestId !== "string" || !event.data.requestId) {
                throw new Error(`${event.type} has no requestId`);
            }
            const key = `${kind}:${event.data.requestId}`;
            if (action === "requested") {
                const added = !this.requests.has(key);
                this.requests.add(key);
                this.state = "waiting";
                return { changed: added, bell: added };
            }
            if (action === "completed" && this.requests.delete(key)) {
                this.state = this.requests.size ? "waiting" : this.active ? "running" : "idle";
                return { changed: true };
            }
            return {};
        }

        if (event.agentId) {
            return {};
        }
        switch (event.type) {
            case "user.message":
                if (event.data.delivery === "queued") {
                    return {};
                }
                // Fall through: system notifications also wake an idle agent.
            case "assistant.turn_start":
            case "tool.execution_start": {
                const previous = this.state;
                this.active = true;
                this.state = this.requests.size ? "waiting" : "running";
                return { changed: this.state !== previous };
            }
            case "assistant.idle":
                if (!event.data.aborted) {
                    return {};
                }
                // Fall through: cancellation is not a completed response.
            case "abort":
                this.active = false;
                this.requests.clear();
                this.state = "idle";
                return { changed: true };
            case "session.idle":
                if (event.data.aborted) {
                    this.active = false;
                    this.requests.clear();
                    this.state = "idle";
                    return { changed: true };
                }
                if (!this.active) {
                    return {};
                }
                this.active = false;
                this.requests.clear();
                this.state = "done";
                return { changed: true, bell: true };
            case "session.error":
                this.active = false;
                this.requests.clear();
                this.state = "error";
                return { changed: true, bell: true };
            case "session.shutdown":
                return { shutdown: true };
            default:
                return {};
        }
    }
}

function commandText(args) {
    return args.map((argument) => JSON.stringify(String(argument))).join(" ");
}

function targetGone(error) {
    return /can't find pane|no server running|error connecting to .+ \(No such file or directory\)/.test(
        error.stderr ?? "",
    );
}

export class TmuxStatus {
    constructor(paneId, { socketPath } = {}) {
        if (!/^%\d+$/.test(paneId)) {
            throw new Error(`Invalid tmux pane ID: ${paneId}`);
        }
        this.paneId = paneId;
        this.prefix = socketPath ? ["-S", socketPath] : [];
        this.owner = randomUUID();
        this.clients = [];
        this.clientsUntil = 0;
    }

    async command(args) {
        const result = await execute("tmux", [...this.prefix, ...args], {
            timeout: 2000,
            maxBuffer: 128 * 1024,
            encoding: "utf8",
        });
        return result.stdout.trim();
    }

    async claim() {
        this.tty = await this.command([
            "display-message", "-p", "-t", this.paneId, "#{pane_tty}",
        ]);
        if (!/^\/dev\/pts\/\d+$/.test(this.tty)) {
            throw new Error(`Unsupported tmux pane terminal: ${this.tty}`);
        }
        await this.command([
            "set-option", "-p", "-t", this.paneId, "@copilot_status_owner", this.owner,
        ]);
    }

    async guarded(commands) {
        if (Date.now() >= this.clientsUntil) {
            const clients = await this.command(["list-clients", "-F", "#{client_name}"]);
            this.clients = clients ? clients.split("\n") : [];
            this.clientsUntil = Date.now() + 1000;
        }
        const refresh = this.clients.map((client) => ["refresh-client", "-S", "-t", client]);
        const condition = `#{==:#{@copilot_status_owner},${this.owner}}`;
        const run = (batch) => this.command([
            "if-shell", "-F", "-t", this.paneId, condition,
            batch.map(commandText).join(" ; "),
        ]);
        try {
            await run([...commands, ...refresh]);
        } catch (error) {
            if (!/can't find client/.test(error.stderr ?? "")) {
                throw error;
            }
            this.clientsUntil = 0;
            await run(commands);
        }
    }

    async publish(state, frame, until) {
        const values = {
            "@copilot_state": state,
            "@copilot_status": indicator(state, frame),
            "@copilot_status_until": String(until),
        };
        await this.guarded(Object.entries(values).map(([name, value]) => [
            "set-option", "-p", "-t", this.paneId, name, value,
        ]));
    }

    async ring() {
        await writeFile(this.tty, "\x07");
    }

    async clear() {
        try {
            await this.guarded(STATUS_OPTIONS.map((name) => [
                "set-option", "-p", "-u", "-t", this.paneId, name,
            ]));
        } catch (error) {
            if (!targetGone(error)) {
                throw error;
            }
        }
    }
}

export class StatusController {
    constructor(tmux, {
        onError = (error) => console.error(`tmux-status: ${error.message}`),
        timers = { setInterval, clearInterval },
        now = Date.now,
    } = {}) {
        this.tmux = tmux;
        this.onError = onError;
        this.timers = timers;
        this.now = now;
        this.tracker = new StatusTracker();
        this.frame = 0;
        this.queue = Promise.resolve();
        this.renderQueued = false;
        this.bells = 0;
        this.closed = false;
        this.retrying = false;
    }

    async start() {
        await this.tmux.claim();
        await this.tmux.publish("idle", 0, 0);
    }

    clearTimer() {
        if (this.timer !== undefined) {
            this.timers.clearInterval(this.timer);
            this.timer = undefined;
        }
    }

    updateTimer() {
        const interval = this.retrying ? 1000
            : this.tracker.state === "running" ? FRAME_INTERVAL_MS
            : this.tracker.state === "waiting" ? 1000 : undefined;
        if (interval === this.interval) {
            return;
        }
        this.clearTimer();
        this.interval = interval;
        this.frame = 0;
        if (interval !== undefined) {
            this.timer = this.timers.setInterval(() => {
                this.frame = (this.frame + 1) % SPINNER_FRAMES.length;
                this.render();
            }, interval);
        }
    }

    handle(event) {
        if (this.closed) {
            return;
        }
        try {
            const result = this.tracker.handle(event);
            if (result.shutdown) {
                this.queue = this.stop().catch((error) => this.fail(error));
                return;
            }
            if (result.changed) {
                this.updateTimer();
                this.bells += result.bell ? 1 : 0;
                this.render();
            }
        } catch (error) {
            this.queue = this.queue.then(() => this.fail(error));
        }
    }

    render() {
        if (this.closed || this.renderQueued) {
            return;
        }
        this.renderQueued = true;
        this.queue = this.queue.then(async () => {
            this.renderQueued = false;
            if (this.closed) {
                return;
            }
            const state = this.tracker.state;
            const until = ["running", "waiting"].includes(state)
                ? Math.floor(this.now() / 1000) + LEASE_SECONDS : 0;
            await this.tmux.publish(state, this.frame, until);
            if (!this.closed && this.bells) {
                const bells = this.bells;
                await this.tmux.ring();
                this.bells -= bells;
            }
            if (this.retrying && !this.closed) {
                this.retrying = false;
                this.updateTimer();
            }
        }).catch((error) => this.retryOrFail(error));
    }

    async retryOrFail(error) {
        if (error.code !== "EAGAIN") {
            await this.fail(error);
            return;
        }
        if (this.closed) {
            return;
        }
        const report = !this.retrying;
        this.retrying = true;
        this.updateTimer();
        if (report) {
            await this.onError(error);
        }
    }

    async fail(error) {
        this.closed = true;
        this.clearTimer();
        await this.onError(error);
        try {
            await this.tmux.clear();
        } catch (cleanupError) {
            await this.onError(cleanupError);
        }
    }

    async stop() {
        this.closed = true;
        this.clearTimer();
        await this.queue;
        await this.tmux.clear();
    }
}
