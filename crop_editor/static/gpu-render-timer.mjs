export function createGpuRenderTimer(gl, { maxPendingQueries = 8 } = {}) {
  const webgl2Extension = gl?.getExtension?.("EXT_disjoint_timer_query_webgl2") || null;
  const webgl1Extension = webgl2Extension ? null : gl?.getExtension?.("EXT_disjoint_timer_query") || null;
  const extension = webgl2Extension || webgl1Extension;
  const pending = [];
  let activeQuery = null;

  const isWebGl2 = Boolean(webgl2Extension);
  const supported = Boolean(extension);
  const capacity = Math.max(1, Math.floor(Number(maxPendingQueries) || 8));

  function deleteQuery(query) {
    if (!query) return;
    if (isWebGl2) gl.deleteQuery(query);
    else extension.deleteQueryEXT(query);
  }

  function clearPending() {
    while (pending.length) deleteQuery(pending.shift());
  }

  return {
    supported() {
      return supported;
    },
    begin() {
      if (!supported || activeQuery || pending.length >= capacity) return false;
      activeQuery = isWebGl2 ? gl.createQuery() : extension.createQueryEXT();
      if (!activeQuery) return false;
      if (isWebGl2) gl.beginQuery(extension.TIME_ELAPSED_EXT, activeQuery);
      else extension.beginQueryEXT(extension.TIME_ELAPSED_EXT, activeQuery);
      return true;
    },
    end() {
      if (!supported || !activeQuery) return false;
      if (isWebGl2) gl.endQuery(extension.TIME_ELAPSED_EXT);
      else extension.endQueryEXT(extension.TIME_ELAPSED_EXT);
      pending.push(activeQuery);
      activeQuery = null;
      return true;
    },
    poll() {
      if (!supported || !pending.length) return null;
      if (gl.getParameter(extension.GPU_DISJOINT_EXT)) {
        clearPending();
        return null;
      }
      const query = pending[0];
      const available = isWebGl2
        ? gl.getQueryParameter(query, gl.QUERY_RESULT_AVAILABLE)
        : extension.getQueryObjectEXT(query, extension.QUERY_RESULT_AVAILABLE_EXT);
      if (!available) return null;
      const elapsedNanoseconds = isWebGl2
        ? gl.getQueryParameter(query, gl.QUERY_RESULT)
        : extension.getQueryObjectEXT(query, extension.QUERY_RESULT_EXT);
      pending.shift();
      deleteQuery(query);
      const elapsedMs = Number(elapsedNanoseconds) / 1e6;
      return Number.isFinite(elapsedMs) && elapsedMs > 0 ? elapsedMs : null;
    },
    reset() {
      clearPending();
    },
    dispose() {
      if (activeQuery) {
        deleteQuery(activeQuery);
        activeQuery = null;
      }
      clearPending();
    },
  };
}
