test("proactive probe: acknowledged idle is not periodically republished", async () => {
  const h = await harness({ count: 0 });
  await h.emit("session_start");
  await h.advance(0);
  assert.equal(h.reports.at(-1).status, "idle");
  const sent = h.reports.length;
  await h.advance(20000);
  assert.equal(h.reports.length, sent);
  await h.emit("session_shutdown");
});

test("proactive probe: acknowledged finished is not periodically republished", async () => {
  const h = await settledHarness({ count: 0 });
  assert.equal(h.reports.at(-1).status, "finished");
  const sent = h.reports.length;
  await h.advance(20000);
  assert.equal(h.reports.length, sent);
  await h.emit("session_shutdown");
});

test("proactive probe: running continues reporting while the parent is active", async () => {
  const h = await harness({ count: 0 });
  await h.emit("session_start");
  await h.advance(0);
  await h.emit("agent_start");
  const sent = h.reports.length;
  await h.advance(12000);
  const renewed = h.reports.slice(sent);
  assert.ok(renewed.length >= 5);
  assert.ok(renewed.every(report => report.status === "running" && report.heartbeat === true));
  await h.emit("session_shutdown");
});
