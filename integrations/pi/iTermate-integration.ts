import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { randomUUID } from "node:crypto";
import { readFile, access } from "node:fs/promises";
import { existsSync } from "node:fs";
import { request as httpRequest } from "node:http";
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
  if (/不(?:会|再)?\s*(?:等待|等候)[^。！？\n]{0,20}(?:批准|授权|答复)|\b(?:not|never|without)\s+(?:awaiting|await)\b|\b(?:won't|won’t|will not|don't|don’t|do not)\s+await\b|\bno\s+(?:reply|response|confirmation|approval|input)\s+(?:is\s+)?(?:needed|required)\b/i.test(tail)) {
    return false;
  }
  // Short approval gates already imply waiting; they need no second sentence
  // saying "I will wait". Keep them action-scoped to avoid rhetorical questions.
  const approvalGate = /(?:按(?:这个|上述|以上|该)(?:范围|方案|计划|方式|步骤|设计|配置|目标)[^。！？?\n]{0,24}[，,]\s*(?:可以|行|好)(?:吗|么)|(?:这样|这么)(?:实现|修改|调整|处理|执行|继续|安排)[，,]?\s*(?:可以|行|好)(?:吗|么))[？?]\s*$/u.test(tail);
  const request = [
    /(?:是否|能否)[^。！？\n]{0,80}[？?]|\b(?:can|could|would|will) you (?:confirm|choose|select|provide)\b|请(?:你|您)?[^。！？\n]{0,30}(?:确认|选择|回复|提供|补充)|(?:你|您)(?:更希望|希望|选择|倾向)[^。！？\n]{0,80}[？?]|\bplease\s+(?:confirm|choose|select|reply|provide)\b/i,
    /请(?:你|您)?[^。！？\n]{0,30}(?:批准|授权|决定|告知|告诉我|回答|选定)|(?:你|您)(?:更偏好|更倾向于?|想要)[^。！？\n]{0,80}[？?]/,
    /\b(?:please|(?:can|could|would|will) you)\s+(?:approve|authorize|pick|decide|answer|clarify|specify|tell me|let me know)\b/i,
    /\b(?:which|what)\b[^.!?\n]{0,60}\b(?:do|would) you\s+(?:prefer|choose|want|like)\b[^.!?\n]{0,40}\?|\b(?:may|should|can) I\s+(?:proceed|continue|start|begin)\b[^.!?\n]{0,40}\?/i,
  ].some((pattern) => pattern.test(tail));
  const waiting = [
    /(?:确认|选择|回复|回答|提供|补充)[^。！？\n]{0,20}(?:后|之后)[^。！？\n]{0,20}(?:开始|继续|执行|进行)|(?:等待|等你|等您)[^。！？\n]{0,20}(?:确认|选择|回复|回答)|\b(?:before I (?:begin|start|continue|proceed)|(?:once|after) you (?:confirm|choose|reply)|waiting for your (?:reply|confirmation|answer))\b/i,
    /(?:批准|授权|决定|选定|答复)[^。！？\n]{0,20}(?:后|之后)[^。！？\n]{0,20}(?:开始|继续|执行|进行)|(?:等待|等候|等你|等您)[^。！？\n]{0,20}(?:批准|授权|决定|选定|答复|补充|提供)/,
    /(?:收到|得到)[^。！？\n]{0,20}(?:确认|回复|批准|授权|答复)[^。！？\n]{0,12}(?:再|才)(?:开始|继续|执行|进行)|(?:确认|回复|批准|授权|答复)(?:前|之前)[^。！？\n]{0,20}(?:不会|不再|暂停)(?:开始|继续|执行|进行)/,
    /\b(?:waiting for|awaiting) your (?:response|approval|authorization|decision|choice|input|reply|confirmation|answer)\b|\b(?:once|after) you (?:approve|authorize|select|pick|decide|answer|respond|provide|clarify|specify)\b|\b(?:before I can|before we|until you (?:confirm|approve|authorize|choose|select|reply|respond|provide))\b[^.!?\n]{0,40}\b(?:begin|start|continue|proceed)\b/i,
    /\b(?:cannot|can't|can’t)\s+(?:continue|proceed|start|begin)\s+(?:without your (?:confirmation|approval|authorization|reply|response|input)|until you (?:confirm|approve|authorize|choose|select|reply|respond|provide))\b/i,
  ].some((pattern) => pattern.test(tail));
  return approvalGate || (request && waiting);
}

