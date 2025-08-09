## MaximizeOnEdge

macOS でウィンドウを画面端へドラッグしてマウスボタンを離すと、そのディスプレイの表示領域いっぱいに自動で最大化するメニューバー常駐アプリです。

### 主な特徴
- 画面の上/下/左/右 いずれかの端で最大化
- プレビュー（薄い青のオーバーレイ）を表示して確定操作を視覚化
- 有効にする端/しきい値(px)/プレビュー ON/OFF を設定可能
- ログイン時の自動起動に対応

### 対応環境
- macOS 13 以降

### 入手とインストール
- 配布アーカイブは Releases に掲載予定です。
- 手動インストール手順は `README_Install_ja.md` にも記載しています。
  1. Zip を展開して `MaximizeOnEdge.app` を `/Applications` に移動
  2. 初回のみ Gatekeeper 回避のため「アプリを右クリック → 開く」で実行
  3. メニューバーのアイコン → 「アクセシビリティ設定を開く」
  4. システム設定 → プライバシーとセキュリティ → アクセシビリティで本アプリをオン

### 使い方
- ウィンドウを端へドラッグし、端に触れた状態でマウスボタンを離すと最大化されます。
- プレビュー表示が出ている状態で離すと確定します。
- 設定はメニューバーの「設定…」から変更できます。

### ビルド方法（開発者向け）
前提: Xcode Command Line Tools, Swift 5.9 以降

1) バイナリビルド（SwiftPM）
```
swift build -c release
```

2) `.app` バンドル作成
```
scripts/make_app_bundle.sh
```
生成物: `MaximizeOnEdge.app`

3) 配布用 Zip（アプリ単体）
```
scripts/package_zip.sh
```
生成物: `MaximizeOnEdge.zip`

4) 配布用 Zip（インストールガイド同梱）
```
scripts/package_zip_with_readme.sh
```
生成物: `MaximizeOnEdge.zip`（`MaximizeOnEdge_Distribution/` 配下に `.app` と `README_Install_ja.md` を同梱）

### 権限について
- ウィンドウ操作のために「アクセシビリティ」権限のみを使用します。

### アンインストール
1. メニューから「ログイン時に自動起動（有効）」をオフ
2. アプリを終了し、`/Applications/MaximizeOnEdge.app` を削除
3. 必要に応じて `~/Library/LaunchAgents/dev.tabe.maximizeonedge.plist` を削除

### ライセンス
本リポジトリは MIT ライセンスで提供します。詳細は `LICENSE` を参照してください。

### 作者
- tabe (GitHub: abeciii0120)


