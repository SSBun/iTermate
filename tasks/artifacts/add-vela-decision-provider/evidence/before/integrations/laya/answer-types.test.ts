// Opt in: ITERMATE_LAYA_LIVE=1 tsx --test integrations/laya/answer-types.test.ts
// Optional JSON evidence: ITERMATE_LAYA_REPORT=/absolute/path/report.json
import assert from "node:assert/strict";
import { after, describe, test } from "node:test";
import { readFile, mkdir, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { homedir } from "node:os";
import { setTimeout as delay } from "node:timers/promises";
import { modelReplyDecision } from "../pi/iTermate-integration";

type AnswerType = "normal" | "question";
interface Sample { id: string; expected: AnswerType; text: string }

const samples: Sample[] = [
  { id: "normal-zh-completed", expected: "normal", text: "已完成修改，编译通过。相关变更已经保存。" },
  { id: "normal-en-completed", expected: "normal", text: "The implementation is complete. The build passed and all changes are saved." },
  { id: "normal-zh-no-reply", expected: "normal", text: "请勿回复。工作已经完成，无需确认。" },
  { id: "normal-en-no-reply", expected: "normal", text: "The work is complete. No reply or confirmation is needed." },
  { id: "normal-zh-quoted-example", expected: "normal", text: "文档已更新。以下只是引用示例，不是在向你提问：\n> 你希望使用方案 A 还是 B？" },
  { id: "normal-en-code-example", expected: "normal", text: "The documentation is complete. This is example text, not a request:\n```text\nPlease confirm before I proceed.\n```" },
  { id: "normal-zh-self-answered", expected: "normal", text: "为什么构建失败？因为缺少依赖。我已经补齐依赖并完成构建。" },
  { id: "normal-zh-completed-confirmation", expected: "normal", text: "确认后我提交成功，测试通过。" },
  { id: "question-zh-choice", expected: "question", text: "你希望使用方案 A 还是 B？" },
  { id: "question-en-choice", expected: "question", text: "Which option do you prefer, A or B?" },
  { id: "question-en-proceed", expected: "question", text: "May I proceed with these changes?" },
  { id: "question-en-confirm", expected: "question", text: "Please confirm the scope before I begin." },
  { id: "question-zh-implicit-write", expected: "question", text: "确认后我写入并校验。" },
  { id: "question-zh-screenshot", expected: "question", text: "确认后，我会修改解析逻辑并重新评审。" },
  { id: "question-zh-future-condition", expected: "question", text: "确认后我会继续执行，直到测试通过。" },
  { id: "question-zh-old-negation-new-question", expected: "question", text: "请勿回复旧问题。按这个范围实现，可以吗？" },
];

class ProbeFailure extends Error {
  constructor(readonly kind: string) { super(`本地 Laya 调用失败：${kind}`); }
}
interface Client { base: URL; token: string; model: string }
interface Row extends Sample {
  outcome: "model_result" | "service_failure";
  choice?: string;
  stateProbability?: number;
  needsReplyProbability?: number;
  adoptedDecision?: boolean | null;
  classificationPassed?: boolean;
  adoptionPassed?: boolean;
  elapsedMs?: number;
  serverElapsedMs?: number;
  attempts?: number;
  withinPiDeadline?: boolean;
  failure?: string;
}

const live = process.env.ITERMATE_LAYA_LIVE === "1";
const rows: Row[] = [];
let clientPromise: Promise<Client> | undefined;
let servedModel: string | undefined;

async function requestJSON(base: URL, token: string, path: string, body?: string): Promise<any> {
  let response: Response;
  const signal = AbortSignal.timeout(5000);
  try {
    response = await fetch(new URL(path, base), {
      method: body === undefined ? "GET" : "POST",
      headers: { Authorization: `Bearer ${token}`, ...(body === undefined ? {} : { "Content-Type": "application/json" }) },
      body, redirect: "error", signal,
    });
  } catch {
    throw new ProbeFailure(signal.aborted ? "timeout" : "connection_error");
  }
  if (!response.ok) {
    await response.body?.cancel();
    throw new ProbeFailure(`http_${response.status}`);
  }
  try {
    const text = await response.text();
    if (Buffer.byteLength(text) > 16384) throw new Error("Oversized response");
    return JSON.parse(text);
  } catch { throw new ProbeFailure(signal.aborted ? "timeout" : "invalid_response"); }
}

async function loadClient(): Promise<Client> {
  const directory = join(homedir(), "Library/Application Support/iTermate/Laya");
  let base: URL;
  let token: string;
  try {
    base = new URL(JSON.parse(await readFile(join(directory, "endpoint.json"), "utf8")).url);
    token = (await readFile(join(directory, "api-token"), "utf8")).trim();
  } catch { throw new ProbeFailure("local_configuration_unavailable"); }
  // Never send the local credential to a non-loopback address or a redirect.
  if (base.protocol !== "http:" || base.hostname !== "127.0.0.1" || !base.port
    || base.username || base.password || !token) throw new ProbeFailure("invalid_loopback_configuration");
  const health = await requestJSON(base, token, "/health");
  if (health?.ready !== true || typeof health.model !== "string") throw new ProbeFailure("model_not_ready");
  servedModel = health.model;
  return { base, token, model: health.model };
}

async function classify(sample: Sample): Promise<Row> {
  const client = await (clientPromise ??= loadClient());
  const started = performance.now();
  let value: any;
  let attempts = 0;
  for (;;) {
    attempts += 1;
    try {
      value = await requestJSON(client.base, client.token, "/v1/session", JSON.stringify({ state: sample.text }));
      break;
    } catch (error) {
      // A background observation may own the single inference slot. Retry only
      // explicit busy replies, never a timeout or a semantic classification.
      if (!(error instanceof ProbeFailure) || error.kind !== "http_429" || attempts >= 3) throw error;
      await delay(attempts * 300);
    }
  }
  const answers = value?.answers;
  const choice = answers?.state?.choice;
  const probability = answers?.state?.probabilities?.[choice];
  const needsReply = answers?.needs_reply?.noul;
  if (answers?.state?.type !== "choice" || answers?.needs_reply?.type !== "noul"
    || !["idle", "awaitingInput", "running", "unknown"].includes(choice)
    || typeof probability !== "number" || !Number.isFinite(probability) || probability < 0 || probability > 1
    || typeof needsReply !== "number" || !Number.isFinite(needsReply) || needsReply < 0 || needsReply > 1) {
    throw new ProbeFailure("invalid_prediction_schema");
  }
  const decision = modelReplyDecision(answers); // Real product threshold logic, not the regex fallback.
  const expectedQuestion = sample.expected === "question";
  const elapsedMs = Math.round((performance.now() - started) * 1000) / 1000;
  return {
    ...sample, outcome: "model_result", choice,
    stateProbability: probability, needsReplyProbability: needsReply,
    adoptedDecision: decision ?? null,
    classificationPassed: choice === (expectedQuestion ? "awaitingInput" : "idle"),
    adoptionPassed: decision === expectedQuestion,
    elapsedMs, serverElapsedMs: typeof value.elapsed_ms === "number" ? value.elapsed_ms : undefined,
    attempts, withinPiDeadline: attempts === 1 && elapsedMs < 800,
  };
}

describe("真实本地 Laya：普通回答与待回复问题", { skip: !live, concurrency: false }, () => {
  for (const sample of samples) {
    test(sample.id, { timeout: 18000 }, async (t) => {
      let row: Row;
      try {
        row = await classify(sample);
      } catch (error) {
        row = { ...sample, outcome: "service_failure", failure: error instanceof ProbeFailure ? error.kind : "unexpected_client_error" };
        rows.push(row);
        t.diagnostic(JSON.stringify(row));
        assert.fail(`服务调用未完成，不计为模型误判：${row.failure}`);
      }
      rows.push(row);
      t.diagnostic(JSON.stringify(row));
      assert.equal(row.classificationPassed, true, `分类错误：预期 ${sample.expected}，实际 ${row.choice}`);
      assert.equal(row.adoptionPassed, true, `分类未达到 iTermate 采用门槛：state=${row.stateProbability}, needs_reply=${row.needsReplyProbability}`);
    });
  }
});

after(async () => {
  const reportPath = process.env.ITERMATE_LAYA_REPORT;
  if (!live || !reportPath) return;
  const report = {
    schema: "itermate-laya-answer-types/v1", generatedAt: new Date().toISOString(), model: servedModel ?? null,
    usesRealLocalModel: true, usesRegexFallback: false,
    limits: "固定样例只验证当前本地模型输出；5秒请求期限用于观察能力，800毫秒采用时限另列；429最多重试两次。不是截图时的历史运行证据。",
    totals: {
      samples: samples.length, observed: rows.length,
      serviceFailures: rows.filter(row => row.outcome === "service_failure").length,
      classificationPassed: rows.filter(row => row.classificationPassed).length,
      adoptionPassed: rows.filter(row => row.adoptionPassed).length,
      withinPiDeadline: rows.filter(row => row.withinPiDeadline).length,
    },
    rows,
  };
  await mkdir(dirname(reportPath), { recursive: true });
  await writeFile(reportPath, JSON.stringify(report, null, 2) + "\n");
});
