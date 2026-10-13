import { joinSession } from "@github/copilot-sdk/extension";
import { EVENT_TYPES, StatusController, TmuxStatus } from "./status.mjs";

const session = await joinSession();

if (process.env.TMUX && process.env.TMUX_PANE) {
    const controller = new StatusController(new TmuxStatus(process.env.TMUX_PANE), {
        onError: async (error) => {
            const message = `tmux-status: ${error.stderr?.trim() || error.message}`;
            try {
                await session.log(message, { level: "warning" });
            } catch (logError) {
                console.error(`${message}; could not notify the session: ${logError.message}`);
            }
        },
    });
    await controller.start();
    const unsubscribe = EVENT_TYPES.map((type) => session.on(type, (event) => {
        controller.handle(event);
    }));
    const shutdown = async () => {
        unsubscribe.forEach((remove) => remove());
        await controller.stop();
        await session.disconnect();
    };
    for (const signal of ["SIGINT", "SIGTERM"]) {
        process.once(signal, () => {
            shutdown().then(() => process.exit(0), (error) => {
                console.error(`tmux-status: ${error.message}`);
                process.exit(1);
            });
        });
    }
}
