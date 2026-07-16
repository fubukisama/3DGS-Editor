# Gaussian Scene Workbench 0.2.5

## English

- Added a strict 3DGS CUDA runtime preflight so training does not start when the rasterizer cannot be loaded.
- Detects Windows Smart App Control policy blocks and reports the actual cause instead of a generic training failure.
- Automatically uses a verified local SuGaR compatibility runtime when the primary unsigned CUDA extension is blocked.
- Added compatibility for both legacy and current Gaussian rasterizer APIs, including safe handling of antialiasing and depth output differences.
- Verified both primary and compatibility runtimes with a real 3DGS training, evaluation, PLY save, and checkpoint cycle.

## 中文

- 加入严格的 3DGS CUDA 运行时预检；栅格器无法加载时不再创建必然失败的训练任务。
- 可识别 Windows Smart App Control 的策略拦截，并显示真实原因，不再只报告普通训练失败。
- 主要未签名 CUDA 扩展被拦截时，自动切换到已验证的本地 SuGaR 兼容运行时。
- 同时兼容新旧 Gaussian 栅格器 API，并安全处理抗锯齿和深度输出差异。
- 已使用真实 3DGS 数据验证主要及兼容运行时，覆盖训练、评估、PLY 保存和 checkpoint 保存流程。

## 日本語

- 3DGS CUDA ランタイムの厳密な事前確認を追加し、ラスタライザを読み込めない場合は失敗する学習ジョブを開始しないようにしました。
- Windows Smart App Control によるポリシーブロックを検出し、一般的な学習失敗ではなく実際の原因を表示します。
- メインの未署名 CUDA 拡張がブロックされた場合、検証済みのローカル SuGaR 互換ランタイムへ自動的に切り替えます。
- 新旧 Gaussian ラスタライザ API の両方に対応し、アンチエイリアスと深度出力の差を安全に処理します。
- 実データを使い、メイン／互換ランタイムの学習、評価、PLY 保存、チェックポイント保存を確認しました。
