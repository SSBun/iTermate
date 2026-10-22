import assert from "node:assert/strict";
import { test } from "node:test";
import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
import { summarizeTask, taskSummaryExcerpt } from "./iTermate-integration";

const localModel = "qwen3.5:2b";
const localURL = "http://127.0.0.1:11434/api/chat";
type Side = "remote" | "local";
type Fetcher = (url: string, init: RequestInit) => Promise<Response>;
type Remote = { url: string; model: string; key: string };
type Request = { systemPrompt: string; messages: { role: string; content: string }[] };
type Options = { maxTokens: number; signal: AbortSignal };

// Synthetic fixtures only: never read the active session, model credentials, or history.
const fixtures = [
  {
    id: "pagination",
    messages: [
      { role: "system", content: "SYNTHETIC_PRIVATE_SYSTEM" },
      { role: "user", content: "修复文章列表滚动到底部后不能加载下一页的问题。" },
      { role: "assistant", content: [
        { type: "thinking", thinking: "SYNTHETIC_PRIVATE_THINKING" },
        { type: "text", text: "正在检查分页游标和触底回调，尚未修改代码。" },
      ] },
      { role: "toolResult", content: [{ type: "text", text: "SYNTHETIC_PRIVATE_TOOL" }] },
    ],
  },
  {
    id: "changed-goal",
    messages: [
      { role: "user", content: "检查客户端点赞数格式化规则。" },
      { role: "assistant", content: "规则已核实，两个客户端均采用截断。" },
      { role: "user", content: "现在先不要改点赞数，改为定位登录后白屏的原因。" },
      { role: "assistant", content: "开始追踪登录回调与首页初始化路径。" },
    ],
  },
  {
    id: "english-request",
    messages: [
      { role: "user", content: "Investigate why the macOS sidebar loses the selected session after reconnecting." },
      { role: "assistant", content: "I am comparing session identity before and after reconnection. No fix has been applied yet." },
    ],
  },
];

function context(messages: unknown[], id: string, complete: (...args: any[]) => Promise<unknown>) {
  return {
    model: { id },
    sessionManager: { buildSessionProjection: () => ({ messages }) },
    modelRegistry: { complete },
  } as unknown as ExtensionContext;
}

// Diagnostic comparison supplies an explicit transport; production always uses the default local client.
async function titleWithAdapter(ctx: ExtensionContext, excerpt: string, signal: AbortSignal) {
  return summarizeTask(ctx, excerpt, signal, async (systemPrompt, text, cancel, maxTokens) => {
    const response = await ctx.modelRegistry.complete(ctx.model!, {
      systemPrompt, messages: [{ role: "user", content: text, timestamp: Date.now() }],
    }, { maxTokens, signal: cancel });
    if (response.stopReason !== "stop") throw new Error("Incomplete diagnostic title");
    return response.content.flatMap(block => block.type === "text" ? [block.text] : []).join("\n");
  });
}

function liveConfiguration(env: Record<string, string | undefined>): Remote | undefined {
  if (env.ITERMATE_TITLE_COMPARE_LIVE !== "1") return undefined;
  for (const name of ["ITERMATE_TITLE_REMOTE_URL", "ITERMATE_TITLE_REMOTE_MODEL", "ITERMATE_TITLE_REMOTE_API_KEY"]) {
    if (!env[name]?.trim()) throw new Error(`Missing ${name}`);
  }
  let url: URL;
  try { url = new URL(env.ITERMATE_TITLE_REMOTE_URL!); }
  catch { throw new Error("ITERMATE_TITLE_REMOTE_URL must be a valid HTTPS URL"); }
  if (url.protocol !== "https:" || url.username || url.password || url.search || url.hash) {
    throw new Error("Remote URL requires HTTPS without embedded credentials, query or fragment");
  }
  const model = env.ITERMATE_TITLE_REMOTE_MODEL!.trim();
  const key = env.ITERMATE_TITLE_REMOTE_API_KEY!.trim();
  if (/[\u0000-\u001f\u007f]/u.test(model) || /\s/u.test(key)) {
    throw new Error("Remote model or API key contains invalid whitespace/control characters");
  }
  return { url: url.href, model, key };
}

