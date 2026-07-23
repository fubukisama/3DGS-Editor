# Gaussian Scene Workbench 0.2.15

## English

- Preflights the complete 2DGS PyTorch/CUDA runtime before starting a mesh export.
- Stops immediately with a specific Smart App Control message when Windows blocks `c10.dll`, instead of launching rendering and reporting a misleading mesh failure.
- Prevents policy-blocked jobs from attempting stale raw-mesh recovery.
- Clarifies that the workbench does not disable system-wide Smart App Control automatically and that 2DGS requires a trusted signed Windows runtime or WSL2/Linux runtime under this policy.
- Updates the source version to `36.10.15` and the package version to `0.2.15`.

## 中文

- 在启动网格导出前完整预检 2DGS PyTorch/CUDA 运行时。
- 当 Windows Smart App Control 阻止 `c10.dll` 时立即给出明确提示，不再进入渲染后误报为网格失败。
- 防止被系统策略阻止的任务继续尝试恢复旧的原始网格。
- 明确软件不会自动关闭全局 Smart App Control；该策略下运行 2DGS 需要可信签名的 Windows 运行时或 WSL2/Linux 运行时。
- 源码版本更新至 `36.10.15`，封装版本更新至 `0.2.15`。

## 日本語

- メッシュ出力を開始する前に、2DGS の PyTorch/CUDA ランタイム全体を事前確認します。
- Windows Smart App Control が `c10.dll` をブロックした場合、レンダリングを開始せず、誤解を招くメッシュ失敗ではなく明確なメッセージを表示します。
- ポリシーでブロックされたタスクが古い raw メッシュの復旧を試行しないようにします。
- 本ソフトはシステム全体の Smart App Control を自動的に無効化しません。このポリシー下の 2DGS には、信頼された署名付き Windows ランタイムまたは WSL2/Linux ランタイムが必要です。
- ソースバージョンを `36.10.15`、パッケージバージョンを `0.2.15` に更新しました。
