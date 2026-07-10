# Gaussian Scene Workbench 0.2.1

Updated: 2026-07-10

- Replace the display-refresh counter with a SIBR-style 60-frame rolling render-performance average.
- Use asynchronous WebGL GPU timer queries when supported, with CPU render timing as a fallback.
- Show both effective FPS and average frame time in milliseconds.
- Keep the meter at `FPS --` until a Gaussian or mesh model is actually visible.
- Prevent empty scenes and browser refresh callbacks from producing misleading FPS values.
- Add GPU timer, rolling-window, warmup, invalid-sample, and reset test coverage.
- Add SIBR/Inria source attribution to the third-party notices.

Package SHA256 is published as a separate `.sha256` Release asset.
