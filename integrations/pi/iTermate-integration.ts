import { randomUUID } from "node:crypto";
import { connect } from "node:net";
import { homedir } from "node:os";
import { join } from "node:path";

const socketPath = join(
  homedir(),
  "Library/Application Support/iTermate/bridge.sock",
);

function iTermSessionID(): string | undefined {
  const value = process.env.ITERM_SESSION_ID ?? process.env.TERM_SESSION_ID;
  return value?.split(":").at(-1);
}

function report(
  status: "idle" | "running" | "finished" | "detached",
): Promise<void> {
  const sessionID = iTermSessionID();
  if (!sessionID) return Promise.resolve();

  return new Promise((resolve) => {
    const requestId = randomUUID();
    const socket = connect(socketPath, () => {
      socket.write(
        `${JSON.stringify({
          version: 5,
          type: "setSessionStatus",
          requestId,
          sessionId: sessionID,
          status,
        })}\n`,
      );
    });
    let buffer = "";
    let completed = false;
    const complete = () => {
      if (completed) return;
      completed = true;
      socket.destroy();
      resolve();
    };

    socket.setTimeout(3000, complete);
    socket.on("data", (data) => {
      buffer += data.toString();
      const lines = buffer.split("\n");
      buffer = lines.pop() ?? "";
      for (const line of lines) {
        try {
          const message = JSON.parse(line);
          if (message.type === "actionResult" && message.requestId === requestId) {
            complete();
            return;
          }
        } catch {}
      }
    });
    socket.on("error", complete);
    socket.on("close", complete);
  });
}

export default function (pi): void {
  pi.on("session_start", () => report("idle"));
  pi.on("agent_start", () => report("running"));
  pi.on("agent_settled", () => report("finished"));
  pi.on("session_shutdown", () => report("detached"));
}
