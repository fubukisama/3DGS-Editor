import test from "node:test";
import assert from "node:assert/strict";

import { createGpuRenderTimer } from "../static/gpu-render-timer.mjs";

function createWebGl2Mock({ elapsedNanoseconds = 4_000_000, disjoint = false } = {}) {
  const extension = { TIME_ELAPSED_EXT: 100, GPU_DISJOINT_EXT: 101 };
  const deleted = [];
  let active = null;
  return {
    QUERY_RESULT_AVAILABLE: 102,
    QUERY_RESULT: 103,
    deleted,
    getExtension(name) {
      return name === "EXT_disjoint_timer_query_webgl2" ? extension : null;
    },
    createQuery() {
      return {};
    },
    beginQuery(_target, query) {
      active = query;
    },
    endQuery() {
      active = null;
    },
    getParameter(parameter) {
      return parameter === extension.GPU_DISJOINT_EXT ? disjoint : null;
    },
    getQueryParameter(_query, parameter) {
      if (parameter === this.QUERY_RESULT_AVAILABLE) return true;
      if (parameter === this.QUERY_RESULT) return elapsedNanoseconds;
      return null;
    },
    deleteQuery(query) {
      deleted.push(query);
    },
  };
}

test("GPU render timer reports asynchronous WebGL2 elapsed time", () => {
  const gl = createWebGl2Mock({ elapsedNanoseconds: 6_250_000 });
  const timer = createGpuRenderTimer(gl);

  assert.equal(timer.supported(), true);
  assert.equal(timer.begin(), true);
  assert.equal(timer.end(), true);
  assert.equal(timer.poll(), 6.25);
  assert.equal(gl.deleted.length, 1);
});

test("GPU render timer drops invalid samples when the GPU is disjoint", () => {
  const gl = createWebGl2Mock({ disjoint: true });
  const timer = createGpuRenderTimer(gl);

  timer.begin();
  timer.end();

  assert.equal(timer.poll(), null);
  assert.equal(gl.deleted.length, 1);
});

test("GPU render timer reports unsupported contexts without throwing", () => {
  const timer = createGpuRenderTimer({ getExtension: () => null });

  assert.equal(timer.supported(), false);
  assert.equal(timer.begin(), false);
  assert.equal(timer.poll(), null);
});
