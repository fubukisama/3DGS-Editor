# Gaussian Scene Workbench 0.2.9

## English

- Strictly separates GS2Mesh and SuGaR source trees, Python environments, `PATH`, and `PYTHONPATH`.
- Rejects configurations that point GS2Mesh and SuGaR at the same source directory or Python runtime.
- Adds a GS2Mesh preflight that verifies its dedicated Torch, OpenCV, Open3D, Matplotlib, rasterizer, and KNN modules before mesh extraction starts.
- Resolves GS2Mesh, SuGaR, OpenMVS, and 2DGS from explicit environment overrides, packaged folders, or the active workspace without device-specific paths.
- Removes local user and desktop paths from launch, OpenMVS setup, environment-check, and helper scripts.
- Verified the dedicated GS2Mesh `run_single.py` runtime on the current workstation; all Python, web UI, and desktop-shell tests pass.
- Updates the source version to `36.10.9` and the package version to `0.2.9`.

## 中文

- 严格分离 GS2Mesh 与 SuGaR 的源码目录、Python 环境、`PATH` 和 `PYTHONPATH`。
- 当 GS2Mesh 与 SuGaR 指向同一源码目录或 Python 运行环境时直接拒绝启动，禁止混用。
- GS2Mesh 抽取网格前会检查其专用环境中的 Torch、OpenCV、Open3D、Matplotlib、光栅化器和 KNN 模块。
- GS2Mesh、SuGaR、OpenMVS 和 2DGS 改为按环境变量、随包目录、当前工作区动态解析，不依赖设备绝对路径。
- 清理启动、OpenMVS 设置、环境检查和辅助脚本中的本机用户名及桌面路径。
- 已在当前工作站验证专用 GS2Mesh `run_single.py` 运行时，Python、网页 UI 和桌面壳测试全部通过。
- 源码版本更新至 `36.10.9`，封装版本更新至 `0.2.9`。

## 日本語

- GS2Mesh と SuGaR のソース、Python 環境、`PATH`、`PYTHONPATH` を完全に分離しました。
- 両バックエンドが同じソースディレクトリまたは Python 環境を参照する設定を起動前に拒否します。
- GS2Mesh の実行前に、専用環境の Torch、OpenCV、Open3D、Matplotlib、ラスタライザー、KNN モジュールを検証します。
- GS2Mesh、SuGaR、OpenMVS、2DGS は環境変数、同梱フォルダー、現在のワークスペースから動的に解決し、端末固有の絶対パスを使用しません。
- 起動、OpenMVS セットアップ、環境確認、補助スクリプトからローカルユーザー名とデスクトップの固定パスを削除しました。
- 現在のワークステーションで専用 GS2Mesh `run_single.py` ランタイムを確認し、Python、Web UI、デスクトップシェルの全テストに合格しました。
- ソースバージョンを `36.10.9`、パッケージバージョンを `0.2.9` に更新します。
