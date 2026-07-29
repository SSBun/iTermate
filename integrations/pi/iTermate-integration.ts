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

function report(status: "idle" | "running" | "finished" | "detached"): void {
  const sessionID = iTermSessionID();
  if (!sessionID) return;

  const socket = connect(socketPath);
  let receivedLines = 0;
  let sent = false;

  socket.setTimeout(1000, () => socket.destroy());
  socket.on("data", (data) => {
    receivedLines += data.toString().split("\n").length - 1;
    if (receivedLines < 2 || sent) return;
    sent = true;

    socket.end(
      `${JSON.stringify({
        version: 4,
        type: "setSessionStatus",
        requestId: randomUUID(),
        sessionId: sessionID,
        status,
      })}\n`,
    );
  });
  socket.on("error", () => {});
}

export default function (pi): void {
  pi.on("session_start", () => report("idle"));
  pi.on("agent_start", () => report("running"));
  pi.on("agent_settled", () => report("finished"));
  pi.on("session_shutdown", () => report("detached"));
}