function completion(side: Side, remote: Remote, fetcher: Fetcher) {
  return async (_model: unknown, request: Request, options: Options) => {
    const messages = [{ role: "system", content: request.systemPrompt },
      ...request.messages.map(({ role, content }) => ({ role, content }))];
    const body = side === "remote"
      ? { model: remote.model, messages, stream: false, max_tokens: options.maxTokens }
      : { model: localModel, messages, stream: false, think: false,
          options: { num_predict: options.maxTokens, num_ctx: 32768, temperature: 0 }, keep_alive: "10m" };
    const response = await fetcher(side === "remote" ? remote.url : localURL, {
      method: "POST", redirect: "error", signal: options.signal,
      headers: side === "remote"
        ? { "Content-Type": "application/json", Authorization: `Bearer ${remote.key}` }
        : { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    if (!response.ok) throw new Error(`${side} title request returned HTTP ${response.status}`);
    const value = await response.json() as any;
    const text = side === "remote" ? value.choices?.[0]?.message?.content : value.message?.content;
    const stopped = side === "remote" ? value.choices?.[0]?.finish_reason === "stop"
      : value.model === localModel && value.done === true && value.done_reason === "stop" && !value.message?.thinking;
    if (!stopped || typeof text !== "string") throw new Error(`${side} title response is incomplete`);
    return { stopReason: "stop", content: [{ type: "text", text }] };
  };
}

function titleIssues(title: string): string[] {
  const issues: string[] = [];
  if (!title.trim()) issues.push("empty");
  if (title.length > 80) issues.push("over_80_utf16_units");
  if (/[\u0000-\u001f\u007f]/u.test(title)) issues.push("control_or_multiline");
  if (!/\p{Script=Han}/u.test(title)) issues.push("missing_chinese");
  if (/`|\*\*|__|^#{1,6}\s|^\s*[-*]\s|\[[^\]]+\]\(/u.test(title)) issues.push("markdown");
  if (/https?:\/\/|\/(?:Users|home|tmp|var|etc)\/|[A-Za-z]:\\/u.test(title)) issues.push("path_or_url");
  if (/^(?:已完成|等待确认|等待输入|进行中)[。！.!]?$/u.test(title)) issues.push("status_only");
  if (title.includes("SYNTHETIC_PRIVATE")) issues.push("private_marker");
  return issues;
}

async function compareTitles(fixture: typeof fixtures[number], remote: Remote, fetcher: Fetcher, signal = new AbortController().signal) {
  const excerpt = taskSummaryExcerpt(context(fixture.messages, "excerpt-only", async () => {
    throw new Error("Excerpt extraction must not call a model");
  }));
  const rows: { side: Side; title?: string; elapsedMs: number; issues: string[]; withinPreferred24?: boolean }[] = [];
  for (const side of ["remote", "local"] as const) {
    const ctx = context(fixture.messages, side === "remote" ? remote.model : localModel, completion(side, remote, fetcher));
    const started = performance.now();
    try {
      const title = await titleWithAdapter(ctx, excerpt, signal);
      if (title.includes(remote.key)) throw new Error("Credential echo must not enter diagnostics");
      rows.push({ side, title, elapsedMs: performance.now() - started,
        issues: titleIssues(title), withinPreferred24: title.length <= 24 });
    } catch {
      // Never persist the URL, API key, response body, or provider error text.
      rows.push({ side, elapsedMs: performance.now() - started, issues: ["generation_failed"] });
    }
  }
  return { caseId: fixture.id, rows };
}

const isolatedRemote = { url: "https://remote.example.test/v1/chat/completions", model: "isolated-remote", key: "SYNTHETIC_API_KEY" };
function modelResponse(side: Side, title: string) {
  return Response.json(side === "remote"
    ? { choices: [{ finish_reason: "stop", message: { role: "assistant", content: title } }] }
    : { model: localModel, done: true, done_reason: "stop", message: { role: "assistant", content: title } });
}

test("both model adapters use the production excerpt and identical title prompt without requiring equal titles", async () => {
  const requests: { url: string; init: RequestInit; body: any }[] = [];
  const fetcher: Fetcher = async (url, init) => {
    requests.push({ url, init, body: JSON.parse(String(init.body)) });
    return modelResponse(url === localURL ? "local" : "remote",
      url === localURL ? "修复文章列表翻页加载" : "修复文章列表分页");
  };
  const result = await compareTitles(fixtures[0], isolatedRemote, fetcher);
  assert.equal(requests.length, 2);
  assert.deepEqual(requests[0].body.messages, requests[1].body.messages);
  assert.match(requests[0].body.messages[0].content, /当前工作任务标题/);
  assert.match(requests[0].body.messages[1].content, /修复文章列表/);
  assert.deepEqual(Object.keys(requests[0].body.messages[1]).sort(), ["content", "role"]);
  assert.doesNotMatch(JSON.stringify(requests.map(r => r.body)), /SYNTHETIC_PRIVATE/);
  assert.equal(requests[0].body.model, isolatedRemote.model);
  assert.equal(requests[1].body.model, localModel);
  assert.equal(requests[0].body.max_tokens, 64);
  assert.equal(requests[1].body.options.num_predict, 64);
  assert.equal(requests[1].body.think, false);
  assert.equal(requests[0].init.redirect, "error");
  assert.equal(requests[1].init.redirect, "error");
  assert.ok(requests.every(r => r.init.signal instanceof AbortSignal));
  assert.equal(new Headers(requests[0].init.headers).get("Authorization"), `Bearer ${isolatedRemote.key}`);
  assert.equal(new Headers(requests[1].init.headers).has("Authorization"), false);
  assert.ok(result.rows.every(r => r.issues.length === 0 && r.elapsedMs >= 0));
  assert.notEqual(result.rows[0].title, result.rows[1].title);
});

test("goal changes and English requests retain the exact same visible input for both models", async () => {
  for (const fixture of fixtures.slice(1)) {
    const inputs: any[] = [];
    await compareTitles(fixture, isolatedRemote, async (url, init) => {
      inputs.push(JSON.parse(String(init.body)).messages);
      return modelResponse(url === localURL ? "local" : "remote", "定位当前会话任务问题");
    });
    assert.deepEqual(inputs[0], inputs[1]);
    if (fixture.id === "changed-goal") {
      assert.match(inputs[0][1].content, /改为定位登录后白屏/);
    } else {
      assert.match(inputs[0][1].content, /sidebar loses the selected session/);
    }
  }
});

test("the 24-character preference is soft while invalid title forms are reported", () => {
  assert.deepEqual(titleIssues("修".repeat(25)), []);
  for (const [title, issue] of [
    ["", "empty"], ["修".repeat(81), "over_80_utf16_units"],
    ["修复\n分页", "control_or_multiline"], ["Fix pagination", "missing_chinese"],
    ["**修复分页**", "markdown"], ["修复 /Users/example/project", "path_or_url"],
    ["等待确认", "status_only"], ["处理 SYNTHETIC_PRIVATE_TOOL", "private_marker"],
  ]) assert.ok(titleIssues(title).includes(issue), issue);
});

test("provider failures preserve both outcomes and never reveal credentials or raw errors", async () => {
  let calls = 0;
  const result = await compareTitles(fixtures[0], isolatedRemote, async (url) => {
    calls += 1;
    return new Response(`upstream error containing ${isolatedRemote.key}`, { status: url === localURL ? 503 : 401 });
  });
  assert.equal(calls, 2);
  assert.ok(result.rows.every(r => r.issues.includes("generation_failed")));
  assert.doesNotMatch(JSON.stringify(result), /SYNTHETIC_API_KEY|remote\.example|upstream error/);
});

test("title style issues remain diagnostics rather than generation failures", async () => {
  const result = await compareTitles(fixtures[0], isolatedRemote, async (url) =>
    modelResponse(url === localURL ? "local" : "remote", "修".repeat(81)));
  assert.ok(result.rows.every(row => row.title === "修".repeat(81)));
  assert.ok(result.rows.every(row => row.issues.includes("over_80_utf16_units")));
  assert.ok(result.rows.every(row => !row.issues.includes("generation_failed")));
});

test("a credential echoed in a successful response is never saved in diagnostics", async () => {
  const result = await compareTitles(fixtures[0], isolatedRemote, async (url) =>
    modelResponse(url === localURL ? "local" : "remote", `生成标题 ${isolatedRemote.key}`));
  assert.ok(result.rows.every(r => r.issues.includes("generation_failed")));
  assert.doesNotMatch(JSON.stringify(result), /SYNTHETIC_API_KEY/);
});

test("incomplete or thinking-only local responses cannot count as a valid title", async () => {
  for (const value of [
    { model: localModel, done: true, done_reason: "length", message: { content: "修复分页" } },
    { model: localModel, done: true, done_reason: "stop", message: { thinking: "private reasoning", content: "" } },
    { model: "another-model", done: true, done_reason: "stop", message: { content: "修复分页" } },
  ]) {
    const result = await compareTitles(fixtures[0], isolatedRemote, async (url) =>
      url === localURL ? Response.json(value) : modelResponse("remote", "修复分页"));
    assert.deepEqual(result.rows[0].issues, []);
    assert.deepEqual(result.rows[1].issues, ["generation_failed"]);
  }
});

test("an already cancelled comparison never calls either provider", async () => {
  const controller = new AbortController();
  controller.abort();
  let calls = 0;
  const result = await compareTitles(fixtures[0], isolatedRemote, async () => {
    calls += 1;
    throw new Error("A cancelled request must not fetch");
  }, controller.signal);
  assert.equal(calls, 0);
  assert.ok(result.rows.every(r => r.issues.includes("generation_failed")));
});

test("live comparison is opt-in and validates complete explicit remote configuration", () => {
  assert.equal(liveConfiguration({}), undefined);
  assert.equal(liveConfiguration({ ITERMATE_TITLE_REMOTE_API_KEY: "unused" }), undefined);
  const env = { ITERMATE_TITLE_COMPARE_LIVE: "1", ITERMATE_TITLE_REMOTE_URL: isolatedRemote.url,
    ITERMATE_TITLE_REMOTE_MODEL: isolatedRemote.model, ITERMATE_TITLE_REMOTE_API_KEY: isolatedRemote.key };
  assert.deepEqual(liveConfiguration(env), isolatedRemote);
  for (const name of ["ITERMATE_TITLE_REMOTE_URL", "ITERMATE_TITLE_REMOTE_MODEL", "ITERMATE_TITLE_REMOTE_API_KEY"]) {
    assert.throws(() => liveConfiguration({ ...env, [name]: "" }), /Missing ITERMATE_TITLE_REMOTE/);
  }
  for (const url of ["not a URL", "http://remote.example.test", "https://user:password@remote.example.test",
    "https://remote.example.test?key=secret", "https://remote.example.test#secret"]) {
    assert.throws(() => liveConfiguration({ ...env, ITERMATE_TITLE_REMOTE_URL: url }));
  }
});

// Local-only live probe: uses the production prompt, but never remote configuration or real sessions.
test("live local 2B title generation", {
  skip: process.env.ITERMATE_TITLE_LOCAL_LIVE !== "1",
}, async (t) => {
  const focusChecks = [
    /分页|下一页|翻页/u,
    /登录.*白屏|白屏.*登录/u,
    /侧边栏|侧栏/u,
  ];
  const rows = [];
  for (const [index, fixture] of fixtures.entries()) {
    const excerpt = taskSummaryExcerpt(context(fixture.messages, "excerpt-only", async () => {
      throw new Error("Excerpt extraction must not call a model");
    }));
    let rawTitle: string | undefined;
    const localFetch: Fetcher = async (url, init) => {
      assert.equal(url, localURL);
      assert.equal(new Headers(init.headers).has("Authorization"), false);
      const response = await fetch(url, init);
      if (response.ok) rawTitle = (await response.clone().json() as any).message?.content;
      return response;
    };
    const ctx = context(fixture.messages, localModel, completion("local", isolatedRemote, localFetch));
    const started = performance.now();
    let title: string | undefined;
    let issues: string[];
    try {
      title = await titleWithAdapter(ctx, excerpt, new AbortController().signal);
      issues = [...new Set([...titleIssues(title), ...titleIssues(rawTitle ?? "")])];
      if (!focusChecks[index].test(title)) issues.push("missing_current_goal");
      if (fixture.id === "changed-goal" && /点赞/u.test(title)) issues.push("stale_goal");
    } catch {
      issues = ["generation_failed"];
    }
    const row = { caseId: fixture.id, model: localModel, input: excerpt, rawTitle, title,
      elapsedMs: performance.now() - started, issues,
      withinPreferred24: title !== undefined && title.length <= 24 };
    rows.push(row);
    t.diagnostic(JSON.stringify(row));
  }
  assert.ok(rows.every(row => row.issues.length === 0),
    "At least one local title failed generation, raw/normalized format checks, or current-goal matching");
});

test("live remote versus local 2B session-title comparison", {
  skip: process.env.ITERMATE_TITLE_COMPARE_LIVE !== "1",
}, async (t) => {
  const remote = liveConfiguration(process.env);
  assert.ok(remote);
  const comparisons = [];
  for (const fixture of fixtures) {
    const result = await compareTitles(fixture, remote, fetch);
    comparisons.push(result);
    t.diagnostic(JSON.stringify(result));
  }
  assert.ok(comparisons.every(c => c.rows.every(r => r.issues.length === 0)),
    "At least one title failed generation or structural checks; inspect the comparison diagnostics");
});
