import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { randomUUID } from "node:crypto";
import { execFileSync } from "node:child_process";
import { connect, type Socket } from "node:net";
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

type Status = "idle" | "running" | "awaitingInput" | "finished" | "detached";

// Deliberately prefer missed questions over interpreting examples as requests.
export function needsReply(text: string): boolean {
  let fence: string | undefined;
  const prose: string[] = [];
  for (const line of text.split("\n")) {
    const marker = line.match(/^\s*(`{3,}|~{3,})/);
    if (marker) {
      if (!fence) fence = marker[1];
      else if (marker[1][0] === fence[0] && marker[1].length >= fence.length) {
        fence = undefined;
      }
      prose.push("");
      continue;
    }
    if (fence || /^\s*>|^(?: {4}|\t)/.test(line)) continue;
    prose.push(line.replace(/`[^`]*`|“[^”]*”|「[^」]*」|"[^"\n]*"/g, ""));
  }
  if (fence) return false;
  const tail = prose.join("\n").trim().split(/\n\s*\n/).slice(-2).join("\n");
  if (!tail || tail.length > 1200) return false;
  if (/示例|例如|比如|举例|\bexample\b|\be\.g\.|无需|不需要|不用|不必|如果需要|如有需要|不(?:会|再|要|用)?\s*(?:等待|等你|等您)|\b(?:not|never|without)\s+waiting\b|\b(?:won't|will not|don't|do not)\s+wait\b|\bif (?:you (?:want|like|need)|needed)\b|\b(?:no need|do not need|don't need)\b/i.test(tail)) {
    return false;
  }
  const request = /(?:是否|能否)[^。！？\n]{0,80}[？?]|\b(?:can|could|would|will) you (?:confirm|choose|select|provide)\b|请(?:你|您)?[^。！？\n]{0,30}(?:确认|选择|回复|提供|补充)|(?:你|您)(?:更希望|希望|选择|倾向)[^。！？\n]{0,80}[？?]|\bplease\s+(?:confirm|choose|select|reply|provide)\b/i.test(tail);
  const waiting = /(?:确认|选择|回复|回答|提供|补充)[^。！？\n]{0,20}(?:后|之后)[^。！？\n]{0,20}(?:开始|继续|执行|进行)|(?:等待|等你|等您)[^。！？\n]{0,20}(?:确认|选择|回复|回答)|\b(?:before I (?:begin|start|continue|proceed)|(?:once|after) you (?:confirm|choose|reply)|waiting for your (?:reply|confirmation|answer))\b/i.test(tail);
  return request && waiting;
}

function report(
  status: Status,
  exitStatus?: number,
  heartbeat = false,
): Promise<boolean> {
  const sessionID = iTermSessionID();
  if (!sessionID && !tty) return Promise.resolve(false);

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
    const socket: Socket = connect(
      sessionID ? bridgeSocketPath : statusSocketPath,
      () => socket.write(`${JSON.stringify(request)}\n`),
    );
    let buffer = "";
    let completed = false;
    const complete = (accepted: boolean) => {
      if (completed) return;
      completed = true;
      socket.destroy();
      resolve(accepted);
    };

    socket.setTimeout(3000, () => complete(false));
    socket.on("data", (data) => {
      buffer += data.toString();
      const lines = buffer.split("\n");
      buffer = lines.pop() ?? "";
      for (const line of lines) {
        try {
          const message = JSON.parse(line);
          if (message.type === "actionResult" && message.requestId === requestId) {
            complete(message.ok === true);
            return;
          }
        } catch {}
      }
    });
    socket.on("error", () => complete(false));
    socket.on("close", () => complete(false));
  });
}

export default function (pi: ExtensionAPI): void {
  let agentFailed = false;
  let agentRunning = false;
  let replyPending = false;
  let promptOpen = false;
  let baseStatus: Status = "idle";
  let active = false;
  let heartbeatGeneration = 0;
  let heartbeatTimer: ReturnType<typeof setTimeout> | undefined;
  let reportQueue = Promise.resolve(true);

  function queueReport(
    status: Status,
    exitStatus?: number,
    heartbeat = false,
    generation = heartbeatGeneration,
  ): Promise<boolean> {
    const send = () => generation === heartbeatGeneration
      ? report(status, exitStatus, heartbeat)
      : Promise.resolve(false);
    reportQueue = reportQueue.then(send, send);
    return reportQueue;
  }

  function stopHeartbeat(): void {
    heartbeatGeneration += 1;
    clearTimeout(heartbeatTimer);
    heartbeatTimer = undefined;
  }

  function visibleStatus(): Status {
    return promptOpen ? "awaitingInput" : baseStatus;
  }

  async function sendHeartbeat(
    generation: number,
    confirmed: boolean,
    retries = 3,
  ): Promise<void> {
    if (!active || generation !== heartbeatGeneration) return;
    const status = visibleStatus();
    const leased = status === "running" || status === "awaitingInput";
    const accepted = await queueReport(
      status,
      status === "finished" ? (agentFailed ? 1 : 0) : undefined,
      leased && confirmed,
      generation,
    );
    if (generation !== heartbeatGeneration) return;
    // Retry the full transition until acknowledged, not a heartbeat that the
    // receiver might reject against its previous idle/finished state.
    if (leased || (!accepted && retries > 0)) {
      heartbeatTimer = setTimeout(
        () => void sendHeartbeat(generation, accepted, leased ? 3 : retries - 1), 2000,
      );
    }
  }

  function publish(): Promise<void> {
    if (!active) return Promise.resolve();
    stopHeartbeat();
    return sendHeartbeat(heartbeatGeneration, false);
  }

  pi.on("session_start", (_event, ctx) => {
    active = ctx.mode === "tui";
    baseStatus = "idle";
    agentRunning = false;
    replyPending = false;
    promptOpen = false;
    return publish();
  });
  pi.on("agent_start", () => {
    agentFailed = false;
    agentRunning = true;
    replyPending = false;
    baseStatus = "running";
    return publish();
  });
  pi.on("agent_end", (event) => {
    agentRunning = false;
    const message = event.messages.findLast(({ role }) => role === "assistant");
    if (message?.role !== "assistant") {
      replyPending = false;
      return;
    }
    agentFailed = message.stopReason === "error";
    replyPending = message.stopReason === "stop" && needsReply(
      message.content.flatMap((block) => block.type === "text" ? [block.text] : [])
        .join("\n"),
    );
  });
  pi.on("agent_settled", (_event, ctx) => {
    if (!ctx.isIdle()) return;
    baseStatus = replyPending ? "awaitingInput" : "finished";
    return publish();
  });
  pi.on("ui_prompt_start", (event, ctx) => {
    if (!active || ctx.mode !== "tui" || event.kind === "custom") return;
    promptOpen = true;
    return publish();
  });
  pi.on("ui_prompt_end", () => {
    if (!promptOpen) return;
    promptOpen = false;
    return publish();
  });
  pi.on("session_tree", () => {
    replyPending = false;
    // Pi still holds its branch-navigation busy flag during this event.
    baseStatus = agentRunning ? "running" : "idle";
    return publish();
  });
  pi.on("session_shutdown", () => {
    if (!active) return;
    active = false;
    stopHeartbeat();
    return queueReport("detached").then(() => {});
  });
}
