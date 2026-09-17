import assert from "node:assert/strict";
import { test } from "node:test";
import { needsReply } from "./iTermate-integration";

test("recognizes explicit confirmation gates", () => {
  assert.equal(needsReply("这是否准确表达你的目标？确认后开始检查和提交。"), true);
  assert.equal(needsReply("Please confirm the configuration before I proceed."), true);
});

test("rejects negated waiting in both languages", () => {
  for (const text of [
    "Please confirm the configuration. I am not waiting for your reply.",
    "Please confirm the configuration. I will not wait for your reply.",
    "请确认配置是否正确。我不会等待你的回复，会直接继续执行。",
    "请确认配置是否正确，不用等待你的回复。",
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
  ]) {
    assert.equal(needsReply(text), false, text);
  }
});
