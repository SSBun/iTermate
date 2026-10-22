import assert from "node:assert/strict";
import { test } from "node:test";
import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
import { isValidTaskTitle, localQuestionDecision, summarizeTask, taskSummaryExcerpt, taskTitleElements } from "./iTermate-integration";

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
      assert.match(text, /修复分页/);
      assert.doesNotMatch(text, /private/);
      assert.ok(signal instanceof AbortSignal);
      assert.equal(maxTokens, 64);
      return "修复分页";
    });
  assert.equal(title, "修复分页");
});

test("title validation counts technical words once and never repairs invalid output", () => {
  assert.equal(taskTitleElements("修复HTTP重试").length, 5);
  for (const title of ["修复分页", "排查macOS侧边栏", "字".repeat(16), "𠮷".repeat(15) + "AVCaptureSession"]) {
    assert.equal(isValidTaskTitle(title), true, title);
  }
  for (const title of ["", "字".repeat(17), "字".repeat(16) + "HTTP", "HTTP",
    "修复HTTP429重试", "修复，分页", "修复分页。", " 修复分页", "修复 分页", "修复分页\n",
    "修复分页\u0000", "修复🔔", "已完成", '"修复分页"']) {
    assert.equal(isValidTaskTitle(title), false, title);
  }
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

test("invalid output, late cancellation and provider errors cannot publish a title", async () => {
  for (const title of ["修复\n分页", "修复HTTP429重试", "字".repeat(17)]) {
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
