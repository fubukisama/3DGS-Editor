# Third-Party Licenses

Gaussian Scene Workbench is distributed for open-source research, learning, and evaluation use. The repository includes third-party components with their own licenses. The root MIT terms apply only to original Gaussian Scene Workbench code and do not override these third-party licenses.

## SIBR FPSCounter Design Reference

The render-performance meter is a JavaScript adaptation of the rolling frame-time design used by SIBR's `FPSCounter` (Inria GRAPHDECO). No SIBR binaries are bundled. The reference implementation is distributed for non-commercial research and evaluation use: https://gitlab.inria.fr/sibr/sibr_core/-/blob/gaussian_code_release_union/src/core/view/FPSCounter.cpp

## Key License Constraints

- `gaussian-splatting/`: Gaussian-Splatting License. This license limits use to non-commercial research and evaluation purposes unless separate permission is obtained from the original licensors.
- `gaussian-splatting/submodules/diff-gaussian-rasterization/`: Gaussian-Splatting License.
- `gaussian-splatting/submodules/simple-knn/`: Gaussian-Splatting License.
- `gaussian-splatting/SIBR_viewers/`: Apache License 2.0, except for subdirectories that state a different license.
- `gaussian-splatting/submodules/fused-ssim/`: MIT License.

## Practical Meaning

You may use this repository for research, learning, experiments, and evaluation, subject to the included licenses.

Do not assume the full repository is available for commercial use under MIT. Commercial use of the bundled Gaussian Splatting components requires permission from the original licensors.

## Included License Files

- `LICENSE`
- `gaussian-splatting/LICENSE.md`
- `gaussian-splatting/submodules/diff-gaussian-rasterization/LICENSE.md`
- `gaussian-splatting/submodules/simple-knn/LICENSE.md`
- `gaussian-splatting/SIBR_viewers/LICENSE.md`
- `gaussian-splatting/submodules/fused-ssim/LICENSE`
