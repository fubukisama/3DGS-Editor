# Gaussian Scene Workbench 0.2.13

## English

- Upgrades the desktop runtime from Electron 36 to Electron 43.1.1 and Electron Packager 20.0.3.
- Builds releases in an isolated temporary workspace, so packaging cannot replace files used by a running editor or 2DGS training task.
- Requires Node.js 22.12 or newer for release builds and uses reproducible `npm ci` installs from the lockfile.
- Adds desktop toolchain and isolated-packaging regression tests.
- Updates the source version to `36.10.13` and the package version to `0.2.13`.

## 中文

- 桌面运行时从 Electron 36 升级至 Electron 43.1.1，Electron Packager 升级至 20.0.3。
- 发布封装改为独立临时工作区，封装时不会替换正在运行的编辑器或 2DGS 训练任务所使用的文件。
- 发布构建要求 Node.js 22.12 或更高版本，并通过锁文件和 `npm ci` 进行可复现安装。
- 新增桌面工具链版本与隔离封装的防回归测试。
- 源码版本更新至 `36.10.13`，封装版本更新至 `0.2.13`。

## 日本語

- デスクトップランタイムを Electron 36 から Electron 43.1.1 へ、Electron Packager を 20.0.3 へ更新しました。
- リリース作成を隔離された一時ワークスペースで行い、実行中のエディターや 2DGS 学習が使用するファイルを置き換えないようにしました。
- リリースビルドには Node.js 22.12 以降を要求し、ロックファイルと `npm ci` による再現可能なインストールを使用します。
- デスクトップツールチェーンと隔離パッケージングの回帰テストを追加しました。
- ソースバージョンを `36.10.13`、パッケージバージョンを `0.2.13` に更新しました。
