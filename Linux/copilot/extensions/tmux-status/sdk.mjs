export async function loadJoinSession(importModule = (specifier) => import(specifier)) {
    try {
        return (await importModule("@microsoft/copilot-sdk/extension")).joinSession;
    } catch (error) {
        if (error.code !== "ERR_MODULE_NOT_FOUND"
            || !error.message.startsWith("Cannot find package '@microsoft/copilot-sdk' imported from ")) {
            throw error;
        }
        return (await importModule("@github/copilot-sdk/extension")).joinSession;
    }
}
