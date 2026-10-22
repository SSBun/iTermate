// Offline checks: tsx --test integrations/pi/reply-classification.test.ts
// Real selected local model: ITERMATE_REPLY_CLASSIFICATION_LIVE=1 tsx --test integrations/pi/reply-classification.test.ts
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { classifyReplyWithModel } from "./iTermate-integration";

type ReplyCase = { id: string; expected: "normal" | "question"; text: string };
const cases: ReplyCase[] = JSON.parse(readFileSync(new URL("./reply-classification-cases.json", import.meta.url), "utf8"));

test("reply regression cases have unique identities and fit the production input boundary", () => {
  assert.equal(cases.length, 22);
  assert.equal(new Set(cases.map(row => row.id)).size, cases.length);
  for (const row of cases) {
    assert.ok(["normal", "question"].includes(row.expected), row.id);
    assert.ok(typeof row.text === "string" && row.text.trim() && row.text.length <= 3000, row.id);
  }
  assert.equal(cases.find(row => row.id === "local-commit-report")?.expected, "normal");
  assert.equal(cases.find(row => row.id === "commit-awaiting-push-approval")?.expected, "question");
});

// No injected labels or HTTP mocks: malformed/unavailable/late results fail, never become a passing normal.
// Sequential subtests avoid concurrent model loading. Production configuration and identity checks remain active.
test("production reply classifier matches every regression case on the selected local model", {
  skip: process.env.ITERMATE_REPLY_CLASSIFICATION_LIVE !== "1",
  timeout: 240000,
}, async (t) => {
  for (const row of cases) {
    await t.test(`${row.id}: ${row.expected}`, async () => {
      assert.equal(await classifyReplyWithModel(row.text), row.expected === "question", row.id);
    });
  }
});
