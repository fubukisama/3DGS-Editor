# 3DGS Editor v0.1.5

## Changes

- Packages the 36.9.13 source update into a refreshed Windows x64 archive.
- Fixes stale training jobs that remained stuck in cancelling after app restart.
- Hides cancelled training history from the active Job Center list.
- Improves 3DGS PSNR analysis stability by using Python SH evaluation and finite-value checks.

## Notes

- Close and reopen the editor after updating so the packaged backend reloads the new job cleanup logic.
