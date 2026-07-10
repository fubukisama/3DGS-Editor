import test from "node:test";
import assert from "node:assert/strict";

import { createFpsMeter } from "../static/fps-meter.mjs";

test("fps meter reports SIBR-style average render throughput", () => {
  const meter = createFpsMeter({ smoothingFrames: 3, minSamples: 3 });

  meter.recordFrame(10);
  meter.recordFrame(10);
  const metrics = meter.recordFrame(20);

  assert.equal(metrics.samples, 3);
  assert.ok(Math.abs(metrics.frameTimeMs - 40 / 3) < 1e-9);
  assert.ok(Math.abs(metrics.fps - 75) < 1e-9);
});

test("fps meter keeps a rolling window of completed render durations", () => {
  const meter = createFpsMeter({ smoothingFrames: 3, minSamples: 1 });

  meter.recordFrame(10);
  meter.recordFrame(10);
  meter.recordFrame(20);
  const metrics = meter.recordFrame(20);

  assert.ok(Math.abs(metrics.frameTimeMs - 50 / 3) < 1e-9);
  assert.ok(Math.abs(metrics.fps - 60) < 1e-9);
});

test("fps meter waits for the configured warmup samples", () => {
  const meter = createFpsMeter({ smoothingFrames: 60, minSamples: 5 });

  for (let i = 0; i < 4; i++) meter.recordFrame(4);

  assert.equal(meter.value(), 0);
  assert.equal(meter.recordFrame(4).fps, 250);
});

test("fps meter ignores invalid render durations", () => {
  const meter = createFpsMeter({ smoothingFrames: 60, minSamples: 1 });

  meter.recordFrame(Number.NaN);
  meter.recordFrame(0);

  assert.deepEqual(meter.metrics(), { fps: 0, frameTimeMs: 0, samples: 0 });
});

test("fps meter can reset when no model is being rendered", () => {
  const meter = createFpsMeter({ smoothingFrames: 3, minSamples: 1 });

  meter.recordFrame(5);
  meter.reset();

  assert.deepEqual(meter.metrics(), { fps: 0, frameTimeMs: 0, samples: 0 });
});
