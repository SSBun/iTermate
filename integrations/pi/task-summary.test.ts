import assert from "node:assert/strict";
import { test } from "node:test";
import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
import { fillsMissingTitles, isValidTaskTitle, localQuestionDecision, summarizeTask, taskSummaryExcerpt } from "./iTermate-integration";

test("missing title preference defaults on, honors false, and rejects invalid configuration", () => {
  const configuration = { model: "qwen3.5:2b", revision: "11111111-1111-1111-1111-111111111111" };
  assert.equal(fillsMissingTitles(null), true);
  assert.equal(fillsMissingTitles(JSON.stringify(configuration)), true);
  assert.equal(fillsMissingTitles(JSON.stringify({ ...configuration, autoFillMissingTitles: false })), false);
  assert.equal(fillsMissingTitles(JSON.stringify({ ...configuration, autoFillMissingTitles: true })), true);
  assert.equal(fillsMissingTitles(JSON.stringify({ ...configuration, autoFillMissingTitles: "false" })), false);
  assert.equal(fillsMissingTitles("not JSON"), false);
});

function context(messages: unknown[]) {
  return {
    model: undefined,
    sessionManager: { buildSessionProjection: () => ({ messages }) },
    modelRegistry: { complete: async () => { throw new Error("Pi model must not generate task titles"); } },
  } as unknown as ExtensionContext;
}

test("local task titles use only visible text and need no selected Pi model", async () => {
  const ctx = context([
    { role: "system", content: "private system" },
    { role: "user", content: [{ type: "text", text: "修复分页" }, { type: "image", data: "private image" }] },
    { role: "assistant", content: [{ type: "thinking", thinking: "private reasoning" }, { type: "text", text: "正在检查分页边界" }] },
    { role: "toolResult", content: "private tool result" },
  ]);
  const title = await summarizeTask(ctx, taskSummaryExcerpt(ctx), new AbortController().signal,
    async (prompt, text, signal, maxTokens) => {
      assert.match(prompt, /当前工作任务标题/);
      assert.match(prompt, /十六个元素/);
      assert.match(prompt, /不摘录原句/);
      assert.match(prompt, /用户仅说确认或继续时/);
      assert.match(prompt, /不要Markdown、标签/);
      assert.match(prompt, /标题：优化会话切换/);
      assert.match(prompt, /标题：修复会话刷新/);
      assert.match(text, /修复分页/);
      assert.doesNotMatch(text, /private/);
      assert.ok(signal instanceof AbortSignal);
      assert.equal(maxTokens, 64);
      return "修复分页";
    });
  assert.equal(title, "修复分页");
});

test("titles must be nonblank single lines within eighty Unicode scalars", () => {
  for (const title of ["修复分页", "字".repeat(80), "🔔".repeat(80), "修复HTTP429重试",
    "修复分页。", " 修复分页 ", "控制 Tab 切换会话跳过 Codex 故障"]) {
    assert.equal(isValidTaskTitle(title), true, title);
  }
  for (const title of ["", " \t", "字".repeat(81), "🔔".repeat(81),
    ...["\n", "\r", "\r\n", "\v", "\f", "\u0085", "\u2028", "\u2029"].map(line => `修复${line}分页`),
    "修复分页\n", undefined, null, 42, {}]) {
    assert.equal(isValidTaskTitle(title), false);
  }
});

test("valid single-line titles retain their original text without a second call", async () => {
  let calls = 0;
  const title = " 修复 HTTP429 重试。";
  assert.equal(await summarizeTask(context([]), "Goal", new AbortController().signal, async () => {
    calls += 1;
    return title;
  }), title);
  assert.equal(calls, 1);
});

test("invalid drafts are summarized once more with the original conversation", async () => {
  for (const draft of ["", " \t", "字".repeat(81), "1. 终端界面重构\n2. 调整项目布局", "修复分页\n"]) {
    let calls = 0;
    const title = await summarizeTask(context([]), "修复标题截断", new AbortController().signal,
      async (prompt, text, _signal, maxTokens) => {
        calls += 1;
        assert.equal(maxTokens, 64);
        if (calls === 1) return draft;
        assert.match(prompt, /单行/);
        assert.match(text, /修复标题截断/);
        assert.ok(text.includes(draft));
        return "修复标题截断";
      });
    assert.equal(title, "修复标题截断");
    assert.equal(calls, 2);
  }
});

test("a second invalid title fails without a third call or mechanical truncation", async () => {
  for (const draft of ["", "字".repeat(81), "修复\n标题"]) {
    let calls = 0;
    await assert.rejects(summarizeTask(context([]), "Goal", new AbortController().signal, async () => {
      calls += 1;
      return draft;
    }));
    assert.equal(calls, 2);
  }
});

test("cancellation during refinement cannot publish the second result", async () => {
  const controller = new AbortController();
  let calls = 0;
  await assert.rejects(summarizeTask(context([]), "Goal", controller.signal, async () => {
    calls += 1;
    if (calls === 1) return "多行\n草稿";
    controller.abort();
    return "修复标题";
  }));
  assert.equal(calls, 2);
});

test("question labels accept only the exact local binary JSON protocol", () => {
  assert.equal(localQuestionDecision('{"label":"question"}'), true);
  assert.equal(localQuestionDecision('{"label":"normal"}'), false);
  for (const text of ['{"label":"unknown"}', '{"label":"normal","confidence":1}', '[]', 'null', 'normal']) {
    assert.equal(localQuestionDecision(text), undefined);
  }
});

test("excerpt bounds messages while retaining the latest user goal", () => {
  const messages = Array.from({ length: 20 }, (_, index) => ({
    role: index % 2 ? "assistant" : "user", content: `START-${index}:` + "x".repeat(30000) + `:END-${index}`,
  }));
  const excerpt = taskSummaryExcerpt(context(messages));
  assert.doesNotMatch(excerpt, /START-11:/);
  assert.match(excerpt, /START-12:/);
  assert.match(excerpt, /:END-19$/);
  assert.ok(excerpt.length < 16200);
  assert.match(taskSummaryExcerpt(context([
    { role: "user", content: "修复分页" },
    ...Array.from({ length: 20 }, () => ({ role: "assistant", content: "正在检查" })),
  ])), /修复分页/);
});

test("empty input and prior cancellation never invoke a model", async () => {
  let calls = 0;
  const generate = async () => { calls += 1; return "修复分页"; };
  await assert.rejects(summarizeTask(context([]), " ", new AbortController().signal, generate));
  const controller = new AbortController();
  controller.abort();
  await assert.rejects(summarizeTask(context([]), "Goal", controller.signal, generate));
  assert.equal(calls, 0);
});

test("empty output, late cancellation and provider errors cannot publish a title", async () => {
  for (const title of ["", " \n\t"]) {
    await assert.rejects(summarizeTask(context([]), "Goal", new AbortController().signal, async () => title));
  }
  const controller = new AbortController();
  await assert.rejects(summarizeTask(context([]), "Goal", controller.signal, async () => {
    controller.abort();
    return "修复分页";
  }));
  await assert.rejects(summarizeTask(context([]), "Goal", new AbortController().signal, async () => {
    throw new Error("SYNTHETIC_PRIVATE_PROVIDER_ERROR");
  }), error => !String(error).includes("SYNTHETIC_PRIVATE"));
});
