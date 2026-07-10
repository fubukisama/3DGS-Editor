const DEFAULT_SMOOTHING_FRAMES = 60;

// SIBR FPSCounter-style rolling average, fed with completed render-work durations.
export function createFpsMeter({
  smoothingFrames = DEFAULT_SMOOTHING_FRAMES,
  minSamples = 5,
} = {}) {
  const capacity = Math.max(1, Math.floor(Number(smoothingFrames) || DEFAULT_SMOOTHING_FRAMES));
  const requiredSamples = Math.min(capacity, Math.max(1, Math.floor(Number(minSamples) || 1)));
  const frameTimes = new Float64Array(capacity);
  let frameIndex = 0;
  let sampleCount = 0;
  let frameTimeSum = 0;
  let fps = 0;
  let averageFrameTimeMs = 0;

  return {
    recordFrame(frameTimeMs) {
      const duration = Number(frameTimeMs);
      if (!Number.isFinite(duration) || duration <= 0) return this.metrics();

      if (sampleCount === capacity) {
        frameTimeSum -= frameTimes[frameIndex];
      } else {
        sampleCount += 1;
      }
      frameTimes[frameIndex] = duration;
      frameTimeSum += duration;
      frameIndex = (frameIndex + 1) % capacity;

      averageFrameTimeMs = frameTimeSum / sampleCount;
      fps = sampleCount >= requiredSamples ? 1000 / averageFrameTimeMs : 0;
      return this.metrics();
    },
    metrics() {
      return { fps, frameTimeMs: averageFrameTimeMs, samples: sampleCount };
    },
    value() {
      return fps;
    },
    reset() {
      frameTimes.fill(0);
      frameIndex = 0;
      sampleCount = 0;
      frameTimeSum = 0;
      fps = 0;
      averageFrameTimeMs = 0;
    },
  };
}
