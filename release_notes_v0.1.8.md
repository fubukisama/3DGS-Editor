# 3DGS Editor v0.1.8

## Changes

- Prevents right-button and middle-button pan gestures from running zoom updates.
- Ignores wheel-style events while a mouse drag is active, avoiding accidental zoom during vertical right-drag panning.
- Keeps normal wheel zoom enabled when no mouse button is held.

## Notes

- Restart the editor after updating so the patched control module is reloaded.