function report(
  status: Status,
  exitStatus?: number,
  heartbeat = false,
  hasRunningSubagents = false,
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
          hasRunningSubagents,
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
          hasRunningSubagents,
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

// Undefined means unavailable or uncertain, not a negative classification.
export function modelReplyDecision(answers: unknown): boolean | undefined {
  if (!answers || typeof answers !== "object") return undefined;
  const value = answers as {
    state?: { type?: unknown; choice?: unknown; probabilities?: Record<string, unknown> };
    needs_reply?: { type?: unknown; noul?: unknown };
  };
  if (value.state?.type !== "choice" || value.needs_reply?.type !== "noul") return undefined;
  const choice = value.state?.choice;
  if (choice !== "awaitingInput" && choice !== "idle") return undefined;
  const probability = value.state?.probabilities?.[choice];
  const needsReplyProbability = value.needs_reply?.noul;
  if (typeof probability !== "number" || !Number.isFinite(probability)
    || probability < 0.85 || probability > 1
    || typeof needsReplyProbability !== "number" || !Number.isFinite(needsReplyProbability)
    || needsReplyProbability < 0 || needsReplyProbability > 1) return undefined;
  if (choice === "awaitingInput" && needsReplyProbability >= 0.6) return true;
  if (choice === "idle" && needsReplyProbability <= 0.4) return false;
  return undefined;
}

// The optional HTTP inference request has an 800 ms deadline.
async function classifyReplyWithModel(text: string): Promise<boolean | undefined> {
  if (!text.trim()) return undefined;
  try {
    const directory = join(supportDirectory, "Laya");
    await access(join(directory, "analysis-enabled"));
    const endpoint = JSON.parse(await readFile(join(directory, "endpoint.json"), "utf8"));
    const url = new URL(endpoint.url);
    if (url.protocol !== "http:" || url.hostname !== "127.0.0.1" || !url.port) return undefined;
    const token = (await readFile(join(directory, "api-token"), "utf8")).trim();
    const body = JSON.stringify({ state: text.slice(-1500) });
    return await new Promise<boolean | undefined>((resolve) => {
      let finished = false;
      const finish = (value: boolean | undefined) => {
        if (finished) return;
        finished = true;
        clearTimeout(timer);
        request.destroy();
        resolve(value);
      };
      const request = httpRequest({
        hostname: "127.0.0.1", port: url.port, path: "/v1/session", method: "POST",
        headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json", "Content-Length": Buffer.byteLength(body) },
      }, (response) => {
        let result = "";
        response.on("data", (data) => {
          result += data.toString();
          if (result.length > 16384) finish(undefined);
        });
        response.on("error", () => finish(undefined));
        response.on("end", () => {
          try {
            finish(response.statusCode === 200
              ? modelReplyDecision(JSON.parse(result).answers) : undefined);
          } catch { finish(undefined); }
        });
      });
      const timer = setTimeout(() => finish(undefined), 800);
      request.on("error", () => finish(undefined));
      request.end(body);
    });
  } catch { return undefined; }
}

export default function (pi: ExtensionAPI): void {
  let agentFailed = false;
  let agentRunning = false;
  let replyPending = false;
  let lastAssistantText = "";
  let modelDecision: boolean | undefined;
  let promptOpen = false;
  let baseStatus: Status = "idle";
  let active = false;
  let heartbeatGeneration = 0;
  let heartbeatTimer: ReturnType<typeof setTimeout> | undefined;
  let reportQueue = Promise.resolve(true);
  let hasRunningSubagents = false;
  let heartbeatPausedForFleet = false;
  let fleetObservedAt = 0;
  let fleetGeneration = 0;
  let fleetTimer: ReturnType<typeof setTimeout> | undefined;
  let fleetRequest: Promise<void> | undefined;
  let cancelFleetRequest: (() => void) | undefined;

  // Query the public, current-session DTO, not tool text or historical messages.
  function refreshFleet(): Promise<void> {
    if (!active) return Promise.resolve();
    if (fleetRequest) return fleetRequest;
    const generation = fleetGeneration;
    fleetRequest = new Promise<void>((resolve) => {
      const requestId = randomUUID();
      let unsubscribe = () => {};
      const finish = () => {
        clearTimeout(timer);
        unsubscribe();
        cancelFleetRequest = undefined;
        resolve();
      };
      const timer = setTimeout(finish, 1000);
      cancelFleetRequest = finish;
      unsubscribe = pi.events.on(`subagents:rpc:v1:reply:${requestId}`, (raw) => {
        const reply = raw as {
          version?: unknown; requestId?: unknown; success?: unknown;
          data?: { fleet?: { version?: unknown; totalActive?: unknown } };
        } | null;
        const fleet = reply?.data?.fleet;
        if (active && generation === fleetGeneration
          && reply?.version === 1 && reply.requestId === requestId
          && reply.success === true && fleet?.version === 1
          && typeof fleet.totalActive === "number"
          && Number.isSafeInteger(fleet.totalActive) && fleet.totalActive >= 0) {
          hasRunningSubagents = fleet.totalActive > 0;
          fleetObservedAt = performance.now();
        }
        finish();
      });
      try {
        pi.events.emit("subagents:rpc:v1:request", {
          version: 1, requestId, method: "status", params: {},
        });
      } catch {
        finish();
      }
    }).finally(() => { fleetRequest = undefined; });
    return fleetRequest;
  }

  async function pollFleet(generation: number): Promise<void> {
    const previous = hasRunningSubagents;
    await refreshFleet();
    if (!active || generation !== fleetGeneration) return;
    // The heartbeat can pause while this RPC is pending, including across the
    // expiry boundary. Inspect its actual state after the reply, not before it.
    if (previous !== hasRunningSubagents
      || (heartbeatPausedForFleet && performance.now() - fleetObservedAt <= 6000)) {
      await publish();
    }
    if (active && generation === fleetGeneration) {
      fleetTimer = setTimeout(() => void pollFleet(generation), 2000);
    }
  }

  function queueReport(
    status: Status,
    exitStatus?: number,
    heartbeat = false,
    generation = heartbeatGeneration,
  ): Promise<boolean> {
    const subagents = hasRunningSubagents && performance.now() - fleetObservedAt <= 6000
      && (status === "running" || status === "awaitingInput");
    const send = () => generation === heartbeatGeneration
      ? report(status, exitStatus, heartbeat, subagents)
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
    if (promptOpen || baseStatus === "awaitingInput") return "awaitingInput";
    return hasRunningSubagents ? "running" : baseStatus;
  }

  async function sendHeartbeat(
    generation: number,
    confirmed: boolean,
    retries = 3,
  ): Promise<void> {
    if (!active || generation !== heartbeatGeneration) return;
    // Unknown is not completion: stop renewing an unconfirmed run and let the
    // receiver's lease expire rather than emitting a false success.
    if (hasRunningSubagents && performance.now() - fleetObservedAt > 6000
      && baseStatus !== "running" && baseStatus !== "awaitingInput" && !promptOpen) {
      heartbeatPausedForFleet = true;
      return;
    }
    heartbeatPausedForFleet = false;
    if (modelDecision !== undefined && !existsSync(join(supportDirectory, "Laya", "analysis-enabled"))) {
      modelDecision = undefined;
      baseStatus = replyPending ? "awaitingInput" : "finished";
      confirmed = false; // A changed classification needs a full transition, not a lease renewal.
    }
    const status = visibleStatus();
    const leased = status === "running" || status === "awaitingInput";
    // A model-derived negative decision watches the enable marker without
    // repeatedly reporting completion or changing its timestamp.
    const accepted = !leased && confirmed ? true : await queueReport(
      status,
      status === "finished" ? (agentFailed ? 1 : 0) : undefined,
      leased && confirmed,
      generation,
    );
    if (generation !== heartbeatGeneration) return;
    // Retry the full transition until acknowledged, not a heartbeat that the
    // receiver might reject against its previous idle/finished state.
    if (leased || modelDecision !== undefined || (!accepted && retries > 0)) {
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
    lastAssistantText = "";
    modelDecision = undefined;
    agentRunning = false;
    replyPending = false;
    promptOpen = false;
    hasRunningSubagents = false;
    heartbeatPausedForFleet = false;
    fleetObservedAt = 0;
    fleetGeneration += 1;
    // Let other extensions restore their state before the first observation.
    if (active) fleetTimer = setTimeout(() => void pollFleet(fleetGeneration), 0);
    return publish();
  });
  pi.on("tool_execution_end", async (event) => {
    if (event.toolName !== "subagent") return;
    const previous = hasRunningSubagents;
    await refreshFleet();
    if (previous !== hasRunningSubagents) await publish();
  });
  pi.on("agent_start", () => {
    agentFailed = false;
    agentRunning = true;
    modelDecision = undefined;
    lastAssistantText = "";
    replyPending = false;
    baseStatus = "running";
    return publish();
  });
  pi.on("agent_end", (event) => {
    agentRunning = false;
    const message = event.messages.findLast(({ role }) => role === "assistant");
    if (message?.role !== "assistant") {
      lastAssistantText = "";
      replyPending = false;
      return;
    }
    agentFailed = message.stopReason === "error";
    lastAssistantText = message.stopReason === "stop"
      ? message.content.flatMap((block) => block.type === "text" ? [block.text] : []).join("\n")
      : "";
    replyPending = needsReply(lastAssistantText); // Cached fallback, not the primary decision.
  });
  pi.on("agent_settled", async (_event, ctx) => {
    if (!active || !ctx.isIdle()) return;
    stopHeartbeat();
    // Establish the lifecycle fallback before awaiting optional inference so UI
    // prompt events during that wait cannot restore the old running state.
    modelDecision = undefined;
    baseStatus = replyPending ? "awaitingInput" : "finished";
    const generation = heartbeatGeneration;
    await refreshFleet();
    const decision = !agentFailed && !promptOpen
      ? await classifyReplyWithModel(lastAssistantText) : undefined;
    if (!active || !ctx.isIdle() || generation !== heartbeatGeneration) return;
    modelDecision = existsSync(join(supportDirectory, "Laya", "analysis-enabled"))
      ? decision : undefined;
    baseStatus = (modelDecision ?? replyPending) ? "awaitingInput" : "finished";
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
    modelDecision = undefined;
    lastAssistantText = "";
    replyPending = false;
    // Pi still holds its branch-navigation busy flag during this event.
    baseStatus = agentRunning ? "running" : "idle";
    return publish();
  });
  pi.on("session_shutdown", () => {
    if (!active) return;
    active = false;
    fleetGeneration += 1;
    clearTimeout(fleetTimer);
    cancelFleetRequest?.();
    hasRunningSubagents = false;
    heartbeatPausedForFleet = false;
    stopHeartbeat();
    return queueReport("detached").then(() => {});
  });
}
