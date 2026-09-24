import assert from "node:assert/strict";
import { test } from "node:test";
import { modelReplyDecision, needsReply } from "./iTermate-integration";

function modelAnswers(choice: string, probability: unknown, noul: unknown) {
  return {
    state: { type: "choice", choice, probabilities: { [choice]: probability } },
    needs_reply: { type: "noul", noul },
  };
}

test("confident model decisions take precedence in both directions", () => {
  const positive = modelReplyDecision(modelAnswers("awaitingInput", 0.95, 0.8));
  const negative = modelReplyDecision(modelAnswers("idle", 0.95, 0.1));
  assert.equal(positive, true);
  assert.equal(negative, false);
  assert.equal(positive ?? needsReply("Which option do you prefer?"), true);
  assert.equal(negative ?? needsReply("Please confirm before I proceed."), false);
});

test("uncertain or malformed model output falls back instead of becoming false", () => {
  for (const answer of [
    undefined, null, {},
    modelAnswers("unknown", 0.99, 0.1),
    modelAnswers("running", 0.99, 0.1),
    modelAnswers("awaitingInput", 0.5, 0.8),
    modelAnswers("awaitingInput", 0.95, 0.2),
    modelAnswers("idle", 0.95, 0.8),
    modelAnswers("idle", NaN, 0.1),
    modelAnswers("idle", 1.1, 0.1),
    modelAnswers("idle", 0.95, -0.1),
    modelAnswers("idle", "0.95", 0.1),
    { state: { choice: "idle", probabilities: { idle: 0.99 } }, needs_reply: { noul: 0 } },
  ]) {
    const result = modelReplyDecision(answer);
    assert.equal(result, undefined);
    assert.equal(result ?? needsReply("Please confirm before I proceed."), true);
    assert.equal(result ?? needsReply("Work is complete."), false);
  }
});

test("recognizes explicit confirmation gates", () => {
  assert.equal(needsReply("这是否准确表达你的目标？确认后开始检查和提交。"), true);
  assert.equal(needsReply("Please confirm the configuration before I proceed."), true);
});

test("recognizes short action-scoped approval questions without a separate waiting clause", () => {
  for (const text of [
    "按这个范围实现，可以吗？",
    "按上述方案继续执行，可以吗？",
    "按以上计划开始，好吗？",
    "这样修改可以吗？",
    "这么处理，行吗？",
    "**Task Target**\n\n- **目标**：增加辅助语义标签。\n- **边界**：不改变完成统计，不自动批准操作。\n\n按这个范围实现，可以吗？",
  ]) assert.equal(needsReply(text), true, text);
  for (const text of [
    "示例：按这个范围实现，可以吗？",
    "> 按这个范围实现，可以吗？",
    "```text\n按这个范围实现，可以吗？\n```",
    "按这个范围实现，可以吗？不需要回复。",
    "这样理解可以吗？",
  ]) assert.equal(needsReply(text), false, text);
});

test("recognizes approval, selection, and clarification gates", () => {
  for (const text of [
    "请批准这个方案，批准后我再开始执行。",
    "请授权这次操作，收到你的授权再执行。",
    "请告知你的决定，等待你的答复。",
    "请告诉我目标平台，收到你的回复再继续。",
    "Please let me know your choice. Awaiting your decision.",
    "Could you tell me the target platform? Waiting for your input.",
    "请选定一个方案，选定后继续进行。",
    "你更偏好哪个方案？等待你的选择。",
    "请补充目标平台，等你提供后继续。",
    "请确认目标，收到你的确认再开始。",
    "请确认目标，确认之前不会继续执行。",
    "Please approve this change. Awaiting your approval.",
    "Could you authorize this operation? Once you authorize it, I will proceed.",
    "Please pick an option. Waiting for your choice.",
    "Please clarify the target platform before I can proceed.",
    "Please specify the directory. I cannot proceed without your input.",
    "Which option do you prefer? Waiting for your decision.",
    "What would you like to use? Awaiting your response.",
    "May I proceed with this change? Waiting for your authorization.",
    "Please answer the question. I can't continue until you reply.",
    "Please confirm the scope before we continue.",
  ]) {
    assert.equal(needsReply(text), true, text);
  }
});

test("rejects negated waiting in both languages", () => {
  for (const text of [
    "Please confirm the configuration. I am not waiting for your reply.",
    "Please confirm the configuration. I will not wait for your reply.",
    "请确认配置是否正确。我不会等待你的回复，会直接继续执行。",
    "请确认配置是否正确，不用等待你的回复。",
    "Please approve the change. I am not awaiting your approval.",
    "Please specify the directory. No input is required before I proceed.",
    "Please confirm the scope. No response needed before I continue.",
    "请批准方案，我不会等候你的批准，批准后开始执行只是旧流程。",
    "Please approve the change. I won't await your approval.",
  ]) {
    assert.equal(needsReply(text), false, text);
  }
});

test("does not treat examples, code, or optional offers as blocking questions", () => {
  for (const text of [
    "> 请确认配置，确认后开始执行。",
    "```text\n请确认配置，确认后开始执行。\n```",
    "例如：请确认配置，确认后开始执行。",
    "如果需要，我可以继续。请确认后再开始。",
    "是否要继续？",
    "The configuration is complete.",
    "Please approve the change whenever convenient.",
    "Which option do you prefer?",
    "May I proceed?",
    "请授权这次操作。",
    "请补充说明（如有需要）。补充后继续。",
    "Example: Please approve the change before I proceed.",
    "If you like, please clarify the platform before I proceed.",
    "No need to reply. Please approve the change before I proceed.",
    "> Please approve the change. Awaiting your approval.",
    "    请授权操作，授权后继续执行。",
    "~~~text\nPlease approve the change before I proceed.\n~~~",
    "```text\nPlease approve the change before I proceed.",
    "`Please approve the change before I proceed.`",
    "“请授权操作，授权后继续执行。”",
    "Suggested wording: \"Please approve the change before I proceed.\"",
    "我们对这份 RFC 的写法已对齐：\n\n- 读者：熟悉短篇阅读容器的客户端同事。\n- 目的：评审模块设计与接入方案是否合理。\n\n建议正文结构：\n\n1. 背景与目标。\n2. 模块结构。\n3. 待确认事项：集中保留会影响模块或 API 的问题，并给出建议行为。",
  ]) {
    assert.equal(needsReply(text), false, text);
  }
});
