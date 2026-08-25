import { randomUUID } from "node:crypto";
import { execFileSync } from "node:child_process";
import { connect } from "node:net";
import { homedir } from "node:os";
import { join } from "node:path";

const supportDirectory = join(
  homedir(),
  "Library/Application Support/iTermate",
);
const bridgeSocketPath = join(supportDirectory, "bridge.sock");
const statusSocketPath = join(supportDirectory, "status.sock");
const reporterId = randomUUID();
let reportSequence = 0;

function iTermSessionID(): string | undefined {
  if (process.env.TERM_PROGRAM !== "iTerm.app") return undefined;
  const value = process.env.ITERM_SESSION_ID ?? process.env.TERM_SESSION_ID;
  return value?.split(":").at(-1);
}

function terminalTTY(): string | undefined {
  try {
    const value = execFileSync(
      "/bin/ps",
      ["-o", "tty=", "-p", String(process.pid)],
      { encoding: "utf8", timeout: 1000 },
    ).trim();
    if (!value || value === "??") return undefined;
    const tty = value.startsWith("/dev/") ? value : `/dev/${value}`;
    return /^\/dev\/tty[^/]{0,119}$/.test(tty) ? tty : undefined;
  } catch {
    return undefined;
  }
}

const tty = terminalTTY();

function report(
  status: "idle" | "running" | "finished" | "detached",
  exitStatus?: number,
  heartbeat = false,
): Promise<void> {
  const sessionID = iTermSessionID();
  if (!sessionID && !tty) return Promise.resolve();

  return new Promise((resolve) => {
    const requestId = randomUUID();
    const request = sessionID
      ? {
          version: 7,
          type: "setSessionStatus",
          requestId,
          sessionId: sessionID,
          status,
          exitStatus,
          heartbeat,
        }
      : {
          version: 1,
          type: "setTerminalStatus",
          requestId,
          tty,
          source: "agent",
          reporterId,
          sequence: ++reportSequence,
          status,
          exitStatus,
          heartbeat,
        };
    const socket = connect(
      sessionID ? bridgeSocketPath : statusSocketPath,
      () => socket.write(`${JSON.stringify(request)}\n`),
    );
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
  let agentFailed = false;
  let heartbeatGeneration = 0;
  let heartbeatTimer: ReturnType<typeof setTimeout> | undefined;
  let reportQueue = Promise.resolve();

  function queueReport(
    status: "idle" | "running" | "finished" | "detached",
    exitStatus?: number,
    heartbeat = false,
  ): Promise<void> {
    const send = () => report(status, exitStatus, heartbeat);
    reportQueue = reportQueue.then(send, send);
    return reportQueue;
  }

  function stopHeartbeat(): void {
    heartbeatGeneration += 1;
    clearTimeout(heartbeatTimer);
    heartbeatTimer = undefined;
  }

  async function sendHeartbeat(generation: number): Promise<void> {
    await queueReport("running", undefined, true);
    if (generation !== heartbeatGeneration) return;
    heartbeatTimer = setTimeout(() => void sendHeartbeat(generation), 2000);
  }

  async function startHeartbeat(): Promise<void> {
    stopHeartbeat();
    const generation = heartbeatGeneration;
    await queueReport("running");
    if (generation !== heartbeatGeneration) return;
    heartbeatTimer = setTimeout(() => void sendHeartbeat(generation), 2000);
  }

  pi.on("session_start", () => queueReport("idle"));
  pi.on("agent_start", () => {
    agentFailed = false;
    return startHeartbeat();
  });
  pi.on("agent_end", (event) => {
    const message = event.messages.findLast(({ role }) => role === "assistant");
    agentFailed = message?.stopReason === "error";
  });
  pi.on("agent_settled", () => {
    stopHeartbeat();
    return queueReport("finished", agentFailed ? 1 : 0);
  });
  pi.on("session_shutdown", () => {
    stopHeartbeat();
    return queueReport("detached");
  });
}
